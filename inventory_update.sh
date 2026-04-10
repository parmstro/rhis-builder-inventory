#!/bin/bash

echo "Executing inventory update."

bv_file="inventory_basevars.yml"

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -b|--basevars-file)
            bv_file="$2"
            shift # Shift past the value
            ;;
        *)
            echo "Unknown option: $1"
            echo "USAGE:"
            echo "./inventory_update.sh -b|--basevars-file yaml_file_pathspec"
            echo "with no parameters the default inventory_basevars.yml file is used"
            exit 1
            ;;
    esac
    shift # Shift past the option
done

podman run --rm --userns=keep-id --env working_directory_external_to_container="$PWD" \
           --volume $PWD:/rhis/external_inventory:Z,U \
           --workdir /rhis/external_inventory \
           --hostname inventory_update \
           quay.io/s4v0/centosstream10-ansible:latest ansible-playbook -e "basevars_file=$bv_file" inventory_update.yml \
           --extra-vars "working_directory_external_to_container=${working_directory_external_to_container}"
