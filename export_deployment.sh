#!/bin/bash
# export_deployment.sh
# Single-command lowside export workflow.
#
# Validates the lowside→highside mapping, saves the provisioner container image
# (and Tang container if pulled locally), runs the export playbook (Stage 1 —
# Pulp export + satellite artifact pull), stages provisioner-side artifacts
# (Stage 1.5 — bash), and generates the operator transfer script
# (Stage 2 — transfer_to_drive.sh).
#
# The operator copies transfer_to_drive.sh to their RHEL workstation, plugs in
# the transfer drive, and runs it.  The script rsyncs staging from the provisioner
# and Pulp chunks from the satellite directly to the drive.
#
# USAGE:
#   ./export_deployment.sh [options]
#
# OPTIONS:
#   -b | --basevars-file <file>   Lowside basevars file (e.g. example.ca_inventory_basevars.yml)
#                                 REQUIRED
#       --highside <domain>       Target highside domain; required if basevars lists >1 highside
#       --ansible-ver <version>   Provisioner container version (default: 2.5)
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
dry_run=false
skip_confirm=false

usage() {
    sed -n '/^# USAGE:/,/^[^#]/p' "$0" | grep '^#' | sed 's/^# \{0,1\}//'
    exit 0
}

die() { echo -e "${RED}ERROR: $*${NC}" >&2; exit 1; }
warn() { echo -e "${YELLOW}WARNING: $*${NC}" >&2; }
_hr_bytes() {
    awk -v b="${1:-0}" 'BEGIN {
        if (b >= 1073741824) printf "%.1f GiB", b/1073741824;
        else if (b >= 1048576) printf "%.1f MiB", b/1048576;
        else if (b >= 1024) printf "%.1f KiB", b/1024;
        else printf "%d B", b;
    }'
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -b|--basevars-file)  bv_file="$2"; shift ;;
        --highside)          highside_arg="$2"; shift ;;
        --ansible-ver)       ansible_ver="$2"; shift ;;
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
            s/[[:space:]]*#.*$//
            s/["'"'"']$//
            p
        }
    }' "${RHIS_ROOT}/${bv_file}"
)

# ── Extract infra ISO basevars (C9) ───────────────────────────────────────────

RHEL_DVD_CSET=$(grep "^basevars_rhel_dvd_cset:" "${RHIS_ROOT}/${bv_file}" \
    | awk '{print $2}' | tr -d '"'"'")
RHEL_DVD_VERSION=$(grep "^basevars_rhel_dvd_version:" "${RHIS_ROOT}/${bv_file}" \
    | awk '{print $2}' | tr -d '"'"'")
RHEL_DVD_ISO_PATH=$(grep "^basevars_rhel_dvd_iso_path:" "${RHIS_ROOT}/${bv_file}" \
    | awk '{print $2}' | tr -d '"'"'")
SAT_DVD_CSET=$(grep "^basevars_satellite_dvd_cset:" "${RHIS_ROOT}/${bv_file}" \
    | awk '{print $2}' | tr -d '"'"'")
SAT_DVD_VERSION=$(grep "^basevars_satellite_dvd_version:" "${RHIS_ROOT}/${bv_file}" \
    | awk '{print $2}' | tr -d '"'"'")
SAT_DVD_ISO_PATH=$(grep "^basevars_satellite_dvd_iso_path:" "${RHIS_ROOT}/${bv_file}" \
    | awk '{print $2}' | tr -d '"'"'")

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

# ── Parse rhis_highside_containers from highside basevars ─────────────────────
HIGHSIDE_BV="${RHIS_ROOT}/${HIGHSIDE_DOMAIN}_inventory_basevars.yml"
mapfile -t rhis_containers < <(
    [[ -f "${HIGHSIDE_BV}" ]] && \
    sed -n '/^rhis_highside_containers:/,/^[a-zA-Z_]/{
        /^[[:space:]]*-[[:space:]]/{
            s/^[[:space:]]*-[[:space:]]*//
            s/^["'"'"']//
            s/[[:space:]]*#.*$//
            s/["'"'"'][[:space:]]*$//
            /./p
        }
    }' "${HIGHSIDE_BV}"
)

# ── Resume detection ──────────────────────────────────────────────────────────
# If a Pulp export completion marker exists from a prior run, automatically skip
# the Pulp export and proceed directly to staging.  Delete the marker file to
# force a fresh Pulp export on the next run.

MARKER_FILE="${LOWSIDE_DIR}/logs/.pulp_export_complete"
SKIP_EXPORT_TAGS=""

if [[ -f "$MARKER_FILE" ]]; then
    SKIP_EXPORT_TAGS="--skip-tags tags_content_exports"
fi

# ── Preflight checks ───────────────────────────────────────────────────────────

SAT_HOST="satellite1.${LOWSIDE_DOMAIN}"
CONTAINER_IMAGE="quay.io/parmstro/rhis-provisioner-9-${ansible_ver}:latest"
IMAGE_TAR="/tmp/rhis_provisioner_${LOWSIDE_DOMAIN//./_}_$(date +%Y%m%d_%H%M%S).tar"

# 1. Manifest ZIP: must be staged in highside deployment files/ before export
MANIFEST_ZIP=$(find "${HIGHSIDE_DIR}/files/" -name "*.zip" 2>/dev/null | head -1)
if [[ -z "$MANIFEST_ZIP" ]]; then
    warn "No manifest ZIP found in ${HIGHSIDE_DIR}/files/"
    warn "The highside Satellite requires its own manifest allocation from the Red Hat Customer Portal."
    warn "  1. Create a separate allocation at https://access.redhat.com/management"
    warn "  2. Download the manifest ZIP"
    warn "  3. Copy it to: ${HIGHSIDE_DIR}/files/"
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
    warn "Set 'generate: false' for all redhat_manifest configurations in the satellite host_vars/manifests.yml for the highside deployment."
fi

# 3. Container image exists locally
if ! podman image exists "${CONTAINER_IMAGE}"; then
    die "Container image not found locally: ${CONTAINER_IMAGE}
Pull it first: podman pull ${CONTAINER_IMAGE}"
fi

# 4. Infra ISOs (C9): verify or download via rh_iso_download.sh
_ISO_SCRIPT="${RHIS_ROOT}/rh_iso_download.sh"
_iso_warnings=0

_check_or_download_iso() {
    local label="$1" cset="$2" ver="$3" dest="$4"
    if [[ -z "$cset" || -z "$dest" ]]; then
        warn "${label} ISO not configured — infra_isos/ on the drive will not contain this file"
        return 1
    fi
    if [[ -f "$dest" ]]; then
        local size; size=$(du -sh "$dest" 2>/dev/null | cut -f1)
        echo -e "  ${label} ISO: ${GREEN}present${NC} (${size})  ${dest}"
        return 0
    fi
    echo -e "  ${label} ISO: not found at ${dest}"
    if [[ ! -f "${_ISO_SCRIPT}" ]]; then
        warn "${label} ISO missing and rh_iso_download.sh not found at ${_ISO_SCRIPT}"
        return 1
    fi
    echo -e "  Downloading ${label} ISO via RHSM API (this may take 20-30 minutes)..."
    local ver_arg=""
    [[ -n "$ver" && "$ver" != "latest" ]] && ver_arg="--version ${ver}"
    if bash "${_ISO_SCRIPT}" --cset "${cset}" ${ver_arg} --output "${dest}"; then
        local size; size=$(du -sh "$dest" 2>/dev/null | cut -f1)
        echo -e "  ${label} ISO: ${GREEN}downloaded${NC} (${size})  ${dest}"
        return 0
    fi
    warn "${label} ISO download failed — infra_isos/ on the drive will not contain this file"
    return 1
}

_check_or_download_iso "RHEL DVD" "${RHEL_DVD_CSET}" "${RHEL_DVD_VERSION}" "${RHEL_DVD_ISO_PATH}" \
    || _iso_warnings=$(( _iso_warnings + 1 ))
_check_or_download_iso "Satellite DVD" "${SAT_DVD_CSET}" "${SAT_DVD_VERSION}" "${SAT_DVD_ISO_PATH}" \
    || _iso_warnings=$(( _iso_warnings + 1 ))

if [[ $_iso_warnings -gt 0 ]]; then
    warn "The highside satellite installation requires RHEL and Satellite DVD ISOs."
    warn "Without them, the highside Satellite build will fail at the OS installation step."
    if ! $skip_confirm && ! $dry_run; then
        read -rp "Continue without ISO(s)? The highside build will fail [y/N]: " ans
        [[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
    fi
fi

# ── Summary and confirmation ───────────────────────────────────────────────────

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  RHIS Disconnected Satellite Export${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Lowside:   ${YELLOW}${LOWSIDE_DOMAIN}${NC}  (satellite1.${LOWSIDE_DOMAIN})"
echo -e "  Highside:  ${YELLOW}${HIGHSIDE_DOMAIN}${NC}"
echo -e "  Container: ${YELLOW}${CONTAINER_IMAGE}${NC}"
if [[ -n "$MANIFEST_BASENAME" ]]; then
    echo -e "  Manifest:  ${YELLOW}${MANIFEST_BASENAME}${NC}"
else
    echo -e "  Manifest:  ${RED}NOT FOUND — highside build will fail${NC}"
fi
if [[ -n "$SKIP_EXPORT_TAGS" ]]; then
    echo -e "  Resume:    ${YELLOW}Pulp export marker found — Pulp export will be skipped${NC}"
    echo -e "             ${YELLOW}(delete ${MARKER_FILE} to force a fresh export)${NC}"
else
    echo -e "  Resume:    ${GREEN}No marker — full export will run${NC}"
fi
if [[ -n "$RHEL_DVD_ISO_PATH" ]]; then
    _rhel_label="$([[ -f "$RHEL_DVD_ISO_PATH" ]] && echo "${GREEN}present${NC}" || echo "${RED}missing${NC}")"
    echo -e "  RHEL ISO:  ${_rhel_label}  ${RHEL_DVD_ISO_PATH}"
else
    echo -e "  RHEL ISO:  ${YELLOW}not configured${NC}"
fi
if [[ -n "$SAT_DVD_ISO_PATH" ]]; then
    _sat_label="$([[ -f "$SAT_DVD_ISO_PATH" ]] && echo "${GREEN}present${NC}" || echo "${RED}missing${NC}")"
    echo -e "  Sat ISO:   ${_sat_label}  ${SAT_DVD_ISO_PATH}"
else
    echo -e "  Sat ISO:   ${YELLOW}not configured${NC}"
fi
if [[ ${#rhis_containers[@]} -gt 0 ]]; then
    echo -e "  Containers to bundle:"
    for _c in "${rhis_containers[@]}"; do
        _clabel="$(podman image exists "${_c}" 2>/dev/null \
            && echo "${GREEN}present${NC}" || echo "${RED}not pulled${NC}")"
        echo -e "    ${_clabel}  ${_c}"
    done
else
    echo -e "  Containers: ${YELLOW}none defined in rhis_highside_containers${NC}"
fi
echo ""

if $dry_run; then
    echo -e "${YELLOW}  --dry-run: no export will be performed${NC}"
    echo ""
    exit 0
fi

if ! $skip_confirm; then
    read -rp "  Proceed with export? [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
fi

echo ""
printf "${GREEN}Start Time: %(%T)T${NC}\n" -1
SECONDS=0
LOG_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FULL="${LOWSIDE_DIR}/logs/export_deployment_${LOG_TIMESTAMP}.log"
LOG_STAGE1="${LOWSIDE_DIR}/logs/export_deployment_stage1_${LOG_TIMESTAMP}.log"
LOG_STAGE15="${LOWSIDE_DIR}/logs/export_deployment_stage15_${LOG_TIMESTAMP}.log"
LOG_STAGE2="${LOWSIDE_DIR}/logs/export_deployment_stage2_${LOG_TIMESTAMP}.log"

exec > >(tee "${LOG_FULL}") 2>&1
echo -e "  Log: ${YELLOW}${LOG_FULL}${NC}"

EXPORT_STAGING="/home/ansiblerunner/rhis_export_staging/${HIGHSIDE_DOMAIN}_${LOG_TIMESTAMP}"
PROVISIONER_HOST=$(hostname -f)

# ── Create staging directory tree ─────────────────────────────────────────────

mkdir -p \
  "${EXPORT_STAGING}/provisioner/containers" \
  "${EXPORT_STAGING}/provisioner/inventory" \
  "${EXPORT_STAGING}/bootstrap/bootstrap_isos" \
  "${EXPORT_STAGING}/bootstrap/infra_isos" \
  "${EXPORT_STAGING}/bootstrap/rhis-builder-bootstrap-init" \
  "${EXPORT_STAGING}/satellite/ansible_roles" \
  "${EXPORT_STAGING}/satellite/discovery_images"

# ── Stage 0: Save container image ─────────────────────────────────────────────

echo ""
echo -e "${GREEN}Saving provisioner container image...${NC}"
echo -e "  Image:  ${CONTAINER_IMAGE}"
echo -e "  Output: ${IMAGE_TAR}"

if ! podman save "${CONTAINER_IMAGE}" -o "${IMAGE_TAR}"; then
    die "podman save failed for ${CONTAINER_IMAGE}"
fi
echo -e "${GREEN}Container image saved.${NC}"

# ── Stage 1: Pulp export and satellite artifact collection ─────────────────────
# export_disconnected.yml runs the Pulp library export (Step 1) and pulls
# ansible_roles and discovery_images from the satellite to the staging directory.

echo ""
echo -e "${GREEN}Stage 1 — Pulp export and satellite artifact collection on ${SAT_HOST}...${NC}"

podman run --rm \
  --entrypoint /bin/bash \
  -v "${LOWSIDE_DIR}/inventory:/rhis/vars/external_inventory:Z" \
  -v "${LOWSIDE_DIR}/group_vars:/rhis/vars/group_vars:Z" \
  -v "${LOWSIDE_DIR}/host_vars:/rhis/vars/host_vars:Z" \
  -v "${LOWSIDE_DIR}/logs:/rhis/vars/logs:Z" \
  -v "${LOWSIDE_DIR}/vars:/rhis/vars/vars:Z" \
  -v "${LOWSIDE_DIR}/vault:/rhis/vars/vault:Z" \
  -v "${HIGHSIDE_DIR}/host_vars:/rhis/vars/highside_host_vars:Z" \
  -v "${EXPORT_STAGING}:/rhis/vars/export_staging:Z" \
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
        --extra-vars 'active_downstream_deployment=${HIGHSIDE_DOMAIN}' \
        --limit=sat_primary \
        ${SKIP_EXPORT_TAGS} \
        export_disconnected.yml 2>&1 | tee /rhis/vars/logs/export_deployment_${LOG_TIMESTAMP}.log"

STAGE1_EXIT=${PIPESTATUS[0]}

if [[ $STAGE1_EXIT -ne 0 ]]; then
    echo -e "${RED}Stage 1 failed (exit ${STAGE1_EXIT}).${NC}"
    echo "  Log: ${LOG_STAGE1}"
    rm -f "${IMAGE_TAR}"
    exit $STAGE1_EXIT
fi

echo -e "${GREEN}Stage 1 complete.${NC}"

# ── Stage 1.5: Provision-side artifact staging ─────────────────────────────────
# Stages all provisioner-sourced artifacts into EXPORT_STAGING.
# Satellite-sourced artifacts (ansible_roles, discovery_images) were pulled by Stage 1.

echo ""
echo -e "${GREEN}Stage 1.5 — Staging provisioner-side artifacts...${NC}" \
  | tee "${LOG_STAGE15}"

{
  # ── Container image ──────────────────────────────────────────────────────────
  echo -e "  Moving container image to staging..."
  mv "${IMAGE_TAR}" "${EXPORT_STAGING}/provisioner/containers/rhis-provisioner_${LOG_TIMESTAMP}.tar"

  # ── Additional containers (rhis_highside_containers from highside basevars) ───
  if [[ ${#rhis_containers[@]} -eq 0 ]]; then
      echo -e "  No additional containers defined in rhis_highside_containers."
  else
      for _image in "${rhis_containers[@]}"; do
          _short=$(basename "${_image%%:*}")
          _tar="${EXPORT_STAGING}/provisioner/containers/${_short}_${LOG_TIMESTAMP}.tar"
          echo -e "  Checking: ${_image}"
          if podman image exists "${_image}"; then
              echo -e "  Saving: ${_image}"
              if podman save "${_image}" -o "${_tar}"; then
                  echo -e "  Saved: $(basename "${_tar}")"
              else
                  warn "podman save failed for ${_image} — skipping"
                  rm -f "${_tar}"
              fi
          else
              warn "Image not found locally: ${_image}"
              warn "  Pull it first:  podman pull ${_image}"
          fi
      done
  fi

  # ── Inventory archive (git archive → extract → inject content_imports.yml) ───
  echo -e "  Archiving inventory to staging..."
  git -C "${RHIS_ROOT}" archive HEAD | tar -x -C "${EXPORT_STAGING}/provisioner/inventory/"

  # ── Prune non-highside files from the extracted archive ─────────────────────
  # Compartmentalization: the transfer bundle must contain configuration ONLY for
  # the target highside deployment.  This holds for arbitrary chain depths
  # (lowside → H1 → H2 → H3 ...) — the bundle produced at each tier must not
  # carry any configuration from the current or lower tiers.
  #
  # Positive-selection rule:
  #   Deployment-specific files have an FQDN prefix containing a dot in the stem
  #   (e.g. highside.example.ca.25.sh, example.ca_inventory_basevars.yml).
  #   Generic scripts have no dot in the stem (e.g. run_container.sh).
  #   Keep the target's files; remove ALL other deployment-specific files.

  echo -e "  Pruning non-highside files from inventory archive..."

  _inv_stage="${EXPORT_STAGING}/provisioner/inventory"
  echo -e "    Target: ${HIGHSIDE_DOMAIN}  (launcher: ${HIGHSIDE_DOMAIN}.${ansible_ver}.sh)"

  # Remove all deployment directories except the target highside
  for _d in "${_inv_stage}/deployments"/*/; do
      _dname=$(basename "${_d}")
      if [[ "${_dname}" != "${HIGHSIDE_DOMAIN}" ]]; then
          rm -rf "${_d}"
          echo -e "    Removed deployment dir: ${_dname}"
      fi
  done

  # Remove all deployment-specific basevars files except the target's.
  # inventory_basevars.yml (no domain prefix) is the generic template — kept.
  for _f in "${_inv_stage}"/*_inventory_basevars.yml; do
      [[ -f "${_f}" ]] || continue
      _base=$(basename "${_f}")
      [[ "${_base}" == "inventory_basevars.yml" ]] && continue
      [[ "${_base}" == "${HIGHSIDE_DOMAIN}_inventory_basevars.yml" ]] && continue
      rm -f "${_f}" && echo -e "    Removed basevars: ${_base}"
  done

  # Remove all deployment-specific launcher scripts except the target version.
  # A deployment launcher is identified by a dot in the filename stem
  # (e.g. highside.example.ca.25.sh → stem highside.example.ca.25 contains dots).
  # Generic scripts (run_container.sh, build_highside_isos.sh, etc.) have no dot
  # in the stem and are left untouched.
  for _f in "${_inv_stage}"/*.sh; do
      [[ -f "${_f}" ]] || continue
      _base=$(basename "${_f}")
      _stem="${_base%.sh}"
      [[ "${_stem}" == *.* ]] || continue   # no dot in stem → generic script, keep
      if [[ "${_base}" != "${HIGHSIDE_DOMAIN}.${ansible_ver}.sh" ]]; then
          rm -f "${_f}" && echo -e "    Removed launcher: ${_base}"
      fi
  done

  # Ensure the highside deployment logs/ directory exists and is empty.
  # Git does not track empty directories, so the archive never creates it.
  # Remove any files that may have been committed there, then recreate clean.
  _logs_dir="${_inv_stage}/deployments/${HIGHSIDE_DOMAIN}/logs"
  rm -rf "${_logs_dir}"
  mkdir -p "${_logs_dir}"
  echo -e "  Created empty logs dir: deployments/${HIGHSIDE_DOMAIN}/logs/"

  # Inject content_imports.yml written by Stage 1 (C6) into the extracted tree.
  CONTENT_IMPORTS_SRC="${HIGHSIDE_DIR}/host_vars/satellite1.${HIGHSIDE_DOMAIN}/content_imports.yml"
  CONTENT_IMPORTS_DEST="${EXPORT_STAGING}/provisioner/inventory/deployments/${HIGHSIDE_DOMAIN}/host_vars/satellite1.${HIGHSIDE_DOMAIN}"
  if [[ -f "${CONTENT_IMPORTS_SRC}" ]]; then
      mkdir -p "${CONTENT_IMPORTS_DEST}"
      cp "${CONTENT_IMPORTS_SRC}" "${CONTENT_IMPORTS_DEST}/content_imports.yml"
      echo -e "  Injected content_imports.yml into inventory staging."
  else
      warn "content_imports.yml not found at ${CONTENT_IMPORTS_SRC} — not injected into staging"
  fi

  # ── Subscription manifests (from highside deployment files/) ─────────────────
  MANIFEST_DEST="${EXPORT_STAGING}/provisioner/inventory/deployments/${HIGHSIDE_DOMAIN}/files"
  mkdir -p "${MANIFEST_DEST}"
  zip_count=0
  for zip in "${HIGHSIDE_DIR}/files/"*.zip; do
      [[ -f "$zip" ]] && cp "$zip" "${MANIFEST_DEST}/" && ((zip_count++))
  done
  if [[ $zip_count -gt 0 ]]; then
      echo -e "  Staged ${zip_count} subscription manifest(s)."
  else
      warn "No subscription manifests found in ${HIGHSIDE_DIR}/files/ — staged directory is empty"
  fi

  # Normalize permissions so any user on the highside can read inventory files.
  # Source vault dirs are 700/600; drive content must be world-readable because
  # the operator's OS user differs from the build machine's ansiblerunner UID.
  find "${_inv_stage}" -type d -exec chmod 755 {} \;
  find "${_inv_stage}" -type f -exec chmod 644 {} \;
  find "${_inv_stage}" -name "*.sh" -exec chmod 755 {} \;
  echo -e "  Normalized inventory permissions (dirs 755, files 644, scripts 755)."

  # ── Bootstrap-init ───────────────────────────────────────────────────────────
  BOOTSTRAP_INIT_SRC="/home/ansiblerunner/rhis/rhis-builder-bootstrap-init"
  if [[ -d "${BOOTSTRAP_INIT_SRC}" ]]; then
      echo -e "  Staging rhis-builder-bootstrap-init..."
      rsync -a --exclude=.git "${BOOTSTRAP_INIT_SRC}/" \
          "${EXPORT_STAGING}/bootstrap/rhis-builder-bootstrap-init/"
  else
      warn "rhis-builder-bootstrap-init not found at ${BOOTSTRAP_INIT_SRC} — not staged"
      warn "  Clone it to ${BOOTSTRAP_INIT_SRC} before transferring."
  fi

  # ── Bootstrap ISOs (C10) ─────────────────────────────────────────────────────
  BOOTSTRAP_VARS="${HIGHSIDE_DIR}/vars/highside_bootstrap_hosts.yml"
  BOOTSTRAP_ISO_DEST="${EXPORT_STAGING}/bootstrap/bootstrap_isos"

  if [[ ! -d "${BOOTSTRAP_INIT_SRC}" ]]; then
      echo -e "  rhis-builder-bootstrap-init not found — cloning from GitHub..."
      git clone https://github.com/parmstro/rhis-builder-bootstrap-init "${BOOTSTRAP_INIT_SRC}"
      if [[ $? -ne 0 ]]; then
          warn "Failed to clone rhis-builder-bootstrap-init — bootstrap ISOs not generated"
      fi
  else
      echo -e "  Updating rhis-builder-bootstrap-init from GitHub..."
      git -C "${BOOTSTRAP_INIT_SRC}" pull origin main
      if [[ $? -ne 0 ]]; then
          warn "Failed to pull rhis-builder-bootstrap-init — continuing with existing version"
      fi
  fi

  if [[ ! -f "${BOOTSTRAP_VARS}" ]]; then
      warn "Bootstrap vars not found: ${BOOTSTRAP_VARS} — bootstrap ISOs not generated"
      warn "  Create ${BOOTSTRAP_VARS} to enable ISO generation."
  elif ! command -v ansible-playbook &>/dev/null; then
      warn "ansible-playbook not found on PATH — bootstrap ISOs not generated"
      warn "  Install ansible-core on the provisioner host to enable ISO generation."
  elif [[ -d "${BOOTSTRAP_INIT_SRC}" ]]; then
      echo -e "  Generating OEMDRV kickstart ISOs..."
      _BOOTSTRAP_INV="/tmp/rhis_bootstrap_inv_$$.ini"
      printf '[provisioner]\nlocalhost ansible_connection=local\n' > "${_BOOTSTRAP_INV}"

      (cd "${BOOTSTRAP_INIT_SRC}" && \
      ansible-playbook \
        --inventory "${_BOOTSTRAP_INV}" \
        --vault-password-file "${HOME}/.ssh/vault.txt" \
        --extra-vars "vault_dir=${HIGHSIDE_DIR}/vault" \
        --extra-vars "vars_path=${BOOTSTRAP_VARS}" \
        --extra-vars "bootstrap_init_iso_dir=${BOOTSTRAP_ISO_DEST}" \
        main.yml)
      ISO_EXIT=$?
      rm -f "${_BOOTSTRAP_INV}"

      if [[ $ISO_EXIT -ne 0 ]]; then
          warn "Bootstrap ISO generation failed (exit ${ISO_EXIT}) — bootstrap_isos/ will be empty"
      else
          ISO_COUNT=$(find "${BOOTSTRAP_ISO_DEST}" -name "*.iso" 2>/dev/null | wc -l)
          if [[ $ISO_COUNT -gt 0 ]]; then
              echo -e "  Generated ${ISO_COUNT} OEMDRV ISO(s):"
              find "${BOOTSTRAP_ISO_DEST}" -name "*.iso" -exec ls -lh {} \; | \
                  awk '{print "    " $NF " (" $5 ")"}'
          else
              warn "No ISOs found after generation — check generate_oemdrv_iso flags in ${BOOTSTRAP_VARS}"
          fi
      fi
  fi

  # ── Infra ISOs (C9) — verified/downloaded at preflight; transferred directly to drive ─────
  if [[ -n "$RHEL_DVD_ISO_PATH" && -f "$RHEL_DVD_ISO_PATH" ]]; then
      _rhel_size=$(du -sh "$RHEL_DVD_ISO_PATH" | cut -f1)
      echo -e "  RHEL DVD ISO:      ${GREEN}ready${NC} (${_rhel_size})  ${RHEL_DVD_ISO_PATH}"
  else
      [[ -n "$RHEL_DVD_ISO_PATH" ]] \
          && warn "RHEL DVD ISO not found at ${RHEL_DVD_ISO_PATH} — infra_isos/ will not contain RHEL DVD" \
          || warn "RHEL DVD ISO not configured — infra_isos/ will not contain RHEL DVD"
  fi
  if [[ -n "$SAT_DVD_ISO_PATH" && -f "$SAT_DVD_ISO_PATH" ]]; then
      _sat_size=$(du -sh "$SAT_DVD_ISO_PATH" | cut -f1)
      echo -e "  Satellite DVD ISO: ${GREEN}ready${NC} (${_sat_size})  ${SAT_DVD_ISO_PATH}"
  else
      [[ -n "$SAT_DVD_ISO_PATH" ]] \
          && warn "Satellite DVD ISO not found at ${SAT_DVD_ISO_PATH} — infra_isos/ will not contain Satellite DVD" \
          || warn "Satellite DVD ISO not configured — infra_isos/ will not contain Satellite DVD"
  fi
  echo -e "  Note: infra ISOs are transferred directly from provisioner to drive — not staged here."

  # ── Operator tools (validate script, README, import tools) ─────────────────
  VALIDATE_SCRIPT="${RHIS_ROOT}/../rhis-provisioner-container/rhis-provisioner/validate_import_bundle.sh"
  [[ -f "${VALIDATE_SCRIPT}" ]] && \
      cp "${VALIDATE_SCRIPT}" "${EXPORT_STAGING}/validate_import_bundle.sh" && \
      chmod +x "${EXPORT_STAGING}/validate_import_bundle.sh"

  for f in README_FIRST.md import_bundle.sh import_bundle.yml; do
      src="${RHIS_ROOT}/transfer_drive/${f}"
      [[ -f "${src}" ]] && cp "${src}" "${EXPORT_STAGING}/${f}"
  done

  echo -e "${GREEN}Stage 1.5 complete.${NC}"

} 2>&1 | tee -a "${LOG_STAGE15}"

STAGE15_EXIT=${PIPESTATUS[0]}

if [[ $STAGE15_EXIT -ne 0 ]]; then
    echo -e "${RED}Stage 1.5 failed (exit ${STAGE15_EXIT}).${NC}"
    echo "  Log: ${LOG_STAGE15}"
    exit $STAGE15_EXIT
fi

# ── Stage 2: Generate manifest and transfer_to_drive.sh ───────────────────────
# Read Pulp export path before the tee subshell so it's visible in the summary.

PULP_EXPORT_PATH=""
if [[ -f "${MARKER_FILE}" ]]; then
    PULP_EXPORT_PATH=$(grep "^pulp_export_path:" "${MARKER_FILE}" | awk '{print $2}' | tr -d '"')
fi
[[ -z "${PULP_EXPORT_PATH}" ]] && \
    warn "Could not read pulp_export_path from ${MARKER_FILE} — Pulp path will be empty in manifest"

echo ""
echo -e "${GREEN}Stage 2 — Generating transfer manifest and transfer script...${NC}" \
  | tee "${LOG_STAGE2}"

{

  # Generate rhis_export_manifest.yml
  echo -e "  Generating rhis_export_manifest.yml..."
  python3 - <<PYEOF
import hashlib, os, sys

staging = "${EXPORT_STAGING}"
manifest_path = os.path.join(staging, "rhis_export_manifest.yml")
version_facts_path = os.path.join(staging, "_version_facts.yml")

# Read version facts written by export_disconnected.yml (package_facts on satellite)
version_facts = {}
if os.path.exists(version_facts_path):
    with open(version_facts_path) as vf:
        for line in vf:
            line = line.strip()
            if ": " in line:
                k, v = line.split(": ", 1)
                version_facts[k.strip()] = v.strip().strip('"')

_skip = {"rhis_export_manifest.yml", "transfer_to_drive.sh", "transfer_to_drive.yml", "_version_facts.yml"}
entries = []
for root, dirs, fnames in os.walk(staging):
    dirs.sort()
    for fname in sorted(fnames):
        fpath = os.path.join(root, fname)
        relpath = os.path.relpath(fpath, staging)
        if relpath in _skip:
            continue
        h = hashlib.sha256()
        with open(fpath, "rb") as f:
            for chunk in iter(lambda: f.read(65536), b""):
                h.update(chunk)
        entries.append((relpath, h.hexdigest()))

with open(manifest_path, "w") as f:
    f.write("source_satellite: \"${SAT_HOST}\"\n")
    f.write("lowside_deployment: \"${LOWSIDE_DOMAIN}\"\n")
    f.write("highside_deployment: \"${HIGHSIDE_DOMAIN}\"\n")
    f.write("generated: \"${LOG_TIMESTAMP}\"\n")
    f.write("staging_path: \"${EXPORT_STAGING}\"\n")
    f.write("pulp_export_path: \"${PULP_EXPORT_PATH}\"\n")
    f.write("satellite_version: \"{}\"\n".format(version_facts.get("satellite_version", "unknown")))
    f.write("pulpcore_version: \"{}\"\n".format(version_facts.get("pulpcore_version", "unknown")))
    f.write("pulp_rpm_version: \"{}\"\n".format(version_facts.get("pulp_rpm_version", "unknown")))
    f.write("pulp_file_version: \"{}\"\n".format(version_facts.get("pulp_file_version", "unknown")))
    f.write("files:\n")
    for path, sha in entries:
        f.write(f"  - path: \"{path}\"\n")
        f.write(f"    sha256: \"{sha}\"\n")

print(f"  Manifest written: {len(entries)} files checksummed")
PYEOF

  # Generate transfer_to_drive.sh and transfer_to_drive.yml from templates.
  # Uses Python3 string replace — safe with paths containing /, |, and other chars
  # that would break envsubst or sed substitution.
  _PULP_ORG_DIR="${PULP_EXPORT_PATH#/var/lib/pulp/exports/}"
  _PULP_ORG_DIR="${_PULP_ORG_DIR%%/*}"
  _PULP_SRC_ROOT="/var/lib/pulp/exports/${_PULP_ORG_DIR}"

  python3 - <<PYEOF
import sys, os, stat

subst = {
    "@@PROVISIONER_HOST@@": "${PROVISIONER_HOST}",
    "@@SAT_HOST@@":         "${SAT_HOST}",
    "@@EXPORT_STAGING@@":   "${EXPORT_STAGING}",
    "@@PULP_EXPORT_PATH@@": "${PULP_EXPORT_PATH}",
    "@@PULP_SRC_ROOT@@":    "${_PULP_SRC_ROOT}",
    "@@PULP_ORG_DIR@@":     "${_PULP_ORG_DIR}",
    "@@HIGHSIDE_DOMAIN@@":  "${HIGHSIDE_DOMAIN}",
    "@@LOG_TIMESTAMP@@":    "${LOG_TIMESTAMP}",
    "@@RHEL_DVD_ISO_PATH@@": "${RHEL_DVD_ISO_PATH}",
    "@@SAT_DVD_ISO_PATH@@":  "${SAT_DVD_ISO_PATH}",
}

def render(tmpl_path, dest_path, executable=False):
    if not os.path.exists(tmpl_path):
        print(f"  WARNING: template not found: {tmpl_path}")
        return
    with open(tmpl_path) as f:
        content = f.read()
    for k, v in subst.items():
        content = content.replace(k, v)
    with open(dest_path, "w") as f:
        f.write(content)
    if executable:
        os.chmod(dest_path, os.stat(dest_path).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    print(f"  {os.path.basename(dest_path)} written to staging.")

tmpl_dir = "${RHIS_ROOT}/transfer_drive"
staging  = "${EXPORT_STAGING}"

render(f"{tmpl_dir}/transfer_to_drive.sh.tmpl",  f"{staging}/transfer_to_drive.sh",  executable=True)
render(f"{tmpl_dir}/transfer_to_drive.yml.tmpl", f"{staging}/transfer_to_drive.yml", executable=False)
PYEOF

  echo -e "${GREEN}Stage 2 complete.${NC}"

} 2>&1 | tee -a "${LOG_STAGE2}"

STAGE2_EXIT=${PIPESTATUS[0]}

if [[ $STAGE2_EXIT -ne 0 ]]; then
    echo -e "${RED}Stage 2 failed (exit ${STAGE2_EXIT}).${NC}"
    echo "  Log: ${LOG_STAGE2}"
    exit $STAGE2_EXIT
fi

# ── Drive size estimation ──────────────────────────────────────────────────────

_staging_bytes=0
_pulp_bytes=0
_iso_bytes=0
_pulp_size_known=false

_v=$(du -sb "${EXPORT_STAGING}" 2>/dev/null | awk '{print $1}')
[[ "${_v}" =~ ^[0-9]+$ ]] && _staging_bytes=$_v

_pulp_org_dir="${PULP_EXPORT_PATH#/var/lib/pulp/exports/}"
_pulp_org_dir="${_pulp_org_dir%%/*}"
_pulp_src_root_est="/var/lib/pulp/exports/${_pulp_org_dir}"

if [[ -n "${_pulp_org_dir}" && -n "${PULP_EXPORT_PATH}" ]]; then
    _v=$(ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        "ansiblerunner@${SAT_HOST}" \
        "sudo du -sb '${_pulp_src_root_est}' 2>/dev/null" 2>/dev/null | awk '{print $1}')
    if [[ "${_v}" =~ ^[0-9]+$ ]]; then
        _pulp_bytes=$_v
        _pulp_size_known=true
    fi
fi

if [[ -n "$RHEL_DVD_ISO_PATH" && -f "$RHEL_DVD_ISO_PATH" ]]; then
    _v=$(du -sb "$RHEL_DVD_ISO_PATH" 2>/dev/null | awk '{print $1}')
    [[ "${_v}" =~ ^[0-9]+$ ]] && _iso_bytes=$(( _iso_bytes + _v ))
fi
if [[ -n "$SAT_DVD_ISO_PATH" && -f "$SAT_DVD_ISO_PATH" ]]; then
    _v=$(du -sb "$SAT_DVD_ISO_PATH" 2>/dev/null | awk '{print $1}')
    [[ "${_v}" =~ ^[0-9]+$ ]] && _iso_bytes=$(( _iso_bytes + _v ))
fi

_total_bytes=$(( _staging_bytes + _pulp_bytes + _iso_bytes ))

# ── Cleanup and summary ────────────────────────────────────────────────────────

duration=$SECONDS
printf "\n${GREEN}End Time: %(%T)T${NC}\n" -1
TZ=UTC0 printf "${GREEN}Elapsed Time: %(%T)T${NC}\n" $duration

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  RHIS Export Complete — Staging Ready${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Lowside → Highside:  ${YELLOW}${LOWSIDE_DOMAIN} → ${HIGHSIDE_DOMAIN}${NC}"
echo -e "  Staging:             ${YELLOW}${EXPORT_STAGING}${NC}  ($(_hr_bytes ${_staging_bytes}))"
if $_pulp_size_known; then
    echo -e "  Pulp export:         ${YELLOW}${PULP_EXPORT_PATH:-unknown}${NC}  ($(_hr_bytes ${_pulp_bytes}), on ${SAT_HOST})"
else
    echo -e "  Pulp export:         ${YELLOW}${PULP_EXPORT_PATH:-unknown}${NC}  (size unknown — SSH to ${SAT_HOST} failed)"
fi
if [[ ${_iso_bytes} -gt 0 ]]; then
    echo -e "  Infra ISOs:          ${YELLOW}$(_hr_bytes ${_iso_bytes})${NC}"
fi
echo -e "  Est. drive required: ${YELLOW}$(_hr_bytes ${_total_bytes})${NC}  (allow +20%% headroom)"
echo ""
echo -e "  Full log:      ${LOG_FULL}"
echo -e "  Stage 1 log:   ${LOG_STAGE1}"
echo -e "  Stage 1.5 log: ${LOG_STAGE15}"
echo -e "  Stage 2 log:   ${LOG_STAGE2}"
echo ""
echo -e "${GREEN}  Next steps — transfer to drive:${NC}"
echo -e "  1. Copy the transfer scripts to your RHEL operator workstation:"
echo -e "     ${YELLOW}scp ansiblerunner@${PROVISIONER_HOST}:${EXPORT_STAGING}/transfer_to_drive.* .${NC}"
echo -e "  2. Plug in the transfer drive (label: TRANSFER_DRV)"
echo -e "  3. Run the transfer script:"
echo -e "     ${YELLOW}./transfer_to_drive.sh -d <drive_mount>${NC}"
echo -e "  4. Physically transport the drive to the highside environment"
echo -e "  5. Mount the drive on an operator RHEL workstation"
echo -e "  6. cd <drive_mount> && ./import_bundle.sh"
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}  !! IMPORTANT: The vault password is NOT on the transfer drive.${NC}"
echo -e "${YELLOW}     It must travel via a separate trusted channel before the${NC}"
echo -e "${YELLOW}     highside operator can complete the satellite build.${NC}"
echo ""
