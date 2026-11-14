-- Concurrent payments from one account: Session B.
-- Follow the numbered steps in order across the Session A file and this file.

-- ============ Part 1: READ COMMITTED, read then write (no lock) ============

-- 2. Session B: read the balance before A writes (also 640.00, also "enough").
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT "account_id", "available_balance" FROM portfolio."account" WHERE "account_id" = 2002;

-- 4. Session B: write the value calculated from its stale read (240.00), record its payment
--    and commit. Both payments are posted but the balance only went down once.
UPDATE portfolio."account" SET "available_balance" = 240.00 WHERE "account_id" = 2002;
INSERT INTO portfolio."payment" ("payment_id", "account_id", "amount", "requested_at", "status", "external_reference", "beneficiary_label")
VALUES (3902, 2002, 400.00, '2025-06-01T10:00:01Z', 'posted', 'P3-RC-B', 'Concurrency test B');
COMMIT;
SELECT a."available_balance", count(p."payment_id") AS test_payments,
       coalesce(sum(p."amount"), 0) AS paid_out,
       640.00 - coalesce(sum(p."amount"), 0) AS balance_if_correct
FROM portfolio."account" a
LEFT JOIN portfolio."payment" p ON p."account_id" = a."account_id" AND p."payment_id" BETWEEN 3901 AND 3999
WHERE a."account_id" = 2002
GROUP BY a."available_balance";

-- ============ Part 2: READ COMMITTED with SELECT ... FOR UPDATE ============

-- 7. Session B: ask for the same row lock. This statement waits for Session A.
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT "account_id", "available_balance" FROM portfolio."account" WHERE "account_id" = 2002 FOR UPDATE;

-- 9. Session B: its locked read returned 240.00, which does not cover 400.00, so the
--    application rejects the payment and rolls back. Then check the outcome.
ROLLBACK;
SELECT a."available_balance", count(p."payment_id") AS test_payments,
       coalesce(sum(p."amount"), 0) AS paid_out,
       640.00 - coalesce(sum(p."amount"), 0) AS balance_if_correct
FROM portfolio."account" a
LEFT JOIN portfolio."payment" p ON p."account_id" = a."account_id" AND p."payment_id" BETWEEN 3901 AND 3999
WHERE a."account_id" = 2002
GROUP BY a."available_balance";

-- ============ Part 3: REPEATABLE READ, read then write (no explicit lock) ============

-- 12. Session B: read the balance in its own snapshot (640.00).
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT "account_id", "available_balance" FROM portfolio."account" WHERE "account_id" = 2002;

-- 14. Session B: try to write its stale value. A changed the row after B's snapshot,
--     so PostgreSQL refuses with SQLSTATE 40001 (serialization failure).
UPDATE portfolio."account" SET "available_balance" = 240.00 WHERE "account_id" = 2002;

-- 15. Session B: roll back and retry the whole transaction, as an application must
--     after a serialization failure. The new snapshot shows 240.00, so the payment is
--     rejected. Then check the outcome.
ROLLBACK;
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT "account_id", "available_balance" FROM portfolio."account" WHERE "account_id" = 2002;
ROLLBACK;
SELECT a."available_balance", count(p."payment_id") AS test_payments,
       coalesce(sum(p."amount"), 0) AS paid_out,
       640.00 - coalesce(sum(p."amount"), 0) AS balance_if_correct
FROM portfolio."account" a
LEFT JOIN portfolio."payment" p ON p."account_id" = a."account_id" AND p."payment_id" BETWEEN 3901 AND 3999
WHERE a."account_id" = 2002
GROUP BY a."available_balance";
