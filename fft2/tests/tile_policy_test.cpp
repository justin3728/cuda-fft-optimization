#include "detail/tile_policy.h"

#include <cstdio>
#include <stdexcept>

namespace {

int failures = 0;

void expect(bool condition, const char* what, int length, int value) {
    if (!condition) {
        std::printf("FAIL %s length=%d value=%d\n", what, length, value);
        ++failures;
    }
}

}  // namespace

int main() {
    constexpr std::size_t a100 = 163 * 1024;  // opt-in shared-memory limit per block
    constexpr std::size_t l4 = 99 * 1024;
    struct Case { int length; int a100_lanes; int l4_lanes; int a100_radix_bits; };
    // other_length = 4096 (the largest partner dimension) leaves the tile
    // limited only by the 32 KiB target, the 2-lane minimum and the device limit.
    const Case cases[] = {
        // radix-16 only when length*lanes/16 >= 256, i.e. every thread has a butterfly.
        {256, 8, 8, 3},
        {512, 4, 4, 3},
        {1024, 2, 2, 3},
        {2048, 2, 2, 4},
        {4096, 2, 1, 4},
    };
    for (const auto& test : cases) {
        const int lanes = fft2::detail::choose_tile(test.length, 4096, a100);
        expect(lanes == test.a100_lanes, "A100 lanes", test.length, lanes);
        expect(fft2::detail::choose_tile(test.length, 4096, l4) == test.l4_lanes, "L4 lanes", test.length,
               fft2::detail::choose_tile(test.length, 4096, l4));
        expect(fft2::detail::shared_bytes(test.length, lanes) <= a100, "tile fits", test.length, lanes);
        const int bits = fft2::detail::radix_bits(test.length, lanes, 256);
        expect(bits == test.a100_radix_bits, "A100 radix bits", test.length, bits);
    }
    // A pass never uses more lanes than the partner dimension provides.
    expect(fft2::detail::choose_tile(256, 4, a100) == 4, "partner bound", 256, 4);
    try {
        (void)fft2::detail::choose_tile(4096, 4096, 32 * 1024);
        expect(false, "one FFT above limit must throw", 4096, 0);
    } catch (const std::runtime_error&) {
    }
    std::printf(failures == 0 ? "tile_policy_test PASS\n" : "tile_policy_test FAIL\n");
    return failures == 0 ? 0 : 1;
}
