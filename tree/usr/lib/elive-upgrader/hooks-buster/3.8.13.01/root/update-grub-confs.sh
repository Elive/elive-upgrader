#!/bin/bash
source /usr/lib/elive-tools/functions

if ! grep -qs "^GRUB_DISABLE_SUBMENU" "/etc/default/grub" ; then
    cat >> "/etc/default/grub" << EOF

# Elive extra confs:
# Disable recovery modes, we don't use them at all and if we do, we should have our own reparation tool like elive-nurse, by other side, the easiest and fastest way to fix an elive is by just reinstalling it (upgrade-mode integrated feature)
GRUB_DISABLE_RECOVERY="true"
# Disable submenus: they are pretty useless and annoying, we want to have our selected kernels well visually and easy to select since the first moment:
GRUB_DISABLE_SUBMENU="y"
# Always save our last selected boot: in any of the cases, is what we should want
GRUB_DEFAULT="saved"
GRUB_SAVEDEFAULT="true"

EOF

    sed -i -e 's|^GRUB_GFXMODE=.*$|#&1|g' /etc/default/grub

fi

update-grub || true


