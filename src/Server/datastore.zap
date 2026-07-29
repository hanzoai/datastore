@0xd92a630ebcf0c250;

# Hanzo Datastore — native ZAP (Zero-copy Application Protocol) data plane.
#
# Canonical service-to-service ingest/query interface. The zap-rpc server on the
# ZAP port (default 9999) serves an implementation of `Datastore` as its bootstrap
# capability (see src/Server/ZapServer.cpp). Every method dispatches to the
# in-process query engine (Interpreters/executeQuery) using the same Session +
# AccessControl path as the HTTP and native TCP interfaces.
#
# Envelope conventions follow the canonical ZAP schema in
# ~/work/hanzo/zap/rust/schema/zap.zap (Push/Resolve/Reject over zap-rpc): here a
# promise-pipelined typed capability replaces the hand-rolled Push/Resolve
# envelope — the C++/kj-native form of the same protocol.

$import "/zap/c++.zap".namespace("DB::Zap");

interface Datastore {
  # Bootstrap capability of the ZAP data plane.

  insert @0 (database :Text, table :Text, format :Text, rows :Data)
         -> (written :UInt64);
  # Append `rows` (encoded in `format` — e.g. "JSONEachRow", "RowBinary",
  # "Native") to `database`.`table`. Equivalent to
  #   INSERT INTO `database`.`table` FORMAT <format> <rows>
  # Returns the number of rows written.

  execQuery @1 (sql :Text, format :Text)
            -> (result :Data);
  # Execute `sql` and return the result set serialized in `format` (e.g.
  # "JSONEachRow", "Native", "RowBinary"). For statements that produce no result
  # set (DDL, INSERT ... SELECT), `result` is empty.
}
