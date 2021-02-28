  $ source ./setup.sh

  $ watch-later list
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

  $ watch-later remove -anon -FlxM_0S2lA

  $ watch-later list
  ((video_info
    ((channel_id UCJ7W3mGBp1SCC-5Xsy4ufZQ)
     (channel_title "GEMN Chill Out & Lofi Music") (video_id qvUWA45GOMg)
     (video_title
      "Chill Lo-fi Hip-Hop Beats FREE | Lofi Hip Hop Chillhop Music Mix | GEMN")))
   (watched false))
