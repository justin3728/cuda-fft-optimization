"""Tiled, natural-order forward FFT model matching fft2.cu's index maps.

The small in-block FFT is also modeled (binary bit reversal, fused pairs of
radix-2 stages, i.e. radix-4, then one radix-2 stage for odd log2 lengths).
Only a tile lives in local storage at a time. Offsets include the batch base.
"""

from dataclasses import dataclass

import numpy as np


def _power_of_two(value):
    return isinstance(value, (int, np.integer)) and value > 0 and not value & (value - 1)


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

    def lookup(self, n2, k1):
        # CUDA uses uint64_t multiplication and modulo before hi/lo lookup.
        exponent = (np.asarray(n2, dtype=np.uint64) * np.asarray(k1, dtype=np.uint64))
        exponent %= np.uint64(self.n)
        return self.high[exponent // np.uint64(self.base)] * self.low[exponent % np.uint64(self.base)]


def bit_reverse_indices(length):
    if not _power_of_two(length):
        raise ValueError("FFT length must be a positive power of two")
    index = np.arange(length, dtype=np.uint64)
    reverse = np.zeros(length, dtype=np.uint64)
    for _ in range(int(length).bit_length() - 1):
        reverse = (reverse << np.uint64(1)) | (index & np.uint64(1))
        index >>= np.uint64(1)
    return reverse.astype(np.intp)


def block_fft(tile):
    """FFT along axis 0 of shared[element, lane], with CUDA's stage formulas."""
    length, _ = tile.shape
    shared = np.empty_like(tile)
    shared[bit_reverse_indices(length), :] = tile
    roots = twiddle_table(length, np.arange(length, dtype=np.uint64))
    span = 4
    while span <= length:
        quarter = span // 4
        # CUDA: butterfly = flat / lanes; lane = flat % lanes;
        # j = butterfly % quarter; start = (butterfly / quarter) * span + j.
        j = np.arange(quarter, dtype=np.intp)
        start = (np.arange(length // span)[:, None] * span + j).reshape(-1)
        exponent = np.tile(j * (length // span), length // span)
        w1 = roots[exponent, None]
        w2 = roots[2 * exponent, None]
        a0 = shared[start].copy()
        a1 = shared[start + quarter] * w2
        a2 = shared[start + 2 * quarter].copy()
        a3 = shared[start + 3 * quarter] * w2
        u0, u1 = a0 + a1, a0 - a1
        u2, u3 = (a2 + a3) * w1, (a2 - a3) * w1 * (-1j)
        shared[start] = u0 + u2
        shared[start + quarter] = u1 + u3
        shared[start + 2 * quarter] = u0 - u2
        shared[start + 3 * quarter] = u1 - u3
        span *= 4  # CUDA block barrier between stages.
    if (int(length).bit_length() - 1) & 1:
        half = length // 2
        a = shared[:half].copy()
        b = shared[half:] * roots[:half, None]
        shared[:half], shared[half:] = a + b, a - b
    return shared


def choose_tile(length, other_length, shared_limit, requested=0):
    """Same policy as the CUDA plan; automatic widths are powers of two <= 8."""
    if not _power_of_two(length) or not _power_of_two(other_length):
        raise ValueError("tile dimensions must be powers of two")
    if shared_limit < 0 or requested < 0:
        raise ValueError("shared-memory limit and requested tile must be nonnegative")
    if requested:
        if requested > other_length or length * requested * 16 > shared_limit:
            raise ValueError("requested tile exceeds dimension or shared-memory limit")
        return requested
    tile = min(8, other_length)
    while tile and length * tile * 16 > shared_limit:
        tile //= 2
    if not tile:
        raise ValueError("one FFT exceeds the shared-memory limit")
    return tile


def two_pass_fft(values, n1=None, tile_cols=0, tile_rows=0, shared_limit=99 * 1024):
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
    cols = choose_tile(n1, n2, shared_limit, tile_cols)
    rows = choose_tile(n2, n1, shared_limit, tile_rows)
    cross = CrossTwiddles.build(n)
    data = np.ascontiguousarray(values).reshape(-1)
    batch = values.size // n
    workspace = np.empty_like(data)
    output = np.empty_like(data)

    for batch_index in range(batch):  # CUDA encodes this in grid.y/grid.z.
        base = batch_index * n
        for first_col in range(0, n2, cols):
            # Pass 1 flat = element * C + lane: adjacent columns per row.
            element, lane = np.divmod(np.arange(n1 * cols), cols)
            n2_index = first_col + lane
            active = n2_index < n2
            offsets = base + element[active] * n2 + n2_index[active]
            tile = np.zeros((n1, cols), dtype=np.complex128)
            tile.reshape(-1)[active] = data[offsets]
            transformed = block_fft(tile)
            # Same shared layout, now element == k1.
            k1 = element[active]
            result = transformed.reshape(-1)[active] * cross.lookup(n2_index[active], k1)
            workspace[base + k1 * n2 + n2_index[active]] = result

        for first_row in range(0, n1, rows):
            # Pass 2 LOAD flat = lane * N2 + n2: contiguous input rows.
            lane, element = np.divmod(np.arange(rows * n2), n2)
            k1 = first_row + lane
            active = k1 < n1
            tile = np.zeros((n2, rows), dtype=np.complex128)
            tile[element[active], lane[active]] = workspace[base + k1[active] * n2 + element[active]]
            transformed = block_fft(tile)
            # Pass 2 STORE flat = k2 * R + lane: adjacent output k1's.
            k2, lane = np.divmod(np.arange(n2 * rows), rows)
            k1 = first_row + lane
            active = k1 < n1
            output[base + k1[active] + n1 * k2[active]] = transformed.reshape(-1)[active]
    return output.reshape(values.shape)
