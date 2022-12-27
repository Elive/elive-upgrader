#!/bin/bash

main(){
    # pre {{{
    local var

    # }}}

    # create ulauncher confs
    cd ~
    elive-skel upgrade .config/ulauncher
    elive-skel upgrade .local/share/ulauncher
    killall -q kupfer

    # replace user bindings
    sed -i -e 's|kupfer|elive-launcher-app|g' ~/.e16/bindings.cfg
    if ! grep -qsE "space.*(kupfer|elive-launcher-app)" ~/.e16/bindings.cfg ; then
        echo "KeyDown    C        space                 exec elive-launcher-app" >> ~/.e16/bindings.cfg
    fi

    #elive-launcher-app

    # ask the user if wants to watch the video

}

#
#  MAIN
#
main "$@"

# vim: set foldmethod=marker :
