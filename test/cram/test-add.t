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

  $ wl add -playlist 'https://www.youtube.com/playlist?list=PLE18841CABEA24090'
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
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id -J_xL4IGhJA)
     (video_title "Lecture 1A: Overview and Introduction to Lisp")
     (published_at ("2019-08-22 22:17:39Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id V_7mmwpgJHU)
     (video_title "Lecture 1B: Procedures and Processes; Substitution Model")
     (published_at ("2019-08-22 22:17:21Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id eJeMOEiHv8c) (video_title "Lecture 2A: Higher-order Procedures")
     (published_at ("2019-08-22 22:17:21Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id DrFkf-T-6Co) (video_title "Lecture 2B: Compound Data")
     (published_at ("2019-08-22 22:17:22Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id PEwZL3H2oKg)
     (video_title "Lecture 3A: Henderson Escher Example")
     (published_at ("2019-08-22 22:17:22Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id bV87UzKMRtE)
     (video_title "Lecture 3B: Symbolic Differentiation; Quotation")
     (published_at ("2019-08-22 22:17:21Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id _fXQ1SwKjDg)
     (video_title "Lecture 4A: Pattern Matching and Rule-based Substitution")
     (published_at ("2019-08-22 22:17:22Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id OscT4N2qq7o) (video_title "Lecture 4B: Generic Operators")
     (published_at ("2019-08-22 22:17:21Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id dO1aqPBJCPg)
     (video_title "Lecture 5A: Assignment, State, and Side-effects")
     (published_at ("2019-08-22 22:17:21Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id yedzRWhi-9E) (video_title "Lecture 5B: Computational Objects")
     (published_at ("2019-08-22 22:17:21Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id JkGKLILLy0I) (video_title "Lecture 6A: Streams, Part 1")
     (published_at ("2019-08-22 22:17:21Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id qp05AtXbOP0) (video_title "Lecture 6B: Streams, Part 2")
     (published_at ("2019-08-22 22:17:22Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id aAlR3cezPJg)
     (video_title "Lecture 7A: Metacircular Evaluator, Part 1")
     (published_at ("2019-08-22 22:17:21Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id QVEOq5k6Xi0)
     (video_title "Lecture 7B: Metacircular Evaluator, Part 2")
     (published_at ("2019-08-22 22:17:22Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id rCqMiPk1BJE)
     (video_title "Lecture 8A: Logic Programming, Part 1")
     (published_at ("2019-08-22 22:17:22Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id GReBwkGFZcs)
     (video_title "Lecture 8B: Logic Programming, Part 2")
     (published_at ("2019-08-22 22:17:21Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id cIc8ZBMcqAc) (video_title "Lecture 9A: Register Machines")
     (published_at ("2019-08-22 22:17:22Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id Z8-qWEEwTCk)
     (video_title "Lecture 9B: Explicit-control Evaluator")
     (published_at ("2019-08-22 22:17:21Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id TqO6V3qR9Ws) (video_title "Lecture 10A: Compilation")
     (published_at ("2019-08-22 22:17:21Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id AbK4bZhUk48)
     (video_title "Lecture 10B: Storage Allocation and Garbage Collection")
     (published_at ("2019-08-22 22:17:21Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id 2Op3QLzMgSY)
     (video_title "Lecture 1A | MIT 6.001 Structure and Interpretation, 1986")
     (published_at ("2009-04-08 15:51:22Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id dlbMuv-jix8)
     (video_title "Lecture 1B | MIT 6.001 Structure and Interpretation, 1986")
     (published_at ("2009-04-08 18:13:22Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id erHp3r6PbJk)
     (video_title "Lecture 2A | MIT 6.001 Structure and Interpretation, 1986")
     (published_at ("2009-04-08 18:57:29Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id ymsbTVLbyN4)
     (video_title "Lecture 2B | MIT 6.001 Structure and Interpretation, 1986")
     (published_at ("2009-04-08 19:20:20Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id 2QgZVYI3tDs)
     (video_title "Lecture 3A | MIT 6.001 Structure and Interpretation, 1986")
     (published_at ("2009-04-08 19:52:19Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id X21cKVtGvYk)
     (video_title "Lecture 3B | MIT 6.001 Structure and Interpretation, 1986")
     (published_at ("2009-04-08 19:10:22Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id amf5lTZ0UTc)
     (video_title "Lecture 4A | MIT 6.001 Structure and Interpretation, 1986")
     (published_at ("2009-04-08 20:25:21Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id h6Z7vx9iUB8)
     (video_title "Lecture 4B | MIT 6.001 Structure and Interpretation, 1986")
     (published_at ("2009-04-08 21:05:50Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id jl8EHP1WrWY)
     (video_title "Lecture 5A | MIT 6.001 Structure and Interpretation, 1986")
     (published_at ("2009-04-08 20:57:18Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id SsBxcpkyMMw)
     (video_title "Lecture 5B | MIT 6.001 Structure and Interpretation, 1986")
     (published_at ("2009-04-08 20:29:04Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id a2Qt9uxhNSM)
     (video_title "Lecture 6A | MIT 6.001 Structure and Interpretation, 1986")
     (published_at ("2009-04-08 21:10:33Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id DCub3iqteuI)
     (video_title "Lecture 6B | MIT 6.001 Structure and Interpretation, 1986")
     (published_at ("2009-04-22 17:23:42Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id 0m6hoOelZH8)
     (video_title "Lecture 7A | MIT 6.001 Structure and Interpretation, 1986")
     (published_at ("2009-04-08 22:47:42Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id t5EI5fXX8K0)
     (video_title "Lecture 7B | MIT 6.001 Structure and Interpretation, 1986")
     (published_at ("2009-04-08 21:38:05Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id cyVXjnFL2Ps)
     (video_title "Lecture 8A | MIT 6.001 Structure and Interpretation, 1986")
     (published_at ("2009-04-08 21:52:26Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id R3uRidfSpc4)
     (video_title "Lecture 8B | MIT 6.001 Structure and Interpretation, 1986")
     (published_at ("2009-04-08 22:27:34Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id jPDAPmx4pXE)
     (video_title "Lecture 9A | MIT 6.001 Structure and Interpretation, 1986")
     (published_at ("2009-05-14 16:17:05Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id SLcZXbyGC3E)
     (video_title "Lecture 9B | MIT 6.001 Structure and Interpretation, 1986")
     (published_at ("2009-05-14 16:33:50Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id kNmiTTKiYd4)
     (video_title "Lecture 10A | MIT 6.001 Structure and Interpretation, 1986")
     (published_at ("2009-04-08 23:34:30Z")) (duration ())))
   (watched false))
  ((video_info
    ((channel_id UCEBb1b_L6zDS3xTUrIALZOw) (channel_title "MIT OpenCourseWare")
     (video_id 2s2_FAf-yQs)
     (video_title "Lecture 10B | MIT 6.001 Structure and Interpretation, 1986")
     (published_at ("2009-04-08 23:35:32Z")) (duration ())))
   (watched false))
