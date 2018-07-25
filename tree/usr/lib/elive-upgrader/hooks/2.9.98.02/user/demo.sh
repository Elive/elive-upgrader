#!/bin/bash
#source /usr/lib/elive-tools/functions


mkdir -p "$HOME/.ecomp"
cp -a /etc/skel/.ecomp/ecomp.cfg.full "$HOME/.ecomp/"
cp -a /etc/skel/.ecomp/ecomp.cfg.normal "$HOME/.ecomp/"

true

#echo "$(date +%s)|$(pwd)|$0|user:${USER}|display:${DISPLAY}" >> /tmp/logs-user.txt

