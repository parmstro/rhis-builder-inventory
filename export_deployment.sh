#!/bin/bash
# export_deployment.sh
# Single-command lowside export workflow.
#
# Validates the lowside→highside mapping, saves the provisioner container image,
# runs the export playbook (Stage 1 — assemble bundle on satellite), then copies
# the bundle to transfer media (Stage 2 — rsync to drive).
#
# The operator mounts the transfer drive on the satellite BEFORE running this script.
# The drive must be labelled TRANSFER_DRV or a custom media path must be provided.
#
# USAGE:
#   ./export_deployment.sh [options]
#
# OPTIONS:
#   -b | --basevars-file <file>   Lowside basevars file (e.g. example.ca_inventory_basevars.yml)
#                                 REQUIRED
#       --highside <domain>       Target highside domain; required if basevars lists >1 highside
#       --media-path <path>       Transfer drive mount point on the satellite
#                                 (default: /mnt/rhis_transfer)
#       --export-root <path>      Bundle staging root on the satellite
#                                 (default: /home/ansiblerunner/rhis_export)
#       --ansible-ver <version>   Provisioner container version (default: 2.5)
#       --dry-run                 Validate and print plan — do not export
#       --yes                     Skip confirmation prompt
#   -h | --help                   Show this help

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

RHIS_ROOT="$(cd "$(dirname "$0")" && pwd)"
bv_file=""
highside_arg=""
media_path="/mnt/rhis_transfer"
export_root="/home/ansiblerunner/rhis_export"
ansible_ver="2.5"
dry_run=false
skip_confirm=false

usage() {
    sed -n '/^# USAGE:/,/^[^#]/p' "$0" | grep '^#' | sed 's/^# \{0,1\}//'
    exit 0
}

die() { echo -e "${RED}ERROR: $*${NC}" >&2; exit 1; }
warn() { echo -e "${YELLOW}WARNING: $*${NC}" >&2; }

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -b|--basevars-file)  bv_file="$2"; shift ;;
        --highside)          highside_arg="$2"; shift ;;
        --media-path)        media_path="$2"; shift ;;
        --export-root)       export_root="$2"; shift ;;
        --ansible-ver)       ansible_ver="$2"; shift ;;
        --dry-run)           dry_run=true ;;
        --yes)               skip_confirm=true ;;
        -h|--help)           usage ;;
        *)
            echo -e "${RED}ERROR: Unknown option: $1${NC}" >&2
            echo "Run '$(basename "$0") --help' for usage." >&2
            exit 1 ;;
    esac
    shift
done

# ── Validate required args ─────────────────────────────────────────────────────

[[ -z "$bv_file" ]] && die "--basevars-file is required"
[[ -f "${RHIS_ROOT}/${bv_file}" ]] || die "basevars file not found: ${RHIS_ROOT}/${bv_file}"

# ── Extract lowside domain ─────────────────────────────────────────────────────

LOWSIDE_DOMAIN=$(grep "^basevars_global_domain_name:" "${RHIS_ROOT}/${bv_file}" \
    | awk '{print $2}' | tr -d '"'"'" )
[[ -z "$LOWSIDE_DOMAIN" ]] && die "Could not parse basevars_global_domain_name from ${bv_file}"

LOWSIDE_DIR="${RHIS_ROOT}/deployments/${LOWSIDE_DOMAIN}"
[[ -d "$LOWSIDE_DIR" ]] || die "Lowside deployment not found: ${LOWSIDE_DIR}
Run: ./inventory_update.sh -b ${bv_file}"

# ── Parse basevars_downstream_disconnected_deployment list ─────────────────────
#
# Handles the YAML list format:
#   basevars_downstream_disconnected_deployment:
#     - "highside.example.ca"

mapfile -t downstream_list < <(
    sed -n '/^basevars_downstream_disconnected_deployment:/,/^[a-zA-Z_]/{
        /^[[:space:]]*-[[:space:]]/{
            s/^[[:space:]]*-[[:space:]]*//
            s/^["'"'"']//
            s/["'"'"']$//
            p
        }
    }' "${RHIS_ROOT}/${bv_file}"
)

[[ ${#downstream_list[@]} -eq 0 ]] && die "basevars_downstream_disconnected_deployment is empty in ${bv_file}.
At least one highside domain must be listed."

# ── Determine target highside ──────────────────────────────────────────────────

if [[ ${#downstream_list[@]} -eq 1 ]]; then
    HIGHSIDE_DOMAIN="${downstream_list[0]}"
    if [[ -n "$highside_arg" && "$highside_arg" != "$HIGHSIDE_DOMAIN" ]]; then
        die "--highside '${highside_arg}' does not match the configured highside '${HIGHSIDE_DOMAIN}'"
    fi
else
    # Multiple configured — require explicit selection
    if [[ -z "$highside_arg" ]]; then
        echo -e "${YELLOW}Multiple highside deployments are configured:${NC}"
        for d in "${downstream_list[@]}"; do echo "  - $d"; done
        die "Specify which to export to with --highside <domain>"
    fi
    # Validate the selection is in the list
    found=false
    for d in "${downstream_list[@]}"; do
        [[ "$d" == "$highside_arg" ]] && found=true && break
    done
    $found || die "--highside '${highside_arg}' is not in basevars_downstream_disconnected_deployment.
Configured highsides: ${downstream_list[*]}"
    HIGHSIDE_DOMAIN="$highside_arg"
fi

HIGHSIDE_DIR="${RHIS_ROOT}/deployments/${HIGHSIDE_DOMAIN}"
[[ -d "$HIGHSIDE_DIR" ]] || die "Highside deployment not found: ${HIGHSIDE_DIR}
Run: ./inventory_update.sh -b <highside_basevars_file>"

# ── Preflight checks ───────────────────────────────────────────────────────────

SAT_HOST="satellite1.${LOWSIDE_DOMAIN}"
CONTAINER_IMAGE="quay.io/parmstro/rhis-provisioner-9-${ansible_ver}:latest"
IMAGE_TAR="/tmp/rhis_provisioner_${LOWSIDE_DOMAIN//./_}_$(date +%Y%m%d_%H%M%S).tar"

# 1. Manifest ZIP: must be staged in highside deployment files/manifests/ before export
MANIFEST_ZIP=$(find "${HIGHSIDE_DIR}/files/manifests/" -name "*.zip" 2>/dev/null | head -1)
if [[ -z "$MANIFEST_ZIP" ]]; then
    warn "No manifest ZIP found in ${HIGHSIDE_DIR}/files/manifests/"
    warn "The highside Satellite requires its own manifest allocation from the Red Hat Customer Portal."
    warn "  1. Create a separate allocation at https://access.redhat.com/management"
    warn "  2. Download the manifest ZIP"
    warn "  3. Copy it to: ${HIGHSIDE_DIR}/files/manifests/"
    if ! $skip_confirm && ! $dry_run; then
        echo ""
        read -rp "Continue without manifest ZIP? Satellite build will fail on the highside [y/N]: " ans
        [[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
    fi
else
    MANIFEST_BASENAME=$(basename "$MANIFEST_ZIP")
fi

# 2. Highside manifests.yml: verify generate: false (catches misconfiguration early)
MANIFESTS_YML=$(find "${HIGHSIDE_DIR}/host_vars" -name "manifests.yml" \
    -exec grep -l "generate: false" {} \; 2>/dev/null | head -1)
if [[ -z "$MANIFESTS_YML" ]]; then
    warn "No manifests.yml with 'generate: false' found in ${HIGHSIDE_DIR}/host_vars/"
    warn "The highside Satellite cannot reach subscription.rhsm.redhat.com."
    warn "Set 'generate: false' in the satellite host_vars/manifests.yml for the highside deployment."
fi

# 3. Container image exists locally
if ! podman image exists "${CONTAINER_IMAGE}"; then
    die "Container image not found locally: ${CONTAINER_IMAGE}
Pull it first: podman pull ${CONTAINER_IMAGE}"
fi

# ── Summary and confirmation ───────────────────────────────────────────────────

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  RHIS Disconnected Satellite Export${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Lowside:     ${YELLOW}${LOWSIDE_DOMAIN}${NC}  (satellite1.${LOWSIDE_DOMAIN})"
echo -e "  Highside:    ${YELLOW}${HIGHSIDE_DOMAIN}${NC}"
echo -e "  Drive mount: ${YELLOW}${media_path}${NC}  (on ${SAT_HOST})"
echo -e "  Export root: ${YELLOW}${export_root}${NC}  (on ${SAT_HOST})"
if [[ -n "$MANIFEST_BASENAME" ]]; then
    echo -e "  Manifest:    ${YELLOW}${MANIFEST_BASENAME}${NC}"
else
    echo -e "  Manifest:    ${RED}NOT FOUND — highside build will fail${NC}"
fi
echo -e "  Container:   ${YELLOW}${CONTAINER_IMAGE}${NC}"
echo ""

if $dry_run; then
    echo -e "${YELLOW}  --dry-run: no export will be performed${NC}"
    echo ""
    exit 0
fi

if ! $skip_confirm; then
    echo -e "  ${YELLOW}Ensure the transfer drive is mounted at ${media_path} on ${SAT_HOST}${NC}"
    echo -e "  ${YELLOW}before proceeding. The export playbook will validate the drive.${NC}"
    echo ""
    read -rp "  Proceed with export? [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
fi

echo ""
printf "${GREEN}Start Time: %(%T)T${NC}\n" -1
SECONDS=0

# ── Stage 0: Save container image ─────────────────────────────────────────────

echo ""
echo -e "${GREEN}Saving provisioner container image...${NC}"
echo -e "  Image:  ${CONTAINER_IMAGE}"
echo -e "  Output: ${IMAGE_TAR}"

if ! podman save "${CONTAINER_IMAGE}" -o "${IMAGE_TAR}"; then
    die "podman save failed for ${CONTAINER_IMAGE}"
fi
echo -e "${GREEN}Container image saved.${NC}"

# ── Stage 1: Export playbook (assemble bundle on satellite) ────────────────────

echo ""
echo -e "${GREEN}Stage 1 — Assembling export bundle on ${SAT_HOST}...${NC}"

podman run --rm \
  --entrypoint /bin/bash \
  -v "${LOWSIDE_DIR}/inventory:/rhis/vars/external_inventory:Z" \
  -v "${LOWSIDE_DIR}/group_vars:/rhis/vars/group_vars:Z" \
  -v "${LOWSIDE_DIR}/host_vars:/rhis/vars/host_vars:Z" \
  -v "${LOWSIDE_DIR}/logs:/rhis/vars/logs:Z" \
  -v "${LOWSIDE_DIR}/vars:/rhis/vars/vars:Z" \
  -v "${LOWSIDE_DIR}/vault:/rhis/vars/vault:Z" \
  -v "${HIGHSIDE_DIR}/files:/rhis/vars/highside_files:Z" \
  -v "${IMAGE_TAR}:/tmp/rhis_provisioner_image.tar:Z" \
  -v "${RHIS_ROOT}/../rhis-builder-satellite:/rhis/rhis-builder-satellite:Z" \
  -v "${HOME}/.ssh:/root/.ssh:Z" \
  --hostname provisioner \
  "${CONTAINER_IMAGE}" \
  -c "cd /rhis/rhis-builder-satellite && \
      ansible-playbook \
        --inventory /rhis/vars/external_inventory/inventory \
        --user ansiblerunner \
        --private-key /root/.ssh/id_ed25519 \
        --vault-password-file /root/.ssh/vault.txt \
        --extra-vars 'vault_dir=/rhis/vars/vault vars_dir=/rhis/vars/host_vars' \
        --extra-vars 'rhis_export_root=${export_root}' \
        --extra-vars 'active_downstream_deployment=${HIGHSIDE_DOMAIN}' \
        --extra-vars '_manifests_src=/rhis/vars/highside_files/manifests' \
        --extra-vars 'provisioner_image_tar=/tmp/rhis_provisioner_image.tar' \
        --limit=sat_primary \
        export_disconnected.yml 2>&1 | tee /rhis/vars/logs/export_deployment_stage1.log"

STAGE1_EXIT=${PIPESTATUS[0]}

if [[ $STAGE1_EXIT -ne 0 ]]; then
    echo -e "${RED}Stage 1 failed (exit ${STAGE1_EXIT}).${NC}"
    echo "  Log: ${LOWSIDE_DIR}/logs/export_deployment_stage1.log"
    rm -f "${IMAGE_TAR}"
    exit $STAGE1_EXIT
fi

echo -e "${GREEN}Stage 1 complete.${NC}"

# ── Discover bundle directory for Stage 2 ─────────────────────────────────────

echo ""
echo -e "${GREEN}Discovering bundle directory on ${SAT_HOST}...${NC}"

BUNDLE_DIR=$(ssh -o BatchMode=yes -o StrictHostKeyChecking=no \
    "ansiblerunner@${SAT_HOST}" \
    "ls -td '${export_root}'/*/  2>/dev/null | head -1" 2>/dev/null | tr -d '\n')

if [[ -z "$BUNDLE_DIR" ]]; then
    echo -e "${RED}Could not locate bundle directory under ${export_root} on ${SAT_HOST}${NC}" >&2
    echo "Stage 1 may have failed. Check: ${LOWSIDE_DIR}/logs/export_deployment_stage1.log"
    rm -f "${IMAGE_TAR}"
    exit 1
fi

echo -e "  Bundle: ${YELLOW}${BUNDLE_DIR}${NC}"

# ── Stage 2: Copy bundle to transfer media ─────────────────────────────────────

echo ""
echo -e "${GREEN}Stage 2 — Copying bundle to transfer media at ${media_path}...${NC}"

podman run --rm \
  --entrypoint /bin/bash \
  -v "${LOWSIDE_DIR}/inventory:/rhis/vars/external_inventory:Z" \
  -v "${LOWSIDE_DIR}/group_vars:/rhis/vars/group_vars:Z" \
  -v "${LOWSIDE_DIR}/host_vars:/rhis/vars/host_vars:Z" \
  -v "${LOWSIDE_DIR}/logs:/rhis/vars/logs:Z" \
  -v "${LOWSIDE_DIR}/vars:/rhis/vars/vars:Z" \
  -v "${LOWSIDE_DIR}/vault:/rhis/vars/vault:Z" \
  -v "${RHIS_ROOT}:/rhis/rhis-builder-inventory:Z" \
  -v "${RHIS_ROOT}/../rhis-builder-satellite:/rhis/rhis-builder-satellite:Z" \
  -v "${HOME}/.ssh:/root/.ssh:Z" \
  --hostname provisioner \
  "${CONTAINER_IMAGE}" \
  -c "cd /rhis/rhis-builder-satellite && \
      ansible-playbook \
        --inventory /rhis/vars/external_inventory/inventory \
        --user ansiblerunner \
        --private-key /root/.ssh/id_ed25519 \
        --vault-password-file /root/.ssh/vault.txt \
        --extra-vars 'vault_dir=/rhis/vars/vault vars_dir=/rhis/vars/host_vars' \
        --extra-vars 'bundle_dir=${BUNDLE_DIR} media_path=${media_path}' \
        --limit=sat_primary \
        copy_to_transfer_media.yml 2>&1 | tee /rhis/vars/logs/export_deployment_stage2.log"

STAGE2_EXIT=${PIPESTATUS[0]}

if [[ $STAGE2_EXIT -ne 0 ]]; then
    echo -e "${RED}Stage 2 failed (exit ${STAGE2_EXIT}).${NC}"
    echo "  Log: ${LOWSIDE_DIR}/logs/export_deployment_stage2.log"
    rm -f "${IMAGE_TAR}"
    exit $STAGE2_EXIT
fi

# ── Stage 3: Validate transfer drive ──────────────────────────────────────────
# Pipes validate_import_bundle.sh from inside the container to the satellite
# via SSH so the drive is validated in place — no file copying needed.

echo ""
echo -e "${GREEN}Stage 3 — Validating transfer drive at ${media_path} on ${SAT_HOST}...${NC}"

VALIDATE_SCRIPT="${RHIS_ROOT}/../rhis-provisioner-container/rhis-provisioner/validate_import_bundle.sh"

ssh -o StrictHostKeyChecking=no \
    -i "${HOME}/.ssh/id_ed25519" \
    "ansiblerunner@${SAT_HOST}" \
    "sudo bash -s -- -d ${media_path}" \
    < "${VALIDATE_SCRIPT}" \
  2>&1 | tee "${LOWSIDE_DIR}/logs/export_deployment_stage3.log"

STAGE3_EXIT=${PIPESTATUS[0]}

if [[ $STAGE3_EXIT -ne 0 ]]; then
    echo -e "${RED}Stage 3 — Drive validation failed (exit ${STAGE3_EXIT}).${NC}"
    echo "  Log: ${LOWSIDE_DIR}/logs/export_deployment_stage3.log"
    echo -e "${RED}  Resolve failures before transporting the drive.${NC}"
    rm -f "${IMAGE_TAR}"
    exit $STAGE3_EXIT
fi

echo -e "${GREEN}Stage 3 complete — drive validated.${NC}"

# ── Cleanup and summary ────────────────────────────────────────────────────────

rm -f "${IMAGE_TAR}"

duration=$SECONDS
printf "\n${GREEN}End Time: %(%T)T${NC}\n" -1
TZ=UTC0 printf "${GREEN}Elapsed Time: %(%T)T${NC}\n" $duration

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  RHIS Export Complete${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Lowside → Highside:  ${YELLOW}${LOWSIDE_DOMAIN} → ${HIGHSIDE_DOMAIN}${NC}"
echo -e "  Bundle assembled at: ${YELLOW}${BUNDLE_DIR}${NC}"
echo -e "  Transfer media:      ${YELLOW}${media_path}${NC}  (on ${SAT_HOST})"
echo ""
echo -e "  Stage 1 log: ${LOWSIDE_DIR}/logs/export_deployment_stage1.log"
echo -e "  Stage 2 log: ${LOWSIDE_DIR}/logs/export_deployment_stage2.log"
echo -e "  Stage 3 log: ${LOWSIDE_DIR}/logs/export_deployment_stage3.log"
echo ""
echo -e "${YELLOW}  IMPORTANT: Vault password must travel via a separate trusted channel.${NC}"
echo -e "${YELLOW}  Do NOT include the vault password in or alongside the transfer bundle.${NC}"
echo ""
echo -e "${GREEN}  Next steps on the highside:${NC}"
echo -e "  1. Physically transport the drive to the highside environment"
echo -e "  2. Mount the drive on an operator RHEL workstation"
echo -e "  3. cd <drive_mount> && ./import_bundle.sh"
echo -e "     (follow the survey — it handles data delivery to provisioner and satellite)"
echo -e "  4. SSH to provisioner and run the satellite build:"
echo -e "     build_sat_disconnected_import.sh --delivery-method <method> --deployment ${HIGHSIDE_DOMAIN}"
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""
