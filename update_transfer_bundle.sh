#!/bin/bash

# update_transfer_bundle.sh
# Sync updated bundle artifacts to the transfer drive without re-running the export.
#
# Use when bundle artifacts have changed (new ISOs, updated roles, updated
# inventory archive) but the Pulp content export does not need to be repeated.
# Uses rsync — only changed or new files are transferred. Fast.
#
# The Pulp export content at the drive root is never touched.
#
# Usage:
#   ./update_transfer_bundle.sh -b <connected_basevars_file> -d <bundle_dir>
#   ./update_transfer_bundle.sh -b example.ca_inventory_basevars.yml \
#       -d /home/ansiblerunner/rhis_export/Library_2026-06-07_1416
#
# Common scenarios:
#   - ISOs were generated or updated after the export
#   - Inventory archive was regenerated
#   - Compliance roles were updated
#   - content_imports.yml was regenerated
#
# Prerequisites:
#   - Transfer drive mounted at --media-path on the satellite
#   - Bundle directory exists on the satellite (export was previously run)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

bv_file=""
bundle_dir=""
media_path="/mnt/rhis_transfer"
RHIS_ROOT="$(cd "$(dirname "$0")" && pwd)"

usage() {
    echo "Usage: update_transfer_bundle.sh [options]"
    echo ""
    echo "Sync updated bundle artifacts to the transfer drive without re-exporting."
    echo "Only changed files are transferred — fast."
    echo ""
    echo "Options:"
    echo "    -b | --basevars-file <file>   Connected (lowside) basevars file"
    echo "    -d | --bundle-dir <path>      Bundle staging directory on the satellite"
    echo "    -m | --media-path <path>      Transfer drive mount point (default: /mnt/rhis_transfer)"
    echo "    -h | --help                   Show this message"
    echo ""
    echo "Examples:"
    echo "    # After generating new ISOs:"
    echo "    ./update_transfer_bundle.sh \\"
    echo "        -b example.ca_inventory_basevars.yml \\"
    echo "        -d /home/ansiblerunner/rhis_export/Library_2026-06-07_1416"
    echo ""
    echo "    # With non-default drive mount:"
    echo "    ./update_transfer_bundle.sh \\"
    echo "        -b example.ca_inventory_basevars.yml \\"
    echo "        -d /home/ansiblerunner/rhis_export/Library_2026-06-07_1416 \\"
    echo "        -m /mnt/transfer"
    exit 1
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -b|--basevars-file) bv_file="$2"; shift ;;
        -d|--bundle-dir)    bundle_dir="$2"; shift ;;
        -m|--media-path)    media_path="$2"; shift ;;
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

DOMAIN=$(grep "basevars_global_domain_name:" "$RHIS_ROOT/$bv_file" | awk '{print $2}' | tr -d '"')
DEPLOYMENT_DIR="${RHIS_ROOT}/deployments/${DOMAIN}"

if [[ ! -d "$DEPLOYMENT_DIR" ]]; then
    echo -e "${RED}ERROR: Deployment not found: ${DEPLOYMENT_DIR}${NC}"
    echo "Run: ./inventory_update.sh -b ${bv_file}"
    exit 1
fi

echo -e "${GREEN}Updating transfer bundle (delta sync only — no export)${NC}"
echo " Domain:      ${DOMAIN}"
echo " Bundle dir:  ${bundle_dir}"
echo " Drive mount: ${media_path}"
echo ""

printf "${GREEN}Start Time: %(%T)T${NC}\n" -1
SECONDS=0

podman run --rm \
  --entrypoint /bin/bash \
  -v "${DEPLOYMENT_DIR}/inventory:/rhis/vars/external_inventory:Z" \
  -v "${DEPLOYMENT_DIR}/group_vars:/rhis/vars/group_vars:Z" \
  -v "${DEPLOYMENT_DIR}/host_vars:/rhis/vars/host_vars:Z" \
  -v "${DEPLOYMENT_DIR}/logs:/rhis/vars/logs:Z" \
  -v "${DEPLOYMENT_DIR}/vars:/rhis/vars/vars:Z" \
  -v "${DEPLOYMENT_DIR}/vault:/rhis/vars/vault:Z" \
  -v "${RHIS_ROOT}:/rhis/rhis-builder-inventory:Z" \
  -v "${RHIS_ROOT}/../rhis-builder-satellite:/rhis/rhis-builder-satellite:Z" \
  -v "${HOME}/.ssh:/root/.ssh:Z" \
  --hostname provisioner \
  quay.io/parmstro/rhis-provisioner-9-2.5:latest \
  -c "cd /rhis/rhis-builder-satellite && \
      ansible-playbook \
        --inventory /rhis/vars/external_inventory/inventory \
        --user ansiblerunner \
        --private-key /root/.ssh/id_ed25519 \
        --vault-password-file /root/.ssh/vault.txt \
        --extra-vars 'vault_dir=/rhis/vars/vault vars_dir=/rhis/vars/host_vars' \
        --extra-vars 'bundle_dir=${bundle_dir} media_path=${media_path}' \
        --limit=sat_primary \
        copy_to_transfer_media.yml 2>&1 | tee /rhis/vars/logs/update_transfer_bundle.log"

EXIT_CODE=$?

duration=$SECONDS
printf "\n${GREEN}End Time: %(%T)T${NC}\n" -1
TZ=UTC0 printf "${GREEN}Elapsed Time: %(%T)T${NC}\n" $duration

if [[ $EXIT_CODE -ne 0 ]]; then
    echo -e "${RED}ERROR: Bundle update failed with exit code ${EXIT_CODE}${NC}"
    echo "  Check: ${DEPLOYMENT_DIR}/logs/update_transfer_bundle.log"
    exit $EXIT_CODE
fi

SAT_HOST="satellite1.${DOMAIN}"

echo ""
echo -e "${GREEN}Validating transfer drive at ${media_path} on ${SAT_HOST}...${NC}"

VALIDATE_SCRIPT="${RHIS_ROOT}/../rhis-provisioner-container/rhis-provisioner/validate_import_bundle.sh"

ssh -o StrictHostKeyChecking=no \
    -i "${HOME}/.ssh/id_ed25519" \
    "ansiblerunner@${SAT_HOST}" \
    "sudo bash -s -- -d ${media_path}" \
    < "${VALIDATE_SCRIPT}" \
  2>&1 | tee "${DEPLOYMENT_DIR}/logs/update_transfer_bundle_validate.log"

VALIDATE_EXIT=${PIPESTATUS[0]}

if [[ $VALIDATE_EXIT -ne 0 ]]; then
    echo -e "${RED}Drive validation failed — resolve failures before transporting.${NC}"
    echo "  Check: ${DEPLOYMENT_DIR}/logs/update_transfer_bundle_validate.log"
    exit $VALIDATE_EXIT
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Transfer bundle updated and drive validated${NC}"
echo -e "  Bundle log:     ${DEPLOYMENT_DIR}/logs/update_transfer_bundle.log"
echo -e "  Validation log: ${DEPLOYMENT_DIR}/logs/update_transfer_bundle_validate.log"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
