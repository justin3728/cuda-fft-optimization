#include "detail/tile_policy.h"

#include <cassert>
#include <iostream>
#include <stdexcept>
#include <string>

namespace {

void expect_resource_error(int length, int other, int requested, int padding,
                           std::size_t limit, int policy) {
    try {
        (void)fft2::detail::choose_tile(length, other, requested, padding, limit, "tile_cols", policy);
    } catch (const std::runtime_error& error) {
        assert(std::string(error.what()).find("device opt-in shared-memory limit=") != std::string::npos);
        return;
    }
    throw std::runtime_error("expected tile resource error");
}

}  // namespace

int main() {
    struct Case { int length; int lanes[3]; };
    const Case cases[] = {
        {256, {8, 4, 4}}, {512, {4, 2, 2}}, {1024, {2, 2, 2}},
        {2048, {2, 2, 2}}, {4096, {2, 2, 2}},
    };
    for (const std::size_t limit : {99 * 1024, 163 * 1024}) {
        for (const auto& test : cases) {
            for (int padding = 0; padding <= 2; ++padding) {
                int legacy = -1;
                try {
                    legacy = fft2::detail::choose_tile(test.length, 256, 0, padding, limit,
                                                       "tile_cols", 0);
                } catch (const std::runtime_error&) {}
                const bool fallback = fft2::detail::shared_bytes(test.length, 2, padding) > limit;
                const int expected = fallback ? legacy : test.lanes[padding];
                try {
                    const int lanes = fft2::detail::choose_tile(test.length, 256, 0, padding, limit,
                                                               "tile_cols", 1);
                    assert(lanes == expected);
                    assert(legacy > 0);
                    assert(fft2::detail::shared_bytes(test.length, lanes, padding) <= limit);
                } catch (const std::runtime_error&) {
                    // Policy 1 must never error where policy 0 succeeds.
                    assert(legacy < 0);
                    expect_resource_error(test.length, 256, 0, padding, limit, 1);
                }
            }
        }
    }
    // The other dimension bounds the tile; policy 1 has no legacy eight-lane cap.
    assert(fft2::detail::choose_tile(256, 2, 0, 0, 163 * 1024, "tile_cols", 1) == 2);
    assert(fft2::detail::choose_tile(64, 256, 0, 0, 163 * 1024, "tile_cols", 1) == 32);
    for (int policy : {0, 1}) {
        assert(fft2::detail::choose_tile(512, 256, 3, 1, 163 * 1024, "tile_cols", policy) == 3);
        assert(fft2::detail::choose_tile(4096, 256, 1, 0, 99 * 1024, "tile_rows", policy) == 1);
        expect_resource_error(4096, 256, 3, 0, 163 * 1024, policy);
        expect_resource_error(256, 2, 3, 0, 163 * 1024, policy);
    }
    assert(fft2::detail::choose_tile(4096, 256, 0, 0, 99 * 1024, "tile_rows", 0) == 1);
    assert(fft2::detail::choose_tile(4096, 256, 0, 1, 163 * 1024, "tile_rows", 1) == 1);
    assert(fft2::detail::choose_tile(2048, 256, 0, 2, 99 * 1024, "tile_rows", 1) == 1);
    assert(fft2::detail::choose_tile(1024, 256, 0, 0, 32 * 1024 - 1, "tile_rows", 1) == 1);
    std::cout << "tile policy CPU checks PASS\n";
}
