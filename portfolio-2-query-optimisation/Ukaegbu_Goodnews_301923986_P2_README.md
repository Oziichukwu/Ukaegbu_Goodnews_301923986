# Bank / Fintech Platform — SQL queries

## 1. Show related payment, account, customer records (up to 20).

```sql
SELECT t0."payment_id" AS "payment_payment_id",
       t0."amount" AS "payment_amount",
       t1."account_id" AS "account_account_id",
       t1."opened_date" AS "account_opened_date",
       t2."customer_id" AS "customer_customer_id",
       t2."legal_name" AS "customer_legal_name"
FROM portfolio."payment" t0
JOIN portfolio."account" t1 ON t0."account_id" = t1."account_id"
JOIN portfolio."customer" t2 ON t1."customer_id" = t2."customer_id"
ORDER BY t0."payment_id", t1."account_id", t2."customer_id"
LIMIT 20;
```

| payment_payment_id | payment_amount | account_account_id | account_opened_date | customer_customer_id | customer_legal_name |
| --- | --- | --- | --- | --- | --- |
| 3001 | 42.5 | 2001 | 2025-03-12 | 1001 | Avery Morgan |
| 3002 | 18.25 | 2001 | 2025-03-12 | 1001 | Avery Morgan |

## 2. Find payment records where requested_at matches "2025-04-02T14:30:00Z" (up to 20).

```sql
SELECT * FROM portfolio."payment"
WHERE "requested_at" IS NOT DISTINCT FROM '2025-04-02T14:30:00Z'
ORDER BY "payment_id"
LIMIT 20;
```

| payment_id | account_id | amount | requested_at | status | external_reference | beneficiary_label |
| --- | --- | --- | --- | --- | --- | --- |
| 3001 | 2001 | 42.5 | 2025-04-02T14:30:00+00:00 | posted | EXT-001 | Northwind Supplies |

## 3. Count payment records for each account_id (up to 20 groups).

```sql
SELECT "account_id", count(*) AS record_count
FROM portfolio."payment"
GROUP BY "account_id"
ORDER BY record_count DESC, "account_id" NULLS LAST
LIMIT 20;
```

| account_id | record_count |
| --- | --- |
| 2001 | 2 |


## Index comparison

| Phase | Median (ms) | Three runs (ms) | Plan nodes | Buffer hits |
| --- | --- | --- | --- | --- |
| Before index | 2.231 | 2.301, 2.231, 2.189 | Sort → Seq Scan | 274 |
| After index | 0.273 | 0.273, 0.266, 0.333 | Sort → Bitmap Heap Scan → Bitmap Index Scan | 55 |

The median execution time changed from 2.231 ms to 0.273 ms. The measured plan used p2_filter_idx. The results matched in both phases. An index adds storage and write-maintenance costs; timings depend on the selected lookup and environment.

## Execution plans

### Before index, run 1

```text
Sort (actual time=2.272..2.275 rows=50 loops=1)
  Seq Scan on payment (actual time=0.017..2.229 rows=50 loops=1)
Planning Time: 0.356 ms
Execution Time: 2.301 ms
```

### Before index, run 2

```text
Sort (actual time=2.203..2.206 rows=50 loops=1)
  Seq Scan on payment (actual time=0.016..2.166 rows=50 loops=1)
Planning Time: 0.336 ms
Execution Time: 2.231 ms
```

### Before index, run 3

```text
Sort (actual time=2.163..2.166 rows=50 loops=1)
  Seq Scan on payment (actual time=0.016..2.126 rows=50 loops=1)
Planning Time: 0.328 ms
Execution Time: 2.189 ms
```

### After index, run 1

```text
Sort (actual time=0.218..0.221 rows=50 loops=1)
  Bitmap Heap Scan on payment (actual time=0.032..0.157 rows=50 loops=1)
    Bitmap Index Scan using p2_filter_idx (actual time=0.015..0.015 rows=50 loops=1)
Planning Time: 0.519 ms
Execution Time: 0.273 ms
```

### After index, run 2

```text
Sort (actual time=0.202..0.204 rows=50 loops=1)
  Bitmap Heap Scan on payment (actual time=0.032..0.157 rows=50 loops=1)
    Bitmap Index Scan using p2_filter_idx (actual time=0.015..0.016 rows=50 loops=1)
Planning Time: 0.56 ms
Execution Time: 0.266 ms
```

### After index, run 3

```text
Sort (actual time=0.258..0.262 rows=50 loops=1)
  Bitmap Heap Scan on payment (actual time=0.041..0.207 rows=50 loops=1)
    Bitmap Index Scan using p2_filter_idx (actual time=0.02..0.021 rows=50 loops=1)
Planning Time: 0.613 ms
Execution Time: 0.333 ms
```

## Reproduce

Use a fresh database with the Portfolio 1 schema and sample data. Run Ukaegbu_Goodnews_301923986_P2_Queries.sql, then Ukaegbu_Goodnews_301923986_P2_Optimisation.sql. The optimisation script creates a separate performance table and runs EXPLAIN (ANALYZE, BUFFERS).

[Query screenshot](screenshots/Ukaegbu_Goodnews_301923986_P2_QueryResults.png) · [Index comparison](screenshots/Ukaegbu_Goodnews_301923986_P2_IndexComparison.png)

## References

- [PostgreSQL — EXPLAIN](https://www.postgresql.org/docs/17/using-explain.html)

