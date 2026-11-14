# Bank / Fintech Platform

Goodnews Ukaegbu · Student ID 301923986

The portfolio uses fictional records for Bank / Fintech Platform.

- [Portfolio 1](portfolio-1-database-design/)
- [Portfolio 2](portfolio-2-query-optimisation/)
- [Portfolio 3](portfolio-3-transactions-concurrency/)
- [Portfolio 4](portfolio-4-nosql/)
- [Portfolio 5](portfolio-5-distributed-cloud/)

[Final summary](Ukaegbu_Goodnews_301923986_FinalSummary.md) · [PDF](Ukaegbu_Goodnews_301923986_FinalSummary.pdf)

---

## About this portfolio

This repository holds my five MIT 8103 Advanced Database Systems portfolio activities. All of them are built around one case study, a **Bank / Fintech Platform**. Customers open accounts and make payments, and operations staff review and reconcile payment activity. All records are fictional.

| # | Activity | Technology | Type of work |
| --- | --- | --- | --- |
| 1 | Database Design and Modelling | PostgreSQL | Schema, ER diagram, normalisation, constraint tests |
| 2 | Query Processing and Optimisation | PostgreSQL | Case queries, `EXPLAIN ANALYZE`, index benchmarks |
| 3 | Transactions and Concurrency | PostgreSQL (two sessions) | COMMIT/ROLLBACK, isolation, lost update and double spend vs `FOR UPDATE` and `REPEATABLE READ` |
| 4 | NoSQL and Advanced Data Models | MongoDB (`mongosh`) | Event documents, schema validation, queries, aggregation, `explain()` |
| 5 | Distributed and Cloud Database Exercise | MongoDB replica set | Distributed design proposal plus a live three-member failover demonstration |

Every result quoted in this repository comes from a real run. The raw output of each run is saved in the portfolio's `evidence/` folder, and the screenshots are rendered from that output. The current evidence was produced on PostgreSQL 16.15 and MongoDB 8.0.23.

## Repository structure

```text
Ukaegbu_Goodnews_301923986/
├── README.md                                   ← this file
├── Ukaegbu_Goodnews_301923986_FinalSummary.md  ← final written summary (also as PDF)
├── run_all.sh                                  ← rebuilds every exercise and refreshes the evidence
├── docker-compose.yml                          ← PostgreSQL 16 + MongoDB 8.0 for local runs
├── requirements.txt                            ← Python package for the two-session driver
├── tools/two_session_driver.py                 ← replays the Portfolio 3 two-session scripts
├── images/                                     ← ER diagram image
├── portfolio-1-database-design/                ← design, ER, normalisation, schema, data, tests, verification
├── portfolio-2-query-optimisation/             ← case queries, index benchmark
├── portfolio-3-transactions-concurrency/       ← transactions, two-session scripts, cleanup
├── portfolio-4-nosql/                          ← MongoDB script (validator, events, indexes, queries)
└── portfolio-5-distributed-cloud/              ← design proposal and replica-set demonstration
```

Each portfolio folder has its own `*_README.md` with the full results, a `screenshots/` folder and an `evidence/` folder with the raw output.

## Prerequisites

- **PostgreSQL 16+** with `psql` (Portfolios 1–3)
- **MongoDB 8.0** with `mongosh` (Portfolio 4; `mongod` on PATH for the Portfolio 5 demonstration)
- **Python 3** with `psycopg2` (`pip install -r requirements.txt`) for the Portfolio 3 two-session replay

## Quick start

```bash
# Start the databases (or use your own PostgreSQL and MongoDB)
docker compose up -d

# Rebuild everything and refresh every evidence/ file
pip install -r requirements.txt
PGHOST=localhost PGUSER=postgres PGPASSWORD=postgres ./run_all.sh

# Also run the Portfolio 5 replica-set demonstration (needs mongod on PATH)
./run_all.sh --with-replica-set
```

`run_all.sh` drops and recreates the exercise database (`mit_portfolio`) and the MongoDB database `portfolio_nosql` each time. Each script can also be run by hand, as described in the portfolio READMEs and below.

---

## Portfolio 1: Database Design and Modelling

**Folder:** [portfolio-1-database-design](portfolio-1-database-design/)

### Objective
Design a normalised relational database for the Bank / Fintech case. Enforce its business rules inside the database instead of relying on application code.

### How it was implemented
1. **Requirements and entities.** I identified the users (customers, operations staff), the main operations (open an account, start and record a payment, review payments by account and time period) and three entities: `customer`, `account` and `payment` ([Design](portfolio-1-database-design/Ukaegbu_Goodnews_301923986_P1_Design.md)).
2. **ER model.** I drew the relationships as a Mermaid ER diagram: one customer has zero or more accounts, and one account has zero or more payments. The diagram shows the allowed values of each status field and marks `external_reference` as unique when not null ([ER diagram](portfolio-1-database-design/Ukaegbu_Goodnews_301923986_P1_ERDiagram.md), [image](images/Ukaegbu_Goodnews_301923986_ERDiagram.png)).
3. **Normalisation.** Starting from unnormalised statement-style records, I flattened them to 1NF, measured the anomalies (a customer's name repeated 6 times, a customer and an account that cannot be stored at all), and decomposed to 3NF. A lossless-join check rebuilds all 10 original rows exactly ([Normalisation](portfolio-1-database-design/Ukaegbu_Goodnews_301923986_P1_Normalisation.md)).
4. **Physical schema.** [`P1_Schema.sql`](portfolio-1-database-design/Ukaegbu_Goodnews_301923986_P1_Schema.sql) creates the `portfolio` schema in a single transaction, with:
   - primary keys: `pk_customer`, `pk_account`, `pk_payment`
   - foreign keys: `fk_account_0` (account → customer) and `fk_payment_0` (payment → account)
   - `NOT NULL` on every required field
   - CHECK constraints: `account_nonnegative_balance` (`available_balance >= 0`) and `payment_positive_amount` (`amount > 0`)
   - CHECK constraints for allowed values: `customer_status_allowed`, `account_status_allowed`, `payment_status_allowed`, and `account_currency_iso` (three upper-case letters)
   - a **partial unique index**, `payment_reference_idempotent`, on `external_reference WHERE external_reference IS NOT NULL`. A supplied reference works as an idempotency key, and payments without one are still allowed.
   - indexes on the foreign keys, which PostgreSQL does not create automatically: `idx_account_customer_id`, and `idx_payment_account_requested_at` on `(account_id, requested_at)`, which also serves the "payments by account and time period" review
   - `NUMERIC(18,2)` for money and `TIMESTAMPTZ` for payment times
5. **Sample data.** [`P1_SampleData.sql`](portfolio-1-database-design/Ukaegbu_Goodnews_301923986_P1_SampleData.sql) inserts 3 customers, 4 accounts and 10 payments in three currencies and all three payment statuses. Account 2004 deliberately has no payments.

### How it was tested
- [`P1_ConstraintTests.sql`](portfolio-1-database-design/Ukaegbu_Goodnews_301923986_P1_ConstraintTests.sql) holds **28 deliberately invalid inserts**. Each one is labelled with the constraint and SQLSTATE it should hit:

  | Test group | Count | Expected SQLSTATE |
  | --- | --- | --- |
  | Duplicate primary keys | 3 | 23505 `unique_violation` |
  | Missing parent rows (foreign keys) | 2 | 23503 `foreign_key_violation` |
  | NULL in required columns | 16 | 23502 `not_null_violation` |
  | Negative balance / zero amount (CHECK) | 2 | 23514 `check_violation` |
  | Duplicate non-null `external_reference` | 1 | 23505 `unique_violation` |
  | Status or currency outside the allowed values (CHECK) | 4 | 23514 `check_violation` |

- Each statement was run on its own, outside a transaction, so one failure could not affect the next.
- **Result:** all 28 were rejected at the expected constraint with the expected SQLSTATE. Afterwards the tables still held exactly 3 customers, 4 accounts and 10 payments.
- [`P1_Verify.sql`](portfolio-1-database-design/Ukaegbu_Goodnews_301923986_P1_Verify.sql) lists the 11 constraints and 6 indexes from the system catalog and runs the lossless-join check (10 rows in, 10 rows out, 0 missing, 0 extra).
- Evidence: [screenshot](portfolio-1-database-design/screenshots/Ukaegbu_Goodnews_301923986_P1_DatabaseResults.png) · [raw output](portfolio-1-database-design/evidence/)

---

## Portfolio 2: Query Processing and Optimisation

**Folder:** [portfolio-2-query-optimisation](portfolio-2-query-optimisation/)

### Objective
Write useful queries for the case, read their execution plans, and measure what different indexes change for the lookups the case actually needs.

### How it was implemented
1. **Case queries** ([`P2_Queries.sql`](portfolio-2-query-optimisation/Ukaegbu_Goodnews_301923986_P2_Queries.sql)), each followed by `EXPLAIN (ANALYZE, BUFFERS)`:
   - a three-table **join** of payment → account → customer
   - **payments for one account in one period** (account 2003, April 2025), the case's main review operation
   - **activity per account** with a `LEFT JOIN`, so the account with no payments still appears
2. **Performance lab** ([`P2_Optimisation.sql`](portfolio-2-query-optimisation/Ukaegbu_Goodnews_301923986_P2_Optimisation.sql)):
   - creates a separate `query_lab.payment` table so the Portfolio 1 data stays untouched
   - loads **50,000 rows** (500 accounts × 100 payments, spread across 2025), then runs `VACUUM ANALYZE`
   - measures two lookups, each warmed once and then run five times under `EXPLAIN (ANALYZE, BUFFERS)`:
     **A**, a one-day `requested_at` range, and **B**, one account over one quarter
   - phase 1 has no secondary index, phase 2 adds a B-tree on `requested_at`, and phase 3 adds a composite B-tree on `(account_id, requested_at)`
   - records each result's row count and MD5 fingerprint in every phase, and the size of each index

### How it was tested
- **Query correctness:** the outputs were checked against the sample data. The join returned 10 rows, the period query returned payments 3006–3008 (and excluded 3009 on 2 May), and the activity query returned all 4 accounts, including account 2004 with 0 payments.
- **Plans:** the period query was answered directly by `idx_payment_account_requested_at` from Portfolio 1.
- **Index comparison** (medians of five runs; every phase returned identical rows):

  | Lookup | No secondary index | B-tree on `requested_at` | Composite `(account_id, requested_at)` |
  | --- | --- | --- | --- |
  | A: one-day range (137 rows) | 1.560 ms, 368 buffers | **0.098 ms**, 139 buffers | — |
  | B: account 42, Apr–Jun (27 rows) | 1.723 ms, 368 buffers | 0.947 ms, 404 buffers | **0.022 ms**, 29 buffers |

- **Conclusion:** the range index made lookup A about 16× faster. For lookup B, the single-column index still had to read the whole quarter and discard 12,438 rows from other accounts; it touched more buffers than a full scan. The composite index matched the query's shape (equality on `account_id` first, then the range) and was about 78× faster than no index. The two indexes cost 2.6 MB on a 2.9 MB table, plus extra work on every write.
- Evidence: [query results](portfolio-2-query-optimisation/screenshots/Ukaegbu_Goodnews_301923986_P2_QueryResults.png) · [index comparison](portfolio-2-query-optimisation/screenshots/Ukaegbu_Goodnews_301923986_P2_IndexComparison.png) · [raw output](portfolio-2-query-optimisation/evidence/). Plans and all timings are in the [P2 README](portfolio-2-query-optimisation/Ukaegbu_Goodnews_301923986_P2_README.md).

---

## Portfolio 3: Transactions and Concurrency

**Folder:** [portfolio-3-transactions-concurrency](portfolio-3-transactions-concurrency/)

### Objective
Show atomicity (COMMIT/ROLLBACK), READ COMMITTED visibility, and how a lost update happens, using both a simple counter and a realistic payment scenario, and compare the ways to prevent it.

### How it was implemented
1. [`P3_Transactions.sql`](portfolio-3-transactions-concurrency/Ukaegbu_Goodnews_301923986_P3_Transactions.sql) adds a temporary helper column, `p3_processed_count`, to `account`, with a CHECK that it stays ≥ 0. A committed +1 is kept. A second transaction adds 10, then breaks the CHECK (SQLSTATE **23514**); further statements fail with **25P02** until `ROLLBACK`, which also undoes the +10.
2. **Counter, two sessions** ([Session A](portfolio-3-transactions-concurrency/Ukaegbu_Goodnews_301923986_P3_SessionA.sql) / [Session B](portfolio-3-transactions-concurrency/Ukaegbu_Goodnews_301923986_P3_SessionB.sql), steps 1–12): B reads while A's change is uncommitted, then both sessions do read-calculate-write without a lock, then again with `SELECT … FOR UPDATE`.
3. **Concurrent payments, two sessions** ([Session A](portfolio-3-transactions-concurrency/Ukaegbu_Goodnews_301923986_P3_Payments_SessionA.sql) / [Session B](portfolio-3-transactions-concurrency/Ukaegbu_Goodnews_301923986_P3_Payments_SessionB.sql), steps 1–15): account 2002 holds 640.00, and each session tries to pay 400.00. The scenario is run three ways: READ COMMITTED with no lock, `SELECT … FOR UPDATE`, and REPEATABLE READ with a retry.
4. [`P3_Cleanup.sql`](portfolio-3-transactions-concurrency/Ukaegbu_Goodnews_301923986_P3_Cleanup.sql) removes the helper column and the test payments and restores the account.
5. `run_all.sh` replays the two-session files with [`tools/two_session_driver.py`](tools/two_session_driver.py). It uses two real connections and runs the numbered steps in order, as two `psql` terminals would. It also records when a session is blocked and on what (`pg_stat_activity`).

### How it was tested

| Check | Expected | Observed |
| --- | --- | --- |
| Counter after COMMIT | 1 | 1 |
| Other session during A's uncommitted change | 1 (no dirty read) | 1 (A saw 2) |
| Counter after the failed transaction and ROLLBACK | 1 (the +10 is undone) | 1 |
| Two increments without locking | 3 | **2** (lost update) |
| Two increments with `SELECT FOR UPDATE` | 3 | **3**; B waited on `Lock/transactionid` |
| Two 400.00 payments from 640.00, no lock | one payment rejected | **both paid (800.00), balance 240.00**: double spend |
| Same with `SELECT FOR UPDATE` | one payment rejected | B waited, read 240.00, rejected: balance 240.00, 1 payment |
| Same with REPEATABLE READ | one payment rejected | B failed with **40001**; the retry read 240.00 and rejected |
| After cleanup | Portfolio 1 state | 6 original columns; 3 / 4 / 10 rows; account 2002 at 640.00 |

- Evidence: [commit/rollback](portfolio-3-transactions-concurrency/screenshots/Ukaegbu_Goodnews_301923986_P3_CommitRollback.png) · [counter](portfolio-3-transactions-concurrency/screenshots/Ukaegbu_Goodnews_301923986_P3_ConcurrencyResult.png) · [concurrent payments](portfolio-3-transactions-concurrency/screenshots/Ukaegbu_Goodnews_301923986_P3_DoubleSpend.png) · [raw output](portfolio-3-transactions-concurrency/evidence/)

### How to reproduce
Run the Portfolio 1 schema and sample data, then `P3_Transactions.sql`. Open two `psql` terminals on the same database and run the numbered steps in order, switching between Session A and Session B (first the counter files, then the payment files). Run the reset steps outside any transaction. Finish with `P3_Cleanup.sql`. Alternatively, `run_all.sh` does all of this.

---

## Portfolio 4: NoSQL and Advanced Data Models

**Folder:** [portfolio-4-nosql](portfolio-4-nosql/)

### Objective
Model payment lifecycle events as MongoDB documents and compare the document approach with the relational design.

### How it was implemented
[`P4_MongoDB.js`](portfolio-4-nosql/Ukaegbu_Goodnews_301923986_P4_MongoDB.js) is a single `mongosh` script (229 lines; the documents are built by a `makeEvent()` helper instead of being written out by hand). It:
1. switches to the `portfolio_nosql` database and stops if `payment_event` already exists, so it only runs on a fresh database
2. creates `payment_event` with a **`$jsonSchema` validator** (`validationLevel: strict`, `validationAction: error`). The validator requires an `eventType` of `payment_requested`, `payment_settled` or `payment_failed`, a BSON `date` for `occurredAt`, a `Decimal128` amount and a valid status in the payment snapshot, and a `details.channel`.
3. builds **18 event documents** from the Portfolio 1 sample data, consistent with each payment's status: a request for each of the 10 payments, a settlement for the 7 posted ones and a failure for the 1 failed one. Each document embeds the account and customer **snapshots** so it can be read on its own.
4. creates two compound indexes: `event_type_time` `{eventType: 1, occurredAt: -1}` and `source_payment_time` `{"source.key.payment_id": 1, occurredAt: 1}`
5. runs 5 queries (event type, the lifecycle of one payment, a date range, a count per type, and the settled value per currency from the embedded account) and checks the index use with `explain("executionStats")`

### How it was tested

| Test | Expected | Observed |
| --- | --- | --- |
| Insert events | 18 inserted | 18 |
| Settled payments, newest first | 7 documents | 7 |
| Lifecycle of payment 3005 | requested, then failed | 2 documents, in that order |
| Events from 1 to 7 April 2025 | 7 documents | 7 |
| Count per type | requested 10, settled 7, failed 1 | 10 / 7 / 1 |
| Settled value per currency | same as the PostgreSQL posted totals | EUR 1047.05, GBP 75.40, USD 220.50 (matches) |
| `explain()` with the indexes | IXSCAN, documents examined = returned | IXSCAN; 7 of 7 and 2 of 2 (18 without the index) |
| Date as text / unknown type / text amount / no channel | Rejected by the validator | Error **121** for all four |
| Duplicate `_id` | Rejected by the unique `_id` index | Error **11000** |
| Final document count | 18 | 18 |

- Evidence: [screenshot](portfolio-4-nosql/screenshots/Ukaegbu_Goodnews_301923986_P4_DocumentsAndQueries.png) · [raw output](portfolio-4-nosql/evidence/)
- Trade-off noted: embedded snapshots make each event self-contained, but they duplicate data and won't follow later SQL changes. PostgreSQL remains the system of record.

---

## Portfolio 5: Distributed and Cloud Database Exercise

**Folder:** [portfolio-5-distributed-cloud](portfolio-5-distributed-cloud/)

### Objective
Propose and justify a distributed, highly available deployment for the case's event data, and test the replication behaviour it relies on.

### How it was implemented
- **Design proposal** ([P5 README](portfolio-5-distributed-cloud/Ukaegbu_Goodnews_301923986_P5_README.md), [diagram](portfolio-5-distributed-cloud/screenshots/Ukaegbu_Goodnews_301923986_P5_ProposedDesign.png)):
  - **Topology:** a 3-member MongoDB replica set across 3 availability zones, with PostgreSQL on its own managed high-availability setup.
  - **Consistency:** majority write concern with a timeout, majority read concern, secondary lag, and idempotency keys for retries. There is no atomic transaction across PostgreSQL and MongoDB, so an outbox pattern would be needed.
  - **Sharding trade-offs:** a hashed high-cardinality key compared with a time-based key.
  - **Cloud operations:** security, monitoring and tested backups.
- **Live demonstration** ([`P5_ReplicaSetDemo.sh`](portfolio-5-distributed-cloud/Ukaegbu_Goodnews_301923986_P5_ReplicaSetDemo.sh)): starts three `mongod` processes as replica set `rs0`, writes with `w: "majority"`, crashes the primary with `kill -9`, restarts it, and then removes the majority.

### How it was tested

| Check | Observed |
| --- | --- |
| Majority write, read on every member | 3 documents on all three members; replication lag 0 s |
| Primary killed | New primary elected after **9,099 ms** (term 1 → 2, `electionTimeout`) |
| Majority write with one member down | Acknowledged (2 of 3 is a majority) |
| Crashed member restarted | Rejoined as SECONDARY and caught up (4 documents) |
| Only 1 of 3 members left | No primary after 12 s; write refused with **10107 NotWritablePrimary** |
| All members back | Primary re-elected; identical 4 documents on all three |

- **Limitation:** all three members ran on one machine, so this shows the mechanism, not real high availability. No cloud resources were provisioned, and no sharding or backup-recovery test was run.
- Evidence: [screenshot](portfolio-5-distributed-cloud/screenshots/Ukaegbu_Goodnews_301923986_P5_ReplicaSetFailover.png) · [raw output](portfolio-5-distributed-cloud/evidence/)

---

## Evidence summary

| Portfolio | Key result |
| --- | --- |
| 1 | 28 of 28 invalid inserts rejected at the expected constraint; sample data unchanged; lossless 3NF decomposition |
| 2 | Range lookup 1.560 → 0.098 ms with a B-tree; account + period lookup 1.723 → 0.022 ms with a composite index (single-column index: 0.947 ms) |
| 3 | Lost update and double spend without locking; correct results with `SELECT FOR UPDATE` (wait) and `REPEATABLE READ` (40001 + retry) |
| 4 | 18 consistent events; 5 queries correct; indexes confirmed with `explain()`; 5 invalid inserts rejected (121 ×4, 11000) |
| 5 | Live three-member replica set: failover in about 9 s, majority writes continued, a minority refused writes |

Repository: https://github.com/Oziichukwu/Ukaegbu_Goodnews_301923986
