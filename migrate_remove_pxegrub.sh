#!/bin/bash
# migrate_remove_pxegrub.sh
# Removes legacy PXEGrub v1 (grub legacy) references from a rendered deployment inventory.
# PXEGrub v1 was removed in Satellite 6.19. PXEGrub2 references are not touched.
#
# USAGE:
#   # Preview changes (default) — writes .new files for review, nothing is modified
#   ./migrate_remove_pxegrub.sh -e "inventory_dir=deployments/example.ca"
#
#   # Apply changes in place
#   ./migrate_remove_pxegrub.sh -e "inventory_dir=deployments/example.ca" -e "preview=false"
#
#   # Discard previews without applying
#   find deployments/example.ca -name '*.new' -delete

cd "$(dirname "$0")" || exit 1
ansible-playbook -i localhost, schema/scripts/migrate_remove_pxegrub.yml "$@"
