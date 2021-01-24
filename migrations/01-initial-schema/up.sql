BEGIN;

CREATE TABLE videos (
  video_id      TEXT PRIMARY KEY,
  video_title   TEXT,
  channel_id    TEXT,
  channel_title TEXT,
  watched       INTEGER NOT NULL DEFAULT 0
);

PRAGMA user_version = 1;

COMMIT;
