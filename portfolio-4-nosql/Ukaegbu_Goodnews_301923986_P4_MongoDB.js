// Run once in mongosh against a fresh exercise database.
// These records are fictional events for the case study.
(async function () {
  db = db.getSiblingDB('portfolio_nosql');
  if ((await db.getCollectionNames()).includes("payment_event")) {
    throw new Error('The exercise collection already exists. Use a fresh database.');
  }

  // The validator checks the stable event fields while details can vary.
  await db.createCollection("payment_event", {
    validator: {
    "$jsonSchema": {
        "bsonType": "object",
        "required": [
            "_id",
            "schemaVersion",
            "simulation",
            "eventType",
            "occurredAt",
            "source",
            "embedded",
            "references",
            "details"
        ],
        "properties": {
            "_id": {
                "bsonType": "string",
                "minLength": 1
            },
            "schemaVersion": {
                "enum": [
                    1
                ]
            },
            "simulation": {
                "enum": [
                    true
                ]
            },
            "eventType": {
                "bsonType": "string",
                "enum": [
                    "payment_requested",
                    "payment_settled"
                ]
            },
            "occurredAt": {
                "bsonType": "date"
            },
            "source": {
                "bsonType": "object",
                "required": [
                    "entity",
                    "key",
                    "snapshot"
                ],
                "properties": {
                    "entity": {
                        "enum": [
                            "payment"
                        ]
                    },
                    "key": {
                        "bsonType": "object",
                        "required": [
                            "payment_id"
                        ]
                    },
                    "snapshot": {
                        "bsonType": "object"
                    }
                }
            },
            "embedded": {
                "bsonType": "object"
            },
            "references": {
                "bsonType": "object"
            },
            "details": {
                "bsonType": "object"
            }
        }
    }
},
    validationLevel: 'strict', validationAction: 'error'
  });

  // Insert the four example events and show their IDs.
  printjson(await db.getCollection("payment_event").insertMany([
    {
        "_id": "event_000001",
        "schemaVersion": 1,
        "simulation": true,
        "eventType": "payment_requested",
        "occurredAt": ISODate("2030-01-01T10:00:00Z"),
        "source": {
            "entity": "payment",
            "key": {
                "payment_id": 3001
            },
            "snapshot": {
                "payment_id": 3001,
                "account_id": 2001,
                "amount": 42.5,
                "requested_at": "2025-04-02T14:30:00Z",
                "status": "posted",
                "external_reference": "EXT-001",
                "beneficiary_label": "Northwind Supplies"
            }
        },
        "embedded": {
            "account": [
                {
                    "key": {
                        "account_id": 2001
                    },
                    "snapshot": {
                        "account_id": 2001,
                        "customer_id": 1001,
                        "opened_date": "2025-03-12",
                        "currency": "USD",
                        "available_balance": 1250.75,
                        "status": "open"
                    },
                    "via": [
                        "payment.account_id → account"
                    ]
                }
            ],
            "customer": [
                {
                    "key": {
                        "customer_id": 1001
                    },
                    "snapshot": {
                        "customer_id": 1001,
                        "legal_name": "Avery Morgan",
                        "opened_date": "2025-03-10",
                        "status": "active"
                    },
                    "via": [
                        "payment.account_id → account.customer_id → customer"
                    ]
                }
            ]
        },
        "references": {},
        "details": {
            "channel": "web"
        }
    },
    {
        "_id": "event_000002",
        "schemaVersion": 1,
        "simulation": true,
        "eventType": "payment_settled",
        "occurredAt": ISODate("2030-01-01T10:01:00Z"),
        "source": {
            "entity": "payment",
            "key": {
                "payment_id": 3001
            },
            "snapshot": {
                "payment_id": 3001,
                "account_id": 2001,
                "amount": 42.5,
                "requested_at": "2025-04-02T14:30:00Z",
                "status": "posted",
                "external_reference": "EXT-001",
                "beneficiary_label": "Northwind Supplies"
            }
        },
        "embedded": {
            "account": [
                {
                    "key": {
                        "account_id": 2001
                    },
                    "snapshot": {
                        "account_id": 2001,
                        "customer_id": 1001,
                        "opened_date": "2025-03-12",
                        "currency": "USD",
                        "available_balance": 1250.75,
                        "status": "open"
                    },
                    "via": [
                        "payment.account_id → account"
                    ]
                }
            ],
            "customer": [
                {
                    "key": {
                        "customer_id": 1001
                    },
                    "snapshot": {
                        "customer_id": 1001,
                        "legal_name": "Avery Morgan",
                        "opened_date": "2025-03-10",
                        "status": "active"
                    },
                    "via": [
                        "payment.account_id → account.customer_id → customer"
                    ]
                }
            ]
        },
        "references": {},
        "details": {
            "channel": "mobile",
            "note": "Illustrative event-specific metadata",
            "examples": {
                "failure_code": "illustrative failure_code",
                "provider_payload": "illustrative provider_payload",
                "review_note": "illustrative review_note"
            }
        }
    },
    {
        "_id": "event_000003",
        "schemaVersion": 1,
        "simulation": true,
        "eventType": "payment_requested",
        "occurredAt": ISODate("2030-01-01T10:02:00Z"),
        "source": {
            "entity": "payment",
            "key": {
                "payment_id": 3002
            },
            "snapshot": {
                "payment_id": 3002,
                "account_id": 2001,
                "amount": 18.25,
                "requested_at": "2025-04-03T09:15:00+00:00",
                "status": "pending",
                "external_reference": null,
                "beneficiary_label": "Harbor Design"
            }
        },
        "embedded": {
            "account": [
                {
                    "key": {
                        "account_id": 2001
                    },
                    "snapshot": {
                        "account_id": 2001,
                        "customer_id": 1001,
                        "opened_date": "2025-03-12",
                        "currency": "USD",
                        "available_balance": 1250.75,
                        "status": "open"
                    },
                    "via": [
                        "payment.account_id → account"
                    ]
                }
            ],
            "customer": [
                {
                    "key": {
                        "customer_id": 1001
                    },
                    "snapshot": {
                        "customer_id": 1001,
                        "legal_name": "Avery Morgan",
                        "opened_date": "2025-03-10",
                        "status": "active"
                    },
                    "via": [
                        "payment.account_id → account.customer_id → customer"
                    ]
                }
            ]
        },
        "references": {},
        "details": {
            "channel": "web"
        }
    },
    {
        "_id": "event_000004",
        "schemaVersion": 1,
        "simulation": true,
        "eventType": "payment_settled",
        "occurredAt": ISODate("2030-01-01T10:03:00Z"),
        "source": {
            "entity": "payment",
            "key": {
                "payment_id": 3002
            },
            "snapshot": {
                "payment_id": 3002,
                "account_id": 2001,
                "amount": 18.25,
                "requested_at": "2025-04-03T09:15:00+00:00",
                "status": "pending",
                "external_reference": null,
                "beneficiary_label": "Harbor Design"
            }
        },
        "embedded": {
            "account": [
                {
                    "key": {
                        "account_id": 2001
                    },
                    "snapshot": {
                        "account_id": 2001,
                        "customer_id": 1001,
                        "opened_date": "2025-03-12",
                        "currency": "USD",
                        "available_balance": 1250.75,
                        "status": "open"
                    },
                    "via": [
                        "payment.account_id → account"
                    ]
                }
            ],
            "customer": [
                {
                    "key": {
                        "customer_id": 1001
                    },
                    "snapshot": {
                        "customer_id": 1001,
                        "legal_name": "Avery Morgan",
                        "opened_date": "2025-03-10",
                        "status": "active"
                    },
                    "via": [
                        "payment.account_id → account.customer_id → customer"
                    ]
                }
            ]
        },
        "references": {},
        "details": {
            "channel": "mobile",
            "note": "Illustrative event-specific metadata",
            "examples": {
                "failure_code": "illustrative failure_code",
                "provider_payload": "illustrative provider_payload",
                "review_note": "illustrative review_note"
            }
        }
    }
]));
  await db.getCollection("payment_event").createIndex({eventType: 1, occurredAt: -1}, {name: 'event_type_time'});

  // 1. Find the first sample event type (up to five documents).
  printjson(await db.getCollection("payment_event").find({"eventType":"payment_requested"}).sort({_id:1}).limit(5).toArray());

  // 2. Find events for the first source record using nested key fields (up to five).
  printjson(await db.getCollection("payment_event").find({"source.key.payment_id":3001}).sort({_id:1}).limit(5).toArray());

  // 3. Find events in the sample time range using a MongoDB Date filter (up to five).
  printjson(await db.getCollection("payment_event").find({"occurredAt":{"$gte":ISODate("2030-01-01T10:00:00Z"), "$lt":ISODate("2030-01-01T11:00:00Z")}}).sort({_id:1}).limit(5).toArray());

  // 4. Count documents for each event type.
  printjson(await db.getCollection("payment_event").aggregate([{"$group":{"_id":"$eventType", "documentCount":{"$sum":1}}}, {"$sort":{"_id":1}}]).toArray());

  // A date stored as text should be rejected by the validator.
  try {
    await db.getCollection("payment_event").insertOne({...{
    "_id": "event_000001",
    "schemaVersion": 1,
    "simulation": true,
    "eventType": "payment_requested",
    "occurredAt": ISODate("2030-01-01T10:00:00Z"),
    "source": {
        "entity": "payment",
        "key": {
            "payment_id": 3001
        },
        "snapshot": {
            "payment_id": 3001,
            "account_id": 2001,
            "amount": 42.5,
            "requested_at": "2025-04-02T14:30:00Z",
            "status": "posted",
            "external_reference": "EXT-001",
            "beneficiary_label": "Northwind Supplies"
        }
    },
    "embedded": {
        "account": [
            {
                "key": {
                    "account_id": 2001
                },
                "snapshot": {
                    "account_id": 2001,
                    "customer_id": 1001,
                    "opened_date": "2025-03-12",
                    "currency": "USD",
                    "available_balance": 1250.75,
                    "status": "open"
                },
                "via": [
                    "payment.account_id → account"
                ]
            }
        ],
        "customer": [
            {
                "key": {
                    "customer_id": 1001
                },
                "snapshot": {
                    "customer_id": 1001,
                    "legal_name": "Avery Morgan",
                    "opened_date": "2025-03-10",
                    "status": "active"
                },
                "via": [
                    "payment.account_id → account.customer_id → customer"
                ]
            }
        ]
    },
    "references": {},
    "details": {
        "channel": "web"
    }
}, _id: 'invalid_date_example', occurredAt: 'not-a-date'});
  } catch (error) { print('Invalid date error: ' + error.code); }

  // Reusing an event ID should be rejected by the unique _id index.
  try { await db.getCollection("payment_event").insertOne({
    "_id": "event_000001",
    "schemaVersion": 1,
    "simulation": true,
    "eventType": "payment_requested",
    "occurredAt": ISODate("2030-01-01T10:00:00Z"),
    "source": {
        "entity": "payment",
        "key": {
            "payment_id": 3001
        },
        "snapshot": {
            "payment_id": 3001,
            "account_id": 2001,
            "amount": 42.5,
            "requested_at": "2025-04-02T14:30:00Z",
            "status": "posted",
            "external_reference": "EXT-001",
            "beneficiary_label": "Northwind Supplies"
        }
    },
    "embedded": {
        "account": [
            {
                "key": {
                    "account_id": 2001
                },
                "snapshot": {
                    "account_id": 2001,
                    "customer_id": 1001,
                    "opened_date": "2025-03-12",
                    "currency": "USD",
                    "available_balance": 1250.75,
                    "status": "open"
                },
                "via": [
                    "payment.account_id → account"
                ]
            }
        ],
        "customer": [
            {
                "key": {
                    "customer_id": 1001
                },
                "snapshot": {
                    "customer_id": 1001,
                    "legal_name": "Avery Morgan",
                    "opened_date": "2025-03-10",
                    "status": "active"
                },
                "via": [
                    "payment.account_id → account.customer_id → customer"
                ]
            }
        ]
    },
    "references": {},
    "details": {
        "channel": "web"
    }
}); }
  catch (error) { print('Duplicate ID error: ' + error.code); }

  print('Document count: ' + await db.getCollection("payment_event").countDocuments());
})().catch(error => { print(error.stack || String(error)); quit(1); });
