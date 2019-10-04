#!/bin/bash
source /usr/lib/elive-tools/functions

if [[ -n "$EROOT" ]] ; then
    if [[ -d "/usr/share/e16/themes/Elive_Dark/" ]] ; then
        rm -f "$HOME/.e16/Init/"*
        rm -f "$HOME/.e16/New/"*
        rm -f "$HOME/.e16/Stop/"*
        cp -a /etc/skel/.e16/Init/* "$HOME/.e16/Init/"
        cp -a /etc/skel/.e16/New/* "$HOME/.e16/New/"
        cp -a /etc/skel/.e16/Stop/* "$HOME/.e16/Stop/"
        sync
        /usr/share/e16/scripts/e_gen_menu
        sync
        eesh theme use Elive_Dark
    fi
fi

