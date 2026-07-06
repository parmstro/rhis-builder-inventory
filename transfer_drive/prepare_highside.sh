#!/usr/bin/env bash
# prepare_highside.sh
# Run ON the provisioner after import_bundle.sh has completed data delivery.
#
# What this script does:
#   Stage 1 — Load container images into podman
#   Stage 2 — Place inventory at ~/rhis/rhis-builder-inventory/
#   Stage 3 — Loop-mount the RHEL and Satellite DVD ISOs
#   Stage 4 — Copy fdi-image-latest.tar to /mnt/rhis_dvd/ for the HTTP server
#   Stage 5 — Start a persistent HTTP server serving ISOs and discovery image on --dvd-port
#   Stage 6 — Write and distribute yum repo files to idm1 and satellite1
#
# The DVD HTTP server must remain running for the duration of the IdM and
# Satellite builds. Stop it after both builds are complete:
#   kill $(cat ~/.rhis_dvd_server.pid)
#   sudo umount /mnt/rhis_dvd/rhel /mnt/rhis_dvd/satellite
#
# Usage:
#   ./prepare_highside.sh \
#     --deployment  highside.example.ca \
#     --idm-host    idm1.highside.example.ca \
#     --sat-host    satellite1.highside.example.ca \
#     [--ssh-user   ansiblerunner] \
#     [--ssh-key    ~/.ssh/id_ed25519] \
#     [--dvd-port   7778]

set -euo pipefail
SECONDS=0

# ── Style ─────────────────────────────────────────────────────────────────────
_bold=$(tput bold 2>/dev/null || printf '')
_reset=$(tput sgr0 2>/dev/null || printf '')
_green=$(tput setaf 2 2>/dev/null || printf '')
_yellow=$(tput setaf 3 2>/dev/null || printf '')
_red=$(tput setaf 1 2>/dev/null || printf '')
_cyan=$(tput setaf 6 2>/dev/null || printf '')

step()   { echo "${_bold}${_green}  ▶ $*${_reset}"; }
warn()   { echo "${_yellow}  ⚠ $*${_reset}"; }
die()    { echo "${_red}  ✗ $*${_reset}" >&2; exit 1; }
banner() {
    echo ""
    echo "${_bold}${_cyan}══════════════════════════════════════════════════════════════════${_reset}"
    echo "${_bold}${_cyan}  $*${_reset}"
    echo "${_bold}${_cyan}══════════════════════════════════════════════════════════════════${_reset}"
}

# ── Defaults ──────────────────────────────────────────────────────────────────
DEPLOYMENT=""
IDM_HOST=""
SAT_HOST=""
SSH_USER="ansiblerunner"
SSH_KEY="${HOME}/.ssh/id_ed25519"
DVD_PORT=7778
RHIS_TRANSFER="${HOME}/rhis_transfer"
DVD_MOUNT_ROOT="/mnt/rhis_dvd"
DVD_NGINX_CONF="/etc/nginx/conf.d/rhis-dvd.conf"

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --deployment)   DEPLOYMENT="$2";  shift 2 ;;
        --idm-host)     IDM_HOST="$2";    shift 2 ;;
        --sat-host)     SAT_HOST="$2";    shift 2 ;;
        --ssh-user)     SSH_USER="$2";    shift 2 ;;
        --ssh-key)      SSH_KEY="$2";     shift 2 ;;
        --dvd-port)     DVD_PORT="$2";    shift 2 ;;
        --help|-h)
            sed -n '/^# Usage:/,/^[^#]/p' "$0" | grep '^#' | sed 's/^# *//'
            exit 0 ;;
        *) die "Unknown argument: $1. Use --help for usage." ;;
    esac
done

[[ -n "${DEPLOYMENT}" ]] || die "--deployment is required"
[[ -n "${IDM_HOST}" ]]   || die "--idm-host is required"
[[ -n "${SAT_HOST}" ]]   || die "--sat-host is required"
[[ -f "${SSH_KEY}" ]]    || die "SSH key not found: ${SSH_KEY}"

_ssh="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=15 -i ${SSH_KEY}"
_scp="scp -o StrictHostKeyChecking=no -o ConnectTimeout=15 -i ${SSH_KEY}"

banner "RHIS Highside — Provisioner Preparation"
echo ""
echo "  Deployment:  ${DEPLOYMENT}"
echo "  IdM host:    ${IDM_HOST}"
echo "  Satellite:   ${SAT_HOST}"
echo "  SSH user:    ${SSH_USER}"
echo "  DVD port:    ${DVD_PORT}"
echo "  Transfer:    ${RHIS_TRANSFER}"

# ── Stage 1: Load containers ──────────────────────────────────────────────────
banner "Stage 1 — Load containers into podman"

_containers_dir="${RHIS_TRANSFER}/provisioner/containers"
[[ -d "${_containers_dir}" ]] \
    || die "Containers directory not found: ${_containers_dir}"

_prov_tar=$(find "${_containers_dir}" -maxdepth 1 -name "rhis-provisioner_*.tar" \
    | sort | tail -1)
[[ -n "${_prov_tar}" ]] \
    || die "No rhis-provisioner_*.tar found in ${_containers_dir}"

step "Loading provisioner container: $(basename "${_prov_tar}")"
podman load -i "${_prov_tar}"

# Load all additional containers present (tang, quay, gitea, etc.)
while IFS= read -r _tar; do
    _base=$(basename "${_tar}")
    [[ "${_base}" == rhis-provisioner_* ]] && continue
    step "Loading container: ${_base}"
    podman load -i "${_tar}"
done < <(find "${_containers_dir}" -maxdepth 1 -name "*.tar" | sort)

echo ""
step "Loaded images:"
podman images --format "    {{.Repository}}:{{.Tag}}" | grep -v '<none>' || true

# ── Stage 2: Place inventory ──────────────────────────────────────────────────
banner "Stage 2 — Place inventory"

_inv_src="${RHIS_TRANSFER}/provisioner/inventory"
_inv_dst="${HOME}/rhis/rhis-builder-inventory"

[[ -d "${_inv_src}" ]] || die "Inventory source not found: ${_inv_src}"

step "Installing inventory to ${_inv_dst}"
mkdir -p "${_inv_dst}"
rsync -a --delete "${_inv_src}/" "${_inv_dst}/"

if [[ -d "${_inv_dst}/deployments/${DEPLOYMENT}" ]]; then
    step "Deployment directory confirmed: deployments/${DEPLOYMENT}/"
else
    warn "deployments/${DEPLOYMENT}/ not found — verify --deployment value"
fi

# ── Stage 3: Mount DVD ISOs ───────────────────────────────────────────────────
banner "Stage 3 — Mount DVD ISOs"

_infra_isos="${RHIS_TRANSFER}/bootstrap/infra_isos"
[[ -d "${_infra_isos}" ]] || die "infra_isos directory not found: ${_infra_isos}"

_rhel_iso=$(find "${_infra_isos}" -maxdepth 1 -name "rhel*.iso" | sort | tail -1)
_sat_iso=$(find "${_infra_isos}" -maxdepth 1 -name "satellite*.iso" | sort | tail -1)

[[ -n "${_rhel_iso}" ]] || die "No rhel*.iso found in ${_infra_isos}"
[[ -n "${_sat_iso}" ]]  || die "No satellite*.iso found in ${_infra_isos}"

step "RHEL DVD ISO:      $(basename "${_rhel_iso}")"
step "Satellite DVD ISO: $(basename "${_sat_iso}")"

sudo mkdir -p "${DVD_MOUNT_ROOT}/rhel" "${DVD_MOUNT_ROOT}/satellite"

if mountpoint -q "${DVD_MOUNT_ROOT}/rhel" 2>/dev/null; then
    warn "RHEL DVD already mounted at ${DVD_MOUNT_ROOT}/rhel — skipping"
else
    step "Mounting RHEL DVD"
    sudo mount -o loop,ro "${_rhel_iso}" "${DVD_MOUNT_ROOT}/rhel"
fi

if mountpoint -q "${DVD_MOUNT_ROOT}/satellite" 2>/dev/null; then
    warn "Satellite DVD already mounted at ${DVD_MOUNT_ROOT}/satellite — skipping"
else
    step "Mounting Satellite DVD"
    sudo mount -o loop,ro "${_sat_iso}" "${DVD_MOUNT_ROOT}/satellite"
fi

# Verify the expected repo directories exist
for _check in rhel/BaseOS rhel/AppStream satellite/Satellite satellite/Maintenance; do
    [[ -d "${DVD_MOUNT_ROOT}/${_check}" ]] \
        || die "Expected repo directory not found after mount: ${DVD_MOUNT_ROOT}/${_check}"
done
step "All four repo directories confirmed"

# ── Stage 4: Stage discovery image ───────────────────────────────────────────
banner "Stage 4 — Stage discovery image"

_provisioner_ip=$(hostname -I | awk '{print $1}')
_discovery_src="${RHIS_TRANSFER}/satellite/discovery_images/fdi-image-latest.tar"
_discovery_dst="${DVD_MOUNT_ROOT}/fdi-image-latest.tar"

if [[ ! -f "${_discovery_src}" ]]; then
    warn "Discovery image not found at ${_discovery_src}"
    warn "The satellite-installer will not be able to download the FDI image."
    warn "Ensure fdi-image-latest.tar is in the transfer bundle's satellite/discovery_images/ directory."
else
    if [[ -f "${_discovery_dst}" ]]; then
        warn "Discovery image already staged at ${_discovery_dst} — skipping copy"
    else
        step "Copying discovery image to DVD server root"
        sudo cp "${_discovery_src}" "${_discovery_dst}"
        step "Discovery image staged: $(du -sh "${_discovery_dst}" | cut -f1) at ${_discovery_dst}"
    fi
    step "Setting SELinux type cobbler_var_lib_t on discovery image (required by satellite-installer)"
    sudo chcon -t cobbler_var_lib_t "${_discovery_dst}" \
        || warn "chcon failed — satellite-installer may fail to read the FDI image"
fi

echo ""
echo "    http://${_provisioner_ip}:${DVD_PORT}/fdi-image-latest.tar"

# ── Stage 5: Start DVD HTTP server (nginx) ───────────────────────────────────
banner "Stage 5 — Start DVD HTTP server (nginx)"

# python3 -m http.server is single-threaded and corrupts responses under the
# concurrent RPM downloads that dnf issues. nginx handles parallel requests correctly.

if ! command -v nginx &>/dev/null; then
    step "Installing nginx from mounted RHEL DVD"
    sudo dnf install -y nginx \
        --disablerepo='*' \
        --repofrompath=dvd-baseos,"file://${DVD_MOUNT_ROOT}/rhel/BaseOS" \
        --repofrompath=dvd-appstream,"file://${DVD_MOUNT_ROOT}/rhel/AppStream" \
        --nogpgcheck \
        || die "nginx install failed — verify ${DVD_MOUNT_ROOT}/rhel is mounted"
fi

step "Writing nginx server block for DVD root on port ${DVD_PORT}"
sudo tee "${DVD_NGINX_CONF}" > /dev/null << NGINXEOF
server {
    listen ${DVD_PORT};
    root ${DVD_MOUNT_ROOT};
    autoindex on;
    sendfile on;
}
NGINXEOF

# Disable the default port-80 block so nginx starts without conflicts
if [[ -f /etc/nginx/conf.d/default.conf ]]; then
    sudo mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.disabled
fi

step "Adding SELinux label for port ${DVD_PORT}/tcp (required for non-standard nginx port)"
if command -v semanage &>/dev/null; then
    sudo semanage port -a -t http_port_t -p tcp "${DVD_PORT}" 2>/dev/null \
        || sudo semanage port -m -t http_port_t -p tcp "${DVD_PORT}" 2>/dev/null \
        || warn "semanage port failed — SELinux may block nginx on port ${DVD_PORT}"
else
    warn "semanage not found — install policycoreutils-python-utils if nginx fails to bind"
fi

step "Opening firewall port ${DVD_PORT}/tcp (runtime only — closes on firewalld restart or reboot)"
if command -v firewall-cmd &>/dev/null; then
    sudo firewall-cmd --add-port="${DVD_PORT}/tcp" --zone=public 2>/dev/null \
        || warn "firewall-cmd failed — port ${DVD_PORT} may already be open or firewalld is not running"
else
    warn "firewall-cmd not found — skipping firewall rule (ensure port ${DVD_PORT} is reachable)"
fi

if sudo systemctl is-active nginx &>/dev/null; then
    step "nginx already running — reloading config"
    sudo systemctl reload nginx
else
    step "Starting nginx on port ${DVD_PORT}"
    sudo systemctl enable --now nginx
fi

sudo systemctl is-active nginx > /dev/null \
    || die "nginx failed to start — check: journalctl -u nginx"
step "nginx started on port ${DVD_PORT}"

echo ""
echo "    http://${_provisioner_ip}:${DVD_PORT}/rhel/BaseOS/"
echo "    http://${_provisioner_ip}:${DVD_PORT}/rhel/AppStream/"
echo "    http://${_provisioner_ip}:${DVD_PORT}/satellite/Satellite/"
echo "    http://${_provisioner_ip}:${DVD_PORT}/satellite/Maintenance/"

# ── Stage 6: Create and distribute repo files ─────────────────────────────────
banner "Stage 6 — Distribute repo files"

_pub_key_file=$(mktemp /tmp/rhis-provisioner-pub.XXXXXX)
_idm_repo=$(mktemp /tmp/rhis-highside-idm.XXXXXX.repo)
_sat_repo=$(mktemp /tmp/rhis-highside-satellite.XXXXXX.repo)
trap 'rm -f "${_pub_key_file}" "${_idm_repo}" "${_sat_repo}"' EXIT

ssh-keygen -y -f "${SSH_KEY}" > "${_pub_key_file}" \
    || die "Failed to extract public key from ${SSH_KEY}"

for _host in "${IDM_HOST}" "${SAT_HOST}"; do
    step "Preparing ${_host}"

    step "Adding provisioner public key to authorized_keys on ${_host}"
    ${_scp} "${_pub_key_file}" "${SSH_USER}@${_host}:/tmp/.rhis_provisioner.pub"
    ${_ssh} "${SSH_USER}@${_host}" \
        "mkdir -p ~/.ssh && chmod 700 ~/.ssh && \
         cat /tmp/.rhis_provisioner.pub >> ~/.ssh/authorized_keys && \
         sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys && \
         chmod 600 ~/.ssh/authorized_keys && \
         rm -f /tmp/.rhis_provisioner.pub"

    step "Cleaning subscription-manager on ${_host} to prevent CDN timeouts"
    ${_ssh} "${SSH_USER}@${_host}" \
        "sudo subscription-manager clean 2>/dev/null || true"
done
echo ""

cat > "${_idm_repo}" << REPOEOF
# RHIS Highside IdM package source
# Generated by prepare_highside.sh — provisioner: ${_provisioner_ip}
# Remove this file after registering this host to the satellite.

[rhis-rhel-baseos]
name=RHEL 9 BaseOS — RHIS Highside
baseurl=http://${_provisioner_ip}:${DVD_PORT}/rhel/BaseOS/
enabled=1
gpgcheck=0
skip_if_unavailable=1

[rhis-rhel-appstream]
name=RHEL 9 AppStream — RHIS Highside
baseurl=http://${_provisioner_ip}:${DVD_PORT}/rhel/AppStream/
enabled=1
gpgcheck=0
skip_if_unavailable=1
REPOEOF

cat > "${_sat_repo}" << REPOEOF
# RHIS Highside Satellite package source
# Generated by prepare_highside.sh — provisioner: ${_provisioner_ip}
# NOTE: This file is permanent — it is the only patching path for this satellite host.
# The satellite host cannot self-subscribe to its own content views.

[rhis-rhel-baseos]
name=RHEL 9 BaseOS — RHIS Highside
baseurl=http://${_provisioner_ip}:${DVD_PORT}/rhel/BaseOS/
enabled=1
gpgcheck=0
skip_if_unavailable=1

[rhis-rhel-appstream]
name=RHEL 9 AppStream — RHIS Highside
baseurl=http://${_provisioner_ip}:${DVD_PORT}/rhel/AppStream/
enabled=1
gpgcheck=0
skip_if_unavailable=1

[rhis-satellite]
name=Red Hat Satellite 6 — RHIS Highside
baseurl=http://${_provisioner_ip}:${DVD_PORT}/satellite/Satellite/
enabled=1
gpgcheck=0
skip_if_unavailable=1

[rhis-satellite-maintenance]
name=Red Hat Satellite 6 Maintenance — RHIS Highside
baseurl=http://${_provisioner_ip}:${DVD_PORT}/satellite/Maintenance/
enabled=1
gpgcheck=0
skip_if_unavailable=1
REPOEOF

step "Distributing repo file to IdM host: ${IDM_HOST}"
${_scp} "${_idm_repo}" \
    "${SSH_USER}@${IDM_HOST}:/tmp/rhis-highside.repo"
${_ssh} "${SSH_USER}@${IDM_HOST}" \
    "sudo mv /tmp/rhis-highside.repo /etc/yum.repos.d/rhis-highside.repo && \
     sudo dnf clean all -q && \
     sudo dnf repolist --disablerepo='*' --enablerepo='rhis-*' 2>/dev/null"

step "Distributing repo file to Satellite host: ${SAT_HOST}"
${_scp} "${_sat_repo}" \
    "${SSH_USER}@${SAT_HOST}:/tmp/rhis-highside.repo"
${_ssh} "${SSH_USER}@${SAT_HOST}" \
    "sudo mv /tmp/rhis-highside.repo /etc/yum.repos.d/rhis-highside.repo && \
     sudo dnf clean all -q && \
     sudo dnf repolist --disablerepo='*' --enablerepo='rhis-*' 2>/dev/null"

# ── Summary ───────────────────────────────────────────────────────────────────
banner "Preparation complete  (${SECONDS}s)"

echo ""
echo "  DVD server:  http://${_provisioner_ip}:${DVD_PORT}/"
echo "               Serves:  /rhel/BaseOS/   /rhel/AppStream/"
echo "                        /satellite/Satellite/   /satellite/Maintenance/"
echo "                        /fdi-image-latest.tar   (discovery image)"
echo "               nginx — check status: sudo systemctl status nginx"
echo ""
echo "  ─────────────────────────────────────────────────────────────────"
echo "  Next steps — run in order from inside the provisioner container:"
echo "  ─────────────────────────────────────────────────────────────────"
echo ""
echo "  1. Build IdM:"
echo "       build_idm_primary.sh \\"
echo "         --deployment ${DEPLOYMENT}"
echo ""
echo "  2. Build Satellite:"
echo "       build_sat_disconnected_import.sh \\"
echo "         --delivery-method rsync \\"
echo "         --deployment ${DEPLOYMENT}"
echo ""
echo "  The DVD server must remain running for the duration of both builds."
echo ""
echo "  After both builds are complete, stop the DVD server:"
echo "       sudo systemctl stop nginx"
echo "       sudo umount ${DVD_MOUNT_ROOT}/rhel ${DVD_MOUNT_ROOT}/satellite"
echo ""
echo "  Then register IdM to the satellite and remove the temporary repo file:"
echo "       ssh ${SSH_USER}@${IDM_HOST} \\"
echo "         'sudo subscription-manager register ... && sudo rm /etc/yum.repos.d/rhis-highside.repo'"
echo ""
