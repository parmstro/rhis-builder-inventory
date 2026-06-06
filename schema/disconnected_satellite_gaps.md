# Disconnected Satellite — Implementation Gap Analysis

**Date:** 2026-06-02
**Branch:** disconnected_satellite
**Purpose:** Comprehensive audit of what is implemented vs what is missing for a
confident end-to-end disconnected satellite build and import process.

---

## What Is Already Implemented

| Component | Location | Status | Notes |
|---|---|---|---|
| `satellite_disconnected_pre` role | `rhis-builder-satellite` | ✅ Complete | Copies RHEL + Satellite ISOs, mounts them, creates local repo files, updates system, installs Satellite binaries from DVD |
| `redhat_manifests` — user-provided path | `roles/redhat_manifests/tasks/fetch_manifest.yml` | ✅ Complete | When `generate: false`, copies manifest zip from `files/` directory via `ansible.builtin.copy`. No CDN contact. |
| `satellite_post` disconnected CDN config | `roles/satellite_post/tasks/ensure_configure_custom_cdn.yml` | ✅ Partial | Sets subscription to false; runs `hammer organization configure-cdn --type=export_sync`. Custom CDN URL/SSL config commented out. |
| `content_imports` role | `roles/content_imports/tasks/main.yml` | ✅ Complete | Loops through `content_imports` list, imports each. |
| `satellite_import_content` flag | `main.yml` | ✅ Complete | Allows re-running the full play without re-importing content. |
| `content_exports` role | `roles/content_exports/tasks/` | ✅ Partial | Export tasks exist (library, CV version, repository). Auto-generates `content_imports.yml`. Not yet wired to an orchestration playbook. |
| `satellite_pre` disconnected guards | `roles/satellite_pre/tasks/main.yml` | ✅ Complete | CDN registration, repo enable steps gated with `when: not satellite_disconnected` |

---

## Gaps — Highside Build

### ~~GAP 1: `discosatellite/imported_git_repos.yml` uses `clone: true`~~ RESOLVED 2026-06-02
**File:** `inventory_template/host_vars/discosatellite/imported_git_repos.yml`

**Purpose of this role:** Downloads Red Hat Official "Compliance as Code" Ansible roles
from `https://github.com/RedHatOfficial/` into `/etc/ansible/roles/` on the Satellite
server. The `ensure_import_roles.yml` task then calls the Satellite API to ingest the
roles from that local path so they are available for assignment to hostgroups and policies.

**Mechanism:** The `imported_git_repos` role passes `clone: "{{ gitrepo.clone }}"` to
`ansible.builtin.git`. When `clone: false`, the module verifies/updates an existing local
repo without reaching the remote — correct for air-gap where roles arrive pre-extracted
from the bundle tar as valid git repositories. When `clone: true`, it will attempt to
clone from GitHub if the directory doesn't exist — this fails on an air-gapped highside.
The `ensure_import_roles.yml` step runs normally on both sides — it only calls the
Satellite API with a local path, no GitHub access required.

**Current state:** The discosatellite `imported_git_repos.yml` currently has `clone: true`
on all entries. This is believed to have been fixed with Bryn but the fix may not have
been committed.

**Fix — Part 1 (applied):** Change all `clone: true` → `clone: false` in
`inventory_template/host_vars/discosatellite/imported_git_repos.yml`.

**Fix — Part 2 (NOT YET IMPLEMENTED):** The `imported_git_repos` role does not extract
roles from a bundle tar archive. Without extraction, `/etc/ansible/roles/` will be empty
on the highside and `clone: false` will simply fail silently or error.

The role needs a new disconnected extraction path added to
`roles/imported_git_repos/tasks/main.yml` in `rhis-builder-satellite`:

```yaml
- name: "Extract compliance roles from bundle archive (disconnected)"
  when:
    - satellite_disconnected
    - satellite_roles_bundle_path is defined
  ansible.builtin.unarchive:
    src: "{{ satellite_roles_bundle_path }}"
    dest: "/etc/ansible/roles/"
    remote_src: true
```

Where `satellite_roles_bundle_path` points to the roles tar in the transferred bundle
(e.g. `/home/ansiblerunner/rhis_export/ansible_roles.tar.gz`).

This must run BEFORE the `ansible.builtin.git` check so the repos exist when
`clone: false` is evaluated. The Satellite ingestion step (`ensure_import_roles.yml`)
then runs as normal against the extracted local repos.

`satellite_roles_bundle_path` must be added to `host_vars/discosatellite/` variables.

---

### GAP 2: Custom CDN URL configuration commented out (DEFERRED — INTENTIONAL)
**File:** `roles/satellite_post/tasks/ensure_configure_custom_cdn.yml`

**Status:** Intentionally deferred. The `export_sync` CDN type (configured via hammer) covers
the primary use case. The full custom CDN proxy configuration (URL, SSL CA cert, upstream
org/CV/environment) for Satellite-to-Satellite sync mode is stubbed out and commented.

**Future work:** There should be a `redhat.satellite` collection module for CDN configuration.
If one does not exist, this is a candidate for an upstream contribution to
`foreman-ansible-modules`. There is broader work planned for that collection. When the
module exists, implement the full `custom_cdn` type configuration block.

---

### ~~GAP 3: `satellite_disconnected_pre` ISO handling — no pre-staged/pre-mounted option~~ RESOLVED 2026-06-02
**File:** `roles/satellite_disconnected_pre/tasks/main.yml`

**Impact:** The role unconditionally copies both ISOs from the Ansible controller `files/`
directory and mounts them. There is no way to tell the role that:
- The ISOs are already at `satellite_disconnected_root` (pre-staged via transfer media) → skip the copy
- The ISOs are already mounted (e.g. from a persistent mount after a failed run) → skip the mount

This forces a full re-copy on every run even when ISOs are already in place, which is
slow (`ansible.builtin.copy` base64-encodes large files through the SSH connection).

**Fix:** Add three new variables with defaults that preserve current behaviour:

```yaml
# In host_vars/discosatellite/satellite_pre.yml or similar
satellite_disconnected_iso_prestaged: false   # ISOs already at satellite_disconnected_root
satellite_disconnected_iso_mounted: false     # ISOs already mounted at their mount paths
```

In `satellite_disconnected_pre/tasks/main.yml`:
```yaml
- name: "Copy the OS iso"
  when: not satellite_disconnected_iso_prestaged
  ansible.posix.synchronize:         # Use synchronize instead of copy for large files
    src: "{{ satellite_os_iso_source }}"
    dest: "{{ satellite_disconnected_root }}/{{ satellite_os_iso_source }}"
    delegate_to: "{{ inventory_hostname }}"

- name: "Mount the OS source"
  when: not satellite_disconnected_iso_mounted
  ansible.posix.mount: ...
```

Using `ansible.posix.synchronize` instead of `ansible.builtin.copy` also dramatically
improves transfer speed for large ISOs on subsequent runs (rsync only sends deltas).

---

## Gaps — Lowside Export

### GAP 4: No export orchestration playbook or script (HIGH)
**Status:** `content_exports` role exists and works. There is NO playbook that drives the
full bundle assembly, and NO helper script (`build_sat_disconnected_export.sh`).

**What's needed:**
1. `export_disconnected.yml` playbook in `rhis-builder-satellite`
2. `build_sat_disconnected_export.sh` helper script in `rhis-provisioner-container`

The playbook must orchestrate in order:
1. Run `content_exports` role (Library export → `/var/lib/pulp/exports/`)
2. Create bundle staging directory (`/home/ansiblerunner/rhis_export/<timestamp>/`)
3. Copy/symlink export chunks to staging directory
4. Tar compliance-as-code roles from `/etc/ansible/roles/` and `/etc/ansible/playbooks/`
5. Copy Foreman discovery images from TFTP directory
6. Tar the entire inventory directory
7. `podman save` the rhis-provisioner container image
8. Copy highside manifests from `files/manifests/` to staging directory
9. Run `generate_content_imports_file.yml` (already exists, needs wiring)
10. Generate `rhis_disconnected_manifest.yml` (checksums, versions, git SHAs — not yet implemented)
11. Output the pre-export checklist Markdown with ISO warning (not yet implemented)

---

### ~~GAP 5: `generate_content_imports_file.yml` has a broken task~~ RESOLVED 2026-06-02
**File:** `roles/content_exports/tasks/generate_content_imports_file.yml`

**Line ~38:** Uses `ansible.builtin.fact` which is not a valid Ansible module.
Should be `ansible.builtin.set_fact`.

**Impact:** The `generation_datetime` fact is never set, which may cause the
`content_imports.yml` output file to have an incorrect or missing timestamp in the filename.

**Fix:** Change `ansible.builtin.fact` to `ansible.builtin.set_fact`.

---

### GAP 6: `rhis_disconnected_manifest.yml` not implemented (HIGH)
**Status:** No task or role generates a bundle manifest file.

**What's needed:** A final task in the export playbook that writes
`rhis_disconnected_manifest.yml` containing:
- SHA256 checksums of all export chunks and bundle artifacts
- Satellite export history ID and content view version
- Git SHAs of all compliance-as-code roles at export time
- Export timestamp and lowside satellite FQDN
- List of highside manifest ZIPs and their target hostnames
- Satellite and RHEL versions

Used by the highside import process to validate bundle integrity before beginning import.

---

### GAP 7: Pre-export checklist not implemented (MEDIUM)
**Status:** Not yet implemented.

**What's needed:** A pre-check task list that runs before the export and writes a
Markdown stepwise checklist to the bundle staging directory. See `schema/TODO.md` —
**Disconnected Export Helper Script** for the full specification including the check
items table and the auto-generated `content_imports.yml` output.

---

## Gaps — Highside Import

### GAP 8: No import orchestration script (HIGH)
**Status:** The `content_imports` role works. There is NO helper script
(`build_sat_disconnected_import.sh`) to drive the highside import sequence.

**What's needed:** Script that:
1. Validates `rhis_disconnected_manifest.yml` checksums before starting
2. Stages bundle artifacts to the correct highside paths
3. Calls `main.yml` with `satellite_disconnected: true` and `satellite_import_content: true`
4. Provides clear output on completion with next steps

---

### GAP 9: Content view promotion after import (MEDIUM)
**Status:** After `content_imports`, the imported content is in Library but NOT promoted
through lifecycle environments (Development → Qualification → Staging → Production).

**Impact:** Activation keys referencing non-Library environments will fail until promotion
is complete.

**Fix:** The `content_views` role runs unconditionally in `main.yml` AFTER the content
import and handles publication and promotion. This is already correct — just needs
to be documented clearly in the import sequence documentation.

---

### GAP 10: Sync plans on the highside (LOW)
**Status:** Sync plans are skipped (`when: not satellite_disconnected`) — correct behaviour.
However, the highside satellite will show sync plans as configured in the inventory
if the `sync_plans` role ever runs without the guard. The inventory
`host_vars/discosatellite/sync_plan_product_map.yml` should be empty or absent for
disconnected satellites.

**Fix:** Ensure `host_vars/discosatellite/` does not define `product_plans` entries,
or set `satellite_disconnected: true` in `host_vars/discosatellite/main.yml` so the
guard in `main.yml` prevents sync plan configuration.

---

## Summary — Priority Order

| Priority | Gap | Effort |
|---|---|---|
| HIGH | GAP 4 — No export orchestration playbook/script | Large |
| HIGH | GAP 6 — rhis_disconnected_manifest.yml not implemented | Medium |
| HIGH | GAP 8 — No import orchestration script | Medium |
| HIGH | GAP 1 — imported_git_repos not guarded for air-gap | Small |
| MEDIUM | GAP 5 — generate_content_imports_file.yml broken task | Trivial |
| MEDIUM | GAP 2 — Custom CDN URL configuration commented out | Medium |
| MEDIUM | GAP 7 — Pre-export checklist not implemented | Medium |
| MEDIUM | GAP 9 — Document CV promotion after import | Small |
| LOW | GAP 3 — ISO transfer performance | Small |
| LOW | GAP 10 — Sync plan inventory hygiene | Trivial |
