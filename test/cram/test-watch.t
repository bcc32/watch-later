  $ source ./setup.sh

Successful browse marks a video as watched.  By default, only unwatched videos
are selectable.

  $ watch-later watch
  https://youtu.be/qvUWA45GOMg

  $ watch-later list -watched false
  $ reset_db

Specify video to watch by ID.

  $ watch-later watch -anon -FlxM_0S2lA
  https://youtu.be/-FlxM_0S2lA

  $ watch-later list -watched false
  ((video_info
    ((channel_id UCJ7W3mGBp1SCC-5Xsy4ufZQ)
     (channel_title "GEMN Chill Out & Lofi Music") (video_id qvUWA45GOMg)
     (video_title
      "Chill Lo-fi Hip-Hop Beats FREE | Lofi Hip Hop Chillhop Music Mix | GEMN")))
   (watched false))
  $ reset_db

Specify video to watch by filter.

  $ watch-later watch -channel-id UCJ7W3mGBp1SCC-5Xsy4ufZQ
  https://youtu.be/qvUWA45GOMg

  $ watch-later list -watched false
  $ reset_db

Failure to browse doesn't mark a video as watched.

  $ BROWSER=false watch-later watch
  run ['false' 'https://youtu.be/qvUWA45GOMg']: exited with 1
  browser reload: run ['false' 'https://youtu.be/qvUWA45GOMg']: exited with 1
  [1]

  $ watch-later list -watched false
  ((video_info
    ((channel_id UCJ7W3mGBp1SCC-5Xsy4ufZQ)
     (channel_title "GEMN Chill Out & Lofi Music") (video_id qvUWA45GOMg)
     (video_title
      "Chill Lo-fi Hip-Hop Beats FREE | Lofi Hip Hop Chillhop Music Mix | GEMN")))
   (watched false))
