# Bank / Fintech Platform — ER diagram

```mermaid
erDiagram
    direction LR
    customer {
        bigint customer_id PK
        text legal_name
        date opened_date
        text status
    }
    account {
        bigint account_id PK
        bigint customer_id FK
        date opened_date
        text currency
        numeric available_balance
        text status
    }
    payment {
        bigint payment_id PK
        bigint account_id FK
        numeric amount
        timestamptz requested_at
        text status
        text external_reference "Optional"
        text beneficiary_label
    }
    customer ||--o{ account : "customer_id"
    account ||--o{ payment : "account_id"
```

PK identifies a record; FK links to another table; UK marks a single-field unique value. The relationship ends show exactly one, zero or one, or zero or many records. Composite unique keys and conditional rules are listed in the schema and design.

[Diagram image](../images/Ukaegbu_Goodnews_301923986_ERDiagram.png)
