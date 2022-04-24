#!/bin/sh

main() {
    if [ "$*" = "--test" ]; then
        run_tests
        exit 0
    elif [ "$*" = "--debug" ]; then
        DEBUG="1"
    fi

    INSTANCE="gettogether.community"
    VAR="cache"
    ALLPREV="$VAR/all.csv.gz"
    ALLZ="$VAR/all-new.csv.gz"
    mkdir -p "$VAR"

    local LASTRUN="`get_file_time "$ALLPREV"`"
    NOW="`date +%s`"
    local AGE="$((NOW-LASTRUN))"
    if ! [ "$AGE" -lt 900 ] || [ -n "$DEBUG" ]; then
        get_new_events
        mv "$ALLZ" "$ALLPREV"
    fi
}

curl2() {
    case "$1" in
        */all/)
            local HTML="$VAR/all.html"
    esac
    if [ -n "$DEBUG" ] && [ -f "$HTML" ]; then
        NOW="`get_file_time "$HTML"`"
        cat "$HTML"
        return
    fi

    curl \
        -A "GetTogether-antispam/0.1" \
        --connect-timeout 30 \
        --compress \
        --max-time 40 \
        "$@" |
    if [ -n "$DEBUG" ] && ! [ -f "$HTML" ]; then
        tee "$HTML"
    else
        cat
    fi

    sleep 1
}

get_new_events() {
    local ALLMTIP="$VAR/all-mti.csv"
    local ALLMTI="$VAR/all-mti-new.csv"
    local DELISTED="$VAR/delisted.csv.gz"

    get_all_events

    zcat "$ALLZ" |
    sed -nr "s~^/events/([0-9]+)/[^\t]*\t([0-9]+)\t.*$~\1\t\2\t${NOW}~; T e; p; :e" |
    if [ -f "$ALLMTIP" ]; then
        melded_mti "$NOW" "$ALLMTIP" |
        tee "$ALLMTI" |
        sed -n "s~^-~~; T e; p; :e" |
        gzip >> "$DELISTED"
    else
        cat > "$ALLMTI"
    fi
    mv "$ALLMTI" "$ALLMTIP"
}

melded_mti() {
    local NOW="$1"
    shift
    join -t "`printf "\t"`" -a 1 -a 2 - "$@" |
    awk -vOFS="\t" -vNOW="$NOW" '
    {
        if (substr($1, 0, 1) == "-") {
        } else if ($3 != NOW) {
            $1 = "-" $1;
            print;
        } else if ($4 == "") {
            print;
        } else if ($2 != $4) {
            MAX = $2;
            if ($4 > MAX) {
                MAX = $4;
            }
            print $1 OFS MAX OFS $5 OFS $3;
        } else if ($6 == "") {
            print $1 OFS $4 OFS $5;
        } else {
            print $1 OFS $4 OFS $5 OFS $6;
        }
    }
    '
}

get_all_events() {
    curl2 "https://$INSTANCE/events/all/" |
    get_all_events_soup |
    events_soup2csv |
    sort |
    uniq -c |
    sed -r "s~^\s*(\S+)\s([^\t]*)(\t.*)~\2\t\1\3~" |
    gzip -1 > "$ALLZ"
}

get_all_events_soup() {
    sed -nr "
        s~^\s*<a href=\"(/events/[^\"]+)\".*$~event_url\t\1~
        t p

        s~^\s*<img class=\"card-img-top\" src=\"([^\"]+)\" alt=\"([^\"]*)\".*$~team_image_url\t\1\nevent_name\t\2~
        t p

        s~^\s*<p class=\"card-text\"><strong>(.*)</strong></p>$~team_name\t\1~
        t p

        s~^\s*<small class=\"text-muted\">([^<>]*)(<br/>([^<>]*))?</small>~start_time\t\1\nplace_name\t\3~
        t p

        b e
        :p
        p
        :e
    " "$@"
}

events_soup2csv() {
    awk --field-separator="`printf "\t"`" '
    {
        if ($1 == "event_url") {
            event_url = $2;
        } else if ($1 == "team_image_url") {
            team_image_url = $2;
        } else if ($1 == "event_name") {
            event_name = $2;
        } else if ($1 == "team_name") {
            team_name = $2;
        } else if ($1 == "start_time") {
            start_time = $2;
        } else if ($1 == "place_name") {
            place_name = $2;
            save();
        }
    }

    END {
        save();
    }

    function save() {
        if (event_url != "") {
            printf("%s\t%s\t%s\t%s\t%s\t%s\n",
                event_url, team_image_url, event_name,
                team_name, start_time, place_name);
        }
        event_url = "";
        team_image_url = "";
        event_name = "";
        team_name = "";
        start_time = "";
        place_name = "";
    }
    '
}

get_file_time() {
    ls --no-group --time-style=+%s -l "$@" 2>/dev/null |
    cut -d " " -f 5
}

run_tests() {
    test_melded_mti
}

test_melded_mti() {
    local OLD="tmp1.txt"
    local EXPECT="$tmp2.tmp"

    cat << EOF |
a 1 7
b 3 8 9
c 3 7 9
-d 2 7 8
-e 1 8
f 1 9
EOF
    space2tab > "$EXPECT"

    cat << EOF |
a 1 7
b 2 8
c 2 7 8
d 2 7 8
e 1 8
-g 1 8
EOF
    space2tab > "$OLD"

    cat << EOF |
a 1 9
b 3 9
c 3 9
f 1 9
EOF
    space2tab |
    melded_mti 9 "$OLD" |
    diff -U0 "$EXPECT" -
    S=$?
    rm "$OLD" "$EXPECT"
    [ $S = 0 ] || { echo test_melded_mti >&2; exit $S; }
}

space2tab() {
    sed "s~ ~\t~g"
}

main "$@"
