import numpy as np
import pytest

import model
from model import (A100_LIMIT, L4_LIMIT, THREADS, TilePass, choose_tile, fft2, make_table,
                   plan, radix_bits, shared_bytes)

DEFAULT_LIMIT = 48 * 1024  # no opt-in


def random_signal(batch, n, seed):
    rng = np.random.default_rng(seed)
    return rng.standard_normal((batch, n)) + 1j * rng.standard_normal((batch, n))


def rel_l2(a, b):
    return np.linalg.norm(a - b) / np.linalg.norm(b)


# ---- end to end vs numpy -------------------------------------------------------
@pytest.mark.parametrize("batch", [1, 3])
@pytest.mark.parametrize("log_n", range(16, 21))
def test_fft2_matches_numpy(log_n, batch):
    x = random_signal(batch, 1 << log_n, log_n * 10 + batch)
    assert rel_l2(fft2(x), np.fft.fft(x, axis=1)) <= 1e-12


@pytest.mark.slow
@pytest.mark.parametrize("log_n", [22, 24])
def test_fft2_matches_numpy_large(log_n):
    x = random_signal(1, 1 << log_n, log_n)
    assert rel_l2(fft2(x[0]), np.fft.fft(x[0])) <= 1e-12


def test_fft2_single_vector_and_impulse():
    n = 1 << 16
    x = np.zeros(n, dtype=complex)
    x[5] = 1
    expected = np.exp(-2j * np.pi * 5 * np.arange(n) / n)
    assert rel_l2(fft2(x), expected) <= 1e-12


@pytest.mark.parametrize("log_n,limit", [(21, DEFAULT_LIMIT), (21, L4_LIMIT), (22, DEFAULT_LIMIT)])
def test_fft2_other_devices(log_n, limit):
    # 48 KiB: length 2048 gets Lanes=1 with radix 8 (stages 3+3+3+2). Lanes=1 with
    # radix 16 (L4, length 4096) is in the slow test below.
    x = random_signal(1, 1 << log_n, 7)
    assert rel_l2(fft2(x[0], limit), np.fft.fft(x[0])) <= 1e-12


@pytest.mark.slow
def test_fft2_l4_single_lane_4096():
    x = random_signal(1, 1 << 23, 8)[0]
    pl = plan(1 << 23, L4_LIMIT)
    assert (pl["n2"], pl["rows"], pl["radix2"]) == (4096, 1, 4)
    assert rel_l2(fft2(x, L4_LIMIT), np.fft.fft(x)) <= 1e-12


def test_plan_rejects_bad_sizes():
    for n in [1 << 15, 1 << 25, (1 << 16) + 1]:
        with pytest.raises(ValueError):
            plan(n)


# ---- every stage plan: a single tile pass vs numpy (no cross twiddle) -------------
@pytest.mark.parametrize("lanes", [1, 2, 4, 8])
@pytest.mark.parametrize("bits", [3, 4])
@pytest.mark.parametrize("log_length", range(8, 13))
@pytest.mark.parametrize("columns", [True, False])
def test_tile_pass_alone(log_length, bits, lanes, columns):
    tile = TilePass(log_length, bits, lanes)
    length, other, batch = tile.length, 2 * lanes, 2
    roots = make_table(length, length, 1)
    x = random_signal(batch, length * other, log_length)
    out = np.zeros(batch * length * other, dtype=complex)
    tile.run(columns, x.reshape(-1), out, other, batch, roots)
    out = out.reshape(batch, length, other)
    if columns:  # x is length x other row-major; FFT down each column, stored in place
        expected = np.fft.fft(x.reshape(batch, length, other), axis=1)
    else:        # x is other x length; FFT of each row, stored transposed
        expected = np.fft.fft(x.reshape(batch, other, length), axis=2).transpose(0, 2, 1)
    assert rel_l2(out, expected) <= 1e-13


def test_stage_plans():
    # (log_length, bits) -> radix of each stage: register, shared..., register
    t = TilePass(11, 4, 2)
    assert (t.bits, t.last_bits, list(t.shared_stage_starts())) == (4, 3, [4])
    t = TilePass(8, 4, 8)
    assert (t.last_bits, list(t.shared_stage_starts())) == (4, [])
    t = TilePass(12, 3, 1)  # 3+3+3+3
    assert (t.last_bits, list(t.shared_stage_starts())) == (3, [3, 6])
    t = TilePass(10, 3, 2)  # 3+3+3+1
    assert (t.last_bits, list(t.shared_stage_starts())) == (1, [3, 6])


def test_butterfly_is_dft_of_bit_reversed_input():
    for bits in (1, 2, 3, 4):
        r = 1 << bits
        x = np.random.default_rng(bits).standard_normal(r) + 0j
        v = np.array([x[model.reverse_bits(t, bits)] for t in range(r)])[:, None]
        model.register_butterfly(v)
        assert np.allclose(v[:, 0], np.fft.fft(x), atol=1e-14)


def test_twiddle_tables_and_no_wrap():
    t = make_table(1 << 20, 1 << 10, 1 << 10)
    assert np.allclose(t, np.exp(-2j * np.pi * (np.arange(1 << 10) * (1 << 10)) / (1 << 20)), atol=1e-15)
    # The kernel's "% n" on the cross exponent never wraps: column < n2, k1 < n1.
    for log_n in range(16, 25):
        pl = plan(1 << log_n)
        assert (pl["n2"] - 1) * (pl["n1"] - 1) < pl["n"]
        assert pl["n1"] * pl["n2"] == pl["n"]
        # high table index (exponent / cross_base) stays inside its n / cross_base entries.
        assert (pl["n"] - 1) // pl["cross_base"] < pl["n"] // pl["cross_base"]


# ---- tile policy tables (derived by hand from tile_policy.h) -----------------------
# choose_tile: 16*length bytes per lane. Start at lanes=other and halve while lanes > 2 and
# bytes > min(limit, 32 KiB): 256 -> 8 (8*4 KiB = 32 KiB), 512 -> 4, 1024 -> 2 (2*16 KiB),
# 2048 and 4096 never fit 32 KiB with 2 lanes, so they stop at the floor of 2.
# The floor of 2 lanes needs 2*16*length bytes: 64 KiB (2048), 128 KiB (4096). 128 KiB fits the
# A100 limit (163 KiB) but not L4 (99 KiB), where 4096 drops to 1 lane. Under the 48 KiB default,
# 2048 (64 KiB for 2 lanes) also drops to 1 lane and 4096 (64 KiB for even one lane) is rejected.
A100_LANES = {256: 8, 512: 4, 1024: 2, 2048: 2, 4096: 2}
L4_LANES = {256: 8, 512: 4, 1024: 2, 2048: 2, 4096: 1}
DEFAULT_LANES = {256: 8, 512: 4, 1024: 2, 2048: 1}
# radix_bits: radix 16 iff length*lanes/16 >= 256, i.e. length*lanes >= 4096.
# 256*8=2048, 512*4=2048, 1024*2=2048, 2048*1=2048 -> radix 8; 2048*2=4096, 4096*1=4096,
# 4096*2=8192 -> radix 16.
BITS = {(256, 8): 3, (512, 4): 3, (1024, 2): 3, (2048, 1): 3, (2048, 2): 4, (4096, 1): 4, (4096, 2): 4}


@pytest.mark.parametrize("limit,table", [(A100_LIMIT, A100_LANES), (L4_LIMIT, L4_LANES),
                                         (DEFAULT_LIMIT, DEFAULT_LANES)])
def test_choose_tile_tables(limit, table):
    assert limit in (166912, 101376, 49152)
    for length, lanes in table.items():
        for other in (256, 512, 1024, 2048, 4096):  # every production pairing
            assert choose_tile(length, other, limit) == lanes, (length, other)
        assert shared_bytes(length, lanes) <= limit
    if limit == DEFAULT_LIMIT:
        with pytest.raises(ValueError):
            choose_tile(4096, 4096, limit)


def test_radix_bits_table():
    for (length, lanes), bits in BITS.items():
        assert radix_bits(length, lanes, THREADS) == bits, (length, lanes)


def test_production_plans():
    for limit in (A100_LIMIT, L4_LIMIT):
        for log_n in range(16, 25):
            pl = plan(1 << log_n, limit)
            for length, lanes, bits in ((pl["n1"], pl["cols"], pl["radix1"]),
                                        (pl["n2"], pl["rows"], pl["radix2"])):
                assert shared_bytes(length, lanes) <= limit
                assert bits == radix_bits(length, lanes)
                t = TilePass(length.bit_length() - 1, bits, lanes)
                # every thread of the first pass has work when radix 16 was chosen
                assert t.count_in >= THREADS or bits == 3


# ---- load/store coalescing the C++ relies on ---------------------------------------
def production_tiles():
    seen = set()
    for limit in (A100_LIMIT, L4_LIMIT):
        for log_n in range(16, 25):
            pl = plan(1 << log_n, limit)
            seen.add((pl["log_n1"], pl["radix1"], pl["cols"], pl["n2"]))   # pass 1: other = n2
            seen.add((pl["log_n2"], pl["radix2"], pl["rows"], pl["n1"]))   # pass 2: other = n1
    return sorted(seen)


@pytest.mark.parametrize("log_length,bits,lanes,other", production_tiles())
def test_loads_coalesce(log_length, bits, lanes, other):
    tile = TilePass(log_length, bits, lanes)
    length, first = tile.length, lanes  # block 1
    for g in range(tile.loads):
        for t in range(tile.first_radix):
            # Pass 2 (rows): offset = (first + lane) * length + element. Every warp is fully
            # active or idle, and its 32 threads read 32 consecutive complex values.
            flat, el, lane = tile.input_map(False, g, t)
            off = (first + lane) * length + el
            ok = (flat < tile.count_in).reshape(-1, 32)
            for w, wok in zip(off.reshape(-1, 32), ok):
                assert wok.all() or not wok.any()
                if wok.all():
                    assert (np.diff(w) == 1).all()
            # Pass 1 (columns): offset = element * other + first + lane.
            flat, el, lane = tile.input_map(True, g, t)
            col = (el * other + first + lane)[flat < tile.count_in]
            if lanes == 1:
                # No coalescing: neighbouring threads are one whole row (other values) apart.
                assert (np.diff(col) == other).all()
            else:
                # Runs of `lanes` threads read `lanes` adjacent columns; the next run is another row.
                runs = col.reshape(-1, lanes)
                assert (np.diff(runs, axis=1) == 1).all()
                assert (np.diff(runs[:, 0]) == other).all()


@pytest.mark.parametrize("log_length,bits,lanes,other", production_tiles())
def test_stores_are_runs_of_lanes(log_length, bits, lanes, other):
    # Both passes store element * other + first + lane (pass 1) or first + lane + other * element
    # (pass 2): runs of `lanes` consecutive values, runs one `other` apart.
    tile = TilePass(log_length, bits, lanes)
    for g in range(tile.stores):
        for t in range(tile.last_radix):
            flat, el, lane = tile.output_map(g, t)
            off = (el * other + lane)[flat < tile.count_out].reshape(-1, lanes)
            assert (np.diff(off, axis=1) == 1).all()
            if lanes < 32:
                assert (np.diff(off[:, 0]) == other).all()
