export XDG_CONFIG_DIR=$HOME/.config
export HOME=$TMPDIR/home
export XDG_DATA_DIR=$TMPDIR/data
export BROWSER=echo
export BUILD_PATH_PREFIX_MAP="HOME=$HOME:XDG_DATA_DIR=$XDG_DATA_DIR:$BUILD_PATH_PREFIX_MAP"

reset_db() {
    mkdir -p "$XDG_DATA_DIR/watch-later/"
    install -m 644 ./example-db "$XDG_DATA_DIR/watch-later/watch-later.db"
}
reset_db