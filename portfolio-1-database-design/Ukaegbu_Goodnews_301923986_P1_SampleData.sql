-- Fictional sample records for Bank / Fintech Platform.
-- 3 customers, 4 accounts and 10 payments. Account 2004 deliberately has no payments.
BEGIN;
SET LOCAL standard_conforming_strings = on;
INSERT INTO portfolio."customer" ("customer_id", "legal_name", "opened_date", "status") VALUES
  (1001, 'Avery Morgan',    '2025-03-10', 'active'),
  (1002, 'Blessing Okafor', '2025-03-18', 'active'),
  (1003, 'Chen Wei Lim',    '2025-04-01', 'suspended');
INSERT INTO portfolio."account" ("account_id", "customer_id", "opened_date", "currency", "available_balance", "status") VALUES
  (2001, 1001, '2025-03-12', 'USD', 1250.75, 'open'),
  (2002, 1001, '2025-03-20', 'GBP',  640.00, 'open'),
  (2003, 1002, '2025-03-19', 'EUR', 3200.00, 'open'),
  (2004, 1003, '2025-04-02', 'USD',    0.00, 'frozen');
INSERT INTO portfolio."payment" ("payment_id", "account_id", "amount", "requested_at", "status", "external_reference", "beneficiary_label") VALUES
  (3001, 2001,  42.50, '2025-04-02T14:30:00Z', 'posted',  'EXT-001', 'Northwind Supplies'),
  (3002, 2001,  18.25, '2025-04-03T09:15:00Z', 'pending', NULL,      'Harbor Design'),
  (3003, 2001, 120.00, '2025-04-10T11:00:00Z', 'posted',  'EXT-002', 'Lakeside Utilities'),
  (3004, 2002,  75.40, '2025-04-05T08:45:00Z', 'posted',  'EXT-003', 'Brightline Rail'),
  (3005, 2002,  15.99, '2025-04-12T19:20:00Z', 'failed',  NULL,      'Streamly Media'),
  (3006, 2003, 950.00, '2025-04-06T10:00:00Z', 'posted',  'EXT-004', 'Cedar Property Rentals'),
  (3007, 2003,  64.30, '2025-04-08T16:05:00Z', 'posted',  NULL,      'Greenleaf Grocers'),
  (3008, 2003, 210.00, '2025-04-15T12:30:00Z', 'pending', 'EXT-005', 'Summit Insurance'),
  (3009, 2003,  32.75, '2025-05-02T09:10:00Z', 'posted',  'EXT-006', 'Metro Fuel'),
  (3010, 2001,  58.00, '2025-05-04T13:45:00Z', 'posted',  NULL,      'Harbor Design');
COMMIT;
