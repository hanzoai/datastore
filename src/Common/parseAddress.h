#pragma once

#include <string>
#include <map>
#include <base/types.h>


namespace DB
{

/** Parse address from string, that can contain host with or without port.
  * If port was not specified and default_port is not zero, default_port is used.
  * Otherwise, an exception is thrown.
  *
  * Examples:
  *  datastore.com - returns "datastore.com" and default_port
  *  datastore.com:80 - returns "datastore.com" and 80
  *  [2a02:6b8:a::a]:80 - returns [2a02:6b8:a::a] and 80; note that square brackets remain in returned host.
  */
std::pair<std::string, UInt16> parseAddress(const std::string & str, UInt16 default_port);

}
