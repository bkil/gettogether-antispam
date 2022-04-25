#!/bin/sh

. `dirname $(readlink -f "$0")`/common.inc.sh

main() {
    if [ "$*" = "--test" ]; then
        run_tests
        exit 0
    elif [ "$*" = "--debug" ]; then
        DEBUG="1"
    fi

    ALLPREV="$VAR/all.csv.gz"
    ALLZ="$VAR/all-new.csv.gz"
    mkdir -p "$VAR/events"

    local LASTRUN="`get_file_time "$ALLPREV"`"
    NOW="`date +%s`"
    local AGE="$((NOW-LASTRUN))"
    if ! [ "$AGE" -lt 900 ] || [ -n "$DEBUG" ]; then
        get_new_events
        mv "$ALLZ" "$ALLPREV"
    fi
}

main "$@"
