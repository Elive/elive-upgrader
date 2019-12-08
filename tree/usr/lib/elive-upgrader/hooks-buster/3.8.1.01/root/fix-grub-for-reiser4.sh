#!/bin/bash

service network-manager stop
sync
sleep 1
rm -f /etc/elive-tools/geolocation/timezones.conf
sync
sleep 1
service network-manager start
## wait for time updates
sleep 40
