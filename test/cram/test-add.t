  $ source ./setup.sh

Add a new video to the database.

  $ wl add 'https://www.youtube.com/watch?v=sjkrrmBnpGE'

  $ wl list -video-id sjkrrmBnpGE
  ((video_info
    ((channel_id UC1dVfl5-I98WX3yCy8IJQMg)
     (channel_title "Quiet Quest - Study Music") (video_id sjkrrmBnpGE)
     (video_title
      "Ambient Study Music To Concentrate - 4 Hours of Music for Studying, Concentration and Memory")
     (published_at ("2019-11-25 10:00:09Z")) (duration (3h57m52s))))
   (watched false))

Add new videos from a playlist (which has PlaylistItem resources instead of
Video resources).

  $ wl add -playlist 'https://www.youtube.com/playlist?list=PLZHQObOWTQDOqzmnORfqizZK-TcBE09jR'
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
    ((channel_id UC1dVfl5-I98WX3yCy8IJQMg)
     (channel_title "Quiet Quest - Study Music") (video_id sjkrrmBnpGE)
     (video_title
      "Ambient Study Music To Concentrate - 4 Hours of Music for Studying, Concentration and Memory")
     (published_at ("2019-11-25 10:00:09Z")) (duration (3h57m52s))))
   (watched false))
  ((video_info
    ((channel_id UCYO_jab_esuFRV4b17AJtAw) (channel_title 3Blue1Brown)
     (video_id 84hEmGHw3J8) (video_title "A Curious Pattern Indeed")
     (published_at ("2015-04-11 08:19:03Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCYO_jab_esuFRV4b17AJtAw) (channel_title 3Blue1Brown)
     (video_id K8P8uFahAgc)
     (video_title "Circle Division Solution (old version)")
     (published_at ("2015-05-24 05:25:09Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCYO_jab_esuFRV4b17AJtAw) (channel_title 3Blue1Brown)
     (video_id -9OUyo8NFZg) (video_title "Euler's Formula and Graph Duality")
     (published_at ("2015-06-21 06:05:43Z")) (duration ())))
   (watched false))
