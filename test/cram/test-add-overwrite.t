  $ source ./setup.sh

Insert bogus information for a video.

  $ sqlite3 "$(dbpath)" <<SQL
  > INSERT INTO channels (id, title) VALUES
  >   ('UC1dVfl5-I98WX3yCy8IJQMg', 'REPLACE ME');
  > INSERT INTO videos (id, title, channel_id, watched) VALUES
  >   ('9xwazD5SyVg', 'REPLACE ME', 'UC1dVfl5-I98WX3yCy8IJQMg', 0);
  > SQL

  $ wl list
  ((video_info
    ((channel_id UCSJ4gkVC6NrvII8umztf0Ow) (channel_title ChilledCow)
     (video_id -FlxM_0S2lA)
     (video_title "Lofi hip hop mix - Beats to Relax/Study to [2018]")
     (published_at ()) (duration ())))
   (watched true) (saved false))
  ((video_info
    ((channel_id UCJ7W3mGBp1SCC-5Xsy4ufZQ)
     (channel_title "GEMN Chill Out & Lofi Music") (video_id qvUWA45GOMg)
     (video_title
      "Chill Lo-fi Hip-Hop Beats FREE | Lofi Hip Hop Chillhop Music Mix | GEMN")
     (published_at ()) (duration ())))
   (watched false) (saved false))
  ((video_info
    ((channel_id UC1dVfl5-I98WX3yCy8IJQMg) (channel_title "REPLACE ME")
     (video_id 9xwazD5SyVg) (video_title "REPLACE ME") (published_at ())
     (duration ())))
   (watched false) (saved false))

Add an existing video to the database, not overwriting any information.
`-mark-watched` has no effect.

  $ wl add 9xwazD5SyVg -mark-watched true
  $ wl list -video-id 9xwazD5SyVg
  ((video_info
    ((channel_id UC1dVfl5-I98WX3yCy8IJQMg) (channel_title "REPLACE ME")
     (video_id 9xwazD5SyVg) (video_title "REPLACE ME") (published_at ())
     (duration ())))
   (watched false) (saved false))

Add an existing video to the database, re-fetching information from YouTube, and
marking watched.

  $ wl add -overwrite 9xwazD5SyVg -mark-watched true
  $ wl list -video-id 9xwazD5SyVg
  ((video_info
    ((channel_id UCOR9CnVWpl0hc8AIcD86zJQ)
     (channel_title "Maximilian Mustermann") (video_id 9xwazD5SyVg)
     (video_title "Dummy Video For YouTube API Test")
     (published_at ("2016-04-18 12:00:44Z")) (duration (6s))))
   (watched true) (saved false))

Add an existing video to the database, re-fetching information from YouTube,
without marking.  The watched status does not change.

  $ wl add -overwrite 9xwazD5SyVg
  $ wl list -video-id 9xwazD5SyVg
  ((video_info
    ((channel_id UCOR9CnVWpl0hc8AIcD86zJQ)
     (channel_title "Maximilian Mustermann") (video_id 9xwazD5SyVg)
     (video_title "Dummy Video For YouTube API Test")
     (published_at ("2016-04-18 12:00:44Z")) (duration (6s))))
   (watched true) (saved false))

Add existing video to the database via playlist.

  $ wl add 84hEmGHw3J8
  $ wl list -video-id 84hEmGHw3J8
  ((video_info
    ((channel_id UCYO_jab_esuFRV4b17AJtAw) (channel_title 3Blue1Brown)
     (video_id 84hEmGHw3J8) (video_title "A Curious Pattern Indeed")
     (published_at ("2015-04-11 08:19:03Z")) (duration (1m49s))))
   (watched false) (saved false))

  $ wl add -overwrite -playlist 'https://www.youtube.com/playlist?list=PLE18841CABEA24090'
  $ wl list -video-id 84hEmGHw3J8
  ((video_info
    ((channel_id UCYO_jab_esuFRV4b17AJtAw) (channel_title 3Blue1Brown)
     (video_id 84hEmGHw3J8) (video_title "A Curious Pattern Indeed")
     (published_at ("2015-04-11 08:19:03Z")) (duration (1m49s))))
   (watched false) (saved false))
