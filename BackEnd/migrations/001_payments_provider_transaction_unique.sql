-- Apply once to an existing database created before the provider transaction unique index.
-- New databases created from the current root schema.sql already have this key.
ALTER TABLE payments
  ADD UNIQUE KEY uq_payments_provider_txn (provider, transaction_id);
