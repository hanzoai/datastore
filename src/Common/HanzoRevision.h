#pragma once

namespace HanzoRevision
{
    unsigned getVersionRevision();
    unsigned getVersionInteger();
}

// Backward compatibility alias
namespace DatastoreRevision = HanzoRevision;
