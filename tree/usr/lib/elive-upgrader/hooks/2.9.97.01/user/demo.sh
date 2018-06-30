#!/bin/bash
source /usr/lib/elive-tools/functions


# remove deprecated randr E configurator
if LC_ALL="$EL_LC_EN" enlightenment_remote -module-list | grep -qs "conf_randr.*Enabled" ; then
    enlightenment_remote -module-disable "conf_randr"
    enlightenment_remote -module-unload "conf_randr"
fi
