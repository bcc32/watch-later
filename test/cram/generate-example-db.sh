#!/bin/sh

cd "$(dirname "$0")" || exit 1
dbpath=./example-db
rm -f "$dbpath"
dune exec -- wl add -dbpath "$dbpath" 'https://www.youtube.com/watch?v=-FlxM_0S2lA'
dune exec -- wl add -dbpath "$dbpath" 'https://www.youtube.com/watch?v=qvUWA45GOMg'
dune exec -- wl mark-watched -dbpath "$dbpath" -anon '-FlxM_0S2lA'
sqlite3 "$dbpath" "PRAGMA journal_mode=DELETE"
chmod -w "$dbpath"
