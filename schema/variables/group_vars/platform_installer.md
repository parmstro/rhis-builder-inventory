# Group: platform_installer — AAP Platform Installer Variables

Schema Version: 1.0.0

These variables configure Ansible Automation Platform (AAP) after installation, including credentials, organizations, inventories, projects, job templates, workflow templates, execution environments, notification integrations, and LDAP authentication settings. They are consumed by the `ansible.controller` collection.

Upstream collection: `ansible.controller` — refer to the [collection documentation](https://galaxy.ansible.com/ui/repo/published/ansible/controller/) for authoritative variable references and allowed values. The correct version of `ansible.controller` depends on the version of AAP being deployed:

| AAP version | `ansible.controller` version |
|---|---|
| 2.4 and earlier | `4.5.21` |
| 2.5 and later | `4.6+` |

> **Note:** AAP 2.4 support is deprecated in RHIS. New deployments should use AAP 2.6 or later.

---

## Core Platform Settings

**Source file:** `FQD.aap_main.yml`

Top-level connection and authentication variables for AAP and supporting services. These scalars wire together dynamically resolved hostnames (from inventory groups) with vault-sourced secrets.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `satellite_url` | string | `"https://{{ groups['sat_primary'][0] }}"` | HTTPS URL for the Satellite server, resolved from the `sat_primary` inventory group | Satellite-interacting roles and templates |
| `rhis_default_git_dest` | string | `"~/rhis_ee_repos"` | Local filesystem path where Execution Environment (EE) git repos are cloned during EE build | EE build tasks |
| `redhat_container_registry_url` | string | `"registry.redhat.io"` | Red Hat container registry base URL | EE pull/push tasks |
| `redhat_registry_username` | string | _(from vault)_ | Username for registry.redhat.io authentication | EE image pulls |
| `redhat_registry_password` | string | _(from vault)_ | Password for registry.redhat.io authentication | EE image pulls |
| `redhat_automation_hub_token` | string | _(from vault)_ | API token for Red Hat Automation Hub (cloud.redhat.com) | Hub credentials, collection downloads |
| `redhat_automation_hub_token_refresh_cmd` | string | _(from vault)_ | Shell command used to refresh the Automation Hub token | Token refresh automation |
| `private_hub_token` | string | _(from vault)_ | API token for the on-premise Private Automation Hub | Private Hub credentials |
| `private_hub_url` | string | `"https://{{ groups['aap_hubs'][0] }}/api/galaxy/"` | Galaxy API URL for the Private Hub, resolved from the `aap_hubs` inventory group | Private Hub credentials |
| `aap_platform_host` | string | `"{{ groups['aap_controllers'][0] }}"` | Hostname of the primary AAP controller, resolved from the `aap_controllers` inventory group | Controller API connections |
| `aap_platform_username` | string | _(from vault)_ | AAP admin username for API authentication | Controller API connections |
| `aap_platform_password` | string | _(from vault)_ | AAP admin password for API authentication | Controller API connections |
| `aap_ldap_domain_map` | string | _(computed)_ | LDAP DC string computed from `_runtime_global_domain_name` (e.g. `dc=example,dc=com`). Prefixed with `_` convention would mark this computed, but it is a plain variable used in LDAP settings | LDAP settings, credential inputs |
| `aap_admin_username` | string | _(from vault)_ | AAP admin username (duplicates `aap_platform_username` for role compatibility) | Controller configuration roles |
| `aap_admin_password` | string | _(from vault)_ | AAP admin password (duplicates `aap_platform_password` for role compatibility) | Controller configuration roles |
| `active_controller` | string | `"{{ groups['aap_controllers'][0] }}"` | Convenience alias for the active controller FQDN | Role targeting |
| `active_aap_hub` | string | `"{{ groups['aap_hubs'][0] }}"` | Convenience alias for the active Private Hub FQDN | Role targeting |
| `aap_validate_certs` | bool | `false` | Whether to validate TLS certificates when connecting to the AAP controller | All controller API calls |
| `aap_hub_validate_certs` | bool | `false` | Whether to validate TLS certificates when connecting to the Private Hub | Hub API calls |
| `ah_container_token` | string | `""` | Container registry token for Automation Hub; empty by default and populated at runtime if needed | EE registry authentication |
| `satellite_ansible_callback_config_key` | string | _(from vault)_ | Host config key used by Satellite to trigger AAP Ansible Callback job templates | SOE callback job templates |
| `cleanup_installer_keys` | bool | `false` | Whether to remove installer SSH keys after AAP post-install configuration | Post-install cleanup tasks |

---

## CDN Manifest Configuration

**Source file:** `FQD.aap_manifest.yml`

Defines the `redhat_manifest` mapping used to generate and upload a Red Hat subscription manifest to the AAP controller. Only non-vault fields are documented here.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `redhat_manifest` | dict | — | Top-level manifest configuration object | Manifest upload role |
| `redhat_manifest.name` | string | `"{{ ansible_fqdn }}"` | Manifest name; defaults to the FQDN of the controller host | CDN/manifest API |
| `redhat_manifest.content_access_mode` | string | `"org_environment"` | Subscription access mode; `"org_environment"` enables Simple Content Access (SCA) | Manifest generation |
| `redhat_manifest.path` | string | `"/tmp/{{ ansible_fqdn }}.zip"` | Temporary local path where the manifest ZIP is written before upload | Manifest upload role |
| `redhat_manifest.portal_url` | string | `"https://subscription.rhsm.redhat.com"` | Red Hat Subscription Management portal URL | Manifest download |
| `redhat_manifest.state` | string | `"present"` | Desired state of the manifest on the controller (`present` or `absent`) | Manifest upload role |
| `redhat_manifest.validate_certs` | bool | `false` | Whether to validate TLS certificates when contacting the RHSM portal | Manifest download |

> Note: `redhat_manifest.account`, `redhat_manifest.cdn_username`, `redhat_manifest.cdn_password`, and `redhat_manifest.subs` reference vault variables and are not documented here.

---

## LDAP / Authentication Settings

**Source file:** `FQD.aap_settings.yml`

Configures AAP's LDAP authentication backend via the `aap_settings` list. The single entry shown targets the `authentication` settings category. All LDAP DN values are interpolated from `aap_ldap_domain_map` (computed in `FQD.aap_main.yml`).

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `aap_settings` | list of dicts | — | List of AAP settings blocks, each targeting a named settings category | `ansible.controller.settings` role |

### `aap_settings[]` entry schema

| Field | Type | Description |
|---|---|---|
| `name` | string | Settings category name (e.g. `"authentication"`) |
| `settings` | dict | Key/value pairs matching AAP Django settings for that category |

### `aap_settings[].settings` fields (authentication category)

| Setting key | Type | Description |
|---|---|---|
| `AUTH_LDAP_SERVER_URI` | string | LDAP server URI; uses `ipa_server_fqdn` on port 389 |
| `AUTH_LDAP_USER_DN_TEMPLATE` | string | DN template for user lookups; uses `uid=%(user)s` pattern under `cn=users,cn=accounts` |
| `AUTH_LDAP_GROUP_TYPE` | string | LDAP group type class; set to `NestedMemberDNGroupType` for IPA-style nested groups |
| `AUTH_LDAP_REQUIRE_GROUP` | string | DN of the LDAP group required for any AAP login; maps to `aapgroup-user` |
| `AUTH_LDAP_GROUP_SEARCH` | JSON string | Three-element JSON array: `[base_dn, scope, filter]` for group enumeration |
| `AUTH_LDAP_GROUP_TYPE_PARAMS` | dict | Parameters for the group type class; `member_attr: "member"`, `name_attr: "cn"` |
| `AUTH_LDAP_USER_FLAGS_BY_GROUP` | JSON string | Maps AAP user flags to LDAP group DNs; `is_superuser` granted to `aapgroup-administrator` members |
| `AUTH_LDAP_USER_ATTR_MAP` | dict | Maps AAP user fields to LDAP attributes: `email→mail`, `first_name→givenName`, `last_name→surname` |

> `AUTH_LDAP_BIND_DN` and `AUTH_LDAP_BIND_PASSWORD` reference vault variables and are not documented here.

---

## Organizations

**Source file:** `FQD.aap_organizations.yml`

Defines AAP organizations via the `aap_organizations` list. The template ships with a single `Default` organization.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `aap_organizations` | list of dicts | — | List of organization definitions to create/manage on the controller | `ansible.controller.organizations` role |

### `aap_organizations[]` entry schema

| Field | Type | Description |
|---|---|---|
| `name` | string | Organization name |
| `description` | string | Human-readable description |
| `default_environment` | string | Name of the default execution environment for this organization |
| `galaxy_credentials` | list of strings | Ordered list of credential names used for collection resolution |
| `state` | string | `present` or `absent` |

---

## Credential Types

**Source file:** `FQD.aap_credential_types.yml`

Defines custom credential types via the `aap_credential_types` list. Each type exposes operator-specific fields and injects them as extra variables into job runs. The `!unsafe` tag is used in injectors to pass Jinja2 variable references literally without Ansible evaluating them at inventory time.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `aap_credential_types` | list of dicts | — | List of custom credential type definitions | `ansible.controller.credential_types` role |

### `aap_credential_types[]` entry schema

| Field | Type | Description |
|---|---|---|
| `name` | string | Unique credential type name |
| `description` | string | Human-readable description |
| `kind` | string | Must be `"cloud"` or `"net"` for custom types |
| `inputs` | dict | Defines the credential form fields (`fields` list and `required` list) |
| `inputs.fields[]` | list of dicts | Each field: `id` (string), `type` (`"string"`), `label` (string), optionally `secret: true` |
| `inputs.required` | list of strings | Field IDs that must be populated |
| `injectors` | dict | Maps credential fields to job variables; supports `extra_vars` sub-key |
| `injectors.extra_vars` | dict | Variable name → `!unsafe "{{ field_id }}"` mappings injected as job extra vars |

### Defined credential types

| Name | Purpose | Injected extra vars |
|---|---|---|
| `rhis_rhsm_operator` | Red Hat Subscription Manager (CDN) credentials | `rhsm_org`, `rhsm_username`, `rhsm_password` |
| `rhis_idm_operator` | Red Hat Identity Management (IPA) admin credentials | `ipa_admin_password`, `ipa_admin_principal`, `ipa_realm` |
| `rhis_satellite_operator` | Red Hat Satellite admin credentials with URL | `satellite_password`, `satellite_username`, `satellite_url` |
| `rhis_vmware_operator` | VMware vCenter credentials with datacenter | `vcenter_password`, `vcenter_username`, `vcenter_hostname`, `datacenter_name` |

---

## Credentials

**Source file:** `FQD.aap_credentials.yml`

Defines AAP credentials via the `aap_credentials` list. Covers Hub API tokens, source control, machine, vault, Satellite, container registry, and the four custom RHIS operator credential types. Secret input values all reference vault variables.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `aap_credentials` | list of dicts | — | List of credential definitions to create/manage on the controller | `ansible.controller.credentials` role |

### `aap_credentials[]` entry schema

| Field | Type | Description |
|---|---|---|
| `name` | string | Unique credential name within the organization |
| `organization` | string | Organization that owns this credential |
| `credential_type` | string | Built-in or custom credential type name |
| `description` | string | Human-readable description |
| `state` | string | `present` or `absent` |
| `inputs` | dict | Type-specific input fields (see credential type definition for field names); secret fields reference vault variables |

### Defined credentials

| Name | Credential type | Purpose |
|---|---|---|
| `Automation_Hub_validated` | Ansible Galaxy/Automation Hub API Token | Red Hat cloud Hub — validated content repo |
| `Automation_Hub_rh_certified` | Ansible Galaxy/Automation Hub API Token | Red Hat cloud Hub — rh-certified repo |
| `Private_Hub_community` | Ansible Galaxy/Automation Hub API Token | On-premise Hub — community content repo |
| `Private_Hub_rh_certified` | Ansible Galaxy/Automation Hub API Token | On-premise Hub — rh-certified repo |
| `Private_Hub_validated` | Ansible Galaxy/Automation Hub API Token | On-premise Hub — validated content repo |
| `ansible_github` | Source Control | GitHub access for rhis-builder project repos |
| `default_machine` | Machine | Default SSH credential for demo/test systems |
| `idm_machine` | Machine | SSH credential targeting IdM-joined systems |
| `default_vault` | Vault | Ansible Vault passphrase for demo projects |
| `prod_satellite` | Red Hat Satellite 6 | API credential for the production Satellite server |
| `aaphub24_containers` | Container Registry | Pull access to EEs stored in the Private Hub registry |
| `rhis_{{ _runtime_global_domain_name }}_rhsm` | `rhis_rhsm_operator` | CDN subscription credentials for this domain |
| `rhis_{{ _runtime_global_domain_name }}_satellite` | `rhis_satellite_operator` | Satellite operator credentials for this domain |
| `rhis_{{ _runtime_global_domain_name }}_idm` | `rhis_idm_operator` | IdM admin credentials for this domain |
| `rhis_{{ _runtime_global_domain_name }}_vmware1` | `rhis_vmware_operator` | vCenter credentials for VMware environment 1 |

---

## Galaxy/Hub Organization Credentials

**Source file:** `FQD.aap_organization_galaxy_credentials.yml`

Assigns an ordered list of Galaxy/Hub credentials to organizations via the `org_galaxy` list. This controls the collection resolution order used when syncing projects.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `org_galaxy` | list of dicts | — | List of organization-to-galaxy-credential mappings | `ansible.controller.organization_galaxy_credentials` role |

### `org_galaxy[]` entry schema

| Field | Type | Description |
|---|---|---|
| `name` | string | Organization name to configure |
| `galaxy_credentials` | list of strings | Ordered credential names for collection resolution; searched left-to-right |

The `Default` organization is configured with credentials in this order: `Automation_Hub_validated`, `Automation_Hub_rh_certified`, `Ansible Galaxy`, `Private_Hub_validated`, `Private_Hub_rh_certified`.

---

## Inventories

**Source file:** `FQD.aap_inventories.yml`

Defines AAP inventories via the `aap_inventories` list. Most inventories are plain containers; `convert2rhel_pipeline_inventory` embeds a substantial set of inventory-level variables that are passed to all hosts in that inventory.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `aap_inventories` | list of dicts | — | List of inventory definitions to create/manage on the controller | `ansible.controller.inventories` role |

### `aap_inventories[]` entry schema

| Field | Type | Description |
|---|---|---|
| `name` | string | Inventory name |
| `description` | string | Human-readable description |
| `organization` | string | Owning organization |
| `state` | string | `present` or `absent` |
| `variables` | dict | Optional inventory-level variables applied to all hosts |

### Defined inventories

| Name | Purpose |
|---|---|
| `{{ groups['sat_primary'][0] }}` | Dynamic inventory populated from the Satellite source |
| `TheSatellite` | Static single-host inventory for the Satellite server |
| `TheAutomationController` | Static single-host inventory for the AAP controller |
| `TheProvisioner` | Alias inventory for the AAP controller; used as the execution target for provisioning templates |
| `SOE_pipeline_inventory` | Static hosts for Development SOE pipeline testing (JBoss, LAMP, WordPress) |
| `SOE_qa_pipeline_inventory` | Static hosts for Qualification SOE pipeline testing |
| `convert2rhel_pipeline_inventory` | Static hosts for convert2RHEL demo; carries VMware, Satellite, and LVM snapshot variables |

### `convert2rhel_pipeline_inventory` inventory variables

| Variable | Type | Description |
|---|---|---|
| `host_platform` | string | Target platform type (`"vmware"`) |
| `disk_search_pattern` | string | Regex pattern for identifying disks (e.g. `"sd.*"`) |
| `snapshot_disk_size_gb` | string | Size in GB for the c2r snapshot disk |
| `snapshot_disk_provision_type` | string | VMware disk provisioning type (`"thin"`) |
| `snapshot_disk_datastore` | string | VMware datastore name for snapshot disks |
| `snapshot_disk_state` | string | Desired disk state (`"present"`) |
| `snapshot_disk_controller` | int | SCSI controller number |
| `snapshot_disk_unit` | int | SCSI unit number for the snapshot disk |
| `snapshot_disk_scsi_type` | string | SCSI adapter type (`"paravirtual"`) |
| `snapshot_disk_mode` | string | Disk mode (`"persistent"`) |
| `snapshot_create_set_name` | string | LVM snapshot set name for create operations |
| `snapshot_revert_set_name` | string | LVM snapshot set name for revert operations |
| `snapshot_remove_set_name` | string | LVM snapshot set name for remove operations |
| `snapshot_create_snapshot_autoextend_threshold` | int | LVM autoextend threshold percentage |
| `snapshot_create_snapshot_autoextend_percent` | int | LVM autoextend growth percentage |
| `snapshot_create_boot_backup` | bool | Whether to back up the boot partition |
| `snapshot_create_volumes` | list of dicts | LVM volumes to snapshot; each entry has `vg`, `lv`, and `size` |

> `satellite_username`, `satellite_password`, `vmware1_*` fields reference vault variables.

---

## Inventory Sources

**Source file:** `FQD.aap_inventory_sources.yml`

Defines dynamic inventory sources via the `aap_inventory_sources` list. The template ships with one source that pulls host data from Red Hat Satellite.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `aap_inventory_sources` | list of dicts | — | List of inventory source definitions | `ansible.controller.inventory_sources` role |

### `aap_inventory_sources[]` entry schema

| Field | Type | Description |
|---|---|---|
| `name` | string | Source name (also used as the display name in the inventory) |
| `credential` | string | Credential name used to authenticate to the source |
| `description` | string | Human-readable description |
| `execution_environment` | string | EE name to use when syncing |
| `inventory` | string | Parent inventory name that this source populates |
| `organization` | string | Owning organization |
| `overwrite` | bool | Whether to remove hosts from the inventory that no longer exist in the source |
| `source` | string | Source plugin type (e.g. `"satellite6"`) |
| `source_vars` | dict | Plugin-specific configuration variables |
| `state` | string | `present` or `absent` |
| `update_on_launch` | bool | Whether to sync automatically before each job run |

### `source_vars` for the `satellite6` source

| Key | Type | Description |
|---|---|---|
| `batch_size` | int | Number of hosts to fetch per API page (default `500`) |
| `use_extra_vars` | bool | Pass job extra vars into the sync |
| `want_facts` | bool | Import host facts from Satellite |
| `want_params` | bool | Import Satellite host parameters |

---

## Static Hosts

**Source file:** `FQD.aap_static_hosts.yml`

Defines statically-defined hosts inside AAP inventories via the `aap_static_hosts` list. Hosts may carry per-host variables used by provisioning playbooks.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `aap_static_hosts` | list of dicts | — | List of static host definitions | `ansible.controller.hosts` role |

### `aap_static_hosts[]` entry schema

| Field | Type | Description |
|---|---|---|
| `name` | string | Host FQDN or identifier |
| `description` | string | Human-readable description |
| `enabled` | bool | Whether the host is enabled for job execution |
| `inventory` | string | Inventory name where this host resides |
| `state` | string | `present` or `absent` |
| `variables` | dict | Per-host variables (optional) |

### Per-host variable schema (pipeline hosts)

Per-host variables are consumed by the `create_host` role in `rhis-builder-pipelines`. The samples defined here target VMware as the compute resource, but any parameter structure accepted by Satellite's host creation API is supported. The `create_host` role supports bare-metal, hypervisor PXE or image builds, and cloud image builds. Required parameters vary by compute resource target — refer to the Satellite documentation and the relevant hostgroup definitions for the full set of supported fields. More complete examples across all supported build types are documented in the [provisioner group vars schema](provisioner.md).

**SOE pipeline hosts** (`SOE_pipeline_inventory`, `SOE_qa_pipeline_inventory`):

| Variable | Type | Description |
|---|---|---|
| `fqdn` | string | Fully qualified domain name of the host |
| `hostgroup` | string | Satellite hostgroup path for provisioning |
| `kickstart_repository` | string | Satellite kickstart repository label |
| `compute_resource` | string | Satellite compute resource name |
| `compute_profile` | string | Satellite compute profile name |
| `mac` | string | MAC address for PXE provisioning |
| `dhostname` | string | Dynamic hostname override (empty string to use `fqdn`) |

**Convert2RHEL pipeline hosts** (`convert2rhel_pipeline_inventory`):

| Variable | Type | Description |
|---|---|---|
| `fqdn` | string | Fully qualified domain name of the host |
| `delete_host` | bool | Whether to remove the host from Satellite after conversion |
| `organization` | string | Satellite organization |
| `location` | string | Satellite location |
| `hostgroup` | string | Satellite hostgroup for OS assignment |
| `compute_resource` | string | Satellite compute resource name |
| `compute_profile` | string | Satellite compute profile name |
| `mac` | string | MAC address for PXE provisioning |
| `comment` | string | Descriptive comment tag (used to mark ephemeral hosts) |

---

## Static Groups

**Source file:** `FQD.aap_static_groups.yml`

Defines static groups within AAP inventories via the `aap_static_groups` list. Groups aggregate static hosts and can be used as `limit` targets in job templates.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `aap_static_groups` | list of dicts | — | List of static group definitions | `ansible.controller.groups` role |

### `aap_static_groups[]` entry schema

| Field | Type | Description |
|---|---|---|
| `name` | string | Group name |
| `description` | string | Human-readable description |
| `hosts` | list of strings | Host FQDNs that are members of this group |
| `inventory` | string | Inventory name where this group lives |
| `state` | string | `present` or `absent` |

### Groups defined per inventory

**`SOE_pipeline_inventory`** (Dev testing):
`JBoss`, `LAMP`, `dbservers`, `webservers`, `WordPress`, `wordpressserver`

**`SOE_qa_pipeline_inventory`** (QA testing):
`JBoss`, `LAMP`, `dbservers`, `webservers`, `WordPress`, `wordpressserver`

**`TheAutomationController`**:
`controller`

**`TheProvisioner`**:
`provisioner`

**`convert2rhel_pipeline_inventory`**:
`centos` (CentOS 7.9 hosts), `oel` (Oracle Enterprise Linux 7.9 hosts), `cconvert2rhel` (all c2r target hosts)

---

## Projects

**Source file:** `FQD.aap_projects.yml`

Defines AAP projects (SCM-backed playbook repositories) via the `aap_projects` list. Two internal computed variables control the Git base URL and are documented below.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `_g_git_url` | string | `"https://github.com"` | Base GitHub URL; internal variable, prefix `_g_` indicates project-scoped | Project SCM URL construction |
| `_g_git_user` | string | `"parmstro"` | GitHub organization or user; controls which fork of rhis repos is used | Project SCM URL construction |
| `_g_base_scm_url` | string | `"{{ _g_git_url }}/{{ _g_git_user }}"` | Assembled base URL prepended to each project's repo name | All `scm_url` fields |
| `aap_projects` | list of dicts | — | List of project definitions to create/manage on the controller | `ansible.controller.projects` role |

### `aap_projects[]` entry schema

| Field | Type | Description |
|---|---|---|
| `name` | string | Unique project name |
| `organization` | string | Owning organization |
| `credential` | string | SCM credential name |
| `description` | string | Human-readable description |
| `default_env` | string | Default execution environment for jobs from this project |
| `scm_type` | string | Source control type (always `"git"` in this template) |
| `scm_branch` | string | Branch to track (always `"main"` in this template) |
| `scm_clean` | bool | Delete local changes before update |
| `scm_delete_on_update` | bool | Delete the project directory before each update |
| `scm_track_submodules` | bool | Recursively initialize/update git submodules |
| `scm_update_on_launch` | bool | Auto-update before each job run |
| `scm_url` | string | Full Git remote URL |
| `state` | string | `present` or `absent` |
| `validate_certs` | bool | TLS certificate validation; inherits `aap_validate_certs` |

### Defined projects

| Name | Repo (relative to `_g_base_scm_url`) | Purpose |
|---|---|---|
| `rhis-builder-day-2-ops` | `rhis-builder-day-2-ops.git` | Day 2 operations: post-provisioning callbacks, IdM config |
| `rhis-builder-pipelines` | `rhis-builder-pipelines.git` | SOE content lifecycle pipeline playbooks |
| `rhis-builder-convert2rhel` | `rhis-builder-convert2rhel.git` | Convert2RHEL automation roles and playbooks |
| `rhis-builder-imagebuilder` | `rhis-builder-imagebuilder.git` | Image Builder tooling for cloud image creation |

---

## Execution Environments

**Source file:** `FQD.aap_execution_environments.yml`

Defines AAP execution environments (EEs) via the `aap_execution_environments` list. EEs are built from templates and pushed to the Private Hub registry. The fields in this list extend the standard `ansible.controller` EE schema with rhis-builder-specific build fields.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `aap_execution_environments` | list of dicts | — | List of execution environment definitions | `ansible.controller.execution_environments` role and EE build tasks |

### `aap_execution_environments[]` entry schema

| Field | Type | Description |
|---|---|---|
| `name` | string | EE name as it appears in AAP |
| `credential` | string | Container registry credential for push/pull access to the Private Hub |
| `base_image` | string | Base container image from `registry.redhat.io` |
| `image` | string | Fully qualified destination image path in the Private Hub registry |
| `ansible_requirements_template` | string | Jinja2 template filename for the Ansible `requirements.yml` |
| `python_requirements_template` | string | Jinja2 template filename for the pip `requirements.txt` |
| `system_requirements_template` | string | Jinja2 template filename for the `bindep.txt` system package list |
| `additional_dependencies` | dict | Extra build-time configuration; currently supports `python_interpreter` sub-key |
| `additional_dependencies.python_interpreter` | dict | `package_system` (RPM package) and `python_path` (interpreter path in the EE) |
| `description` | string | Human-readable description |
| `pull` | string | Pull policy for the base image: `"always"`, `"missing"`, or `"never"` |
| `organization` | string | Owning AAP organization |
| `tag` | string | Image tag to apply (e.g. `"v1"`) |
| `git_repo` | string | Git repository URL containing the EE definition files |
| `git_dest` | string | Local filesystem path to clone the EE repo into |
| `git_clone` | bool | Whether to clone the repo before building |
| `git_force` | bool | Whether to force-overwrite an existing local clone |

### Defined execution environments

| Name | Base OS | Purpose |
|---|---|---|
| `satellite_ee_9` | RHEL 9 (`ee-minimal-rhel9`) | Primary EE for RHEL 9 Satellite-registered systems; includes Python 3.12 |
| `satellite_ee_8` | RHEL 8 (`ee-minimal-rhel8`) | EE for RHEL 8 Satellite-registered systems |

---

## Job Templates

Rather than defining all job templates in a single large file, RHIS packages related templates together into named dictionary variables — for example, `aap_job_templates_vm_day_2` groups all VMware day-2 lifecycle templates. `aap_job_templates_list` (in `FQD.aap_templates_list.yml`) acts as an aggregator: it is a list of references to these named dictionaries, which the controller configuration role flattens and processes as a single set.

This design provides two key benefits:

- **Maintenance** — each functional group of templates lives in its own file. A problem in one file does not affect any other group, and changes are isolated to the relevant area.
- **Selection** — activating, deactivating, or extending a group of templates requires only adding, removing, or commenting out a single entry in `aap_job_templates_list`, without touching any of the individual template definitions.

### Job Template List

**Source file:** `FQD.aap_templates_list.yml`

| Variable | Type | Description | Used by |
|---|---|---|---|
| `aap_job_templates_list` | list | Ordered list of job template group variables to process; each element references one named template dictionary | `ansible.controller.job_templates` role |

The list includes: `aap_job_templates_vm_day_2`, `aap_job_templates_soe_dev`, `aap_job_templates_soe_qa`, `aap_job_templates_convert_2_rhel`, `aap_job_templates_default_monthly_publish`, `aap_job_templates_soe_ansible_callback`, `aap_job_templates_soe_imagebuilder`.

**Extending the job template configuration:**

1. Create a new file under `inventory_template/group_vars/platform_installer/` to hold your template definitions.
2. Define your templates as a uniquely named list variable (e.g. `aap_job_templates_my_custom_group`).
3. Add that variable name as a new entry in `aap_job_templates_list` in `FQD.aap_templates_list.yml`.

The controller configuration role will automatically include your templates in the next run without any changes to existing files.

### Job template entry schema (all groups)

All job template lists share the same entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | Unique template name within the organization |
| `description` | string | Human-readable description |
| `job_type` | string | `"run"` or `"check"` |
| `organization` | string | Owning organization |
| `inventory` | string | Default inventory for the template |
| `project` | string | Project containing the playbook |
| `execution_environment` | string | EE name to use |
| `playbook` | string | Relative path to the playbook within the project |
| `limit` | string | (Optional) Host pattern to limit execution |
| `become_enabled` | bool | Whether to enable privilege escalation (`become`) |
| `ask_limit_on_launch` | bool | (Optional) Prompt for limit at launch time |
| `host_config_key` | string | (Optional) Key required for Satellite Ansible Callback |
| `credentials` | list of strings | Credential names attached to the template |
| `variables` | dict | Default extra variables (job-level defaults) |
| `state` | string | `present` or `absent` |

---

### VM Day 2 Management Templates

**Source file:** `FQD.aap_templates_vm_mgmt.yml`

| Variable | Type | Description | Used by |
|---|---|---|---|
| `aap_job_templates_vm_day_2` | list of dicts | VMware virtual machine day-2 lifecycle templates | `aap_job_templates_list` |

| Template name | Playbook | Purpose |
|---|---|---|
| `VMwareCreateSnapshot` | `vmware/vmw_create_snapshot.yml` | Create quiesced snapshots of test VMs |
| `VMwarePowerOffVM` | `vmware/vmw_power_off_vm.yml` | Force power-off of test VMs |
| `VMwarePowerOnVM` | `vmware/vmw_power_on_vm.yml` | Power-on test VMs |
| `VMwareRebootGuestOS` | `vmware/vmw_reboot_guest_os.yml` | Guest OS reboot (via VMware tools) |
| `VMwareRemoveAllSnaps` | `vmware/vmw_delete_snapshot.yml` | Remove all snapshots from test VMs |
| `VMwareRestartVM` | `vmware/vmw_restart_vm.yml` | Hard restart of VM |
| `VMwareRevertSnaps` | `vmware/vmw_revert_snapshot.yml` | Revert VMs to a named snapshot |
| `VMwareShutdownGuestOS` | `vmware/vmw_shutdown_guest_os.yml` | Graceful guest OS shutdown |
| `VMwareSuspendVM` | `vmware/vmw_suspend_vm.yml` | Suspend VM (use with caution) |

All templates target `TheProvisioner` inventory, use `satellite_ee_9`, and require `idm_machine`, `default_vault`, and `rhis_{{ _runtime_global_domain_name }}_vmware1` credentials.

---

### SOE Development Content Pipeline Templates

**Source file:** `FQD.aap_templates_soe_content_dev.yml`

| Variable | Type | Description | Used by |
|---|---|---|---|
| `aap_job_templates_soe_dev` | list of dicts | Templates for the Development lifecycle SOE content delivery pipeline | `aap_job_templates_list` |

| Template name | Playbook | Purpose |
|---|---|---|
| `Dev1PublishContent` | `publish_only.yml` | Publish SOE content views (JBoss, LAMP, WordPress, EPEL) |
| `Dev2PromoteToDev` | `promote_only.yml` | Promote content from Library to Development lifecycle environment |
| `Dev3DeployTestServers` | `create_hosts.yml` | Deploy JBoss, LAMP, WordPress test hosts via Satellite |
| `Dev4SnapshotTestServers` | `vmware/vmw_create_snapshot.yml` | Snapshot freshly deployed Dev test VMs |
| `Dev5.1.1BuildJBoss` | `testcontent/jboss-standalone/main.yml` | Deploy JBoss EAP 8 application on Dev JBoss host |
| `Dev5.1.2TestJBoss` | `testcontent/jboss-standalone/deploymenttest.yml` | Validate JBoss application deployment |
| `Dev5.2.1BuildLAMP` | `testcontent/lamp_simple/main.yml` | Deploy LAMP stack on Dev LAMP host |
| `Dev5.2.2TestLAMP` | `testcontent/lamp_simple/deploymenttest.yml` | Validate LAMP stack deployment |
| `Dev5.3.1BuildWordpress` | `testcontent/wordpress-nginx/main.yml` | Deploy WordPress + nginx on Dev WordPress host |
| `Dev5.3.2TestWordpress` | `testcontent/wordpress-nginx/deploymenttest.yml` | Validate WordPress deployment |
| `Dev6PromoteToQA` | `promote_only.yml` | Promote content from Development to Qualification |
| `Dev7DeleteSnapshots` | `vmware/vmw_delete_snapshot.yml` | Delete Dev VM snapshots after successful promotion |
| `Dev8FPowerOffTestServers` | `vmware/vmw_power_off_vm.yml` | Power off Dev test VMs (failure path) |
| `Dev8SDeleteTestServers` | `delete_hosts.yml` | Delete Dev test hosts from Satellite (after approval) |

---

### SOE Qualification Content Pipeline Templates

**Source file:** `FQD.aap_templates_soe_content_qa.yml`

| Variable | Type | Description | Used by |
|---|---|---|---|
| `aap_job_templates_soe_qa` | list of dicts | Templates for the Qualification lifecycle SOE content delivery pipeline | `aap_job_templates_list` |

| Template name | Playbook | Purpose |
|---|---|---|
| `QA1DeployQATestServers` | `create_hosts.yml` | Deploy QA JBoss, LAMP, WordPress test hosts via Satellite |
| `QA2SnapshotQATestServers` | `vmware/vmw_create_snapshot.yml` | Snapshot freshly deployed QA test VMs |
| `QA3.1.1BuildQAJBoss` | `testcontent/jboss-standalone/main.yml` | Deploy JBoss EAP 8 application on QA JBoss host |
| `QA3.1.2TestQAJBoss` | `testcontent/jboss-standalone/deploymenttest.yml` | Validate QA JBoss deployment |
| `QA3.2.1BuildQALAMP` | `testcontent/lamp_simple/main.yml` | Deploy LAMP stack on QA LAMP host |
| `QA3.2.2TestQALAMP` | `testcontent/lamp_simple/deploymenttest.yml` | Validate QA LAMP deployment |
| `QA3.3.1BuildQAWordpress` | `testcontent/wordpress-nginx/main.yml` | Deploy WordPress + nginx on QA WordPress host |
| `QA3.3.2TestQAWordpress` | `testcontent/wordpress-nginx/deploymenttest.yml` | Validate QA WordPress deployment |
| `QA4PromoteToProd` | `promote_only.yml` | Promote content from Qualification to Production |
| `QA5DeleteQASnapshots` | `vmware/vmw_delete_snapshot.yml` | Delete QA VM snapshots after promotion |
| `QA6FPowerOffQATestServers` | `vmware/vmw_power_off_vm.yml` | Power off QA test VMs (failure path) |
| `QA6SDeleteQATestServers` | `delete_hosts.yml` | Delete QA test hosts from Satellite (after approval) |

---

### Convert2RHEL Pipeline Templates

**Source file:** `FQD.aap_templates_convert_2_rhel.yml`

| Variable | Type | Description | Used by |
|---|---|---|---|
| `aap_job_templates_convert_2_rhel` | list of dicts | Templates for the convert2RHEL automated conversion pipeline; note: marked as broken with current ansible-core/collection versions in `FQD.aap_templates_list.yml` | `aap_job_templates_list` |

| Template name | Project | Playbook/Role | Purpose |
|---|---|---|---|
| `c2r_deploy_test_servers` | `rhis-builder-pipelines` | `create_hosts.yml` | Deploy CentOS 7.9 and OEL 7.9 test hosts via Satellite |
| `c2r_analyze` | `rhis-builder-convert2rhel` | `run_role.yml` (role: `c2r_analyze`) | Run convert2RHEL analysis/pre-check |
| `c2r_report_export` | `rhis-builder-convert2rhel` | `run_role.yml` (role: `c2r_report_export`) | Export c2r analysis report for external consumption |
| `c2r_convert` | `rhis-builder-convert2rhel` | `run_role.yml` (role: `c2r_convert`) | Execute OS conversion and reboot |
| `c2r_preconvert_remediate` | `rhis-builder-convert2rhel` | `run_role.yml` (role: `c2r_preconvert_remediate`) | Pre-conversion remediation steps |
| `c2r_post_remediate` | `rhis-builder-convert2rhel` | `run_role.yml` (role: `c2r_post_remediate`) | Post-conversion remediation |
| `c2r_post_validate` | `rhis-builder-convert2rhel` | `run_role.yml` (role: `c2r_post_validate`) | Validate converted OS version and function |
| `c2r_prereq_cdn` | `rhis-builder-convert2rhel` | `run_role.yml` (role: `c2r_prereq_cdn`) | Set up prerequisites for CDN-registered hosts |
| `c2r_prereq_sat` | `rhis-builder-convert2rhel` | `run_role.yml` (role: `c2r_prereq_sat`) | Set up prerequisites for Satellite-registered hosts |
| `c2r_snapshot_cleanup` | `rhis-builder-convert2rhel` | `run_role.yml` (role: `c2r_snapshot_cleanup`) | Remove LVM snapshot disks and cleanup config |
| `c2r_snapshot_create` | `rhis-builder-convert2rhel` | `run_role.yml` (role: `c2r_snapshot_create`) | Create LVM rollback snapshot |
| `c2r_snapshot_prepare` | `rhis-builder-convert2rhel` | `run_role.yml` (role: `c2r_snapshot_prepare`) | Prepare disk space and snapshot configuration |
| `c2r_snapshot_remove` | `rhis-builder-convert2rhel` | `run_role.yml` (role: `c2r_snapshot_remove`) | Commit conversion by removing LVM snapshot |
| `c2r_snapshot_revert` | `rhis-builder-convert2rhel` | `run_role.yml` (role: `c2r_snapshot_revert`) | Revert host to pre-conversion snapshot |

All templates use `convert2rhel_pipeline_inventory` (except `c2r_deploy_test_servers` which uses `TheAutomationController`) and `satellite_ee_9`.

---

### Default Monthly Publish Template

**Source file:** `FQD.aap_templates_default_monthy_publish_all.yml`

| Variable | Type | Description | Used by |
|---|---|---|---|
| `aap_job_templates_default_monthly_publish` | list of dicts | Single template for monthly full content view publication | `aap_job_templates_list` |

| Template name | Playbook | Purpose |
|---|---|---|
| `MonthlyPublishContent` | `publish_only.yml` | Force-publish all content views across all lifecycle environments; covers SOE7/8/9, JBoss, EPEL, convert2RHEL, LEAPP, Image Builder, MSSQLServer, and composite views |

The template's `variables.content_views` list covers: `AAP24_Files`, `AAP24_RPMs`, `AAP25_Files`, `AAP25_RPMs`, `bootc_containers`, `CentOS79`, `CentOS_S9`, `convert2rhel7`, `convert2rhel8`, `EPEL8`, `EPEL9`, `JBoss8EAP74`, `JBoss9EAP74`, `LEAPP_2_RHEL8`, `LEAPP_2_RHEL9`, `mssqlserver2022_rhel9`, `OEL79`, `SOE7`, `SOE8`, `SOE9`, `SOE9_aarch64`.

The `variables.composite_content_views` list covers: `SOE_AAP24`, `SOE_AAP25`, `SOE8_JBoss`, `SOE9_JBoss`, `SOE8_EPEL`, `SOE9_EPEL`, `convert_CentOS2RHEL7`, `convert_OEL2RHEL7`, `LEAPP_7_2_8`, `LEAPP_8_2_9`, `SOE9_MSSQL`, `SOE9_POS`.

---

### SOE Ansible Callback Templates

**Source file:** `FQD.aap_templates_soe_ansible_callback.yml.j2`

This file is a Jinja2 template (`.j2` suffix) that injects the time server list and timezone from inventory variables at generation time using `{% for %}` loops. The resulting YAML is loaded as a standard group vars file.

| Variable | Type | Description | Used by |
|---|---|---|---|
| `aap_job_templates_soe_ansible_callback` | list of dicts | Templates for Satellite-triggered Ansible Callback post-provisioning | `aap_job_templates_list` |

| Template name | Playbook | Purpose |
|---|---|---|
| `SOE_Base_Ansible_Callback` | `post_provisioning_base.yml` | Called by Satellite via host config key after PXE provisioning; applies base SOE configuration |
| `SOE_Base_Ansible_Callback_Survey` | `post_provisioning_base.yml` | Same as above but with `ask_limit_on_launch: true` for manual re-runs against a specific host |

Both templates use the Satellite dynamic inventory, `rhis-builder-day-2-ops` project, and require `idm_machine`, `default_vault`, and `rhis_{{ _runtime_global_domain_name }}_idm` credentials. The `host_config_key` is set from `satellite_ansible_callback_config_key`. Time server and timezone variables are rendered from `rhis_time_servers` and `rhis_timezone` at template generation time.

---

### Image Builder Templates

**Source file:** `FQD.aap_templates_soe_imagebuilder.yml`

| Variable | Type | Description | Used by |
|---|---|---|---|
| `aap_job_templates_soe_imagebuilder` | list of dicts | Templates for Red Hat Image Builder (osbuild) integration | `aap_job_templates_list` |

| Template name | Project | Playbook | Purpose |
|---|---|---|---|
| `detect_imagebuilder9` | `rhis-builder-imagebuilder` | `detect_imagebuilder9.yml` | Check whether the imagebuilder9 host exists in Satellite |
| `create_imagebuilder9` | `rhis-builder-pipelines` | `create_hosts.yml` | Deploy the imagebuilder9 host via Satellite if it does not exist |
| `deploy_imagebuilder_code` | `rhis-builder-imagebuilder` | `deploy_imagebuilder9.yml` | Install and configure Image Builder software on imagebuilder9 |
| `config_imagebuilder_build` | `rhis-builder-imagebuilder` | `config_imagebuilder_build.yml` | Configure osbuild repositories and TOML blueprints for image building |

All templates use the Satellite dynamic inventory and `satellite_ee_9`.

---

### JBoss Production Patching Templates (Work in Progress)

**Source file:** `FQD.aap_templates_patch_jboss_prod.yml`

> This file is marked as a work in progress.

| Variable | Type | Description | Used by |
|---|---|---|---|
| `aap_job_templates_patch_jboss_prod` | list of dicts | Templates for structured JBoss production patching with ServiceNow integration | Not yet included in `aap_job_templates_list` |

| Template name | Playbook | Purpose |
|---|---|---|
| `PJP1_begin_upgrade` | `run_task.yml` | Open change control and validate upgrade prerequisites; includes ServiceNow incident metadata |
| `PJP2.1_app_health_check` | `run_task.yml` | Validate JBoss application health before patching |
| `PJP2.2_node_health_check` | `run_task.yml` | Validate OS/node health before patching |
| `PJP3_enable_maintenance_page` | `run_task.yml` | Enable maintenance page on the application |

All templates use `TheProvisioner` inventory, `satellite_ee_9`, and `rhis-builder-pipelines` project with `default_machine` and `default_vault` credentials.

---

## Workflow Templates

Workflow template lists follow the same aggregator pattern as job template lists. Each workflow template is defined in its own file as a uniquely named variable; `aap_workflow_templates_list` in `FQD.aap_workflow_templates_list.yml` assembles them into a single list consumed by the controller configuration role. The same maintenance and selection benefits apply — adding, removing, or commenting out a single entry activates or deactivates an entire workflow without touching any other configuration.

Workflow templates are tightly related to their corresponding job templates. A workflow template orchestrates the execution of job templates in a defined sequence or topology, so changes to job template names or structures should be reflected in the associated workflow. The SOE Development Content pipeline templates (`aap_job_templates_soe_dev`) and the SOE Development Content Delivery Pipeline workflow (`aap_workflow_template_soe_content_delivery_pipeline_dev`) demonstrate this relationship and serve as the reference pattern for extending the model.

To extend the workflow template configuration, follow the same approach as for job templates: create a new file under `inventory_template/group_vars/platform_installer/`, define your workflow as a uniquely named variable, and add it to `aap_workflow_templates_list`.

### Workflow Template List

**Source file:** `FQD.aap_workflow_templates_list.yml`

| Variable | Type | Description | Used by |
|---|---|---|---|
| `aap_workflow_templates_list` | list | Ordered list of workflow template variables to process; each element references one named workflow dictionary | `ansible.controller.workflow_job_templates` role |

Contains: `aap_workflow_template_soe_content_delivery_pipeline_dev`, `aap_workflow_template_soe_content_delivery_pipeline_qa`, `aap_workflow_template_c2r_pipeline`, `aap_workflow_template_test_vmware_plays_pipeline`.

### Workflow template entry schema

| Field | Type | Description |
|---|---|---|
| `name` | string | Unique workflow name |
| `description` | string | Human-readable description |
| `organization` | string | Owning organization |
| `state` | string | `present` or `absent` |
| `notification_templates_approvals` | list of strings | Notification names fired when an approval node is reached |
| `notification_templates_success` | list of strings | Notification names fired on workflow success |
| `notification_templates_error` | list of strings | Notification names fired on workflow failure |
| `workflow_nodes` | list of dicts | Ordered list of workflow node definitions |

### Workflow node schema

| Field | Type | Description |
|---|---|---|
| `identifier` | string | Unique node identifier within this workflow |
| `all_parents_must_converge` | bool | (Optional) When `true`, the node only runs when all upstream nodes succeed |
| `unified_job_template` | dict | Reference to the job template or approval node to execute |
| `unified_job_template.name` | string | Template name |
| `unified_job_template.organization` | dict | `{name: "org_name"}` — organization scoping for the lookup |
| `unified_job_template.type` | string | `job_template` or `workflow_approval` |
| `unified_job_template.timeout` | int | (Approval nodes only) Seconds before the approval request expires |
| `unified_job_template.description` | string | (Approval nodes only) Approval prompt shown to the approver |
| `related` | dict | Downstream node routing |
| `related.success_nodes` | list of dicts | Node identifiers to run on success (`[{identifier: "name"}]`) |
| `related.failure_nodes` | list of dicts | Node identifiers to run on failure |
| `related.always_nodes` | list of dicts | Node identifiers that always run regardless of outcome |
| `related.credentials` | list | Additional credentials to attach at the node level |

---

### SOE Dev Content Delivery Pipeline Workflow

**Source file:** `FQD.aap_workflow_SOE_content_delivery_pipeline_dev.yml`

| Variable | Type | Description | Used by |
|---|---|---|---|
| `aap_workflow_template_soe_content_delivery_pipeline_dev` | dict | Workflow template object for the Development lifecycle SOE content delivery pipeline | `aap_workflow_templates_list` |

**Workflow name:** `SOE_ContentDeliveryPipeline`

**Node sequence:** `Define` (publish) → `Deliver` (promote to Dev) → `Deploy` (deploy test servers) → `Snapshot` → parallel branches `ConfigureApp1/2/3` (build JBoss/LAMP/WordPress) and `TestApp1/2/3` (test each) → `PromoteNext` (converge all, promote to QA) → `DeleteSnapshot` → `ApproveDeleteHosts` (approval, 3-hour timeout) → on approval: `DeleteHosts`; on rejection or snapshot failure: `PowerOffHosts`.

---

### SOE QA Content Delivery Pipeline Workflow

**Source file:** `FQD.aap_workflow_SOE_content_delivery_pipeline_qa.yml`

| Variable | Type | Description | Used by |
|---|---|---|---|
| `aap_workflow_template_soe_content_delivery_pipeline_qa` | dict | Workflow template object for the Qualification lifecycle SOE content delivery pipeline | `aap_workflow_templates_list` |

**Workflow name:** `SOE_ContentDeliveryPipeline_QA`

**Node sequence:** `DeployQA` → `SnapshotQA` → parallel branches `ConfigureApp1/2/3QA` and `TestApp1/2/3QA` → `PromoteNextQA` (converge, promote to Production) → `DeleteSnapshotQA` → `ApproveDeleteHostsQA` (3-hour timeout) → on approval: `DeleteHostsQA`; on rejection or snapshot failure: `PowerOffHostsQA`.

---

### Convert2RHEL Pipeline Workflow

**Source file:** `FQD.aap_workflow_convert2rhel_pipeline.yml`

| Variable | Type | Description | Used by |
|---|---|---|---|
| `aap_workflow_template_c2r_pipeline` | dict | Workflow template object for the automated CentOS/OEL to RHEL conversion pipeline | `aap_workflow_templates_list` |

**Workflow name:** `c2r_pipeline`

**Node sequence:** `Prerequisites` (prereq_sat) → `Pre Convert Remediate` → `Analyze` → on success: `Prepare Snapshot Devices` → `Create Snapshot` → `Convert` → `Post Convert Remediate` → `Post Convert Validate` → on success: `Approve Commit` (approval) → `Commit System` (remove snapshot) → `Snapshot Cleanup`; on validate failure: `Approve Revert` (approval) → `Revert System`. The `Export Report` node runs always after `Analyze` regardless of outcome.

---

### VMware Test Pipeline Workflow

**Source file:** `FQD.aap_workflow_test_vmware_plays_pipeline.yml`

| Variable | Type | Description | Used by |
|---|---|---|---|
| `aap_workflow_template_test_vmware_plays_pipeline` | dict | Workflow template for sequentially exercising all VMware day-2 operations against test VMs | `aap_workflow_templates_list` |

**Workflow name:** `test_vmware_plays_pipeline`

**Node sequence:** `Build Test VMs` → `VMwarePowerOffVM` → `VMwarePowerOnVM` → `VMwareRestartVM` → `VMwareCreateSnapshot` → `VMwareRebootGuestOS` → `VMwareSuspendVM` → `VMwareUnsuspend` (PowerOn) → `VMwareRevertSnaps` → `VMwarePowerOnAfterRevert` → `VMwareRemoveAllSnaps` → `VMwareShutdownGuestOS` → `Delete Test Servers`.

---

## Notifications

**Source file:** `FQD.aap_notifications.yml`

Defines notification integrations via the `aap_notifications` list. The template ships with one Slack notifier; comments in the file enumerate all supported notification types and configuration fields.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `aap_notifications` | list of dicts | — | List of notification definitions to create/manage on the controller | `ansible.controller.notification_templates` role |

### `aap_notifications[]` entry schema

| Field | Type | Description |
|---|---|---|
| `name` | string | Unique notification name |
| `description` | string | Human-readable description (note: field has a typo `descritpion` in the source file) |
| `organization` | string | Owning organization |
| `state` | string | `present` or `absent` |
| `validate_certs` | bool | Whether to validate TLS certificates when contacting the notification service |
| `notification_type` | string | Notification backend: `awssns`, `email`, `grafana`, `irc`, `mattermost`, `pagerduty`, `rocketchat`, `slack`, `twilio`, or `webhook` |
| `notification_configuration` | dict | Backend-specific configuration (see fields below) |

### `notification_configuration` fields by type

| Field | Applicable types | Description |
|---|---|---|
| `targets` | `slack`, `irc` | List of channel or user targets (e.g. `["#channel"]`) |
| `token` | `slack` | API/bot token for authentication |
| `username` | `email` | Mail server username |
| `sender` | `email` | Sender email address |
| `recipients` | `email` | List of recipient email addresses |
| `use_tls` | `email` | Enable STARTTLS |
| `use_ssl` | `email` | Enable SSL/TLS |
| `host` | `email` | Mail server hostname |
| `password` | `email` | Mail server password |
| `port` | `email` | Mail server port |
| `account_token` | `twilio` | Twilio account token |
| `from_number` | `twilio` | Source phone number |
| `to_numbers` | `twilio` | List of destination phone numbers |
| `account_sid` | `twilio` | Twilio account SID |
| `subdomain` | `pagerduty` | PagerDuty subdomain |
| `service_key` | `pagerduty` | PagerDuty service/integration API key |
| `client_name` | `pagerduty` | PagerDuty client identifier |
| `message_from` | `rocketchat`, `mattermost` | Display label for the notification sender |
| `color` | `rocketchat`, `mattermost` | Notification accent color |
| `notify` | `rocketchat` | Whether to trigger a channel notification ping |
| `url` | `webhook`, `rocketchat`, `mattermost`, `grafana` | Target URL |
| `headers` | `webhook` | HTTP headers as a JSON string |
| `server` | `irc` | IRC server address |
| `nickname` | `irc` | IRC bot nickname |

### Defined notifications

| Name | Type | Target |
|---|---|---|
| `RedHatGCA_NotifySlack` | `slack` | `#rhis_notify` Slack channel; used by all four workflow templates for approvals, success, and error events |
