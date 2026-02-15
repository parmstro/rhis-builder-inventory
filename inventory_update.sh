#!/bin/bash

echo "Executing inventory update."
podman run -it --env working_directory_external_to_container="$PWD" \
               --volume $PWD:/rhis/external_inventory:Z \
               --workdir /rhis/external_inventory \
               --hostname inventory_update \
               quay.io/s4v0/centosstream10-ansible:latest ansible-playbook -u ansiblerunner inventory_update.yml --extra-vars "working_directory_external_to_container=${working_directory_external_to_container}"
