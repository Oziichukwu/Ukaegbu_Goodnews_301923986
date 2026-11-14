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
| 2 | Query Processing and Optimisation | PostgreSQL | SQL queries, `EXPLAIN ANALYZE`, index comparison |
| 3 | Transactions and Concurrency | PostgreSQL (two `psql` sessions) | COMMIT/ROLLBACK, isolation, lost update vs `SELECT … FOR UPDATE` |
| 4 | NoSQL and Advanced Data Models | MongoDB (`mongosh`) | Document model, schema validation, queries, aggregation |
| 5 | Distributed and Cloud Database Exercise | Design discussion | Replica set, consistency, sharding and recovery proposal |

## Repository structure

```text
Ukaegbu_Goodnews_301923986/
├── README.md                                   ← this file
├── Ukaegbu_Goodnews_301923986_FinalSummary.md  ← final written summary (also as PDF)
├── images/                                     ← ER diagram image
├── portfolio-1-database-design/                ← design, ER, normalisation, schema, sample data, constraint tests
├── portfolio-2-query-optimisation/             ← queries, optimisation script, plans, timings
├── portfolio-3-transactions-concurrency/       ← transaction script + Session A / Session B scripts
├── portfolio-4-nosql/                          ← MongoDB script (collection, validator, inserts, queries)
└── portfolio-5-distributed-cloud/              ← proposed distributed architecture
```

Each portfolio folder has its own `*_README.md` with the full results and a `screenshots/` folder with the evidence.

## Prerequisites

- **PostgreSQL 16 or 17** with the `psql` client (Portfolios 1–3)
- **MongoDB 6+** with `mongosh` (Portfolio 4)
- Nothing to install for Portfolio 5, which is a written design

## Quick start

```bash
# PostgreSQL: Portfolios 1–3 (run from the Ukaegbu_Goodnews_301923986 folder)
createdb mit_portfolio
psql -d mit_portfolio -f portfolio-1-database-design/Ukaegbu_Goodnews_301923986_P1_Schema.sql
psql -d mit_portfolio -f portfolio-1-database-design/Ukaegbu_Goodnews_301923986_P1_SampleData.sql
psql -d mit_portfolio -f portfolio-2-query-optimisation/Ukaegbu_Goodnews_301923986_P2_Queries.sql
psql -d mit_portfolio -f portfolio-2-query-optimisation/Ukaegbu_Goodnews_301923986_P2_Optimisation.sql
psql -d mit_portfolio -f portfolio-3-transactions-concurrency/Ukaegbu_Goodnews_301923986_P3_Transactions.sql
# then follow the two-session steps in Portfolio 3 below

# MongoDB: Portfolio 4
mongosh --file portfolio-4-nosql/Ukaegbu_Goodnews_301923986_P4_MongoDB.js
```

Run the constraint tests in Portfolio 1 statement by statement, as described below. Each one is meant to fail.

---

## Portfolio 1: Database Design and Modelling

**Folder:** [portfolio-1-database-design](portfolio-1-database-design/)

### Objective
Design a normalised relational database for the Bank / Fintech case. Enforce its business rules inside the database instead of relying on application code.

### How it was implemented
1. **Requirements and entities.** I identified the users (customers, operations staff), the main operations (open an account, start and record a payment, review payments by account and time period) and three entities: `customer`, `account` and `payment` ([Design](portfolio-1-database-design/Ukaegbu_Goodnews_301923986_P1_Design.md)).
2. **ER model.** I drew the relationships as a Mermaid ER diagram: one customer has zero or more accounts, and one account has zero or more payments ([ER diagram](portfolio-1-database-design/Ukaegbu_Goodnews_301923986_P1_ERDiagram.md), [image](images/Ukaegbu_Goodnews_301923986_ERDiagram.png)).
3. **Normalisation.** I took a grouped sample record through 1NF, 2NF and 3NF and listed the functional dependencies for each table ([Normalisation](portfolio-1-database-design/Ukaegbu_Goodnews_301923986_P1_Normalisation.md)).
4. **Physical schema.** [`P1_Schema.sql`](portfolio-1-database-design/Ukaegbu_Goodnews_301923986_P1_Schema.sql) creates the `portfolio` schema in a single transaction, with:
   - primary keys: `pk_customer`, `pk_account`, `pk_payment`
   - foreign keys: `fk_account_0` (account → customer) and `fk_payment_0` (payment → account)
   - `NOT NULL` on every required field
   - CHECK constraints: `account_nonnegative_balance` (`available_balance >= 0`) and `payment_positive_amount` (`amount > 0`)
   - a **partial unique index**, `payment_reference_idempotent`, on `external_reference WHERE external_reference IS NOT NULL`. A supplied reference works as an idempotency key, and payments without one are still allowed.
   - `NUMERIC(18,2)` for money and `TIMESTAMPTZ` for payment times
5. **Sample data.** [`P1_SampleData.sql`](portfolio-1-database-design/Ukaegbu_Goodnews_301923986_P1_SampleData.sql) inserts 1 customer, 1 account and 2 payments in one transaction. One payment has an external reference and the other is `NULL`.

### How it was tested
- [`P1_ConstraintTests.sql`](portfolio-1-database-design/Ukaegbu_Goodnews_301923986_P1_ConstraintTests.sql) holds **24 deliberately invalid inserts**. Each one is labelled with the constraint and SQLSTATE it should hit:

  | Test group | Count | Expected SQLSTATE |
  | --- | --- | --- |
  | Duplicate primary keys | 3 | 23505 `unique_violation` |
  | Missing parent rows (foreign keys) | 2 | 23503 `foreign_key_violation` |
  | NULL in required columns | 16 | 23502 `not_null_violation` |
  | Negative balance / zero amount (CHECK) | 2 | 23514 `check_violation` |
  | Duplicate non-null `external_reference` | 1 | 23505 `unique_violation` |

- Each statement was run on its own, outside a transaction, so one failure could not affect the next.
- **Result:** all 24 were rejected at the expected constraint. Afterwards the tables still held exactly 1 customer, 1 account and 2 payments.
- Evidence: [screenshots/…_P1_DatabaseResults.png](portfolio-1-database-design/screenshots/Ukaegbu_Goodnews_301923986_P1_DatabaseResults.png)

---

## Portfolio 2: Query Processing and Optimisation

**Folder:** [portfolio-2-query-optimisation](portfolio-2-query-optimisation/)

### Objective
Write useful queries for the case, read their execution plans, and measure what an index changes for a selective lookup.

### How it was implemented
1. **Case queries** ([`P2_Queries.sql`](portfolio-2-query-optimisation/Ukaegbu_Goodnews_301923986_P2_Queries.sql)), each followed by `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)`:
   - a three-table **join** of payment → account → customer
   - a **filter** on `payment.requested_at`
   - a **group-by** count of payments per account
2. **Performance lab** ([`P2_Optimisation.sql`](portfolio-2-query-optimisation/Ukaegbu_Goodnews_301923986_P2_Optimisation.sql)):
   - creates a separate `query_lab.payment` table so the Portfolio 1 data stays untouched
   - loads **50,000 rows** with `generate_series`, spreading `requested_at` over 1,000 distinct timestamps (50 rows each), then runs `ANALYZE`
   - runs the same equality lookup once to warm the cache, then three times with `EXPLAIN (ANALYZE, BUFFERS)`
   - creates a B-tree index, `p2_filter_idx`, on `requested_at`
   - repeats the warm-up and the three measured runs

### How it was tested
- **Query correctness:** the outputs were checked against the sample data. The join returned 2 rows (both for Avery Morgan), the filter returned payment 3001, and the group-by returned account 2001 with 2 payments.
- **Index comparison:** I compared the plan shape, buffer hits and the median of three runs before and after the index. I also confirmed that both phases returned the same 50 rows.

  | Phase | Plan | Median time | Buffer hits |
  | --- | --- | --- | --- |
  | Before index | Sort → Seq Scan | 2.231 ms | 274 |
  | After index | Sort → Bitmap Heap Scan → Bitmap Index Scan (`p2_filter_idx`) | 0.273 ms | 55 |

- **Conclusion:** the planner switched from a full sequential scan to the index, and the work for this lookup dropped by about 8×. Indexes also cost storage and write maintenance, and the timings apply only to this environment.
- Evidence: [query results](portfolio-2-query-optimisation/screenshots/Ukaegbu_Goodnews_301923986_P2_QueryResults.png) · [index comparison](portfolio-2-query-optimisation/screenshots/Ukaegbu_Goodnews_301923986_P2_IndexComparison.png). All six plans are in the [P2 README](portfolio-2-query-optimisation/Ukaegbu_Goodnews_301923986_P2_README.md).

---

## Portfolio 3: Transactions and Concurrency

**Folder:** [portfolio-3-transactions-concurrency](portfolio-3-transactions-concurrency/)

### Objective
Show atomicity (COMMIT/ROLLBACK), READ COMMITTED isolation, and how a lost update happens and how row locking prevents it.

### How it was implemented
1. [`P3_Transactions.sql`](portfolio-3-transactions-concurrency/Ukaegbu_Goodnews_301923986_P3_Transactions.sql) adds a temporary helper column, `p3_processed_count`, to `account`, with a CHECK that it stays ≥ 0. The real business columns are not changed.
2. **Commit:** a READ COMMITTED transaction adds 1 to the counter and commits.
3. **Rollback:** a second transaction adds 10, then deliberately sets the counter to −1. That breaks the CHECK constraint (SQLSTATE **23514**), aborts the transaction (later statements fail with **25P02**), and `ROLLBACK` undoes the +10 as well.
4. **Two-session exercise:** [`P3_SessionA.sql`](portfolio-3-transactions-concurrency/Ukaegbu_Goodnews_301923986_P3_SessionA.sql) and [`P3_SessionB.sql`](portfolio-3-transactions-concurrency/Ukaegbu_Goodnews_301923986_P3_SessionB.sql) are run side by side in two `psql` terminals, following steps 1–9:
   - **Steps 1–4, no locking:** both sessions read the counter (1), each calculates 2 and writes it.
   - **Step 5:** reset the counter to 1.
   - **Steps 6–9, with `SELECT … FOR UPDATE`:** Session A locks the row, and Session B's locking read **waits**. When A commits 2, B reads 2 and commits 3.

### How it was tested

| Check | Expected | Observed |
| --- | --- | --- |
| Counter after COMMIT | 1 | 1 |
| Uncommitted change seen by the other session | Hidden (0) | 0 |
| Counter after the failed transaction and ROLLBACK | 1 (the +10 is undone) | 1 |
| Two increments without locking | 3 | **2** (lost update) |
| Two increments with `SELECT FOR UPDATE` | 3 | **3** |
| Session B wait type during the locked run | Lock | Lock |

- Evidence: [commit/rollback](portfolio-3-transactions-concurrency/screenshots/Ukaegbu_Goodnews_301923986_P3_CommitRollback.png) · [concurrency result](portfolio-3-transactions-concurrency/screenshots/Ukaegbu_Goodnews_301923986_P3_ConcurrencyResult.png)

### How to reproduce
Run the Portfolio 1 schema and sample data, then `P3_Transactions.sql`. Open two `psql` terminals on the same database and run the numbered steps in order, switching between Session A and Session B. Run step 5 outside any transaction.

---

## Portfolio 4: NoSQL and Advanced Data Models

**Folder:** [portfolio-4-nosql](portfolio-4-nosql/)

### Objective
Model payment lifecycle events as MongoDB documents and compare the document approach with the relational design.

### How it was implemented
[`P4_MongoDB.js`](portfolio-4-nosql/Ukaegbu_Goodnews_301923986_P4_MongoDB.js) is a single `mongosh` script that:
1. switches to the `portfolio_nosql` database and stops if `payment_event` already exists, so it only runs on a fresh database
2. creates `payment_event` with a **`$jsonSchema` validator** (`validationLevel: strict`, `validationAction: error`). The validator requires `_id`, `schemaVersion`, `eventType` (`payment_requested` or `payment_settled`), `occurredAt` as a BSON `date`, a `source` with `payment_id`, and `embedded`, `references` and `details` objects.
3. inserts **4 event documents**, a requested and a settled event for each of payments 3001 and 3002. Each document embeds account and customer **snapshots** so it can be read on its own. The `details` field changes shape by event type.
4. creates a compound index, `event_type_time`, on `{eventType: 1, occurredAt: -1}`
5. runs 4 queries: a filter by event type, a nested-field query (`source.key.payment_id`), a date-range query using `ISODate`, and a `$group` aggregation counting events per type

### How it was tested

| Test | Expected | Observed |
| --- | --- | --- |
| Insert 4 valid events | 4 inserted | 4 |
| `eventType = payment_requested` | 2 documents | 2 |
| `source.key.payment_id = 3001` | 2 documents | 2 |
| `occurredAt` between 10:00 and 11:00 | 4 documents | 4 |
| `$group` by `eventType` | 2 groups of 2 | 2 groups of 2 |
| Insert with `occurredAt` as text | Rejected by the validator | Error **121** (DocumentValidationFailure) |
| Insert with a duplicate `_id` | Rejected by the unique `_id` index | Error **11000** (DuplicateKey) |
| Final document count | 4 | 4 |

- Evidence: [screenshots/…_P4_DocumentsAndQueries.png](portfolio-4-nosql/screenshots/Ukaegbu_Goodnews_301923986_P4_DocumentsAndQueries.png)
- Trade-off noted: embedded snapshots make each event self-contained, but they duplicate data and won't follow later SQL changes. PostgreSQL remains the system of record.

---

## Portfolio 5: Distributed and Cloud Database Exercise

**Folder:** [portfolio-5-distributed-cloud](portfolio-5-distributed-cloud/)

### Objective
Propose and justify a distributed, highly available deployment for the case's event data.

### How it was implemented
This activity uses the **discussion option**, so it is a written architecture rather than a live deployment ([P5 README](portfolio-5-distributed-cloud/Ukaegbu_Goodnews_301923986_P5_README.md), [diagram](portfolio-5-distributed-cloud/screenshots/Ukaegbu_Goodnews_301923986_P5_ProposedDesign.png)). It covers:
- **Topology:** a 3-member MongoDB replica set (1 primary, 2 secondaries) across 3 availability zones in one region, with PostgreSQL on its own managed high-availability setup
- **Availability:** oplog replication, primary elections that need a voting majority, writes pausing during an election, and why three containers on one machine don't count as high availability
- **Consistency:** majority write concern with a timeout, primary reads, majority read concern, secondary lag, and idempotency keys for retries. It also notes that there is no atomic transaction across PostgreSQL and MongoDB, so an outbox pattern would be needed.
- **Sharding:** when `payment_event` would need it, a hashed high-cardinality key compared with a time-based key, and the hot-spot and scatter-gather trade-offs
- **Cloud operations:** private networking, authentication, least privilege, TLS, monitoring, and tested backups, since replication also copies accidental deletes

### How it was validated
- The design was checked against the official MongoDB replication and sharding documentation (see References).
- **Limitation:** no cloud resources were provisioned and no failover, sharding or recovery test was run. The README states this openly.

---

## Evidence summary

| Portfolio | Key result |
| --- | --- |
| 1 | 24 of 24 invalid inserts rejected at the expected constraint; sample data unchanged |
| 2 | Median lookup time 2.231 ms → 0.273 ms after adding `p2_filter_idx`, with identical results |
| 3 | Lost update without locking (final value 2); correct result with `SELECT FOR UPDATE` (final value 3) |
| 4 | 4 documents inserted, 4 queries correct, invalid date (121) and duplicate ID (11000) rejected |
| 5 | Written replica-set, consistency and sharding design (discussion option, nothing deployed) |

Repository: https://github.com/Oziichukwu/Ukaegbu_Goodnews_301923986
