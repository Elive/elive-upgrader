#!/bin/bash
#source /usr/lib/elive-tools/functions

find /var/lib/apt/lists/ -type f -delete

timeout 600 apt-get update


