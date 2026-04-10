#!/bin/bash
./run_container.sh --secrets-dir '/home/ansiblerunner/rhis/rhis-builder-inventory/deployments/example.ca/vault' \
                   --external-tasks-dir '/home/ansiblerunner/rhis/rhis-builder-inventory/deployments/example.ca/external_tasks' \
                   --files-dir '/home/ansiblerunner/rhis/rhis-builder-inventory/deployments/example.ca/files' \
                   --group-vars-dir '/home/ansiblerunner/rhis/rhis-builder-inventory/deployments/example.ca/group_vars' \
                   --host-vars-dir '/home/ansiblerunner/rhis/rhis-builder-inventory/deployments/example.ca/host_vars' \
                   --inventory-dir '/home/ansiblerunner/rhis/rhis-builder-inventory/deployments/example.ca/inventory' \
                   --templates-dir '/home/ansiblerunner/rhis/rhis-builder-inventory/deployments/example.ca/templates' \
                   --vars-dir '/home/ansiblerunner/rhis/rhis-builder-inventory/deployments/example.ca/vars' \
                   --container-registry 'quay.io' \
                   --container-repo 'parmstro'
