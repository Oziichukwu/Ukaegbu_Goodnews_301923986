-- Portfolio 2: index benchmark on a separate 50,000-row performance table.
-- Run with psql after the Portfolio 1 schema (it only reads the column types from it).
-- The generated rows are for measuring two lookups, not complete case records,
-- and the Portfolio 1 tables are not changed.
\timing off

CREATE SCHEMA query_lab;
CREATE TABLE query_lab."payment" (
  "lab_row_id" bigint PRIMARY KEY,
  "account_id" bigint NOT NULL,
  "requested_at" timestamptz NOT NULL,
  "amount" numeric(18,2) NOT NULL
);
-- 500 accounts with 100 payments each; requested_at is spread over every minute of
-- 2025 in a scrambled order (7919 is prime and shares no factor with 525,600 minutes).
INSERT INTO query_lab."payment" ("lab_row_id", "account_id", "requested_at", "amount")
SELECT g,
       1 + (g % 500),
       TIMESTAMPTZ '2025-01-01 00:00:00+00' + ((g * 7919) % 525600) * INTERVAL '1 minute',
       (g % 997) + 0.50
FROM generate_series(1, 50000) AS g;
VACUUM ANALYZE query_lab."payment";

-- The two lookups being measured.
--   A. Range filter: every payment requested on 1 June 2025.
--   B. Account + period: account 42 during April-June 2025 (the case's review operation).
\set lookup_a 'SELECT "lab_row_id", "requested_at" FROM query_lab."payment" WHERE "requested_at" >= TIMESTAMPTZ \'2025-06-01 00:00:00+00\' AND "requested_at" < TIMESTAMPTZ \'2025-06-02 00:00:00+00\' ORDER BY "requested_at", "lab_row_id"'
\set lookup_b 'SELECT "lab_row_id", "requested_at", "amount" FROM query_lab."payment" WHERE "account_id" = 42 AND "requested_at" >= TIMESTAMPTZ \'2025-04-01 00:00:00+00\' AND "requested_at" < TIMESTAMPTZ \'2025-07-01 00:00:00+00\' ORDER BY "requested_at"'
-- A fingerprint of each result, so every phase can be checked to return identical rows.
\set check_a 'SELECT count(*) AS rows_returned, md5(string_agg("lab_row_id"::text, \',\' ORDER BY "requested_at", "lab_row_id")) AS result_md5 FROM (' :lookup_a ') r'
\set check_b 'SELECT count(*) AS rows_returned, md5(string_agg("lab_row_id"::text, \',\' ORDER BY "requested_at", "lab_row_id")) AS result_md5 FROM (' :lookup_b ') r'
\echo 'Lookup A:' :lookup_a
\echo 'Lookup B:' :lookup_b

-- ===================== PHASE 1: no secondary index =====================
\echo '=== PHASE 1: no secondary index ==='
:check_a;
:check_b;
-- Warm the cache once, then measure each lookup five times.
:lookup_a \g /dev/null
\echo '--- lookup A, phase 1, run 1' \\ EXPLAIN (ANALYZE, BUFFERS) :lookup_a;
\echo '--- lookup A, phase 1, run 2' \\ EXPLAIN (ANALYZE, BUFFERS) :lookup_a;
\echo '--- lookup A, phase 1, run 3' \\ EXPLAIN (ANALYZE, BUFFERS) :lookup_a;
\echo '--- lookup A, phase 1, run 4' \\ EXPLAIN (ANALYZE, BUFFERS) :lookup_a;
\echo '--- lookup A, phase 1, run 5' \\ EXPLAIN (ANALYZE, BUFFERS) :lookup_a;
:lookup_b \g /dev/null
\echo '--- lookup B, phase 1, run 1' \\ EXPLAIN (ANALYZE, BUFFERS) :lookup_b;
\echo '--- lookup B, phase 1, run 2' \\ EXPLAIN (ANALYZE, BUFFERS) :lookup_b;
\echo '--- lookup B, phase 1, run 3' \\ EXPLAIN (ANALYZE, BUFFERS) :lookup_b;
\echo '--- lookup B, phase 1, run 4' \\ EXPLAIN (ANALYZE, BUFFERS) :lookup_b;
\echo '--- lookup B, phase 1, run 5' \\ EXPLAIN (ANALYZE, BUFFERS) :lookup_b;

-- ===================== PHASE 2: B-tree index on requested_at =====================
CREATE INDEX p2_requested_at_idx ON query_lab."payment" USING btree ("requested_at");
ANALYZE query_lab."payment";
\echo '=== PHASE 2: index on requested_at ==='
:check_a;
:check_b;
:lookup_a \g /dev/null
\echo '--- lookup A, phase 2, run 1' \\ EXPLAIN (ANALYZE, BUFFERS) :lookup_a;
\echo '--- lookup A, phase 2, run 2' \\ EXPLAIN (ANALYZE, BUFFERS) :lookup_a;
\echo '--- lookup A, phase 2, run 3' \\ EXPLAIN (ANALYZE, BUFFERS) :lookup_a;
\echo '--- lookup A, phase 2, run 4' \\ EXPLAIN (ANALYZE, BUFFERS) :lookup_a;
\echo '--- lookup A, phase 2, run 5' \\ EXPLAIN (ANALYZE, BUFFERS) :lookup_a;
:lookup_b \g /dev/null
\echo '--- lookup B, phase 2, run 1' \\ EXPLAIN (ANALYZE, BUFFERS) :lookup_b;
\echo '--- lookup B, phase 2, run 2' \\ EXPLAIN (ANALYZE, BUFFERS) :lookup_b;
\echo '--- lookup B, phase 2, run 3' \\ EXPLAIN (ANALYZE, BUFFERS) :lookup_b;
\echo '--- lookup B, phase 2, run 4' \\ EXPLAIN (ANALYZE, BUFFERS) :lookup_b;
\echo '--- lookup B, phase 2, run 5' \\ EXPLAIN (ANALYZE, BUFFERS) :lookup_b;

-- ===================== PHASE 3: composite index (account_id, requested_at) =====================
CREATE INDEX p2_account_requested_at_idx ON query_lab."payment" USING btree ("account_id", "requested_at");
ANALYZE query_lab."payment";
\echo '=== PHASE 3: composite index on (account_id, requested_at) ==='
:check_b;
:lookup_b \g /dev/null
\echo '--- lookup B, phase 3, run 1' \\ EXPLAIN (ANALYZE, BUFFERS) :lookup_b;
\echo '--- lookup B, phase 3, run 2' \\ EXPLAIN (ANALYZE, BUFFERS) :lookup_b;
\echo '--- lookup B, phase 3, run 3' \\ EXPLAIN (ANALYZE, BUFFERS) :lookup_b;
\echo '--- lookup B, phase 3, run 4' \\ EXPLAIN (ANALYZE, BUFFERS) :lookup_b;
\echo '--- lookup B, phase 3, run 5' \\ EXPLAIN (ANALYZE, BUFFERS) :lookup_b;

-- ===================== Storage cost of the indexes =====================
\echo '=== Index sizes ==='
SELECT c.relname AS relation,
       CASE c.relkind WHEN 'r' THEN 'table' WHEN 'i' THEN 'index' END AS kind,
       pg_size_pretty(pg_relation_size(c.oid)) AS size
FROM pg_class c
WHERE c.relnamespace = 'query_lab'::regnamespace AND c.relkind IN ('r', 'i')
ORDER BY c.relkind DESC, c.relname;
