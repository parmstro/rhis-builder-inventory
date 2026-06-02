# Host: satellite — Primary Satellite Variables

Schema Version: 1.0.0

These variables configure the primary Red Hat Satellite server. Satellite manages content lifecycle, provisioning, patch management, and subscription entitlements for the RHIS infrastructure.

> **Note:** The `satellite` host_vars directory is large, reflecting the breadth of Satellite's configuration surface. Despite its size, the contents follow common, repeating patterns throughout — once familiar with one section, the others will feel immediately recognizable. A significant portion of the configuration is boilerplate that applies directly to most customer environments with little or no modification. Users are encouraged to review the full set and adjust only what is specific to their environment rather than starting from scratch.

Upstream collection: `redhat.satellite` — refer to the [collection documentation](https://console.redhat.com/ansible/automation-hub/repo/published/redhat/satellite/) for authoritative variable references.

---

## main.yml — Core Satellite Identity and Connection

Top-level connection and identity variables used across all Satellite roles.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `use_completion_logic` | bool | `true` | Enable task completion tracking logic | rhis-builder-satellite |
| `satellite_fqdn` | string | `{{ ansible_fqdn }}` | Fully-qualified domain name of the Satellite server | all roles |
| `satellite_domain` | string | derived from `ansible_fqdn` | DNS domain portion of the Satellite FQDN | all roles |
| `satellite_username` | string | — | Satellite admin username (references vault) | all roles |
| `satellite_password` | string | — | Satellite admin password (references vault) | all roles |
| `satellite_admin_email` | string | `admin@{{ satellite_domain }}` | Email address for the initial admin account | satellite_installer |
| `satellite_initial_location` | string | `"Default Location"` | Name of the initial Satellite location created at install | satellite_installer |
| `satellite_initial_organization` | string | `"Default Organization"` | Name of the initial Satellite organization created at install | satellite_installer |
| `satellite_location` | string | `{{ satellite_initial_location }}` | Active location context for Satellite API calls | all roles |
| `satellite_organization` | string | `{{ satellite_initial_organization }}` | Active organization context for Satellite API calls | all roles |
| `satellite_url` | string | `https://{{ satellite_fqdn }}/` | Base URL used to access the Satellite API | all roles |
| `satellite_virtwho_username` | string | — | virt-who service account username (references vault) | virtwho_configs |
| `satellite_virtwho_password` | string | — | virt-who service account password (references vault) | virtwho_configs |
| `satellite_validate_certs` | bool | `true` | Whether to validate TLS certificates when calling the Satellite API | all roles |
| `satellite_disconnected` | bool | `false` | Set `true` when operating in disconnected/air-gapped mode. Enables ISO-based installation and export/import content flow | satellite_pre, satellite_installer |
| `satellite_disconnected_root` | string | `"/var/media"` | Root mount path for offline media (uncommented when disconnected) | satellite_pre |
| `satellite_os_iso_source` | string | — | Filename of the RHEL OS DVD ISO (disconnected only) | satellite_pre |
| `satellite_install_iso_source` | string | — | Filename of the Satellite installer DVD ISO (disconnected only) | satellite_pre |
| `satellite_os_repo_mount` | string | — | Mount point for the RHEL OS ISO (disconnected only) | satellite_pre |
| `satellite_install_repo_mount` | string | — | Mount point for the Satellite installer ISO (disconnected only) | satellite_pre |
| `satellite_os_repo_template_name` | string | — | Jinja2 template name for generating the OS repo file (disconnected only) | satellite_pre |
| `satellite_os_repo_template_dest` | string | — | Destination path on the Satellite host for the generated repo file (disconnected only) | satellite_pre |
| `satellite_cdn_configuration_type` | string | — | CDN configuration type; set to `"export_sync"` for disconnected installs | satellite_pre |

---

## satellite_pre.yml — Pre-Installation and IdM Integration

Variables controlling OS prerequisites, firewall, IdM client enrollment, SSL certificate generation, and libvirt TLS setup. Run before `satellite-installer`.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `async_timeout` | int | `14400` | Maximum seconds for async task execution | satellite_pre |
| `async_delay` | int | `30` | Polling interval (seconds) for async tasks | satellite_pre |
| `apply_standard_tuning` | bool | `true` | Install `tuned` and apply standard tuning profile (disables transparent huge pages) | satellite_pre |
| `cdn_organization_id` | string | — | Red Hat CDN organization ID for initial host registration (references vault) | satellite_pre |
| `cdn_sat_activation_key` | string | — | CDN activation key for registering the Satellite host (references vault) | satellite_pre |
| `sat_repository_ids` | list of string | — | List of repository IDs to enable on the Satellite host OS prior to installation | satellite_pre |
| `sat_firewalld_zone` | string | `"public"` | Firewalld zone to configure | satellite_pre |
| `sat_firewalld_interface` | string | `{{ ansible_default_ipv4.interface }}` | Network interface to assign to the firewalld zone | satellite_pre |
| `sat_override_iface` | string | `""` | Optional override for the firewalld interface | satellite_pre |
| `sat_firewalld_services` | list of string | — | List of firewalld service names to allow | satellite_pre |
| `satellite_pre_use_idm` | bool | `true` | Enable IdM client enrollment and Kerberos integration. Set `false` to skip IdM entirely | satellite_pre, satellite_installer |
| `use_non_idm_certs` | bool | `false` | Must be `true` only when `satellite_pre_use_idm` is `false` | satellite_pre |
| `skip_prepare_realm` | bool | `false` | Skip keytab generation for the realm user; useful when capsules already hold the keytab | satellite_pre |
| `ipa_generate_certs` | bool | `true` | Generate IPA-signed SSL certificates for Satellite | satellite_pre |
| `ipa_admin_password` | string | — | IdM admin password (references vault) | satellite_pre |
| `ipa_admin_principal` | string | — | IdM admin principal (references vault) | satellite_pre |
| `ipa_server_fqdn` | string | `idm1.{{ _runtime_global_domain_name }}` | FQDN of the primary IdM server | satellite_pre |
| `ipa_server_domain` | string | `{{ _runtime_global_domain_name }}` | DNS domain of the IdM server | satellite_pre |
| `ipa_server_realm` | string | derived (uppercased domain) | Kerberos realm name | satellite_pre |
| `ipa_client_domain` | string | `{{ ipa_server_domain }}` | DNS domain for the IdM client | satellite_pre |
| `ipa_client_configure_dns_resolver` | bool | `true` | Configure the DNS resolver for the IdM client | satellite_pre |
| `ipa_client_mkhomedir` | bool | `true` | Automatically create home directories for IdM users on first login | satellite_pre |
| `ipasssd_enable_dns_updates` | bool | `true` | Enable SSSD dynamic DNS updates | satellite_pre |
| `ipa_client_dns_servers` | string | `{{ _default_network }}.5` | DNS server IP for the IdM client | satellite_pre |
| `ipa_dns_reverse_zone` | string | `"168.192.in-addr.arpa"` | Reverse DNS zone for the lab network | satellite_pre |
| `ipa_dns_zone` | string | `{{ _runtime_global_domain_name }}` | Forward DNS zone | satellite_pre |
| `ipa_default_bind_policy` | string | — | BIND dynamic update policy for forward DNS records | satellite_pre |
| `ipa_default_bind_policy_reverse` | string | — | BIND dynamic update policy for reverse DNS records | satellite_pre |
| `ipaadmin_password` | string | — | Alias for `ipa_admin_password`; required by the `ipaclient` role (references vault) | ipaclient role |
| `ipaadmin_principal` | string | — | Alias for `ipa_admin_principal`; required by the `ipaclient` role (references vault) | ipaclient role |
| `ipaserver_fqdn` | string | `{{ ipa_server_fqdn }}` | Alias for `ipa_server_fqdn`; required by the `ipaclient` role | ipaclient role |
| `ipaclient_domain` | string | `{{ ipa_server_domain }}` | Domain for the `ipaclient` role | ipaclient role |
| `ipaclient_realm` | string | `{{ ipa_server_domain \| upper }}` | Kerberos realm for the `ipaclient` role | ipaclient role |
| `ipaclient_configure_dns_resolver` | bool | `{{ ipa_client_configure_dns_resolver }}` | DNS resolver configuration for the `ipaclient` role | ipaclient role |
| `ipaclient_dns_servers` | string | `{{ ipa_client_dns_servers }}` | DNS server for the `ipaclient` role | ipaclient role |
| `ipaclient_mkhomedir` | bool | `{{ ipa_client_mkhomedir }}` | Homedir creation for the `ipaclient` role | ipaclient role |
| `ipaclient_force_join` | bool | `true` | Force re-enrollment even if the host already exists in IdM | ipaclient role |
| `foreman_proxy_realm_role_name` | string | `"Smart Proxy Host Manager"` | Name of the IdM role assigned to the realm-capsule principal | satellite_pre |
| `foreman_proxy_realm_principal` | string | `"realm-capsule"` | Kerberos principal name used by the foreman-proxy for DNS and realm operations | satellite_pre, satellite_installer |
| `foreman_proxy_dns_update_policy` | string | — | BIND update policy grant for the realm principal (forward zone) | satellite_pre |
| `foreman_proxy_bind_update_policy` | string | — | Combined BIND update policy for the forward zone. The policy is intentionally broad to grant the foreman-proxy user the permissions required to create and update DNS entries. In the RHIS default configuration with IdM, the foreman-proxy user is a realm user with a specific RBAC role configured in IdM (`foreman_proxy_realm_role_name`). The user authenticates via a keytab used for both IdM management and Ansible remote execution. The keytab is properly protected and access is restricted to the foreman-proxy process. If desired, a stricter update policy may be substituted; however, thorough testing is strongly recommended as the default policy is tested and documented. | satellite_pre |
| `foreman_proxy_dns_update_policy_reverse` | string | — | BIND update policy grant for the realm principal (reverse zone) | satellite_pre |
| `foreman_proxy_bind_update_policy_reverse` | string | — | Combined BIND update policy for the reverse zone. See `foreman_proxy_bind_update_policy` note above. | satellite_pre |
| `keytab_retrieval_password` | string | — | Password used to retrieve the keytab from IdM (references vault) | satellite_pre |
| `keytab_retrieval_dn` | string | — | LDAP DN used to retrieve the keytab from IdM (references vault) | satellite_pre |
| `crt_service_type` | string | `"HTTP"` | Kerberos service type for the SSL certificate | satellite_pre |
| `crt_force_regen` | bool | `true` | Force certificate regeneration even if one already exists | satellite_pre |
| `sat_ssl_certs_dir` | string | `/etc/ipa/private/{{ ansible_fqdn }}/` | Directory holding the Satellite SSL certificates | satellite_pre, satellite_installer |
| `sat_ssl_rsa_key_pass` | string | — | Passphrase for the Satellite RSA private key (references vault) | satellite_pre |
| `sat_ssl_crt_path` | string | derived | Path to the Satellite SSL certificate | satellite_installer |
| `sat_ssl_key_path` | string | derived | Path to the Satellite SSL private key | satellite_installer |
| `sat_ssl_csr_path` | string | derived | Path to the Satellite SSL certificate signing request | satellite_pre |
| `sat_ssl_ca_crt_path` | string | `{{ ipa_server_ca_crt_path }}` | Path to the CA certificate used to sign the Satellite cert | satellite_installer |
| `ipa_server_ca_crt_path` | string | `"/etc/ipa/ca.crt"` | Filesystem path to the IdM CA certificate | satellite_pre |
| `passfile` | string | derived | Path to the passphrase file for key operations | satellite_pre |
| `ssl_private_key_cipher` | string | `"aes256"` | Cipher for encrypting the private key | satellite_pre |
| `ssl_private_key_size` | int | `4096` | RSA key size in bits | satellite_pre |
| `ssl_private_key_pem_path` | string | derived | Path to the PEM-encoded private key | satellite_pre |
| `ssl_public_key_path` | string | derived | Path to the public key file | satellite_pre |
| `ssl_public_key_format` | string | `"PEM"` | Format of the public key | satellite_pre |
| `csr_digest` | string | `"aes256"` | Digest algorithm for the CSR | satellite_pre |
| `csr_organization_name` | string | `{{ ansible_domain \| upper }}` | Organization name for the CSR subject | satellite_pre |
| `csr_organization_unit_name` | string | `"Demo Lab"` | Organizational unit for the CSR subject | satellite_pre |
| `csr_locality_name` | string | `"Hespeler"` | Locality for the CSR subject | satellite_pre |
| `csr_state_or_province_name` | string | `"ON"` | Province/state for the CSR subject | satellite_pre |
| `csr_country_name` | string | `"CA"` | Country code for the CSR subject | satellite_pre |
| `csr_email_address` | string | `admin@{{ ansible_domain }}` | Email address for the CSR subject | satellite_pre |
| `host_ssl_certs_dir` | string | `{{ sat_ssl_certs_dir }}` | Certificate directory alias for libvirt TLS setup | satellite_pre |
| `host_ssl_rsa_key_pass` | string | `{{ sat_ssl_rsa_key_pass }}` | Key passphrase alias for libvirt TLS setup | satellite_pre |
| `libvirt_non_idm_ca_crt_path` | string | derived | Path to a non-IdM CA cert for libvirt (used when no IdM) | satellite_pre |
| `libvirt_client_private_key_pem_path` | string | derived | Path to the libvirt client PEM private key | satellite_pre |
| `libvirt_client_key_path` | string | derived | Path to the libvirt client key | satellite_pre |
| `libvirt_client_csr_path` | string | derived | Path to the libvirt client CSR | satellite_pre |
| `libvirt_client_crt_path` | string | derived | Path to the libvirt client certificate | satellite_pre |
| `libvirt_client_crt_service_type` | string | `"libvirtclient"` | Kerberos service type for the libvirt client certificate | satellite_pre |
| `libvirt_server_private_key_pem_path` | string | derived | Path to the libvirt server PEM private key | satellite_pre |
| `libvirt_server_key_path` | string | derived | Path to the libvirt server key | satellite_pre |
| `libvirt_server_csr_path` | string | derived | Path to the libvirt server CSR | satellite_pre |
| `libvirt_server_crt_path` | string | derived | Path to the libvirt server certificate | satellite_pre |
| `libvirt_server_crt_service_type` | string | `"libvirt"` | Kerberos service type for the libvirt server certificate | satellite_pre |

**Note:** These libvirt TLS variables are part of a shared cross-role contract. Satellite carries both client and server certificates because the `qemu+tls://` connection to KVM hypervisors is **mutually authenticated** — either end can initiate a connection. The KVM hypervisor carries the same variable set. See `schema/variables/host_vars/kvm.md` for the full mutual TLS documentation.

---

## satellite_installer.yml — Satellite Installer Options

Variables controlling the `satellite-installer` invocation, including tuning profile, proxy options, DHCP ranges, and optional feature flags.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `foreman_proxy_realm_principal` | string | — | Kerberos principal for the Smart Proxy (set in `satellite_pre.yml`) | satellite_installer |
| `dhcp_interface` | string | first `e*` interface | Network interface for Satellite-managed DHCP | satellite_installer |
| `satellite_tuning_size` | string | `"default"` | Satellite performance profile. Values: `default` (up to 5,000 hosts / 20 GiB / 4 cores), `medium`, `large`, `extra-large`, `extra-extra-large` | satellite_installer |
| `sat_installer_verbose` | bool | `true` | Enable verbose output from `satellite-installer` | satellite_installer |
| `sat_installer_options` | list of string | — | Complete ordered list of `satellite-installer` CLI arguments. Covers: Puma thread/worker tuning, initial org/location/admin, SSL certs, IdM auth, DNS/TSIG, Realm/keytab, PXE/TFTP/registration, DHCP range/gateway/nameservers, and content types (ansible, deb, docker, file, yum). Compute resource plugins enabled: ec2, libvirt, vmware | satellite_installer |

---

## satellite_post.yml — Post-Installation PostgreSQL Tuning

Database tuning applied after the Satellite installer completes.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `satellite_post` | dict | — | PostgreSQL tuning parameters | satellite_post |
| `satellite_post.postgres_max_connections` | int | `1000` | Maximum number of PostgreSQL connections | satellite_post |
| `satellite_post.postgres_shared_buffers` | string | `"16GB"` | PostgreSQL `shared_buffers` setting | satellite_post |
| `satellite_post.postgres_work_mem` | string | `"8MB"` | PostgreSQL `work_mem` setting | satellite_post |
| `satellite_post.postgres_avcl` | int | `2000` | PostgreSQL `autovacuum_vacuum_cost_limit` setting | satellite_post |

---

## manifests.yml — Red Hat Subscription Manifest

Controls how the Satellite manifest is obtained. The manifest grants entitlement for content synchronization. On the primary Satellite, the manifest is generated from the CDN directly.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `redhat_manifests` | list of dict | — | List of manifest definitions | manifest role |

Each `redhat_manifests` entry schema:

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Manifest name (typically `{{ ansible_fqdn }}`) |
| `account` | string | when `generate: true` | CDN account number (references vault) |
| `cdn_username` | string | when `generate: true` | CDN username for manifest generation (references vault) |
| `cdn_password` | string | when `generate: true` | CDN password for manifest generation (references vault) |
| `content_access_mode` | string | no | `"org_environment"` enables Simple Content Access (SCA) mode |
| `generate` | bool | yes | `true` = generate/manage via CDN API; `false` = upload a pre-existing zip file |
| `organization` | string | yes | Satellite organization to assign the manifest to |
| `source` | string | when `generate: false` | Filename of the manifest zip in the `files/` directory |
| `path` | string | yes | Destination path on the Satellite host for the manifest file |
| `portal_url` | string | no | Red Hat Subscription Management portal URL |
| `state` | string | yes | `present`, `absent`, or `refreshed` |
| `subs` | dict | when `generate: true` and `state: present` | Subscription pool definitions (references vault). Each entry: `name`, `pool_id`, `pool_state`, `qty` |
| `validate_certs` | bool | no | Validate CDN TLS certificates |

> **Note:** `discosatellite` sets `generate: false` and provides a pre-exported manifest zip by filename. It does not contact the CDN directly.

---

## content_credentials.yml — GPG Keys and SSL Certificates

Defines GPG keys and SSL certificates registered in Satellite for verifying custom product repositories.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `content_credentials` | list of dict | — | List of content credential definitions | content_credentials role |

Each `content_credentials` entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | Unique credential name in Satellite |
| `content_type` | string | `"gpg_key"` or `"cert"` |
| `content_source` | string | `"file"` (read from local filesystem) or `"url"` (fetch from remote URL). **Disconnected satellites must use `"file"` only.** |
| `content_path` | string | Filesystem path (for `file`) or URL (for `url`) of the credential content |
| `state` | string | `"present"` or `"absent"` |

Standard credentials defined: `RedHatGPG`, `RedHatSSL`, `CentOS9OfficialGPG`, `OracleLinux7GPG`, `CentOS79GPG`, `MicrosoftGPG`, `EPEL7GPG`, `EPEL8GPG`, `EPEL9GPG`, `POSTGRES-RHEL`.

---

## custom_products.yml — Custom (Non-Red Hat) Products and Repositories

Defines custom products and their repositories for third-party or community content. Includes CDN public repos (convert2RHEL), community repos (EPEL, CentOS, OEL), and container registries.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `custom_products` | list of dict | — | List of custom product definitions | custom_products role |

Each `custom_products` entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | Product name |
| `desc` or `description` | string | Product description |
| `org` | string | Satellite organization |
| `label` | string | Short unique label for the product |
| `repositories` | list of dict | Repository definitions (see below) |

Each `repositories` entry within a custom product:

| Field | Type | Description |
|---|---|---|
| `name` | string | Repository name |
| `label` | string | Repository label (optional; auto-generated if omitted) |
| `description` | string | Repository description (optional) |
| `upstream_name` | string | Upstream repository name (for container repos: `docker_upstream_name`) |
| `content_type` | string | `"yum"`, `"docker"`, `"file"`, etc. |
| `url` | string | Upstream repository URL |
| `username` / `password` | string | Credentials for authenticated repositories |
| `gpg_key` | string | Content credential name for GPG verification |
| `download_policy` | string | `"immediate"` or `"on_demand"` |
| `include_tags` / `exclude_tags` | string | Tag filters for container repositories |
| `upstream_username` / `upstream_password` | string | Registry credentials for container pulls (references vault) |

Products defined: `Red Hat Client Tools for RHEL`, `CentOS79`, `OEL79`, `EPEL8`, `EPEL9`, `CentOS Stream 9`, `Microsoft SQL Server for Linux 2022 for RHEL 8`, `Microsoft SQL Server for Linux 2022 for RHEL 9`, `rhel9_containers`.

---

## repository_sets.yml — Red Hat Repository Sets

Enables Red Hat-provided repository sets from the CDN (requires a valid manifest). Includes control variables for publish/sync behaviour.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `skip_sync` | bool | `false` | Skip content synchronization during the run | content roles |
| `skip_publish_all` | bool | `false` | Skip publishing all CVs and CCVs during the run | content roles |
| `repository_sets` | list of dict | — | List of repository set definitions to enable | repository_sets role |

Each `repository_sets` entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | Repository set name as shown in the Satellite CDN catalog |
| `product` | string | Red Hat product the repository set belongs to |
| `repository_list` | list of dict | Optional list of `releasever` and/or `basearch` entries to enable specific releases. Omit to enable all available |

Repository sets are organized into product families: RHEL 10 x86_64, RHEL 10 aarch64, RHEL 9 x86_64, RHEL 9 aarch64, RHEL 8 x86_64, RHEL 7.x (including ELS), AAP 2.4/2.6, Satellite 6.18, JBoss EAP 7.4/8.x, and convert2RHEL repositories.

---

## repositories.yml — Repository Download Policy Overrides

Overrides default download policy settings for individual repositories that have already been enabled via repository sets or custom products. All entries use `download_policy: "immediate"` to ensure content is fully synced locally — required for export to disconnected satellites.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `satellite_repositories` | list of dict | — | List of repository override definitions | repositories role |

Each `satellite_repositories` entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | Exact repository name as it appears in Satellite |
| `product` | string | Product the repository belongs to |
| `content_type` | string | `"yum"`, `"file"`, `"docker"`, etc. |
| `download_policy` | string | `"immediate"`, `"on_demand"`, or `"background"` |
| `gpg_key` | string | Content credential name (optional; overrides product default) |
| `ssl_ca_cert` | string | SSL CA certificate credential name (optional) |
| `unprotected` | bool | Whether the repository is accessible without authentication (optional) |

---

## content_views.yml — Content Views and Composite Content Views

Defines all Content Views (CVs) and Composite Content Views (CCVs). CVs filter and version content; CCVs compose multiple CVs. Includes errata date filter variables.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `errata_end_date` | string | `{{ ansible_date_time.date }}` | Cut-off date for errata inclusion filters | content_views role |
| `skip_publish_all` | bool | `false` | Skip publishing all CVs/CCVs | content_views role |
| `content_views` | list of dict | — | List of Content View definitions | content_views role |
| `composite_content_views` | list of dict | — | List of Composite Content View definitions | content_views role |

Each `content_views` entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | Content view name |
| `desc` | string | Description |
| `org` | string | Satellite organization |
| `force_publish` | bool | Force republication even if content has not changed |
| `publication_threshold_hours` | int | Skip republication if the CV was published within this many hours |
| `repositories` | list of dict | Repositories included: each has `name` and `product` |
| `filters` | list of dict | Content filters (see below) |
| `date_filter_name` | string | Name of the errata-by-date filter to update on each publish |
| `environments` | list of string | Lifecycle environments to promote to on publish |

Each filter within `filters`:

| Field | Type | Description |
|---|---|---|
| `name` | string | Filter name |
| `type` | string | `"rpm"`, `"erratum"`, `"modulemd"` |
| `inclusion` | bool | `true` = include-filter; `false` = exclude-filter |
| `description` | string | Filter description |
| `original_packages` | bool | Include packages not covered by the filter (rpm filters) |
| `original_module_streams` | bool | Include module streams not covered by the filter (modulemd filters) |
| `repositories` | string | `"[]"` = apply to all repositories in the CV |
| `rules` | list of dict | Filter rules; errata rules use `name`, `end_date`, `date_type`, `types` |

Each `composite_content_views` entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | CCV name |
| `desc` | string | Description |
| `org` | string | Satellite organization |
| `force_publish` | bool | Force republication |
| `publication_threshold_hours` | int | Publication threshold in hours |
| `components` | list of dict | Component CVs: each has `content_view` (name) and `latest: true` |
| `environments` | list of string | Lifecycle environments to promote to |

CVs defined (representative): `AAP24_Files`, `AAP24_RPMs`, `AAP26_RHEL9_Files`, `AAP26_RHEL9_RPMs`, `AAP26_RHEL10_Files`, `AAP26_RHEL10_RPMs`, `RHEL9_EdgeManager`, `EPEL8`, `EPEL9`, `convert2rhel7/8/9`, `SOE10`, `SOE10_aarch64`, `SOE9`, `SOE9_aarch64`, `SOE8`, `SOE7`, `SOE7ELS`, `CentOS79`, `OEL79`, `LEAPP_2_RHEL8`, `LEAPP_2_RHEL9`, `mssqlserver2022_rhel9`, `JBoss8EAP74`, `JBoss8EAP8`, `JBoss9EAP74`, `JBoss9EAP8`, `CentOS_S9`.

CCVs defined: `SOE9_AAP24`, `SOE9_AAP26`, `SOE10_AAP26`, `SOE9_EdgeManager`, `SOE8_EPEL`, `SOE9_EPEL`, `convert_CentOS2RHEL7`, `convert_OEL2RHEL7`, `LEAPP_7_2_8`, `LEAPP_8_2_9`, `SOE8_JBoss`, `SOE9_JBoss`, `SOE9_MSSQL`.

---

## lifecycle_environments.yml — Lifecycle Environments

Defines the content promotion pipeline stages.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `lifecycle_environments` | list of dict | — | Ordered list of lifecycle environment definitions | lifecycle_environments role |

Each `lifecycle_environments` entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | Environment name |
| `label` | string | Short label (no spaces) |
| `description` | string | Description |
| `organization` | string | Satellite organization |
| `prior` | string | Name of the preceding environment in the chain |

Default pipeline: `Library` → `Development` → `Qualification` → `Production` → `Retired`.

---

## activation_keys.yml — Activation Keys

Activation keys bind hosts to content views, lifecycle environments, and subscription purposes. A key is required for every CV × lifecycle environment combination used in hostgroups.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `activation_keys` | list of dict | — | List of activation key definitions | activation_keys role |

Each `activation_keys` entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | Activation key name |
| `state` | string | `"present"` or `"absent"` |
| `description` | string | Description |
| `organization` | string | Satellite organization |
| `auto_attach` | bool | Automatically attach matching subscriptions |
| `content_overrides` | list of dict | Repository enable/disable overrides; each has `label` and `override` (`"enabled"` or `"disabled"`) |
| `content_view` | string | Content view name to associate |
| `lifecycle_environment` | string | Lifecycle environment name to associate |
| `unlimited_hosts` | bool | Allow unlimited host registrations |
| `purpose_role` | string | System purpose role (e.g., `"Red Hat Enterprise Linux Server"`) |
| `purpose_usage` | string | System purpose usage (`"Development/Test"`, `"Production"`, `"Disaster Recovery"`) |
| `service_level` | string | Service level agreement (`"Premium"`, `"Standard"`, `"Self-Support"`) |

Keys are defined for every SOE version (RHEL 7–10), per environment (dev/qa/prod), and for specialized workloads: AAP, JBoss, EPEL, LEAPP, convert2RHEL, CentOS79, OEL79, satellite capsule.

---

## sync_plans.yml — Sync Plans

Defines recurring schedules for content synchronization.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `sync_plans` | list of dict | — | List of sync plan definitions | sync_plans role |

Each `sync_plans` entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | Sync plan name |
| `desc` | string | Description |
| `interval` | string | Recurrence: `"daily"`, `"weekly"`, `"monthly"`, `"custom cron"` |
| `sync_date` | string | Start date/time in `YYYY-MM-DD HH:MM:SS` format |
| `enabled` | bool | Whether the sync plan is active |
| `organization` | string | Satellite organization |
| `location` | string | Satellite location |

Plans defined: `nightly_os` (00:30), `nightly_infra` (02:30), `nightly_third_party` (03:30).

---

## sync_plan_product_map.yml — Sync Plan-to-Product Associations

Maps products to their sync plans.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `product_plans` | list of dict | — | List of product-to-sync-plan assignments | sync_plan role |

Each `product_plans` entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | Product name as it appears in Satellite |
| `plan` | string | Sync plan name to associate |
| `organization` | string | Satellite organization |

---

## synchronization.yml — Sync Control

Global overrides for ad-hoc synchronization runs.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `last_sync_threshold_hours` | int | `24` | Repos synced within this window are skipped on ad-hoc runs | synchronization role |
| `skip_sync_all` | bool | `false` | Skip all repository synchronization | synchronization role |

---

## content_exports.yml — Content Export Configuration

Defines content export jobs that package content for transfer to a disconnected satellite. On the primary satellite, a library export is configured.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `content_exports` | list of dict | — | List of content export definitions | content_exports role |

Each `content_exports` entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | Export job name |
| `type` | string | `"library"`, `"repository"`, or `"cv_version"` |
| `organization` | string | Satellite organization |
| `format` | string | `"importable"` (chunked, for import) or `"syncable"` (RPM-based, cannot be chunked) |
| `chunk_size_gb` | string | Chunk size in GB; only valid with `format: importable` |
| `destination_server` | string | FQDN of the target disconnected satellite; used to name the export directory |
| `fail_on_missing_content` | bool | Abort if any expected content is missing |
| `incremental` | bool | Perform an incremental export rather than a full export |
| `product` | string | Product name (required for `type: repository`) |
| `repository` | string | Repository name (required for `type: repository`) |
| `content_view` | string | CV name (required for `type: cv_version`) |
| `content_view_version` | string | CV version string (required for `type: cv_version`) |

---

## content_export_copies.yml — Export Copy Offload

Copies an already-completed export to removable media or an alternate path for physical transfer to a disconnected environment.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `content_export_copies` | list of dict | — | List of export copy definitions | content_export_copies role |

Each entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | Export name to copy |
| `type` | string | Export type (`"library"`, etc.) |
| `destination_server` | string | Name component used to locate the export on disk |
| `export_version` | string | Version string of the export to copy |
| `destination_folder` | string | Local path to copy the export to (e.g., removable media mount point) |

---

## content_imports.yml — Content Import Configuration

On the primary satellite, this file is minimal — it exists as a placeholder listing the `Library` import name. Actual import configuration is generated by the export role and placed on the disconnected satellite. See `discosatellite` for the active import workflow.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `content_imports` | list of dict | — | List of content import definitions | content_imports role |

---

## domains.yml — DNS Domains

Domains group hosts within a DNS zone and associate them with a capsule for DNS management.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `satellite_domains` | list of dict | — | List of domain definitions | domains role |

Each `satellite_domains` entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | DNS domain name |
| `description` | string | Domain description |
| `dns_capsule` | string | FQDN of the capsule responsible for DNS in this domain |
| `organizations` | list of string | Organizations associated with this domain |
| `locations` | list of string | Locations associated with this domain |

---

## subnets.yml — IP Subnets

Defines IP subnets managed by Satellite, including DHCP, DNS, TFTP, and template capsule assignments.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `satellite_subnets` | list of dict | — | List of subnet definitions | subnets role |

Each `satellite_subnets` entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | Subnet name |
| `description` | string | Subnet description |
| `network_type` | string | `"IPv4"` or `"IPv6"` |
| `network` | string | Network address |
| `prefix` | string | CIDR prefix length |
| `mask` | string | Subnet mask |
| `gateway` | string | Default gateway IP |
| `dns_primary` | string | Primary DNS server IP |
| `dns_secondary` | string | Secondary DNS server IP |
| `ipam` | string | IPAM mode (`"Internal DB"`, `"None"`, `"EUI-64"`, etc.) |
| `from_ip` | string | Start of DHCP/IPAM address range |
| `to_ip` | string | End of DHCP/IPAM address range |
| `boot_mode` | string | `"Static"` or `"DHCP"` |
| `discovery_capsule` | string | Capsule providing discovery in this subnet (optional) |
| `tftp_capsule` | string | Capsule providing TFTP in this subnet (optional) |
| `dns_capsule` | string | Capsule providing DNS in this subnet |
| `template_capsule` | string | Capsule providing provisioning templates in this subnet (optional) |
| `remote_execution_capsules` | list of string | Capsules providing remote execution in this subnet (optional) |
| `parameters` | list of dict | Subnet-level parameters (`name`, `parameter_type`, `value`) |
| `domains` | list of string | DNS domains associated with this subnet |
| `locations` | list of string | Locations associated with this subnet |
| `organizations` | list of string | Organizations associated with this subnet |

Subnets defined: the primary management network and a bond subnet.

---

## realms.yml — IdM/AD Realms

Registers IdM or Active Directory realms in Satellite for automated host enrollment during provisioning.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `satellite_realms` | list of dict | — | List of realm definitions | realms role |

Each `satellite_realms` entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | Realm name (uppercase, e.g., `EXAMPLE.COM`) |
| `organizations` | string | Satellite organization |
| `locations` | string | Satellite location |
| `realm_type` | string | `"Red Hat Identity Management"` or `"Active Directory"` |
| `realm_capsule` | string | FQDN of the capsule managing this realm |

---

## locations.yml — Locations

Defines additional Satellite locations beyond the initial default. The default location is created during installation. This file contains commented-out examples for cloud locations (Azure, AWS).

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `satellite_locations` | list of dict | — | List of additional location definitions | locations role |

Each entry schema: `name`, `organizations` (list), `parameters` (list of `name`, `parameter_type`, `value`), `state`.

---

## organizations.yml — Organizations

Defines additional Satellite organizations beyond the initial default. Contains commented-out example only.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `satellite_organizations` | list of dict | — | List of additional organization definitions | organizations role |

Each entry schema: `name`, `description`, `label`, `parameters` (list), `state`.

---

## compute_resources.yml.j2 — Compute Resources

Defines hypervisor and cloud provider connections. The file is a Jinja2 template to allow domain-name interpolation for Azure and AWS region variables.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `vmware1_vcenter_username` | string | — | vCenter login username (references vault) | compute_resources role |
| `vmware1_vcenter_password` | string | — | vCenter login password (references vault) | compute_resources role |
| `vmware1_cluster1_name` | string | `"chassis3"` | VMware cluster name | compute_profiles |
| `vmware1_cluster1_path` | string | derived | VMware VM folder path | compute_profiles |
| `vmware1_cluster1_datastore` | string | `"NASAEX_VMS"` | VMware datastore name | compute_profiles |
| `vmware1_cluster1_network` | string | `"VM Network"` | VMware port group name | compute_profiles |
| `azure1_cloud` | string | `"azure"` | Azure cloud environment | compute_resources |
| `azure1_region` | string | `{{ rhis_azure_region }}` | Azure region | compute_resources, compute_profiles |
| `azure1_resourcegroup1` | string | derived from domain | Azure resource group name | compute_resources, compute_profiles |
| `azure1_rg1_vnet1` | string | derived | Azure virtual network name | compute_profiles |
| `azure1_rg1_vn1_subnet1` | string | derived | Azure subnet name | compute_profiles |
| `aws1_gov_cloud` | bool | `false` | Use AWS GovCloud endpoints | compute_resources |
| `aws1_region` | string | `{{ rhis_aws_region }}` | AWS region | compute_resources |
| `compute_resources` | list of dict | — | List of compute resource definitions | compute_resources role |

Each `compute_resources` entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | Compute resource name in Satellite |
| `provider` | string | `"vmware"`, `"libvirt"`, `"AzureRm"`, `"EC2"`, `"ovirt"`, `"GCE"`, `"Openstack"` |
| `description` | string | Description |
| `locations` | string | Satellite location |
| `organizations` | string | Satellite organization |
| `images` | list of dict | OS images available in this resource (optional); each: `name`, `architecture`, `operatingsystem`, `image_username`, `image_password`, `uuid` |
| `provider_params` | dict | Provider-specific connection parameters (url, user, password, datacenter, region, etc.) |

Compute resources defined: `VMware_Lab`, `KVM1_Lab`, `KVM2_Lab`, `Azure_Lab`, `AWS_Lab`.

---

## compute_profiles.yml — Compute Profiles

Defines reusable VM size templates that map to specific hypervisor configurations. Profiles are referenced by hostgroups.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `compute_profiles` | list of dict | — | List of compute profile definitions | compute_profiles role |

Each `compute_profiles` entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | Profile name (e.g., `SOE_Small`, `SOE_Medium`, `SOE_Large`) |
| `compute_attributes` | list of dict | Per-compute-resource VM attribute sets |

Each `compute_attributes` entry:

| Field | Type | Description |
|---|---|---|
| `compute_resource` | string | Compute resource name to apply these attributes to |
| `vm_attrs` | dict | Provider-specific VM attributes. VMware: `cpus`, `corespersocket`, `memory_mb`, `cluster`, `path`, `guest_id`, `firmware`, `boot_order`, `scsi_controllers`, `volumes_attributes`, `interfaces_attributes`. Azure: `resource_group`, `vm_size`, `platform`, `os_disk_size_gb`, `volumes_attributes`, `interfaces_attributes` |

Profiles defined: `SOE_Small` (1 CPU / 4 GiB), `SOE_Medium` (1 CPU / 8 GiB), `SOE_Large` (2 CPU / 16 GiB).

---

## operating_systems.yml — Operating System Definitions

Updates OS records created automatically when kickstart repositories are enabled. Associates provisioning templates, partition tables, and architectures.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `operating_systems` | list of dict | — | List of OS definition updates | operating_systems role |

Each `operating_systems` entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | OS family name (`"RedHat"`, `"CentOS"`, `"CentOS_Stream"`, `"OracleLinux"`) |
| `major` | int | Major version number |
| `minor` | int | Minor version number (blank for rolling releases) |
| `description` | string | Human-readable name shown in Satellite |
| `family` | string | OS family (`"Redhat"`, `"Debian"`, etc.) |
| `password_hash` | string | Password hashing algorithm (`"SHA256"`) |
| `organization` | string | Satellite organization |
| `location` | string | Satellite location |
| `state` | string | `"present"` or `"absent"` |
| `architectures` | list of string | Supported architectures (`"x86_64"`, `"aarch64"`) |
| `media` | list of string | Installation media names (optional; for non-Satellite content repos) |
| `provisioning_templates` | list of string | Templates associated with this OS |
| `ptables` | list of string | Partition tables associated with this OS |
| `default_templates` | list of dict | Default template per `template_kind` (`provision`, `finish`, `PXELinux`, `host_init_config`, etc.) |

OS records defined: RHEL 7.9, RHEL 8.10, RHEL 9.2 (aarch64), RHEL 9.6, RHEL 9.7, RHEL 10.0, RHEL 10.1, CentOS 7.9, CentOS Stream 9, OracleLinux 7.9.

---

## provisioning_templates.yml — Custom Provisioning Templates

Uploads custom SOE kickstart, PXE boot, iPXE, and snippet templates into Satellite from local Jinja2 template files.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `provisioning_templates` | list of dict | — | List of template definitions | provisioning_templates role |

Each `provisioning_templates` entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | Template name as it appears in Satellite |
| `type` | string | Template type: `"snippet"`, `"provision"`, `"finish"`, `"pxelinux"`, `"pxegrub"`, `"pxegrub2"`, `"ipxe"`, etc. |
| `locked` | bool | Whether to lock the template from editing via the UI |
| `description` | string | Template description |
| `audit_comment` | string | Audit log comment set when the template is created |
| `path` | string | Relative path to the template Jinja2 source file (resolved from the role `files/` directory) |
| `organizations` | list of string | Organizations to associate |
| `locations` | list of string | Locations to associate |

Templates defined include: SOE kickstart default (provision, finish, PXELinux), SOE global PXE defaults (iPXE, PXELinux, PXEGrub, PXEGrub2), local boot defaults, discovery snippets, and utility snippets (users, repos, python, cockpit, NBDE).

---

## partition_tables.yml — Partition Tables

Uploads custom partition table templates for compliance-oriented disk layouts.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `partition_tables` | list of dict | — | List of partition table definitions | partition_tables role |

Each `partition_tables` entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | Partition table name in Satellite |
| `os_family` | string | OS family this table applies to (`"Redhat"`) |
| `path` | string | Relative path to the template source file |
| `description` | string | Description |
| `audit_comment` | string | Audit log comment |
| `organizations` | list of string | Organizations to associate |
| `locations` | list of string | Locations to associate |

Tables defined: `RHEL_Server_CIS1` (CIS Server Level 1), `RHEL_Server_Compliance` (multi-profile compliance, min 100 GB), `RHEL_Server_Compliance_Encrypted` (LUKS2 + NBDE), `RHEL_Server_Compliance_with_data` (compliance + data partition).

---

## installation_media.yml — Installation Media

Defines network-based installation media locations for non-Satellite-managed OS installations (CentOS, OEL).

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `installation_media` | list of dict | — | List of installation media definitions | installation_media role |

Each entry schema: `name`, `os_family`, `path` (URL), `organization`, `location`.

---

## hostgroups.yml — Host Groups

Hostgroups are the primary mechanism for grouping hosts into provisioning configurations. Each hostgroup inherits from a parent (if set) and overrides specific attributes.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `satellite_hostgroups` | list of dict | — | List of hostgroup definitions | hostgroups role |

Each `satellite_hostgroups` entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | Hostgroup name (used as path component when `parent` is set) |
| `parent` | string | Parent hostgroup path (e.g., `"hg_x86_64_rhel9_vm"`) |
| `description` | string | Description |
| `organization` | string | Satellite organization |
| `locations` | string | Satellite location |
| `compute_resource` | string | Compute resource for VM provisioning (optional; omit for bare-metal) |
| `compute_profile` | string | Compute profile name (optional) |
| `content_source` | string | Capsule FQDN providing content (typically `groups['sat_primary'][0]`) |
| `lifecycle_environment` | string | Lifecycle environment name |
| `content_view` | string | Content view name |
| `activation_keys` | string | Activation key name |
| `openscap_capsule` | string | Capsule FQDN providing OpenSCAP scanning (optional) |
| `ansible_roles` | list of string | Ansible roles applied to hosts in this group |
| `domain` | string | DNS domain |
| `subnet` | string | Subnet name |
| `realm` | string | Kerberos realm name |
| `architecture` | string | CPU architecture (`"x86_64"`, `"aarch64"`) |
| `operatingsystem` | string | OS name and version as it appears in Satellite |
| `kickstart_repository` | string | Repository name providing the kickstart tree |
| `media` | string | Installation media name (for non-kickstart-repo installs) |
| `ptable` | string | Partition table name |
| `pxe_loader` | string | PXE loader type (`"Grub2 UEFI"`, `"PXELinux BIOS"`) |
| `root_pass` | string | Root password for provisioned hosts |
| `parameters` | list of dict | Hostgroup-level parameters (`name`, `hidden_value`, `parameter_type`, `value`). Common: `boot_disk`, `root_disk`, `kvm_host_enabled` |

Hostgroups are defined for RHEL 10 (x86_64 metal/VM + child groups), RHEL 9 (x86_64 metal/VM + child groups for AAP, capsule, JBoss, LAMP, WordPress, Edge Manager, CIS2), RHEL 8 (x86_64 metal/VM + child groups), CentOS 7.9, and OEL 7.9.

---

## global_parameters.yml.j2 — Global Host Parameters

Global parameters provide default values for all provisioning templates. They can be overridden at the hostgroup or host level.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `global_parameters` | list of dict | — | List of global parameter definitions | global_parameters role |

Each `global_parameters` entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | Parameter name |
| `value` | any | Parameter value |
| `parameter_type` | string | `"string"`, `"boolean"`, `"integer"`, `"array"`, `"json"` |
| `hidden_value` | bool | Hide value in the UI (optional) |
| `state` | string | `"present"` or `"absent"` |

Key global parameters defined:

| Parameter Name | Type | Description |
|---|---|---|
| `ansible_controller_api_url` | string | AAP controller API endpoint URL |
| `ansible_host_config_key` | string | AAP callback configuration key (references vault) |
| `ansible_job_template_id` | integer | AAP job template ID for post-provisioning configuration |
| `ansible_roles_check_mode` | boolean | Run Ansible roles in check mode |
| `ansible_tower_provisioning` | boolean | Enable AAP Tower provisioning callback |
| `binding_json` | json | Tang server binding configuration for NBDE |
| `binding_type` | string | NBDE binding type |
| `default_passphrase` | string | Temporary disk encryption passphrase |
| `enable_cloud_remediations` | boolean | Enable Red Hat cloud remediations |
| `enable-epel` | boolean | Enable EPEL during provisioning |
| `enable-remote-execution-pull` | boolean | Enable REX pull mode |
| `fips_enabled` | boolean | Enable FIPS mode |
| `encrypt-grub` | boolean | Enable GRUB password encryption |
| `enc_target_drives` | array | List of drives to encrypt |
| `grubmenu_pass` | string | GRUB menu password (hidden) |
| `host_packages` | string | Additional packages to install during provisioning |
| `host_registration_insights` | boolean | Register host with Red Hat Insights |
| `host_registration_lightspeed` | boolean | Enable Lightspeed integration during registration |
| `host_registration_insights_inventory` | boolean | Include host in Insights inventory |
| `host_registration_remote_execution` | boolean | Configure REX during registration |
| `install_environment_group` | string | Kickstart environment group to install |
| `install_reboot_kexec` | boolean | Use kexec for post-install reboot |
| `network_zone` | string | Firewalld zone for provisioned hosts |
| `package_upgrade` | boolean | Upgrade all packages during provisioning |
| `redhat_install_agent` | boolean | Install RHC agent |
| `redhat_install_host_tools` | boolean | Install Red Hat host tools |
| `redhat_install_host_tracer_tools` | boolean | Install Red Hat Tracer tools |
| `remote_execution_create_user` | boolean | Create REX user during provisioning |
| `remote_execution_effective_user_method` | string | Method for REX privilege escalation (`"sudo"`) |
| `remote_execution_ssh_keys` | string | Public SSH keys for REX user (references vault) |
| `remote_execution_ssh_user` | string | REX SSH username (references vault) |
| `remove_default_passphrase` | boolean | Remove the default disk passphrase after provisioning |
| `use_foreman_users` | boolean | Create Foreman-defined users on provisioned hosts |
| `use_graphical_installer` | boolean | Use graphical installation mode |
| `use_NBDE` | boolean | Enable Network Bound Disk Encryption |
| `use_ntp` | boolean | Configure NTP during provisioning |

---

## discovery_config.yml — Satellite Discovery Configuration

Variables controlling PXE-based bare-metal discovery with custom fact injection.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `rhis_discovery_custom_facts_enable` | bool | `true` | Enable custom fact injection into the discovery image | discovery_config role |
| `rhis_discovery_custom_facts_file` | string | `"boot/discovery_facts.zip"` | Path to the custom facts zip file (relative to role `files/`) | discovery_config role |
| `rhis_discovery_pxelinux_template` | string | — | Path to the custom PXELinux discovery snippet template | discovery_config role |
| `rhis_discovery_pxegrub_template` | string | — | Path to the custom PXEGrub discovery snippet template | discovery_config role |
| `rhis_discovery_pxegrub2_template` | string | — | Path to the custom PXEGrub2 discovery snippet template | discovery_config role |
| `rhis_discovery_ipxe_global_default_template` | string | — | Path to the iPXE global default template | discovery_config role |
| `rhis_discovery_pxegrub_global_default_template` | string | — | Path to the PXEGrub global default template | discovery_config role |
| `rhis_discovery_pxegrub2_global_default_template` | string | — | Path to the PXEGrub2 global default template | discovery_config role |
| `rhis_discovery_pxegrub2_default_local_boot_template` | string | — | Path to the PXEGrub2 local boot template | discovery_config role |
| `rhis_discovery_pxelinux_global_default_template` | string | — | Path to the PXELinux global default template | discovery_config role |

---

## discovery_rules.yml — Discovery Auto-Provisioning Rules

Defines rules that match discovered hosts to hostgroups for automatic provisioning.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `discovery_rules` | list of dict | — | List of discovery rule definitions | discovery_rules role |

Each `discovery_rules` entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | Rule name |
| `enabled` | bool | Whether the rule is active |
| `state` | string | `"present"` or `"absent"` |
| `organizations` | string | Satellite organization |
| `locations` | string | Satellite location |
| `search` | string | Foreman search expression to match discovered hosts |
| `priority` | int | Rule priority (lower number = higher priority) |
| `hostgroup` | string | Target hostgroup name for auto-provisioning |

---

## scap_content.yml — SCAP Content and Tailoring Files

Registers OpenSCAP data stream files and tailoring files for compliance scanning.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `scap_contents` | list of dict | — | List of SCAP content file definitions | scap_content role |
| `scap_tailoring_files` | list of dict | — | List of SCAP tailoring file definitions | scap_content role |

Each `scap_contents` entry schema: `title`, `scap_file` (filename relative to role `files/`), `locations`, `organizations`.

Each `scap_tailoring_files` entry schema: `name`, `scap_file`, `locations`, `organizations`.

Content defined: RHEL 7, 8, 9 data streams. Tailoring files: RHEL 7, 8, 9 DS 2022 Tailoring v3.0.

---

## scap_policies.yml — SCAP Compliance Policies

Defines scheduled compliance scan policies.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `scap_policies` | list of dict | — | List of compliance policy definitions | scap_policies role |

Each `scap_policies` entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | Policy name |
| `description` | string | Policy description |
| `deploy_by` | string | Deployment method (`"ansible"`, `"puppet"`, `"manual"`) |
| `scap_content` | string | SCAP content title |
| `scap_profile` | string | Profile name within the SCAP content |
| `period` | string | Scan period (`"weekly"`, `"monthly"`, `"custom"`) |
| `weekday` | string | Day of week for weekly scans |
| `day_of_month` | int | Day of month for monthly scans (optional) |
| `cron_line` | string | Cron expression for custom schedules (optional) |
| `hostgroups` | list of string | Hostgroups to apply this policy to |
| `tailoring_file` | string | Tailoring file name (optional) |
| `tailoring_file_profile` | string | Profile within the tailoring file (optional) |
| `organizations` | list of string | Organizations |
| `locations` | list of string | Locations |

---

## virtwho_configs.yml — virt-who Configurations

Defines virt-who configurations for hypervisor subscription reporting.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `vcenter_virtwho_username` | string | — | vCenter account for virt-who (references vault) | virtwho_configs role |
| `vcenter_virtwho_password` | string | — | vCenter password for virt-who (references vault) | virtwho_configs role |
| `virtwho_configs` | list of dict | — | List of virt-who configuration definitions | virtwho_configs role |

Each `virtwho_configs` entry schema (nested under `foreman_virt_who_configure_config`):

| Field | Type | Description |
|---|---|---|
| `name` | string | Configuration name |
| `hypervisor_type` | string | Hypervisor type (`"esx"`, `"hyperv"`, `"libvirt"`, `"kubevirt"`, etc.) |
| `hypervisor_server` | string | Hypervisor host address |
| `hypervisor_username` | string | Hypervisor login username |
| `hypervisor_password` | string | Hypervisor login password |
| `hypervisor_id` | string | Host identifier method (`"hostname"`, `"uuid"`, `"hwuuid"`) |
| `interval` | string | Reporting interval in minutes |
| `filtering_mode` | int | `0` = no filtering, `1` = whitelist, `2` = blacklist |
| `satellite_url` | string | Satellite server FQDN |
| `organization_name` | string | Satellite organization |
| `organization_id` | int | Organization ID (looked up at runtime if `0`) |

---

## capsules.yml — Satellite Capsule Definitions

Defines Smart Proxy/Capsule servers to register and configure.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `capsule_ssl_rsa_key_pass` | string | — | Passphrase for capsule SSL keys (references vault) | capsules role |
| `capsules_use_idm` | bool | `true` | Use IdM for capsule SSL certificate generation | capsules role |
| `satellite_capsules` | list of dict | — | List of capsule definitions | capsules role |

Each `satellite_capsules` entry schema:

| Field | Type | Description |
|---|---|---|
| `fqdn` | string | Capsule FQDN |
| `crt_force_regen` | bool | Force SSL certificate regeneration |
| `download_policy` | string | Capsule sync download policy (`"inherit"`, `"immediate"`, `"on_demand"`) |
| `lifecycle_environments` | list of string | Environments synced by this capsule |
| `organizations` | list of string | Organizations assigned to this capsule |
| `locations` | list of string | Locations assigned to this capsule |

---

## rex_kerberos.yml — Remote Execution Kerberos Integration

Configures Kerberos-based SSH authentication for Remote Execution.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `rex_kerberos_enabled` | bool | `true` | Enable Kerberos authentication for REX SSH | satellite_installer, rex |
| `rex_realm_principal` | string | `"realm-capsule"` | Kerberos principal name for REX operations | satellite_installer |
| `rex_executor` | string | `"foreman-proxy"` | Process running as the REX executor | rex role |

---

## satellite_template_sync.yml — Template Repository Synchronization

Configures Git repositories from which Satellite will import provisioning templates.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `satellite_template_repos` | list of dict | — | List of Git template repository definitions | template_sync role |

Each `satellite_template_repos` entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | Display name for the template repository |
| `repo_url` | string | Git repository URL |
| `dirname` | string | Subdirectory within the repository containing templates |
| `branch` | string | Git branch to sync from |
| `associate` | string | When to associate templates to OS/org/location: `"always"`, `"new"`, `"never"` |
| `force` | string | `"true"` to overwrite locked templates |
| `locations` | string | Satellite location filter |
| `organizations` | string | Satellite organization filter |

---

## imported_git_repos.yml — Git Repository Imports to the Satellite Host OS

Clones Git repositories directly onto the Satellite host (into `/etc/ansible/roles/`) to make Ansible roles available for import into Satellite. Used to sync compliance-as-code roles from `RedHatOfficial`.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `git_repos` | list of dict | — | List of Git repository clone definitions | imported_git_repos role |

Each `git_repos` entry schema: `repository` (URL), `dest` (local path), `clone` (bool), `force` (bool).

Roles cloned cover RHEL 9, 8, and 7 compliance profiles: CIS, STIG, PCI-DSS, OSPP, HIPAA, CJIS, CUI, ISM, ANSSI BP28 (minimal/intermediary/high/enhanced).

---

## imported_ansible_roles.yml — Ansible Role Import into Satellite

Imports Ansible roles from the Satellite host filesystem into the Satellite application for use in hostgroup automation.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `satellite_api_proxy_id_string` | string | `"1-{{ satellite_fqdn }}"` | Smart proxy identifier string used in API calls | imported_ansible_roles role |
| `ansible_roles_import_list` | list of string | — | List of Ansible role names to import from the Satellite host | imported_ansible_roles role |

Roles imported include all compliance roles cloned via `imported_git_repos.yml` plus `theforeman.foreman_scap_client` and `RedHatInsights.insights-client`.

---

## job_templates.yml — Job Templates

Uploads custom Remote Execution job templates.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `job_templates` | list of dict | — | List of job template definitions | job_templates role |

Each `job_templates` entry schema:

| Field | Type | Description |
|---|---|---|
| `name` | string | Job template name |
| `audit_comment` | string | Audit log comment |
| `path` | string | Relative path to the template source file |
| `job_category` | string | Category shown in the REX UI |
| `locations` | string | Satellite location |
| `organizations` | string | Satellite organization |
| `locked` | bool | Whether the template is locked from UI editing |
| `provider_type` | string | Execution provider (`"script"`) |
| `snippet` | bool | Whether this is a snippet |
| `state` | string | `"present"` or `"absent"` |
| `template_inputs` | list of dict | User inputs for the template; each: `name`, `advanced`, `default`, `description`, `input_type`, `options`, `required`, `value_type` |

---

## role_filters_all.yml — Role Permission Filters

Defines the full set of Satellite permissions organized by resource type, used as a reference when building custom roles.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `role_filters_all` | list of dict | — | Reference list of all permission filters organized by Satellite resource type | user_group_role role |

Each entry: `resource_type` (string), `permissions` (list of string).

---

## user_group_role.yml.j2 — Users, Groups, and Roles

Defines Satellite users, local user groups, external IdM group mappings, and custom RBAC roles. This is a Jinja2 template to allow locale and timezone interpolation.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `satellite_users` | list of dict | — | Satellite local user definitions | user_group_role role |
| `satellite_user_groups` | list of dict | — | Satellite local user group definitions | user_group_role role |
| `satellite_user_groups_external` | list of dict | — | External (IdM/AD) group-to-Satellite-group mappings | user_group_role role |
| `satellite_roles` | list of dict | — | Custom RBAC role definitions | user_group_role role |

`satellite_users` entry schema: `name`, `firstname`, `lastname`, `email`, `description`, `admin`, `user_password`, `default_location`, `default_organization`, `auth_source`, `timezone`, `locale`, `locations`, `organizations`, `state`.

`satellite_user_groups` entry schema: `name`, `admin`, `roles` (list), `users` (list), `state`.

`satellite_user_groups_external` entry schema: `auth_source_group_name`, `auth_source`, `sat_usergroup`, `state`.

`satellite_roles` entry schema: `name`, `state`, `description`, `locations`, `organizations`, `filters` (list of `resource_type` + `permissions`).

---

## settings_general.yml — General Settings

Satellite-wide general configuration. Applies to Satellite 6.17+. Most settings are commented out (leaving Satellite defaults). Only actively-set values are noted below.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `settings_general` | list of dict | — | List of general setting definitions | settings role |

Key settings actively configured (others commented out):

| Setting `id` | Type | Value | Description |
|---|---|---|---|
| `administrator` | string | `root@{{ _runtime_global_domain_name }}` | Default administrator email address |
| `login_text` | string | Custom string with version | Login page footer text |

Each setting entry schema: `id`/`name`, `full_name`, `description`, `settings_type`, `value`, `category`, `category_name`, `readonly`, `encrypted`, `updated_at`, `config_file`, `select_values`.

---

## settings_content.yml — Content Settings

Katello content management settings controlling download policies, export paths, template defaults, and host lifecycle behaviour.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `settings_content` | list of dict | — | List of content setting definitions | settings role |

Key settings actively configured:

| Setting `name` | Type | Value | Description |
|---|---|---|---|
| `katello_default_provision` | string | `"SOE Kickstart default"` | Default provision template for synced OS |
| `katello_default_finish` | string | `"SOE Kickstart default finish"` | Default finish template for synced OS |
| `katello_default_PXELinux` | string | `"SOE Kickstart default PXELinux"` | Default PXELinux template for synced OS |
| `katello_default_ptable` | string | `"RHEL_Server_Compliance"` | Default partition table for synced OS |
| `default_download_policy` | string | `"immediate"` | Download policy for custom repositories |
| `default_redhat_download_policy` | string | `"on_demand"` | Download policy for Red Hat repositories |
| `default_proxy_download_policy` | string | `"on_demand"` | Download policy for capsule syncs |
| `pulpcore_export_destination` | string | `"/var/lib/pulp/exports"` | Filesystem path for Pulp 3 exports |
| `default_export_format` | string | `"importable"` | Default content export format |
| `unregister_delete_host` | bool | `true` | Delete host record when unregistering via subscription-manager |

---

## settings_provisioning.yml — Provisioning Settings

Controls provisioning behaviour including PXE defaults, template rendering, hostname generation, and VM lifecycle management.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `settings_provisioning` | list of dict | — | List of provisioning setting definitions | settings role |

Key settings actively configured:

| Setting `name` | Type | Value | Description |
|---|---|---|---|
| `root_pass` | string | (vault) | Default root password (encrypted) |
| `unattended_url` | string | `http://satellite.{{ _runtime_global_domain_name }}` | URL hosts contact for templates during build |
| `safemode_render` | bool | `false` | Disable safe-mode template rendering (allows full Ruby) |
| `update_ip_from_built_request` | bool | `false` | Do not update host IP from the build request source |
| `name_generator_type` | string | `"MAC-based"` | Hostname generation strategy |
| `default_pxe_item_global` | string | `"discovery"` | Default global PXE menu entry |
| `default_pxe_item_local` | string | `"force_local_chain_hd0"` | Default local PXE menu entry |
| `destroy_vm_on_host_delete` | bool | `true` | Destroy the VM on the compute resource when a host is deleted |
| `maximum_structured_facts` | int | `120` | Maximum structured fact keys per host |
| `default_global_registration_item` | string | `"Global Registration"` | Default global registration template |
| `global_PXEGrub2` | string | `"PXEGrub2 global default"` | Global PXEGrub2 template |
| `global_PXELinux` | string | `"PXELinux global default"` | Global PXELinux template |
| `global_PXEGrub` | string | `"PXEGrub global default"` | Global PXEGrub template |
| `global_iPXE` | string | `"iPXE global default"` | Global iPXE template |
| `local_boot_PXEGrub2` | string | `"PXEGrub2 default local boot"` | PXEGrub2 local boot template |
| `local_boot_PXELinux` | string | `"PXELinux default local boot"` | PXELinux local boot template |
| `local_boot_PXEGrub` | string | `"PXEGrub default local boot"` | PXEGrub local boot template |
| `local_boot_iPXE` | string | `"iPXE default local boot"` | iPXE local boot template |

---

## settings_email.yml — Email Settings

SMTP delivery configuration for Satellite notification emails.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `settings_email` | list of dict | — | List of email setting definitions | settings role |

Key settings actively configured:

| Setting `name` | Type | Value | Description |
|---|---|---|---|
| `email_reply_address` | string | `satellite-noreply@{{ _runtime_global_domain_name }}` | Reply-to address for outgoing email |
| `email_subject_prefix` | string | `[satellite.{{ _runtime_global_domain_name }}]` | Subject line prefix |
| `delivery_method` | string | `"SMTP"` | Email delivery backend |
| `smtp_address` | string | `"smtp.gmail.com"` | SMTP server address |
| `smtp_port` | int | `587` | SMTP port |
| `smtp_user_name` | string | (vault) | SMTP authentication username |
| `smtp_password` | string | (vault) | SMTP authentication password (encrypted) |
| `smtp_authentication` | string | `{{ satellite_smtp_authentication }}` | SMTP authentication type |

---

## settings_discovery.yml — Discovery Settings

Controls bare-metal host discovery behaviour.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `settings_discovery` | list of dict | — | List of discovery setting definitions | settings role |

Key settings actively configured:

| Setting `name` | Type | Value | Description |
|---|---|---|---|
| `discovery_hostname` | array | `["chassis_position", "discovery_bootif"]` | Ordered list of facts used to build the discovery hostname |
| `discovery_prefix` | string | `"lab-"` | Prefix prepended to discovered hostnames |

---

## settings_remote_execution.yml — Remote Execution Settings

Configures default SSH user and Cockpit web console integration.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `settings_remote_execution` | list of dict | — | List of REX setting definitions | settings role |

Key settings actively configured:

| Setting `name` | Type | Value | Description |
|---|---|---|---|
| `remote_execution_ssh_user` | string | `"realm-capsule"` | Default SSH user for remote execution |
| `remote_execution_cockpit_url` | string | `"https://%{host}:9090"` | Cockpit web console URL pattern |

---

## settings_ansible.yml — Ansible Integration Settings

Configures Ansible connection behaviour.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `settings_ansible` | list of dict | — | List of Ansible setting definitions | settings role |

Key settings actively configured:

| Setting `name` | Type | Value | Description |
|---|---|---|---|
| `ansible_connection` | string | `"ssh"` | Default Ansible connection type |

---

## settings_authentication.yml — Authentication Settings

Controls session and login security settings.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `settings_authentication` | list of dict | — | List of authentication setting definitions | settings role |

Key settings actively configured:

| Setting `name` | Type | Value | Description |
|---|---|---|---|
| `idle_timeout` | int | `60` | Minutes before idle users are logged out |

---

## settings_rhcloud.yml — Red Hat Cloud Settings

Controls integration with `console.redhat.com` for Insights recommendations and inventory.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `settings_rhcloud` | list of dict | — | List of Red Hat cloud setting definitions | settings role |

Key settings actively configured:

| Setting `name` | Type | Value | Description |
|---|---|---|---|
| `allow_auto_insights_sync` | bool | `true` | Automatically sync Insights recommendations |
| `allow_auto_insights_mismatch_delete` | bool | `true` | Automatically delete mismatched Insights host records |

---

## settings_content.yml, settings_template_sync.yml, settings_boot_disk.yml, settings_config_management.yml, settings_facts.yml, settings_notifications.yml, settings_tasks.yml — Additional Settings Categories

These files follow the same pattern: each defines a list variable (`settings_template_sync`, `settings_boot_disk`, etc.) of setting dicts with the schema `name`, `full_name`, `description`, `settings_type`, `value`.

Key actively-configured values:

| File | Setting `name` | Value | Description |
|---|---|---|---|
| `settings_template_sync.yml` | `template_sync_associate` | `"New"` | Associate imported templates only to new OS/org/location |
| `settings_template_sync.yml` | `template_sync_dirname` | `"/"` | Template sync root directory |
| `settings_template_sync.yml` | `template_sync_repo` | theforeman community-templates URL | Default template sync repository |
| `settings_template_sync.yml` | `template_sync_commit_msg` | Custom string | Commit message for template exports |
| `settings_boot_disk.yml` | (all commented out) | — | Boot disk settings left at Satellite defaults |
| `settings_config_management.yml` | (all commented out) | — | Config management settings left at Satellite defaults |
| `settings_facts.yml` | (all commented out) | — | Fact settings left at Satellite defaults |
| `settings_notifications.yml` | (all commented out) | — | Notification settings left at Satellite defaults |
| `settings_tasks.yml` | (all commented out) | — | Task settings left at Satellite defaults |
