#!/bin/sh

DEBUG=1
. `dirname $(readlink -f "$0")`/common.inc.sh

for ID in 2965 18440 18431; do
  echo "=$ID"

  get_event_page "$ID"
done |
tee "cache/log-event.txt"
