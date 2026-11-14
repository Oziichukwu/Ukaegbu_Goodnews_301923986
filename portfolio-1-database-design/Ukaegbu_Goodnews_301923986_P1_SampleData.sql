-- Fictional sample records for Bank / Fintech Platform.
BEGIN;
SET LOCAL standard_conforming_strings = on;
INSERT INTO portfolio."customer" ("customer_id", "legal_name", "opened_date", "status") VALUES (1001, 'Avery Morgan', '2025-03-10', 'active');
INSERT INTO portfolio."account" ("account_id", "customer_id", "opened_date", "currency", "available_balance", "status") VALUES (2001, 1001, '2025-03-12', 'USD', 1250.75, 'open');
INSERT INTO portfolio."payment" ("payment_id", "account_id", "amount", "requested_at", "status", "external_reference", "beneficiary_label") VALUES (3001, 2001, 42.5, '2025-04-02T14:30:00Z', 'posted', 'EXT-001', 'Northwind Supplies');
INSERT INTO portfolio."payment" ("payment_id", "account_id", "amount", "requested_at", "status", "external_reference", "beneficiary_label") VALUES (3002, 2001, 18.25, '2025-04-03T09:15:00+00:00', 'pending', NULL, 'Harbor Design');
COMMIT;
