#!/bin/sh

DEBUG=1
. `dirname $(readlink -f "$0")`/common.inc.sh

for ID in 2965 18440 18431; do
  echo "=$ID"

  curl2 "https://$INSTANCE/events/$ID/0/" |
  get_event_soup |
  event_soup2csv
done |
tee "cache/log.txt"
