#!/bin/bash

main(){
    sed -i -e 's|^Package: .*$|#&\nPackage: *|g' /etc/apt/preferences.d/backports_priority.pref
    sed -i -e 's|^Pin-Priority: .*$|#&\nPin-Priority: 500|g' /etc/apt/preferences.d/backports_priority.pref
}

#
#  MAIN
#
main "$@"

# vim: set foldmethod=marker :
