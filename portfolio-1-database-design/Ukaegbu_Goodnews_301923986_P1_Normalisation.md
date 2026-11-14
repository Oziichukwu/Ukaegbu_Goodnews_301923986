# Bank / Fintech Platform — normalisation

The example uses the saved sample records. The full set of fields is in the design and schema.

## Starting grouped records

| customer_id | account records (list) |
| --- | --- |
| 1001 | [2001] |


The record IDs are grouped in a list. In 1NF, each record has its own row and each cell holds one value.

## 1NF: one value per cell

| account.account_id | account.customer_id | account.currency | customer.customer_id | customer.legal_name |
| --- | --- | --- | --- | --- |
| 2001 | 1001 | USD | 1001 | Avery Morgan |

Key: account_id.

## 2NF: depend on the whole key

The declared candidate keys do not introduce a partial dependency here, so the 1NF rows stay unchanged at this step.

## account_example

| account.account_id | account.customer_id | account.currency | customer.customer_id | customer.legal_name |
| --- | --- | --- | --- | --- |
| 2001 | 1001 | USD | 1001 | Avery Morgan |

## 3NF: store each entity’s details once

The entity keys determine their own descriptions. Related records keep foreign keys rather than repeating those descriptions.

## customer

| customer_id | legal_name | opened_date | status |
| --- | --- | --- | --- |
| 1001 | Avery Morgan | 2025-03-10 | active |

## account

| account_id | customer_id | opened_date | currency | available_balance | status |
| --- | --- | --- | --- | --- | --- |
| 2001 | 1001 | 2025-03-12 | USD | 1250.75 | open |

## payment

| payment_id | account_id | amount | requested_at | status | external_reference | beneficiary_label |
| --- | --- | --- | --- | --- | --- | --- |
| 3001 | 2001 | 42.5 | 2025-04-02T14:30:00+00:00 | posted | EXT-001 | Northwind Supplies |
| 3002 | 2001 | 18.25 | 2025-04-03T09:15:00+00:00 | pending | NULL | Harbor Design |

## Dependencies

- customer: (customer_id) → legal_name, opened_date, status
- account: (account_id) → customer_id, opened_date, currency, available_balance, status
- payment: (payment_id) → account_id, amount, requested_at, status, external_reference, beneficiary_label

Joining the decomposed sample tables reproduces the original 1 example rows. The design assumes the declared keys describe the relevant business dependencies.
