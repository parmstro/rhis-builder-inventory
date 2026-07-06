# Disconnected Satellite Workflow

**Document version:** 1.0
**Branch:** schema
**Status:** Partially implemented â see TODO callouts throughout

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Prerequisites](#2-prerequisites)
   - [2.1 Lowside prerequisites](#21-lowside-prerequisites-must-be-complete-first)
   - [2.2 Highside prerequisites](#22-highside-prerequisites)
   - [2.3 Highside basevars pre-flight for export_disconnected](#23-highside-basevars-pre-flight-for-export_disconnected)
3. [Build Sequence](#3-build-sequence)
4. [Content Export Process](#4-content-export-process)
5. [Transfer Process](#5-transfer-process)
6. [Highside Import Process](#6-highside-import-process)
7. [Configuration Differences](#7-configuration-differences)
8. [Known Limitations and Risks](#8-known-limitations-and-risks)
9. [Inventory Template Requirements](#9-inventory-template-requirements)

---

## 1. Architecture Overview

The rhis-builder disconnected Satellite workflow implements a two-satellite model. One satellite has outbound internet access to the Red Hat CDN (the "lowside" or connected satellite). A second satellite operates in an air-gapped network with no CDN access (the "highside" or disconnected satellite, referred to in inventory as `discosatellite`).

```
ââââââââââââââââââââââââââââââââââââ         air gap          âââââââââââââââââââââââââââââââââââââââ
â         LOWSIDE (connected)       â                          â        HIGHSIDE (disconnected)       â
â                                   â                          â                                      â
â  Red Hat CDN âââº satellite1       â   export bundle on      â  discosatellite1                     â
â                  (sat_primary)    â   physical/secure media  â  (discosatellite group)              â
â                       â           â ââââââââââââââââââââââº  â        â                             â
â                 content_exports   â                          â  content_imports                     â
â                 role generates    â                          â  role ingests                        â
â                 export tarball    â                          â  export tarball                      â
ââââââââââââââââââââââââââââââââââââ                          âââââââââââââââââââââââââââââââââââââââ
```

**Lowside responsibilities:**
- Sync content from Red Hat CDN via repository sets
- Generate a Satellite subscription manifest via CDN API (`generate: true`)
- Run content export to produce chunked importable tarballs
- Stage the export bundle (content + inventory archive + container image + compliance roles + discovery image)
- Copy the bundle to transfer media when transfer is authorized

**Highside responsibilities:**
- Receive the export bundle from transfer media
- Import content via the `content_imports` role
- Operate fully offline; no CDN, no IdM integration, no NBDE/Tang
- Serve as the primary PXE/bare-metal discovery endpoint for the air-gapped environment

The two satellites are configured as distinct inventory hosts. The lowside uses the `satellite` host_vars directory; the highside uses the `discosatellite` host_vars directory. They belong to the same `sat_primary` inventory group but are driven by separate inventory files (`inventory.j2` for lowside, `disco_inventory.j2` for highside).

---

## 2. Prerequisites

The following must be complete before the disconnected satellite build can begin.

### 2.1 Lowside prerequisites (must be complete first)

The comment in `build_sat_primary_connected.sh` states explicitly: "You must build a connected satellite before a disconnected satellite."

| Prerequisite | Where configured | Notes |
|---|---|---|
| Connected satellite fully built and configured | `build_sat_primary_connected.sh` | Runs `main.yml` limited to `sat_primary` |
| Repository sets enabled and synced | `host_vars/satellite/repository_sets.yml` | CDN sync must be complete before export |
| Content views published | `host_vars/satellite/content_views.yml` | At minimum the Library must be in a publishable state |
| Subscription manifest generated | `host_vars/satellite/manifests.yml` (`generate: true`) | Connected satellite generates via CDN API |
| A separate manifest zip for the highside obtained from Red Hat Customer Portal | Downloaded manually and placed on the provisioner | The highside manifest cannot be auto-generated; it must be created in the portal and downloaded as a zip file |
| Compliance-as-code Ansible roles cloned to `/etc/ansible/roles/` on the connected satellite | `host_vars/satellite/imported_git_repos.yml` | These are tarred at export time; must be present before running the export playbook |
| Foreman discovery image present in the TFTP directory | Installed by `satellite-installer` during lowside build | Located and staged at export time |
| ISOs available for highside OS install | `host_vars/discosatellite/main.yml` â `satellite_os_iso_source`, `satellite_install_iso_source` | RHEL OS ISO and Satellite install ISO must be accessible to the provisioner for transfer to highside |
| `discosatellite` host_vars fully populated | `inventory_template/host_vars/discosatellite/` | All required files must exist before running the export or import playbooks |
| Vault password for the highside inventory | Out-of-band, operator-managed | The vault password must cross the air gap via a trusted channel separately from the bundle |

### 2.2 Highside prerequisites

| Prerequisite | Notes |
|---|---|
| Highside host provisioned with supported RHEL OS | Base OS only; no internet access required or expected |
| Transfer media accessible at highside | The bundle landing path (e.g. `/run/media/ansiblerunner/export`) must be mountable |
| Vault password received via trusted channel | Required before the import playbook can run |

### 2.3 Highside basevars pre-flight for export_disconnected

Before running `export_disconnected.yml`, a basevars file for the disconnected deployment must exist and pass all of the following checks. The export playbook reads this file to determine what to include in the bundle and where the highside satellite will be.

| Requirement | Basevars key | Valid value | Notes |
|---|---|---|---|
| Basevars file exists | — | File must be present on the provisioner | e.g. `highside.example.ca_inventory_basevars.yml` |
| Deployment has been rendered | `basevars_global_domain_name` | Must match an existing directory under `deployments/` | Run `inventory_update` if the deployment directory is missing or stale |
| Flagged as disconnected | `basevars_disconnected_domain` | `true` | Enables disconnected code paths; export will refuse to run against a connected deployment |
| Upstream connected deployment identified | `basevars_upstream_connected_deployment` | Domain name of the connected lowside (e.g. `"example.ca"`) | Used by the export playbook to locate the lowside satellite and its content |
| Content import enabled | `satellite_import_content` | `true` | Must be uncommented and set to `true`; controls whether the import role runs during the highside build |
| Satellite count | `rhis_system_count.satellite` | `>= 1` | At least one satellite must be defined in the highside inventory |
| Satellite version matches lowside | `rhis_satellite_release_version` | Must match the lowside version exactly | Pulp enforces strict version compatibility between export and import — a mismatch causes content import to fail |

> **Note on `satellite_roles_source_path`:** This variable does **not** need to be set in basevars. It is injected automatically by `build_sat_disconnected_import.sh` using the bundle path written by `bundle_delivery/tasks/validate.yml` to `/tmp/rhis_bundle_path.txt`. The resolved default is `/var/satellite_stage/satellite/ansible_roles` (derived from `bundle_delivery_stage_path`). Only set it manually if overriding the default staging location.

**Pre-flight checklist before running `export_disconnected.yml`:**

```bash
# 1. Confirm basevars file exists
ls <domain>_inventory_basevars.yml

# 2. Confirm deployment directory exists and is current
ls deployments/<domain>/
# If missing or stale: ./inventory_update.sh --basevars-file <domain>_inventory_basevars.yml

# 3. Confirm required keys
grep "basevars_disconnected_domain" <domain>_inventory_basevars.yml      # must be: true
grep "basevars_upstream_connected_deployment" <domain>_inventory_basevars.yml  # must be set
grep "satellite_import_content" <domain>_inventory_basevars.yml          # must be uncommented and: true
grep "rhis_system_count" -A6 <domain>_inventory_basevars.yml             # satellite must be >= 1
grep "rhis_satellite_release_version" <domain>_inventory_basevars.yml    # must match lowside version
```

---

## 3. Build Sequence

The full end-to-end sequence spans lowside export, physical transfer, and highside import.

### 3.1 Lowside build (connected satellite)

This sequence is fully implemented.

```
build_sat_primary_connected.sh
    âââ main.yml (limited to sat_primary)
            âââ satellite_pre            (unconditional)
            âââ satellite                (installs Satellite)
            âââ satellite_post           (unconditional)
            âââ redhat_manifests         (generate: true â CDN API call)
            âââ subscription_manifests   (unconditional)
            âââ content_credentials      (unconditional)
            âââ repository_sets          (when: not satellite_disconnected)
            âââ repositories             (when: not satellite_disconnected)
            âââ start_synchronization    (when: not satellite_disconnected)
            âââ sync_plans               (when: not satellite_disconnected)
            âââ lifecycle_environments   (unconditional)
            âââ content_views            (unconditional)
            âââ [remaining roles]        (all unconditional)
```

### 3.2 Lowside export (content + bundle assembly)

**Status: Partially implemented.** The `content_exports` role (step 1) is implemented. Steps 2â6 are not yet implemented.

```
[planned] build_sat_disconnected_export.sh          â TODO: does not exist yet
    âââ export_disconnected.yml                     â TODO: does not exist yet
            âââ content_exports role                â IMPLEMENTED
            â       âââ Library export â /var/lib/pulp/exports/<destination_server>/
            âââ inventory archive (tar.gz)           â TODO
            âââ podman save (container image)        â TODO
            âââ compliance-as-code roles (tar)       â TODO
            âââ discovery image copy                 â TODO
            âââ bundle manifest (sha256 + git SHAs) â TODO
```

### 3.3 Transfer (operator-triggered)

**Status: Not yet implemented.** The `content_export_copies` role copies the staged bundle to physical transfer media. This is a distinct action from export assembly and must be run only when transfer is authorized.

```
[planned] content_export_copies role
    âââ copies /var/lib/pulp/exports/<destination_server>/
        to /run/media/ansiblerunner/export           â destination_folder in host_vars
```

### 3.4 Highside build (disconnected satellite)

**Status: Partially implemented.** The `satellite_disconnected_pre` role and `content_imports` role exist. No helper script (`build_sat_primary_disconnected.sh`) exists yet.

```
[planned] build_sat_primary_disconnected.sh          â TODO: does not exist yet
    âââ main.yml (limited to discosatellite group)
            âââ satellite_disconnected_pre   (when: satellite_disconnected)
            â       âââ unmount existing ISO mounts
            â       âââ create satellite_disconnected_root
            â       âââ copy and mount RHEL OS ISO
            â       âââ copy and mount Satellite install ISO
            â       âââ template OS .repo file
            â       âââ assert BaseOS + AppStream repos present
            â       âââ dnf update (offline)
            â       âââ install Satellite binaries from DVD
            âââ satellite_pre                (unconditional; satellite_pre_use_idm: false)
            âââ satellite                    (installs Satellite)
            âââ satellite_post               (unconditional)
            âââ redhat_manifests             (generate: false â uses pre-existing zip)
            âââ subscription_manifests       (unconditional)
            âââ content_credentials          (unconditional)
            â   [repository_sets skipped]
            â   [repositories skipped]
            â   [start_synchronization skipped]
            âââ content_imports              (when: satellite_disconnected AND satellite_import_content)
            âââ lifecycle_environments       (unconditional)
            â   [sync_plans skipped]
            âââ content_views                (unconditional)
            âââ [remaining roles]            (all unconditional)
```

---

## 4. Content Export Process

### 4.1 Export types

The `content_exports` role supports three export types. All are defined in `host_vars/satellite/content_exports.yml`. Only one entry is active at a time.

| Type | Required fields | Format support | Use case |
|---|---|---|---|
| `library` | `organization` | `importable` (chunked) or `syncable` | Full library export â standard path for disconnected builds |
| `cv_version` | `organization`, `content_view`, `content_view_version` | `importable` or `syncable` | Export a specific content view version |
| `repository` | `organization`, `product`, `repository` | `importable` or `syncable` | Export a single repository |

**Note:** `syncable` format does not support chunking. Use `importable` format when chunk_size_gb is specified.

### 4.2 Active export configuration (lowside)

The lowside `content_exports.yml` defines a library export with the following active settings:

| Field | Value | Notes |
|---|---|---|
| `name` | `Library` | Human label; matched by `content_export_copies` |
| `type` | `library` | Full library export |
| `organization` | `{{ satellite_organization }}` | Rendered at runtime |
| `format` | `importable` | Required for chunking |
| `chunk_size_gb` | `2` | 2 GB chunks |
| `destination_server` | `discosatellite1.{{ _runtime_global_domain_name }}` | FQDN of the highside Satellite |
| `fail_on_missing_content` | `true` | Abort if any content is unavailable |
| `incremental` | `false` | Full export each time |

### 4.3 Where exports land

Satellite writes export chunks to:

```
/var/lib/pulp/exports/<destination_server>/
```

The `content_exports` role also generates a `metadata.json` via `hammer content-export generate-metadata` and writes a timestamped `_content_imports.yml` file to this directory via `generate_content_imports_file.yml`. This auto-generated import file is the canonical input for the highside import role â the `content_imports.yml` in the highside host_vars is intentionally left as a commented-out stub.

### 4.4 Planned additional bundle artifacts

The following artifacts are planned to be assembled in the same staging directory as part of the future `export_disconnected.yml` playbook. They are not yet implemented.

| Artifact | Source location | Staging method |
|---|---|---|
| rhis-builder-inventory archive | Provisioner (tar.gz of inventory tree, excluding `.git`) | Pushed from provisioner to Satellite staging dir |
| rhis-provisioner container image | Provisioner (`podman save`) | Pushed from provisioner to Satellite staging dir |
| Compliance-as-code Ansible roles | `/etc/ansible/roles/` on connected Satellite (already cloned by `imported_git_repos`) | Tarred from on-disk location; git HEAD SHA captured per repo |
| Foreman discovery image | TFTP directory on connected Satellite (installed by `satellite-installer`) | Located and copied to staging dir |
| Bundle manifest | Generated on Satellite | sha256 checksums + git SHAs + export history ID + vault password checklist |

---

## 5. Transfer Process

### 5.1 Overview

The transfer step is deliberately separated from export assembly. It is an operator-triggered action run only when physical transfer to the highside is authorized.

### 5.2 Content export copies (implemented in host_vars, role not yet implemented)

The `content_export_copies` host_vars variable is defined in `host_vars/satellite/content_export_copies.yml`. The corresponding role does not yet exist in rhis-builder-satellite.

| Field | Value | Notes |
|---|---|---|
| `name` | `Library` | Must match the `name` in `content_exports` |
| `type` | `library` | Must match the `type` in `content_exports` |
| `destination_server` | `discosatellite1.{{ _runtime_global_domain_name }}` | Identifies which export to copy |
| `export_version` | `1.0` | Identifies the specific export version |
| `destination_folder` | `/run/media/ansiblerunner/export` | Mount point for removable media |

### 5.3 Artifacts that must cross the air gap

| Artifact | Method | Notes |
|---|---|---|
| Export tarball chunks (2 GB each) | Physical media (USB/external drive) or secure channel | Written by `content_export_copies` role to `destination_folder` |
| `metadata.json` | Included in export staging directory | Required for `hammer content-export generate-metadata` |
| Auto-generated `_content_imports.yml` | Included in export staging directory | Used as input to highside `content_imports` role |
| rhis-builder-inventory archive | Included in export bundle | Vault-encrypted vars travel with the bundle |
| rhis-provisioner container image | Included in export bundle | Required to run playbooks on the highside |
| Compliance-as-code Ansible roles tarball | Included in export bundle | |
| Foreman discovery image | Included in export bundle | |
| Bundle manifest | Included in export bundle | Operator checklist for verifying bundle integrity |
| **Vault password** | **Separate trusted channel â never in the bundle** | Must be communicated to the highside operator independently |

---

## 6. Highside Import Process

### 6.1 Pre-installation: satellite_disconnected_pre role

Before the standard `satellite_pre` role runs, the `satellite_disconnected_pre` role prepares the host to install Satellite from offline media. This role is fully implemented.

**Execution order:**

1. Unmount any existing ISO mount points (idempotency cleanup)
2. Create the `satellite_disconnected_root` directory
3. Copy the RHEL OS ISO and the Satellite install ISO to that root (validates and overwrites if present)
4. Mount both ISOs read-only (iso9660) at their configured mount paths
5. Template the OS `.repo` file from `satellite_os_repo_template_name`
6. Run `dnf repolist` and assert that `RHEL-BaseOS` and `RHEL-AppStream` are present
7. Run a full `dnf update` against the offline repos
8. Run `{{ satellite_install_repo_mount }}/install_packages` to install Satellite binaries from the DVD

**Variables required by this role** (all defined in `host_vars/discosatellite/main.yml`):

| Variable | Purpose |
|---|---|
| `satellite_disconnected_root` | Base directory for ISO staging |
| `satellite_os_iso_source` | Path to the RHEL OS ISO |
| `satellite_install_iso_source` | Path to the Satellite install ISO |
| `satellite_os_repo_mount` | Mount point for the OS ISO |
| `satellite_install_repo_mount` | Mount point for the Satellite install ISO |
| `satellite_os_repo_template_name` | Jinja2 template name for the `.repo` file |
| `satellite_os_repo_template_dest` | Destination path for the templated `.repo` file |

### 6.2 Manifest upload

Unlike the lowside, the highside cannot generate a manifest via the CDN API. The `manifests.yml.j2` for the highside sets `generate: false` and expects a pre-existing zip file at the configured source path.

> **Licensing requirement: the highside manifest must be a separate allocation.**
> Red Hat subscription terms require each registered Satellite to have its own manifest
> allocation created independently in the [Red Hat Customer Portal](https://access.redhat.com/management/subscription-allocations).
> The lowside manifest cannot be copied, re-used, or re-exported for the highside — even
> though the highside satellite operates in Simple Content Access (SCA) mode and cannot
> phone home to validate subscription counts. The contractual obligation exists regardless
> of what Satellite technically enforces. Create a distinct manifest allocation for the
> highside Satellite in the portal before beginning the highside build.

The manifest zip must be obtained and staged on the lowside **before running the export**:

1. Create a separate allocation in the Red Hat Customer Portal for the highside Satellite
2. Download the manifest ZIP from the portal
3. Copy it to `deployments/<name>/files/manifests/` in your rhis-builder-inventory — this directory is included in the export bundle automatically
4. Update `host_vars/<discosatellite>/manifests.yml` — set `source:` to the manifest filename so `redhat_manifests` can find it when the highside build runs

The export bundle assembly step picks up everything in `files/manifests/` and transfers it with the bundle. If the manifest is not staged and the configuration is not updated before export, the highside build will fail when `redhat_manifests` runs.

### 6.3 Content import

The `content_imports` role runs only when both conditions are true:

```yaml
when: satellite_disconnected and satellite_import_content
```

The `satellite_import_content` flag is a convenience override. Operators can re-run the full main.yml play without repeating the slow import step by setting `satellite_import_content: false`.

The `content_imports` role supports the same three types as `content_exports`:

| Type | Required fields |
|---|---|
| `library` | `organization`, `import_path` |
| `cv_version` | `organization`, `import_path`, `content_view` |
| `repository` | `organization`, `import_path`, `product`, `repository` |

The auto-generated `_content_imports.yml` from the lowside export is the intended input for this role. The `content_imports.yml` stub in `host_vars/discosatellite/` is left fully commented out because the export role writes the canonical import configuration at export time.

**Import path convention:**

```
/var/lib/pulp/imports/<destination_server>/
```

The `metadata_file` field points to the `metadata.json` generated by the lowside export.

---

## 7. Configuration Differences

### 7.1 main.yml â Disconnected mode flag

| Variable | Connected satellite | Disconnected satellite |
|---|---|---|
| `satellite_disconnected` | `false` | `true` |
| `satellite_cdn_configuration_type` | (not set) | `export_sync` |
| `satellite_import_content` | (not applicable) | `true` (set to `false` to skip re-import on re-runs) |

### 7.2 IdM integration

This is the single most significant configuration difference. Setting `satellite_pre_use_idm: false` cascades into multiple downstream differences.

| Aspect | Connected satellite | Disconnected satellite |
|---|---|---|
| `satellite_pre_use_idm` | `true` | `false` |
| Satellite installer IPA auth | `--foreman-ipa-authentication true` | `--foreman-ipa-authentication false` |
| DNS update method | `nsupdate_gss` (Kerberos) | (not configured) |
| Realm enrollment | Active | Commented out |
| IPA-issued TLS certificates | `--certs-server-*` options active | Commented out |
| Rex Kerberos | Active (conditional on `rex_kerberos_enabled`) | Not applicable |
| External LDAP/IdM group mappings | `satellite_user_groups_external` defined | Not defined |
| User groups | `Operators`, `ComplianceAuditors`, `Administrators` | `Operators` only |
| `keytab_retrieval_dn` | References `ipa_keytab_dn_vault` | References `ipa_keytab_dn` (non-vault) |

### 7.3 Manifest handling

| Aspect | Connected satellite | Disconnected satellite |
|---|---|---|
| File format | Plain YAML (`manifests.yml`) | Jinja2 template (`manifests.yml.j2`) |
| `generate` | `true` | `false` |
| CDN credentials | Required (`cdn_account_number`, `cdn_username`, `cdn_password`) | Not used |
| Manifest source | CDN API | Pre-existing zip file uploaded from transfer bundle |

### 7.4 Content synchronisation

| Step | Connected satellite | Disconnected satellite |
|---|---|---|
| `repository_sets` role | Runs | Skipped |
| `repositories` role | Runs | Skipped |
| `start_synchronization` | Runs | Skipped |
| `sync_plans` role | Runs | Skipped |
| `content_imports` role | Skipped | Runs (when `satellite_import_content: true`) |

### 7.5 Global parameters

| Parameter | Connected satellite | Disconnected satellite |
|---|---|---|
| `ansible_controller_api_url` | Hardcoded hostname `aapcontroller24.*` | Dynamic: `groups['aap_controllers'][0]` |
| `ansible_job_template_id` | `125` | `13` |
| `binding_json` / NBDE Tang config | Present | Not present (no Tang servers reachable) |
| `binding_type` | `sss` (Shamir's Secret Sharing) | Not present |
| `use_NBDE` | `false` (infrastructure configured, toggle off) | Not present |
| `host_registration_lightspeed` | `true` | Not present |
| `enable_cloud_remediations` | `true` | Not present |
| `remove_default_passphrase` | `false` (NBDE handles it) | `true` |
| `grubmenu_pass` | `""` (empty) | Pre-computed PBKDF2 hash |

### 7.6 OS version variable

| Context | Connected satellite | Disconnected satellite |
|---|---|---|
| `sat_repository_ids` OS version source | `{{ ansible_distribution_major_version }}` (runtime fact) | `{{ rhis_satellite_os_major_version }}` (static inventory var) |

This is necessary because the disconnected satellite may not have Ansible facts gathered in the same environment where content IDs are resolved.

### 7.7 Discovery configuration

The disconnected satellite is the primary PXE/bare-metal discovery endpoint.

| Aspect | Connected satellite | Disconnected satellite |
|---|---|---|
| `discovery_config.yml` | Minimal | Full â custom fact evaluation, PXELinux/PXEGrub/PXEGrub2 remastering templates, multiple global default boot templates |
| `settings_discovery.yml` | All settings commented out | Active: `discovery_hostname` (`["chassis_position", "discovery_bootif"]`), `discovery_prefix` (`"nuc-"`) |
| Foreman proxy discovery install images | `true` (satellite installer flag) | `false` |

### 7.8 Hostgroup differences

| Aspect | Connected satellite | Disconnected satellite |
|---|---|---|
| RHEL 10 minor version | `10.2` | `10.1` |
| `hg_x86_64_centos79_vm` | Commented out (deprecated) | Active |
| `hg_x86_64_oel79_vm` | Commented out (deprecated) | Active |
| `content_source` on RHEL 9 VM hostgroups | Explicitly set to `groups['sat_primary'][0]` | Not set |
| `lifecycle_environment` on RHEL 9 VM hostgroups | `Development` | Not set |

### 7.9 Email subject prefix

| Connected satellite | Disconnected satellite |
|---|---|
| `"[satellite.{{ _runtime_global_domain_name }}]"` | `"[{{ groups['sat_primary'][0] }}]"` â evaluates to actual FQDN at runtime |

---

## 8. Known Limitations and Risks

### 8.1 Known bug: basevars_global_domain_name variable name

**File:** `host_vars/discosatellite/content_exports.yml.j2`, line 30

The `destination_server` field uses `basevars_global_domain_name` instead of the correct `_runtime_global_domain_name`. This will cause the `destination_server` to render as a literal string rather than the actual domain name at template generation time.

**Status:** Tracked in TODO.md. Fix is pending.

**Fix required:**
```
# current (incorrect):
destination_server: "discosatellite1.{{ basevars_global_domain_name }}"

# correct:
destination_server: "discosatellite1.{{ _runtime_global_domain_name }}"
```

The same bug exists in `quay.yml.j2`.

### 8.2 No disconnected build helper script

There is a `build_sat_primary_connected.sh` script in rhis-provisioner-container. The equivalent `build_sat_primary_disconnected.sh` does not exist. Operators must currently invoke `main.yml` manually with the correct inventory and limit flags.

**Status:** Tracked in TODO.md as a required implementation item.

### 8.3 Export bundle assembly not automated

Steps 2â6 of the export bundle (inventory archive, container image, compliance roles, discovery image, bundle manifest) have no automation. Only the `content_exports` role (step 1, Library export) is implemented. There is no `export_disconnected.yml` playbook and no `content_export_copies` role.

**Status:** Tracked in TODO.md. Five implementation items are pending.

### 8.4 Vault password must travel separately

The vault password cannot be included in the transfer bundle under any circumstances. It must cross the air gap via a separate trusted channel. The planned bundle manifest will include a checklist item for this, but enforcement is entirely operator-dependent.

### 8.5 Incremental exports not used

The active export configuration sets `incremental: false` â every export is a full Library export. For large content libraries this produces significant data volume on every transfer cycle. Incremental exports are supported by Satellite and the role, but are not currently configured.

### 8.6 satellite_import_content flag management

Setting `satellite_import_content: false` to skip a slow re-import on subsequent play runs is a manual operator action. There is no automation to detect whether content has already been imported or whether new content is available. Operators must manage this flag explicitly.

### 8.7 Disco inventory hostname loop variable

In `disco_inventory.j2`, the loop that populates `sat_primary` iterates using `rhis_system_count.discosatellite` but the hostname is hardcoded to `discosatellite1.{{ basevars_global_domain_name }}` â the loop variable `num` is never interpolated into the hostname. This means `rhis_system_count.discosatellite` values greater than 1 will produce duplicate inventory entries. The current configured value is `discosatellite: 1`, which avoids the problem in practice.

### 8.8 No NBDE/Tang in the disconnected environment

The connected satellite configures Tang server bindings for NBDE (Network-Bound Disk Encryption). This is not available in the highside environment because there are no outbound Tang servers reachable. Disk encryption on highside hosts must use a different mechanism, or NBDE must be deployed entirely within the air-gapped network with dedicated Tang servers.

### 8.9 Export version pinned at 1.0

The `content_export_copies.yml` configuration pins `export_version: "1.0"`. This must be updated manually to match the actual export version ID after each export run. There is no automation to detect the current export version.

---

## 9. Inventory Template Requirements

### 9.1 Host_vars file inventory

The following files must exist under `inventory_template/host_vars/discosatellite/`.

| File | Format | Status | Purpose |
|---|---|---|---|
| `main.yml` | Plain YAML | Required | Core satellite vars including `satellite_disconnected: true`, ISO paths, CDN type |
| `satellite_pre.yml` | Plain YAML | Required | IdM flags (`satellite_pre_use_idm: false`), firewall, SSL, OS repo IDs |
| `satellite_installer.yml` | Plain YAML | Required | Installer CLI options; must include `--foreman-ipa-authentication false` |
| `manifests.yml.j2` | Jinja2 template | Required | `generate: false`; source filename interpolated from `basevars_global_domain_name` |
| `content_exports.yml.j2` | Jinja2 template | Required (with bug fix pending) | Defines outbound exports from the connected satellite targeting the highside |
| `content_imports.yml` | Plain YAML (stub) | Present (stub only) | Intentionally commented out; auto-generated by `content_exports` role at export time |
| `content_export_copies.yml` | Plain YAML | Required | Defines copy to transfer media; role not yet implemented |
| `content_uploads.yml` | Plain YAML | Present | Manual content upload support (not present in connected satellite host_vars) |
| `hostgroups.yml` | Plain YAML | Required | Hostgroup tree; note CentOS79/OEL79 active, no `content_source` on RHEL 9 VMs |
| `lifecycle_environments.yml` | Plain YAML | Required | Standard lifecycle environments |
| `content_views.yml` | Plain YAML | Required | Content view definitions |
| `domains.yml` | Plain YAML | Required | Domain configuration (identical to connected satellite) |
| `subnets.yml` | Plain YAML | Required | Subnet configuration (identical to connected satellite) |
| `global_parameters.yml` | Plain YAML | Required | Leaner parameter set; no NBDE, no Lightspeed, no cloud remediations |
| `settings_general.yml` | Plain YAML | Required | Identical to connected satellite |
| `settings_email.yml` | Plain YAML | Required | FQDN-based subject prefix |
| `settings_discovery.yml` | Plain YAML | Required | Active discovery settings (prefix `nuc-`, chassis_position fact) |
| `discovery_config.yml` | Plain YAML | Required | Full PXE remastering templates and boot config |
| `user_group_role.yml.j2` | Jinja2 template | Required | Operators group only; no `satellite_user_groups_external` |
| `template_repos_jobs.yml` | Plain YAML | Present (not in connected sat) | Foreman template sync repos for job templates |
| `template_repos_provisioning.yml` | Plain YAML | Present (not in connected sat) | Foreman template sync repos for provisioning templates |
| `template_repos_ptables.yml` | Plain YAML | Present (not in connected sat) | Foreman template sync repos for partition tables |

### 9.2 Required variables in main.yml

| Variable | Example value | Notes |
|---|---|---|
| `satellite_disconnected` | `true` | Activates the disconnected code path in main.yml |
| `satellite_import_content` | `true` | Set `false` to skip re-import on subsequent runs |
| `satellite_cdn_configuration_type` | `export_sync` | Tells Satellite not to use CDN |
| `satellite_disconnected_root` | `/mnt/satellite_disconnected` | Base directory for ISO staging |
| `satellite_os_iso_source` | Path to RHEL OS ISO | Must be accessible at play time |
| `satellite_install_iso_source` | Path to Satellite install ISO | Must be accessible at play time |
| `satellite_os_repo_mount` | Mount point for OS ISO | |
| `satellite_install_repo_mount` | Mount point for Satellite install ISO | |
| `satellite_os_repo_template_name` | Template name for `.repo` file | |
| `satellite_os_repo_template_dest` | Destination path for templated `.repo` | |
| `rhis_satellite_os_major_version` | `9` | Static var used for repo IDs; replaces `ansible_distribution_major_version` |

### 9.3 Required variables in satellite_pre.yml

| Variable | Value | Notes |
|---|---|---|
| `satellite_pre_use_idm` | `false` | Must be explicitly false; drives all IdM-dependent role skips |
| `ipa_server_fqdn` | `{{ groups['idm_primary'][0] }}` | Declared but IdM integration disabled; present to support future enablement |
| `keytab_retrieval_dn` | `{{ ipa_keytab_dn }}` | References non-vault var (unlike connected satellite which uses `ipa_keytab_dn_vault`) |

### 9.4 Required variables in manifests.yml.j2

| Variable | Value | Notes |
|---|---|---|
| `generate` | `false` | CDN API not reachable; manifest must be pre-existing |
| `source` | Path to manifest zip | Must be present before `redhat_manifests` role runs |
| `organization` | `{{ satellite_organization }}` | |
| `state` | `present` | |

### 9.5 Inventory file

The highside inventory is generated from `inventory_template/disco_inventory.j2`. The relevant count variable in `inventory_basevars.yml` is:

```yaml
rhis_system_count:
  discosatellite: 1
```

The count must remain `1` until the latent hostname loop bug in `disco_inventory.j2` is resolved.

---

## Implementation Status Summary

| Component | Status |
|---|---|
| `satellite_disconnected_pre` role | Implemented |
| `content_exports` role (Library export) | Implemented |
| `content_imports` role | Implemented |
| `discosatellite` host_vars (all files) | Implemented (with `basevars_global_domain_name` bug pending fix) |
| `disco_inventory.j2` | Implemented (with latent loop variable bug) |
| `export_disconnected.yml` playbook | TODO |
| `content_export_copies` role | TODO |
| `build_sat_disconnected_export.sh` helper script | TODO |
| `build_sat_primary_disconnected.sh` helper script | TODO |
| Bundle manifest generation | TODO |
| Inventory archive staging | TODO |
| Container image staging (`podman save`) | TODO |
| Compliance-as-code roles staging | TODO |
| Discovery image staging | TODO |
| `basevars_global_domain_name` bug fix in `content_exports.yml.j2` | TODO |"
---
