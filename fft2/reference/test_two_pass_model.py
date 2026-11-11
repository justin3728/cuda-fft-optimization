import numpy as np
import pytest

from two_pass_model import CrossTwiddles, block_fft, choose_tile, two_pass_fft, twiddle_table


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
def test_register_butterflies_and_bit_reversal(exponent, lanes):
    rng = np.random.default_rng(exponent * 10 + lanes)
    tile = rng.standard_normal((1 << exponent, lanes)) + 1j * rng.standard_normal((1 << exponent, lanes))
    assert relative_l2(block_fft(tile), np.fft.fft(tile, axis=0)) <= 1e-13


@pytest.mark.parametrize("n1", [16, 32, 64])
@pytest.mark.parametrize("cols,rows", [(1, 1), (2, 4), (4, 2), (3, 5), (8, 8)])
def test_tile_load_store_maps_and_partial_tiles(n1, cols, rows):
    # Impulses, a DC component, a tone, and different batches catch permutations.
    n = 1024
    values = np.zeros((3, n), dtype=np.complex128)
    values[0, [0, 17, n - 1]] = [1, 2j, 3 - 4j]
    values[1] = 1
    values[2] = np.exp(2j * np.pi * 37 * np.arange(n) / n)
    before = values.copy()
    actual = two_pass_fft(values, n1, cols, rows)
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
def test_shared_memory_budget_every_production_size(limit):
    for exponent in range(16, 25):
        n1 = 1 << (exponent // 2)
        n2 = (1 << exponent) // n1
        for length, other in [(n1, n2), (n2, n1)]:
            tile = choose_tile(length, other, limit)
            assert length * tile * 16 <= limit
            assert tile >= 2 or length * 2 * 16 > limit


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
