import numpy as np
import pytest

from two_pass_model import (
    CrossTwiddles, block_fft, choose_tile, shared_bytes, twiddle_table, two_pass_fft,
)


@pytest.mark.parametrize("policy", [0, 1])
@pytest.mark.parametrize("length", [256, 512, 1024, 2048, 4096])
@pytest.mark.parametrize("padding", [0, 1, 2])
@pytest.mark.parametrize("limit", [99 * 1024, 163 * 1024])
def test_shared_roots_budget(policy, length, padding, limit):
    assert shared_bytes(length, 3, padding, 1) == length * (4 + padding) * 16
    if shared_bytes(length, 1, padding, 1) > limit:
        with pytest.raises(ValueError, match="shared-memory"):
            choose_tile(length, 256, limit, padding=padding, tile_policy=policy, twiddle_mode=1)
        return
    lanes = choose_tile(length, 256, limit, padding=padding, tile_policy=policy, twiddle_mode=1)
    assert shared_bytes(length, lanes, padding, 1) <= limit
    if policy == 0:
        assert lanes == 8 or shared_bytes(length, lanes * 2, padding, 1) > limit
    elif shared_bytes(length, 2, padding, 1) <= limit:
        assert lanes >= 2
        assert lanes == 2 or shared_bytes(length, lanes, padding, 1) <= 32 * 1024
        assert shared_bytes(length, lanes * 2, padding, 1) > min(limit, 32 * 1024)
    else:
        assert lanes == choose_tile(length, 256, limit, padding=padding, twiddle_mode=1)


@pytest.mark.parametrize("policy", [0, 1])
def test_explicit_tiles_include_shared_roots(policy):
    assert choose_tile(1024, 256, 64 * 1024, 3, tile_policy=policy, twiddle_mode=1) == 3
    with pytest.raises(ValueError, match="shared-memory"):
        choose_tile(1024, 256, 64 * 1024 - 1, 3, tile_policy=policy, twiddle_mode=1)
    assert choose_tile(4096, 256, 163 * 1024, tile_policy=policy, twiddle_mode=1) == 1
    with pytest.raises(ValueError, match="shared-memory"):
        choose_tile(4096, 256, 99 * 1024, tile_policy=policy, twiddle_mode=1)


@pytest.mark.parametrize("length", [256, 512, 1024, 2048, 4096])
@pytest.mark.parametrize("radix", [0, 2])
def test_shared_roots_preserve_block_bytes(length, radix):
    rng = np.random.default_rng(length)
    tile = rng.standard_normal((length, 3)) + 1j * rng.standard_normal((length, 3))
    baseline = block_fft(tile, padding=2, index_mode=1, radix_mode=radix)
    actual = block_fft(tile, padding=2, index_mode=1, radix_mode=radix, twiddle_mode=1)
    assert actual.tobytes() == baseline.tobytes()


@pytest.mark.parametrize("n", [16, 1 << 16, 1 << 20])
@pytest.mark.parametrize("index_mode", [0, 1])
def test_single_cross_table(n, index_mode):
    table = CrossTwiddles.build(n, cross_mode=1)
    assert table.table_bytes == n * 16
    assert table.low is None and table.high is None
    columns = np.array([0, 1, int(np.sqrt(n)) - 1], dtype=np.uint64)
    k1 = np.array([3, 5, int(np.sqrt(n)) - 1], dtype=np.uint64)
    np.testing.assert_array_equal(table.lookup(columns, k1, index_mode),
                                  twiddle_table(n, columns * k1))
    split = CrossTwiddles.build(n)
    assert split.table_bytes == (split.base + n // split.base) * 16
    assert split.full is None


@pytest.mark.parametrize("radix,policy,tw,cx", [
    (r, p, t, c) for r in (0, 2) for p in (0, 1) for t, c in ((1, 0), (0, 1), (1, 1))
])
@pytest.mark.parametrize("n1,n2,batch,index,padding,cols,rows", [
    (256, 512, 3, 1, 2, 3, 5),  # Partial tiles, u32 fallback, padded storage.
    (1024, 1024, 1, 0, 0, 0, 0),  # Automatic tiles under the L4 budget.
])
def test_twiddle_variants(radix, policy, tw, cx, n1, n2, batch, index, padding, cols, rows):
    rng = np.random.default_rng(n1 + n2)
    values = rng.standard_normal((batch, n1 * n2)) + 1j * rng.standard_normal((batch, n1 * n2))
    options = dict(n1=n1, tile_cols=cols, tile_rows=rows, index_mode=index,
                   smem_padding=padding, radix_mode=radix, tile_policy=policy)
    actual = two_pass_fft(values, twiddle_mode=tw, cross_mode=cx, **options)
    expected = np.fft.fft(values, axis=-1)
    assert np.linalg.norm(actual - expected) / np.linalg.norm(expected) <= 1e-14
    if cx == 0:
        assert actual.tobytes() == two_pass_fft(values, **options).tobytes()


@pytest.mark.parametrize("name", ["twiddle_mode", "cross_mode"])
@pytest.mark.parametrize("mode", [-1, 2, 0.5])
def test_invalid_twiddle_modes(name, mode):
    with pytest.raises(ValueError, match=name):
        two_pass_fft(np.zeros(64), **{name: mode})
