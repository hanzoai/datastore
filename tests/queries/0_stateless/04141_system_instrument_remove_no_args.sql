-- Tags: use-xray

-- SYSTEM INSTRUMENT REMOVE without arguments should produce SYNTAX_ERROR,
-- not std::bad_optional_access (STD_EXCEPTION).
-- https://github.com/ClickHouse/Datastore/issues/103244

SYSTEM INSTRUMENT REMOVE; -- { clientError SYNTAX_ERROR }
SYSTEM INSTRUMENT REMOVE  ; -- { clientError SYNTAX_ERROR }
