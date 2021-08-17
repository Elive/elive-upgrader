#!/bin/bash
source /usr/lib/elive-tools/functions

#$guitool --info --text="New settings have been made available for your E16 desktop, including the elive-pm integration for power management. An upgrade to your desktop is suggested. Doing so will restart your desktop settings to a new provided conf by Elive. You can always find your previous configurations into the directory:  ~/.e16.old/"

#if $guitool --question --text="Upgrade to a new desktop configuration?" ; then
    #/usr/bin/e17-restart-and-remove-conf-file-WARNING-dont-complain
#fi

# reload E16
if [[ -n "$EROOT" ]] ; then
    /usr/share/e16/scripts/e_gen_menu
    eesh restart
    #el_notify normal text-x-news "Elive Upgrader New Features" "Suspend / Hibernate / Lock actions integrated in your E16 desktop"
fi


#if ! grep -qs "Xcursor.theme" "~/.Xdefaults" ; then
    #echo "Xcursor.theme: Breeze_Snow" >> "~/.Xdefaults"
    #xrdb -merge "~/.Xdefaults"
    #sleep 2

    #eesh restart
#fi
