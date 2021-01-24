BEGIN;

PRAGMA foreign_keys = OFF;

CREATE TABLE channels (
  id    TEXT PRIMARY KEY,
  title TEXT NOT NULL
);

CREATE TABLE videos_new (
  id         TEXT PRIMARY KEY,
  title      TEXT NOT NULL,
  channel_id TEXT NOT NULL REFERENCES channels ON DELETE CASCADE,
  watched    INTEGER NOT NULL DEFAULT 0
);

INSERT INTO channels (id, title)
SELECT channel_id, channel_title
  FROM (
    SELECT max(rowid), channel_id, channel_title
      FROM videos AS v1
     GROUP BY channel_id);

INSERT INTO videos_new (id, title, channel_id, watched)
SELECT video_id, video_title, channel_id, watched
  FROM videos;

DROP TABLE videos;

ALTER TABLE videos_new RENAME TO videos;

CREATE INDEX index_videos_on_channel_id ON videos (channel_id);

CREATE TRIGGER trigger_delete_unused_channel
  AFTER DELETE ON videos
  FOR EACH ROW
    WHEN NOT EXISTS (SELECT 1 FROM videos WHERE channel_id = old.channel_id)
    BEGIN
      DELETE FROM channels WHERE id = old.channel_id;
    END;

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

PRAGMA foreign_keys = ON;

PRAGMA user_version = 2;

COMMIT;

VACUUM;
