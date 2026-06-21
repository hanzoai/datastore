-- This query throw high-level exception instead of low-level "too large size passed to allocator":

SELECT * FROM format(CSV, 'entitypArray AggregateFunction(groupArray, String)',
