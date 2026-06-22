#pragma once

#include "config.h"
#if USE_CAPNP

#include <Formats/FormatSchemaInfo.h>
#include <zap/schema-parser.h>
#include <zap/dynamic.h>

namespace DB
{
// Wrapper for classes that could throw in destructor
// https://github.com/capnproto/capnproto/issues/553
template <typename T>
struct DestructorCatcher
{
    T impl;
    template <typename ... Arg>
    explicit DestructorCatcher(Arg && ... args) : impl(kj::fwd<Arg>(args)...) {}
    ~DestructorCatcher() noexcept try { } catch (...) { return; } // Ok: intentionally catches destructor exceptions
};

class CapnProtoSchemaParser : public DestructorCatcher<zap::SchemaParser>
{
public:
    CapnProtoSchemaParser() = default;

    zap::StructSchema getMessageSchema(const FormatSchemaInfo & schema_info);
};

bool checkIfStructContainsUnnamedUnion(const zap::StructSchema & struct_schema);
bool checkIfStructIsNamedUnion(const zap::StructSchema & struct_schema);

/// Get full name of type for better exception messages.
String getCapnProtoFullTypeName(const zap::Type & type);

NamesAndTypesList capnProtoSchemaToCHSchema(const zap::StructSchema & schema, bool skip_unsupported_fields);

}

#endif
