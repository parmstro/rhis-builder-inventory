# Highside Import Workflow — Verified from Code

**Status:** Verified from code 2026-06-10; corrected 2026-06-10 (import path)  
**Related capability:** C10 — Disconnected / Air-Gapped Operation  
**Source of truth:** rhis-builder-satellite `main.yml`, `satellite_disconnected_pre`, `content_imports` roles

---

## Core Principle

The highside is a **greenfield** environment on first deployment. The provisioner, IdM, and
Satellite are not pre-installed. The import script's job is to:

1. Validate the transfer bundle
2. Stage the content to the correct path on the satellite
3. Call `build_sat_primary.sh` — which is identical to a connected build except for the
   variables in the highside inventory

`main.yml` is the full satellite build entry point. The `satellite_disconnected: true` variable
in the highside inventory drives all code-path differences. No separate import playbook exists
or is needed for the initial build.

---

## main.yml Execution Flow (when satellite_disconnected: true)

```
main.yml (hosts: sat_primary)
  │
  ├── satellite_disconnected_pre    [when: satellite_disconnected]
  │     Prepares satellite to install from offline media
  │
  ├── satellite_pre                 [always]
  │     Firewall, SSL, Kerberos (satellite_pre_use_idm: false on highside)
  │
  ├── satellite                     [always]
  │     Runs satellite-installer
  │
  ├── satellite_post                [always]
  │     Foreman-proxy, certificate management
  │
  ├── configure_hammer.yml          [always]
  │
  ├── redhat_manifests              [always — generate: false on highside]
  │     Uploads pre-existing manifest zip (NOT via CDN API)
  │
  ├── subscription_manifests        [always]
  ├── content_credentials           [always]
  ├── custom_products               [always]
  │
  ├── repository_sets               [SKIPPED — when: not satellite_disconnected]
  ├── repositories                  [SKIPPED — when: not satellite_disconnected]
  ├── start_synchronization         [SKIPPED — when: not satellite_disconnected]
  │
  ├── content_imports               [when: satellite_disconnected AND satellite_import_content]
  │     Imports content from transfer bundle into Satellite Library
  │     (this is the long step — hundreds of GB)
  │
  ├── lifecycle_environments        [always]
  ├── sync_plans                    [SKIPPED — when: not satellite_disconnected]
  │
  ├── content_views                 [always]
  │     Publishes AND PROMOTES content views through all LCEs automatically.
  │     No separate promotion step needed after import. This is why host
  │     registration must wait for the FULL main.yml play to complete.
  │
  └── [all remaining roles]         [always — provisioning config, SCAP, etc.]
```

---

## satellite_disconnected_pre Role (verified)

**File:** `rhis-builder-satellite/roles/satellite_disconnected_pre/tasks/main.yml`

Runs BEFORE satellite_pre. Prepares the satellite host for offline installation.

**Key variables:**
| Variable | Purpose |
|---|---|
| `satellite_disconnected_root` | Base directory for ISO staging on satellite (e.g. `/var/media`) |
| `satellite_os_iso_source` | Filename of the RHEL OS ISO (e.g. `rhel9_dvd.iso`) |
| `satellite_install_iso_source` | Filename of the Satellite install ISO |
| `satellite_os_repo_mount` | Mount point for OS ISO (e.g. `{{ satellite_disconnected_root }}/rhel`) |
| `satellite_install_repo_mount` | Mount point for Satellite ISO |
| `satellite_disconnected_iso_prestaged` | **Default: false.** Set true to skip rsync of ISOs |
| `satellite_disconnected_iso_mounted` | **Default: false.** Set true to skip mount tasks |

**Execution sequence:**
1. Unmount existing ISO mount points (idempotency — always safe to re-run)
2. Create `satellite_disconnected_root` directory
3. **Rsync RHEL OS ISO from provisioner → satellite** using `ansible.posix.synchronize`
   (SKIPPED when `satellite_disconnected_iso_prestaged: true`)
4. **Rsync Satellite install ISO from provisioner → satellite**
   (SKIPPED when `satellite_disconnected_iso_prestaged: true`)
5. Mount both ISOs read-only
   (SKIPPED when `satellite_disconnected_iso_mounted: true`)
6. Template OS `.repo` file
7. Assert `RHEL-BaseOS` and `RHEL-AppStream` are present in `dnf repolist`
8. `dnf update` from offline ISO repos
9. Install satellite binaries: `{{ satellite_install_repo_mount }}/install_packages`

**Critical: `ansible.posix.synchronize` pushes FROM the Ansible controller (provisioner container)
TO the satellite.** The ISO source files must be accessible on the provisioner at
`{{ satellite_os_iso_source }}` and `{{ satellite_install_iso_source }}`.

**USB scenario exception:** When the drive is mounted at `/var/lib/pulp/imports` on the satellite
and ISOs are inside the bundle directory on the drive, set:
- `satellite_disconnected_iso_prestaged: true` (skip rsync — ISOs are already on satellite)
- `satellite_disconnected_root: /var/lib/pulp/imports/rhis_transfer_<timestamp>` (bundle dir on drive)
- `satellite_os_iso_source: rhel9_dvd.iso` (filename only — combined with root gives the full path)

---

## content_imports Role (verified)

**Files:**
- `roles/content_imports/tasks/main.yml` — iterates over `content_imports` list
- `roles/content_imports/tasks/ensure_content_import.yml` — validates path, sets permissions + SELinux
- `roles/content_imports/tasks/perform_library_import.yml` — calls `hammer content-import library`

**Variable:** `content_imports` (list, loaded from `host_vars/<satellite>/content_imports.yml`)

```yaml
content_imports:
  - name: "Library"
    type: "library"
    import_path: "/var/lib/pulp/imports/<destination_server>/<timestamp>/<export_id>"
    metadata_file: "/var/lib/pulp/imports/<destination_server>/<timestamp>/<export_id>/metadata.json"
```

**`ensure_content_import.yml` does the following ON THE SATELLITE:**
1. `ansible.builtin.file` with `recurse: true` — creates `import_path` directory if absent,
   sets `owner: pulp, group: pulp, mode: 0770`,
   SELinux: `system_u:object_r:pulpcore_var_lib_t:s0`
2. `ansible.builtin.stat` — asserts `import_path` exists
3. Delegates to `perform_library_import.yml`

**`perform_library_import.yml`:**
Calls `redhat.satellite.content_import_library` with `path: {{ content_import.import_path }}`.
Retries with `until: import_library_result.finished` — this is an async task that can run
for hours on large libraries.

**SELinux is fully handled by `ensure_content_import.yml`.** No separate restorecon step is
needed. The `ansible.builtin.file` with `recurse: true` and explicit `seuser/serole/setype/selevel`
sets the correct context on all files in the import_path tree before the import runs.

---

## Transfer Drive Architecture (verified)

The transfer drive is formatted with label `TRANSFER_DRV`. **The mount path differs by side:**

**Drive on the lowside:**
- Mounted at `/var/lib/pulp/exports` during export (Pulp writes here)
- Pulp writes chunks to `/var/lib/pulp/exports/<dest>/<timestamp>/<id>/`
- Bundle artifacts (ISOs, manifest, ansible_roles, etc.) copied to `/var/lib/pulp/exports/rhis_transfer_<timestamp>/`
- Auto-generated `_content_imports.yml` written to `/var/lib/pulp/exports/<dest>/<timestamp>_content_imports.yml`
- `import_path` in that file reads: `/var/lib/pulp/exports/<dest>/<timestamp>/<id>/`

**Drive on the highside:**
- Mounted at `/var/lib/pulp/imports` — Satellite reads from this path during import
- Chunks at `/var/lib/pulp/imports/<dest>/<timestamp>/<id>/`
- Bundle artifacts at `/var/lib/pulp/imports/rhis_transfer_<timestamp>/`

**Path remapping is required.** The auto-generated `_content_imports.yml` carries the lowside
prefix `/var/lib/pulp/exports/`. When the import script copies it to the deployment
`host_vars/<satellite>/content_imports.yml`, it must substitute:
```
/var/lib/pulp/exports/  →  /var/lib/pulp/imports/
```
This applies to ALL delivery scenarios — the prefix on the drive changes side, so the
`import_path` must always be corrected before `main.yml` runs.

**Drive mounting for USB scenario:** The operator plugs the drive into the satellite baremetal.
The `bundle_delivery` role (USB variant) or a pre-flight Ansible step mounts it at
`/var/lib/pulp/imports` using the existing `content_export_prepare_drv` role with the
mount path overridden:
```yaml
content_export_prepare_drv_mount: "/var/lib/pulp/imports"
```
A dedicated `content_import_prepare_drv` role with this default is the clean long-term solution.

---

## Three Delivery Scenarios

The Pulp content chunks must reach `/var/lib/pulp/imports/` on the highside satellite.
The ISOs must be accessible from the provisioner (controller) for `satellite_disconnected_pre`.
The operator interacts only with the provisioner. Provisioner knows the satellite address from inventory.

In all scenarios the import script performs prefix remapping when copying `_content_imports.yml`:
`/var/lib/pulp/exports/` → `/var/lib/pulp/imports/`.

### Scenario 1 — USB (drive plugged directly into satellite)

Operator plugs drive into satellite baremetal. `bundle_delivery` role mounts it at
`/var/lib/pulp/imports` on the satellite (using `content_export_prepare_drv` with mount
path overridden to `/var/lib/pulp/imports`).

Content chunks: at `/var/lib/pulp/imports/<dest>/<timestamp>/<id>/` once mounted — no copy needed.

ISOs: on the drive at `/var/lib/pulp/imports/rhis_transfer_<timestamp>/`. The provisioner
cannot push ISOs from itself (they're not there). Instead:
- Set `satellite_disconnected_iso_prestaged: true`
- Set `satellite_disconnected_root: /var/lib/pulp/imports/rhis_transfer_<timestamp>`
- `satellite_disconnected_pre` skips rsync, mounts ISOs from drive path on satellite

Script copies `_content_imports.yml` from bundle with prefix remap, then runs `main.yml`.

### Scenario 2 — Virtual disk (operator has hypervisor API access)

Operator (from workstation connected to highside subnet):
1. Creates QCOW2/VMDK image from USB drive contents
2. Uploads to ESX hypervisor storage
3. Attaches image to provisioner VM as `/dev/vdb` (or similar)

`build_sat_disconnected_import.sh` (bash — host level):
- Mounts `/dev/vdb` at `/mnt/rhis_transfer` on provisioner host

Ansible `bundle_delivery` role:
- `ansible.posix.synchronize` push: `/mnt/rhis_transfer/<dest>/` → satellite `/var/lib/pulp/imports/`
- ISOs available at `/mnt/rhis_transfer/rhis_transfer_<timestamp>/` — provisioner pushes to satellite
- `satellite_disconnected_iso_prestaged: false` — provisioner has ISOs and pushes them
- `satellite_disconnected_root`: path on satellite where ISOs land (e.g. `/var/satellite_stage`)

Script copies `_content_imports.yml` from `/mnt/rhis_transfer/` with prefix remap, then runs `main.yml`.
Shell cleanup: unmount `/mnt/rhis_transfer` after completion.

### Scenario 3 — rsync (operator workstation has network path to provisioner)

Operator (from workstation connected to highside subnet, NO path to lowside):
```
rsync -avz --partial /mnt/usb/ ansiblerunner@provisioner.highside.example.ca:/home/ansiblerunner/rhis_import/
```

Ansible `bundle_delivery` role:
- `ansible.posix.synchronize` push: provisioner `/home/ansiblerunner/rhis_import/<dest>/` → satellite `/var/lib/pulp/imports/`
- ISOs at provisioner `/home/ansiblerunner/rhis_import/rhis_transfer_<timestamp>/` — provisioner pushes to satellite
- `satellite_disconnected_iso_prestaged: false` — provisioner has ISOs and pushes them

Script copies `_content_imports.yml` from staging path with prefix remap, then runs `main.yml`.

---

## content_imports Variable Loading

The auto-generated `_content_imports.yml` from the lowside export must be loaded as the
`content_imports` variable for the `content_imports` role to know the `import_path`.

The `_content_imports.yml` file is in the bundle at:
```
/var/lib/pulp/exports/<dest>/<timestamp>_content_imports.yml   (on drive — lowside path)
rhis_transfer_<timestamp>/_content_imports.yml                 (also copied to bundle artifacts dir)
```

**The `import_path` values in `_content_imports.yml` use the lowside prefix `/var/lib/pulp/exports/`.**
The import script must remap to `/var/lib/pulp/imports/` when copying to the deployment inventory:

```bash
sed 's|/var/lib/pulp/exports/|/var/lib/pulp/imports/|g' _content_imports.yml \
  > deployments/<name>/host_vars/<satellite_fqdn>/content_imports.yml
```

**Recommended approach:** The import script performs the prefix substitution and writes the
result directly to `host_vars/<satellite>/content_imports.yml`. This integrates cleanly with
the existing `vars_dir` loading in `main.yml` and leaves a readable record of what was imported.

---

## Day 2 Operations (re-import after initial build)

After the initial build, if new content must be imported (incremental transfer cycle):

1. Stage new bundle to satellite at `/var/lib/pulp/exports/` (same delivery scenarios)
2. Update `content_imports.yml` with new `import_path` from new `_content_imports.yml`
3. Run `main.yml` with `satellite_import_content: true`
   OR run just the `content_imports` + `content_views` roles via tags:
   `--tags tags_content_imports,tags_content_views`

`satellite_import_content: false` skips the slow import step on subsequent full runs when
content has not changed. This is an operator-managed flag.

---

## Operator Checklist Before Running Import Script

- [ ] Transfer drive received, integrity verified (compare manifest SHA256)
- [ ] Vault password received via separate trusted channel (NEVER in the bundle)
- [ ] Highside manifest ZIP obtained from Red Hat Customer Portal (separate allocation)
- [ ] One of: drive plugged in (USB), virtual disk attached to provisioner (virtual_disk),
       bundle rsync'd to provisioner staging path (rsync)
- [ ] `_content_imports.yml` identified in bundle — note the timestamp in the filename
- [ ] For USB: note the `rhis_transfer_<timestamp>` directory name (needed for ISO path vars)
- [ ] Provisioner container image loaded (`podman load`)
- [ ] Vault password file accessible on provisioner

---

## What build_sat_disconnected_import.sh Must Do

The bash wrapper script. All real work is in Ansible.

```
1. Parse args: --deployment, --delivery-method [usb|virtual_disk|rsync],
               method-specific args (--bundle-path, --disk-device, --staging-path)

2. If virtual_disk:
   - mount --disk-device at /mnt/rhis_transfer on PROVISIONER HOST (bash — host level)

3. Copy _content_imports.yml from bundle to deployment host_vars WITH PREFIX REMAP:
   sed 's|/var/lib/pulp/exports/|/var/lib/pulp/imports/|g' \
     <bundle-path>/_content_imports.yml \
     > deployments/<name>/host_vars/<satellite_fqdn>/content_imports.yml

4. Run Ansible bundle_delivery role (inside provisioner container):
   - usb:          mount drive at satellite /var/lib/pulp/imports; validate chunks present
   - virtual_disk: ansible.posix.synchronize /mnt/rhis_transfer/<dest>/ → satellite /var/lib/pulp/imports/
                   also push ISOs from /mnt/rhis_transfer/rhis_transfer_<ts>/ → satellite staging dir
   - rsync:        ansible.posix.synchronize <staging-path>/<dest>/ → satellite /var/lib/pulp/imports/
                   also push ISOs from <staging-path>/rhis_transfer_<ts>/ → satellite staging dir

5. Run main.yml (inside provisioner container) against highside satellite:
   - satellite_disconnected: true (already in inventory)
   - satellite_import_content: true (enables content_imports role)
   - For USB: satellite_disconnected_iso_prestaged: true
              satellite_disconnected_root: /var/lib/pulp/imports/rhis_transfer_<timestamp>
   - For virtual_disk/rsync: satellite_disconnected_iso_prestaged: false
              satellite_disconnected_root: <satellite staging dir where ISOs were pushed>

6. If virtual_disk:
   - umount /mnt/rhis_transfer on PROVISIONER HOST (bash — cleanup)

7. Report: build complete, next steps (host registration, SCAP, etc.)
```

---

## Files Involved

| File | Location | Purpose |
|---|---|---|
| `main.yml` | `rhis-builder-satellite/` | Full satellite build entry point — DO NOT modify |
| `roles/satellite_disconnected_pre/` | `rhis-builder-satellite/` | Offline OS install prep |
| `roles/content_imports/` | `rhis-builder-satellite/` | Pulp import (all logic already there) |
| `content_export_prepare_drv.yml` | deployment `host_vars/<satellite>/` | Drive mount config |
| `content_imports.yml` | deployment `host_vars/<satellite>/` | Updated with `_content_imports.yml` from bundle |
| `build_sat_disconnected_import.sh` | `rhis-provisioner-container/` | **NEW** — bash wrapper |
| `roles/bundle_delivery/` | `rhis-builder-satellite/` | **NEW** — stages bundle to satellite |
