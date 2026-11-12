import numpy as np
import pytest

from two_pass_model import (
    block_fft, radix_stage_plan, shared_bytes, staged_index_map, two_pass_fft,
)


@pytest.mark.parametrize("mode,plans", [
    (1, [(3, 3, 2), (3, 3, 3), (3, 3, 3, 1), (3, 3, 3, 2), (3, 3, 3, 3)]),
    (2, [(4, 4), (4, 4, 1), (4, 4, 2), (4, 4, 3), (4, 4, 4)]),
])
def test_host_stage_plans(mode, plans):
    assert [radix_stage_plan(1 << e, mode) for e in range(8, 13)] == plans


@pytest.mark.parametrize("exponent", range(8, 13))
@pytest.mark.parametrize("mode", [1, 2])
@pytest.mark.parametrize("lanes", [1, 2, 3, 8])
@pytest.mark.parametrize("padding", [0, 1, 2])
@pytest.mark.parametrize("index_mode", [0, 1])
def test_stages_and_thread_maps(exponent, mode, lanes, padding, index_mode):
    length = 1 << exponent
    done = 0
    for bits in radix_stage_plan(length, mode):
        m = staged_index_map(length, lanes, done, bits, padding, index_mode)
        flat = m['thread'] + 256 * m['iteration']
        np.testing.assert_array_equal(flat, np.arange(length * lanes // (1 << bits)))
        np.testing.assert_array_equal(m['lane'], flat % lanes)
        logical = m['element'] * lanes + m['lane'][:, None]
        np.testing.assert_array_equal(np.sort(logical.ravel()), np.arange(length * lanes))
        assert np.unique(m['shared']).size == length * lanes
        assert m['shared'].max() < shared_bytes(length, lanes, padding) // 16
        assert np.all(m['shared'] % (lanes + padding) < lanes)
        assert m['exponent'].max() < length
        done += bits
    rng = np.random.default_rng(exponent * 100 + lanes)
    tile = rng.standard_normal((length, lanes)) + 1j * rng.standard_normal((length, lanes))
    actual = block_fft(tile, padding, index_mode, mode)
    expected = np.fft.fft(tile, axis=0)
    assert np.linalg.norm(actual - expected) / np.linalg.norm(expected) <= 1e-14
    np.testing.assert_array_equal(actual, block_fft(tile, radix_mode=mode))


@pytest.mark.parametrize("mode", [1, 2])
@pytest.mark.parametrize("policy", [0, 1])
@pytest.mark.parametrize("index_mode,padding", [(0, 0), (1, 0), (1, 2)])
@pytest.mark.parametrize("n1,n2", [(256, 256), (256, 1024), (1024, 512), (4096, 256)])
def test_staged_two_pass_partial_tiles(mode, policy, index_mode, padding, n1, n2):
    rng = np.random.default_rng(n1 + n2)
    values = rng.standard_normal((3, n1 * n2)) + 1j * rng.standard_normal((3, n1 * n2))
    before = values.copy()
    actual = two_pass_fft(values, n1, 3, 5, shared_limit=512 * 1024,
                          radix_mode=mode, tile_policy=policy,
                          index_mode=index_mode, smem_padding=padding)
    expected = np.fft.fft(values, axis=-1)
    assert np.linalg.norm(actual - expected) / np.linalg.norm(expected) <= 1e-14
    np.testing.assert_array_equal(values, before)


@pytest.mark.parametrize("mode", [-1, 3])
def test_invalid_radix_mode(mode):
    with pytest.raises(ValueError, match="radix_mode"):
        block_fft(np.zeros((256, 1)), radix_mode=mode)
