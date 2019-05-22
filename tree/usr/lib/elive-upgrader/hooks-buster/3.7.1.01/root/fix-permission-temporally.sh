#!/bin/bash

for userdir in /home/*
do
    if [[ -d "$userdir" ]] ; then
        user="$( basename "$userdir" )"
        chown "${user}:${user}" "${userdir}/.config/elive"
    fi
done

