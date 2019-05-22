#!/bin/bash

for userdir in /home/*
do
    if [[ -d "$userdir" ]] ; then
        user="$( basename "$userdir" )"
        chown "${user}:${user}" "${userdir}/.config/elive-tools/el_config"
        chown "${user}:${user}" "${userdir}/.config/elive-tools"
        chown "${user}:${user}" "${userdir}/.config/elive"
        chown "${user}:${user}" "${userdir}/.config"
    fi
done

