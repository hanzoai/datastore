-- Representative OLAP workload for PGO profile collection.
-- Exercises the hot query paths: MergeTree insert/scan, aggregation, sort,
-- top-k, filter, join, window, array, subquery, string/date functions.
CREATE TABLE pgo_bench (id UInt64, user_id UInt32, ts DateTime, value Float64, category LowCardinality(String), tags Array(String)) ENGINE = MergeTree ORDER BY (category, ts);
INSERT INTO pgo_bench SELECT number, rand() % 100000, now() - (rand() % 2592000), rand() / 4e6, ['ads','web','api','iot'][(number % 4) + 1], [toString(number % 7), toString(number % 13)] FROM numbers(10000000);
SELECT category, count(), avg(value), sum(value), max(value), quantile(0.9)(value) FROM pgo_bench GROUP BY category;
SELECT user_id, sum(value) s FROM pgo_bench GROUP BY user_id ORDER BY s DESC LIMIT 20;
SELECT count() FROM pgo_bench WHERE value > 0.5 AND category = 'api';
SELECT category, toStartOfHour(ts) h, count() FROM pgo_bench GROUP BY category, h ORDER BY category, h LIMIT 100;
SELECT a.category, count() FROM pgo_bench a JOIN (SELECT DISTINCT category FROM pgo_bench) b ON a.category = b.category GROUP BY a.category;
SELECT user_id, value, sum(value) OVER (PARTITION BY category ORDER BY ts) FROM pgo_bench LIMIT 1000;
SELECT arrayJoin(tags) t, count() FROM pgo_bench GROUP BY t ORDER BY count() DESC;
SELECT category, uniqExact(user_id), median(value) FROM pgo_bench GROUP BY category;
SELECT count() FROM pgo_bench WHERE id IN (SELECT id FROM pgo_bench WHERE value > 0.99);
SELECT toString(id), lower(category), value * 2, ts + INTERVAL 1 HOUR FROM pgo_bench ORDER BY id LIMIT 5000;
DROP TABLE pgo_bench;
