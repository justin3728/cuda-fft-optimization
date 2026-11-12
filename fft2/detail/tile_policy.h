#pragma once

#include <algorithm>
#include <cstddef>
#include <sstream>
#include <stdexcept>
#include <string>

namespace fft2::detail {

// Host-only planner: FP64 complex storage is two doubles, without CUDA headers.
inline std::size_t shared_bytes(int length, int lanes, int padding, int twiddle_mode = 0) {
    return static_cast<std::size_t>(length) * (static_cast<std::size_t>(lanes) + static_cast<std::size_t>(padding)
                                             + static_cast<std::size_t>(twiddle_mode))
           * (2 * sizeof(double));
}

// Plan validates power-of-two dimensions, padding, policy and mode before use.
inline int choose_tile(int length, int other_length, int requested, int padding,
                       std::size_t limit, const char* name, int policy, int twiddle_mode = 0) {
    if (requested < 0) {
        throw std::runtime_error(std::string("fft2: ") + name + " must be nonnegative (0 = automatic)");
    }
    int lanes = requested;
    if (requested == 0) {
        if (policy == 1 && shared_bytes(length, 2, padding, twiddle_mode) > limit) {
            return choose_tile(length, other_length, requested, padding, limit, name, 0, twiddle_mode);
        }
        const std::size_t budget = policy == 1 ? std::min(limit, std::size_t{32 * 1024}) : limit;
        lanes = policy == 1 ? other_length : std::min(8, other_length);
        const int minimum = policy == 1 ? 2 : 0;
        while (lanes > minimum && shared_bytes(length, lanes, padding, twiddle_mode) > budget) {
            lanes /= 2;
        }
        if (policy == 1) { lanes = std::max(2, lanes); }
    }
    if (lanes == 0 || lanes > other_length || shared_bytes(length, lanes, padding, twiddle_mode) > limit) {
        std::ostringstream message;
        message << "fft2: " << name << "=" << requested << " for length=" << length
                << " exceeds the dimension or device opt-in shared-memory limit=" << limit
                << " bytes (padding=" << padding << ", twiddle_mode=" << twiddle_mode << ", one FFT requires "
                << shared_bytes(length, 1, padding, twiddle_mode) << " bytes)";
        throw std::runtime_error(message.str());
    }
    return lanes;
}

}  // namespace fft2::detail
