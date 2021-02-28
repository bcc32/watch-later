  $ source ./setup.sh

  $ watch-later debug db path
  HOME/.local/share/watch-later/watch-later.db

  $ watch-later add 'https://www.youtube.com/watch?v=-FlxM_0S2lA'

  $ sqlite3 "$(watch-later debug db path)" .dump
  PRAGMA foreign_keys=OFF;
  BEGIN TRANSACTION;
  CREATE TABLE channels (
    id    TEXT PRIMARY KEY,
    title TEXT NOT NULL
  );
  INSERT INTO channels VALUES('UCSJ4gkVC6NrvII8umztf0Ow','ChilledCow');
  CREATE TABLE IF NOT EXISTS "videos" (
    id         TEXT PRIMARY KEY,
    title      TEXT NOT NULL,
    channel_id TEXT NOT NULL REFERENCES channels ON DELETE CASCADE,
    watched    INTEGER NOT NULL DEFAULT 0
  );
  INSERT INTO videos VALUES('-FlxM_0S2lA','Lofi hip hop mix - Beats to Relax/Study to [2018]','UCSJ4gkVC6NrvII8umztf0Ow',0);
  ANALYZE sqlite_schema;
  INSERT INTO sqlite_stat1 VALUES('videos','index_videos_on_title','1 1');
  INSERT INTO sqlite_stat1 VALUES('videos','index_videos_on_channel_id','1 1');
  INSERT INTO sqlite_stat1 VALUES('videos','sqlite_autoindex_videos_1','1 1');
  CREATE INDEX index_videos_on_channel_id ON videos (channel_id)
  ;
  CREATE INDEX index_videos_on_title ON videos (title COLLATE NOCASE)
  ;
  CREATE INDEX index_channels_on_title ON channels (title COLLATE NOCASE)
  ;
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
  COMMIT;
