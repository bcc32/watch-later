BEGIN;

CREATE INDEX index_videos_on_title ON videos (title COLLATE NOCASE);
CREATE INDEX index_channels_on_title ON channels (title COLLATE NOCASE);

PRAGMA user_version = 3;

COMMIT;
