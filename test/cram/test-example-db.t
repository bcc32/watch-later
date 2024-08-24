  $ source ./setup.sh

  $ wl debug db path
  XDG_DATA_DIR/watch-later/watch-later.db

  $ wl list
  ((video_info
    ((channel_id UCSJ4gkVC6NrvII8umztf0Ow) (channel_title ChilledCow)
     (video_id -FlxM_0S2lA)
     (video_title "Lofi hip hop mix - Beats to Relax/Study to [2018]")
     (published_at ()) (duration ())))
   (watched true))
  ((video_info
    ((channel_id UCJ7W3mGBp1SCC-5Xsy4ufZQ)
     (channel_title "GEMN Chill Out & Lofi Music") (video_id qvUWA45GOMg)
     (video_title
      "Chill Lo-fi Hip-Hop Beats FREE | Lofi Hip Hop Chillhop Music Mix | GEMN")
     (published_at ()) (duration ())))
   (watched false))

  $ sqlite3 "$(dbpath)" .dump
  PRAGMA foreign_keys=OFF;
  BEGIN TRANSACTION;
  CREATE TABLE channels (
    id    TEXT PRIMARY KEY,
    title TEXT NOT NULL
  );
  INSERT INTO channels VALUES('UCSJ4gkVC6NrvII8umztf0Ow','ChilledCow');
  INSERT INTO channels VALUES('UCJ7W3mGBp1SCC-5Xsy4ufZQ','GEMN Chill Out & Lofi Music');
  CREATE TABLE IF NOT EXISTS "videos" (
    id         TEXT PRIMARY KEY,
    title      TEXT NOT NULL,
    channel_id TEXT NOT NULL REFERENCES channels ON DELETE CASCADE,
    watched    INTEGER NOT NULL DEFAULT 0
  , published_at TEXT, duration INTEGER);
  INSERT INTO videos VALUES('-FlxM_0S2lA','Lofi hip hop mix - Beats to Relax/Study to [2018]','UCSJ4gkVC6NrvII8umztf0Ow',1,NULL,NULL);
  INSERT INTO videos VALUES('qvUWA45GOMg','Chill Lo-fi Hip-Hop Beats FREE | Lofi Hip Hop Chillhop Music Mix | GEMN','UCJ7W3mGBp1SCC-5Xsy4ufZQ',0,NULL,NULL);
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
    published_at,
    duration,
    watched
  )
    AS
    SELECT videos.id, videos.title, channels.id, channels.title, videos.published_at, videos.duration, videos.watched
      FROM videos JOIN channels ON videos.channel_id = channels.id;
  COMMIT;
