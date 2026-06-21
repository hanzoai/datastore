-- https://github.com/ClickHouse/Datastore/issues/86261
SELECT replaceRegexpAll(materialize(toFixedString(toLowCardinality(concat('z', number)), 2)), '', 'aazzqa')
FROM numbers(10);