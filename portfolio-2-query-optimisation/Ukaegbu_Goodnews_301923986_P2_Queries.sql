-- Portfolio 2: case queries on the Portfolio 1 sample data.
-- Each query runs once to show its result, then under EXPLAIN (ANALYZE, BUFFERS)
-- to show the plan PostgreSQL actually used.

-- 1. Payments with their account and customer (join across all three tables).
SELECT p."payment_id", p."amount", a."currency", p."status",
       a."account_id", c."customer_id", c."legal_name"
FROM portfolio."payment" p
JOIN portfolio."account" a ON a."account_id" = p."account_id"
JOIN portfolio."customer" c ON c."customer_id" = a."customer_id"
ORDER BY p."payment_id"
LIMIT 20;

EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT p."payment_id", p."amount", a."currency", p."status",
       a."account_id", c."customer_id", c."legal_name"
FROM portfolio."payment" p
JOIN portfolio."account" a ON a."account_id" = p."account_id"
JOIN portfolio."customer" c ON c."customer_id" = a."customer_id"
ORDER BY p."payment_id"
LIMIT 20;

-- 2. Review payments by account and time period (the case's main review operation):
--    account 2003 during April 2025. A half-open range [start, end) avoids
--    missing or double-counting payments on the boundary.
SELECT p."payment_id", p."requested_at", p."amount", p."status", p."beneficiary_label"
FROM portfolio."payment" p
WHERE p."account_id" = 2003
  AND p."requested_at" >= TIMESTAMPTZ '2025-04-01 00:00:00+00'
  AND p."requested_at" <  TIMESTAMPTZ '2025-05-01 00:00:00+00'
ORDER BY p."requested_at";

EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT p."payment_id", p."requested_at", p."amount", p."status", p."beneficiary_label"
FROM portfolio."payment" p
WHERE p."account_id" = 2003
  AND p."requested_at" >= TIMESTAMPTZ '2025-04-01 00:00:00+00'
  AND p."requested_at" <  TIMESTAMPTZ '2025-05-01 00:00:00+00'
ORDER BY p."requested_at";


-- 3. Activity per account, including accounts with no payments (LEFT JOIN),
--    with the number of payments and the total value actually posted.
SELECT a."account_id", a."currency",
       count(p."payment_id") AS payment_count,
       coalesce(sum(p."amount") FILTER (WHERE p."status" = 'posted'), 0) AS posted_total
FROM portfolio."account" a
LEFT JOIN portfolio."payment" p ON p."account_id" = a."account_id"
GROUP BY a."account_id", a."currency"
ORDER BY payment_count DESC, a."account_id";

EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT a."account_id", a."currency",
       count(p."payment_id") AS payment_count,
       coalesce(sum(p."amount") FILTER (WHERE p."status" = 'posted'), 0) AS posted_total
FROM portfolio."account" a
LEFT JOIN portfolio."payment" p ON p."account_id" = a."account_id"
GROUP BY a."account_id", a."currency"
ORDER BY payment_count DESC, a."account_id";
