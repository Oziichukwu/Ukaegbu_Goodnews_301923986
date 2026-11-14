-- Read-only checks run after the schema, sample data and constraint tests.

-- 1. Row counts: the invalid inserts must not have changed the sample data.
SELECT 'customer' AS table_name, count(*) AS row_count FROM portfolio."customer"
UNION ALL SELECT 'account', count(*) FROM portfolio."account"
UNION ALL SELECT 'payment', count(*) FROM portfolio."payment";

-- 2. Declared constraints, read from the system catalog.
SELECT conrelid::regclass AS table_name, conname AS constraint_name,
       CASE contype WHEN 'p' THEN 'primary key' WHEN 'f' THEN 'foreign key'
                    WHEN 'c' THEN 'check' WHEN 'u' THEN 'unique' END AS constraint_type
FROM pg_constraint
WHERE connamespace = 'portfolio'::regnamespace AND contype IN ('p', 'f', 'c', 'u')
ORDER BY conrelid::regclass::text, constraint_type, constraint_name;

-- 3. Indexes, including the partial unique index and the foreign-key indexes.
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'portfolio'
ORDER BY tablename, indexname;

-- 4. Normalisation check. Build the 1NF relation as a stand-alone table (one row per
--    payment, repeating its account and customer details), decompose it by projection
--    into the three 3NF relations, then join them back. A lossless decomposition gives
--    exactly the original rows, so both EXCEPT counts must be 0.
CREATE TEMP TABLE first_normal_form AS
SELECT p.payment_id, p.amount, p.requested_at, p.status AS payment_status,
       p.external_reference, p.beneficiary_label,
       a.account_id, a.currency, a.available_balance, a.status AS account_status, a.opened_date AS account_opened,
       c.customer_id, c.legal_name, c.status AS customer_status, c.opened_date AS customer_opened
FROM portfolio."payment" p
JOIN portfolio."account" a USING (account_id)
JOIN portfolio."customer" c USING (customer_id);

CREATE TEMP TABLE nf3_customer AS
SELECT DISTINCT customer_id, legal_name, customer_status, customer_opened FROM first_normal_form;
CREATE TEMP TABLE nf3_account AS
SELECT DISTINCT account_id, customer_id, currency, available_balance, account_status, account_opened FROM first_normal_form;
CREATE TEMP TABLE nf3_payment AS
SELECT DISTINCT payment_id, account_id, amount, requested_at, payment_status, external_reference, beneficiary_label FROM first_normal_form;

CREATE TEMP VIEW rejoined AS
SELECT p.payment_id, p.amount, p.requested_at, p.payment_status, p.external_reference, p.beneficiary_label,
       a.account_id, a.currency, a.available_balance, a.account_status, a.account_opened,
       c.customer_id, c.legal_name, c.customer_status, c.customer_opened
FROM nf3_payment p JOIN nf3_account a USING (account_id) JOIN nf3_customer c USING (customer_id);

SELECT (SELECT count(*) FROM first_normal_form) AS rows_1nf,
       (SELECT count(*) FROM nf3_customer) AS rows_customer,
       (SELECT count(*) FROM nf3_account) AS rows_account,
       (SELECT count(*) FROM nf3_payment) AS rows_payment,
       (SELECT count(*) FROM rejoined) AS rows_rejoined,
       (SELECT count(*) FROM (SELECT * FROM first_normal_form EXCEPT SELECT * FROM rejoined) d) AS missing_after_join,
       (SELECT count(*) FROM (SELECT * FROM rejoined EXCEPT SELECT * FROM first_normal_form) d) AS extra_after_join;

-- 5. Redundancy in the 1NF form: how often each customer's name would be repeated.
SELECT customer_id, legal_name, count(*) AS times_repeated_in_1nf
FROM first_normal_form
GROUP BY customer_id, legal_name
ORDER BY customer_id;

-- 6. Rows the 1NF form cannot hold: accounts (and customers) without any payment.
SELECT a.account_id, a.customer_id, a.status
FROM portfolio."account" a
WHERE NOT EXISTS (SELECT 1 FROM portfolio."payment" p WHERE p.account_id = a.account_id);
