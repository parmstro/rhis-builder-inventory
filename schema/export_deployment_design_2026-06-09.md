# export_deployment.sh — Design Document
**Date:** 2026-06-09
**Branch:** disconnected_satellite
**Status:** Approved design — ready to implement

---

## Context

Item 3 of the adversarial analysis (transfer bundle completeness) revealed two gaps in the
lowside export workflow:

1. **Container image save (Step 7) is broken** — `export_disconnected.yml` delegates
   `podman save` to a `provisioner_host` inventory group that doesn't exist in the satellite
   inventory, causing the task to be silently skipped. Root cause: chicken-and-egg — the
   ansible-playbook runs inside the provisioner container and cannot reach back to the host
   podman daemon that owns the image.

2. **No outer wrapper script** — the operator must manually launch an interactive container
   shell and call `build_sat_disconnected_export.sh` and `copy_rhis_to_transfer_media.sh`
   separately. The `update_transfer_bundle.sh` script already demonstrates the correct
   pattern (non-interactive `podman run -c "..."`), but no equivalent exists for the export.

3. **`configure_export.sh` is redundant** — the `content_export_prepare_drv` role in
   `export_disconnected.yml` already handles drive discovery, validation, mount, SELinux
   context, and ownership via Ansible. `configure_export.sh` was written first and
   superseded. It remains useful as an optional manual pre-check (`--dry-run`) but must
   not be a required step.

---

## Design Decisions

### Decision 1 — Container image save: Option A (host-side, before container launch)

`podman save` runs in the outer wrapper script (`export_deployment.sh`) on the provisioner
host BEFORE launching the container. The saved tar is mounted into the container as a
volume. The playbook's Step 7 copies it from the local mount path to the satellite bundle
directory — identical pattern to Step 6 (inventory archive).

**`export_disconnected.yml` Step 7 change:**
```yaml
# Remove: delegate_to: provisioner_host, ignore_errors, ignore_unreachable
# Replace with the Step 6 two-step pattern:

- name: "Step 7 — Copy container image to satellite bundle"
  when: provisioner_image_tar is defined and provisioner_image_tar | length > 0
  ansible.builtin.copy:
    src: "{{ provisioner_image_tar }}"
    dest: "{{ _bundle_dir }}/container/rhis-provisioner_{{ _bundle_timestamp }}.tar"
    mode: "0644"

- name: "Step 7 — Warn if container image tar not provided"
  when: provisioner_image_tar is not defined or provisioner_image_tar | length == 0
  ansible.builtin.debug:
    msg:
      - "WARNING: provisioner_image_tar not set — container image not included in bundle."
      - "Save manually: podman save <image> -o <bundle>/container/rhis-provisioner.tar"
```

`provisioner_image_tar` is passed as an Ansible extra-var by `build_sat_disconnected_export.sh`.

**`build_sat_disconnected_export.sh` change:**
Add `--image-tar <path>` argument. When present, pass to ansible-playbook as
`--extra-vars "provisioner_image_tar=<path>"`.

### Decision 2 — `basevars_downstream_disconnected_deployment` becomes a list

**Rationale:** One lowside satellite can serve multiple highside deployments. The variable
should be a list of domain names, not a single string. There are no existing deployments,
so backward compatibility is not a concern.

`basevars_upstream_connected_deployment` (symmetric highside variable) is also changed to
a list for symmetry. It currently has no template usages — zero-cost change.

### Decision 3 — `destination_server` uses runtime extra-var with list fallback

The `content_exports.yml` `destination_server` template changes from:
```yaml
destination_server: "satellite1.{{ basevars_downstream_disconnected_deployment | default('') }}"
```
to:
```yaml
destination_server: "satellite1.{{ active_downstream_deployment | default(basevars_downstream_disconnected_deployment | first | default('')) }}"
```

`active_downstream_deployment` is set by `export_deployment.sh` at runtime via
`--extra-vars`. Falls back to `| first` for manual playbook runs without the script.

### Decision 4 — `export_deployment.sh` script design

**Location:** `rhis-builder-inventory/` (alongside `update_transfer_bundle.sh`)

**Interface:**
```bash
export_deployment.sh \
    -b | --basevars-file <file>   # e.g. example.ca_inventory_basevars.yml (required)
    [--highside <domain>]         # required if list has >1 entry; auto-selected if list has 1
    [--media-path <path>]         # transfer drive mount on provisioner (default: /mnt/rhis_transfer)
    [--ansible-ver <2.4|2.5>]    # container version (default: 2.5)
    [--dry-run]                   # validate and report only; do not export
    [--yes]                       # skip confirmation prompt
    [-h | --help]
```

**Validation sequence (fail fast):**
1. Basevars file readable
2. Parse `basevars_global_domain_name` → `deployments/<lowside>/` exists
3. Parse `basevars_downstream_disconnected_deployment` (list) → validate non-empty
4. If list has 1 item: use it automatically. If >1: require `--highside`.
5. If `--highside` given: confirm it is in the list (fail if not — prevents misdirected export)
6. `deployments/<highside>/` directory exists
7. At least one `host_vars/*/manifests.yml` in highside deployment has `generate: false`
8. At least one `*.zip` in `deployments/<lowside>/files/manifests/`
9. Transfer drive discoverable by `TRANSFER_DRV` label — fail if not found
10. Print mapping summary; prompt for confirmation (skip with `--yes`)

**Confirmation prompt:**
```
Lowside:    example.ca         (satellite1.example.ca)
Highside:   highside.example.ca (satellite1.highside.example.ca)
Drive:      /dev/sdb           TRANSFER_DRV, 2.0 TB available
Manifests:  satellite1.highside.example.ca_manifest.zip

Proceed with export? [y/N]
```

**Export flow:**
```
1. podman save <image> -o /tmp/rhis_provisioner_<timestamp>.tar
2. podman run (non-interactive) with:
     - lowside deployment volumes (inventory, host_vars, group_vars, vault, files, logs, ssh)
     - /tmp/rhis_provisioner_<timestamp>.tar:/tmp/rhis_provisioner_image.tar:z
     - command: build_sat_disconnected_export.sh \
                    --image-tar /tmp/rhis_provisioner_image.tar \
                    --media-path <media_path>
                    (which calls ansible-playbook export_disconnected.yml then
                     copy_rhis_to_transfer_media.sh automatically on success)
3. Report: checklist path, transfer size, vault reminder, next steps
4. Cleanup: remove /tmp/rhis_provisioner_<timestamp>.tar
```

**One-to-many handling:** operator runs `export_deployment.sh` once per highside, each
with its own drive. The `--highside` flag selects the target from the list.

---

## Files to Change

### `basevars_downstream_disconnected_deployment` type change (string → list)

| File | Change |
|---|---|
| `inventory_basevars.yml` | Update comment to "list of domains"; change default example to list syntax |
| `example.ca_inventory_basevars.yml` | `"highside.example.ca"` → list with one item |
| `README.md` | Update example to list syntax |
| `inventory_template/host_vars/satellite/content_exports.yml` | Update `destination_server` expression (Decision 3) |
| `deployments/example.ca/host_vars/satellite1.example.ca/content_exports.yml` | Same |
| `deployments/highside.example.ca/host_vars/satellite1.highside.example.ca/content_exports.yml` | Same |

### Container image save fix

| File | Change |
|---|---|
| `rhis-builder-satellite/export_disconnected.yml` | Replace Step 7 with two-step copy pattern (Decision 1) |
| `rhis-provisioner-container/rhis-provisioner/build_sat_disconnected_export.sh` | Add `--image-tar` argument, pass to playbook as extra-var |

### New file

| File | Description |
|---|---|
| `rhis-builder-inventory/export_deployment.sh` | Outer wrapper script (Decision 4) |

### `configure_export.sh` status

No code change. Add a comment to the script header clarifying it is an optional
pre-check tool, not a required step — the `content_export_prepare_drv` role handles
everything it does automatically during the export playbook run.

---

## Adversarial Analysis Update

Item 3 status changes from **Open** to **Resolved** once the above is implemented:
- Bundle assembly: already implemented in `export_disconnected.yml` (10 steps)
- Container image save: fixed via Option A in `export_deployment.sh`
- Operator steps: reduced from ~7 to 3 (connect drive, run one script, disconnect drive)
- `configure_export.sh` as required step: eliminated

---

## Related Files (read, not modified)

- `rhis-provisioner-container/rhis-provisioner/copy_rhis_to_transfer_media.sh` — Stage 2, called by `build_sat_disconnected_export.sh` after playbook
- `rhis-provisioner-container/rhis-provisioner/validate_import_bundle.sh` — highside pre-import check, no changes needed
- `rhis-builder-satellite/roles/content_export_prepare_drv/` — handles drive mount/unmount in playbook; no changes needed
- `rhis-builder-inventory/run_container.sh` — reference for volume mount pattern
- `rhis-builder-inventory/update_transfer_bundle.sh` — reference for non-interactive `podman run` pattern
