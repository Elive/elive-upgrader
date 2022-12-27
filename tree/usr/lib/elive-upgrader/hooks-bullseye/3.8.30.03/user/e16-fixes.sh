#!/bin/bash
source /usr/lib/elive-tools/functions

sed -i -e "s|'menus reload'|menus reload|g" ~/.e16/Init/regenerate-menus.sh
