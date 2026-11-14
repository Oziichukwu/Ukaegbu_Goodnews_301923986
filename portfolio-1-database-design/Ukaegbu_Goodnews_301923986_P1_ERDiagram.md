# Bank / Fintech Platform — ER diagram

```mermaid
erDiagram
    direction LR
    customer {
        bigint customer_id PK
        text legal_name
        date opened_date
        text status "active | suspended | closed"
    }
    account {
        bigint account_id PK
        bigint customer_id FK
        date opened_date
        text currency "3-letter code"
        numeric available_balance ">= 0"
        text status "open | frozen | closed"
    }
    payment {
        bigint payment_id PK
        bigint account_id FK
        numeric amount "> 0"
        timestamptz requested_at
        text status "pending | posted | failed"
        text external_reference UK "optional; unique when not null"
        text beneficiary_label
    }
    customer ||--o{ account : "owns (customer_id)"
    account ||--o{ payment : "debited by (account_id)"
```

**Legend.** PK: primary key. FK: foreign key to another table. UK: unique value — here `external_reference` is unique only when it is not null (partial unique index `payment_reference_idempotent`). Quoted text after a field shows its CHECK rule or allowed values. The crow's-foot ends read: one customer owns zero or many accounts; one account is debited by zero or many payments; every account and payment has exactly one parent.

There are no composite keys in this design. Supporting indexes (`idx_account_customer_id`, `idx_payment_account_requested_at`) are listed in the [design](Ukaegbu_Goodnews_301923986_P1_Design.md#indexes).

[Diagram image](../images/Ukaegbu_Goodnews_301923986_ERDiagram.png)
