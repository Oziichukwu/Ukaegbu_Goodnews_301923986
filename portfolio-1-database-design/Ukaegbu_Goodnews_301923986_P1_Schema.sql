-- Bank / Fintech Platform: tables, keys and business constraints.
-- Run once in a fresh PostgreSQL database.
BEGIN;
SET LOCAL standard_conforming_strings = on;
CREATE SCHEMA portfolio;
CREATE TABLE portfolio."customer" (
  "customer_id" bigint NOT NULL,
  "legal_name" text NOT NULL,
  "opened_date" date NOT NULL,
  "status" text NOT NULL,
  CONSTRAINT "pk_customer" PRIMARY KEY ("customer_id")
);
CREATE TABLE portfolio."account" (
  "account_id" bigint NOT NULL,
  "customer_id" bigint NOT NULL,
  "opened_date" date NOT NULL,
  "currency" text NOT NULL,
  "available_balance" numeric(18,2) NOT NULL,
  "status" text NOT NULL,
  CONSTRAINT "pk_account" PRIMARY KEY ("account_id")
);
CREATE TABLE portfolio."payment" (
  "payment_id" bigint NOT NULL,
  "account_id" bigint NOT NULL,
  "amount" numeric(18,2) NOT NULL,
  "requested_at" timestamptz NOT NULL,
  "status" text NOT NULL,
  "external_reference" text,
  "beneficiary_label" text NOT NULL,
  CONSTRAINT "pk_payment" PRIMARY KEY ("payment_id")
);
ALTER TABLE portfolio."account" ADD CONSTRAINT "fk_account_0" FOREIGN KEY ("customer_id") REFERENCES portfolio."customer" ("customer_id");
ALTER TABLE portfolio."payment" ADD CONSTRAINT "fk_payment_0" FOREIGN KEY ("account_id") REFERENCES portfolio."account" ("account_id");
ALTER TABLE portfolio."account" ADD CONSTRAINT "account_nonnegative_balance" CHECK ("available_balance" >= 0);
ALTER TABLE portfolio."payment" ADD CONSTRAINT "payment_positive_amount" CHECK ("amount" > 0);
CREATE UNIQUE INDEX "payment_reference_idempotent" ON portfolio."payment" ("external_reference") WHERE ("external_reference" IS NOT NULL);
COMMIT;
