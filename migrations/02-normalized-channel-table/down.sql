BEGIN;

PRAGMA foreign_keys = OFF;

CREATE TABLE videos_new (
  video_id      TEXT PRIMARY KEY,
  video_title   TEXT,
  channel_id    TEXT,
  channel_title TEXT,
  watched       INTEGER NOT NULL DEFAULT 0
);

INSERT INTO videos_new (video_id, video_title, channel_id, channel_title, watched)
  SELECT videos.id, videos.title, channels.id, channels.title, videos.watched
    FROM videos
           JOIN channels ON videos.channel_id = channels.id;

DROP TABLE channels;
DROP TABLE videos;
DROP VIEW videos_all;

ALTER TABLE videos_new RENAME TO videos;

PRAGMA foreign_keys = ON;

PRAGMA user_version = 1;

COMMIT;

VACUUM;
