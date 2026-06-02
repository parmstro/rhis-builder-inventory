# Hosts: aap — AAP Controller and Hub Variables

Schema Version: 1.0.0

These variables configure the Ansible Automation Platform (AAP) Controller and Private Automation Hub hosts for versions 2.4 and 2.6. Where variables differ between versions, this is noted explicitly. The `platform_installer.yml` files define the AAP installer configuration; `auth_source.yml` defines how each component authenticates to IdM; `repositories.yml` (Hub only) configures collection remote sources.

Upstream installer documentation: [AAP Installation Guide](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/)

---

## IdM Authentication Source

Defined in `auth_source.yml` for all four AAP host directories. These variables tell the AAP provisioner role which IdM server to authenticate against when performing pre-installation tasks (certificate issuance, Kerberos enrollment, etc.). The values are identical across `aapcontroller24`, `aapcontroller26`, `aaphub24`, and `aaphub26`.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `auth_source_fqdn` | string | `groups['idm_primary'][0]` | FQDN of the IdM primary server used as the authentication source | `auth_source.yml` (all AAP hosts) |

---

## Platform Identity and Deployment Mode

Defined in `platform_installer.yml`. These top-level variables declare what version of AAP is being deployed, how it is packaged, and which installer bundle file to use. The values differ between the 2.4 and 2.6 host directories.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `platform_version` | string | `"2.4"` (controller24/hub24) / `"2.6"` (controller26/hub26) | AAP product version string | `platform_installer.yml` |
| `platform_arch` | string | `"x86_64"` | Target CPU architecture | `platform_installer.yml` |
| `platform_installer` | bool | `true` | Marks this host as the AAP installer node (downloads bundle, runs setup) | `platform_installer.yml` |
| `platform_deployment_type` | string | `"rpm"` (24 hosts, hub26) / `"container"` (controller26) | Packaging model: `rpm`, `container`, or `openshift`. Controller 2.6 uses containerized deployment; everything else uses RPM. | `platform_installer.yml` |
| `platform_topology` | string | `"standalone"` (controller24) / `"growth"` (controller26) / `"standalone_hub"` (hub24, hub26) | AAP installer topology. Valid values: `standalone`, `growth`, `enterprise`, `custom`, `standalone_hub`. | `platform_installer.yml` |

---

## Platform Installer Configuration (`platform_installer_config`)

Defined in `platform_installer.yml` as a dictionary. This dictionary is consumed by the RHIS provisioner to template the AAP installer inventory file. Sub-keys are documented below by functional area.

### RHIS Provisioner Sub-keys

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `platform_installer_config.deployment_type` | string | `"{{ platform_deployment_type }}"` | Rendered value of `platform_deployment_type`; passed through to the installer inventory | `platform_installer.yml` |
| `platform_installer_config.topology` | string | `"{{ platform_topology }}"` | Rendered value of `platform_topology`; passed through to the installer inventory | `platform_installer.yml` |
| `platform_installer_config.aap_product` | string | `"Red Hat Ansible Automation Platform"` | Product name string used when locating the Satellite file repository | `platform_installer.yml` |
| `platform_installer_config.aap_file_repo_name` | string | Version-specific (e.g. `"Red Hat Ansible Automation Platform 2.4 for RHEL 9 x86_64 Files"`) | Name of the Satellite file repository from which the installer bundle is downloaded | `platform_installer.yml` |
| `platform_installer_config.aap_bundle_file` | string | Version-specific (e.g. `"ansible-automation-platform-setup-bundle-2.4-14-x86_64.tar.gz"`) | Filename of the installer bundle tarball to fetch from Satellite | `platform_installer.yml` |
| `platform_installer_config.aap_destination_dir` | string | `"/root/ansible_installer"` | Directory on the installer node where the bundle is extracted | `platform_installer.yml` |

### General Installer Settings

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `platform_installer_config.aap_admin_username` | string | `"admin"` | Initial admin username created by the installer (Controllers). On Hub hosts this key is named `aap_platform_username`. | `platform_installer.yml` |
| `platform_installer_config.aap_platform_username` | string | `"admin"` | Initial admin username for Hub installs | `platform_installer.yml` (hub hosts) |
| `platform_installer_config.aap_custom_ca_crt` | string | `"/etc/ipa/ca.crt"` | Path to the IdM CA certificate; used by the installer to trust internal TLS | `platform_installer.yml` |
| `platform_installer_config.aap_redis_mode` | string | `"standalone"` | Redis clustering mode: `standalone` (single-node) or `cluster` | `platform_installer.yml` |

### Red Hat Registry Credentials

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `platform_installer_config.aap_registry_url` | string | `"registry.redhat.io"` | Container registry from which AAP images are pulled (container deployments) | `platform_installer.yml` |
| `platform_installer_config.aap_registry_username` | string | — | Service-account username for `registry.redhat.io`; obtain from [access.redhat.com/terms-based-registry](https://access.redhat.com/terms-based-registry/#/accounts) | `platform_installer.yml` |
| `platform_installer_config.aap_registry_password` | string | — | Service-account token / password for `registry.redhat.io` | `platform_installer.yml` |

### PostgreSQL Database

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `platform_installer_config.aap_pg_host` | string | `""` | PostgreSQL host; empty string means localhost | `platform_installer.yml` |
| `platform_installer_config.aap_pg_port` | int | `5432` | PostgreSQL port (Controller hosts only — Hub hosts leave this commented out for localhost default) | `platform_installer.yml` (controllers) |
| `platform_installer_config.aap_pg_database` | string | `"awx"` | PostgreSQL database name | `platform_installer.yml` |
| `platform_installer_config.aap_pg_username` | string | `"awx"` | PostgreSQL database username | `platform_installer.yml` |
| `platform_installer_config.aap_pg_sslmode` | string | `"prefer"` | PostgreSQL SSL mode (`prefer`, `require`, `disable`, etc.) | `platform_installer.yml` |
| `platform_installer_config.aap_pg_use_ssl` | bool | `true` | Whether to use SSL for the PostgreSQL connection | `platform_installer.yml` |
| `platform_installer_config.aap_pg_ssl_crt` | string | `"{{ platform_ssl_certs_base_dir }}/{{ groups['aap_controllers'][0] }}/...crt"` | Path to the TLS certificate used for PostgreSQL client auth (Controller hosts use `aap_controllers` group; Hub hosts use `aap_hubs` group) | `platform_installer.yml` |
| `platform_installer_config.aap_pg_ssl_key` | string | `"{{ platform_ssl_certs_base_dir }}/{{ groups['aap_controllers'][0] }}/...key"` | Path to the TLS key used for PostgreSQL client auth | `platform_installer.yml` |

### Controller-specific TLS Settings (`aapcontroller24`, `aapcontroller26`)

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `platform_installer_config.aap_controller_verify_ssl` | bool | `true` | Whether the Controller API should verify TLS certificates | `platform_installer.yml` (controllers) |
| `platform_installer_config.aap_controller_ssl_crt` | string | Derived from `platform_ssl_certs_base_dir` and `aap_controllers` group | Path to the Controller's TLS certificate | `platform_installer.yml` (controllers) |
| `platform_installer_config.aap_controller_ssl_key` | string | Derived from `platform_ssl_certs_base_dir` and `aap_controllers` group | Path to the Controller's TLS private key | `platform_installer.yml` (controllers) |
| `platform_installer_config.aap_web_server_ssl_crt` | string | Same as `aap_controller_ssl_crt` | TLS certificate served by the Controller web server | `platform_installer.yml` (controllers) |
| `platform_installer_config.aap_web_server_ssl_key` | string | Same as `aap_controller_ssl_key` | TLS private key for the Controller web server | `platform_installer.yml` (controllers) |
| `platform_installer_config.aap_platform_username` | string | `"{{ aap_admin_username }}"` | Reference to the installer admin username (Controller hosts alias this to `aap_admin_username`) | `platform_installer.yml` (controllers) |
| `platform_installer_config.aap_platform_password` | string | `"{{ aap_admin_password }}"` | Reference to the installer admin password | `platform_installer.yml` (controllers) |

### Hub-specific TLS Settings (`aaphub24`, `aaphub26`)

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `platform_installer_config.aap_hub_verify_ssl` | bool | `true` | Whether Hub API calls should verify TLS | `platform_installer.yml` (hubs) |
| `platform_installer_config.aap_hub_ssl_crt` | string | Derived from `platform_ssl_certs_base_dir` and `aap_hubs` group | Path to the Hub's TLS certificate | `platform_installer.yml` (hubs) |
| `platform_installer_config.aap_hub_ssl_key` | string | Derived from `platform_ssl_certs_base_dir` and `aap_hubs` group | Path to the Hub's TLS private key | `platform_installer.yml` (hubs) |

---

## Node Pre-configuration (`node_pre.yml.j2`)

These variables are rendered by the Jinja2 template before AAP installation runs. They configure storage, firewall rules, and TLS certificate generation on the node itself. The template uses `{% raw %}` blocks so that Ansible variable references are preserved as-is in the rendered output.

### Satellite Registration (Controller nodes only)

Hub node_pre files do not include Satellite credentials; controllers do because the installer node needs to access Satellite to download the bundle.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `satellite_username` | string | — | Username for Satellite API and subscription registration | `node_pre.yml.j2` (controllers) |
| `satellite_password` | string | — | Password for Satellite API and subscription registration | `node_pre.yml.j2` (controllers) |
| `satellite_admin_username` | string | `"{{ satellite_username_vault }}"` | Alias for `satellite_username`; retained for backwards compatibility | `node_pre.yml.j2` (controllers) |
| `satellite_admin_password` | string | `"{{ satellite_password_vault }}"` | Alias for `satellite_password`; retained for backwards compatibility | `node_pre.yml.j2` (controllers) |
| `satellite_url` | string | `"https://{{ groups['sat_primary'][0] }}"` | Base URL of the Satellite server | `node_pre.yml.j2` (controllers) |
| `satellite_server_url` | string | `"{{ satellite_url }}"` | Alias for `satellite_url` used by some collection roles | `node_pre.yml.j2` (controllers) |

### Boot and Reboot Behaviour

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `platform_node_pre_preferred_boot_order` | list | `["IP4", "IP6", "Red Hat"]` | PXE/EFI boot order preference list applied to the node's firmware | `node_pre.yml.j2` (all AAP hosts) |
| `platform_node_pre_reboot_on_finish` | bool | `true` | Whether to reboot the node after pre-configuration tasks complete | `node_pre.yml.j2` (all AAP hosts) |
| `platform_node_pre_reboot_timeout` | int | `1` | Time in minutes to wait for the node to come back up after reboot | `node_pre.yml.j2` (all AAP hosts) |

### Storage Layout (`platform_node_pre_storage`)

A list of logical volume definitions that are enforced on the node. Minimum sizes differ between 2.4 and 2.6 deployments; 2.6 allocates more space for container image storage.

Each list item has the following keys:

| Key | Type | Description |
|---|---|---|
| `lv_name` | string | Logical volume name (e.g. `lv_var`, `lv_home`, `lv_var_tmp`, `lv_tmp`) |
| `vg_name` | string | Volume group that contains the LV (always `vg_root` in RHIS) |
| `minimum_size` | string | Minimum size; the volume is grown if smaller (e.g. `"60G"`) |
| `state` | string | `present` to ensure the LV exists |

**Size differences between versions:**

| LV | 2.4 minimum | 2.6 minimum |
|---|---|---|
| `lv_var` | 60 GiB | 60 GiB |
| `lv_home` | 30 GiB | 60 GiB |
| `lv_var_tmp` | 6 GiB | 10 GiB |
| `lv_tmp` | 6 GiB | 10 GiB |

### Firewall Rules (`platform_node_pre_firewall`)

A list of firewall rule descriptors. Each item configures an inbound firewall rule for the node.

| Key | Type | Description |
|---|---|---|
| `service` | string | Firewalld service name (mutually exclusive with `port`) |
| `port` | string | Port/protocol string, e.g. `"27199/tcp"` (mutually exclusive with `service`) |
| `aap_source` | string | Traffic source descriptor (e.g. `"any"`) |
| `aap_destination` | string | Logical destination group (e.g. `"controllers"`, `"database"`, `"gateway"`) |
| `aap_reason` | string | Human-readable reason for the rule |
| `state` | string | `"present"` or `"absent"` |

Controller nodes open ports for: `ssh`, `http`, `https`, `cockpit`, `postgresql`, `redis`, `16379/tcp` (Redis cluster bus), `27199/tcp` (Receptor mesh). Hub nodes open the same except `27199/tcp` (Receptor is not used on standalone Hub deployments).

### SSL Certificate Paths

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `platform_ssl_certs_base_dir` | string | `"/etc/ipa/private"` | Base directory under which per-host certificate subdirectories are created | `node_pre.yml.j2` (all AAP hosts) |
| `platform_node_pre_ssl_certs_dir` | string | `"{{ platform_ssl_certs_base_dir }}/{{ ansible_fqdn }}"` | Full path to this node's certificate directory | `node_pre.yml.j2` (all AAP hosts) |
| `platform_node_pre_cockpit_certs_dir` | string | `"/etc/cockpit/ws-certs.d/"` | Directory where Cockpit reads its TLS certificate | `node_pre.yml.j2` (all AAP hosts) |

### Certificate Generation (`platform_node_pre_certificates`)

A list of certificate specification dictionaries. The RHIS pre-configuration role issues certificates from IdM using these parameters. All four AAP host directories use identical structures.

| Key | Type | Description |
|---|---|---|
| `ssl_ca_cert_path` | string | Path to the IdM CA certificate (`/etc/ipa/ca.crt`) |
| `ssl_certs_dir` | string | Directory where the issued certificate and key are stored |
| `ssl_cert_path` | string | Full path for the issued certificate file |
| `ssl_key_path` | string | Full path for the issued private key file |
| `ssl_passfile` | string | Path to the passphrase file for the encrypted private key |
| `ssl_private_key_cipher` | string | Cipher used to encrypt the private key (`aes256`) |
| `ssl_private_key_size` | string | RSA key size in bits (`4096`) |
| `ssl_private_key_pem_path` | string | Path to the PEM-format private key |
| `ssl_csr_path` | string | Path to the Certificate Signing Request file |
| `ssl_crt_service_type` | string | Kerberos principal service type for IdM (`HTTP`) |
| `ssl_crt_force_regen` | bool | Force certificate regeneration even if one already exists (`true`) |
| `csr_digest` | string | Digest algorithm for the CSR (`aes256`) |
| `csr_organization_name` | string | Certificate O field; derived from `ansible_domain | upper` |
| `csr_organization_unit_name` | string | Certificate OU field (`Lab`) |
| `csr_locality_name` | string | Certificate L field (`Hespeler`) |
| `csr_state_or_province_name` | string | Certificate ST field (`ON`) |
| `csr_country_name` | string | Certificate C field (`CA`) |
| `csr_email_address` | string | Certificate email SAN; `admin@{{ ansible_domain }}` |

---

## Post-installation Configuration (`platform_post.yml.j2`)

Applies after the AAP installer completes. All four AAP host directories use an identical `platform_post.yml.j2`. Variables here drive manifest upload and LDAP authentication configuration.

### AAP Manifest

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `aap_manifest_name` | string | `"rhis_app_manifest"` | Logical name of the AAP subscription manifest; used to identify the manifest object | `platform_post.yml.j2` |
| `aap_manifest_dest` | string | `"/tmp/rhis_aap_manifest.zip"` | Local path on the controller node where the manifest zip is staged before upload | `platform_post.yml.j2` |
| `aap_manifest_portal_url` | string | `"https://subscription.rhsm.redhat.com"` | Red Hat Subscription Management portal URL from which the manifest is downloaded | `platform_post.yml.j2` |
| `aap_manifest_validate_certs` | bool | `false` | Whether to validate TLS certificates when downloading the manifest from the portal | `platform_post.yml.j2` |
| `aap_validate_certs` | bool | `false` | Whether the post-configuration role validates TLS certificates when connecting to the AAP API | `platform_post.yml.j2` |

### AAP Admin Credentials (post-install)

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `aap_admin_username` | string | — | Admin username used by the post-configuration role to authenticate to the AAP API | `platform_post.yml.j2` |
| `aap_ldap_domain_map` | string | `"dc={{ split_runtime_global_domain_name[0] }},dc={{ split_runtime_global_domain_name[1] }}"` | LDAP base DN constructed from the split global domain name; used in all LDAP configuration settings | `platform_post.yml.j2` |

### LDAP Authentication Settings (`aap_settings`)

A list with a single item (`name: "authentication"`) containing a `settings` dictionary. These values are POSTed to the AAP settings API endpoint to configure LDAP-backed authentication against IdM.

| Setting Key | Type | Description |
|---|---|---|
| `AUTH_LDAP_SERVER_URI` | string | URI of the LDAP server: `ldap://{{ ipa_server_fqdn }}:389` |
| `AUTH_LDAP_USER_DN_TEMPLATE` | string | DN template for user lookups: `uid=%(user)s,cn=users,cn=accounts,{{ aap_ldap_domain_map }}` |
| `AUTH_LDAP_GROUP_TYPE` | string | django-ldap group type: `NestedMemberDNGroupType` (supports nested group membership) |
| `AUTH_LDAP_REQUIRE_GROUP` | string | LDAP group DN that a user must belong to in order to log in: `cn=aapgroup-user,cn=groups,cn=accounts,...` |
| `AUTH_LDAP_GROUP_SEARCH` | string (JSON) | JSON-encoded list specifying the LDAP group search base, scope, and filter |
| `AUTH_LDAP_GROUP_TYPE_PARAMS` | dict | Parameters for the group type: `member_attr: member`, `name_attr: cn` |
| `AUTH_LDAP_USER_FLAGS_BY_GROUP` | string (JSON) | Maps LDAP group membership to Django user flags; grants `is_superuser` to members of `cn=aapgroup-administrator,...` |
| `AUTH_LDAP_USER_ATTR_MAP` | dict | Maps LDAP attributes to AAP user fields: `email←mail`, `first_name←givenName`, `last_name←sn` |

---

## Hub API Client Settings (`main.yml` — Hub hosts only)

Defined in `aaphub24/main.yml` and `aaphub26/main.yml`. These variables are consumed by roles that interact with the Private Automation Hub REST API (e.g. `infra.ah_configuration`). The file content is identical between 2.4 and 2.6.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `ah_api_path_prefix` | string | `"galaxy"` | URL path prefix for the Automation Hub Galaxy API endpoint | `main.yml` (hubs) |
| `ah_username` | string | — | Username for authenticating to the Hub API | `main.yml` (hubs) |
| `ah_update_interval_sec` | int | `1` | Polling interval in seconds when waiting for Hub async operations | `main.yml` (hubs) |
| `ah_request_timeout_sec` | int | `60` | HTTP request timeout in seconds for Hub API calls | `main.yml` (hubs) |
| `ah_validate_certs` | bool | `true` | Whether to validate TLS certificates when connecting to the Hub API | `main.yml` (hubs) |

---

## Hub Collection Remotes and Repositories (`repositories.yml` — Hub hosts only)

Defined in `aaphub24/repositories.yml` and `aaphub26/repositories.yml`. The content is identical between 2.4 and 2.6. These variables configure `infra.ah_configuration` to create and sync collection remote sources and local repository objects in Private Automation Hub.

### `collection_remotes`

A list of remote source definitions. Each entry creates a remote in Hub that points to an upstream Ansible Galaxy or Red Hat Cloud instance.

| Key | Type | Description |
|---|---|---|
| `name` | string | Unique name for the remote (e.g. `rh-validated`, `rh-certified`, `community`) |
| `url` | string | Upstream URL for the remote |
| `include_deps` | bool | Whether to include collection dependencies when syncing |
| `token` | string | API token for authenticated remotes (RH cloud remotes) |
| `sso_url` | string | SSO URL used with the token for Red Hat cloud remotes |
| `requirements` | dict | Inline requirements list (used for the `community` remote to limit which collections are synced) |
| `tls_validation` | bool | Whether to validate TLS when connecting to the remote |
| `download_concurrency` | int | Number of parallel download threads (default: `10`) |
| `rate_limit_req_per_sec` | int | API request rate limit (only set for `community` remote: `8`) |

**Configured remotes:**

| Remote name | URL | Auth method |
|---|---|---|
| `rh-validated` | `https://console.redhat.com/api/automation-hub/content/validated/` | Token + SSO URL |
| `rh-certified` | `https://console.redhat.com/api/automation-hub/content/published/` | Token + SSO URL |
| `community` | `https://galaxy.ansible.com/api/` | None (public) |

**Community collections synced:** `community.aws`, `community.azure`, `community.crypto`, `community.docker`, `community.general`, `community.google`, `community.grafana`, `community.kubevirt`, `community.libvirt`, `community.mysql`, `community.network`, `community.postgresql`, `vmware.vmware`, `community.windows`.

### `collection_repositories`

A list of repository definitions inside Hub. Each repository is backed by one remote.

| Key | Type | Description |
|---|---|---|
| `name` | string | Repository name in Hub |
| `description` | string | Human-readable description |
| `retained_versions` | int | Number of collection versions to retain (`3` for validated; `1` for others) |
| `validated_distribution` | bool | Whether to mark as a validated distribution (`false` for all configured repos) |
| `pipeline` | string | Content pipeline mode (`"none"` for all configured repos) |
| `labels` | list | List of label strings applied to the repository (empty for all) |
| `hide_from_search` | bool | Whether to hide this repo from Hub search (`false` for all) |
| `private` | bool | Whether the repository is private (`false` for all) |
| `remote` | string | Name of the `collection_remotes` entry this repository syncs from |
| `sync_wait` | bool | Whether to wait synchronously for sync completion (`false` for all; syncs run asynchronously) |
