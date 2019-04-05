#!/bin/bash
#source /usr/lib/elive-tools/functions

# REMOVE HAL DEPENDENCY
# save a virtualmachine profile needed for elive-tools
case "$( dmidecode -s system-product-name )" in
    *"VirtualBox"*)
        MACHINE_VIRTUAL="yes"
        MACHINE_VIRTUAL_TYPE="virtualbox"
        ;;
    *"VMware"*)
        MACHINE_VIRTUAL="yes"
        MACHINE_VIRTUAL_TYPE="vmware"
        ;;
    *"OpenStack Nova"*)
        MACHINE_VIRTUAL="yes"
        MACHINE_VIRTUAL_TYPE="openstack nova"
        ;;
    "Bochs")
        # qemu
        if grep -qs "QEMU" /proc/cpuinfo ; then
            MACHINE_VIRTUAL="yes"
            MACHINE_VIRTUAL_TYPE="qemu"
        fi
        ;;
    *)
        if dmidecode | grep -qs "Family: Virtual Machine" \
            || grep -qs "hypervisor" /proc/cpuinfo ; then

            MACHINE_VIRTUAL="yes"
            MACHINE_VIRTUAL_TYPE="other"
        fi
        ;;
esac

# save confs
if ! [[ -e "/etc/elive/machine-profile" ]] ; then
    mkdir -p /etc/elive
    echo "# Configuration file with variables that can be sourced to get variables related to machine profiles and identifiers" >> /etc/elive/machine-profile
fi

if [[ "$MACHINE_VIRTUAL" = "yes" ]] ; then
    # save profile
    if ! grep -qs "^MACHINE_VIRTUAL=" /etc/elive/machine-profile ; then
        echo "MACHINE_VIRTUAL=\"$MACHINE_VIRTUAL\"" >> /etc/elive/machine-profile
    fi
    if ! grep -qs "^MACHINE_VIRTUAL_TYPE=" /etc/elive/machine-profile ; then
        echo "MACHINE_VIRTUAL_TYPE=\"$MACHINE_VIRTUAL_TYPE\"" >> /etc/elive/machine-profile
    fi
fi

