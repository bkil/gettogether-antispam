#!/bin/sh

DEBUG=1
. `dirname $(readlink -f "$0")`/common.inc.sh

for SLUG in fsfhu openstreetmap-hungary; do
  echo "=$SLUG"

  curl2 "https://$INSTANCE/$SLUG/" |
  get_team_soup
done |
tee "cache/log.team.txt"
