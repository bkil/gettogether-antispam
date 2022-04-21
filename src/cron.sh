#!/bin/sh

main() {
    INSTANCE="gettogether.community"
    VAR="cache"
    mkdir -p "$VAR"
    local ALLC="$VAR/all.csv"
    get_all_events "$ALLC"
}

get_all_events() {
    local ALLH="$VAR/all.html"
    if ! [ -f "$ALLH" ]; then
        curl \
            -A- \
            -o "$ALLH" \
            --compress \
            "https://$INSTANCE/events/all/"
    fi

    get_all_events_soup "$ALLH" |
    event_soup2csv > "$ALLC"
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

event_soup2csv() {
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
        printf("%s\t%s\t%s\t%s\t%s\t%s\n",
            event_url, team_image_url, event_name,
            team_name, start_time, place_name);
        event_url = "";
        team_image_url = "";
        event_name = "";
        team_name = "";
        start_time = "";
        place_name = "";
    }
    '
}

main "$@"
