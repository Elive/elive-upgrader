#!/bin/bash

main(){
    true

    # # create ulauncher confs
    # cd ~
    # elive-skel upgrade .config/ulauncher
    # elive-skel upgrade .local/share/ulauncher
    #
    # # replace user bindings
    # sed -i -e 's|kupfer|elive-launcher-app|g' ~/.e16/bindings.cfg
    # if ! grep -qsE "space.*(kupfer|elive-launcher-app)" ~/.e16/bindings.cfg ; then
    #     echo -e "KeyDown    C        space                 exec elive-launcher-app\n" >> ~/.e16/bindings.cfg
    # fi
    #
    # killall -q kupfer
    # killall -q ulauncher
    # eesh restart
    #
    # # fix notification daemon
    # notification-daemon-restarter
    #
    # add autolauncher
    # if ! grep -qs "lockfs-notify.desktop" ~/.e16/startup-applications.list ; then
    #     echo "/etc/xdg/autostart/lockfs-notify.desktop" >> ~/.e16/startup-applications.list
    #     echo -e "Added lockfs notify launcher"
    # fi
}

#
#  MAIN
#
main "$@"

# vim: set foldmethod=marker :
