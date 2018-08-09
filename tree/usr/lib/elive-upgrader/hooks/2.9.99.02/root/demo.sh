#!/bin/bash
#source /usr/lib/elive-tools/functions

if [[ -s "/etc/apt/sources.list.d/debian.list" ]] ; then
    sed -i -e 's|deb.debian.org|repo.wheezy.debian.elivecd.org|g' /etc/apt/sources.list.d/debian.list
    sed -i -e 's|security.debian.org|repo.wheezy.deb-security.elivecd.org|g' /etc/apt/sources.list.d/debian.list
    sed -i -e 's|^deb-src .*$|#&1|g' /etc/apt/sources.list.d/debian.list
fi

if [[ -s "/etc/apt/sources.list" ]] ; then
    sed -i -e 's|deb.debian.org|repo.wheezy.debian.elivecd.org|g' /etc/apt/sources.list
    sed -i -e 's|security.debian.org|repo.wheezy.deb-security.elivecd.org|g' /etc/apt/sources.list
    sed -i -e 's|^deb-src .*$|#&1|g' /etc/apt/sources.list
fi

