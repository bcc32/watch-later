CREATE TABLE channels (
  id    TEXT PRIMARY KEY,
  title TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS "videos" (
  id         TEXT PRIMARY KEY,
  title      TEXT NOT NULL,
  channel_id TEXT NOT NULL REFERENCES channels ON DELETE CASCADE,
  watched    INTEGER NOT NULL DEFAULT 0
);
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
  FROM videos JOIN channels ON videos.channel_id = channels.id
/* videos_all(video_id,video_title,channel_id,channel_title,watched) */;
CREATE INDEX index_videos_on_title ON videos (title COLLATE NOCASE);
CREATE INDEX index_channels_on_title ON channels (title COLLATE NOCASE);
