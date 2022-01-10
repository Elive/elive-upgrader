#!/bin/bash
SOURCE="$0"
source /usr/lib/elive-tools/functions
#EL_REPORTS="1"
#el_make_environment
#. gettext.sh
#TEXTDOMAIN=""
#export TEXTDOMAIN

main(){
    source /etc/adduser.conf || true
    [[ -z "$DHOME" ]] && DHOME=/home

    for userfirst in $DHOME/*
    do
        if [[ -e "/etc/sudoers.d/sudo_nopasswd_generic_${user_first}" ]] ; then
            echo "# profile-sync-daemon which we need (sometimes) for browsers requires privileges\n$user_first ALL=(ALL) NOPASSWD: /usr/bin/psd-overlay-helper" >> "/etc/sudoers.d/sudo_nopasswd_generic_${user_first}"
            chmod 0440 "/etc/sudoers.d/sudo_nopasswd_generic_${user_first}"
        fi
    done

}

#
#  MAIN
#
main "$@"

# vim: set foldmethod=marker :

