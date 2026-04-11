-- PixelPal D1 Schema
-- Run: wrangler d1 execute pixelpal --file=schema.sql

CREATE TABLE IF NOT EXISTS devices (
    device_id TEXT PRIMARY KEY,
    created_at TEXT NOT NULL,
    last_sync TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sync_data (
    device_id TEXT PRIMARY KEY,
    characters TEXT NOT NULL,  -- JSON array of DiscoveredCharacter
    updated_at TEXT NOT NULL,
    FOREIGN KEY (device_id) REFERENCES devices(device_id)
);
