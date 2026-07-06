#!/usr/bin/env python3
# scripts/generate_manifest.py
# Generate rhis_export_manifest.yml from all staged files.
# Called by Stage 4 of export_deployment.yml.
#
# Usage:
#   python3 generate_manifest.py \
#     --staging /path/to/staging \
#     --sat-host satellite1.example.ca \
#     --lowside example.ca \
#     --highside highside.example.ca \
#     --generated 20260705_040909 \
#     --pulp-path /var/lib/pulp/exports/...

import argparse
import hashlib
import os
import sys

parser = argparse.ArgumentParser(description="Generate rhis_export_manifest.yml")
parser.add_argument("--staging", required=True, help="Staging root directory")
parser.add_argument("--sat-host", required=True, help="Source satellite hostname")
parser.add_argument("--lowside", required=True, help="Lowside deployment FQDN")
parser.add_argument("--highside", required=True, help="Highside deployment FQDN")
parser.add_argument("--generated", required=True, help="Generation timestamp (YYYYMMDD_HHMMSS)")
parser.add_argument("--pulp-path", default="", help="Pulp export path on the satellite")
args = parser.parse_args()

# Read version facts written by export_disconnected.yml (Step 4)
version_facts = {}
version_facts_path = os.path.join(args.staging, "_version_facts.yml")
if os.path.exists(version_facts_path):
    with open(version_facts_path) as vf:
        for line in vf:
            line = line.strip()
            if ": " in line:
                k, v = line.split(": ", 1)
                version_facts[k.strip()] = v.strip().strip('"')

_skip = {
    "rhis_export_manifest.yml",
    "transfer_to_drive.sh",
    "transfer_to_drive.yml",
    "transfer_to_drive_vars.yml",
    "_version_facts.yml",
}

entries = []
for root, dirs, fnames in os.walk(args.staging):
    dirs.sort()
    for fname in sorted(fnames):
        fpath = os.path.join(root, fname)
        relpath = os.path.relpath(fpath, args.staging)
        if relpath in _skip:
            continue
        h = hashlib.sha256()
        with open(fpath, "rb") as f:
            for chunk in iter(lambda: f.read(65536), b""):
                h.update(chunk)
        entries.append((relpath, h.hexdigest()))

manifest_path = os.path.join(args.staging, "rhis_export_manifest.yml")
with open(manifest_path, "w") as f:
    f.write(f'source_satellite: "{args.sat_host}"\n')
    f.write(f'lowside_deployment: "{args.lowside}"\n')
    f.write(f'highside_deployment: "{args.highside}"\n')
    f.write(f'generated: "{args.generated}"\n')
    f.write(f'staging_path: "{args.staging}"\n')
    f.write(f'pulp_export_path: "{args.pulp_path}"\n')
    f.write(f'satellite_version: "{version_facts.get("satellite_version", "unknown")}"\n')
    f.write(f'pulpcore_version: "{version_facts.get("pulpcore_version", "unknown")}"\n')
    f.write(f'pulp_rpm_version: "{version_facts.get("pulp_rpm_version", "unknown")}"\n')
    f.write(f'pulp_file_version: "{version_facts.get("pulp_file_version", "unknown")}"\n')
    f.write("files:\n")
    for path, sha in entries:
        f.write(f'  - path: "{path}"\n')
        f.write(f'    sha256: "{sha}"\n')

print(f"Manifest written: {len(entries)} files checksummed")
sys.exit(0)
