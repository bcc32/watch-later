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
  ((video_info
    ((channel_id UC1dVfl5-I98WX3yCy8IJQMg) (channel_title "REPLACE ME")
     (video_id sjkrrmBnpGE) (video_title "REPLACE ME") (published_at ())
     (duration ())))
   (watched false))

Add an existing video to the database, not overwriting any information.  `-mark`
has no effect.

  $ wl add sjkrrmBnpGE -mark true
  $ wl list -video-id sjkrrmBnpGE
  ((video_info
    ((channel_id UC1dVfl5-I98WX3yCy8IJQMg) (channel_title "REPLACE ME")
     (video_id sjkrrmBnpGE) (video_title "REPLACE ME") (published_at ())
     (duration ())))
   (watched false))

Add an existing video to the database, re-fetching information from YouTube, and
marking watched.

  $ wl add -overwrite sjkrrmBnpGE -mark true
  $ wl list -video-id sjkrrmBnpGE
  ((video_info
    ((channel_id UC1dVfl5-I98WX3yCy8IJQMg)
     (channel_title "Quiet Quest - Study Music") (video_id sjkrrmBnpGE)
     (video_title
      "Ambient Study Music To Concentrate - 4 Hours of Music for Studying, Concentration and Memory")
     (published_at ("2019-11-25 10:00:09Z")) (duration (3h57m52s))))
   (watched true))

Add an existing video to the database, re-fetching information from YouTube,
without marking.  The watched status does not change.

  $ wl add -overwrite sjkrrmBnpGE
  $ wl list -video-id sjkrrmBnpGE
  ((video_info
    ((channel_id UC1dVfl5-I98WX3yCy8IJQMg)
     (channel_title "Quiet Quest - Study Music") (video_id sjkrrmBnpGE)
     (video_title
      "Ambient Study Music To Concentrate - 4 Hours of Music for Studying, Concentration and Memory")
     (published_at ("2019-11-25 10:00:09Z")) (duration (3h57m52s))))
   (watched true))

Add existing video to the database via playlist.

  $ wl add 84hEmGHw3J8
  $ wl list -video-id 84hEmGHw3J8
  ((video_info
    ((channel_id UCYO_jab_esuFRV4b17AJtAw) (channel_title 3Blue1Brown)
     (video_id 84hEmGHw3J8) (video_title "A Curious Pattern Indeed")
     (published_at ("2015-04-11 08:19:03Z")) (duration (1m49s))))
   (watched false))

  $ wl add -overwrite -playlist 'https://www.youtube.com/playlist?list=PLZHQObOWTQDOqzmnORfqizZK-TcBE09jR'
  $ wl list -video-id 84hEmGHw3J8
  ((video_info
    ((channel_id UCYO_jab_esuFRV4b17AJtAw) (channel_title 3Blue1Brown)
     (video_id 84hEmGHw3J8) (video_title "A Curious Pattern Indeed")
     (published_at ("2015-04-11 08:19:03Z")) (duration (1m49s))))
   (watched false))
