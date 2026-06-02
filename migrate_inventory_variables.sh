#!/bin/bash
# migrate_inventory_variables.sh
# Wrapper to run the variable migration playbook from the repo root.
# All arguments are passed through to the playbook.
#
# USAGE:
#   ./migrate_inventory_variables.sh -e "basevars_file=example.ca_inventory_basevars.yml"
#   ./migrate_inventory_variables.sh -e "basevars_file=example.ca_inventory_basevars.yml" -e "preview=false"
#   ./migrate_inventory_variables.sh -e "inventory_dir=deployments/example.ca/"

cd "$(dirname "$0")" || exit 1
ansible-playbook -i localhost, schema/scripts/migrate_inventory_variables.yml "$@"
