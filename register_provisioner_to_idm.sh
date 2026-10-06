#!/bin/bash

echo "Register Provisioner to IdM"
GREEN='\033[0;32m'
NC='\033[0m' # No Color/Normal
printf "${GREEN}Start Time: %(%T)T${NC}\n" -1
SECONDS=0

deployment=""
ssh_user="ansiblerunner"

usage() {
    echo "Usage: $0 -d <deployment_domain> [-u <ssh_user>]"
    echo
    echo "Register the provisioner host to IdM."
    echo "Run this after IdM is built."
    echo
    echo "Options:"
    echo "  -d, --deployment <domain>   Deployment domain (required, e.g. example.ca)"
    echo "  -u, --user <user>           SSH user (default: ansiblerunner)"
    echo "  -h, --help                  Show this help"
    echo
    echo "You will be prompted for the ssh and vault passwords."
    echo
    echo "Examples:"
    echo "  $0 -d example.ca"
    echo "  $0 -d example.ca -u admin"
    exit 0
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -d|--deployment) deployment="$2"; shift ;;
        -u|--user) ssh_user="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

if [[ -z "$deployment" ]]; then
    echo "ERROR: --deployment is required"
    echo "Run $0 --help for usage"
    exit 1
fi

inventory_dir="deployments/${deployment}"
inventory_file="${inventory_dir}/inventory/inventory"
if [[ ! -f "$inventory_file" ]]; then
    echo "ERROR: Inventory not found at $inventory_file"
    echo "Have you run inventory_update.sh for this deployment?"
    exit 1
fi

vault_dir="${inventory_dir}/vault"

ansible-playbook --inventory "$inventory_dir" \
                 --user "$ssh_user" \
                 --ask-pass \
                 --ask-vault-pass \
                 --extra-vars "vault_dir=$vault_dir" \
                 register_provisioner_to_idm.yml

duration=$SECONDS
printf "\n${GREEN}End Time: %(%T)T${NC}\n" -1
TZ=UTC0 printf "${GREEN}Elapsed Time: %(%T)T${NC}\n" $duration
