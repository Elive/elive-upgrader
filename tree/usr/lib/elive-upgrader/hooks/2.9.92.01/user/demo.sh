#!/bin/bash
source /usr/lib/elive-tools/functions

if ! grep -qs "touchpad-configurations" "$HOME/.e/e17/applications/startup/.order" && [[ -s "/etc/xdg/autostart/elive-touchpad-configurations.desktop" ]] ; then
    echo "/etc/xdg/autostart/elive-touchpad-configurations.desktop" >> "$HOME/.e/e17/applications/startup/.order"
fi

#echo "$(date +%s)|$(pwd)|$0|user:${USER}|display:${DISPLAY}" >> /tmp/logs-user.txt

