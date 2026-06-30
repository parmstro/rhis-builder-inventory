#!/bin/bash
# rh_iso_download.sh
# Download a Red Hat product DVD ISO from the Red Hat CDN using the RHSM API.
#
# Uses the offline token → bearer token flow:
#   Step 1 — Exchange offline token for a short-lived bearer token (5 min TTL)
#   Step 2 — List available images for the product/version/arch (discovers checksum)
#   Step 3 — Get a pre-signed CDN download URL for the selected ISO
#   Step 4 — Download and SHA256-verify
#
# The offline token is obtained once from: https://access.redhat.com/management/api
# Store it in ~/.config/rh_offline_token (mode 0600) or pass via --token.
#
# USAGE:
#   ./rh_iso_download.sh --cset <content_set> [--version <version>] -o <output_path>
#
# OPTIONS:
#   --cset <content_set>    Content set label — shown in Satellite under Other Repositories.
#                           Examples: rhel-9-for-x86_64-isos
#                                     satellite-6.19-for-rhel-9-x86_64-isos
#   --version <version>     Point release to download, e.g. 9.8 or 6.19.1.
#                           Omit or use 'latest' to select the most recently published ISO.
#   -o | --output <path>    Destination file path (required unless --list)
#       --token <token>     RHSM offline token (or use --token-file)
#       --token-file <path> File containing the offline token
#                           (default: ~/.config/rh_offline_token)
#       --list              List available images and exit — no download
#       --dry-run           Show what would be downloaded without downloading
#   -h | --help             Show this help
#
# EXAMPLES:
#   ./rh_iso_download.sh --cset rhel-9-for-x86_64-baseos-isos --list
#   ./rh_iso_download.sh --cset rhel-9-for-x86_64-baseos-isos --version 9.8 -o /data/isos/rhel-9.8-x86_64-dvd.iso
#   ./rh_iso_download.sh --cset satellite-6.19-for-rhel-9-x86_64-isos --list
#   ./rh_iso_download.sh --cset satellite-6.19-for-rhel-9-x86_64-isos --version 6.19.1 -o /data/isos/satellite-6.19.1-x86_64-dvd.iso
#   ./rh_iso_download.sh --cset satellite-6.19-for-rhel-9-x86_64-isos -o /data/isos/satellite-6.19-latest-x86_64-dvd.iso
#
# NOTES:
#   - The bearer token expires in 5 minutes; the script fetches it immediately before use.
#   - The CDN download URL returned by Step 3 is pre-signed and does NOT require
#     the bearer token header — just curl it directly.
#   - If the output file already exists and its SHA256 matches, the download is skipped.
#   - Requires: curl, python3 (for JSON parsing), sha256sum

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

RHSM_TOKEN_ENDPOINT="https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token"
RHSM_API_BASE="https://api.access.redhat.com/management/v1"

cset=""
version=""
output_path=""
token_literal=""
token_file="${HOME}/.config/rh_offline_token"
list_only=false
dry_run=false

die()  { echo -e "${RED}ERROR: $*${NC}" >&2; exit 1; }
warn() { echo -e "${YELLOW}WARNING: $*${NC}" >&2; }

usage() {
    sed -n '/^# USAGE:/,/^[^#]/p' "$0" | grep '^#' | sed 's/^# \{0,1\}//'
    exit 0
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
           --cset)       cset="$2";          shift ;;
           --version)    version="$2";       shift ;;
        -o|--output)     output_path="$2";   shift ;;
           --token)      token_literal="$2"; shift ;;
           --token-file) token_file="$2";    shift ;;
           --list)       list_only=true ;;
           --dry-run)    dry_run=true ;;
        -h|--help)       usage ;;
        *)
            echo -e "${RED}ERROR: Unknown option: $1${NC}" >&2
            echo "Run '$(basename "$0") --help' for usage." >&2
            exit 1 ;;
    esac
    shift
done

# ── Validate args ──────────────────────────────────────────────────────────────

[[ -z "$cset" ]] && die "--cset <content_set> is required"
if ! $list_only; then
    [[ -z "$output_path" ]] && die "--output is required (destination file path)"
fi

# ── Resolve offline token ──────────────────────────────────────────────────────

if [[ -n "$token_literal" ]]; then
    OFFLINE_TOKEN="$token_literal"
elif [[ -f "$token_file" ]]; then
    OFFLINE_TOKEN=$(cat "$token_file")
    [[ -z "$OFFLINE_TOKEN" ]] && die "Token file is empty: ${token_file}"
else
    die "No offline token found. Pass --token <token> or create ${token_file} (mode 0600).
  Generate an offline token at: https://access.redhat.com/management/api"
fi

# ── Dependency check ───────────────────────────────────────────────────────────

for cmd in curl python3 sha256sum; do
    command -v "$cmd" &>/dev/null || die "Required command not found: ${cmd}"
done

# ── Helper: compact JSON pretty-print via python3 ──────────────────────────────

_json_keys() {
    python3 -c "
import sys, json
data = json.load(sys.stdin)
if isinstance(data, list):
    print('(list of', len(data), 'items)')
    if data:
        print('First item keys:', list(data[0].keys()) if isinstance(data[0], dict) else type(data[0]).__name__)
elif isinstance(data, dict):
    print('Keys:', list(data.keys()))
"
}

# ── Step 1: Get bearer token ───────────────────────────────────────────────────

echo ""
echo -e "${GREEN}Step 1 — Exchanging offline token for bearer token...${NC}"

token_response=$(curl -sf -X POST "${RHSM_TOKEN_ENDPOINT}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "grant_type=refresh_token" \
    --data-urlencode "client_id=rhsm-api" \
    --data-urlencode "refresh_token=${OFFLINE_TOKEN}" 2>&1)

curl_exit=$?
if [[ $curl_exit -ne 0 ]]; then
    die "Token request failed (curl exit ${curl_exit}). Check network connectivity and offline token."
fi

ACCESS_TOKEN=$(echo "${token_response}" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'access_token' in data:
        print(data['access_token'])
    elif 'error' in data:
        print('ERROR:' + data.get('error', '') + ': ' + data.get('error_description', ''), file=sys.stderr)
        sys.exit(1)
    else:
        print('ERROR: Unexpected response:', data, file=sys.stderr)
        sys.exit(1)
except Exception as e:
    print('ERROR: Could not parse token response:', e, file=sys.stderr)
    sys.exit(1)
")

[[ $? -ne 0 || -z "$ACCESS_TOKEN" ]] && die "Failed to extract access token. Response: ${token_response}"
echo -e "  ${GREEN}✓${NC} Bearer token acquired (valid 5 minutes)"

# ── Step 2: List images for product/version/arch ───────────────────────────────

LIST_URL="${RHSM_API_BASE}/images/cset/${cset}"
echo ""
echo -e "${GREEN}Step 2 — Listing available images...${NC}"
echo -e "  URL: ${YELLOW}${LIST_URL}${NC}"

list_response=$(curl -sf -H "Authorization: Bearer ${ACCESS_TOKEN}" "${LIST_URL}" 2>&1)
curl_exit=$?

if [[ $curl_exit -ne 0 ]]; then
    # Try without arch in case the endpoint takes version only
    LIST_URL_ALT="${RHSM_API_BASE}/images/${product}/${version}"
    echo -e "  ${YELLOW}First attempt failed — retrying without arch: ${LIST_URL_ALT}${NC}"
    list_response=$(curl -sf -H "Authorization: Bearer ${ACCESS_TOKEN}" "${LIST_URL_ALT}" 2>&1)
    curl_exit=$?
    [[ $curl_exit -ne 0 ]] && die "Image list request failed (curl exit ${curl_exit}). Response: ${list_response}"
    LIST_URL="${LIST_URL_ALT}"
fi

echo -e "  ${GREEN}✓${NC} Response received"

# ── Parse the image list ───────────────────────────────────────────────────────

# Show raw structure summary for debugging
echo ""
echo -e "  Response structure:"
echo "${list_response}" | _json_keys | sed 's/^/    /'

# Extract the image list — try both body[] and top-level [] patterns
IMAGE_JSON=$(echo "${list_response}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
# Response may be wrapped in 'body' (with optional 'pagination' sibling) or a bare list
images = data.get('body', data) if isinstance(data, dict) else data
if not isinstance(images, list):
    images = [images]
print(json.dumps(images))
")

# Show all available images
echo ""
echo -e "  Available images:"
echo "${IMAGE_JSON}" | python3 -c "
import sys, json
images = json.load(sys.stdin)
for i, img in enumerate(images):
    name      = img.get('imageName', img.get('filename', '(no name)'))
    filename  = img.get('filename', '')
    checksum  = img.get('checksum', '(no checksum)')
    published = img.get('datePublished', '')[:10]
    print(f'  [{i}] {name}')
    if filename:
        print(f'       filename={filename}')
    print(f'       checksum={checksum}')
    if published:
        print(f'       published={published}')
"

if $list_only; then
    _list_label="${cset}"
    echo ""
    echo -e "  Raw JSON saved to: /tmp/rh_images_${_list_label}.json"
    echo "${list_response}" > "/tmp/rh_images_${_list_label}.json"
    echo ""
    exit 0
fi

# ── Select DVD ISO ─────────────────────────────────────────────────────────────
# Look for entries where filename or type indicates a DVD ISO.
# Priority: exact "dvd.iso" in filename, then "DVD" type, then first .iso

SELECTED=$(echo "${IMAGE_JSON}" | python3 -c "
import sys, json
images = json.load(sys.stdin)

def score(img):
    fn   = img.get('filename', '').lower()
    name = img.get('imageName', '').lower()
    # Exact match: Binary DVD in imageName and dvd.iso in filename
    if 'binary dvd' in name and fn.endswith('.iso'):
        return 4
    # dvd in filename and ends in .iso
    if 'dvd' in fn and fn.endswith('.iso') and not fn.startswith('rhel-rt'):
        return 3
    # dvd in imageName
    if 'dvd' in name and fn.endswith('.iso'):
        return 2
    if fn.endswith('.iso'):
        return 1
    return 0

dvd_isos = [img for img in images if score(img) > 0]
version_filter = '${version}'
if version_filter and version_filter != 'latest':
    matched = [img for img in dvd_isos if version_filter in img.get('filename', '') or version_filter in img.get('imageName', '')]
    if not matched:
        available = [img.get('filename', img.get('imageName', '?')) for img in dvd_isos]
        print('ERROR: No DVD ISO matching version ' + version_filter + '. Available: ' + ', '.join(available), file=sys.stderr)
        sys.exit(1)
    dvd_isos = matched
dvd_isos.sort(key=lambda img: img.get('datePublished', ''), reverse=True)
best = dvd_isos[0] if dvd_isos else None
print(json.dumps(best) if best else 'null')
")

if [[ "$SELECTED" == "null" || -z "$SELECTED" ]]; then
    die "No DVD ISO found in the image list for ${product} ${version} ${arch}.
Use --list to inspect the available images and verify the product/version names."
fi

ISO_NAME=$(echo "$SELECTED"     | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('imageName', d.get('filename', 'unknown')))")
ISO_FILENAME=$(echo "$SELECTED" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('filename', 'unknown.iso'))")
ISO_CHECKSUM=$(echo "$SELECTED" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('checksum', ''))")
ISO_DOWNLOAD_HREF=$(echo "$SELECTED" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('downloadHref', ''))")

echo ""
echo -e "${GREEN}Selected:${NC}"
echo -e "  Name:      ${YELLOW}${ISO_NAME}${NC}"
echo -e "  Filename:  ${ISO_FILENAME}"
echo -e "  Checksum:  ${ISO_CHECKSUM}"

[[ -z "$ISO_CHECKSUM" ]] && die "No checksum found for selected image — cannot verify download"

# ── Check if already downloaded ────────────────────────────────────────────────

if [[ -f "$output_path" ]]; then
    echo ""
    echo -e "  Output file already exists: ${output_path}"
    echo -e "  Verifying existing SHA256..."
    existing_sha=$(sha256sum "$output_path" | cut -d' ' -f1)
    expected_sha="${ISO_CHECKSUM}"
    if [[ "$existing_sha" == "$expected_sha" ]]; then
        echo -e "  ${GREEN}✓${NC} SHA256 matches — file already complete, nothing to do."
        echo ""
        exit 0
    else
        warn "SHA256 mismatch on existing file — re-downloading."
        warn "  Expected: ${expected_sha}"
        warn "  Got:      ${existing_sha}"
    fi
fi

# ── Step 3: Get pre-signed CDN download URL ────────────────────────────────────
# downloadHref from the listing is the endpoint to call; it returns a redirect or
# JSON with the actual pre-signed CDN URL.

DOWNLOAD_HREF="${ISO_DOWNLOAD_HREF:-${RHSM_API_BASE}/images/${ISO_CHECKSUM}/download}"
# ISO_DOWNLOAD_HREF comes directly from the listing response; the fallback constructs it from the checksum

echo ""
echo -e "${GREEN}Step 3 — Getting CDN download URL...${NC}"
echo -e "  Endpoint: ${DOWNLOAD_HREF}"

# Re-fetch bearer token — Step 2 may have taken time and 5-min TTL is tight
echo -e "  Refreshing bearer token..."
token_response=$(curl -sf -X POST "${RHSM_TOKEN_ENDPOINT}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "grant_type=refresh_token" \
    --data-urlencode "client_id=rhsm-api" \
    --data-urlencode "refresh_token=${OFFLINE_TOKEN}" 2>&1)

ACCESS_TOKEN=$(echo "${token_response}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('access_token', ''))
")
[[ -z "$ACCESS_TOKEN" ]] && die "Failed to refresh bearer token before download."

DOWNLOAD_RESPONSE=$(curl -sf -H "Authorization: Bearer ${ACCESS_TOKEN}" "${DOWNLOAD_HREF}" 2>&1)
curl_exit=$?
[[ $curl_exit -ne 0 ]] && die "Download URL request failed (curl exit ${curl_exit}). Response: ${DOWNLOAD_RESPONSE}"

CDN_URL=$(echo "${DOWNLOAD_RESPONSE}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
body = data.get('body', data)
# Field may be 'href', 'url', or 'downloadHref'
url = body.get('href', body.get('downloadHref', body.get('url', '')))
print(url)
")
CDN_FILENAME=$(echo "${DOWNLOAD_RESPONSE}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
body = data.get('body', data)
print(body.get('filename', ''))
")

[[ -z "$CDN_URL" ]] && die "No download URL in response. Raw response: ${DOWNLOAD_RESPONSE}"

echo -e "  ${GREEN}✓${NC} CDN URL acquired"
echo -e "  CDN filename: ${CDN_FILENAME}"

if $dry_run; then
    echo ""
    echo -e "${YELLOW}Dry-run — download URL:${NC}"
    echo -e "  ${CDN_URL}"
    echo ""
    echo -e "  To download manually:"
    echo -e "  curl -L --progress-bar -o '${output_path}' '${CDN_URL}'"
    echo ""
    exit 0
fi

# ── Step 4: Download ───────────────────────────────────────────────────────────

output_dir=$(dirname "$output_path")
[[ -d "$output_dir" ]] || mkdir -p "$output_dir" || die "Cannot create output directory: ${output_dir}"
[[ -w "$output_dir" ]] || die "Output directory is not writable: ${output_dir}"

# Pre-flight: check available disk space
avail_bytes=$(df -B1 --output=avail "$output_dir" 2>/dev/null | tail -1 | tr -d ' ')
avail_human=$(df -h --output=avail "$output_dir" 2>/dev/null | tail -1 | tr -d ' ')

echo ""
echo -e "${GREEN}Step 4 — Downloading...${NC}"
echo -e "  Output:    ${YELLOW}${output_path}${NC}"
echo -e "  Available: ${avail_human} on $(df --output=target "$output_dir" 2>/dev/null | tail -1 | tr -d ' ')"
echo ""

# Warn if available space looks tight for a DVD ISO (assume ~10 GB worst case)
if [[ -n "$avail_bytes" && "$avail_bytes" -lt 10737418240 ]]; then
    warn "Less than 10 GB available — download may fail if the ISO is larger than ${avail_human}"
fi

# The CDN URL is pre-signed — no Authorization header needed
curl -L --progress-bar -o "${output_path}.part" "${CDN_URL}"
curl_exit=$?

if [[ $curl_exit -ne 0 ]]; then
    rm -f "${output_path}.part"
    if [[ $curl_exit -eq 23 ]]; then
        avail_now=$(df -h --output=avail "$output_dir" 2>/dev/null | tail -1 | tr -d ' ')
        die "Download failed — write error (curl exit 23).
  This usually means the destination ran out of disk space mid-download.
  Space remaining on ${output_dir}: ${avail_now}
  Try a destination on a larger filesystem, or free up space and retry."
    fi
    die "Download failed (curl exit ${curl_exit})"
fi

# ── Step 5: Verify SHA256 ──────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}Step 5 — Verifying SHA256...${NC}"
actual_sha=$(sha256sum "${output_path}.part" | cut -d' ' -f1)
expected_sha="${ISO_CHECKSUM}"

if [[ "$actual_sha" != "$expected_sha" ]]; then
    rm -f "${output_path}.part"
    die "SHA256 mismatch!
  Expected: ${expected_sha}
  Got:      ${actual_sha}
  Partial file removed."
fi

mv "${output_path}.part" "${output_path}"

echo -e "  ${GREEN}✓${NC} SHA256 verified"
echo ""
echo -e "════════════════════════════════════════════════════════════════"
echo -e "  ${GREEN}Download complete${NC}"
echo -e "  File:   ${output_path}"
echo -e "  SHA256: ${actual_sha}"
echo -e "════════════════════════════════════════════════════════════════"
echo ""
