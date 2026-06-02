#!/bin/bash
# migrate_variables.sh — Apply rhis-builder variable renames to existing files
#
# By default this script writes output to <file>.new so you can review changes
# before committing. Use --apply to rename in place.
#
# USAGE:
#   ./schema/scripts/migrate_variables.sh [OPTIONS]
#
# OPTIONS:
#   -b | --basevars FILE      Path to a <domain>_inventory_basevars.yml file to migrate
#   -d | --inventory-dir DIR  Path to a deployed inventory directory (deployments/<domain>/)
#   --apply                   Apply changes in place instead of writing .new files
#   -h | --help               Show this help
#
# EXAMPLES:
#   # Preview changes to a basevars file
#   ./schema/scripts/migrate_variables.sh -b example.ca_inventory_basevars.yml
#
#   # Apply changes to a basevars file in place
#   ./schema/scripts/migrate_variables.sh -b example.ca_inventory_basevars.yml --apply
#
#   # Preview changes to a deployed inventory directory
#   ./schema/scripts/migrate_variables.sh -d deployments/example.ca/
#
#   # Apply all migrations to both
#   ./schema/scripts/migrate_variables.sh \
#       -b example.ca_inventory_basevars.yml \
#       -d deployments/example.ca/ \
#       --apply

set -euo pipefail

APPLY=false
BASEVARS_FILE=""
INVENTORY_DIR=""
CHANGED=0

usage() {
    sed -n '/^# USAGE:/,/^[^#]/p' "$0" | grep '^#' | sed 's/^# \{0,1\}//'
    exit 0
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -b|--basevars)      BASEVARS_FILE="$2"; shift ;;
        -d|--inventory-dir) INVENTORY_DIR="$2"; shift ;;
        --apply)            APPLY=true ;;
        -h|--help)          usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
    shift
done

if [[ -z "$BASEVARS_FILE" && -z "$INVENTORY_DIR" ]]; then
    echo "ERROR: specify at least one of --basevars or --inventory-dir"
    usage
fi

# ─── helpers ──────────────────────────────────────────────────────────────────

migrate_file() {
    local file="$1"
    shift
    local -a transforms=("$@")

    if [[ ! -f "$file" ]]; then
        echo "  SKIP  $file (not found)"
        return
    fi

    local tmp
    tmp=$(mktemp)
    cp "$file" "$tmp"

    for transform in "${transforms[@]}"; do
        sed -i "$transform" "$tmp"
    done

    if diff -q "$file" "$tmp" > /dev/null 2>&1; then
        echo "  OK    $file (no changes needed)"
        rm "$tmp"
        return
    fi

    if $APPLY; then
        cp "$tmp" "$file"
        echo "  APPLY $file"
    else
        cp "$tmp" "${file}.new"
        echo "  NEW   ${file}.new"
        diff "$file" "${file}.new" | grep '^[<>]' | sed 's/^/        /'
    fi
    rm -f "$tmp"
    CHANGED=$((CHANGED + 1))
}

migrate_dir() {
    local dir="$1"
    shift
    local -a transforms=("$@")

    while IFS= read -r -d '' file; do
        migrate_file "$file" "${transforms[@]}"
    done < <(find "$dir" -type f \( -name "*.yml" -o -name "*.yml.j2" \) -print0)
}

# ─── migrations ───────────────────────────────────────────────────────────────

echo "rhis-builder variable migration"
echo "apply=${APPLY}"
echo ""

# ── Basevars file migrations ───────────────────────────────────────────────────

if [[ -n "$BASEVARS_FILE" ]]; then
    echo "=== Basevars: $BASEVARS_FILE ==="

    # global_domain_name → basevars_global_domain_name (2026-05-28)
    echo "--- global_domain_name → basevars_global_domain_name"
    migrate_file "$BASEVARS_FILE" \
        's/^global_domain_name:/basevars_global_domain_name:/'

    echo ""
fi

# ── Deployed inventory directory migrations ────────────────────────────────────

if [[ -n "$INVENTORY_DIR" ]]; then
    if [[ ! -d "$INVENTORY_DIR" ]]; then
        echo "ERROR: inventory directory not found: $INVENTORY_DIR"
        exit 1
    fi

    echo "=== Inventory directory: $INVENTORY_DIR ==="

    # async_timeout → satellite_async_timeout (2026-05-26)
    # async_delay   → satellite_async_delay   (2026-05-26)
    echo "--- async_timeout/async_delay → satellite_async_timeout/satellite_async_delay"
    for f in \
        "${INVENTORY_DIR}/host_vars/satellite/satellite_pre.yml" \
        "${INVENTORY_DIR}/host_vars/discosatellite/satellite_pre.yml"
    do
        migrate_file "$f" \
            's/^async_timeout:/satellite_async_timeout:/' \
            's/^async_delay:/satellite_async_delay:/'
    done

    # split_global_domain_name → split_basevars_global_domain_name (2026-05-28)
    echo "--- split_global_domain_name → split_basevars_global_domain_name"
    migrate_dir "$INVENTORY_DIR" \
        's/split_global_domain_name/split_basevars_global_domain_name/g'

    # _global_domain_name → _runtime_global_domain_name (2026-05-28)
    # Note: the alias in group_vars/all/main.yml keeps existing deployments working.
    # This migration cleans up after re-rendering. Safe to skip if regenerating from
    # inventory_template.
    echo "--- _global_domain_name → _runtime_global_domain_name"
    migrate_dir "$INVENTORY_DIR" \
        's/_global_domain_name/_runtime_global_domain_name/g'

    echo ""
fi

# ─── summary ──────────────────────────────────────────────────────────────────

echo "=== Summary ==="
if [[ "$CHANGED" -eq 0 ]]; then
    echo "No changes required — all files are up to date."
elif $APPLY; then
    echo "$CHANGED file(s) updated in place."
else
    echo "$CHANGED file(s) would change. Review .new files then re-run with --apply."
    echo "To clean up .new files without applying: find . -name '*.new' -delete"
fi
