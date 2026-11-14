# Portfolio 3 — Transactions and Concurrency

Two exercises. First, a temporary counter (p3_processed_count) on account, record {"account_id":2001}, tests COMMIT, ROLLBACK, READ COMMITTED visibility and a lost update without changing the original business fields. Second, the same problem in a real banking form: two payments drawn at the same time from one account, compared under three methods. A cleanup script then returns the database to the Portfolio 1 design.

All results below come from the raw output in [evidence/](evidence/) (PostgreSQL 16.15).

## Commit and rollback

| Stage | Counter |
| --- | --- |
| Before the first transaction (helper column default) | 0 |
| After transaction 1 (+1) and COMMIT | 1 |
| Inside transaction 2 after +10 (uncommitted) | 11 |
| Transaction 2 sets −1 | rejected: 23514 `p3_count_nonnegative` |
| Next statement in the failed transaction | rejected: 25P02 current transaction is aborted |
| After ROLLBACK | 1 |
| Other session while A's +1 was uncommitted (A saw 2) | 1 |

The CHECK error (23514) aborted the second transaction, and PostgreSQL refused every further statement (25P02) until ROLLBACK, which undid the +10 as well and restored the earlier committed value. READ COMMITTED kept the uncommitted change hidden from the other session: no dirty read.

## Two-session comparison: counter

| Method | Result | Expected |
| --- | --- | --- |
| Read, calculate and write | 2 | 3 |
| SELECT FOR UPDATE | 3 | 3 |

Both sessions first read 1. Without locking, both wrote 2 and one increment was lost. With SELECT FOR UPDATE, Session B waited for Session A (recorded wait: `wait_event_type=Lock`, `wait_event=transactionid`, blocked by Session A), read the updated value 2, and committed 3.

## Two-session comparison: concurrent payments from one account

Account 2002 starts at 640.00. Sessions A and B each try to pay 400.00; the application rule is "read the balance, and only if it covers the amount, write the new balance and record the payment". Only one payment can be honoured.

| Method | Final balance | Payments posted | Paid out | Correct balance for what was paid | Outcome |
| --- | --- | --- | --- | --- | --- |
| READ COMMITTED, read then write | 240.00 | 2 | 800.00 | −160.00 | **Double spend**: both sessions saw 640.00, both paid, and B's write overwrote A's, so 800.00 left an account that only ever went down by 400.00 |
| READ COMMITTED + `SELECT … FOR UPDATE` | 240.00 | 1 | 400.00 | 240.00 | B's locked read waited (`Lock`) until A committed, then returned 240.00; B rejected its payment |
| REPEATABLE READ, read then write | 240.00 | 1 | 400.00 | 240.00 | B's write failed with **40001** "could not serialize access due to concurrent update"; B rolled back, retried, saw 240.00 and rejected its payment |

The account CHECK (`available_balance >= 0`) did not catch the double spend, because each session wrote a valid-looking 240.00. Constraints protect each row on its own; concurrency control is what protects the read-then-write logic. The two safe methods differ in style: `FOR UPDATE` is pessimistic (B waits), REPEATABLE READ is optimistic (B fails fast and the application must retry). A third safe pattern, not run here, is a single conditional statement such as `UPDATE … SET available_balance = available_balance - 400 WHERE account_id = 2002 AND available_balance >= 400`, which checks and writes atomically.

## Cleanup

`P3_Cleanup.sql` drops the helper column and its CHECK, deletes the test payments (IDs 3901–3999) and restores account 2002. Afterwards account has its six original columns again and the row counts are back to 3 customers, 4 accounts and 10 payments, with account 2002 at 640.00.

## Files and order

Run the Portfolio 1 schema and sample data in a fresh database, then:

1. `Ukaegbu_Goodnews_301923986_P3_Transactions.sql` with psql (single session).
2. Open two psql terminals connected to the same database. Follow steps 1–12 across `P3_SessionA.sql` and `P3_SessionB.sql`; run step 8 in Session A outside a transaction.
3. In the same two terminals, follow steps 1–15 across `P3_Payments_SessionA.sql` and `P3_Payments_SessionB.sql`; steps 5 and 10 (resets) run outside a transaction.
4. `Ukaegbu_Goodnews_301923986_P3_Cleanup.sql`.

`run_all.sh` does all of this automatically. For the two-session files it uses [`tools/two_session_driver.py`](../tools/two_session_driver.py), which opens two real connections and replays the numbered steps from the files in order, exactly as two psql terminals would. When a step does not finish within 1.5 s it records that the session is blocked and reads its wait event from `pg_stat_activity`.

- [Transactions](Ukaegbu_Goodnews_301923986_P3_Transactions.sql)
- [Session A](Ukaegbu_Goodnews_301923986_P3_SessionA.sql) · [Session B](Ukaegbu_Goodnews_301923986_P3_SessionB.sql)
- [Payments Session A](Ukaegbu_Goodnews_301923986_P3_Payments_SessionA.sql) · [Payments Session B](Ukaegbu_Goodnews_301923986_P3_Payments_SessionB.sql)
- [Cleanup](Ukaegbu_Goodnews_301923986_P3_Cleanup.sql)
- Screenshots: [commit and rollback](screenshots/Ukaegbu_Goodnews_301923986_P3_CommitRollback.png) · [concurrency](screenshots/Ukaegbu_Goodnews_301923986_P3_ConcurrencyResult.png) · [concurrent payments](screenshots/Ukaegbu_Goodnews_301923986_P3_DoubleSpend.png)
- Raw output: [transactions](evidence/Ukaegbu_Goodnews_301923986_P3_Transactions.txt) · [counter sessions](evidence/Ukaegbu_Goodnews_301923986_P3_CounterSessions.txt) · [payment sessions](evidence/Ukaegbu_Goodnews_301923986_P3_PaymentSessions.txt) · [cleanup](evidence/Ukaegbu_Goodnews_301923986_P3_Cleanup.txt)

## References

- [PostgreSQL — transaction isolation](https://www.postgresql.org/docs/16/transaction-iso.html)
- [PostgreSQL — row locks](https://www.postgresql.org/docs/16/explicit-locking.html)
