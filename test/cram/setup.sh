outer_home=$HOME
export XDG_CONFIG_DIR=$HOME/.config
TMPDIR=$(mktemp -dp "$TMPDIR") || exit 1
export HOME=$TMPDIR/home
export XDG_CONFIG_HOME=$TMPDIR/config
export XDG_DATA_HOME=$TMPDIR/data
export BROWSER=echo
export BUILD_PATH_PREFIX_MAP="HOME=$HOME:XDG_CONFIG_HOME=$XDG_CONFIG_HOME:XDG_DATA_HOME=$XDG_DATA_HOME:$BUILD_PATH_PREFIX_MAP"

reset_db() {
  mkdir -p "$XDG_DATA_HOME/watch-later/"
  install -m644 ./example-db "$XDG_DATA_HOME/watch-later/watch-later.db"
}
reset_db

dbpath() {
  wl debug db path
}

sqlite3() {
  # Run sqlite3 with no init file
  command sqlite3 -init /dev/null "$@"
}

# Copy real credentials file into sandbox
if [ -f "$outer_home/.config/watch-later/credentials" ]; then
  mkdir -p "$XDG_CONFIG_HOME/watch-later"
  cp "$outer_home/.config/watch-later/credentials" "$XDG_CONFIG_HOME/watch-later/credentials"
fi
