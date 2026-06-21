#pragma once

#include <compare>
#include <vector>
#include <string_view>

namespace DB
{

class HanzoVersion
{
public:
    explicit HanzoVersion(std::string_view version);

    std::string toString() const;

    std::strong_ordering operator<=>(const HanzoVersion & other) const = default;

private:
    std::vector<size_t> components;
};

// Backward compatibility alias
using ClickHouseVersion = HanzoVersion;

}
