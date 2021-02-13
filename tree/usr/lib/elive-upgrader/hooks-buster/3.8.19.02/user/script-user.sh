#!/bin/bash
source /usr/lib/elive-tools/functions


# switch cairo-dock from openg (any) to cairo (software) for stability
if pidof cairo-dock 1>/dev/null 2>&1 ; then
    killall cairo-dock || killall -9 cairo-dock
    is_running=1
fi

sed -i -e 's|default backend=.*|default backend=cairo|g' ~/.config/cairo-dock/.cairo-dock

if ((is_running)) ; then
    cairo-dock &
fi
