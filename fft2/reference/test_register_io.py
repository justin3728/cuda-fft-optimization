"""CPU hypothesis checks for register I/O ownership; GPU gates remain required."""
import numpy as np
import pytest

from two_pass_model import (
    CrossTwiddles, _INTERNAL_ROOTS, bit_reverse_indices, block_fft, radix_stage_plan,
    shared_index, staged_index_map, twiddle_table,
)


def butterfly(v):
    v = v.copy()
    half = 1
    while half < v.shape[-1]:
        for base in range(0, v.shape[-1], 2 * half):
            for j in range(half):
                a = v[:, base + j].copy()
                b = v[:, base + j + half] * _INTERNAL_ROOTS[j * (8 // half)]
                v[:, base + j], v[:, base + j + half] = a + b, a - b
        half *= 2
    return v


def io_fft(tile, radix_mode, io_mode, columns, padding):
    length, lanes = tile.shape
    storage = np.full(length * (lanes + padding), complex(np.nan, np.nan))
    output = np.full_like(tile, complex(np.nan, np.nan))
    reverse = bit_reverse_indices(length)
    roots = twiddle_table(length, np.arange(length))
    plan = radix_stage_plan(length, radix_mode)
    if io_mode == 1:
        flat = np.arange(length * lanes)
        lane, element = (flat % lanes, flat // lanes) if columns else divmod(flat, length)
        # thread + e*256: all global loads, then all shared stores.
        registers = tile[element, lane].copy()
        storage[shared_index(reverse[element], lane, lanes, padding)] = registers
        stages = enumerate(plan)
    else:
        radix = 1 << plan[0]
        flat = np.arange(length * lanes // radix)
        lane, q = (flat % lanes, flat // lanes) if columns else divmod(flat, length // radix)
        element = q[:, None] + bit_reverse_indices(radix) * (length // radix)
        registers = tile[element, lane[:, None]].copy()
        destination = bit_reverse_indices(length // radix)[q, None] * radix + np.arange(radix)
        storage[shared_index(destination, lane[:, None], lanes, padding)] = butterfly(registers)
        np.testing.assert_array_equal(np.sort((element * lanes + lane[:, None]).ravel()),
                                      np.arange(length * lanes))
        stages = list(enumerate(plan))[1:]
    done = 0 if io_mode == 1 else plan[0]
    for stage, bits in stages:
        m = staged_index_map(length, lanes, done, bits, padding)
        registers = storage[m['shared']] * roots[m['exponent']]
        registers = butterfly(registers)
        if io_mode == 2 and stage == len(plan) - 1:
            output[m['element'], m['lane'][:, None]] = registers
        else:
            storage[m['shared']] = registers
        done += bits
    if io_mode == 1:
        flat = np.arange(length * lanes)
        k, lane = divmod(flat, lanes)
        registers = storage[shared_index(k, lane, lanes, padding)].copy()
        output[k, lane] = registers
    return output


@pytest.mark.parametrize('exponent', range(8, 13))
@pytest.mark.parametrize('lanes', [1, 2, 3, 4, 5, 8])
@pytest.mark.parametrize('radix_mode', [1, 2])
@pytest.mark.parametrize('columns', [False, True])
@pytest.mark.parametrize('padding', [0, 2])
def test_register_io_mapping_and_arithmetic(exponent, lanes, radix_mode, columns, padding):
    length = 1 << exponent
    rng = np.random.default_rng(length + lanes)
    tile = rng.standard_normal((length, lanes)) + 1j * rng.standard_normal((length, lanes))
    baseline = block_fft(tile, padding=padding, radix_mode=radix_mode)
    np.testing.assert_array_equal(io_fft(tile, radix_mode, 1, columns, padding), baseline)
    fused = io_fft(tile, radix_mode, 2, columns, padding)
    expected = np.fft.fft(tile, axis=0)
    assert np.linalg.norm(fused - expected) / np.linalg.norm(expected) <= 1e-12


@pytest.mark.parametrize('exponent', range(8, 13))
@pytest.mark.parametrize('lanes', [1, 2, 4, 8])
@pytest.mark.parametrize('radix_mode', [1, 2])
def test_thread_ownership_and_coalescing(exponent, lanes, radix_mode):
    length = 1 << exponent
    radix = 1 << radix_stage_plan(length, radix_mode)[0]
    for columns in (False, True):
        for io in (1, 2):
            count = length * lanes // (radix if io == 2 else 1)
            slots = np.arange(256)[:, None] + 256 * np.arange((count + 255) // 256)
            np.testing.assert_array_equal(np.sort(slots[slots < count]), np.arange(count))
            # The first issued instruction has the existing adjacent address order.
            flat = np.arange(min(32, count))
            q, lane = divmod(flat, lanes) if columns else (flat % (length // (radix if io == 2 else 1)),
                                                         flat // (length // (radix if io == 2 else 1)))
            address = q * 8192 + lane if columns else lane * length + q
            if columns:
                np.testing.assert_array_equal(address % 8192, flat % lanes)
            else:
                row_length = length // (radix if io == 2 else 1)
                np.testing.assert_array_equal(address, flat // row_length * length + flat % row_length)


@pytest.mark.parametrize('n1,n2', [(256, 256), (256, 512), (512, 1024)])
@pytest.mark.parametrize('io', [1, 2])
@pytest.mark.parametrize('radix', [1, 2])
def test_two_pass_global_layout_partial_tiles(n1, n2, io, radix):
    rng = np.random.default_rng(n1 + n2)
    values = rng.standard_normal((2, n1, n2)) + 1j * rng.standard_normal((2, n1, n2))
    cross = CrossTwiddles.build(n1 * n2)
    workspace = np.empty_like(values)
    output = np.empty((2, n2, n1), dtype=np.complex128)
    for batch in range(2):
        for first in range(0, n2, 3):
            width = min(3, n2 - first)
            tile = np.zeros((n1, 3), dtype=np.complex128)
            tile[:, :width] = values[batch, :, first:first + width]
            result = io_fft(tile, radix, io, True, 2)
            k1 = np.arange(n1)[:, None]
            columns = np.arange(first, first + width)
            workspace[batch, :, first:first + width] = result[:, :width] * cross.lookup(columns, k1)
        for first in range(0, n1, 5):
            width = min(5, n1 - first)
            tile = np.zeros((n2, 5), dtype=np.complex128)
            tile[:, :width] = workspace[batch, first:first + width].T
            result = io_fft(tile, radix, io, False, 2)
            output[batch, :, first:first + width] = result[:, :width]
    expected = np.fft.fft(values.reshape(2, -1), axis=-1)
    actual = output.reshape(2, -1)
    assert np.linalg.norm(actual - expected) / np.linalg.norm(expected) <= 1e-12
