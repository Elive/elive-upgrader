#!/bin/bash
SOURCE="$0"
source /usr/lib/elive-tools/functions

if ((is_systemd)); then
    systemctl mask tmp.mount
fi
