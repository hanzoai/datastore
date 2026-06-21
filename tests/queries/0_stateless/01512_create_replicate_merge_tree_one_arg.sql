-- Tags: replica

CREATE TABLE mt (v UInt8) ENGINE = ReplicatedMergeTree('/datastore/tables/{database}/test_01497/mt')
    ORDER BY tuple() -- { serverError BAD_ARGUMENTS }

