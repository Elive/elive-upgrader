#!/bin/bash
source /usr/lib/elive-tools/functions

if [[ -n "$EROOT" ]] ; then
    if [[ -d "/usr/share/e16/themes/Elive_Dark/" ]] ; then
        eesh theme use Elive_Dark
    fi
fi

