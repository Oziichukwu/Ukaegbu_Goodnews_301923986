# Bank / Fintech Platform — database design

My case study records customer, account, payment.

## Users

- Customers managing accounts and initiating payments
- Operations staff reviewing and reconciling payment activity

## Main operations

- Open a customer account
- Initiate and record a payment
- Review payments by account and time period

## Entities

| Entity | Information stored |
| --- | --- |
| customer | A synthetic customer who owns accounts. |
| account | An account owned by one customer, with a balance and currency. |
| payment | An outbound payment debited from one account. |

## customer

| Field | Type | Key | Required | Allowed values |
| --- | --- | --- | --- | --- |
| customer_id | BIGINT | PK | Yes | |
| legal_name | TEXT |  | Yes | |
| opened_date | DATE |  | Yes | |
| status | TEXT |  | Yes | active, suspended, closed |


## account

| Field | Type | Key | Required | Allowed values |
| --- | --- | --- | --- | --- |
| account_id | BIGINT | PK | Yes | |
| customer_id | BIGINT | FK | Yes | |
| opened_date | DATE |  | Yes | |
| currency | TEXT |  | Yes | three upper-case letters (ISO 4217 style, e.g. USD) |
| available_balance | NUMERIC(18,2) |  | Yes | ≥ 0 |
| status | TEXT |  | Yes | open, frozen, closed |
- customer_id → customer.customer_id

## payment

| Field | Type | Key | Required | Allowed values |
| --- | --- | --- | --- | --- |
| payment_id | BIGINT | PK | Yes | |
| account_id | BIGINT | FK | Yes | |
| amount | NUMERIC(18,2) |  | Yes | > 0 |
| requested_at | TIMESTAMPTZ |  | Yes | |
| status | TEXT |  | Yes | pending, posted, failed |
| external_reference | TEXT | UK (when not null) | No | |
| beneficiary_label | TEXT |  | Yes | |
- account_id → account.account_id

## Relationships and business rules

- Every account must reference an existing customer through customer_id.
- An account's available_balance must be greater than or equal to zero.
- Every payment must reference an existing account through account_id.
- A payment amount must be greater than zero.
- A non-null external_reference must be unique, enforced by a partial unique index where external_reference is not null.
- Status fields only accept the listed values (`customer_status_allowed`, `account_status_allowed`, `payment_status_allowed`).
- A currency must be a three-letter upper-case code (`account_currency_iso`).

## Indexes

| Index | Columns | Why |
| --- | --- | --- |
| pk_customer, pk_account, pk_payment | primary keys | Created automatically by the primary-key constraints. |
| payment_reference_idempotent | external_reference, where not null | Partial unique index: enforces the idempotency rule. |
| idx_account_customer_id | account.customer_id | PostgreSQL does not index foreign keys automatically. Supports "accounts for a customer" and the FK check when a customer row changes. |
| idx_payment_account_requested_at | payment.account_id, requested_at | Leading column covers the FK lookup on account_id; the second column supports "review payments by account and time period". |

## Assumptions

- All identifiers are synthetic BIGINT surrogate keys. The sample data uses separate ranges (customers 1001+, accounts 2001+, payments 3001+) so the IDs are easy to tell apart, but each key is only required to be unique within its own table.
- Each account belongs to one customer; each payment debits one account and uses that account's currency.
- Payments have positive amounts, and accounts cannot be overdrawn.
- A supplied external reference is an idempotency key and must be unique when non-null.
- A customer can exist without accounts, and an account can exist without payments (account 2004 in the sample data has none).
- For the normalisation exercise, the 1NF relation is one row per payment with its account and customer details; the 3NF design stores each entity's details once.
- Benchmark separately with 50,000 synthetic payments in Portfolio 2: compare a requested_at range filter, and an account + time-period filter, before and after adding B-tree indexes; record the measurements without assuming results.
