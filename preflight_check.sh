#!/bin/bash

deployment=""
hosts="idm_primary,sat_primary"
ssh_user=""

usage() {
    echo "Usage: $0 -d <deployment_domain> [-H <host_pattern>] [-u <ssh_user>]"
    echo
    echo "Run pre-flight connectivity checks against backplane hosts."
    echo
    echo "Options:"
    echo "  -d, --deployment <domain>   Deployment domain (required, e.g. example.ca)"
    echo "  -H, --hosts <pattern>       Ansible host/group pattern (default: idm_primary,sat_primary)"
    echo "  -u, --user <user>           SSH user (default: current user)"
    echo "  -h, --help                  Show this help"
    echo
    echo "Examples:"
    echo "  $0 -d example.ca"
    echo "  $0 -d example.ca -H idm_primary"
    echo "  $0 -d example.ca -H satellite1.example.ca"
    exit 0
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -d|--deployment) deployment="$2"; shift ;;
        -H|--hosts) hosts="$2"; shift ;;
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

inventory="deployments/${deployment}/inventory/inventory"
if [[ ! -f "$inventory" ]]; then
    echo "ERROR: Inventory not found at $inventory"
    echo "Have you run inventory_update.sh for this deployment?"
    exit 1
fi

user_arg=""
[[ -n "$ssh_user" ]] && user_arg="-u $ssh_user"

ansible-playbook -i "$inventory" \
    preflight_check.yml \
    -e "preflight_hosts=$hosts" \
    $user_arg
