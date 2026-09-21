CREATE TABLE IF NOT EXISTS records (
  kind TEXT NOT NULL, id TEXT NOT NULL, version INTEGER NOT NULL CHECK(version>0),
  body TEXT NOT NULL CHECK(json_valid(body)), updated_at TEXT NOT NULL,
  PRIMARY KEY(kind,id)
);
CREATE UNIQUE INDEX IF NOT EXISTS one_business ON records(kind) WHERE kind='Business';
CREATE UNIQUE INDEX IF NOT EXISTS product_code ON records(json_extract(body,'$.code') COLLATE NOCASE) WHERE kind='Product';
CREATE UNIQUE INDEX IF NOT EXISTS product_barcode ON records(json_extract(body,'$.barcode')) WHERE kind='Product' AND json_extract(body,'$.barcode')<>'';
CREATE INDEX IF NOT EXISTS records_kind ON records(kind,updated_at);
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY, username TEXT NOT NULL COLLATE NOCASE UNIQUE,
  name TEXT NOT NULL, password_hash TEXT NOT NULL,
  role TEXT NOT NULL CHECK(role IN ('Owner','Admin','Cashier','Employee','Viewer')),
  active INTEGER NOT NULL CHECK(active IN (0,1)), failed_attempts INTEGER NOT NULL DEFAULT 0,
  locked_until TEXT, pin_hash TEXT, updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS idempotency (
  request_id TEXT PRIMARY KEY, request_hash TEXT NOT NULL,
  result_kind TEXT NOT NULL, result_id TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS counters (name TEXT PRIMARY KEY, value INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS outbox (
  sequence INTEGER PRIMARY KEY AUTOINCREMENT, event_id TEXT NOT NULL UNIQUE,
  kind TEXT NOT NULL, entity_id TEXT NOT NULL, version INTEGER NOT NULL,
  payload TEXT NOT NULL CHECK(json_valid(payload)), payload_hash TEXT NOT NULL,
  occurred_at TEXT NOT NULL, sent_at TEXT, attempts INTEGER NOT NULL DEFAULT 0,
  next_attempt_at TEXT, last_error TEXT
);
CREATE INDEX IF NOT EXISTS outbox_pending ON outbox(sequence) WHERE sent_at IS NULL;
CREATE TABLE IF NOT EXISTS remote_receipts (
  command_id TEXT PRIMARY KEY, request_hash TEXT NOT NULL, status TEXT NOT NULL,
  result TEXT NOT NULL, processed_at TEXT NOT NULL, acknowledged INTEGER NOT NULL DEFAULT 0
);
PRAGMA application_id=1128481603;
PRAGMA user_version=1;
