BEGIN;

ALTER TABLE videos
  ADD COLUMN published_at TEXT;
ALTER TABLE videos
  ADD COLUMN duration INTEGER;

DROP VIEW videos_all;

CREATE VIEW videos_all (
  video_id,
  video_title,
  channel_id,
  channel_title,
  published_at,
  duration,
  watched
)
  AS
  SELECT videos.id, videos.title, channels.id, channels.title, videos.published_at, videos.duration, videos.watched
    FROM videos JOIN channels ON videos.channel_id = channels.id;

PRAGMA user_version = 4;

COMMIT;
