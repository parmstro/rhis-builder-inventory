#!/bin/bash
# export_deployment.sh
# Thin bash wrapper for the disconnected satellite export workflow.
#
# Parses arguments, handles interactive highside selection when multiple downstreams
# are configured, then delegates all work to export_deployment.yml (Ansible).
#
# USAGE:
#   ./export_deployment.sh [options]
#
# OPTIONS:
#   -b | --basevars-file <file>   Lowside basevars file (e.g. example.ca_inventory_basevars.yml)
#                                 REQUIRED
#       --highside <domain>       Target highside domain; required if basevars lists >1 highside
#       --ansible-ver <version>   Provisioner container version (default: 2.5)
#       --export-root <path>      Staging root directory (default: /var/rhis_export_staging)
#       --dry-run                 Validate and print plan — do not export
#  -y | --yes                     Skip confirmation prompt
#   -h | --help                   Show this help

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

RHIS_ROOT="$(cd "$(dirname "$0")" && pwd)"
bv_file=""
highside_arg=""
ansible_ver="2.5"
export_root="/var/rhis_export_staging"
dry_run=false
skip_confirm=false

usage() {
    sed -n '/^# USAGE:/,/^[^#]/p' "$0" | grep '^#' | sed 's/^# \{0,1\}//'
    exit 0
}

die()  { echo -e "${RED}ERROR: $*${NC}" >&2; exit 1; }
warn() { echo -e "${YELLOW}WARNING: $*${NC}" >&2; }

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -b|--basevars-file)  bv_file="$2"; shift ;;
        --highside)          highside_arg="$2"; shift ;;
        --ansible-ver)       ansible_ver="$2"; shift ;;
        --export-root)       export_root="$2"; shift ;;
        --dry-run)           dry_run=true ;;
        -y|--yes)            skip_confirm=true ;;
        -h|--help)           usage ;;
        *)
            echo -e "${RED}ERROR: Unknown option: $1${NC}" >&2
            echo "Run '$(basename "$0") --help' for usage." >&2
            exit 1 ;;
    esac
    shift
done

[[ -z "$bv_file" ]] && die "--basevars-file is required"
[[ -f "${RHIS_ROOT}/${bv_file}" ]] || die "basevars file not found: ${RHIS_ROOT}/${bv_file}"

# ── Parse downstream list (for interactive selection only) ─────────────────────
# Ansible handles all other YAML — this is the one field the wrapper must read
# to resolve interactive highside selection before invoking ansible-playbook.

mapfile -t downstream_list < <(
    sed -n '/^basevars_downstream_disconnected_deployment:/,/^[a-zA-Z_]/{
        /^[[:space:]]*-[[:space:]]/{
            s/^[[:space:]]*-[[:space:]]*//
            s/^["'"'"']//
            s/[[:space:]]*#.*$//
            s/["'"'"']$//
            p
        }
    }' "${RHIS_ROOT}/${bv_file}"
)

[[ ${#downstream_list[@]} -eq 0 ]] && \
    die "basevars_downstream_disconnected_deployment is empty in ${bv_file}"

# ── Resolve highside domain ────────────────────────────────────────────────────

if [[ ${#downstream_list[@]} -eq 1 ]]; then
    HIGHSIDE_DOMAIN="${downstream_list[0]}"
    if [[ -n "$highside_arg" && "$highside_arg" != "$HIGHSIDE_DOMAIN" ]]; then
        die "--highside '${highside_arg}' does not match configured highside '${HIGHSIDE_DOMAIN}'"
    fi
elif [[ -n "$highside_arg" ]]; then
    found=false
    for d in "${downstream_list[@]}"; do
        [[ "$d" == "$highside_arg" ]] && found=true && break
    done
    $found || die "--highside '${highside_arg}' is not in basevars_downstream_disconnected_deployment.
Configured: ${downstream_list[*]}"
    HIGHSIDE_DOMAIN="$highside_arg"
else
    echo -e "${YELLOW}Multiple highside deployments are configured:${NC}"
    for i in "${!downstream_list[@]}"; do
        echo "  $((i+1)). ${downstream_list[$i]}"
    done
    read -rp "  Select highside [1-${#downstream_list[@]}]: " selection
    [[ "$selection" =~ ^[0-9]+$ && "$selection" -ge 1 && "$selection" -le "${#downstream_list[@]}" ]] \
        || die "Invalid selection: ${selection}"
    HIGHSIDE_DOMAIN="${downstream_list[$((selection-1))]}"
fi

# ── Log setup ─────────────────────────────────────────────────────────────────

LOWSIDE_DOMAIN=$(grep "^basevars_global_domain_name:" "${RHIS_ROOT}/${bv_file}" \
    | awk '{print $2}' | tr -d '"'"'" )
[[ -z "$LOWSIDE_DOMAIN" ]] && die "Could not parse basevars_global_domain_name from ${bv_file}"

LOG_DIR="${RHIS_ROOT}/deployments/${LOWSIDE_DOMAIN}/logs"
mkdir -p "${LOG_DIR}"
LOG_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/export_deployment_${LOG_TIMESTAMP}.log"

echo -e "  Log: ${YELLOW}${LOG_FILE}${NC}"

# ── Confirmation prompt ────────────────────────────────────────────────────────
# Prompt here (not in Ansible) — ansible.builtin.pause prompt text is lost when
# stdout is piped through tee; read -rp on a real terminal works reliably.
# Dry-run bypasses the prompt so the plan summary is always shown.

if ! $dry_run && ! $skip_confirm; then
    echo ""
    echo -e "${YELLOW}  Export: ${LOWSIDE_DOMAIN} → ${HIGHSIDE_DOMAIN}${NC}"
    read -rp "  Proceed? [y/N]: " _ans
    [[ "$_ans" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
    echo ""
fi

printf "${GREEN}Start Time: %(%T)T${NC}\n" -1
SECONDS=0

# ── Run export playbook ────────────────────────────────────────────────────────

ansible-playbook \
    "${RHIS_ROOT}/export_deployment.yml" \
    --extra-vars "basevars_file=${RHIS_ROOT}/${bv_file}" \
    --extra-vars "highside=${HIGHSIDE_DOMAIN}" \
    --extra-vars "ansible_ver=${ansible_ver}" \
    --extra-vars "export_root=${export_root}" \
    --extra-vars "dry_run=${dry_run}" \
    2>&1 | tee "${LOG_FILE}"

EXIT_CODE=${PIPESTATUS[0]}

duration=$SECONDS
printf "\n${GREEN}End Time: %(%T)T${NC}\n" -1
TZ=UTC0 printf "${GREEN}Elapsed Time: %(%T)T${NC}\n" $duration

exit $EXIT_CODE
