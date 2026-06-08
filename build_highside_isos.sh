#!/bin/bash

# build_highside_isos.sh
# Generate OEMDRV kickstart ISOs for a disconnected (highside) RHIS deployment
# and push them to the satellite's export bundle directory.
#
# Runs directly on the provisioner host — NOT inside the provisioner container.
# ISOs are generated locally then pushed to the satellite bundle so that
# copy_to_transfer_media.yml picks them up automatically on next run.
#
# Usage:
#   ./build_highside_isos.sh -b <highside_basevars_file> -d <satellite_bundle_dir>
#
# Prerequisites:
#   - ansible-playbook available on the provisioner host
#   - rhis-builder-bootstrap-init cloned alongside rhis-builder-inventory
#   - Bootstrap vars at deployments/<domain>/vars/highside_bootstrap_hosts.yml
#   - Vault files at deployments/<domain>/vault/ (must include bootstrap-init vault vars)
#   - SSH access to the satellite host

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

bv_file=""
bundle_dir=""
sshuser="ansiblerunner"
RHIS_ROOT="$(cd "$(dirname "$0")" && pwd)"
BOOTSTRAP_INIT="${RHIS_ROOT}/../rhis-builder-bootstrap-init"
ISO_DIR="/tmp/highside_isos"

usage() {
    echo "Usage: build_highside_isos.sh [options]"
    echo ""
    echo "Options:"
    echo "    -b | --basevars-file <file>     Highside basevars file (e.g. highside.example.ca_inventory_basevars.yml)"
    echo "    -d | --bundle-dir <path>        Bundle staging directory on the satellite"
    echo "                                    (e.g. /home/ansiblerunner/rhis_export/Library_2026-06-07_1416)"
    echo "    -u | --sshuser <user>           SSH user for satellite (default: ansiblerunner)"
    echo "    -h | --help                     Show this message"
    echo ""
    echo "Example:"
    echo "    ./build_highside_isos.sh \\"
    echo "        -b highside.example.ca_inventory_basevars.yml \\"
    echo "        -d /home/ansiblerunner/rhis_export/Library_2026-06-07_1416"
    exit 1
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -b|--basevars-file) bv_file="$2"; shift ;;
        -d|--bundle-dir)    bundle_dir="$2"; shift ;;
        -u|--sshuser)       sshuser="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
    shift
done

if [[ -z "$bv_file" || -z "$bundle_dir" ]]; then
    echo -e "${RED}ERROR: --basevars-file and --bundle-dir are required${NC}"
    usage
fi

if [[ ! -f "$RHIS_ROOT/$bv_file" ]]; then
    echo -e "${RED}ERROR: basevars file not found: $RHIS_ROOT/$bv_file${NC}"
    exit 1
fi

# Derive domain and deployment directory from basevars
DOMAIN=$(grep "basevars_global_domain_name:" "$RHIS_ROOT/$bv_file" | awk '{print $2}' | tr -d '"')
DEPLOYMENT_DIR="${RHIS_ROOT}/deployments/${DOMAIN}"
BOOTSTRAP_VARS="${DEPLOYMENT_DIR}/vars/highside_bootstrap_hosts.yml"

# Derive satellite hostname from the upstream connected deployment
UPSTREAM_DOMAIN=$(grep "basevars_upstream_connected_deployment:" "$RHIS_ROOT/$bv_file" | awk '{print $2}' | tr -d '"')
UPSTREAM_DIR="${RHIS_ROOT}/deployments/${UPSTREAM_DOMAIN}"
SATELLITE=$(grep -A3 "^sat_primary:" "${UPSTREAM_DIR}/inventory/inventory" 2>/dev/null | grep -v "sat_primary:\|hosts:" | awk 'NF{gsub(/:$/, "", $1); print $1; exit}')

for check in "$DEPLOYMENT_DIR" "$BOOTSTRAP_VARS" "$BOOTSTRAP_INIT"; do
    if [[ ! -e "$check" ]]; then
        echo -e "${RED}ERROR: Not found: ${check}${NC}"
        exit 1
    fi
done

if [[ -z "$SATELLITE" ]]; then
    echo -e "${YELLOW}WARNING: Could not determine satellite hostname from upstream inventory${NC}"
    echo -e "${YELLOW}         ISOs will be generated locally but not pushed to satellite${NC}"
fi

echo -e "${GREEN}Building highside kickstart ISOs${NC}"
echo " Domain:       ${DOMAIN}"
echo " Bootstrap:    ${BOOTSTRAP_VARS}"
echo " Satellite:    ${SATELLITE:-unknown}"
echo " Bundle dir:   ${bundle_dir}"
echo " Local ISOs:   ${ISO_DIR}"
echo ""

mkdir -p "${ISO_DIR}"

printf "${GREEN}Start Time: %(%T)T${NC}\n" -1
SECONDS=0

# ── Stage 1: Generate ISOs ────────────────────────────────────────────────────

cat > /tmp/rhis_provisioner_inventory.ini << 'INVENTORY'
[provisioner]
localhost ansible_connection=local
INVENTORY

cd "$BOOTSTRAP_INIT" && \
ansible-playbook \
  --inventory /tmp/rhis_provisioner_inventory.ini \
  --vault-password-file "${HOME}/.ssh/vault.txt" \
  --extra-vars "vault_dir=${DEPLOYMENT_DIR}/vault" \
  --extra-vars "vars_path=${BOOTSTRAP_VARS}" \
  --extra-vars "bootstrap_init_iso_dir=${ISO_DIR}" \
  main.yml

EXIT_CODE=$?
if [[ $EXIT_CODE -ne 0 ]]; then
    echo -e "${RED}ERROR: ISO generation failed with exit code ${EXIT_CODE}${NC}"
    exit $EXIT_CODE
fi

ISO_COUNT=$(ls "${ISO_DIR}"/*.iso 2>/dev/null | wc -l)
if [[ "$ISO_COUNT" -eq 0 ]]; then
    echo -e "${YELLOW}WARNING: No ISOs generated — check generate_oemdrv_iso flags in bootstrap vars${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}Generated ${ISO_COUNT} ISO(s):${NC}"
ls -lh "${ISO_DIR}"/*.iso

# ── Stage 2: Push ISOs to satellite bundle ────────────────────────────────────

if [[ -n "$SATELLITE" ]]; then
    echo ""
    echo -e "${GREEN}Pushing ISOs to ${SATELLITE}:${bundle_dir}/isos/${NC}"
    ssh -o BatchMode=yes "${sshuser}@${SATELLITE}" "mkdir -p '${bundle_dir}/isos'" && \
    rsync -av "${ISO_DIR}/"*.iso "${sshuser}@${SATELLITE}:${bundle_dir}/isos/" && \
    echo -e "${GREEN}ISOs pushed to satellite bundle${NC}" || \
    echo -e "${YELLOW}WARNING: Could not push ISOs to satellite — copy manually${NC}"
fi

duration=$SECONDS
printf "\n${GREEN}End Time: %(%T)T${NC}\n" -1
TZ=UTC0 printf "${GREEN}Elapsed Time: %(%T)T${NC}\n" $duration

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  NEXT STEP: Run copy_to_transfer_media.yml${NC}"
echo -e "  ISOs will be included in the drive bundle automatically."
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
