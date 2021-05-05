#!/bin/bash
source /usr/lib/elive-tools/functions

if zenity --question --text="Do you want to reconfigure the size (scale) of your desktop?" ; then
    elive-scale-desktop
    zenity --info --text="To use this new tool again and reconfigure these sizes, go to your Applications -> Settings and search for 'Desktop Size'"
fi
