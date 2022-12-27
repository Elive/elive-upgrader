#!/bin/bash

if ! grep -qs "# ELIVE START" "$HOME/.crontab" 2>/dev/null ; then
    cat /etc/skel/.crontab >> "$HOME/.crontab"
    crontab "$HOME/.crontab"
fi

# vim: set foldmethod=marker :
