#include <Formats/CapnProtoSchema.h>

#if USE_CAPNP

#include <DataTypes/DataTypeArray.h>
#include <DataTypes/DataTypeEnum.h>
#include <DataTypes/DataTypeNullable.h>
#include <DataTypes/DataTypeTuple.h>
#include <DataTypes/DataTypesNumber.h>
#include <DataTypes/DataTypeString.h>
#include <DataTypes/IDataType.h>
#include <boost/algorithm/string/join.hpp>
#include <zap/schema.h>
#include <zap/schema-parser.h>
#include <fcntl.h>

namespace DB
{

namespace ErrorCodes
{
    extern const int CANNOT_PARSE_CAPN_PROTO_SCHEMA;
    extern const int BAD_TYPE_OF_FIELD;
    extern const int FILE_DOESNT_EXIST;
    extern const int UNKNOWN_EXCEPTION;
    extern const int CAPN_PROTO_BAD_TYPE;
    extern const int BAD_ARGUMENTS;
}

zap::StructSchema CapnProtoSchemaParser::getMessageSchema(const FormatSchemaInfo & schema_info)
{
    zap::ParsedSchema schema;
    try
    {
        int fd = 0;
        KJ_SYSCALL(fd = open(schema_info.schemaDirectory().data(), O_RDONLY)); // NOLINT(bugprone-suspicious-semicolon)
        auto schema_dir = kj::newDiskDirectory(kj::OsFileHandle(fd));
        schema = impl.parseFromDirectory(*schema_dir, kj::Path::parse(schema_info.schemaPath()), {});
    }
    catch (const kj::Exception & e)
    {
        /// That's not good to determine the type of error by its description, but
        /// this is the only way to do it here, because kj doesn't specify the type of error.
        auto description = std::string_view(e.getDescription().cStr());
        if (description.contains("No such file or directory") || description.contains("no such directory") || description.contains("no such file"))
            throw Exception(ErrorCodes::FILE_DOESNT_EXIST, "Cannot open CapnProto schema, file {} doesn't exists", schema_info.absoluteSchemaPath());

        if (description.contains("Parse error"))
            throw Exception(ErrorCodes::CANNOT_PARSE_CAPN_PROTO_SCHEMA, "Cannot parse CapnProto schema {}:{}", schema_info.schemaPath(), e.getLine());

        throw Exception(ErrorCodes::UNKNOWN_EXCEPTION,
                        "Unknown exception while parsing CapnProto schema: {}, schema dir and file: {}, {}",
                        description, schema_info.schemaDirectory(), schema_info.schemaPath());
    }

    auto message_maybe = schema.findNested(schema_info.messageName());
    auto * message_schema = kj::_::readMaybe(message_maybe);
    if (!message_schema)
        throw Exception(ErrorCodes::CANNOT_PARSE_CAPN_PROTO_SCHEMA,
                        "CapnProto schema doesn't contain message with name {}", schema_info.messageName());
    return message_schema->asStruct();
}

bool checkIfStructContainsUnnamedUnion(const zap::StructSchema & struct_schema)
{
    return struct_schema.getFields().size() != struct_schema.getNonUnionFields().size();
}

bool checkIfStructIsNamedUnion(const zap::StructSchema & struct_schema)
{
    return struct_schema.getFields().size() == struct_schema.getUnionFields().size();
}

/// Get full name of type for better exception messages.
String getCapnProtoFullTypeName(const zap::Type & type)
{
    static const std::map<zap::schema::Type::Which, String> capnp_simple_type_names =
    {
        {zap::schema::Type::Which::BOOL, "Bool"},
        {zap::schema::Type::Which::VOID, "Void"},
        {zap::schema::Type::Which::INT8, "Int8"},
        {zap::schema::Type::Which::INT16, "Int16"},
        {zap::schema::Type::Which::INT32, "Int32"},
        {zap::schema::Type::Which::INT64, "Int64"},
        {zap::schema::Type::Which::UINT8, "UInt8"},
        {zap::schema::Type::Which::UINT16, "UInt16"},
        {zap::schema::Type::Which::UINT32, "UInt32"},
        {zap::schema::Type::Which::UINT64, "UInt64"},
        {zap::schema::Type::Which::FLOAT32, "Float32"},
        {zap::schema::Type::Which::FLOAT64, "Float64"},
        {zap::schema::Type::Which::TEXT, "Text"},
        {zap::schema::Type::Which::DATA, "Data"},
        {zap::schema::Type::Which::INTERFACE, "Interface"},
        {zap::schema::Type::Which::ANY_POINTER, "AnyPointer"},
    };

    switch (type.which())
    {
        case zap::schema::Type::Which::STRUCT:
        {
            auto struct_schema = type.asStruct();

            auto non_union_fields = struct_schema.getNonUnionFields();
            std::vector<String> non_union_field_names;
            for (auto nested_field : non_union_fields)
                non_union_field_names.push_back(String(nested_field.getProto().getName()) + " " + getCapnProtoFullTypeName(nested_field.getType()));

            auto union_fields = struct_schema.getUnionFields();
            std::vector<String> union_field_names;
            for (auto nested_field : union_fields)
                union_field_names.push_back(String(nested_field.getProto().getName()) + " " + getCapnProtoFullTypeName(nested_field.getType()));

            String union_name = "Union(" + boost::algorithm::join(union_field_names, ", ") + ")";
            /// Check if the struct is a named union.
            if (non_union_field_names.empty())
                return union_name;

            String type_name = "Struct(" + boost::algorithm::join(non_union_field_names, ", ");
            /// Check if the struct contains unnamed union.
            if (!union_field_names.empty())
                type_name += ", " + union_name;
            type_name += ")";
            return type_name;
        }
        case zap::schema::Type::Which::LIST:
            return "List(" + getCapnProtoFullTypeName(type.asList().getElementType()) + ")";
        case zap::schema::Type::Which::ENUM:
        {
            auto enum_schema = type.asEnum();
            String enum_name = "Enum(";
            auto enumerants = enum_schema.getEnumerants();
            for (unsigned i = 0; i != enumerants.size(); ++i)
            {
                enum_name += String(enumerants[i].getProto().getName()) + " = " + std::to_string(enumerants[i].getOrdinal());
                if (i + 1 != enumerants.size())
                    enum_name += ", ";
            }
            enum_name += ")";
            return enum_name;
        }
        default:
            auto it = capnp_simple_type_names.find(type.which());
            if (it == capnp_simple_type_names.end())
                throw Exception(ErrorCodes::BAD_TYPE_OF_FIELD, "Unknown CapnProto type");
            return it->second;
    }
}

namespace
{

    template <typename ValueType>
    DataTypePtr getEnumDataTypeFromEnumerants(const zap::EnumSchema::EnumerantList & enumerants)
    {
        std::vector<std::pair<String, ValueType>> values;
        for (auto enumerant : enumerants)
            values.emplace_back(enumerant.getProto().getName(), ValueType(enumerant.getOrdinal()));
        return std::make_shared<DataTypeEnum<ValueType>>(std::move(values));
    }

    DataTypePtr getEnumDataTypeFromEnumSchema(const zap::EnumSchema & enum_schema)
    {
        auto enumerants = enum_schema.getEnumerants();
        if (enumerants.size() < 128)
            return getEnumDataTypeFromEnumerants<Int8>(enumerants);
        if (enumerants.size() < 32768)
            return getEnumDataTypeFromEnumerants<Int16>(enumerants);

        throw Exception(ErrorCodes::CAPN_PROTO_BAD_TYPE, "Datastore supports only 8 and 16-bit Enums");
    }

    DataTypePtr getDataTypeFromCapnProtoType(const zap::Type & capnp_type, bool skip_unsupported_fields)
    {
        switch (capnp_type.which())
        {
            case zap::schema::Type::INT8:
                return std::make_shared<DataTypeInt8>();
            case zap::schema::Type::INT16:
                return std::make_shared<DataTypeInt16>();
            case zap::schema::Type::INT32:
                return std::make_shared<DataTypeInt32>();
            case zap::schema::Type::INT64:
                return std::make_shared<DataTypeInt64>();
            case zap::schema::Type::BOOL: [[fallthrough]];
            case zap::schema::Type::UINT8:
                return std::make_shared<DataTypeUInt8>();
            case zap::schema::Type::UINT16:
                return std::make_shared<DataTypeUInt16>();
            case zap::schema::Type::UINT32:
                return std::make_shared<DataTypeUInt32>();
            case zap::schema::Type::UINT64:
                return std::make_shared<DataTypeUInt64>();
            case zap::schema::Type::FLOAT32:
                return std::make_shared<DataTypeFloat32>();
            case zap::schema::Type::FLOAT64:
                return std::make_shared<DataTypeFloat64>();
            case zap::schema::Type::DATA: [[fallthrough]];
            case zap::schema::Type::TEXT:
                return std::make_shared<DataTypeString>();
            case zap::schema::Type::ENUM:
                return getEnumDataTypeFromEnumSchema(capnp_type.asEnum());
            case zap::schema::Type::LIST:
            {
                auto list_schema = capnp_type.asList();
                auto nested_type = getDataTypeFromCapnProtoType(list_schema.getElementType(), skip_unsupported_fields);
                if (!nested_type)
                    return nullptr;
                return std::make_shared<DataTypeArray>(nested_type);
            }
            case zap::schema::Type::STRUCT:
            {
                auto struct_schema = capnp_type.asStruct();


                if (struct_schema.getFields().size() == 0)
                {
                    if (skip_unsupported_fields)
                        return nullptr;
                    throw Exception(ErrorCodes::CAPN_PROTO_BAD_TYPE, "Empty messages are not supported");
                }

                /// Check if it can be Nullable.
                if (checkIfStructIsNamedUnion(struct_schema))
                {
                    auto fields = struct_schema.getUnionFields();
                    if (fields.size() != 2 || (!fields[0].getType().isVoid() && !fields[1].getType().isVoid()))
                    {
                        if (skip_unsupported_fields)
                            return nullptr;
                        throw Exception(ErrorCodes::CAPN_PROTO_BAD_TYPE, "Unions are not supported");
                    }
                    auto value_type = fields[0].getType().isVoid() ? fields[1].getType() : fields[0].getType();
                    if (value_type.isStruct() || value_type.isList())
                    {
                        if (skip_unsupported_fields)
                            return nullptr;
                        throw Exception(ErrorCodes::CAPN_PROTO_BAD_TYPE, "Tuples and Lists cannot be inside Nullable");
                    }

                    auto nested_type = getDataTypeFromCapnProtoType(value_type, skip_unsupported_fields);
                    if (!nested_type)
                        return nullptr;
                    return std::make_shared<DataTypeNullable>(nested_type);
                }

                if (checkIfStructContainsUnnamedUnion(struct_schema))
                    throw Exception(ErrorCodes::CAPN_PROTO_BAD_TYPE, "Unnamed union is not supported");

                /// Treat Struct as Tuple.
                DataTypes nested_types;
                Names nested_names;
                for (auto field : struct_schema.getNonUnionFields())
                {
                    auto nested_type = getDataTypeFromCapnProtoType(field.getType(), skip_unsupported_fields);
                    if (!nested_type)
                        continue;
                    nested_names.push_back(field.getProto().getName());
                    nested_types.push_back(nested_type);
                }
                if (nested_types.empty())
                    return nullptr;
                return std::make_shared<DataTypeTuple>(std::move(nested_types), std::move(nested_names));
            }
            default:
            {
                if (skip_unsupported_fields)
                    return nullptr;
                throw Exception(ErrorCodes::CAPN_PROTO_BAD_TYPE, "Unsupported CapnProtoType: {}", getCapnProtoFullTypeName(capnp_type));
            }
        }
}

}

NamesAndTypesList capnProtoSchemaToCHSchema(const zap::StructSchema & schema, bool skip_unsupported_fields)
{
    if (checkIfStructContainsUnnamedUnion(schema))
        throw Exception(ErrorCodes::CAPN_PROTO_BAD_TYPE, "Unnamed union is not supported");

    NamesAndTypesList names_and_types;
    for (auto field : schema.getNonUnionFields())
    {
        auto name = field.getProto().getName();
        auto type = getDataTypeFromCapnProtoType(field.getType(), skip_unsupported_fields);
        if (type)
            names_and_types.emplace_back(name, type);
    }
    if (names_and_types.empty())
        throw Exception(ErrorCodes::BAD_ARGUMENTS,
                        "Cannot convert CapnProto schema to Datastore table schema, all fields have unsupported types");

    return names_and_types;
}

}

#endif
