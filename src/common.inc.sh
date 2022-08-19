#!/bin/sh

INSTANCE="gettogether.community"
VAR="cache"
mkdir -p "$VAR"

curl2() {
    case "$1" in
        */events/all/)
            local HTML="$VAR/all-$DEBUG.html"
            ;;
        */events/*/0/)
            local ID="`echo "$1" | sed -r "s~^.*/([0-9]+)/[^/]+/$~\1~"`"
            local HTML="$VAR/event-$ID.html"
            ;;
        http*/*/*/)
            local SLUG="`echo "$1" | sed -r "s~^.*/([^/]+)/$~\1~"`"
            local HTML="$VAR/team-$SLUG.html"
    esac

    if [ -n "$DEBUG" ] && [ -e "$HTML" ]; then
        NOW="`get_file_time "$HTML"`"
        cat "$HTML"
        return
    fi

    if [ -n "$CURL2SLEEP" ]; then
      sleep 1
    else
      CURL2SLEEP="1"
    fi

    curl \
        -A "GetTogether-antispam/0.1" \
        --connect-timeout 30 \
        --compress \
        --max-time 40 \
        "$@" |
    if [ -n "$DEBUG" ] && ! [ -e "$HTML" ]; then
        tee "$HTML"
    else
        cat
    fi
}

get_new_events() {
    local ALLMTIP="$VAR/all-mti.csv"
    local ALLMTI="$VAR/all-mti-new.csv"
    local DELISTED="$VAR/delisted.csv.gz"
    local TOLIST="$VAR/tolist.tmp.csv"
    ALLZPREV="$VAR/all.csv.gz"
    ALLZ="$VAR/all-new.csv.gz"

    get_all_events

    zcat "$ALLZ" |
    sed -nr "s~^([0-9]+\t[0-9]+\t).*$~\1${NOW}~; T e; p; :e" |
    if [ -f "$ALLMTIP" ]; then
        melded_mti "$NOW" "$ALLMTIP" |
        tee "$ALLMTI" |
        sed -nr "s~^-([0-9]+\t)[^\t]*\t(([^\t]*)\t)?([0-9]+)$~\1\3\t\4~; T e; p; :e" > "$TOLIST"

        mv "$ALLMTI" "$ALLMTIP"

        zcat "$ALLZPREV" |
        join -t "`printf "\t"`" "$TOLIST" - |
        gzip >> "$DELISTED"

        mv "$ALLZ" "$ALLZPREV"

        sed -nr "s~^([0-9]+\t)[^\t]*\t(([^\t]*)\t)?(${NOW})$~\1\3\t\4~; T e; p; :e" < "$ALLMTIP" > "$TOLIST"
        zcat "$ALLZPREV" |
        join -t "`printf "\t"`" "$TOLIST" -

        rm "$TOLIST"
    else
        cat > "$ALLMTIP"
        mv "$ALLZ" "$ALLZPREV"
    fi
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

# all event details listed now
# new event details listed now compared to last poll
# all event details listed in last poll
# all event ID, multiplicity, timestamp in last poll
# all delisted event details ever
# all team id, name, cover ever

get_all_events_soup() {
    sed -nr "
        s~^\s*<a href=\"/events/([^/\"]+)/([^/\"]+)/\".*$~event_id\t\1\nevent_slug\t\2~
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
    awk -F"`printf "\t"`" '
    {
        if ($1 == "event_id") {
            event_id = $2;
        } else if ($1 == "event_slug") {
            event_slug = $2;
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
        if (event_id != "") {
            printf("%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
                event_id, event_slug, team_image_url, event_name,
                team_name, start_time, place_name);
        }
        event_id = "";
        event_slug = "";
        team_image_url = "";
        event_name = "";
        team_name = "";
        start_time = "";
        place_name = "";
    }
    '
}

get_event_page() {
    local EVENTID="$1"

    curl2 "https://$INSTANCE/events/$EVENTID/0/" |
    get_event_soup |
    event_soup2csv
}

get_event_soup() {
    sed "s~\r~~g" "$@" |
    sed -nr "
        s~^\s*<meta property=\"og:url\"\s*content=\"https://[^/\"]+/events/[0-9]+/([^/\"]+)/.*$~slug\t\1~
        t p

        s~^\s*<meta property=\"og:title\"\s*content=\"([^\"]+)\".*$~name\t\1~
        t p

        s~^\s*<meta property=\"og:image\"\s*content=\"([^\"]+)\".*$~og_image\t\1~
        t p

        s~^\s*<div class=\"team-banner\">~team_banner\t~
        T not_team_banner
        N
        s~\n\s*<img class=\"card-img-top\" src=\"([^\"]*)\".*$~\1~
        b p
        :not_team_banner

        s~^\s*<div class=\"container container-secondary mt-3 gt-usertext\">~summary_html\t~
        T not_html_summary
        N
        s~\n\s*<p>~~
        t html_summary
        :html_summary
        N
        s~\n~~
        T p
        s~</p>\s*</div>$~~
        T html_summary
        b p
        :not_html_summary

        s~^\s*<meta property=\"og:description\"\s+content=\"~summary_md\t~
        T not_md_summary
        :md_summary
        s~\" />$~~
        t p
        N
        s~\n~<br>~g
        T p
        b md_summary
        :not_md_summary

        s~^\s*<p class=\"text-muted\">Hosted by <a href=\"/([^/\"]+)/\">([^<>]*)</a></p>$~team_slug\t\1\nteam_name\t\2~
        t p

        s~^\s*\"address\": \"([^\"]+)\".*$~place_address\t\1~
        t p

        s~^\s*<a class=\"\" href=\"/places/([0-9]+)/\">([^<>]*)</a>$~place_id\t\1\nplace_name\t\2~

        s~^\s*\"startDate\": \"([^\"]+)\".*$~start_time\t\1~
        t p
        s~^\s*\"endDate\": \"([^\"]+)\".*$~end_time\t\1~
        t p

        s~^\s*<div class=\"col-3\" width=\"120px\"><b>Website:</b></div><div class=\"col-9\"><a href=\"([^\"]+)\".*$~website\t\1~
        t p

        s~^\s*<div><a href=\"/talk/([0-9]+)/\">([^<>]*)</a> by <a href=\"/speaker/([0-9]+)/\">([^,<>]+)(, ([^<>]+))?</a></div>$~talk_id\t\1\ntalk_title\t\2\ntalk_speaker_id\t\3\ntalk_speaker_name\t\4\ntalk_speaker_title\t\6~
        t p

        s~^\s*<a href=\"([^\"]*)\" target=\"_blank\"><img src=\"(/media/sponsors/[^\"]*)\" alt=\"[^\"]*\" title=\"([^\"]*)\"></a>$~sponsor_website\t\1\nsponsor_image\t\2\nsponsor_name\t\3~
        t p

        s~^\s*<div class=\"col text-muted mb-3\">Limit: ([0-9]+)</div>$~attendee_limit\t\1~
        t p

        s~^\s*<div class=\"card-banner\">$~~
        T not_photo
        n
        N
        s~\n\s*~~
        s~^\s*<a href=\"([^\"]*)\" target=\"_blank\"><img class=\"card-img-top\" src=\"([^\"]*)\" alt=\"([^\"]*)\">$~photo_full\t\1\nphoto_thumb\t\2\nphoto_title\t\3~
        b p
        :not_photo

        s~^\s*<small class=\"text-muted\" style=\"width: 100%; word-break: break-word;overflow-x: hidden;\">([^<>]+)</small>$~photo_caption\t\1~
        t p

        s~^\s*<div class=\"col media gt-profile\">~~
        T not_attendee
        n
        :attendee
        N
        s~</div>$~~
        T attendee
        s~^\s*<img class=\"mr-1 gt-profile-avatar\" src=\"([^\"]*)\".*href=\"/profile/([^\"]*)/\"[^<>]*>([^<>]*)</a>\s*<span[^<>]*>([^<>]*)</span>\s*</h6>\s*(<small class=\"text-muted\">([^<>]*)</small>\s*)?$~attendee_avatar\t\1\nattendee_id\t\2\nattendee_name\t\3\nattendee_attends\t\4\nattendee_host\t\6~
        b p
        :not_attendee

        s~^\s*<span class=\"gt-hover-expose\">(<i [^<>]* title=\"Updated: ([^<>\"]*)\"></i>\s+)?([^<>]*)</span>$~comment_update_time\t\2\ncomment_create_time\t\3~
        t p

        s~^\s*<p id=\"comment-body-([0-9]+)\" style=\"white-space: pre-wrap;\">~comment_id\t\1\ncomment_body\t~
        T not_comment_body
        :comment_body
        s~</p>$~~
        t p
        s~$~<br>~
        N
        s~(<br>)\n~\1~
        t comment_body
        :not_comment_body

        s~^\s*<div class=\"media gt-profile\">~~
        T not_comment_profile
        :comment_profile
        N
        s~\s*</div>$~~
        T comment_profile
        s~^.* src=\"([^\"]*)\".* href=\"/profile/([^\"]*)/\"[^<>]*>([^<>]*)</a>.*~comment_avatar\t\1\ncomment_user_id\t\2\ncomment_user_name\t\3~
        b p
        :not_comment_profile

        s~^\s*<div class=\"col-3\" width=\"120px\"><b>Repeats:</b></div><div class=\"col-9\"><a href=\"/series/([0-9]+)/([^\"]*)/\">~series_id\t\1\nseries_slug\t\2\nseries_repetition\t~
        T not_series
        :series_loop
        s~\s*</a>$~~
        t p
        s~$~<br>~
        N
        s~(<br>)\n\s*~\1~
        t series_loop
        :not_series

        b e
        :p
        p
        :e
    "
}

event_soup2csv() {
    awk -F"`printf "\t"`" -vOFS="\t" '
    {
        if ($1 == "attendee_avatar") {
            save_attendee();
            attendee_avatar = $2;
        } else if ($1 == "attendee_id") {
            attendee_id = $2;
        } else if ($1 == "attendee_name") {
            attendee_name = $2;
        } else if ($1 == "attendee_attends") {
            attendee_attends = $2;
        } else if ($1 == "attendee_host") {
            attendee_host = $2;

        } else if ($1 == "photo_full") {
            save_photo();
            photo_full = $2;
        } else if ($1 == "photo_thumb") {
            photo_thumb = $2;
        } else if ($1 == "photo_title") {
            photo_title = $2;
        } else if ($1 == "photo_caption") {
            photo_caption = $2;

        } else if ($1 == "talk_id") {
            save_talk();
            talk_id = $2;
        } else if ($1 == "talk_title") {
            talk_title = $2;
        } else if ($1 == "talk_speaker_id") {
            talk_speaker_id = $2;
        } else if ($1 == "talk_speaker_name") {
            talk_speaker_name = $2;
        } else if ($1 == "talk_speaker_title") {
            talk_speaker_title = $2;

        } else if ($1 == "comment_avatar") {
            save_comment();
            comment_avatar = $2;
        } else if ($1 == "comment_user_id") {
            comment_user_id = $2;
        } else if ($1 == "comment_user_name") {
            comment_user_name = $2;
        } else if ($1 == "comment_update_time") {
            comment_update_time = $2;
        } else if ($1 == "comment_create_time") {
            comment_create_time = $2;
        } else if ($1 == "comment_id") {
            comment_id = $2;
        } else if ($1 == "comment_body") {
            comment_body = $2;

        } else if ($1 == "sponsor_website") {
            save_sponsor();
            sponsor_website = $2;
        } else if ($1 == "sponsor_image") {
            sponsor_image = $2;
        } else if ($1 == "sponsor_name") {
            sponsor_name = $2;

        } else {
            save();
            print;
        }
    }

    END {
        save();
    }

    function save() {
        save_attendee();
        save_photo();
        save_talk();
        save_comment();
        save_sponsor();
    }

    function save_attendee() {
        if (attendee_avatar != "") {
            printf("ateendee\t%d\t%s\t%s\t%s\t%s\t%s\n",
                attendee_index, attendee_avatar, attendee_id,
                attendee_name, attendee_attends, attendee_host);
            attendee_index += 1;
        }
        attendee_avatar = "";
        attendee_id = "";
        attendee_name = "";
        attendee_attends = "";
        attendee_host = "";
    }

    function save_photo() {
        if (photo_full != "") {
            printf("photo\t%d\t%s\t%s\t%s\t%s\n",
                photo_index, photo_full, photo_thumb,
                photo_title, photo_caption);
            photo_index += 1;
        }
        photo_full = "";
        photo_thumb = "";
        photo_title = "";
        photo_caption = "";
    }

    function save_talk() {
        if (talk_id != "") {
            printf("talk\t%d\t%s\t%s\t%s\t%s\t%s\n",
                talk_index, talk_id, talk_title,
                talk_speaker_id, talk_speaker_name, talk_speaker_title);
            talk_index += 1;
        }
        talk_id = "";
        talk_title = "";
        talk_speaker_id = "";
        talk_speaker_name = "";
        talk_speaker_title = "";
    }

    function save_comment() {
        if (comment_avatar != "") {
            printf("comment\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
                comment_index,
                comment_avatar, comment_user_id, comment_user_name, comment_update_time,
                comment_create_time, comment_id, comment_body);
            comment_index += 1;
        }
        comment_avatar = "";
        comment_user_id = "";
        comment_user_name = "";
        comment_update_time = "";
        comment_create_time = "";
        comment_id = "";
        comment_body = "";
    }

    function save_sponsor() {
        if (sponsor_website != "") {
            printf("sponsor\t%d\t%s\t%s\t%s\n",
                sponsor_index,
                sponsor_website, sponsor_image, sponsor_name);
            sponsor_index += 1;
        }
        sponsor_website = "";
        sponsor_image = "";
        sponsor_name = "";
    }
    '
}

get_team_soup() {
  sed "s~\r~~g" "$@" |
  sed -nr "
    s~^\s*<h2 class=\"team-title\">\s*(\S[^<>]*)</h2>$~name\t\1~
    t p

    s~^\s*<img class=\"card-img-top\" src=\"([^\"]*)\".*$~banner_path\t\1~
    t p

    s~^\s*<a href=\"/([^/<>\"]+)/\" class=\"btn btn-default btn-sm\">Summary</a>$~slug\t\1~
    t p

    s~^\s*<a href=\"/team/([0-9]+)/events\.ics\".*$~id\t\1~
    t p

    s~^\s*<div class=\"col-md-9 gt-usertext\"><p>~summary_html\t~
    T not_html_summary
    :html_summary
    N
    s~\n~~
    T p
    s~</p></div>$~~
    T html_summary
    b p
    :not_html_summary

    s~^\s*<div class=\"col-md-3\"><b>Website:</b></div><div class=\"col-md-6\"><a href=\"([^\"]+)\".*$~website\t\1~
    t p

    s~^\s*<div class=\"col-md-3\"><b>City:</b></div><div class=\"col-md-6\"><a href=\"/[?]city=([0-9]+)\">([^,<>]*)(, ([^<>]*))?</a></div>$~city_id\t\1\ncity_name\t\2\ncity_country\t\4~
    t p

    s~^\s*<div class=\"col\"><a href=\"/events/([0-9]+)/([^/]+)/\">([^<>]+)</a></div>~\1\t\2\t\3~
    T not_event
    :event
    N
    s~\s*</div>\s*</div>~~
    T event
    s~^([^\n]*)\n\s*<div class=\"col\">(None|([^<>]+), ([^<>,]+))</div>\s*<div class=\"col\">([^<>]+)~event\t\1\t\3\t\4\t\5~
    b p
    :not_event

    s~^\s*<img class=\"mr-1 gt-profile-avatar\" src=\"([^\"]+)\"[^>]*>~\1~
    T not_member
    :member
    N
    s~\s*</div>\s*</div>~~
    T member
    s~^([^\n]*)\n.*<h6 class=\"mt-0 mb-0\"><a href=\"/profile/([0-9]+)/\" title=\"'s profile\">([^<>]+)</a></h6>(\s*<small class=\"text-muted\">([^<>]+)</small>)?$~member\t\1\t\2\t\3\t\5~
    s~\n~~g
    b p
    :not_member

    b e
    :p
    p
    :e
  "
}

get_file_time() {
    ls --no-group --time-style=+%s -l "$@" 2>/dev/null |
    cut -d " " -f 5
}

classify_events() {
    SPAM="$VAR/new-events-spam.csv"
    REVIEW="$VAR/new-events-review.csv"
    HAM="$VAR/new-events-ham.csv"
    SPAMPAT="$VAR/pattern-team-spam.csv"
    HAMPAT="$VAR/pattern-team-ham.csv"
    touch "$SPAMPAT" "$HAMPAT"

    local TMP="$VAR/tmp-new-events.csv"

    permute_event_cols "$@" |
    tee "$TMP" |
    grep -Ff "$SPAMPAT" - > "$SPAM"

    grep -vFf "$SPAMPAT" "$TMP" |
    grep -Ff "$HAMPAT" - > "$HAM"

    grep -vFf "$SPAMPAT" -f "$HAMPAT" "$TMP" |
    classify_events_heuristically

    rm "$TMP"
}

classify_events_heuristically() {
  local TMP="$VAR/tmp-event.csv"

  local EVENTID
  TAB="`printf "\t"`"

  while IFS="$TAB" read EVENTID X; do
    local LINE="`printf "%s\t%s" "$EVENTID" "$X"`"

    get_event_page "$EVENTID" |
    tee "$TMP" |
    classify_whole_event_heuristically |
    {
      read VERDICT
      if [ "$VERDICT" = "spam" ]; then
        echo "$LINE" >> "$SPAM"
        mark_spammer "$LINE"
      else
        {
          printf "id\t%s\n" "$EVENTID"
          cat "$TMP"
        } >> "$REVIEW"
      fi
    }
  done

  rm "$TMP" 2>/dev/null
}

mark_spammer() {
  echo make spammer "$1" >&2 #DEBUG
  echo "$1" |
  get_uniq_part_for_mark >> "$SPAMPAT"
}

get_uniq_part_for_mark() {
  sed -rn "
    s~^([^\t]*\t){5}(/media/[^\t]*\t).*$~\t\2~
    t p
    s~^.*(, [^,]+(\t[^\t]*){5})$~\1~
    T e

    :p
    p
    :e
  "
}

classify_whole_event_heuristically() {
  awk -F"$TAB" -vOFS="\t" '
    {
      if ($1 == "start_time") {
        start_time = $2;
      } else if ($1 == "end_time") {
        end_time = $2;
      }
    }

    function get_date_sec(date) {
      ("date -d " date " +%s" ) | getline x
      return x;
    }

    END {
      if ((start_time != "") && (end_time != "")) {
        start_sec = get_date_sec(start_time);
        end_sec = get_date_sec(end_time);
        if (end_sec - start_sec > 24 * 3600) {
          print "spam"
        }
      }
    }
  '
}

permute_event_cols() {
  sed -nr "s~^(([^\t]*\t){4})(([^\t]*\t){4})([^\t]*\t)(.*)$~\1\5\3\6~; T e; p; :e" "$@"
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
