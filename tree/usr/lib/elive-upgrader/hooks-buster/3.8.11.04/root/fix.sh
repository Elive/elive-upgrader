#!/bin/bash
SOURCE="$0"
source /usr/lib/elive-tools/functions

if ! grep -qs "machine-id" /etc/elive-version ; then
    echo -e "machine-id: $( el_get_machine_id )" >> /etc/elive-version
fi


