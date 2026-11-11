#pragma once
#include "runtime.cuh"
#include <map>

namespace measure {
inline std::vector<std::string> split(const std::string& text) {
    std::vector<std::string> out;
    std::istringstream stream(text);
    for (std::string item; std::getline(stream, item, ',');) {
        if (item.empty()) throw std::runtime_error("empty item in list");
        out.push_back(item);
    }
    if (out.empty()) throw std::runtime_error("empty list");
    return out;
}
inline size_t unsigned_value(const std::string& text) {
    if (text.empty() || text.find_first_not_of("0123456789") != std::string::npos)
        throw std::runtime_error("expected a positive integer: " + text);
    size_t used = 0;
    const auto value = std::stoull(text, &used);
    if (used != text.size() || value == 0 || static_cast<unsigned long long>(size_t(value)) != value)
        throw std::runtime_error("integer out of range: " + text);
    return size_t(value);
}
struct Options {
    std::map<std::string, std::string> values;
    Options(int argc, char** argv, const std::vector<std::string>& flags,
            const std::vector<std::string>& args) {
        for (int i = 1; i < argc; ++i) {
            std::string key = argv[i];
            if (values.count(key)) throw std::runtime_error("duplicate option: " + key);
            if (std::find(flags.begin(), flags.end(), key) != flags.end()) values[key] = "1";
            else if (std::find(args.begin(), args.end(), key) != args.end()) {
                if (++i == argc) throw std::runtime_error("missing value: " + key);
                values[key] = argv[i];
            } else throw std::runtime_error("unknown option: " + key);
        }
    }
    bool has(const std::string& key) const { return values.count(key) != 0; }
    std::string get(const std::string& key, const std::string& fallback = "") const {
        const auto it = values.find(key); return it == values.end() ? fallback : it->second;
    }
    int integer(const std::string& key, int fallback) const {
        const auto value = unsigned_value(get(key, std::to_string(fallback)));
        if (value > size_t(std::numeric_limits<int>::max())) throw std::runtime_error(key + " exceeds INT_MAX");
        return int(value);
    }
    int nonnegative_integer(const std::string& key, int fallback = 0) const {
        const auto text = get(key, std::to_string(fallback));
        if (text.empty() || text.find_first_not_of("0123456789") != std::string::npos)
            throw std::runtime_error(key + " requires a nonnegative integer (0 = auto)");
        const auto value = std::stoull(text);
        if (value > static_cast<unsigned long long>(std::numeric_limits<int>::max()))
            throw std::runtime_error(key + " exceeds INT_MAX");
        return int(value);
    }
};
struct Config { size_t n; int batch; std::string batch_mode; };
inline int batch_for(size_t n, const std::string& mode) {
    size_t batch = 0;
    if (mode.size() < 2) throw std::runtime_error("invalid batch mode: " + mode);
    const size_t value = unsigned_value(mode.substr(1));
    if (mode[0] == 'b') batch = value;
    else if (mode[0] == 't' && value < sizeof(size_t) * 8 - 1) {
        const size_t total = size_t(1) << value;
        if (total < n || total % n) throw std::runtime_error("fixed-total batch mode does not divide N");
        batch = total / n;
    } else throw std::runtime_error("batch mode must be b<count> or t<log2-total>");
    if (batch > size_t(std::numeric_limits<int>::max())) throw std::runtime_error("batch exceeds INT_MAX");
    elements(n, int(batch));
    return int(batch);
}
inline std::vector<Config> configs(const Options& opts, const std::string& default_log2 = "16,17,18,19,20,21,22,23,24",
                                   const std::string& default_modes = "b1,b8,t25") {
    std::vector<size_t> sizes;
    if (opts.has("--n")) {
        if (opts.has("--log2")) throw std::runtime_error("choose --n or --log2");
        sizes.push_back(unsigned_value(opts.get("--n")));
    } else for (const auto& item : split(opts.get("--log2", default_log2))) {
        const size_t exponent = unsigned_value(item);
        if (exponent > 30) throw std::runtime_error("log2N must be <= 30 (cuFFT int dimensions)");
        sizes.push_back(size_t(1) << exponent);
    }
    std::vector<Config> out;
    for (size_t n : sizes) {
        if (n > size_t(std::numeric_limits<int>::max())) throw std::runtime_error("N exceeds cuFFT int dimensions");
        for (const auto& mode : split(opts.get("--batch-modes", default_modes))) {
            const int natural_batch = batch_for(n, mode); // Also validates the mode used in output paths.
            const int batch = opts.has("--batch") ? opts.integer("--batch", 1) : natural_batch;
            elements(n, batch);
            out.push_back({n, batch, mode});
        }
    }
    return out;
}
} // namespace measure
