#!/bin/bash

main(){
    true
    update-grub
    echo -e "Grub Updated"
    # sed -i -e 's|^Package: .*$|#&\nPackage: *|g' /etc/apt/preferences.d/backports_priority.pref
    # sed -i -e 's|^Pin-Priority: .*$|#&\nPin-Priority: 500|g' /etc/apt/preferences.d/backports_priority.pref
    #
    # # reload network-manager daemon
    # systemctl restart NetworkManager.service 1>/dev/null 2>&1 || true
}

#
#  MAIN
#
main "$@"

# vim: set foldmethod=marker :
