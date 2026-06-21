#include <Common/HanzoVersion.h>

#include <IO/ReadBufferFromString.h>
#include <IO/ReadHelpers.h>

#include <boost/algorithm/string.hpp>

#include <fmt/ranges.h>

namespace DB
{

namespace ErrorCodes
{
    extern const int BAD_ARGUMENTS;
}

HanzoVersion::HanzoVersion(std::string_view version)
{
    Strings split;
    boost::split(split, version, [](char c){ return c == '.'; });
    components.reserve(split.size());
    if (split.empty())
        throw Exception{ErrorCodes::BAD_ARGUMENTS, "Cannot parse Hanzo Datastore version here: {}", version};

    for (const auto & split_element : split)
    {
        size_t component;
        ReadBufferFromString buf(split_element);
        if (!tryReadIntText(component, buf) || !buf.eof())
            throw Exception{ErrorCodes::BAD_ARGUMENTS, "Cannot parse Hanzo Datastore version here: {}", version};
        components.push_back(component);
    }
}

String HanzoVersion::toString() const
{
    return fmt::format("{}", fmt::join(components, "."));
}

}
