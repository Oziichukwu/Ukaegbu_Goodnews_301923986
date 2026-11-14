-- Portfolio 3 cleanup: return the database to the Portfolio 1 design.
-- Removes the temporary counter column and the test payments, and restores account 2002.
BEGIN;
ALTER TABLE portfolio."account" DROP CONSTRAINT IF EXISTS "p3_count_nonnegative";
ALTER TABLE portfolio."account" DROP COLUMN IF EXISTS "p3_processed_count";
DELETE FROM portfolio."payment" WHERE "payment_id" BETWEEN 3901 AND 3999;
UPDATE portfolio."account" SET "available_balance" = 640.00 WHERE "account_id" = 2002;
COMMIT;

-- Check: account has its six original columns again, and the row counts match Portfolio 1.
SELECT string_agg(column_name, ', ' ORDER BY ordinal_position) AS account_columns
FROM information_schema.columns
WHERE table_schema = 'portfolio' AND table_name = 'account';

SELECT (SELECT count(*) FROM portfolio."customer") AS customers,
       (SELECT count(*) FROM portfolio."account") AS accounts,
       (SELECT count(*) FROM portfolio."payment") AS payments,
       (SELECT "available_balance" FROM portfolio."account" WHERE "account_id" = 2002) AS balance_2002;
