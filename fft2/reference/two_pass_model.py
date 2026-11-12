"""Tiled, natural-order forward FFT model matching fft2.cu's index maps.

The small in-block FFT is also modeled (binary bit reversal, fused pairs of
radix-2 stages, i.e. radix-4, then one radix-2 stage for odd log2 lengths).
Only a tile lives in local storage at a time. Offsets include the batch base.
"""

from dataclasses import dataclass

import numpy as np


def _power_of_two(value):
    return isinstance(value, (int, np.integer)) and value > 0 and not value & (value - 1)


def _validate_padding(padding):
    if not isinstance(padding, (int, np.integer)) or padding not in (0, 1, 2):
        raise ValueError("padding must be 0, 1 or 2")


def shared_index(element, lane, lanes, padding=0):
    """Physical complex-element offset, including unused cells in each row."""
    _validate_padding(padding)
    return np.asarray(element) * (lanes + padding) + np.asarray(lane)


def shared_bytes(length, lanes, padding=0):
    _validate_padding(padding)
    return length * (lanes + padding) * np.dtype(np.complex128).itemsize


def split_index(flat, divisor, index_mode=0):
    """CUDA's quotient/remainder, including the arbitrary-lane u32 fallback."""
    if index_mode not in (0, 1):
        raise ValueError("index_mode must be 0 or 1")
    if index_mode == 0:
        return np.divmod(flat, divisor)
    values = np.asarray(flat, dtype=np.uint32)
    if _power_of_two(divisor):
        shift = np.uint32(int(divisor).bit_length() - 1)
        return values >> shift, values & np.uint32(divisor - 1)
    return np.divmod(values, np.uint32(divisor))


def twiddle_table(length, exponents):
    """Host table: reduce integer exponents before forming long-double angles."""
    exponents = np.asarray(exponents, dtype=np.uint64) % np.uint64(length)
    pi = np.arccos(np.longdouble(-1))
    angles = -2 * pi * exponents.astype(np.longdouble) / np.longdouble(length)
    result = np.empty(exponents.shape, dtype=np.complex128)
    result.real = np.cos(angles).astype(np.float64)
    result.imag = np.sin(angles).astype(np.float64)
    return result


@dataclass
class CrossTwiddles:
    n: int
    base: int
    low: np.ndarray
    high: np.ndarray

    @classmethod
    def build(cls, n):
        if not _power_of_two(n):
            raise ValueError("N must be a positive power of two")
        base = 1 << ((int(n).bit_length() - 1 + 1) // 2)
        low = twiddle_table(n, np.arange(base, dtype=np.uint64))
        high = twiddle_table(n, np.arange(n // base, dtype=np.uint64) * np.uint64(base))
        return cls(n, base, low, high)

    def lookup(self, n2, k1, index_mode=0):
        # CUDA uses uint64_t multiplication and modulo before hi/lo lookup.
        exponent = (np.asarray(n2, dtype=np.uint64) * np.asarray(k1, dtype=np.uint64))
        if index_mode == 1:
            # Production factors imply n2*k1 < N <= 2^24. Do not silently
            # wrap the large synthetic products used to test mode 0.
            if np.any(exponent >= 1 << 32):
                raise ValueError("u32 cross product exceeds the production index range")
            exponent = exponent.astype(np.uint32) & np.uint32(self.n - 1)
        else:
            exponent %= np.uint64(self.n)
        high, low = split_index(exponent, self.base, index_mode)
        return self.high[high] * self.low[low]


def bit_reverse_indices(length):
    if not _power_of_two(length):
        raise ValueError("FFT length must be a positive power of two")
    index = np.arange(length, dtype=np.uint64)
    reverse = np.zeros(length, dtype=np.uint64)
    for _ in range(int(length).bit_length() - 1):
        reverse = (reverse << np.uint64(1)) | (index & np.uint64(1))
        index >>= np.uint64(1)
    return reverse.astype(np.intp)


def block_fft(tile, padding=0, index_mode=0):
    """FFT along axis 0 of shared[element, lane], with CUDA's stage formulas."""
    length, lanes = tile.shape
    # Poison unused padding. Every load/store uses the physical CUDA layout;
    # an accidental padding read propagates NaN into the numerical gate.
    storage = np.full(shared_bytes(length, lanes, padding) // 16, complex(np.nan, np.nan))
    lane = np.arange(lanes)
    positions = shared_index(np.arange(length)[:, None], lane, lanes, padding)
    reversed_positions = shared_index(bit_reverse_indices(length)[:, None], lane, lanes, padding)
    storage[reversed_positions] = tile
    roots = twiddle_table(length, np.arange(length, dtype=np.uint64))
    span = 4
    while span <= length:
        quarter = span // 4
        # CUDA: butterfly = flat / lanes; lane = flat % lanes;
        # j = butterfly % quarter; start = (butterfly / quarter) * span + j.
        group, j = split_index(np.arange(length // 4), quarter, index_mode)
        start = group * span + j
        exponent = j * (length // span)
        w1 = roots[exponent, None]
        w2 = roots[2 * exponent, None]
        a0 = storage[positions[start]]
        a1 = storage[positions[start + quarter]] * w2
        a2 = storage[positions[start + 2 * quarter]]
        a3 = storage[positions[start + 3 * quarter]] * w2
        u0, u1 = a0 + a1, a0 - a1
        u2, u3 = (a2 + a3) * w1, (a2 - a3) * w1 * (-1j)
        storage[positions[start]] = u0 + u2
        storage[positions[start + quarter]] = u1 + u3
        storage[positions[start + 2 * quarter]] = u0 - u2
        storage[positions[start + 3 * quarter]] = u1 - u3
        span *= 4  # CUDA block barrier between stages.
    if (int(length).bit_length() - 1) & 1:
        half = length // 2
        a = storage[positions[:half]]
        b = storage[positions[half:]] * roots[:half, None]
        storage[positions[:half]], storage[positions[half:]] = a + b, a - b
    return storage[positions]


def choose_tile(length, other_length, shared_limit, requested=0, padding=0, tile_policy=0):
    """Same host tile policies as the CUDA plan, including the two-lane floor."""
    if tile_policy not in (0, 1):
        raise ValueError("tile_policy must be 0 or 1")
    if not _power_of_two(length) or not _power_of_two(other_length):
        raise ValueError("tile dimensions must be powers of two")
    if shared_limit < 0 or requested < 0:
        raise ValueError("shared-memory limit and requested tile must be nonnegative")
    if requested:
        if requested > other_length or shared_bytes(length, requested, padding) > shared_limit:
            raise ValueError("requested tile exceeds dimension or shared-memory limit")
        return requested
    tile = other_length if tile_policy == 1 else min(8, other_length)
    budget = min(shared_limit, 32 * 1024) if tile_policy == 1 else shared_limit
    minimum = 2 if tile_policy == 1 else 0
    while tile > minimum and shared_bytes(length, tile, padding) > budget:
        tile //= 2
    if tile_policy == 1:
        tile = max(2, tile)
    if not tile or tile > other_length or shared_bytes(length, tile, padding) > shared_limit:
        raise ValueError("automatic tile exceeds dimension or shared-memory limit")
    return tile


def two_pass_fft(values, n1=None, tile_cols=0, tile_rows=0, shared_limit=99 * 1024,
                 index_mode=0, smem_padding=0, tile_policy=0):
    """Execute both tiled passes for a vector or a (batch, N) array.

    Small N and asymmetric splits are permitted here to test the formulas;
    the production Plan restricts N to 2^16..2^24 and factors to 256..4096.
    """
    values = np.asarray(values, dtype=np.complex128)
    if values.ndim not in (1, 2) or not values.size:
        raise ValueError("input must be a nonempty vector or (batch, N) array")
    n = values.shape[-1]
    if not _power_of_two(n) or n < 4:
        raise ValueError("N must be a power of two >= 4")
    n1 = 1 << ((n.bit_length() - 1) // 2) if n1 is None else n1
    if not _power_of_two(n1) or n1 <= 1 or n1 >= n or n % n1:
        raise ValueError("N1 must be a power-of-two factor strictly between 1 and N")
    n2 = n // n1
    cols = choose_tile(n1, n2, shared_limit, tile_cols, smem_padding, tile_policy)
    rows = choose_tile(n2, n1, shared_limit, tile_rows, smem_padding, tile_policy)
    cross = CrossTwiddles.build(n)
    data = np.ascontiguousarray(values).reshape(-1)
    batch = values.size // n
    workspace = np.empty_like(data)
    output = np.empty_like(data)

    for batch_index in range(batch):  # CUDA encodes this in grid.y/grid.z.
        base = np.uint64(batch_index * n) if index_mode == 1 else batch_index * n
        for first_col in range(0, n2, cols):
            # Pass 1 flat = element * C + lane: adjacent columns per row.
            element, lane = split_index(np.arange(n1 * cols), cols, index_mode)
            n2_index = first_col + lane
            active = n2_index < n2
            offsets = base + element[active] * n2 + n2_index[active]
            tile = np.zeros((n1, cols), dtype=np.complex128)
            tile.reshape(-1)[active] = data[offsets]
            transformed = block_fft(tile, smem_padding, index_mode)
            # Same shared layout, now element == k1.
            k1 = element[active]
            result = transformed.reshape(-1)[active] * cross.lookup(n2_index[active], k1, index_mode)
            workspace[base + k1 * n2 + n2_index[active]] = result

        for first_row in range(0, n1, rows):
            # Pass 2 LOAD flat = lane * N2 + n2: contiguous input rows.
            lane, element = split_index(np.arange(rows * n2), n2, index_mode)
            k1 = first_row + lane
            active = k1 < n1
            tile = np.zeros((n2, rows), dtype=np.complex128)
            tile[element[active], lane[active]] = workspace[base + k1[active] * n2 + element[active]]
            transformed = block_fft(tile, smem_padding, index_mode)
            # Pass 2 STORE flat = k2 * R + lane: adjacent output k1's.
            k2, lane = split_index(np.arange(n2 * rows), rows, index_mode)
            k1 = first_row + lane
            active = k1 < n1
            output[base + k1[active] + n1 * k2[active]] = transformed.reshape(-1)[active]
    return output.reshape(values.shape)
