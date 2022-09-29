#!/bin/bash
SOURCE="$0"
source /usr/lib/elive-tools/functions


while read -ru 3 line
do
    if ! echo "$line" | grep -qsw "ext4" ; then
        continue
    fi
    dev="$( echo "$line" | awk '{print $1}' )"
    if [[ -b "$dev" ]] ; then
        if tune2fs -l "$dev" | grep -qsw fast_commit ; then
            el_info "disabling fast_commit in your EXT4 partition '$dev' because can be dangerous for your data"
            tune2fs -O "^fast_commit" "$dev"
        fi
    fi
done 3<<< "$( cat /proc/mounts | grep "^/dev/" )"


