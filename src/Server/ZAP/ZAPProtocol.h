/*
 * ZAPProtocol.h — ZAP binary protocol utilities for hanzo/datastore.
 *
 * Provides constants, parsers, and builders for the ZAP wire format.
 */
#pragma once

#include <cstdint>
#include <cstring>
#include <string>
#include <string_view>
#include <vector>
#include <memory>

namespace DB::ZAP
{

constexpr char MAGIC[] = "ZAP\0";
constexpr size_t MAGIC_LEN = 4;
constexpr uint16_t VERSION = 1;
constexpr size_t HEADER_SIZE = 16;

// Message type for Datastore operations
constexpr uint16_t MSG_DATASTORE = 302;

// Field offsets
constexpr int FIELD_PATH = 4;
constexpr int FIELD_BODY = 12;
constexpr int RESP_STATUS = 0;
constexpr int RESP_BODY = 4;

inline uint16_t readU16LE(const uint8_t * buf) {
    return static_cast<uint16_t>(buf[0]) | (static_cast<uint16_t>(buf[1]) << 8);
}

inline uint32_t readU32LE(const uint8_t * buf) {
    return static_cast<uint32_t>(buf[0]) | (static_cast<uint32_t>(buf[1]) << 8)
         | (static_cast<uint32_t>(buf[2]) << 16) | (static_cast<uint32_t>(buf[3]) << 24);
}

inline void writeU16LE(uint8_t * buf, uint16_t val) {
    buf[0] = val & 0xFF; buf[1] = (val >> 8) & 0xFF;
}

inline void writeU32LE(uint8_t * buf, uint32_t val) {
    buf[0] = val & 0xFF; buf[1] = (val >> 8) & 0xFF;
    buf[2] = (val >> 16) & 0xFF; buf[3] = (val >> 24) & 0xFF;
}

struct Header
{
    uint16_t version = 0;
    uint16_t flags = 0;
    uint32_t root_offset = 0;
    uint32_t size = 0;
    uint16_t msg_type = 0;

    bool parse(const uint8_t * data, size_t len)
    {
        if (len < HEADER_SIZE) return false;
        if (std::memcmp(data, MAGIC, MAGIC_LEN) != 0) return false;
        version = readU16LE(data + 4);
        if (version != VERSION) return false;
        flags = readU16LE(data + 6);
        root_offset = readU32LE(data + 8);
        size = readU32LE(data + 12);
        msg_type = flags;
        return size <= len;
    }
};

// Read a Text field from a ZAP object (zero-copy view)
inline std::string_view readText(const uint8_t * data, size_t data_len,
                                  uint32_t obj_offset, int field_offset)
{
    uint32_t pos = obj_offset + field_offset;
    if (pos + 8 > data_len) return {};
    auto rel = static_cast<int32_t>(readU32LE(data + pos));
    if (rel == 0) return {};
    uint32_t length = readU32LE(data + pos + 4);
    uint32_t abs_pos = pos + rel;
    if (abs_pos + length > data_len) return {};
    return {reinterpret_cast<const char *>(data + abs_pos), length};
}

// Read a Bytes field
inline std::string_view readBytes(const uint8_t * data, size_t data_len,
                                   uint32_t obj_offset, int field_offset)
{
    return readText(data, data_len, obj_offset, field_offset);
}

// Build a ZAP response message
class ResponseBuilder
{
public:
    std::vector<uint8_t> build(uint32_t status, std::string_view body)
    {
        size_t total = (HEADER_SIZE + 20 + body.size() + 7) & ~7ULL;
        std::vector<uint8_t> buf(total, 0);

        std::memcpy(buf.data(), MAGIC, MAGIC_LEN);
        writeU16LE(buf.data() + 4, VERSION);
        writeU32LE(buf.data() + 8, HEADER_SIZE);  // root offset
        writeU32LE(buf.data() + 12, static_cast<uint32_t>(total));

        uint32_t root = HEADER_SIZE;
        writeU32LE(buf.data() + root + RESP_STATUS, status);

        auto rel = static_cast<int32_t>(20 - RESP_BODY);
        writeU32LE(buf.data() + root + RESP_BODY, static_cast<uint32_t>(rel));
        writeU32LE(buf.data() + root + RESP_BODY + 4, static_cast<uint32_t>(body.size()));

        if (!body.empty())
            std::memcpy(buf.data() + root + 20, body.data(), body.size());

        return buf;
    }
};

} // namespace DB::ZAP
