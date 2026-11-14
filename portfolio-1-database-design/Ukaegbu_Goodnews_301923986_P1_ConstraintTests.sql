-- Run these deliberately invalid statements one at a time, outside a transaction.
-- Each should fail at the named constraint; the sample rows should remain unchanged.

-- 1. customer pk. Expected: pk_customer, SQLSTATE 23505.
INSERT INTO portfolio."customer" ("customer_id", "legal_name", "opened_date", "status")
VALUES (1001, 'Jordan Lee', '2025-05-01', 'active');

-- 2. account pk. Expected: pk_account, SQLSTATE 23505.
INSERT INTO portfolio."account" ("account_id", "customer_id", "opened_date", "currency", "available_balance", "status")
VALUES (2001, 1001, '2025-05-01', 'USD', 100, 'open');

-- 3. payment pk. Expected: pk_payment, SQLSTATE 23505.
INSERT INTO portfolio."payment" ("payment_id", "account_id", "amount", "requested_at", "status", "external_reference", "beneficiary_label")
VALUES (3001, 2001, 1, '2025-05-01T10:00:00Z', 'pending', NULL, 'Fresh Beneficiary');

-- 4. account fk. Expected: fk_account_0, SQLSTATE 23503.
INSERT INTO portfolio."account" ("account_id", "customer_id", "opened_date", "currency", "available_balance", "status")
VALUES (920001, 999001, '2025-05-02', 'USD', 100, 'open');

-- 5. payment fk. Expected: fk_payment_0, SQLSTATE 23503.
INSERT INTO portfolio."payment" ("payment_id", "account_id", "amount", "requested_at", "status", "external_reference", "beneficiary_label")
VALUES (930001, 999002, 1, '2025-05-02T10:00:00Z', 'pending', NULL, 'Fresh Beneficiary');

-- 6. customer nn customer id. Expected: customer_id, SQLSTATE 23502.
INSERT INTO portfolio."customer" ("customer_id", "legal_name", "opened_date", "status")
VALUES (NULL, 'Jordan Lee', '2025-05-03', 'active');

-- 7. customer nn legal name. Expected: legal_name, SQLSTATE 23502.
INSERT INTO portfolio."customer" ("customer_id", "legal_name", "opened_date", "status")
VALUES (910102, NULL, '2025-05-03', 'active');

-- 8. customer nn opened date. Expected: opened_date, SQLSTATE 23502.
INSERT INTO portfolio."customer" ("customer_id", "legal_name", "opened_date", "status")
VALUES (910103, 'Jordan Lee', NULL, 'active');

-- 9. customer nn status. Expected: status, SQLSTATE 23502.
INSERT INTO portfolio."customer" ("customer_id", "legal_name", "opened_date", "status")
VALUES (910104, 'Jordan Lee', '2025-05-03', NULL);

-- 10. account nn account id. Expected: account_id, SQLSTATE 23502.
INSERT INTO portfolio."account" ("account_id", "customer_id", "opened_date", "currency", "available_balance", "status")
VALUES (NULL, 1001, '2025-05-04', 'USD', 100, 'open');

-- 11. account nn customer id. Expected: customer_id, SQLSTATE 23502.
INSERT INTO portfolio."account" ("account_id", "customer_id", "opened_date", "currency", "available_balance", "status")
VALUES (920102, NULL, '2025-05-04', 'USD', 100, 'open');

-- 12. account nn opened date. Expected: opened_date, SQLSTATE 23502.
INSERT INTO portfolio."account" ("account_id", "customer_id", "opened_date", "currency", "available_balance", "status")
VALUES (920103, 1001, NULL, 'USD', 100, 'open');

-- 13. account nn currency. Expected: currency, SQLSTATE 23502.
INSERT INTO portfolio."account" ("account_id", "customer_id", "opened_date", "currency", "available_balance", "status")
VALUES (920104, 1001, '2025-05-04', NULL, 100, 'open');

-- 14. account nn available balance. Expected: available_balance, SQLSTATE 23502.
INSERT INTO portfolio."account" ("account_id", "customer_id", "opened_date", "currency", "available_balance", "status")
VALUES (920105, 1001, '2025-05-04', 'USD', NULL, 'open');

-- 15. account nn status. Expected: status, SQLSTATE 23502.
INSERT INTO portfolio."account" ("account_id", "customer_id", "opened_date", "currency", "available_balance", "status")
VALUES (920106, 1001, '2025-05-04', 'USD', 100, NULL);

-- 16. payment nn payment id. Expected: payment_id, SQLSTATE 23502.
INSERT INTO portfolio."payment" ("payment_id", "account_id", "amount", "requested_at", "status", "external_reference", "beneficiary_label")
VALUES (NULL, 2001, 1, '2025-05-05T10:00:00Z', 'pending', NULL, 'Fresh Beneficiary');

-- 17. payment nn account id. Expected: account_id, SQLSTATE 23502.
INSERT INTO portfolio."payment" ("payment_id", "account_id", "amount", "requested_at", "status", "external_reference", "beneficiary_label")
VALUES (930102, NULL, 1, '2025-05-05T10:00:00Z', 'pending', NULL, 'Fresh Beneficiary');

-- 18. payment nn amount. Expected: amount, SQLSTATE 23502.
INSERT INTO portfolio."payment" ("payment_id", "account_id", "amount", "requested_at", "status", "external_reference", "beneficiary_label")
VALUES (930103, 2001, NULL, '2025-05-05T10:00:00Z', 'pending', NULL, 'Fresh Beneficiary');

-- 19. payment nn requested at. Expected: requested_at, SQLSTATE 23502.
INSERT INTO portfolio."payment" ("payment_id", "account_id", "amount", "requested_at", "status", "external_reference", "beneficiary_label")
VALUES (930104, 2001, 1, NULL, 'pending', NULL, 'Fresh Beneficiary');

-- 20. payment nn status. Expected: status, SQLSTATE 23502.
INSERT INTO portfolio."payment" ("payment_id", "account_id", "amount", "requested_at", "status", "external_reference", "beneficiary_label")
VALUES (930105, 2001, 1, '2025-05-05T10:00:00Z', NULL, NULL, 'Fresh Beneficiary');

-- 21. payment nn beneficiary label. Expected: beneficiary_label, SQLSTATE 23502.
INSERT INTO portfolio."payment" ("payment_id", "account_id", "amount", "requested_at", "status", "external_reference", "beneficiary_label")
VALUES (930106, 2001, 1, '2025-05-05T10:00:00Z', 'pending', NULL, NULL);

-- 22. account balance check. Expected: account_nonnegative_balance, SQLSTATE 23514.
INSERT INTO portfolio."account" ("account_id", "customer_id", "opened_date", "currency", "available_balance", "status")
VALUES (920201, 1001, '2025-05-06', 'USD', -1, 'open');

-- 23. payment amount check. Expected: payment_positive_amount, SQLSTATE 23514.
INSERT INTO portfolio."payment" ("payment_id", "account_id", "amount", "requested_at", "status", "external_reference", "beneficiary_label")
VALUES (930201, 2001, 0, '2025-05-06T10:00:00Z', 'pending', NULL, 'Fresh Beneficiary');

-- 24. payment reference partial unique. Expected: payment_reference_idempotent, SQLSTATE 23505.
INSERT INTO portfolio."payment" ("payment_id", "account_id", "amount", "requested_at", "status", "external_reference", "beneficiary_label")
VALUES (930202, 2001, 1, '2025-05-07T10:00:00Z', 'pending', 'EXT-001', 'Fresh Beneficiary');
