#include <Common/DatastoreRevision.h>
#include <Common/config_version.h>

namespace DatastoreRevision
{
    unsigned getVersionRevision() { return VERSION_REVISION; }
    unsigned getVersionInteger() { return VERSION_INTEGER; }
}
