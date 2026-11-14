# Portfolio 4 — NoSQL and Advanced Data Models

I used MongoDB collection payment_event for the lifecycle of each payment: payment_requested, then payment_settled or payment_failed. The events are built from the Portfolio 1 sample data (same payment, account and customer IDs and values), so the two models can be compared directly. All results below come from [evidence/…_P4_MongoDB.txt](evidence/Ukaegbu_Goodnews_301923986_P4_MongoDB.txt) (MongoDB 8.0.23).

## Document model

| Field | Meaning |
| --- | --- |
| _id | Unique string event ID, numbered in time order |
| schemaVersion | Version of the document shape (2) |
| eventType | payment_requested, payment_settled or payment_failed |
| occurredAt | Native BSON Date |
| source | Original entity, primary key and a snapshot of the payment as it was at the event |
| embedded | Snapshots of the linked account and customer, read together with the event |
| references | account_id and customer_id, to join back to PostgreSQL if needed |
| details | Event metadata whose fields vary by event type (settlement_reference, failure_code, …) |

Event history is consistent with the SQL data:

- every payment has a payment_requested event at its `requested_at` time, with status `pending` in its snapshot;
- the 7 payments that are `posted` in PostgreSQL also have a payment_settled event two hours later (status `posted`);
- the 1 `failed` payment (3005) has a payment_failed event five minutes later (status `failed`);
- the 2 `pending` payments (3002, 3008) have only their request.

That gives 10 + 7 + 1 = **18 documents**. Amounts and balances are stored as Decimal128, so cents are exact, as with NUMERIC(18,2) in SQL.

Embedding the account and customer snapshots makes each event readable in one document, which suits a review screen or audit trail. It duplicates information, and later SQL changes do not update old snapshots — which is the intended behaviour for a history ("what did the account look like when this happened?"), but means PostgreSQL remains the system of record and continues to enforce the relational rules.

The script builds the documents from the source rows with one `makeEvent()` helper instead of repeating every document by hand, so it is 229 lines instead of 498.

## Example document

```javascript
{
  _id: 'event_000002',
  schemaVersion: 2,
  simulation: true,
  eventType: 'payment_settled',
  occurredAt: ISODate('2025-04-02T16:30:00.000Z'),
  source: {
    entity: 'payment',
    key: { payment_id: 3001 },
    snapshot: {
      payment_id: 3001, account_id: 2001, amount: Decimal128('42.50'),
      requested_at: ISODate('2025-04-02T14:30:00.000Z'), status: 'posted',
      external_reference: 'EXT-001', beneficiary_label: 'Northwind Supplies'
    }
  },
  embedded: {
    account: [ {
      key: { account_id: 2001 },
      snapshot: { account_id: 2001, customer_id: 1001, opened_date: '2025-03-12', currency: 'USD',
                  available_balance: Decimal128('1250.75'), status: 'open' },
      via: [ 'payment.account_id -> account' ]
    } ],
    customer: [ {
      key: { customer_id: 1001 },
      snapshot: { customer_id: 1001, legal_name: 'Avery Morgan', opened_date: '2025-03-10', status: 'active' },
      via: [ 'payment.account_id -> account.customer_id -> customer' ]
    } ]
  },
  references: { account_id: 2001, customer_id: 1001 },
  details: { channel: 'web', settlement_reference: 'STL-3001' }
}
```

## Indexes

| Name | Key | Supports |
| --- | --- | --- |
| _id_ | { _id: 1 } | Unique event ID (created automatically) |
| event_type_time | { eventType: 1, occurredAt: -1 } | Events of one type, newest first (query 1) |
| source_payment_time | { "source.key.payment_id": 1, occurredAt: 1 } | Full lifecycle of one payment in time order (query 2) |

## Queries and results

| Query | Returned |
| --- | --- |
| 1. Settled payments, newest first | 7 |
| 2. Full lifecycle of payment 3005 (nested key field) | 2 |
| 3. Events in the first week of April 2025 (Date range) | 7 |
| 4. Number of events of each type | 3 groups |
| 5. Settled value per currency, using the embedded account snapshot | 3 groups |

### 1. Settled payments, newest first

```javascript
db.payment_event.find({ eventType: 'payment_settled' }, summary).sort({ occurredAt: -1 })
```

| _id | occurredAt | payment_id | amount |
| --- | --- | --- | --- |
| event_000018 | 2025-05-04 15:45 | 3010 | 58.00 |
| event_000016 | 2025-05-02 11:10 | 3009 | 32.75 |
| event_000011 | 2025-04-10 13:00 | 3003 | 120.00 |
| event_000009 | 2025-04-08 18:05 | 3007 | 64.30 |
| event_000007 | 2025-04-06 12:00 | 3006 | 950.00 |
| event_000005 | 2025-04-05 10:45 | 3004 | 75.40 |
| event_000002 | 2025-04-02 16:30 | 3001 | 42.50 |

### 2. Full lifecycle of payment 3005

```javascript
db.payment_event.find({ 'source.key.payment_id': 3005 }, summary).sort({ occurredAt: 1 })
```

| _id | eventType | occurredAt | status in snapshot |
| --- | --- | --- | --- |
| event_000012 | payment_requested | 2025-04-12 19:20 | pending |
| event_000013 | payment_failed | 2025-04-12 19:25 | failed |

### 3. Events in the first week of April 2025

```javascript
db.payment_event.find({ occurredAt: { $gte: ISODate('2025-04-01T00:00:00Z'), $lt: ISODate('2025-04-08T00:00:00Z') } }, summary)
  .sort({ occurredAt: 1 })
```

| _id | eventType | occurredAt | payment_id |
| --- | --- | --- | --- |
| event_000001 | payment_requested | 2025-04-02 14:30 | 3001 |
| event_000002 | payment_settled | 2025-04-02 16:30 | 3001 |
| event_000003 | payment_requested | 2025-04-03 09:15 | 3002 |
| event_000004 | payment_requested | 2025-04-05 08:45 | 3004 |
| event_000005 | payment_settled | 2025-04-05 10:45 | 3004 |
| event_000006 | payment_requested | 2025-04-06 10:00 | 3006 |
| event_000007 | payment_settled | 2025-04-06 12:00 | 3006 |

### 4. Number of events of each type

```javascript
db.payment_event.aggregate([{ $group: { _id: '$eventType', documentCount: { $sum: 1 } } }, { $sort: { _id: 1 } }])
```

| _id | documentCount |
| --- | --- |
| payment_failed | 1 |
| payment_requested | 10 |
| payment_settled | 7 |

### 5. Settled value per currency

```javascript
db.payment_event.aggregate([
  { $match: { eventType: 'payment_settled' } },
  { $unwind: '$embedded.account' },
  { $group: { _id: '$embedded.account.snapshot.currency', settledPayments: { $sum: 1 },
              settledTotal: { $sum: '$source.snapshot.amount' } } },
  { $sort: { _id: 1 } }
])
```

| _id | settledPayments | settledTotal |
| --- | --- | --- |
| EUR | 3 | 1047.05 |
| GBP | 1 | 75.40 |
| USD | 3 | 220.50 |

The currency comes from the embedded account snapshot, so no lookup to another collection is needed. The totals match the `posted_total` column of query 3 in Portfolio 2, computed independently by PostgreSQL (EUR 1047.05, GBP 75.40, USD 220.50).

## explain(): are the indexes used?

`explain('executionStats')` for each query with its index, and the same query forced to a collection scan with `hint({ $natural: 1 })`:

| Query | Winning plan | Returned | Keys examined | Docs examined |
| --- | --- | --- | --- | --- |
| Query 1 (event_type_time) | FETCH ← IXSCAN (event_type_time) | 7 | 7 | 7 |
| Query 1 (forced collection scan) | SORT ← COLLSCAN | 7 | 0 | 18 |
| Query 2 (source_payment_time) | FETCH ← IXSCAN (source_payment_time) | 2 | 2 | 2 |
| Query 2 (forced collection scan) | SORT ← COLLSCAN | 2 | 0 | 18 |

With the indexes MongoDB examined exactly the documents it returned, and the index order also removed the in-memory SORT stage. Without them it read all 18 documents and sorted them. With 18 documents the time difference is not meaningful, so the comparison uses documents examined rather than timings.

## Validation

| Invalid insert | Result |
| --- | --- |
| occurredAt stored as text | rejected, code 121 (DocumentValidationFailure) |
| Unknown eventType (payment_reversed) | rejected, code 121 (DocumentValidationFailure) |
| Amount stored as text instead of Decimal128 | rejected, code 121 (DocumentValidationFailure) |
| details without the required channel | rejected, code 121 (DocumentValidationFailure) |
| Duplicate event ID | rejected, code 11000 (DuplicateKey) |

The collection still contained 18 valid documents afterwards. The validator checks the fields every event shares, while `details` can carry different fields for each event type.

## Run the script

Connect mongosh to a fresh exercise database and run Ukaegbu_Goodnews_301923986_P4_MongoDB.js (it stops if `portfolio_nosql.payment_event` already exists):

```bash
mongosh "mongodb://localhost:27017" --file Ukaegbu_Goodnews_301923986_P4_MongoDB.js
```

[Implementation evidence](screenshots/Ukaegbu_Goodnews_301923986_P4_DocumentsAndQueries.png) · [Raw output](evidence/Ukaegbu_Goodnews_301923986_P4_MongoDB.txt)

## References

- [MongoDB — data modelling](https://www.mongodb.com/docs/manual/data-modeling/)
- [MongoDB — schema validation](https://www.mongodb.com/docs/manual/core/schema-validation/)
- [MongoDB — explain results](https://www.mongodb.com/docs/manual/reference/explain-results/)
