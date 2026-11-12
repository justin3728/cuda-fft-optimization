"""CPU model of fft2/fft2.cu, index map by index map.

Every function mirrors a piece of the CUDA code (named in each docstring).
The model "runs" a block by evaluating the same thread maps over the 256 thread
ids (vectorized over threads, and over many blocks at once), against a flat
shared array indexed by shared_index(), so CPU CI validates the CUDA indexing.
Sequential evaluation of a shared stage is only equivalent to the parallel one
because every stage's writes are disjoint; the model asserts that.
"""
import numpy as np

THREADS = 256
A100_LIMIT = 163 * 1024  # opt-in shared memory per block, bytes
L4_LIMIT = 99 * 1024
_CHUNK_ELEMENTS = 1 << 19  # complex values simulated at once


# ---- detail/tile_policy.h ----------------------------------------------------
def shared_bytes(length, lanes):
    return length * lanes * 16


def choose_tile(length, other_length, limit):
    if shared_bytes(length, 1) > limit:
        raise ValueError(f"one FFT of length {length} needs {shared_bytes(length, 1)} "
                         f"bytes of shared memory; limit is {limit}")
    if shared_bytes(length, 2) > limit:
        return 1
    budget = min(limit, 32 * 1024)
    lanes = other_length
    while lanes > 2 and shared_bytes(length, lanes) > budget:
        lanes //= 2
    return lanes


def radix_bits(length, lanes, threads=THREADS):
    return 4 if length * lanes // 16 >= threads else 3


# ---- fft2.cu helpers ---------------------------------------------------------
def reverse_bits(x, nbits):
    """reverse_index: works on Python ints and integer ndarrays."""
    r = 0
    for i in range(nbits):
        r = r | (((x >> i) & 1) << (nbits - 1 - i))
    return r


def shared_index(element, lane, lanes):
    return element * lanes + lane


def make_table(period, count, step):
    """make_table: W_period^(index*step), exponent reduced as an integer first."""
    exponent = (np.arange(count, dtype=np.uint64) * np.uint64(step)) % np.uint64(period)
    two_pi = 2 * np.arccos(np.longdouble(-1))
    angle = -two_pi * exponent.astype(np.longdouble) / np.longdouble(period)
    return (np.cos(angle).astype(np.float64) + 1j * np.sin(angle).astype(np.float64))


_C = 0.923879532511286756128183189396788286
_S = 0.382683432365089771728459984030398867
_H = 0.707106781186547524400844362104849039
_W16 = np.array([complex(r, i) for r, i in zip(
    [1.0, _C, _H, _S, 0.0, -_S, -_H, -_C], [0.0, -_S, -_H, -_C, -1.0, -_C, -_H, -_S])])


def register_butterfly(v, half=1):
    """In place radix-R DIT on v[0..R) (bit-reversed input -> natural output),
    twiddles W_16^(j*(8/half)) as in the CUDA constant subset."""
    r = v.shape[0]
    for base in range(0, r, 2 * half):
        for j in range(half):
            a = v[base + j].copy()
            b = v[base + j + half] * _W16[j * (8 // half)]
            v[base + j] = a + b
            v[base + j + half] = a - b
    if 2 * half < r:
        register_butterfly(v, 2 * half)


def _slots_once(slots, size, what):
    counts = np.bincount(np.concatenate(slots), minlength=size)
    assert counts.shape[0] == size and (counts == 1).all(), f"{what}: shared slots not hit exactly once"


class TilePass:
    """TilePass<LogLength, Bits, Lanes>."""

    def __init__(self, log_length, bits, lanes):
        self.log_length, self.bits, self.lanes = log_length, bits, lanes
        self.length = 1 << log_length
        self.first_radix = 1 << bits
        self.last_bits = (log_length - 1) % bits + 1
        self.last_radix = 1 << self.last_bits
        self.m = self.length // self.first_radix  # length / first_radix
        self.count_in = self.m * lanes
        self.count_out = self.length * lanes // self.last_radix
        self.loads = -(-self.count_in // THREADS)
        self.stores = -(-self.count_out // THREADS)

    # -- thread maps (arrays over threadIdx.x) --
    def input_map(self, columns, group, t, tid=None):
        tid = np.arange(THREADS) if tid is None else tid
        flat = tid + group * THREADS
        q = flat // self.lanes if columns else flat % self.m
        lane = flat % self.lanes if columns else flat // self.m
        element = q + reverse_bits(t, self.bits) * self.m
        return flat, element, lane

    def output_map(self, group, t, tid=None):
        tid = np.arange(THREADS) if tid is None else tid
        flat = tid + group * THREADS
        lane = flat % self.lanes
        element = flat // self.lanes + t * (self.length // self.last_radix)
        return flat, element, lane

    def load_destination(self, element, t):
        """Shared element for a value held after the first butterfly."""
        return reverse_bits(element % self.m, self.log_length - self.bits) * self.first_radix + t

    def stage_bits(self, done):
        return min(self.log_length - done, self.bits)

    def stage_map(self, done, flat):
        """Per-thread (start, lane, j) of shared stage <done, ...>."""
        radix, previous = 1 << self.stage_bits(done), 1 << done
        span = previous * radix
        butterfly, lane = flat // self.lanes, flat % self.lanes
        j = butterfly % previous
        return butterfly // previous * span + j, lane, j

    def shared_stage_starts(self):
        return range(self.bits, self.log_length - self.last_bits, self.bits)

    # -- one stage in shared memory; shared is (blocks, length*lanes) --
    def stage(self, shared, roots, done):
        bits = self.stage_bits(done)
        radix, previous = 1 << bits, 1 << done
        span = previous * radix
        count = self.length // radix * self.lanes
        size = self.length * self.lanes
        writes = np.zeros(size, dtype=np.int64)
        for k in range(-(-count // THREADS)):
            flat = np.arange(THREADS) + k * THREADS
            flat = flat[flat < count]
            start, lane, j = self.stage_map(done, flat)
            slots = [shared_index(start + t * previous, lane, self.lanes) for t in range(radix)]
            v = np.empty((radix, shared.shape[0], len(flat)), dtype=complex)
            for t in range(radix):
                exponent = reverse_bits(t, bits) * j * (self.length // span)
                v[t] = shared[:, slots[t]] * roots[exponent]
            register_butterfly(v)
            for t in range(radix):
                shared[:, slots[t]] = v[t]
                writes += np.bincount(slots[t], minlength=size)
        assert (writes == 1).all(), f"stage<{done}>: shared writes not disjoint/complete"

    # -- the whole pass, over (batch x blocks) in chunks --
    def run(self, columns, src, dst, other, batch, roots, cross=None):
        """execute<Columns>: src/dst are flat arrays of batch*length*other values.
        cross = (n, cross_base, cross_low, cross_high) for pass 1, else None."""
        length, lanes, bits = self.length, self.lanes, self.bits
        n = length * other
        blocks = other // lanes
        size = length * lanes
        pairs = batch * blocks
        per_chunk = max(1, _CHUNK_ELEMENTS // size)
        stored = 0
        seen = np.zeros(batch * n, dtype=bool)
        for lo in range(0, pairs, per_chunk):
            ids = np.arange(lo, min(pairs, lo + per_chunk))
            base = (ids // blocks * n)[:, None]
            first = (ids % blocks * lanes)[:, None]
            p = len(ids)
            shared = np.zeros((p, size), dtype=complex)
            load_slots = []
            for g in range(self.loads):
                v = np.zeros((self.first_radix, p, THREADS), dtype=complex)
                for t in range(self.first_radix):
                    flat, element, lane = self.input_map(columns, g, t)
                    col = first + lane
                    off = element * other + col if columns else col * length + element
                    valid = (flat < self.count_in) & (col < other)
                    v[t] = np.where(valid, src[base + np.where(valid, off, 0)], 0)
                register_butterfly(v)
                for t in range(self.first_radix):
                    flat, element, lane = self.input_map(columns, g, t)
                    ok = flat < self.count_in
                    slots = shared_index(self.load_destination(element, t)[ok], lane[ok], lanes)
                    shared[:, slots] = v[t][:, ok]
                    load_slots.append(slots)
            _slots_once(load_slots, size, "load")
            for done in self.shared_stage_starts():
                self.stage(shared, roots, done)
            read_slots = []
            for g in range(self.stores):
                r = np.zeros((self.last_radix, p, THREADS), dtype=complex)
                for t in range(self.last_radix):
                    flat, element, lane = self.output_map(g, t)
                    ok = flat < self.count_out
                    slots = shared_index(element[ok], lane[ok], lanes)
                    read_slots.append(slots)
                    r[t][:, ok] = shared[:, slots] * roots[reverse_bits(t, self.last_bits) * (flat[ok] // lanes)]
                register_butterfly(r)
                for t in range(self.last_radix):
                    flat, element, lane = self.output_map(g, t)
                    col = first + lane
                    if columns:
                        if cross is not None:  # tests may run a bare column pass
                            # exponent < n always (col < n2, element < n1): "% n" never wraps.
                            _, cross_base, low, high = cross
                            exponent = col * element % cross[0]
                            r[t] = r[t] * (high[exponent // cross_base] * low[exponent % cross_base])
                        off = element * other + col
                    else:
                        off = col + other * element
                    valid = (flat < self.count_out) & (col < other)
                    target = (base + off)[valid]
                    dst[target] = r[t][valid]
                    seen[target] = True
                    stored += target.size
            _slots_once(read_slots, size, "output read")
        assert stored == batch * n and seen.all(), "pass must store every output exactly once"


# ---- Plan::Impl + execute ----------------------------------------------------
def plan(n, limit=A100_LIMIT):
    if n & (n - 1) or not (1 << 16) <= n <= (1 << 24):
        raise ValueError("N must be a power of two in [2^16, 2^24]")
    log_n = n.bit_length() - 1
    log_n1 = log_n // 2
    log_n2 = log_n - log_n1
    n1, n2 = 1 << log_n1, 1 << log_n2
    cols, rows = choose_tile(n1, n2, limit), choose_tile(n2, n1, limit)
    return dict(n=n, n1=n1, n2=n2, log_n1=log_n1, log_n2=log_n2, cols=cols, rows=rows,
                radix1=radix_bits(n1, cols), radix2=radix_bits(n2, rows),
                cross_base=1 << ((log_n + 1) // 2))


def fft2(x, limit=A100_LIMIT):
    """Forward DFT of x ((N,) or (batch, N)) via the two-pass kernels' index maps."""
    x = np.asarray(x, dtype=complex)
    single = x.ndim == 1
    x = x.reshape(1, -1) if single else x
    batch, n = x.shape
    pl = plan(n, limit)
    roots1, roots2 = make_table(pl["n1"], pl["n1"], 1), make_table(pl["n2"], pl["n2"], 1)
    low = make_table(n, pl["cross_base"], 1)
    high = make_table(n, n // pl["cross_base"], pl["cross_base"])
    work = np.zeros(batch * n, dtype=complex)
    out = np.zeros(batch * n, dtype=complex)
    TilePass(pl["log_n1"], pl["radix1"], pl["cols"]).run(
        True, x.reshape(-1), work, pl["n2"], batch, roots1, (n, pl["cross_base"], low, high))
    TilePass(pl["log_n2"], pl["radix2"], pl["rows"]).run(
        False, work, out, pl["n1"], batch, roots2)
    out = out.reshape(batch, n)
    return out[0] if single else out
