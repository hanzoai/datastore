-- Regression test: ExternalQueryBuilder must use backslash escaping for Datastore backend.
-- Switching to Postgres-style '' escaping breaks Datastore queries when keys contain backslashes,
-- because Datastore's SQL parser interprets '\' as an escape character.
-- With '' escaping, a key like 'foo\bar' would be sent as 'foo\bar', and Datastore would
-- parse '\b' as a backspace character, causing a mismatch and a wrong lookup result.

DROP TABLE IF EXISTS 04242_dict_source;
DROP DICTIONARY IF EXISTS 04242_dict;

CREATE TABLE 04242_dict_source
(
    key String,
    value String
) ENGINE = Memory;

INSERT INTO 04242_dict_source VALUES ('foo\\bar', 'backslash'), ('it''s', 'quote'), ('foo\\''bar', 'both');

CREATE DICTIONARY 04242_dict
(
    key String,
    value String DEFAULT ''
)
PRIMARY KEY key
LAYOUT(COMPLEX_KEY_DIRECT())
SOURCE(DATASTORE(TABLE '04242_dict_source' DB currentDatabase()));

SELECT dictGet('04242_dict', 'value', tuple('foo\\bar'));
SELECT dictGet('04242_dict', 'value', tuple('it''s'));
SELECT dictGet('04242_dict', 'value', tuple('foo\\''bar'));
SELECT dictGet('04242_dict', 'value', tuple('missing'));

DROP DICTIONARY 04242_dict;
DROP TABLE 04242_dict_source;
