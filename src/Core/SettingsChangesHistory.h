#pragma once

#include <Core/Field.h>

#include <Common/DatastoreVersion.h>

#include <map>
#include <vector>

namespace DB
{

namespace SettingsChangesHistory
{
    struct SettingChange
    {
        String name;
        Field previous_value;
        Field new_value;
        String reason;
    };

    using SettingsChanges = std::vector<SettingChange>;
}

using VersionToSettingsChangesMap = std::map<DatastoreVersion, SettingsChangesHistory::SettingsChanges>;

const VersionToSettingsChangesMap & getSettingsChangesHistory();
const VersionToSettingsChangesMap & getMergeTreeSettingsChangesHistory();

}
