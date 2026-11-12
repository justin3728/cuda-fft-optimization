import numpy as np
import pytest

from two_pass_model import (
    CrossTwiddles, block_fft, choose_tile, shared_bytes, shared_index, split_index,
    two_pass_fft, twiddle_table,
)


def relative_l2(actual, expected):
    return np.linalg.norm((actual - expected).ravel()) / np.linalg.norm(expected.ravel())


CASES = [
    (exponent, split, batch)
    for exponent in range(4, 21)
    for split in sorted({exponent // 2, max(1, exponent // 2 - 1), max(1, exponent // 2 - 2)})
    for batch in (1, 3)
]


@pytest.mark.parametrize("exponent,split,batch", CASES)
def test_all_powers_splits_and_batches(exponent, split, batch):
    n = 1 << exponent
    rng = np.random.default_rng(1000 * exponent + 10 * split + batch)
    values = rng.standard_normal((batch, n)) + 1j * rng.standard_normal((batch, n))
    # Deliberately distinct transforms catch missing/wrong batch offsets.
    actual = two_pass_fft(values, n1=1 << split)
    assert relative_l2(actual, np.fft.fft(values, axis=-1)) <= 1e-13


@pytest.mark.slow
@pytest.mark.parametrize("exponent", range(21, 25))
@pytest.mark.parametrize("batch", [1, 3])
def test_large_powers(exponent, batch):
    n = 1 << exponent
    rng = np.random.default_rng(exponent + batch)
    values = rng.standard_normal((batch, n)) + 1j * rng.standard_normal((batch, n))
    assert relative_l2(two_pass_fft(values), np.fft.fft(values, axis=-1)) <= 1e-13


@pytest.mark.parametrize("exponent", range(1, 13))
@pytest.mark.parametrize("lanes", [1, 2, 3, 8])
@pytest.mark.parametrize("padding", [0, 1, 2])
@pytest.mark.parametrize("index_mode", [0, 1])
def test_register_butterflies_and_bit_reversal(exponent, lanes, padding, index_mode):
    rng = np.random.default_rng(exponent * 10 + lanes)
    tile = rng.standard_normal((1 << exponent, lanes)) + 1j * rng.standard_normal((1 << exponent, lanes))
    actual = block_fft(tile, padding, index_mode)
    assert relative_l2(actual, np.fft.fft(tile, axis=0)) <= 1e-13
    np.testing.assert_array_equal(actual, block_fft(tile))


@pytest.mark.parametrize("n1", [16, 32, 64])
@pytest.mark.parametrize("cols,rows", [(1, 1), (2, 4), (4, 2), (3, 5), (8, 8)])
@pytest.mark.parametrize("padding", [0, 1, 2])
@pytest.mark.parametrize("index_mode", [0, 1])
def test_tile_load_store_maps_and_partial_tiles(n1, cols, rows, padding, index_mode):
    # Impulses, a DC component, a tone, and different batches catch permutations.
    n = 1024
    values = np.zeros((3, n), dtype=np.complex128)
    values[0, [0, 17, n - 1]] = [1, 2j, 3 - 4j]
    values[1] = 1
    values[2] = np.exp(2j * np.pi * 37 * np.arange(n) / n)
    before = values.copy()
    actual = two_pass_fft(values, n1, cols, rows, index_mode=index_mode, smem_padding=padding)
    np.testing.assert_array_equal(values, before)
    assert relative_l2(actual, np.fft.fft(values, axis=-1)) <= 1e-13


@pytest.mark.parametrize("exponent", range(4, 25))
def test_two_level_table_and_64_bit_reduction(exponent):
    n = 1 << exponent
    table = CrossTwiddles.build(n)
    rng = np.random.default_rng(exponent)
    # Include products far larger than uint32, with exact integer reduction.
    n2 = np.array([0, n - 1, 1 << 35, *rng.integers(0, n, 200)], dtype=np.uint64)
    k1 = np.array([n - 1, n - 1, 12345, *rng.integers(0, n, 200)], dtype=np.uint64)
    expected = twiddle_table(n, (n2 * k1) % np.uint64(n))
    # Windows NumPy's longdouble can equal double. Allow trig/complex-product
    # rounding there; the end-to-end FFT threshold remains 1e-13 everywhere.
    assert np.max(np.abs(table.lookup(n2, k1) - expected)) <= 8 * np.finfo(np.float64).eps
    assert table.base == 1 << ((exponent + 1) // 2)
    assert table.low.size == table.base
    assert table.high.size == n // table.base


@pytest.mark.parametrize("limit", [99 * 1024, 163 * 1024])
@pytest.mark.parametrize("padding", [0, 1, 2])
def test_shared_memory_budget_every_production_size(limit, padding):
    for exponent in range(16, 25):
        n1 = 1 << (exponent // 2)
        n2 = (1 << exponent) // n1
        for length, other in [(n1, n2), (n2, n1)]:
            if shared_bytes(length, 1, padding) > limit:
                with pytest.raises(ValueError, match="shared-memory"):
                    choose_tile(length, other, limit, padding=padding)
                continue
            tile = choose_tile(length, other, limit, padding=padding)
            assert shared_bytes(length, tile, padding) <= limit
            assert tile == 8 or shared_bytes(length, 2 * tile, padding) > limit


@pytest.mark.parametrize("length,limit,padding,expected", [
    (4096, 163 * 1024, 1, 1),
    (2048, 163 * 1024, 2, 2),
    (512, 64 * 1024, 1, 4),
    (2048, 99 * 1024, 2, 1),
    (1024, 128 * 1024, 1, 4),
])
def test_padding_shrinks_automatic_lanes(length, limit, padding, expected):
    before = choose_tile(length, length, limit)
    after = choose_tile(length, length, limit, padding=padding)
    assert after == expected < before
    assert shared_bytes(length, after, padding) <= limit
    with pytest.raises(ValueError, match="shared-memory"):
        choose_tile(length, length, limit, requested=before, padding=padding)


@pytest.mark.parametrize("limit,padding", [(99 * 1024, 1), (99 * 1024, 2), (163 * 1024, 2)])
def test_padding_can_make_even_one_lane_infeasible(limit, padding):
    for requested in (0, 1):
        with pytest.raises(ValueError, match="shared-memory"):
            choose_tile(4096, 4096, limit, requested, padding)


@pytest.mark.parametrize("limit", [99 * 1024, 163 * 1024])
@pytest.mark.parametrize("length,expected", [
    (256, (8, 4, 4)), (512, (4, 2, 2)), (1024, (2, 2, 2)),
    (2048, (2, 2, 2)), (4096, (2, None, None)),
])
def test_tile_policy_one_table(length, expected, limit):
    for padding, lanes in enumerate(expected):
        if lanes is None or shared_bytes(length, 2, padding) > limit:
            with pytest.raises(ValueError, match="shared-memory"):
                choose_tile(length, 256, limit, padding=padding, tile_policy=1)
        else:
            assert choose_tile(length, 256, limit, padding=padding, tile_policy=1) == lanes


@pytest.mark.parametrize("policy", [0, 1])
def test_explicit_tiles_override_policy(policy):
    assert choose_tile(512, 256, 163 * 1024, 3, 1, policy) == 3
    assert choose_tile(4096, 256, 99 * 1024, 1, 0, policy) == 1
    with pytest.raises(ValueError, match="shared-memory"):
        choose_tile(4096, 256, 163 * 1024, 3, 0, policy)


def test_tile_policy_one_dimension_and_minimum():
    assert choose_tile(256, 2, 163 * 1024, tile_policy=1) == 2
    assert choose_tile(64, 256, 163 * 1024, tile_policy=1) == 32
    with pytest.raises(ValueError, match="shared-memory"):
        choose_tile(1024, 256, 32 * 1024 - 1, tile_policy=1)


@pytest.mark.parametrize("n1,n2,batch", [(512, 256, 1), (256, 1024, 3), (2048, 256, 1)])
@pytest.mark.parametrize("padding", [0, 1, 2])
@pytest.mark.parametrize("mode", [0, 1])
def test_tile_policy_preserves_output_bytes(n1, n2, batch, padding, mode):
    rng = np.random.default_rng(n1 + n2)
    values = rng.standard_normal((batch, n1 * n2)) + 1j * rng.standard_normal((batch, n1 * n2))
    options = dict(n1=n1, shared_limit=163 * 1024, index_mode=mode, smem_padding=padding)
    baseline = two_pass_fft(values, **options)
    candidate = two_pass_fft(values, tile_policy=1, **options)
    assert candidate.tobytes() == baseline.tobytes()


@pytest.mark.parametrize("policy", [-1, 2])
def test_invalid_tile_policy(policy):
    with pytest.raises(ValueError, match="tile_policy"):
        two_pass_fft(np.zeros(64), tile_policy=policy)


@pytest.mark.parametrize("length", [2, 256, 4096])
@pytest.mark.parametrize("lanes", [1, 3, 8])
@pytest.mark.parametrize("padding", [0, 1, 2])
def test_physical_shared_layout(length, lanes, padding):
    offsets = shared_index(np.arange(length)[:, None], np.arange(lanes), lanes, padding)
    assert np.unique(offsets).size == length * lanes
    assert offsets.max() < shared_bytes(length, lanes, padding) // 16
    storage = np.full(shared_bytes(length, lanes, padding) // 16, -1)
    storage[offsets] = np.arange(length * lanes).reshape(length, lanes)
    np.testing.assert_array_equal(storage.reshape(length, lanes + padding)[:, lanes:], -1)
    np.testing.assert_array_equal(storage[offsets].ravel(), np.arange(length * lanes))


@pytest.mark.parametrize("divisor", [1, 2, 3, 5, 8, 256, 4096])
def test_u32_shift_mask_and_arbitrary_width_indices(divisor):
    values = np.array([0, 1, divisor - 1, divisor, (1 << 24) - 1, (1 << 32) - 1], dtype=np.uint32)
    quotient, remainder = split_index(values, divisor, 1)
    assert quotient.dtype == remainder.dtype == np.uint32
    np.testing.assert_array_equal(quotient, values.astype(np.uint64) // divisor)
    np.testing.assert_array_equal(remainder, values.astype(np.uint64) % divisor)


@pytest.mark.parametrize("exponent", range(16, 25))
def test_u32_cross_table_production_extremes(exponent):
    n = 1 << exponent
    n1 = 1 << (exponent // 2)
    n2 = n // n1
    table = CrossTwiddles.build(n)
    columns = np.array([0, 1, n2 - 1], dtype=np.uint32)
    k1 = np.array([n1 - 1, 1, n1 - 1], dtype=np.uint32)
    np.testing.assert_array_equal(table.lookup(columns, k1, 1), table.lookup(columns, k1))


@pytest.mark.parametrize("exponent", [16, 19, 20])
@pytest.mark.parametrize("index_mode", [0, 1])
@pytest.mark.parametrize("padding", [0, 1, 2])
def test_production_variants(exponent, index_mode, padding):
    rng = np.random.default_rng(exponent)
    values = rng.standard_normal((1, 1 << exponent)) + 1j * rng.standard_normal((1, 1 << exponent))
    actual = two_pass_fft(values, index_mode=index_mode, smem_padding=padding)
    assert relative_l2(actual, np.fft.fft(values, axis=-1)) <= 1e-13


@pytest.mark.parametrize("padding", [-1, 3, 0.5])
def test_invalid_padding(padding):
    with pytest.raises(ValueError, match="padding"):
        two_pass_fft(np.zeros(64), smem_padding=padding)


def test_invalid_index_mode():
    with pytest.raises(ValueError, match="index_mode"):
        two_pass_fft(np.zeros(64), index_mode=2)


@pytest.mark.parametrize("limit,requested", [(60 * 1024, 0), (99 * 1024, 2), (163 * 1024, 3)])
def test_reject_shared_memory_overflow(limit, requested):
    with pytest.raises(ValueError, match="shared-memory"):
        choose_tile(4096, 4096, limit, requested)


@pytest.mark.parametrize("n,n1", [(15, 4), (16, 3), (16, 16), (16, 0), (0, 2)])
def test_invalid_shapes(n, n1):
    with pytest.raises(ValueError):
        two_pass_fft(np.zeros(n), n1)


def test_vector_and_noncontiguous_input():
    values = np.arange(128, dtype=np.float64)[::2] + 2j
    assert relative_l2(two_pass_fft(values), np.fft.fft(values)) <= 1e-13
