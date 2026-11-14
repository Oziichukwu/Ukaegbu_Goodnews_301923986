-- Concurrent payments from one account: Session A.
-- Use two psql terminals connected to the same exercise database and follow the
-- numbered steps in order across this file and the Session B file.
-- Account 2002 starts with available_balance 640.00. Each session tries to pay 400.00,
-- so only one of the two payments can be honoured. The application rule is:
-- read the balance, and only if it covers the amount, write the new balance and the payment.

-- ============ Part 1: READ COMMITTED, read then write (no lock) ============

-- 1. Session A: read the balance (640.00, enough for 400.00).
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT "account_id", "available_balance" FROM portfolio."account" WHERE "account_id" = 2002;

-- 3. Session A: write 640.00 - 400.00 = 240.00, record the payment and commit.
UPDATE portfolio."account" SET "available_balance" = 240.00 WHERE "account_id" = 2002;
INSERT INTO portfolio."payment" ("payment_id", "account_id", "amount", "requested_at", "status", "external_reference", "beneficiary_label")
VALUES (3901, 2002, 400.00, '2025-06-01T10:00:00Z', 'posted', 'P3-RC-A', 'Concurrency test A');
COMMIT;

-- 5. Reset for Part 2 (outside any transaction): remove the test payments, restore 640.00.
DELETE FROM portfolio."payment" WHERE "payment_id" BETWEEN 3901 AND 3999;
UPDATE portfolio."account" SET "available_balance" = 640.00 WHERE "account_id" = 2002;

-- ============ Part 2: READ COMMITTED with SELECT ... FOR UPDATE ============

-- 6. Session A: lock the account row while reading the balance (640.00).
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT "account_id", "available_balance" FROM portfolio."account" WHERE "account_id" = 2002 FOR UPDATE;

-- 8. Session A: write 240.00, record the payment and commit, which releases the lock.
UPDATE portfolio."account" SET "available_balance" = 240.00 WHERE "account_id" = 2002;
INSERT INTO portfolio."payment" ("payment_id", "account_id", "amount", "requested_at", "status", "external_reference", "beneficiary_label")
VALUES (3903, 2002, 400.00, '2025-06-01T10:00:00Z', 'posted', 'P3-LOCK-A', 'Concurrency test A');
COMMIT;

-- 10. Reset for Part 3 (outside any transaction).
DELETE FROM portfolio."payment" WHERE "payment_id" BETWEEN 3901 AND 3999;
UPDATE portfolio."account" SET "available_balance" = 640.00 WHERE "account_id" = 2002;

-- ============ Part 3: REPEATABLE READ, read then write (no explicit lock) ============

-- 11. Session A: read the balance in a REPEATABLE READ snapshot (640.00).
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT "account_id", "available_balance" FROM portfolio."account" WHERE "account_id" = 2002;

-- 13. Session A: write 240.00, record the payment and commit.
UPDATE portfolio."account" SET "available_balance" = 240.00 WHERE "account_id" = 2002;
INSERT INTO portfolio."payment" ("payment_id", "account_id", "amount", "requested_at", "status", "external_reference", "beneficiary_label")
VALUES (3905, 2002, 400.00, '2025-06-01T10:00:00Z', 'posted', 'P3-RR-A', 'Concurrency test A');
COMMIT;
