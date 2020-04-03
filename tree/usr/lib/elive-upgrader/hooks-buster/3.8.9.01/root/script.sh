#!/bin/bash


sed -i -e 's|^kernel.dmesg|kernel.dmesg_restrict = 0|g' /etc/sysctl.d/dmesg.conf  1>/dev/null 2>&1
sysctl -w kernel.dmesg_restrict=0
