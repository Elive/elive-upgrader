#!/bin/bash

main(){
    # fix tmux conf for root in order to not break elive-upgrader UX
    sed -i -e 's|^if-shell.*message_welcome.*$|#&|g' "/root/.tmux.conf"
}

#
#  MAIN
#
main "$@"

# vim: set foldmethod=marker :
