#!/bin/bash
source /usr/lib/elive-tools/functions

if pidof cairo-dock 1>/dev/null 2>&1 ; then
    if ! grep -qs "^default icon directory=gnome" "$HOME/.config/cairo-dock/current_theme/cairo-dock.conf" ; then

        killall cairo-dock
        sync
        sed -i -e "s|^default icon directory=.*$|default icon directory=gnome|g" "$HOME/.config/cairo-dock/current_theme/cairo-dock.conf"
        sed -i -e "s|^default icon directory=.*$|default icon directory=gnome|g" "$HOME/.config/cairo-dock/current_theme/cairo-dock-simple.conf"
        cairo-dock &

        if [[ -x "$( which notify-send )" ]] ; then
            el_notify "normal" "gwget" "Cairo Dock Icons" "Wohooo! Elive repaired your cairo-dock icons! :)"
        fi
    fi
fi


