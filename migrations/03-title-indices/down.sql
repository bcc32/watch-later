BEGIN;

DROP INDEX index_videos_on_title;
DROP INDEX index_channels_on_title;

PRAGMA user_version = 2;

COMMIT;
