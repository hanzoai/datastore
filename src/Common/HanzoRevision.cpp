#include <Common/HanzoRevision.h>
#include <Common/config_version.h>

namespace HanzoRevision
{
    unsigned getVersionRevision() { return VERSION_REVISION; }
    unsigned getVersionInteger() { return VERSION_INTEGER; }
}
