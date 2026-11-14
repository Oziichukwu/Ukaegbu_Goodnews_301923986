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

| Field | Type | Key | Required |
| --- | --- | --- | --- |
| customer_id | BIGINT | PK | Yes |
| legal_name | TEXT |  | Yes |
| opened_date | DATE |  | Yes |
| status | TEXT |  | Yes |


## account

| Field | Type | Key | Required |
| --- | --- | --- | --- |
| account_id | BIGINT | PK | Yes |
| customer_id | BIGINT | FK | Yes |
| opened_date | DATE |  | Yes |
| currency | TEXT |  | Yes |
| available_balance | NUMERIC(18,2) |  | Yes |
| status | TEXT |  | Yes |
- customer_id → customer.customer_id

## payment

| Field | Type | Key | Required |
| --- | --- | --- | --- |
| payment_id | BIGINT | PK | Yes |
| account_id | BIGINT | FK | Yes |
| amount | NUMERIC(18,2) |  | Yes |
| requested_at | TIMESTAMPTZ |  | Yes |
| status | TEXT |  | Yes |
| external_reference | TEXT |  | No |
| beneficiary_label | TEXT |  | Yes |
- account_id → account.account_id

## Relationships and business rules

- Every account must reference an existing customer through customer_id.
- An account's available_balance must be greater than or equal to zero.
- Every payment must reference an existing account through account_id.
- A payment amount must be greater than zero.
- A non-null external_reference must be unique, enforced by a partial unique index where external_reference is not null.

## Assumptions

- All identifiers are synthetic UUIDs allocated from a shared namespace, so primary-key values are globally unique across these entities.
- Each account belongs to one customer; each payment debits one account and uses that account's currency.
- Payments have positive amounts, and accounts cannot be overdrawn.
- A supplied external reference is an idempotency key and must be unique when non-null.
- For a simple normalization exercise, use account as the root relation: account.customer_id references customer, so customer attributes belong in customer rather than being repeated in account; this example follows only the account-to-customer relationship.
- Benchmark separately with 50000 synthetic payments: compare the same requested_at range filter before and after adding a B-tree index; record measurements in the exercise without assuming results.

