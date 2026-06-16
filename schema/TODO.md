### Schema TODO list

#### rhis-builder-kvm — Network and Storage Roles (WIP)

`kvm_host` (base KVM node configuration, IdM and Satellite integration) is sound.
`kvm_images` is sound.

The following roles are work in progress — network and storage provisioning:
- `kvm_networks` — WIP
- `kvm_pools` — WIP
- `kvm_volumes` — WIP

Do not use kvm_networks, kvm_pools, or kvm_volumes in production until complete.

---

#### Satellite Performance Tuning — Apply After Export Completes

Baseline metrics collected during 2026-06-07 full library export (1.27 TB).
Apply these changes after the export finishes and validate against next export.

**Current state:** 62 GB RAM, 19 GB in use (30%). PostgreSQL shared_buffers=16 GB (good).
Pulp task workers=4 (undersized). SYNC_MAX_IN_FLIGHT_MB=5000 (default, conservative).

**Changes to apply via satellite-installer:**
```bash
sudo satellite-installer \
  --foreman-proxy-content-pulpcore-worker-count=8
```

**Changes via /etc/foreman-installer/custom-hiera.yaml (PostgreSQL):**
```yaml
postgresql::server::config_entries:
  maintenance_work_mem:
    value: '2000MB'
  effective_cache_size:
    value: '48GB'
  max_wal_size:
    value: '4GB'
```

**Changes via /etc/pulp/settings.py (requires satellite-installer to persist):**
```
SYNC_MAX_IN_FLIGHT_MB = 20000
```

**Important:** Red Hat caps Pulp workers at 8 regardless of CPU count (I/O bottleneck risk).
Test at 6 first if unsure, then 8. Monitor `iostat` during export to confirm I/O
is not saturated (util <90%, await <50ms).

**Baseline metrics log:** `deployments/example.ca/logs/export_perf_baseline.log`

---

#### Disconnected Import Workflow — Known Bugs to Fix

The customer has used the import workflow for manually assembled content. Review
`export_disconnected.yml` / `content_imports` role for the following issues:

**1. Role import on highside — skip clone, use bundle source**
The `imported_git_repos` role currently skips role cloning if `satellite_disconnected`
is true and `satellite_roles_source_path` is defined. This is the correct behaviour —
on the highside, roles come from the bundle's `ansible_roles/` directory via
`ansible.posix.synchronize`, not from GitHub. Verify this path is correctly
wired in the highside satellite build.

**2. Discovery images not installed on highside**
The bundle includes discovery images in `discovery_images/` (copied in Step 4).
On the highside Satellite, the discovery plugin tries to pull images from the internet
during satellite-installer and fails in disconnected environments.
Fix: The discovery images must be pre-staged from the bundle (or from the Satellite
DVD ISO) BEFORE satellite-installer runs the discovery configuration.
The `satellite_disconnected_pre` role or a new pre-task should copy the discovery
images to `/var/lib/tftpboot/boot/` on the highside before the installer runs.

**3. Discovery image source URL — serve from provisioner via nginx**
Rather than pre-staging discovery images on the satellite, configure
`satellite-installer` to pull from a local nginx server running on the provisioner
during the install. The bundle already carries the discovery images in
`discovery_images/`. The provisioner starts nginx serving that directory, passes
`--foreman-proxy-plugin-discovery-source-url http://provisioner.<domain>:8080/`
to satellite-installer, and stops nginx when the install completes.

This eliminates the internet dependency cleanly and doesn't require manual file
staging. The provisioner container could include nginx, or it runs on the host.
The satellite-installer parameter name needs to be confirmed — check
`satellite-installer --help | grep discovery` on the highside.

All three items need to be addressed in `rhis-builder-satellite` before the
disconnected import workflow is considered complete.

---

#### SOE Configuration Consistency Validation — Prevent Cross-File Drift

Small inconsistencies between SOE-related files kill long builds late in the run.
When a new RHEL version or product is added, ALL of the following must be updated consistently:

| File | What to check |
|---|---|
| `repository_sets.yml` | Repository set enabled for the new version |
| `repositories.yml` | Specific repos defined and enabled |
| `content_views.yml` | CV includes the new repos |
| `activation_keys.yml` | Content overrides reference only repos that exist in the org |
| `hostgroups.yml` | Hostgroup references correct CV, activation key, OS |
| `operating_systems.yml` | OS definition exists for the new version |

**Example failure (2026-06-06):** RHEL 10 activation keys referenced
`satellite-6-client-2-for-rhel-10-x86_64-rpms` which was not synced to Satellite.
Build failed at activation_keys role after 5+ hours. Fix: comment out the override
until the repo is added to `repositories.yml` and synced.

**Proposed practice:** Before any long build, do a quick cross-file consistency check
for any new RHEL version or product added since the last successful build. Specifically:
every content label in `activation_keys.yml` content_overrides must correspond to an
enabled, synced repository in `repositories.yml`.

**Future:** Consider a pre-build validation playbook or script that checks this
automatically — similar to the preflight check concept in C10 (disconnected export).

---

#### Variable Scoping Cleanup — Steady Practice During Feature Verification

Variables across rhis-builder projects were declared where first used rather than being
methodically scoped. This is not blocking, but creates hidden cross-role dependencies and
lint noise. Clean up incrementally — do not do a big-bang refactor.

**Convention:**
- Operator-tunable per deployment → `group_vars/` in rhis-builder-inventory
- Cross-role shared defaults → `group_vars/sat_primary/` (or equivalent) in inventory
- Role-specific behaviour → `roles/<role>/defaults/main.yml` with role prefix
- Top-level RHIS settings → `group_vars/all/`

**When to clean up:** When verifying a feature, move any variables you touch to the
correct location. The `var-naming[no-role-prefix]` warnings in ansible-lint are your guide.

**Lint config status:**
- All repos have `.ansible-lint` with `var-naming[no-role-prefix]` in `warn_list`
- `rhis-builder-satellite` — deferred, most complex, handle during satellite feature verification
- Canonical template: `schema/ansible_lint_standard.yml`

---

#### Disconnected Lab Environment — Prerequisites Before Testing C10

Before testing the disconnected satellite workflow (C10), a proper isolated lab environment
must be configured. The current `discosatellite1.example.ca` (no gateway, but reachable from
lowside) is adequate for proving the import and configuration plays, but does not fully
replicate a production air-gap.

**Lab topology (3 chassis, OPNsense router):**

| Segment | Chassis | Domain | Purpose | Outbound routing |
|---|---|---|---|---|
| Production demo | Chassis 1 | TBD | Always-on demonstration of all RHIS tools and pathways | Full internet |
| Development lowside | Chassis 2 | `example.ca` | Active development, current builds | Full internet |
| Development highside | Chassis 3 | TBD (e.g. `disconnected.local`) | Air-gapped disconnected environment | None — inbound only from lowside |

Network isolation is managed at the OPNsense router — no gateway configured on the highside
segment, routing policy drops all outbound from highside. Lowside provisioner can reach
highside hosts inbound. Nothing on the highside can reach CDN, external DNS, or internet.

**Naming TBD:** The highside domain name (`disconnected.local` or similar) needs to be
decided before building the highside inventory. Should reflect its role clearly.

**This is a prerequisite for:**
- Full end-to-end disconnected workflow testing
- Proving the provisioner container transfer (podman save → transfer → podman load) works
- Proving the export bundle is truly self-contained (no implicit CDN dependencies)

**Work to complete before testing:**
- [ ] Choose a domain name for the highside segment
- [ ] Configure OPNsense — highside segment: no outbound route, inbound from lowside permitted
- [ ] Verify the lowside provisioner can reach highside hosts (test SSH)
- [ ] Verify highside cannot reach CDN or external resources (test from highside host)
- [ ] Build highside inventory in rhis-builder-inventory (new deployment under new domain)
- [ ] Include provisioner container image in the export bundle (see C10 container image placeholder)
- [ ] Document the final lab topology in `schema/disconnected_satellite_workflow.md`

---

#### Build script for Satellite Primary

To build the Satellite Primary (connected or disconnected deployment), inside the provisioner container run:

```bash
/rhis/rhis-builder-satellite/build_sat_primary.sh
```

**Action required:** Rebuild and push the provisioner container to pick up the rename from `build_sat_primary_connected.sh`.

---

#### RHEL 9.8 Kickstart Repos — aadsshlogin CDN Duplicate Content Bug (NOT resolved as of 2026-06-04)

`aadsshlogin` appears with duplicate `location_href` entries across all 9.8 kickstart repos on the Red Hat CDN.
Every version of the package (39 entries confirmed in Pulp DB) has two content unit records with identical
`(name, epoch, version, release, arch, location_href)`, causing Pulp to reject content view publish with:

> `Cannot create repository version. More than one rpm.package content with the duplicate values for name, epoch, version, release, arch, location_href.`

**Affected repos:** `AppStream Kickstart 9.8` and `BaseOS Kickstart 9.8` for both x86_64 and aarch64.
**Status:** Both repo sets remain commented out in `content_views.yml` for SOE9 and SOE9_aarch64.
The repos themselves remain defined in `repositories.yml` and sync without issue — only CV publish fails.

**To re-enable:** Verify the duplicate is gone by running on the satellite:
```sql
SELECT name, epoch, version, release, arch, location_href, COUNT(*)
FROM rpm_package WHERE name = 'aadsshlogin'
GROUP BY name, epoch, version, release, arch, location_href HAVING COUNT(*) > 1;
```
When this returns zero rows after a fresh sync, uncomment the 9.8 kickstart entries in `content_views.yml`.

**Alternative approach — exclude filter on the CV (untested):**

Rather than excluding the entire 9.8 kickstart repos, a CV RPM exclude filter for `aadsshlogin`
may allow the repos to be included while preventing the duplicate from triggering the Pulp error.
This depends on whether Pulp applies CV filters *before* the duplicate check during publication.
If it does, the duplicate is never added and the publish succeeds. If Pulp creates the merged
repo first (hitting the duplicate) and then applies filters, this approach will not work.

```
hypothesis:        A CV exclude filter on aadsshlogin allows 9.8 kickstart repos to be
                   included in SOE9 without triggering the Pulp duplicate content error
workflow_type:     mutating
test_criteria:     SOE9 CV publish completes with failed=0 with 9.8 kickstart repos
                   re-enabled AND an rpm exclude filter for aadsshlogin* applied
evidence_shape:    play-recap
evidence:          —
residual_risk:     If it fails, revert by re-commenting the 9.8 kickstart repos.
                   aadsshlogin will be absent from kickstart media but remains
                   available from the streaming AppStream RPMs 9 repo.
last_verified:     —
```

To implement: add an exclude filter entry to the SOE9 and SOE9_aarch64 filter lists
in `content_views.yml` before re-enabling the 9.8 kickstart repos.

**Isolated test plan (preferred — no full rebuild required):**

The 9.8 kickstart repos are already enabled in `repositories.yml`, synced to Satellite,
and working. Content views and hostgroups reference 9.7 kickstart and are unaffected.
This allows the CV publish hypothesis to be tested independently without touching
production builds or requiring a full satellite rebuild.

Create a disposable test CV directly in Satellite (hammer or web UI — no inventory
template changes needed). Run publish only. Iterate. Document results. Touch templates
only once a confirmed approach exists.

Run the following three scenarios in order — each answers a specific question:

| Scenario | CV contents | Filter | Expected | Question answered |
|---|---|---|---|---|
| 1 | AppStream/BaseOS Kickstart 9.8 + AppStream/BaseOS RPMs 9 | none | FAIL | Confirms bug still present post-sync (control case) |
| 2 | AppStream/BaseOS Kickstart 9.8 + AppStream/BaseOS RPMs 9 | rpm exclude `aadsshlogin*` | unknown | Does the exclude filter prevent the Pulp duplicate error? |
| 3 | AppStream/BaseOS Kickstart 9.8 only (no streaming repos) | none | unknown | Is the duplicate cross-repo only, or internal to the kickstart repos? |

Run scenario 1 first. If it passes (bug resolved by CDN), skip 2 and 3 and go straight
to re-enabling in templates. If it fails, run 2 and 3.

Record results here when complete:

| Scenario | Date | Result | Notes |
|---|---|---|---|
| 1 | — | — | — |
| 2 | — | — | — |
| 3 | — | — | — |

---

#### Add `Red Hat Enterprise Linux Bootc Containers` to repositories.yml

The custom product `Red Hat Enterprise Linux Bootc Containers` (formerly `rhel9_containers`, label: `rh_rhel9_bootc_containers`) is defined in `custom_products.yml` with a Docker content repository (`rhel9/rhel-bootc` from `registry.redhat.io`) but has no corresponding entry in `repositories.yml`. An entry should be added when the repositories file is next reorganized or when the product is activated for use.

---

#### Rename global parameter `host_packages` → `additional-packages`

In `inventory_template/host_vars/satellite/global_parameters.yml.j2` line 102, the global parameter `host_packages` should be renamed to `additional-packages` to match the expected parameter name used by downstream consumers (confirmed with Bryn).

**Action:** Update the `name:` field from `"host_packages"` to `"additional-packages"` in `global_parameters.yml.j2`. Rebuild inventory and re-run the `global_parameters` role to apply the rename in Satellite. Verify downstream consumers (kickstart snippets, host build templates) reference the correct name.

---

#### Disconnected Export Helper Script — Checklist, Auto-generated Import Config, and Bundle Manifest

**Design principles:**
- No interactive prompts — never block the workflow
- Default run produces documentation artifacts only (safe, repeatable)
- Export run produces the bundle AND all associated configuration artifacts
- Bundle is self-describing and self-validating via a manifest file

**Script interface:**
```bash
./build_sat_disconnected_export.sh [options]
    # Default (no --export flag): generates checklist + import config + validates only
    --export               Actually run the content export and assemble the bundle
    --export-path <path>   Root path for the export bundle (default: /home/ansiblerunner/rhis_export/)
    -u | --sshuser         SSH user (default: ansiblerunner)
    -i | --inventory       Alternate inventory path
    -h | --help
```

**Output 1 — Pre-export checklist (Markdown, always generated):**

Written to `<export-path>/RHIS_Export_Checklist_<timestamp>.md`. A stepwise process
document the operator follows before and after transfer. Sections:

1. Pre-export validation results (PASS/WARN/FAIL per item — see table below)
2. What is included in this bundle (generated list of artifacts)
3. What the operator must source separately (ISOs, vault password)
4. Highside import sequence (step-by-step)
5. Post-import validation steps

| Check | What to verify | Severity |
|---|---|---|
| Highside manifests | `files/manifests/*.zip` — at least one present | FAIL |
| Manifest count | ZIPs match expected highside satellite count | WARN |
| Library CV published | Latest version in Published state in Satellite | FAIL |
| Transfer drive mounted | `/var/lib/pulp/exports/` is a mount point (`mountpoint -q /var/lib/pulp/exports`) | FAIL |
| Transfer drive label | Mounted device has label `TRANSFER_DRV` (`blkid` or `/proc/mounts`) | WARN |
| Transfer drive space | Available space on `/var/lib/pulp/exports/` ≥ current `/var/lib/pulp` used size | FAIL |
| Transfer drive SELinux | Mount context is `pulpcore_var_lib_t` (`ls -dZ /var/lib/pulp/exports`) | FAIL |
| Transfer drive write access | `pulp` user can write to `/var/lib/pulp/exports/` | FAIL |
| Pulp exports path ownership | `/var/lib/pulp/exports/` owned by `pulp:pulp` | FAIL |
| Disk space (fallback) | If no transfer drive, `/var/lib/pulp/exports/` has ≥ current `/var/lib/pulp` used size free | FAIL |
| rhis-provisioner container | Container image present locally (`podman images`) | FAIL |
| Ansible roles | `/etc/ansible/roles/` exists and non-empty | WARN |
| Inventory directory | Inventory path accessible and non-empty | FAIL |
| SCAP tailoring files | `files/ssg-rhel*-ds-tailoring.xml` present | WARN |
| Content credentials | At least one credential configured in Satellite | WARN |
| Foreman discovery image | Discovery image present in TFTP directory | WARN |
| Vault password | NOTE: Vault password must be communicated via separate trusted channel (not verifiable — documented as a required manual step) | NOTE |

**Transfer drive mount procedure** (run on the Satellite before export):

The transfer drive should be formatted ext4 and labelled `TRANSFER_DRV` before use:
```bash
# One-time drive preparation (on any Linux system)
sudo mkfs.ext4 -L TRANSFER_DRV /dev/<device>
```

To mount on the Satellite:
```bash
# Get the drive UUID
sudo blkid -L TRANSFER_DRV
# or: sudo blkid /dev/<device>

# Add to /etc/fstab using UUID (substitue the actual UUID from blkid)
echo 'UUID=<drive-uuid> /var/lib/pulp/exports ext4 defaults,fscontext=system_u:object_r:pulpcore_var_lib_t:s0 0 2' | sudo tee -a /etc/fstab

# Mount
sudo mount /var/lib/pulp/exports

# Fix ownership and permissions
sudo chown pulp:pulp /var/lib/pulp/exports
sudo chmod 750 /var/lib/pulp/exports

# Verify SELinux context and write access
ls -dZ /var/lib/pulp/exports
sudo -u pulp touch /var/lib/pulp/exports/.write_test && sudo rm /var/lib/pulp/exports/.write_test
```

**Why `context=` not `fscontext=`:** On a fresh ext4 transfer drive, the root directory has
`unlabeled_t` stored in its xattr. `fscontext=` only sets the default for files without an
existing xattr label — it does not override `unlabeled_t`. The result is the drive root shows
`unlabeled_t` and Pulp cannot write to it. `context=` forces the context on ALL files regardless
of xattr, which is correct for a drive used exclusively for export content. Per-file SELinux
labels are not needed on the transfer drive.

**Space check logic:** Before exporting, verify available space on the transfer drive is at
least as large as the current used space under `/var/lib/pulp/`. A full Library export
produces chunks roughly equal in size to the stored content. The transfer drive must have
capacity for the full export in a single operation.

**Output 2 — Auto-generated content_imports.yml (always generated):**

Written to `<export-path>/content_imports.yml`. Pre-populated with the correct parameters
derived from the export: content view name, version, organization, chunk paths, destination server.
The highside operator drops this file into their inventory `host_vars/discosatellite/` and runs
the import playbook without needing to manually configure the import parameters.

**Output 3 — rhis_disconnected_manifest.yml (generated as final step of content_export role):**

Written to `<export-path>/rhis_disconnected_manifest.yml` after all artifacts are assembled.
This file inventories everything in the bundle:
- SHA256 checksums of all export chunks
- SHA256 checksums of all other bundle artifacts (container tar, roles tar, inventory tar)
- Satellite export history ID and content view version
- Git SHAs of compliance-as-code roles at time of export
- Export timestamp and lowside satellite FQDN
- List of highside manifest ZIPs included and their target satellite hostnames
- Satellite and RHEL versions

On the highside, the import playbook validates the manifest before beginning import,
ensuring bundle integrity after transfer.

**Highside manifest file convention:**
Copy highside subscription manifest ZIPs to `inventory_template/files/manifests/` before running
the export. They are included in the inventory tar automatically.
Naming: `<hostname>_manifest.zip` — e.g. `discosatellite1_manifest.zip`.

**Scope:** New `build_sat_disconnected_export.sh` in `rhis-provisioner-container` +
pre-check and manifest tasks in the disconnected export playbook in `rhis-builder-satellite`.

---

#### ISO Warning Notice in Disconnected Export Completion Output

When the disconnected export playbook completes, display a prominent warning reminding the operator which ISOs and installation media must be sourced and transferred separately. ISOs are not included in the export bundle — they must be obtained through the customer's Red Hat entitlements or existing media.

**Implementation:** Add a final `ansible.builtin.debug` task to the disconnected export playbook with a multi-line message similar to the satellite_final completion message.

**Proposed message content:**
```
IMPORTANT: The following installation media must be transferred separately.
They are NOT included in this export bundle:

  Required:
    - RHEL 9.x BaseOS DVD ISO  (for bare-metal provisioning of highside hosts)
    - Red Hat Satellite 6.18 (or later) installer ISO

  If applicable to your deployment:
    - Any additional RHEL minor version ISOs required by your hostgroup kickstart configuration
    - Oracle Linux, CentOS, or other OS media for convert2rhel source systems

  Note: AAP installation files (RPMs and setup bundle) are included in the
  Library export and are available via Satellite after import. No separate
  AAP ISO is required.

  Note: Installation media should be registered as Satellite Installation
  Media objects and associated with the appropriate Operating System definitions
  on the highside satellite after import.
```

**Scope:** Disconnected export playbook final task in `rhis-builder-satellite`.

---

#### Container Images for Highside Managed Services — Disconnected Transfer

When the highside environment deploys containerized workloads (quadlets, edge containers, internal registries), those images need to cross the air gap as part of the transfer bundle alongside the Satellite content export. Currently this is a placeholder — the specific images required depend on the customer workload definition.

**Placeholder items to resolve:**
- Identify which container images are required for each RHIS service role on the highside (quadlet services, AAP EE images, etc.)
- Add `podman save` calls for each required image to the disconnected export playbook
- Store saved images in the export bundle under a `container_images/` subdirectory
- Document the `podman load` step as part of the highside import process
- Consider using the Satellite container registry (already in scope for `Red Hat Enterprise Linux Bootc Containers`) as the highside distribution point rather than individual tar files

**Scope:** Disconnected export playbook + highside import playbook in `rhis-builder-satellite`. Coordinate with quadlet and AAP deployment roles.

---

#### AAP Platform Installer Template — Optional Parameter Handling (DEFERRED to AAP testing)

**Problem:** The platform installer inventory templates (`inventory_template/templates/*_inventory.j2`)
use inconsistent patterns for optional parameters. `default(omit)` does not work in Jinja2
`template` module output — `omit` is a magic value only valid in Ansible task parameters.
A missing optional parameter is treated differently from an empty string by the AAP installer.

**Correct pattern for optional parameters:**
```jinja2
{# Required — always emit #}
pg_password="{{ platform_installer_config.pg_password }}"

{# Optional — only emit if defined and non-empty; installer uses its own default if absent #}
{% if platform_installer_config.eda_pg_password | default('') | length > 0 %}
eda_pg_password="{{ platform_installer_config.eda_pg_password }}"
{% endif %}
```

Using `| length > 0` is safer than `| default(false)` — handles the case where the variable
is defined but explicitly set to empty string (should be treated as "use installer default").

**Scope:** All `*_inventory.j2` templates in `inventory_template/templates/`.
**Deferred:** Will be addressed during AAP build-out and testing passes.

---

#### Jinja2 Rendering of {{ }} Expressions Inside YAML Comments in Template Files

**Problem:** In `.j2` template files processed by Ansible's `template` module, Jinja2
evaluates ALL `{{ }}` expressions — including those inside YAML comments (`# ... {{ var }}`).
If the variable is not in scope at render time, Ansible throws a template error even though
the comment has no runtime effect.

**Affected pattern:** Any `# comment containing {{ variable }}` in a `.j2` file where the
variable is not defined in the Ansible variable scope during `inventory_update.yml` rendering.

**Common occurrences:**
- PATTERN comments explaining extra-vars dispatch (e.g. `# platform_hosts=<capsule_hosts>`)
  that were fixed in the provisioner group_vars `.j2` files earlier in this project
- Inline documentation comments referencing variables that are runtime-only (not render-time)

**Fix options:**
1. Use Jinja2 comment syntax instead of YAML comment: `{# This is safe: {{ var }} #}`
   — Jinja2 strips these before output, never evaluates them
2. Escape the braces: `{{ '{{' }} var {{ '}}' }}` — renders literally as `{{ var }}`
3. Move the comment outside `{% raw %}...{% endraw %}` blocks and rewrite without `{{ }}`
4. Use descriptive text without Jinja2 syntax: `# platform_hosts=<capsule_hosts>`

**Recommended approach:** Audit all `.j2` files in `inventory_template/` for YAML comments
containing `{{ }}` outside of `{% raw %}` blocks. Replace with option 1 (`{# #}`) or option 4
(angle bracket notation). Option 4 is preferred for operator-facing documentation comments
as it is more readable.

**Scope:** All `.j2` files in `inventory_template/`. Prioritize files with PATTERN and
explanatory comments that reference variable names in `{{ }}` syntax.

---

#### Extend `satellite_disconnected_pre` with ISO pre-stage and pre-mount variables (rhis-builder-satellite)

Add `satellite_disconnected_iso_prestaged` and `satellite_disconnected_iso_mounted` boolean
variables to skip ISO copy and mount steps respectively when the operator has already
staged/mounted the ISOs via transfer media. Default to `false` to preserve current behaviour.

Replace `ansible.builtin.copy` with `ansible.posix.synchronize` for ISO transfer — rsync
sends only deltas on subsequent runs, dramatically faster for 9GB+ ISOs.

Variables to add to `host_vars/discosatellite/` satellite_pre equivalent:
```yaml
satellite_disconnected_iso_prestaged: false  # skip copy if ISOs already at satellite_disconnected_root
satellite_disconnected_iso_mounted: false    # skip mount if ISOs already mounted
```

**Scope:** `rhis-builder-satellite` — `roles/satellite_disconnected_pre/tasks/main.yml`

---

#### Extend `imported_git_repos` role for disconnected bundle extraction (rhis-builder-satellite)

The `imported_git_repos` role currently only supports `ansible.builtin.git` clone/update
from remote URLs. For the disconnected (air-gapped) highside build, compliance-as-code
roles arrive as a tar archive in the export bundle and must be extracted to
`/etc/ansible/roles/` before the git verification and Satellite ingestion steps run.

**Implementation:** Add a new task block at the TOP of
`roles/imported_git_repos/tasks/main.yml`. Use `ansible.posix.synchronize` (rsync)
rather than unarchive — faster for large role sets, idempotent, handles pre-staged
directory sources as well as bundle-extracted directories:

```yaml
- name: "Sync compliance roles from bundle source (disconnected)"
  when:
    - satellite_disconnected | default(false)
    - satellite_roles_source_path is defined
    - satellite_roles_source_path | length > 0
  ansible.posix.synchronize:
    src: "{{ satellite_roles_source_path }}/"
    dest: "/etc/ansible/roles/"
    recursive: true
    delete: false
  delegate_to: "{{ inventory_hostname }}"
  tags:
    - tags_provisioning_config
    - tags_import_git_repos
```

**New variables required:**
- `satellite_roles_source_path` — path to the extracted/staged roles directory on the
  highside satellite (e.g. `/home/ansiblerunner/rhis_export/ansible_roles/`). The bundle
  assembly extracts roles to a named directory rather than a tar, making synchronize
  the natural choice.

**Bundle side:** The lowside export playbook rsync/copies `/etc/ansible/roles/` and
`/etc/ansible/playbooks/` to `<export_path>/ansible_roles/` in the bundle directory
(not tarred — kept as a directory tree for synchronize compatibility).

**Scope:** `rhis-builder-satellite` — `roles/imported_git_repos/tasks/main.yml`.

---

#### Export Content Credentials for Disconnected Transfer (rhis-builder-satellite)

Write a new role `content_credentials_export` in `rhis-builder-satellite` that exports all custom content credentials (GPG keys, SSL certificates, CA certificates) configured in Satellite to flat text files in rhis format, suitable for inclusion in the disconnected transfer bundle.

**Background:** Content credentials (GPG keys for custom products like EPEL, CentOS, MSSQL; SSL client certs for authenticated repos) are stored in Satellite's database. While the Library export captures the *content* associated with those repos, the credentials themselves may need to be explicitly re-imported on the highside satellite before the content can be verified and used. Capturing them explicitly ensures the highside build does not fail due to missing GPG keys.

**Proposed behaviour:**
- Query Satellite API for all content credentials (`/katello/api/content_credentials`)
- Export each credential to a named file: `<name>.gpg`, `<name>.pem`, or `<name>.crt` depending on type
- Write a manifest YAML file listing all exported credentials with their type, product associations, and file paths
- Output directory configurable (default: `/home/ansiblerunner/rhis_export/content_credentials/`)

**Implementation scope:** `rhis-builder-satellite` — new role `content_credentials_export`. Called as part of the disconnected export playbook (to be written).

**Note:** The rhis `content_credentials` role already handles *import* (creation in Satellite from vault-managed files). This export role is the complement — read back from Satellite and write to the bundle.

---

#### Ephemeral Diagnostic Container Model

**Concept:** Rather than including powerful diagnostic tools (nmap, wireshark, tcpdump, strace, etc.) in the SOE content views — which broadens the attack surface and complicates compliance scans — deliver them as ephemeral containers stored in Satellite's container registry. Operators deploy the container when needed, run the tools, then destroy it. The image is also removed after the session.

**Benefits:**
1. **Compliance** — SOE hosts carry no diagnostic tools. Scans are clean by design, not by manual cleanup.
2. **InfoSec** — Reduced attack surface. Powerful tools are not persistently available on any host.
3. **Operations** — Engineers still have access to everything they need, on demand.
4. **Release Engineering** — Simpler package management; the exclusion list in the content view filter is a formal, versioned audit artifact.

**Proposed models:**

*Two-container model (simpler — maps directly to role separation):*

| Container | Capabilities | Tools | Approval | TTL |
|---|---|---|---|---|
| `rhis-diagnostic-operator` | `CAP_NET_RAW`, `--network host` | ping, traceroute, nmap (basic), curl, dig, ss, iperf | Team lead | 2 hours |
| `rhis-diagnostic-elevated` | + `CAP_SYS_PTRACE`, `--pid host`, optional filesystem mounts | + tcpdump, tshark, strace, lsof, gdb | Security officer | 1 hour |

*Three-tier model (alternative — one size does not fit all):*

| Tier | Capabilities | Tools | Approval |
|---|---|---|---|
| 1 — Observer | `CAP_NET_RAW`, `--network host` | ping, nmap, traceroute | Team lead |
| 2 — Inspector | + `CAP_SYS_PTRACE`, `--pid host` | + strace, lsof, ss | Security officer |
| 3 — Full | Tier 1+2 + filesystem mounts | Everything | Security officer + CISO |

**Capability concerns:**
- `--network host` + `CAP_NET_RAW` → can capture ALL host traffic including decrypted application traffic
- `--pid host` + `CAP_SYS_PTRACE` → can attach to any host process and read its memory (including vault credential holders)
- Filesystem mounts (even `--read-only`) → exposes private keys, vault files, application configs
- Higher tiers may warrant an ephemeral VM instead of a container for stronger isolation guarantees

**Mitigations (all tiers):**
- `--read-only` container filesystem
- `--security-opt no-new-privileges`
- Custom seccomp profile
- SELinux confined container type
- Auto-destroy TTL enforced by AAP job
- Signed images — provenance verifiable from Satellite
- Command-level audit logging inside container
- Session generates audit report on destruction

**RHIS integration:**
- Both images built from a dedicated content view (`SOE9_Diagnostics`) — the only CV allowed to contain restricted packages, never promoted to managed hosts, feeds container registry only
- Both stored in Satellite container registry — no external registry dependency
- IdM groups control access: `grp-diagnostic-operator`, `grp-diagnostic-elevated`
- AAP Job Templates handle deploy/destroy workflow with approval gates
- HBAC in IdM gates who can trigger which AAP job

**Implementation scope:** rhis-builder-satellite (container registry, content view), rhis-builder-aap (job templates, approval workflow), rhis-builder-inventory (activation keys, content view filter exclusions).

---

#### Deprecation Tagging Model for Satellite Configuration Entries

Satellite configuration files (`content_views.yml`, `sync_plan_product_map.yml`, `repositories.yml`, `repository_sets.yml`, `activation_keys.yml`, `hostgroups.yml`, etc.) contain entries for OS versions and products that are periodically deprecated (RHEL 7, ELS, OEL, legacy AAP versions, etc.). Currently deprecation is handled by commenting entries out manually, which:

1. Is invisible to tooling — grep cannot distinguish "commented for deprecation" from "commented for debugging"
2. Is fragile under `git checkout` — manual deprecation work is easily wiped
3. Provides no audit trail — no record of when or why something was deprecated

**Proposed solution: structured YAML state field (`rhis_lifecycle`)**

Add an optional `rhis_lifecycle` field to list entries in all satellite configuration files:

```yaml
content_views:
  - name: "SOE7"
    rhis_lifecycle: "deprecated"        # active (default) | deprecated | experimental
    rhis_deprecated_since: "2026-06-01"
    rhis_deprecated_reason: "RHEL 7 EOL — transitioning all workloads to RHEL 8+"
    desc: "RHEL 7 Standard Operating Environment Content"
    ...
```

**Implementation requirements:**

- Each consuming role (`content_views`, `sync_plans`, `repositories`, `activation_keys`, etc.) in rhis-builder-satellite gains a pre-filter task that removes `rhis_lifecycle: "deprecated"` entries before processing the list
- Default behaviour when `rhis_lifecycle` is absent: treat as `active`
- `experimental` entries are processed but flagged in output
- A schema linting script in `schema/scripts/` can report all deprecated entries across all files

**Benefits:**
- Deprecated entries remain visible in the file with context (why, when)
- `git checkout` cannot silently erase deprecation state
- Queryable: `grep -r "rhis_lifecycle: deprecated"` gives a full deprecation inventory
- Enables future automation: a script could remove entries deprecated > N months ago

**Scope:** rhis-builder-satellite roles + all `inventory_template/host_vars/satellite/` configuration files. Coordinate with rhis-builder-satellite maintainer before implementing role changes.

**Known candidates for `rhis_lifecycle: "deprecated"` tagging:**

| Entry | Files | Reason |
|---|---|---|
| RHEL 7 / ELS / OEL79 content views, repos, activation keys | `content_views.yml`, `repositories.yml`, `repository_sets.yml`, `activation_keys.yml`, `hostgroups.yml` | RHEL 7 EOL — transitioning all workloads to RHEL 8+ |
| `Red Hat Ansible Engine` sync plan product | `sync_plan_product_map.yml` | Replaced by AAP; product is deprecated |
| `Red Hat Enterprise Linux Server` sync plan product | `sync_plan_product_map.yml` | Legacy RHEL 7 product; disabled in current manifests |
| `Red Hat Satellite 6 Client 2` repos | `content_views.yml`, `repositories.yml` | Red Hat announced these repos but never shipped content to them; they are permanently empty and safe to remove |

---

#### Static IP Address Assignment — Cross-Project Brittleness (HIGH PRIORITY)

The current approach to static IP address assignment is fragile and inconsistent across rhis-builder projects. Failures surface at build time as silent wrong-address bugs that are difficult to trace.

**Known failure points identified during example.ca build (2026-05-29):**

1. **`bootstrap_init` vs `inventory_template` mismatch** — `bootstrap_init` embeds nameserver IPs in kickstart files at provisioning time. When the static IP allocation changes (e.g. IdM moved from `.5`/`.6` to `.10`/`.11`), freshly-provisioned hosts boot with wrong nameservers and can't resolve the CDN or IdM, causing downstream builds to fail.

2. **`ipa_client_dns_servers` override in `satellite_pre.yml`** — hardcoded as `"{{ _default_network }}.5"` which silently overrides the correct value (`192.168.140.10` via `ansible.utils.next_nth_usable(10)`) already set in `group_vars/all/main.yml`. Host_vars always wins, so the group_vars fix is invisible. Removed the override (see commit), but the root cause is the pattern of hardcoding ordinal positions.

3. **`.5`/`.6` vs `next_nth_usable(5)`/`next_nth_usable(6)` inconsistency** — some files use `_default_network` + literal offset, others use `ansible.utils.next_nth_usable`. These give the same result on /24 but diverge on other prefix lengths (see network rework item below).

**Root cause:** There is no single authoritative source for "IdM primary is at position X on the network." Each project inlines its own assumption. When the assumption changes in one place, all others are silently wrong.

**Required fix:**
- Define a small set of named network position variables in `inventory_basevars.yml` (e.g. `rhis_idm_primary_position: 10`, `rhis_idm_replica_position: 11`) and derive IPs from them consistently everywhere using `ansible.utils.next_nth_usable`.
- Update `bootstrap_init` to read these positions from the basevars rather than embedding literal IPs in kickstart templates.
- Remove all host_vars overrides of `ipa_client_dns_servers` — let `group_vars/all/main.yml.j2` be the single source of truth.
- This is a cross-project change: `rhis-builder-inventory`, `rhis-builder-idm`, `rhis-builder-satellite`, `rhis-builder-kvm`, `rhis-builder-baremetal-init` all need updating.

---

#### Network address variable rework (group_vars/all/main.yml.j2)

The current `_default_network`, assigned address, and default gateway derivation logic works correctly only for /24 address spaces where the host portion begins in the last octet. It fails in the general case where the host address starts in an earlier octet (e.g. /16, /8, or non-octet-aligned prefix lengths), leading to incorrect gateway assignments and failed network communications. A general rework is required to handle arbitrary CIDR prefix lengths correctly.

**Note on `_default_bond_default_gateway`:** The use of `_default_network` (provision network prefix) rather than `_default_bond_network` for the bond gateway is an intentional workaround, not a bug. The bond interface address range is coincident with the provision network — both reside within the same physical subnet and share the same gateway. The workaround holds for the current /24-aligned topology but will need to be revisited as part of the general rework. When the rework is done, the shared-gateway assumption should be made explicit either through a dedicated `default_gateway` variable or a comment in the template.

**Known static IP allocation (provision network, /24-aligned):**
- `.1` — default gateway
- `.5` — IdM primary (DNS primary)
- `.6` — IdM replica (DNS secondary)
- `.12` — Satellite server (also serves as PXE server via `--foreman-proxy-dhcp-pxeserver`)
- `.13` — provisioner host (rhis-builder Ansible control node)
- `.14` — AAP controller
- `.15` — AAP Hub
- `.41–.47` — KVM hypervisors
- `.71–.72` — Quadlet hosts
- `.81` — Satellite capsule
- `.100–.254` — DHCP pool (bare-metal discovery / dynamic assignment)

**Additional computed variables needed as part of this rework:**

- `_idm_primary_ip` — compute as `target_net_cidr | ansible.utils.next_nth_usable(5)` in `main.yml.j2`. Set `ipa_client_dns_servers: "{{ _idm_primary_ip }}"` globally. Remove the `ipa_client_dns_servers: "{{ _default_network }}.5"` overrides from `host_vars/satellite/satellite_pre.yml` and `host_vars/discosatellite/satellite_pre.yml` — these exist only because the global value currently points to the wrong host (position 10, unallocated). User can override `_idm_primary_ip` in basevars if IdM primary is at a non-standard position.

- `_default_reverse_zone` — compute in `main.yml.j2` from `default_network` (split into octets) and `default_network_prefix` (to select the appropriate octet depth): `/8` or less → 1-octet zone, `/9`–`/16` → 2-octet zone, `/17`–`/24` → 3-octet zone. For non-octet-aligned prefixes (e.g. /22) use the next coarser octet boundary to avoid RFC 2317 classless delegation complexity. Replace the hardcoded `ipa_dns_reverse_zone: "168.192.in-addr.arpa"` in both satellite_pre files with `ipa_dns_reverse_zone: "{{ _default_reverse_zone }}"`.

**Recommended rework approach (hybrid):**

1. Add `default_network_cidr` to `inventory_basevars.yml` as a full CIDR string (e.g. `"192.168.1.0/24"`). Derive `_default_network_cidr` and `_default_bond_network_cidr` in `main.yml.j2` from the user-supplied values.
2. Define `target_net_cidr` in `inventory_basevars.yml` (or derive it in `main.yml.j2`). This variable is already consumed by `ansible.utils.next_nth_usable` throughout the templates but is currently not defined in `inventory_template`.
3. Replace all `{{ _default_network }}.X` patterns with `{{ _default_network_cidr | ansible.utils.nthhost(X) }}` throughout the ~40 affected template files.
4. Replace all `{{ _default_bond_network }}.X` patterns with `{{ _default_bond_network_cidr | ansible.utils.nthhost(X) }}`.
5. For the default gateway, use `ansible.utils.nthhost(_default_network_cidr, 1)` or introduce a dedicated `default_gateway` variable supplied by the user — making the shared-gateway assumption explicit rather than implicit.
6. Verify that `ansible.utils` collection is available in all execution environments that render these templates.

This approach preserves human readability, handles arbitrary prefix lengths correctly, and requires only an additive change to `inventory_basevars.yml`.

---

#### SOE Bundle Model — Snippet Ordering Design Decision

When including Satellite kickstart snippets dynamically via an ERB host parameter (`rhis_extra_snippets`), snippets must execute in a defined order. The design considered two approaches:

**Option evaluated: systemd dependency graph model**
Snippets declare `After=`, `Before=`, `Requires=`, and `Wants=` relationships in a metadata block. An aggregation step builds a directed graph and performs a topological sort to determine render order. This provides the most expressive ordering contract and detects circular dependencies at aggregation time rather than at kickstart runtime.

**Rejected because:** The problem scope does not justify the complexity. Systemd's dependency graph solves ordering across hundreds of units with intricate interdependencies across a full OS boot. A SOE bundle contains a small, well-understood set of snippets with predictable phase relationships. The machinery required (metadata parsing, graph construction, Kahn's algorithm, cycle detection, target resolution) is disproportionate to the problem and would be difficult to explain to customers or for users to extend.

**Chosen approach: priority-weighted ordering with documented phase ranges**

The `rhis_extra_snippets` host parameter is a semicolon-separated list of `priority:snippet_name` pairs. The ERB block in the base template sorts by priority before rendering:

```
rhis_extra_snippets = "200:rhis_subscription;300:rhis_repos;600:rhis_jboss_packages;700:rhis_jboss_config"
```

Phase ranges (gaps allow insertion without renumbering — same reasoning as SysV init script numbering):

| Range | Phase |
|---|---|
| 100–199 | Pre-partition / disk layout |
| 200–299 | Subscription and registration |
| 300–399 | Repository configuration |
| 400–499 | Base package selection |
| 500–599 | Service and daemon configuration |
| 600–699 | Application package installation |
| 700–799 | Application configuration |
| 800–899 | Post-install hooks |
| 900–999 | Cleanup and finalization |

**Key properties:** Order is declared by the snippet author (not by list position), so adding a new snippet never requires touching existing entries. The aggregation step merges lists from multiple bundles, sorts by priority, and deduplicates. Tie-breaking within a shared priority value is alphabetical by name (deterministic). This model is explainable in two minutes and requires no tooling beyond sorting.

---

#### Disconnected Model — Export Bundle Automation

**Context:** The disconnected (air-gapped / highside) build requires a validated lowside Satellite to export its content and configuration before transfer. The Satellite server is the natural staging point because it already holds the lion's share of the data volume — avoiding an additional multi-terabyte copy step.

**Artifacts to assemble on the Satellite:**

1. **Satellite Library export** — handled by the existing `content_exports` role in rhis-builder-satellite. Chunked 2 GB `importable`-format files land in `/var/lib/pulp/exports/<destination_server>/`. Satellite's own `metadata.json` is generated via `hammer content-export generate-metadata`. A timestamped `_content_imports.yml` for the highside is written by `generate_content_imports_file.yml`. **Already implemented.**

2. **rhis-builder-inventory configuration archive** — tar.gz of the inventory tree (excluding `.git`) pushed from the provisioner to the Satellite staging directory. Small in size. Vault-encrypted vars travel with the bundle; the vault password must cross the air gap separately via a trusted channel and is explicitly documented in the bundle manifest.

3. **rhis-provisioner container image** — `podman save` on the provisioner, pushed to the Satellite staging directory. Moderate size.

4. **Compliance-as-code Ansible roles** — RedHatOfficial repos are already cloned to `/etc/ansible/roles/` on the Satellite during the connected build (defined in `imported_git_repos.yml`). At export time, each repo's HEAD SHA is captured (`git -C <dest> rev-parse HEAD`) and recorded in the bundle manifest. The roles are tarred from their on-disk location — no re-download required.

5. **Foreman discovery image** — pulled directly from the foreman-discovery upstream repo by the Satellite installer during the connected build. Already present on the Satellite filesystem (TFTP boot directory). Located and copied to the staging directory at export time.

6. **Bundle manifest** — generated on the Satellite. Records sha256 checksums of every artifact, git SHAs for each compliance-as-code role, Satellite export history ID, and a checklist of what must travel separately (vault password).

**Transfer step (separate, operator-triggered):** The `content_export_copies` role (not yet implemented) copies the fully staged bundle from `/var/lib/pulp/exports/<destination>/` to physical transfer media (`destination_folder` in `content_export_copies` host_vars). This is a distinct action from export assembly, run only when transfer is authorized.

**Implementation work required:**

- [ ] New `export_disconnected.yml` playbook in rhis-builder-satellite — orchestrates steps 2–6 above on the Satellite host; calls the existing `content_exports` role for step 1
- [ ] New `content_export_copies` role in rhis-builder-satellite — copies staged bundle to transfer media; `content_export_copies` host_vars variable already defined in `inventory_template`
- [ ] Export manifest task — walks `git_repos` list, captures HEAD SHAs, computes sha256sums, writes YAML manifest to staging directory
- [ ] New `build_sat_disconnected_export.sh` helper script in rhis-provisioner-container — wraps the playbook call; handles `podman save` and inventory tar locally then pushes both to the Satellite staging directory; follows existing `build_sat_*` naming and invocation pattern
- [ ] Highside import playbook / role verification — `content_imports` role and `discosatellite` host_vars already exist; validate the full import sequence against a test highside

---

---

#### Cross-Host FQDN Reference Audit — COMPLETE

**Principle:** The rendered inventory (`inventory.j2`) is the single source of truth for host FQDNs. Variables referencing tracked infrastructure hosts must use `groups['group_name'][N]` notation — never pattern-reconstruct (`prefix.{{ _runtime_global_domain_name }}`).

**Full findings:** See `schema/audit_findings.md` Section 4.

**Summary of violations found (Category A — fix required):**

| Location | Variable | Current (wrong) | Fix |
|---|---|---|---|
| `host_vars/satellite/satellite_pre.yml:52` | `ipa_server_fqdn` | `"idm1.{{ _runtime_global_domain_name }}"` | Remove line — `group_vars/all` already correct |
| `host_vars/discosatellite/satellite_pre.yml:52` | `ipa_server_fqdn` | `"{{ groups['idm_primary'][0] }}"` | Already correct — no change |
| `group_vars/all/main.yml.j2:40` | `vm_compute_resource` | `"vcenter.{{ _runtime_global_domain_name }}"` | `"{{ groups['vmware_vcenter_hosts'][0] }}"` |
| `host_vars/satellite/compute_resources.yml.j2:55` | vcenter url | `"vcenter.{{ _runtime_global_domain_name }}"` | `"{{ groups['vmware_vcenter_hosts'][0] }}"` |
| `host_vars/discosatellite/compute_resources.yml.j2:52` | vcenter url | `"vcenter.{{ _runtime_global_domain_name }}"` | `"{{ groups['vmware_vcenter_hosts'][0] }}"` |
| `host_vars/satellite/virtwho_configs.yml:14` | `hypervisor_server` | `"vcenter.{{ _runtime_global_domain_name }}"` | `"{{ groups['vmware_vcenter_hosts'][0] }}"` |
| `host_vars/discosatellite/virtwho_configs.yml:14` | `hypervisor_server` | `"vcenter.{{ _runtime_global_domain_name }}"` | `"{{ groups['vmware_vcenter_hosts'][0] }}"` |
| `host_vars/idm/prerequisites.yml:41` | fqdn | `"provisioner.{{ _runtime_global_domain_name }}"` | `"{{ groups['provisioner'][0] }}"` |
| `host_vars/idm/prerequisites.yml:43` | fqdn | `"satellite.{{ _runtime_global_domain_name }}"` | `"{{ groups['satellite_servers'][0] }}"` |
| `host_vars/idm/hbac_policy.yml:47` | host | `"satellite.{{ _runtime_global_domain_name }}"` | `"{{ groups['satellite_servers'][0] }}"` |
| `host_vars/idm/dns_configuration.yml.j2:33` | `srv_target` | `"satellite1.{{ _runtime_global_domain_name }}."` | `"{{ groups['satellite_servers'][0] }}."` |
| `group_vars/idm_replicas/idm_pre_vars.yml:35` | fqdn | `"provisioner.{{ _runtime_global_domain_name }}"` | `"{{ groups['provisioner'][0] }}"` |
| `group_vars/idm_replicas/idm_pre_vars.yml:37` | fqdn | `"satellite1.{{ _runtime_global_domain_name }}"` | `"{{ groups['satellite_servers'][0] }}"` |
| `host_vars/discosatellite/content_exports.yml.j2:30` | `destination_server` | `"discosatellite1.{{ basevars_global_domain_name }}"` | Fix typo: `_runtime_global_domain_name` (or use groups[]) |
| `host_vars/quay1/quay.yml.j2:7` | `quay_server_hostname` | `"quay1.{{ basevars_global_domain_name }}"` | Fix typo: `_runtime_global_domain_name` |

**Pending fixes:**
- [ ] Remove `ipa_server_fqdn` override from `host_vars/satellite/satellite_pre.yml`
- [ ] Fix `vm_compute_resource` in `group_vars/all/main.yml.j2`
- [ ] Fix vcenter URL in both `compute_resources.yml.j2` files
- [ ] Fix vcenter `hypervisor_server` in both `virtwho_configs.yml` files
- [ ] Fix provisioner/satellite fqdn refs in `host_vars/idm/` and `group_vars/idm_replicas/`
- [ ] Fix `basevars_global_domain_name` typo (missing `_` prefix) in `quay.yml.j2` and `content_exports.yml.j2`
- [ ] Add naming convention rule to schema documentation

---

#### Cloud Resource Element Naming — Unworkable Scheme

**Context:** Azure resource groups, VNets, and subnets are currently named using a
split of `basevars_global_domain_name` on `.`, producing a `element#_<part0>_<part1>`
scheme (e.g., `rg1_savage_test` for domain `savage.test`). This is implemented via
`split_basevars_global_domain_name` computed in `inventory_update.yml` and consumed in:

- `host_vars/satellite/compute_resources.yml.j2`
- `host_vars/discosatellite/compute_resources.yml.j2`
- `host_vars/aapcontroller24/platform_post.yml.j2`
- `host_vars/aapcontroller26/platform_post.yml.j2`
- `host_vars/aaphub24/platform_post.yml.j2`
- `host_vars/aaphub26/platform_post.yml.j2`
- `group_vars/provisioner/testyubiuser.yml.j2`

**Why it is unworkable:**
1. Assumes exactly two domain parts. Domains with more components (e.g., `lab.example.ca`)
   produce wrong resource names — `rg1_lab_example` instead of something meaningful.
2. Resource group names must be stable — if the domain name ever changes, Azure resources
   become orphaned (Satellite loses the compute resource reference, existing VMs are
   unmanaged).
3. The scheme encodes no environment or subscription context, so multi-subscription or
   multi-region deployments produce name collisions.
4. Azure naming constraints (length, allowed characters) are not enforced.

**Recommended fix (future):**
Introduce explicit basevars variables for cloud resource naming that are independent of
the domain name:

```yaml
rhis_azure_resource_prefix: "rg1"       # or customer/env abbreviation
rhis_azure_environment_tag: "lab"       # used consistently across resource names
```

Use these to construct resource names deterministically without relying on domain splitting.
This also allows the same inventory to target different Azure subscriptions or regions
without naming collisions.

**Current state:** The `split_basevars_global_domain_name[0]` / `[1]` scheme is retained
as-is for sample deployments. Do not build production landing zones on this scheme.

---

Document Ansible modules and versions
Document rhis-builder internal configuration variables and allowable values
  - names
  - aliases
  - required/optional and conditions
  - defaults
  - dependencies
  - descriptions
  - function
