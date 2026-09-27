#!/bin/bash
# import_bundle.sh
# Highside operator entry point — launches the RHIS bundle delivery survey.
# Run from the root of the TRANSFER_DRV:
#   ./import_bundle.sh
#
# See README_FIRST.md for full instructions.

cd "$(dirname "$0")"
exec ansible-playbook import_bundle.yml "$@"
