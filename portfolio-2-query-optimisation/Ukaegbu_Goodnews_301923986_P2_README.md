# Portfolio 2 — Query Processing and Optimisation

I ran three case queries against the Portfolio 1 sample data and read their execution plans. I then measured two lookups on a separate 50,000-row table before and after adding B-tree indexes. All figures below come from [evidence/…_P2_Queries.txt](evidence/Ukaegbu_Goodnews_301923986_P2_Queries.txt) and [evidence/…_P2_Optimisation.txt](evidence/Ukaegbu_Goodnews_301923986_P2_Optimisation.txt) (PostgreSQL 16.15).

## 1. Payments with their account and customer

```sql
SELECT p."payment_id", p."amount", a."currency", p."status",
       a."account_id", c."customer_id", c."legal_name"
FROM portfolio."payment" p
JOIN portfolio."account" a ON a."account_id" = p."account_id"
JOIN portfolio."customer" c ON c."customer_id" = a."customer_id"
ORDER BY p."payment_id"
LIMIT 20;
```

| payment_id | amount | currency | status | account_id | customer_id | legal_name |
| --- | --- | --- | --- | --- | --- | --- |
| 3001 | 42.50 | USD | posted | 2001 | 1001 | Avery Morgan |
| 3002 | 18.25 | USD | pending | 2001 | 1001 | Avery Morgan |
| 3003 | 120.00 | USD | posted | 2001 | 1001 | Avery Morgan |
| 3004 | 75.40 | GBP | posted | 2002 | 1001 | Avery Morgan |
| 3005 | 15.99 | GBP | failed | 2002 | 1001 | Avery Morgan |
| 3006 | 950.00 | EUR | posted | 2003 | 1002 | Blessing Okafor |
| 3007 | 64.30 | EUR | posted | 2003 | 1002 | Blessing Okafor |
| 3008 | 210.00 | EUR | pending | 2003 | 1002 | Blessing Okafor |
| 3009 | 32.75 | EUR | posted | 2003 | 1002 | Blessing Okafor |
| 3010 | 58.00 | USD | posted | 2001 | 1001 | Avery Morgan |

```text
Limit (actual time=0.015..0.030 rows=10 loops=1)
  Buffers: shared hit=42
  ->  Nested Loop (actual time=0.015..0.029 rows=10 loops=1)
        ->  Nested Loop (actual time=0.011..0.019 rows=10 loops=1)
              ->  Index Scan using pk_payment on payment p (actual time=0.006..0.008 rows=10 loops=1)
              ->  Index Scan using pk_account on account a (actual time=0.001..0.001 rows=1 loops=10)
                    Index Cond: (account_id = p.account_id)
        ->  Index Scan using pk_customer on customer c (actual time=0.001..0.001 rows=1 loops=10)
              Index Cond: (customer_id = a.customer_id)
Planning Time: 0.172 ms
Execution Time: 0.047 ms
```

(Plans for the case queries are abridged here; the full output, including every Buffers line, is in the raw output.)

Because of `ORDER BY … LIMIT`, the planner reads payments in primary-key order and looks up each account and customer through their primary keys (nested loops), instead of hashing whole tables.

## 2. Review payments by account and time period

The case's main review operation: account 2003 during April 2025. The half-open range `[1 April, 1 May)` cannot miss or double-count a payment on the boundary.

```sql
SELECT p."payment_id", p."requested_at", p."amount", p."status", p."beneficiary_label"
FROM portfolio."payment" p
WHERE p."account_id" = 2003
  AND p."requested_at" >= TIMESTAMPTZ '2025-04-01 00:00:00+00'
  AND p."requested_at" <  TIMESTAMPTZ '2025-05-01 00:00:00+00'
ORDER BY p."requested_at";
```

| payment_id | requested_at | amount | status | beneficiary_label |
| --- | --- | --- | --- | --- |
| 3006 | 2025-04-06 10:00:00+00 | 950.00 | posted | Cedar Property Rentals |
| 3007 | 2025-04-08 16:05:00+00 | 64.30 | posted | Greenleaf Grocers |
| 3008 | 2025-04-15 12:30:00+00 | 210.00 | pending | Summit Insurance |

```text
Index Scan using idx_payment_account_requested_at on payment p (actual time=0.016..0.017 rows=3 loops=1)
  Index Cond: ((account_id = 2003) AND (requested_at >= '2025-04-01 00:00:00+00'::timestamp with time zone)
               AND (requested_at < '2025-05-01 00:00:00+00'::timestamp with time zone))
  Buffers: shared hit=2
Planning Time: 0.038 ms
Execution Time: 0.022 ms
```

Both conditions are answered inside the composite index `idx_payment_account_requested_at` from Portfolio 1, and the rows come out already in `requested_at` order, so no separate sort is needed. Payment 3009 (2 May) is correctly excluded.

## 3. Activity per account

A `LEFT JOIN` keeps account 2004, which has no payments; `FILTER` totals only posted payments.

```sql
SELECT a."account_id", a."currency",
       count(p."payment_id") AS payment_count,
       coalesce(sum(p."amount") FILTER (WHERE p."status" = 'posted'), 0) AS posted_total
FROM portfolio."account" a
LEFT JOIN portfolio."payment" p ON p."account_id" = a."account_id"
GROUP BY a."account_id", a."currency"
ORDER BY payment_count DESC, a."account_id";
```

| account_id | currency | payment_count | posted_total |
| --- | --- | --- | --- |
| 2001 | USD | 4 | 220.50 |
| 2003 | EUR | 4 | 1047.05 |
| 2002 | GBP | 2 | 75.40 |
| 2004 | USD | 0 | 0 |

```text
Sort (actual time=0.030..0.032 rows=4 loops=1)
  Sort Key: (count(p.payment_id)) DESC, a.account_id
  ->  HashAggregate (actual time=0.025..0.028 rows=4 loops=1)
        Group Key: a.account_id
        ->  Hash Right Join (actual time=0.013..0.018 rows=11 loops=1)
              Hash Cond: (p.account_id = a.account_id)
              ->  Seq Scan on payment p (actual time=0.001..0.001 rows=10 loops=1)
              ->  Hash (actual time=0.005..0.006 rows=4 loops=1)
                    ->  Seq Scan on account a (actual time=0.002..0.002 rows=4 loops=1)
Planning Time: 0.072 ms
Execution Time: 0.053 ms
```

Every row of both tables is needed here, so sequential scans and a hash join are the right choice; an index would not help. The join produces 11 rows (10 payments plus one NULL-extended row for account 2004). The posted totals match the settled totals that MongoDB computes from its own documents in Portfolio 4.

## Index comparison

[`P2_Optimisation.sql`](Ukaegbu_Goodnews_301923986_P2_Optimisation.sql) creates `query_lab.payment` with 50,000 generated rows (500 accounts × 100 payments, timestamps spread across 2025). Each lookup is warmed once and then measured five times with `EXPLAIN (ANALYZE, BUFFERS)`. Before and after every index change it records the row count and an MD5 fingerprint of the result: all phases returned identical rows (lookup A: 137 rows, `4d921c5d…`; lookup B: 27 rows, `2cfa5e24…`).

### Lookup A — range filter: all payments requested on 1 June 2025

| Phase | Median (ms) | Five runs (ms) | Plan nodes | Buffer hits |
| --- | --- | --- | --- | --- |
| No secondary index | 1.560 | 1.542, 1.520, 1.560, 1.566, 1.594 | Sort → Seq Scan | 368 |
| B-tree on requested_at | 0.098 | 0.098, 0.084, 0.110, 0.079, 0.110 | Sort → Bitmap Heap Scan → Bitmap Index Scan (p2_requested_at_idx) | 139 |

The sequential scan read every page (368) and discarded 49,863 rows. With the index the planner went straight to the 137 matching rows: about 16× faster on the median, with 62 % fewer buffer reads.

### Lookup B — account + period: account 42, April–June 2025

| Phase | Median (ms) | Five runs (ms) | Plan nodes | Buffer hits | Rows removed by filter |
| --- | --- | --- | --- | --- | --- |
| No secondary index | 1.723 | 1.796, 1.717, 1.701, 1.723, 1.849 | Sort → Seq Scan | 368 | 49,973 |
| B-tree on requested_at only | 0.947 | 0.947, 0.959, 0.937, 0.947, 0.968 | Sort → Bitmap Heap Scan → Bitmap Index Scan (p2_requested_at_idx) | 404 | 12,438 |
| Composite (account_id, requested_at) | 0.022 | 0.024, 0.022, 0.024, 0.021, 0.020 | Sort → Bitmap Heap Scan → Bitmap Index Scan (p2_account_requested_at_idx) | 29 | 0 |

This is the more instructive result. The single-column index on `requested_at` still had to fetch the whole quarter (12,465 rows) and throw away 12,438 of them because they belong to other accounts; it touched **more** buffers (404) than the sequential scan (368) and was less than 2× faster. The composite index puts `account_id` first (equality) and `requested_at` second (range), so the index alone narrowed the search to the 27 rows needed: 29 buffers and a median of 0.022 ms, about 78× faster than no index.

### Measured plan — lookup B with the composite index (run 3)

```text
Sort  (cost=86.08..86.14 rows=25 width=22) (actual time=0.018..0.019 rows=27 loops=1)
  Sort Key: requested_at
  Sort Method: quicksort  Memory: 26kB
  Buffers: shared hit=29
  ->  Bitmap Heap Scan on payment  (cost=4.61..85.50 rows=25 width=22) (actual time=0.004..0.015 rows=27 loops=1)
        Recheck Cond: ((account_id = 42) AND (requested_at >= '2025-04-01 00:00:00+00'::timestamp with time zone) AND (requested_at < '2025-07-01 00:00:00+00'::timestamp with time zone))
        Heap Blocks: exact=27
        Buffers: shared hit=29
        ->  Bitmap Index Scan on p2_account_requested_at_idx  (cost=0.00..4.60 rows=25 width=0) (actual time=0.002..0.002 rows=27 loops=1)
              Index Cond: ((account_id = 42) AND (requested_at >= '2025-04-01 00:00:00+00'::timestamp with time zone) AND (requested_at < '2025-07-01 00:00:00+00'::timestamp with time zone))
              Buffers: shared hit=2
Planning Time: 0.019 ms
Execution Time: 0.024 ms
```

All 25 measured plans are in the raw output.

### Cost of the indexes

| Relation | Kind | Size |
| --- | --- | --- |
| payment | table | 2944 kB |
| p2_account_requested_at_idx | index | 1552 kB |
| p2_requested_at_idx | index | 1112 kB |
| payment_pkey | index | 1112 kB |

The two secondary indexes together take 2.6 MB, almost as much as the table itself, and every insert or update of a payment must also maintain them. An index is worth adding for lookups the case actually runs (here, review by account and period, which is why Portfolio 1 already creates `idx_payment_account_requested_at`). Timings depend on this lookup, data distribution and machine.

## Reproduce

Use a fresh database with the Portfolio 1 schema and sample data. Run Ukaegbu_Goodnews_301923986_P2_Queries.sql, then Ukaegbu_Goodnews_301923986_P2_Optimisation.sql with `psql` (it uses psql variables to keep the measured query text identical in every phase). `run_all.sh` does both and saves the output in `evidence/`.

[Query results](screenshots/Ukaegbu_Goodnews_301923986_P2_QueryResults.png) · [Index comparison](screenshots/Ukaegbu_Goodnews_301923986_P2_IndexComparison.png)

## References

- [PostgreSQL — EXPLAIN](https://www.postgresql.org/docs/16/using-explain.html)
- [PostgreSQL — multicolumn indexes](https://www.postgresql.org/docs/16/indexes-multicolumn.html)
