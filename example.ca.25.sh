#!/bin/bash
# Mount ~/rhis_transfer into the container when present (highside: populated by import_bundle.sh).
_transfer_arg=""
[[ -d "${HOME}/rhis_transfer" ]] && _transfer_arg="--transfer-dir ${HOME}/rhis_transfer"

./run_container.sh --ansible-ver '2.5' \
                   --secrets-dir '/home/ansiblerunner/rhis/rhis-builder-inventory/deployments/example.ca/vault' \
                   --external-tasks-dir '/home/ansiblerunner/rhis/rhis-builder-inventory/deployments/example.ca/external_tasks' \
                   --files-dir '/home/ansiblerunner/rhis/rhis-builder-inventory/deployments/example.ca/files' \
                   --group-vars-dir '/home/ansiblerunner/rhis/rhis-builder-inventory/deployments/example.ca/group_vars' \
                   --host-vars-dir '/home/ansiblerunner/rhis/rhis-builder-inventory/deployments/example.ca/host_vars' \
                   --inventory-dir '/home/ansiblerunner/rhis/rhis-builder-inventory/deployments/example.ca/inventory' \
                   --logs-dir '/home/ansiblerunner/rhis/rhis-builder-inventory/deployments/example.ca/logs' \
                   --templates-dir '/home/ansiblerunner/rhis/rhis-builder-inventory/deployments/example.ca/templates' \
                   --vars-dir '/home/ansiblerunner/rhis/rhis-builder-inventory/deployments/example.ca/vars' \
                   --ssh-dir '/home/ansiblerunner/.ssh' \
                   --container-registry 'quay.io' \
                   --container-repo 'parmstro' \
                   ${_transfer_arg}
