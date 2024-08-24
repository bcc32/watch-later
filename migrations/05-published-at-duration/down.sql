BEGIN;

ALTER TABLE videos DROP COLUMN published_at;
ALTER TABLE videos DROP COLUMN duration;

DROP VIEW videos_all;

CREATE VIEW videos_all (
  video_id,
  video_title,
  channel_id,
  channel_title,
  watched
)
  AS
  SELECT videos.id, videos.title, channels.id, channels.title, videos.watched
    FROM videos JOIN channels ON videos.channel_id = channels.id;

PRAGMA user_version = 3;

COMMIT;
