  $ source ./setup.sh

Insert bogus information for a video.

  $ sqlite3 "$(dbpath)" <<SQL
  > INSERT INTO channels (id, title) VALUES
  >   ('UC1dVfl5-I98WX3yCy8IJQMg', 'REPLACE ME');
  > INSERT INTO videos (id, title, channel_id, watched) VALUES
  >   ('sjkrrmBnpGE', 'REPLACE ME', 'UC1dVfl5-I98WX3yCy8IJQMg', 0);
  > SQL

  $ wl list
  ((video_info
    ((channel_id UCSJ4gkVC6NrvII8umztf0Ow) (channel_title ChilledCow)
     (video_id -FlxM_0S2lA)
     (video_title "Lofi hip hop mix - Beats to Relax/Study to [2018]")))
   (watched true))
  ((video_info
    ((channel_id UCJ7W3mGBp1SCC-5Xsy4ufZQ)
     (channel_title "GEMN Chill Out & Lofi Music") (video_id qvUWA45GOMg)
     (video_title
      "Chill Lo-fi Hip-Hop Beats FREE | Lofi Hip Hop Chillhop Music Mix | GEMN")))
   (watched false))
  ((video_info
    ((channel_id UC1dVfl5-I98WX3yCy8IJQMg) (channel_title "REPLACE ME")
     (video_id sjkrrmBnpGE) (video_title "REPLACE ME")))
   (watched false))

Add an existing video to the database, not overwriting any information.  `-mark`
has no effect.

  $ wl add sjkrrmBnpGE -mark true
  $ wl list -video-id sjkrrmBnpGE
  ((video_info
    ((channel_id UC1dVfl5-I98WX3yCy8IJQMg) (channel_title "REPLACE ME")
     (video_id sjkrrmBnpGE) (video_title "REPLACE ME")))
   (watched false))

Add an existing video to the database, re-fetching information from YouTube, and
marking watched.

  $ wl add -overwrite sjkrrmBnpGE -mark true
  $ wl list -video-id sjkrrmBnpGE
  ((video_info
    ((channel_id UC1dVfl5-I98WX3yCy8IJQMg)
     (channel_title "Quiet Quest - Study Music") (video_id sjkrrmBnpGE)
     (video_title
      "Ambient Study Music To Concentrate - 4 Hours of Music for Studying, Concentration and Memory")))
   (watched true))

Add an existing video to the database, re-fetching information from YouTube,
without marking.  The watched status does not change.

  $ wl add -overwrite sjkrrmBnpGE
  $ wl list -video-id sjkrrmBnpGE
  ((video_info
    ((channel_id UC1dVfl5-I98WX3yCy8IJQMg)
     (channel_title "Quiet Quest - Study Music") (video_id sjkrrmBnpGE)
     (video_title
      "Ambient Study Music To Concentrate - 4 Hours of Music for Studying, Concentration and Memory")))
   (watched true))
