#!/bin/bash
# validate_drive.sh
# Validate the RHIS transfer drive in place on the satellite.
# Run this any time — after export, after update, or before physical transport.
#
# USAGE:
#   ./validate_drive.sh [options]
#
# OPTIONS:
#   -b | --basevars-file <file>   Lowside basevars file (e.g. example.ca_inventory_basevars.yml)
#                                 REQUIRED
#   -m | --media-path <path>      Transfer drive mount point on the satellite
#                                 (default: /mnt/rhis_transfer)
#   -h | --help                   Show this help

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

RHIS_ROOT="$(cd "$(dirname "$0")" && pwd)"
bv_file=""
media_path="/mnt/rhis_transfer"

usage() {
    sed -n '/^# USAGE:/,/^[^#]/p' "$0" | grep '^#' | sed 's/^# \{0,1\}//'
    exit 0
}

die() { echo -e "${RED}ERROR: $*${NC}" >&2; exit 1; }

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -b|--basevars-file) bv_file="$2";    shift ;;
        -m|--media-path)    media_path="$2"; shift ;;
        -h|--help)          usage ;;
        *)
            echo -e "${RED}ERROR: Unknown option: $1${NC}" >&2
            echo "Run '$(basename "$0") --help' for usage." >&2
            exit 1 ;;
    esac
    shift
done

[[ -z "$bv_file" ]] && die "--basevars-file is required"
[[ -f "${RHIS_ROOT}/${bv_file}" ]] || die "Basevars file not found: ${RHIS_ROOT}/${bv_file}"

DOMAIN=$(grep "^basevars_global_domain_name:" "${RHIS_ROOT}/${bv_file}" \
    | awk '{print $2}' | tr -d '"'"'")
[[ -z "$DOMAIN" ]] && die "Could not parse basevars_global_domain_name from ${bv_file}"

SAT_HOST="satellite1.${DOMAIN}"

VALIDATE_SCRIPT="${RHIS_ROOT}/../rhis-provisioner-container/rhis-provisioner/validate_import_bundle.sh"
if [[ ! -f "${VALIDATE_SCRIPT}" ]]; then
    die "validate_import_bundle.sh not found: ${VALIDATE_SCRIPT}
Ensure rhis-provisioner-container is checked out alongside rhis-builder-inventory."
fi

echo -e "${GREEN}Validating transfer drive${NC}"
echo "  Satellite:   ${SAT_HOST}"
echo "  Drive mount: ${media_path}"
echo ""

ssh -o StrictHostKeyChecking=no \
    -i "${HOME}/.ssh/id_ed25519" \
    "ansiblerunner@${SAT_HOST}" \
    "sudo bash -s -- -d ${media_path}" \
    < "${VALIDATE_SCRIPT}"

EXIT_CODE=$?

echo ""
if [[ $EXIT_CODE -ne 0 ]]; then
    echo -e "${RED}Drive validation FAILED — resolve issues before transporting.${NC}"
else
    echo -e "${GREEN}Drive validation passed.${NC}"
fi

exit $EXIT_CODE
