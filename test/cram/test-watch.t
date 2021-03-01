  $ source ./setup.sh

Successful browse marks a video as watched.  By default, only unwatched videos
are selectable.

  $ watch-later watch
  https://youtu.be/qvUWA45GOMg

  $ watch-later list -watched false
  $ reset_db

Specify video to watch by ID.

  $ watch-later watch -anon -FlxM_0S2lA
  (monitor.ml.Error (Failure "Cannot specify both video IDs and filter")
   ("Raised at Stdlib.failwith in file \"stdlib.ml\", line 29, characters 17-33"
    "Called from Watch_later__Cmd_watch.command.(fun) in file \"src/cmd_watch.ml\", line 58, characters 28-79"
    "Called from Async_kernel__Monitor.Exported_for_scheduler.schedule'.upon_work_fill_i in file \"src/monitor.ml\", line 295, characters 42-51"
    "Called from Async_kernel__Job_queue.run_jobs in file \"src/job_queue.ml\", line 167, characters 6-47"))
  [1]

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
