#!/bin/bash
./run_container.sh --ansible-ver '2.5' \
                   --secrets-dir '/home/ansiblerunner/rhis/rhis-builder-inventory/example.ca/vault' \
                   --external-tasks-dir '/home/ansiblerunner/rhis/rhis-builder-inventory/example.ca/external_tasks' \
                   --files-dir '/home/ansiblerunner/rhis/rhis-builder-inventory/example.ca/files' \
                   --group-vars-dir '/home/ansiblerunner/rhis/rhis-builder-inventory/example.ca/group_vars' \
                   --host-vars-dir '/home/ansiblerunner/rhis/rhis-builder-inventory/example.ca/host_vars' \
                   --inventory-dir '/home/ansiblerunner/rhis/rhis-builder-inventory/example.ca/inventory' \
                   --templates-dir '/home/ansiblerunner/rhis/rhis-builder-inventory/example.ca/templates' \
                   --vars-dir '/home/ansiblerunner/rhis/rhis-builder-inventory/example.ca/vars' \
                   --container-registry 'quay.io' \
                   --container-repo 'parmstro'
