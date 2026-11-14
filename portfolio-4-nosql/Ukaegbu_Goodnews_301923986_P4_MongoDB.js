// Portfolio 4: payment lifecycle events in MongoDB.
// Run once against a fresh database, for example:
//   mongosh "mongodb://localhost:27017" --file Ukaegbu_Goodnews_301923986_P4_MongoDB.js
// The records are fictional and mirror the Portfolio 1 sample data (same IDs and values).
// PostgreSQL stays the system of record; these documents are an event history for review.

const database = db.getSiblingDB('portfolio_nosql');
if (database.getCollectionNames().includes('payment_event')) {
  throw new Error('portfolio_nosql.payment_event already exists. Use a fresh database.');
}
const events = database.getCollection('payment_event');

function section(title) {
  print('\n=== ' + title + ' ===');
}

// ---------------------------------------------------------------------------
// Source data: copied from the Portfolio 1 sample data.
// Money is stored as Decimal128 so amounts keep exact cents, like NUMERIC(18,2) in SQL.
// ---------------------------------------------------------------------------
const customers = {
  1001: { customer_id: 1001, legal_name: 'Avery Morgan', opened_date: '2025-03-10', status: 'active' },
  1002: { customer_id: 1002, legal_name: 'Blessing Okafor', opened_date: '2025-03-18', status: 'active' },
  1003: { customer_id: 1003, legal_name: 'Chen Wei Lim', opened_date: '2025-04-01', status: 'suspended' },
};
const accounts = {
  2001: { account_id: 2001, customer_id: 1001, opened_date: '2025-03-12', currency: 'USD', available_balance: '1250.75', status: 'open' },
  2002: { account_id: 2002, customer_id: 1001, opened_date: '2025-03-20', currency: 'GBP', available_balance: '640.00', status: 'open' },
  2003: { account_id: 2003, customer_id: 1002, opened_date: '2025-03-19', currency: 'EUR', available_balance: '3200.00', status: 'open' },
  2004: { account_id: 2004, customer_id: 1003, opened_date: '2025-04-02', currency: 'USD', available_balance: '0.00', status: 'frozen' },
};
// status is the payment's current status in PostgreSQL; channel is event metadata.
const payments = [
  { payment_id: 3001, account_id: 2001, amount: '42.50', requested_at: '2025-04-02T14:30:00Z', status: 'posted', external_reference: 'EXT-001', beneficiary_label: 'Northwind Supplies', channel: 'web' },
  { payment_id: 3002, account_id: 2001, amount: '18.25', requested_at: '2025-04-03T09:15:00Z', status: 'pending', external_reference: null, beneficiary_label: 'Harbor Design', channel: 'mobile' },
  { payment_id: 3003, account_id: 2001, amount: '120.00', requested_at: '2025-04-10T11:00:00Z', status: 'posted', external_reference: 'EXT-002', beneficiary_label: 'Lakeside Utilities', channel: 'api' },
  { payment_id: 3004, account_id: 2002, amount: '75.40', requested_at: '2025-04-05T08:45:00Z', status: 'posted', external_reference: 'EXT-003', beneficiary_label: 'Brightline Rail', channel: 'mobile' },
  { payment_id: 3005, account_id: 2002, amount: '15.99', requested_at: '2025-04-12T19:20:00Z', status: 'failed', external_reference: null, beneficiary_label: 'Streamly Media', channel: 'web' },
  { payment_id: 3006, account_id: 2003, amount: '950.00', requested_at: '2025-04-06T10:00:00Z', status: 'posted', external_reference: 'EXT-004', beneficiary_label: 'Cedar Property Rentals', channel: 'web' },
  { payment_id: 3007, account_id: 2003, amount: '64.30', requested_at: '2025-04-08T16:05:00Z', status: 'posted', external_reference: null, beneficiary_label: 'Greenleaf Grocers', channel: 'mobile' },
  { payment_id: 3008, account_id: 2003, amount: '210.00', requested_at: '2025-04-15T12:30:00Z', status: 'pending', external_reference: 'EXT-005', beneficiary_label: 'Summit Insurance', channel: 'api' },
  { payment_id: 3009, account_id: 2003, amount: '32.75', requested_at: '2025-05-02T09:10:00Z', status: 'posted', external_reference: 'EXT-006', beneficiary_label: 'Metro Fuel', channel: 'mobile' },
  { payment_id: 3010, account_id: 2001, amount: '58.00', requested_at: '2025-05-04T13:45:00Z', status: 'posted', external_reference: null, beneficiary_label: 'Harbor Design', channel: 'web' },
];

// ---------------------------------------------------------------------------
// Validator: the stable event fields are checked; details may vary by event type.
// ---------------------------------------------------------------------------
database.createCollection('payment_event', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['_id', 'schemaVersion', 'simulation', 'eventType', 'occurredAt', 'source', 'embedded', 'references', 'details'],
      properties: {
        _id: { bsonType: 'string', minLength: 1 },
        schemaVersion: { enum: [2] },
        simulation: { enum: [true] },
        eventType: { enum: ['payment_requested', 'payment_settled', 'payment_failed'] },
        occurredAt: { bsonType: 'date' },
        source: {
          bsonType: 'object',
          required: ['entity', 'key', 'snapshot'],
          properties: {
            entity: { enum: ['payment'] },
            key: { bsonType: 'object', required: ['payment_id'], properties: { payment_id: { bsonType: ['int', 'long'] } } },
            snapshot: {
              bsonType: 'object',
              required: ['amount', 'status', 'requested_at'],
              properties: {
                amount: { bsonType: 'decimal' },
                status: { enum: ['pending', 'posted', 'failed'] },
                requested_at: { bsonType: 'date' },
              },
            },
          },
        },
        embedded: { bsonType: 'object', required: ['account', 'customer'] },
        references: { bsonType: 'object', required: ['account_id', 'customer_id'] },
        details: { bsonType: 'object', required: ['channel'], properties: { channel: { enum: ['web', 'mobile', 'api'] } } },
      },
    },
  },
  validationLevel: 'strict',
  validationAction: 'error',
});

// ---------------------------------------------------------------------------
// Build the event documents from the source data instead of writing each one by hand.
// Each document embeds the payment, account and customer as they were at the event,
// so one read returns everything needed to review the event.
// ---------------------------------------------------------------------------
function paymentSnapshot(payment, statusAtEvent) {
  return {
    payment_id: payment.payment_id,
    account_id: payment.account_id,
    amount: NumberDecimal(payment.amount),
    requested_at: new Date(payment.requested_at),
    status: statusAtEvent,
    external_reference: payment.external_reference,
    beneficiary_label: payment.beneficiary_label,
  };
}

function makeEvent(eventType, payment, occurredAt, statusAtEvent, extraDetails) {
  const account = accounts[payment.account_id];
  const customer = customers[account.customer_id];
  return {
    schemaVersion: 2,
    simulation: true,
    eventType: eventType,
    occurredAt: occurredAt,
    source: { entity: 'payment', key: { payment_id: payment.payment_id }, snapshot: paymentSnapshot(payment, statusAtEvent) },
    embedded: {
      account: [{ key: { account_id: account.account_id }, snapshot: { ...account, available_balance: NumberDecimal(account.available_balance) }, via: ['payment.account_id -> account'] }],
      customer: [{ key: { customer_id: customer.customer_id }, snapshot: customer, via: ['payment.account_id -> account.customer_id -> customer'] }],
    },
    references: { account_id: account.account_id, customer_id: customer.customer_id },
    details: { channel: payment.channel, ...extraDetails },
  };
}

const MINUTE = 60 * 1000;
const lifecycle = [];
for (const payment of payments) {
  const requestedAt = new Date(payment.requested_at);
  // Every payment starts as a request; its status at that moment is pending.
  lifecycle.push(makeEvent('payment_requested', payment, requestedAt, 'pending', {}));
  // Only payments that are now posted have a settlement, and only failed ones a failure.
  if (payment.status === 'posted') {
    lifecycle.push(makeEvent('payment_settled', payment, new Date(requestedAt.getTime() + 120 * MINUTE), 'posted',
      { settlement_reference: 'STL-' + payment.payment_id }));
  }
  if (payment.status === 'failed') {
    lifecycle.push(makeEvent('payment_failed', payment, new Date(requestedAt.getTime() + 5 * MINUTE), 'failed',
      { failure_code: 'beneficiary_account_closed', retryable: false }));
  }
}
lifecycle.sort((a, b) => a.occurredAt - b.occurredAt);
lifecycle.forEach((event, index) => { event._id = 'event_' + String(index + 1).padStart(6, '0'); });

section('Insert the event documents');
const inserted = events.insertMany(lifecycle);
print('Inserted documents: ' + Object.keys(inserted.insertedIds).length);
print('Example document:');
printjson(events.findOne({ 'source.key.payment_id': 3001, eventType: 'payment_settled' }));

section('Indexes');
events.createIndex({ eventType: 1, occurredAt: -1 }, { name: 'event_type_time' });
events.createIndex({ 'source.key.payment_id': 1, occurredAt: 1 }, { name: 'source_payment_time' });
printjson(events.getIndexes().map((index) => ({ name: index.name, key: index.key })));

// Selected fields shown for each returned event.
const summary = { _id: 1, eventType: 1, occurredAt: 1, payment_id: '$source.key.payment_id', amount: '$source.snapshot.amount', status: '$source.snapshot.status' };

section('Query 1: settled payments, newest first');
const q1 = events.find({ eventType: 'payment_settled' }, summary).sort({ occurredAt: -1 }).toArray();
printjson(q1);
print('Returned: ' + q1.length);

section('Query 2: full lifecycle of payment 3005 (nested key field)');
const q2 = events.find({ 'source.key.payment_id': 3005 }, summary).sort({ occurredAt: 1 }).toArray();
printjson(q2);
print('Returned: ' + q2.length);

section('Query 3: events in the first week of April 2025 (Date range)');
const q3 = events.find({ occurredAt: { $gte: ISODate('2025-04-01T00:00:00Z'), $lt: ISODate('2025-04-08T00:00:00Z') } }, summary)
  .sort({ occurredAt: 1 }).toArray();
printjson(q3);
print('Returned: ' + q3.length);

section('Query 4: number of events of each type');
printjson(events.aggregate([{ $group: { _id: '$eventType', documentCount: { $sum: 1 } } }, { $sort: { _id: 1 } }]).toArray());

section('Query 5: settled value per currency, using the embedded account snapshot');
printjson(events.aggregate([
  { $match: { eventType: 'payment_settled' } },
  { $unwind: '$embedded.account' },
  { $group: { _id: '$embedded.account.snapshot.currency', settledPayments: { $sum: 1 }, settledTotal: { $sum: '$source.snapshot.amount' } } },
  { $sort: { _id: 1 } },
]).toArray());

// ---------------------------------------------------------------------------
// explain(): confirm which plan MongoDB used and how much it had to read.
// ---------------------------------------------------------------------------
function stages(plan) {
  if (!plan) return [];
  const node = plan.queryPlan || plan;
  const children = node.inputStage ? [node.inputStage] : (node.inputStages || []);
  return [node.stage + (node.indexName ? ' (' + node.indexName + ')' : '')].concat(...children.map(stages));
}
function explainSummary(label, cursor) {
  const result = cursor.explain('executionStats');
  printjson({
    query: label,
    winningPlan: stages(result.queryPlanner.winningPlan).join(' <- '),
    nReturned: result.executionStats.nReturned,
    totalKeysExamined: result.executionStats.totalKeysExamined,
    totalDocsExamined: result.executionStats.totalDocsExamined,
  });
}

section('explain(): Query 1 with the index, then forced to a collection scan');
explainSummary('Query 1 (event_type_time)', events.find({ eventType: 'payment_settled' }).sort({ occurredAt: -1 }));
explainSummary('Query 1 (forced collection scan)', events.find({ eventType: 'payment_settled' }).sort({ occurredAt: -1 }).hint({ $natural: 1 }));

section('explain(): Query 2 with the index, then forced to a collection scan');
explainSummary('Query 2 (source_payment_time)', events.find({ 'source.key.payment_id': 3005 }).sort({ occurredAt: 1 }));
explainSummary('Query 2 (forced collection scan)', events.find({ 'source.key.payment_id': 3005 }).sort({ occurredAt: 1 }).hint({ $natural: 1 }));

// ---------------------------------------------------------------------------
// Validation: each invalid insert must be rejected and must not change the collection.
// ---------------------------------------------------------------------------
section('Validation tests');
const valid = events.findOne({ _id: 'event_000001' });
function tryInsert(label, document) {
  try {
    events.insertOne(document);
    print(label + ': ACCEPTED (unexpected)');
  } catch (error) {
    const names = { 121: 'DocumentValidationFailure', 11000: 'DuplicateKey' };
    print(label + ': rejected with code ' + error.code + ' (' + (names[error.code] || error.codeName || error.name) + ')');
  }
}
tryInsert('Date stored as text', { ...valid, _id: 'invalid_date', occurredAt: '2025-04-02T14:30:00Z' });
tryInsert('Unknown event type', { ...valid, _id: 'invalid_type', eventType: 'payment_reversed' });
tryInsert('Amount stored as text', { ...valid, _id: 'invalid_amount', source: { ...valid.source, snapshot: { ...valid.source.snapshot, amount: '42.50' } } });
tryInsert('Missing details.channel', { ...valid, _id: 'invalid_details', details: {} });
tryInsert('Duplicate event ID', { ...valid });
print('Document count after the tests: ' + events.countDocuments());
