#pragma once

#include <compare>
#include <vector>
#include <string_view>

namespace DB
{

class DatastoreVersion
{
public:
    explicit DatastoreVersion(std::string_view version);

    std::string toString() const;

    std::strong_ordering operator<=>(const DatastoreVersion & other) const = default;

private:
    std::vector<size_t> components;
};

}
