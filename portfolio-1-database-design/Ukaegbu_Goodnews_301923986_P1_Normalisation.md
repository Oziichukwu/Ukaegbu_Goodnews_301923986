# Bank / Fintech Platform — normalisation

This walk-through uses the saved sample data (3 customers, 4 accounts, 10 payments). The full set of fields is in the [design](Ukaegbu_Goodnews_301923986_P1_Design.md) and [schema](Ukaegbu_Goodnews_301923986_P1_Schema.sql). The checks quoted here come from [`P1_Verify.sql`](Ukaegbu_Goodnews_301923986_P1_Verify.sql); the raw output is in [evidence/…_P1_Verify.txt](evidence/Ukaegbu_Goodnews_301923986_P1_Verify.txt).

## Starting point: unnormalised records (UNF)

Before any design, a statement-style record keeps one row per customer, with the customer's accounts and their payments packed into repeating groups.

| customer_id | legal_name | customer_status | accounts (repeating group) | payments (repeating group) |
| --- | --- | --- | --- | --- |
| 1001 | Avery Morgan | active | 2001 USD 1250.75 open; 2002 GBP 640.00 open | 3001 (2001) 42.50 posted; 3002 (2001) 18.25 pending; 3003 (2001) 120.00 posted; 3010 (2001) 58.00 posted; 3004 (2002) 75.40 posted; 3005 (2002) 15.99 failed |
| 1002 | Blessing Okafor | active | 2003 EUR 3200.00 open | 3006 (2003) 950.00 posted; 3007 (2003) 64.30 posted; 3008 (2003) 210.00 pending; 3009 (2003) 32.75 posted |
| 1003 | Chen Wei Lim | suspended | 2004 USD 0.00 frozen | — |

Cells hold lists, so a single payment cannot be selected, constrained or indexed on its own.

## 1NF: one value per cell

Flattening the repeating groups gives one row per payment, repeating the account and customer details on every row. Each row is identified by **payment_id**.

| payment_id | account_id | currency | available_balance | account_status | customer_id | legal_name | customer_status | amount | requested_at (UTC) | payment_status | external_reference | beneficiary_label |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 3001 | 2001 | USD | 1250.75 | open | 1001 | Avery Morgan | active | 42.50 | 2025-04-02 14:30 | posted | EXT-001 | Northwind Supplies |
| 3002 | 2001 | USD | 1250.75 | open | 1001 | Avery Morgan | active | 18.25 | 2025-04-03 09:15 | pending | NULL | Harbor Design |
| 3003 | 2001 | USD | 1250.75 | open | 1001 | Avery Morgan | active | 120.00 | 2025-04-10 11:00 | posted | EXT-002 | Lakeside Utilities |
| 3004 | 2002 | GBP | 640.00 | open | 1001 | Avery Morgan | active | 75.40 | 2025-04-05 08:45 | posted | EXT-003 | Brightline Rail |
| 3005 | 2002 | GBP | 640.00 | open | 1001 | Avery Morgan | active | 15.99 | 2025-04-12 19:20 | failed | NULL | Streamly Media |
| 3006 | 2003 | EUR | 3200.00 | open | 1002 | Blessing Okafor | active | 950.00 | 2025-04-06 10:00 | posted | EXT-004 | Cedar Property Rentals |
| 3007 | 2003 | EUR | 3200.00 | open | 1002 | Blessing Okafor | active | 64.30 | 2025-04-08 16:05 | posted | NULL | Greenleaf Grocers |
| 3008 | 2003 | EUR | 3200.00 | open | 1002 | Blessing Okafor | active | 210.00 | 2025-04-15 12:30 | pending | EXT-005 | Summit Insurance |
| 3009 | 2003 | EUR | 3200.00 | open | 1002 | Blessing Okafor | active | 32.75 | 2025-05-02 09:10 | posted | EXT-006 | Metro Fuel |
| 3010 | 2001 | USD | 1250.75 | open | 1001 | Avery Morgan | active | 58.00 | 2025-05-04 13:45 | posted | NULL | Harbor Design |

(The opened dates of the account and customer are also carried on every row; they are left out of the table above to keep it readable.)

### Problems still present in 1NF

| Anomaly | Example from the sample data (measured by `P1_Verify.sql`) |
| --- | --- |
| Redundancy / update anomaly | "Avery Morgan" is stored on **6** rows and "Blessing Okafor" on **4**. Changing a name or an account balance means updating every one of those rows; missing one leaves contradictory data. |
| Insertion anomaly | Customer 1003 and account 2004 have **no payments**, so they cannot be stored at all — the 1NF relation holds only **2 of 3** customers and **3 of 4** accounts. |
| Deletion anomaly | Deleting the last payment of an account would also delete the only record of that account and its customer. |

## Functional dependencies

- payment_id → account_id, amount, requested_at, payment_status, external_reference, beneficiary_label
- account_id → customer_id, currency, available_balance, account_status, account_opened
- customer_id → legal_name, customer_status, customer_opened
- external_reference → payment_id (only when external_reference is not null)

## 2NF: depend on the whole key

The 1NF key is the single attribute payment_id, so no attribute can depend on only part of the key: the relation is already in 2NF. (If the flattened rows were instead identified by the pair (account_id, payment_id), the account details would depend on account_id alone — a partial dependency — and 2NF would move them into an account relation, leading to the same result as the next step.)

## 3NF: remove transitive dependencies

In the 1NF relation the account details depend on the key only through account_id (payment_id → account_id → currency, balance, …), and the customer details through customer_id (account_id → customer_id → legal_name, …). These are transitive dependencies. 3NF moves each determinant and its dependants into their own relation and keeps the determinant as a foreign key:

### customer

| customer_id | legal_name | opened_date | status |
| --- | --- | --- | --- |
| 1001 | Avery Morgan | 2025-03-10 | active |
| 1002 | Blessing Okafor | 2025-03-18 | active |
| 1003 | Chen Wei Lim | 2025-04-01 | suspended |

### account

| account_id | customer_id | opened_date | currency | available_balance | status |
| --- | --- | --- | --- | --- | --- |
| 2001 | 1001 | 2025-03-12 | USD | 1250.75 | open |
| 2002 | 1001 | 2025-03-20 | GBP | 640.00 | open |
| 2003 | 1002 | 2025-03-19 | EUR | 3200.00 | open |
| 2004 | 1003 | 2025-04-02 | USD | 0.00 | frozen |

### payment

| payment_id | account_id | amount | requested_at (UTC) | status | external_reference | beneficiary_label |
| --- | --- | --- | --- | --- | --- | --- |
| 3001 | 2001 | 42.50 | 2025-04-02 14:30 | posted | EXT-001 | Northwind Supplies |
| 3002 | 2001 | 18.25 | 2025-04-03 09:15 | pending | NULL | Harbor Design |
| 3003 | 2001 | 120.00 | 2025-04-10 11:00 | posted | EXT-002 | Lakeside Utilities |
| 3004 | 2002 | 75.40 | 2025-04-05 08:45 | posted | EXT-003 | Brightline Rail |
| 3005 | 2002 | 15.99 | 2025-04-12 19:20 | failed | NULL | Streamly Media |
| 3006 | 2003 | 950.00 | 2025-04-06 10:00 | posted | EXT-004 | Cedar Property Rentals |
| 3007 | 2003 | 64.30 | 2025-04-08 16:05 | posted | NULL | Greenleaf Grocers |
| 3008 | 2003 | 210.00 | 2025-04-15 12:30 | pending | EXT-005 | Summit Insurance |
| 3009 | 2003 | 32.75 | 2025-05-02 09:10 | posted | EXT-006 | Metro Fuel |
| 3010 | 2001 | 58.00 | 2025-05-04 13:45 | posted | NULL | Harbor Design |

Every non-key attribute now depends on the key, the whole key and nothing but the key. The three anomalies are gone: each name and balance is stored once, customer 1003 and account 2004 can exist without payments, and deleting a payment leaves its account and customer in place.

## Lossless-join check

`P1_Verify.sql` builds the 1NF relation as a stand-alone table, decomposes it by projection into the three relations above, and joins them back:

| 1NF rows | customer rows | account rows | payment rows | rows after re-join | missing after join | extra after join |
| --- | --- | --- | --- | --- | --- | --- |
| 10 | 2 | 3 | 10 | 10 | 0 | 0 |

The join reproduces exactly the original 10 rows, so the decomposition loses no information. The projection yields only 2 customers and 3 accounts, which confirms the insertion anomaly above: the rows for customer 1003 and account 2004 only exist in the normalised design.
