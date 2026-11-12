#pragma once

#include <cstddef>
#include <sstream>
#include <stdexcept>
#include <string>

namespace fft2::detail {

// Host-only planner: FP64 complex storage is two doubles, without CUDA headers.
inline std::size_t shared_bytes(int length, int lanes) {
    return static_cast<std::size_t>(length) * static_cast<std::size_t>(lanes) * (2 * sizeof(double));
}

// Lanes = FFTs of one pass computed by one block. Target a 32 KiB shared tile
// with at least 2 lanes (enough blocks per SM to hide latency); use 1 lane
// when 2 do not fit the device's opt-in shared-memory limit.
inline int choose_tile(int length, int other_length, std::size_t limit) {
    if (shared_bytes(length, 1) > limit) {
        std::ostringstream message;
        message << "fft2: one FFT of length " << length << " needs " << shared_bytes(length, 1)
                << " bytes of shared memory; device opt-in limit is " << limit;
        throw std::runtime_error(message.str());
    }
    if (shared_bytes(length, 2) > limit) { return 1; }
    const std::size_t budget = limit < 32 * 1024 ? limit : std::size_t{32 * 1024};
    int lanes = other_length;
    while (lanes > 2 && shared_bytes(length, lanes) > budget) { lanes /= 2; }
    return lanes;
}

// Radix of the register butterflies, as log2: radix-16 when every thread of a
// 256-thread block has at least one radix-16 butterfly, otherwise radix-8.
inline int radix_bits(int length, int lanes, unsigned int threads) {
    return static_cast<std::size_t>(length) * lanes / 16 >= threads ? 4 : 3;
}

}  // namespace fft2::detail
