# Host: discosatellite — Disconnected Satellite Variables

Schema Version: 1.0.0

These variables configure the disconnected (air-gapped) Satellite server used in secure enclave environments. Content is exported from the primary Satellite and imported here. The variable structure mirrors the primary Satellite but includes content import/export configuration.

Upstream collection: `redhat.satellite` — refer to the [collection documentation](https://console.redhat.com/ansible/automation-hub/repo/published/redhat/satellite/) for authoritative variable references.

---

## main.yml — Core Satellite Identity and Connection

Top-level connection and identity variables. All disconnected-mode variables are **uncommented and active** here, unlike the primary Satellite where they are commented out.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `use_completion_logic` | bool | `true` | Enable task completion tracking logic | rhis-builder-satellite |
| `satellite_fqdn` | string | `{{ ansible_fqdn }}` | Fully-qualified domain name of the disconnected Satellite server | all roles |
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
| `satellite_disconnected` | bool | `true` | **Always `true` for discosatellite.** Enables ISO-based installation and export/import content flow | satellite_pre, satellite_installer |
| `satellite_disconnected_root` | string | `"/var/media"` | Root mount path for offline media | satellite_pre |
| `satellite_os_iso_source` | string | `"rhel9_dvd.iso"` | Filename of the RHEL OS DVD ISO for disconnected install | satellite_pre |
| `satellite_install_iso_source` | string | `"sat617_dvd.iso"` | Filename of the Satellite installer DVD ISO for disconnected install | satellite_pre |
| `satellite_os_repo_mount` | string | `{{ satellite_disconnected_root }}/rhel` | Mount point for the RHEL OS ISO | satellite_pre |
| `satellite_install_repo_mount` | string | `{{ satellite_disconnected_root }}/satellite` | Mount point for the Satellite installer ISO | satellite_pre |
| `satellite_os_repo_template_name` | string | `"rhel_os_repo_file.j2"` | Jinja2 template name for generating the OS repo file | satellite_pre |
| `satellite_os_repo_template_dest` | string | `"/etc/yum.repos.d/rhis_os_base.repo"` | Destination path on the Satellite host for the generated repo file | satellite_pre |
| `satellite_cdn_configuration_type` | string | `"export_sync"` | CDN configuration type; always `"export_sync"` for disconnected installs | satellite_pre |

**Difference from primary satellite:** `satellite_disconnected` is `true` and all disconnected variables (`satellite_disconnected_root`, `satellite_os_iso_source`, `satellite_install_iso_source`, `satellite_os_repo_mount`, `satellite_install_repo_mount`, `satellite_os_repo_template_name`, `satellite_os_repo_template_dest`, `satellite_cdn_configuration_type`) are active. On the primary satellite these are commented out.

---

## satellite_pre.yml — Pre-Installation and IdM Integration

Variables controlling OS prerequisites, firewall, IdM client enrollment, SSL certificate generation, and libvirt TLS setup.

**Key difference from primary satellite:** `satellite_pre_use_idm: false` — the disconnected Satellite does not enroll into IdM. The IdM-related variables remain present for reference but the integration is disabled. Additionally, `ipa_server_fqdn` uses `{{ groups['idm_primary'][0] }}` (group-based lookup) rather than a hardcoded hostname, and `keytab_retrieval_dn` references the non-vault variable `{{ ipa_keytab_dn }}` rather than a vault variable.

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
| `satellite_pre_use_idm` | bool | `false` | **Disabled for discosatellite.** Skip all IdM client enrollment and Kerberos integration | satellite_pre, satellite_installer |
| `use_non_idm_certs` | bool | `false` | Must be `true` only when `satellite_pre_use_idm` is `false` and you want self-signed certs | satellite_pre |
| `skip_prepare_realm` | bool | `false` | Skip keytab generation for the realm user | satellite_pre |
| `ipa_generate_certs` | bool | `true` | Generate IPA-signed SSL certificates for Satellite | satellite_pre |
| `ipa_admin_password` | string | — | IdM admin password (references vault) | satellite_pre |
| `ipa_admin_principal` | string | — | IdM admin principal (references vault) | satellite_pre |
| `ipa_server_fqdn` | string | `{{ groups['idm_primary'][0] }}` | FQDN of the primary IdM server (group-based lookup, not hardcoded) | satellite_pre |
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
| `ipaclient_configure_dns_resolver` | bool | `{{ ipa_client_configure_dns_resolver }}` | DNS resolver setting for the `ipaclient` role | ipaclient role |
| `ipaclient_dns_servers` | string | `{{ ipa_client_dns_servers }}` | DNS server for the `ipaclient` role | ipaclient role |
| `ipaclient_mkhomedir` | bool | `{{ ipa_client_mkhomedir }}` | Home directory setting for the `ipaclient` role | ipaclient role |
| `ipaclient_force_join` | bool | `true` | Force realm rejoin; useful when rebuilding Satellite without rebuilding IdM | ipaclient role |
| `foreman_proxy_realm_role_name` | string | `"Smart Proxy Host Manager"` | IdM role name for the Smart Proxy realm user | satellite_pre |
| `foreman_proxy_realm_principal` | string | `"realm-capsule"` | Kerberos principal for the Smart Proxy realm integration | satellite_pre, satellite_installer |
| `foreman_proxy_dns_update_policy` | string | derived | BIND update policy grant for the realm-capsule principal | satellite_pre |
| `foreman_proxy_bind_update_policy` | string | derived | Combined BIND update policy for forward DNS. The policy is intentionally broad to grant the foreman-proxy user the permissions required to create and update DNS entries. In the RHIS default configuration with IdM, the foreman-proxy user is a realm user with a specific RBAC role configured in IdM (`foreman_proxy_realm_role_name`). The user authenticates via a keytab used for both IdM management and Ansible remote execution. The keytab is properly protected and access is restricted to the foreman-proxy process. If desired, a stricter update policy may be substituted; however, thorough testing is strongly recommended as the default policy is tested and documented. | satellite_pre |
| `foreman_proxy_dns_update_policy_reverse` | string | derived | BIND update policy grant for reverse DNS | satellite_pre |
| `foreman_proxy_bind_update_policy_reverse` | string | derived | Combined BIND update policy for reverse DNS. See `foreman_proxy_bind_update_policy` note above. | satellite_pre |
| `keytab_retrieval_password` | string | — | Password used to retrieve keytab from IdM (references vault) | satellite_pre |
| `keytab_retrieval_dn` | string | `{{ ipa_keytab_dn }}` | DN used to retrieve keytab from IdM (non-vault reference, unlike primary satellite) | satellite_pre |
| `crt_service_type` | string | `"HTTP"` | Service type for IPA certificate generation | satellite_pre |
| `crt_force_regen` | bool | `true` | Force regeneration of SSL certificates | satellite_pre |
| `sat_ssl_certs_dir` | string | `/etc/ipa/private/{{ ansible_fqdn }}/` | Directory for SSL certificate storage | satellite_pre |
| `sat_ssl_crt_path` | string | `{{ sat_ssl_certs_dir }}{{ ansible_fqdn }}.crt` | Path to the Satellite SSL certificate | satellite_installer |
| `sat_ssl_key_path` | string | `{{ sat_ssl_certs_dir }}{{ ansible_fqdn }}.key` | Path to the Satellite SSL private key | satellite_installer |
| `sat_ssl_csr_path` | string | `{{ sat_ssl_certs_dir }}{{ ansible_fqdn }}.csr` | Path to the Satellite SSL CSR | satellite_pre |
| `sat_ssl_ca_crt_path` | string | `{{ ipa_server_ca_crt_path }}` | Path to the CA certificate | satellite_installer |
| `ipa_server_ca_crt_path` | string | `"/etc/ipa/ca.crt"` | Path to the IPA server CA certificate | satellite_pre |
| `passfile` | string | `{{ sat_ssl_certs_dir }}passfile` | Path to the SSL key passphrase file | satellite_pre |
| `ssl_private_key_cipher` | string | `"aes256"` | Cipher for the SSL private key | satellite_pre |
| `ssl_private_key_size` | int | `4096` | RSA key size in bits | satellite_pre |
| `ssl_private_key_pem_path` | string | derived | Path to the SSL private key PEM file | satellite_pre |
| `ssl_public_key_path` | string | derived | Path to the SSL public key | satellite_pre |
| `ssl_public_key_format` | string | `"PEM"` | Format for the SSL public key | satellite_pre |
| `csr_digest` | string | `"aes256"` | Digest algorithm for CSR generation | satellite_pre |
| `csr_organization_name` | string | `{{ ansible_domain \| upper }}` | Organization name for the SSL CSR | satellite_pre |
| `csr_organization_unit_name` | string | `"Demo Lab"` | Organizational unit for the SSL CSR | satellite_pre |
| `csr_locality_name` | string | `"Hespeler"` | Locality for the SSL CSR | satellite_pre |
| `csr_state_or_province_name` | string | `"ON"` | Province for the SSL CSR | satellite_pre |
| `csr_country_name` | string | `"CA"` | Country code for the SSL CSR | satellite_pre |
| `csr_email_address` | string | `admin@{{ ansible_domain }}` | Email for the SSL CSR | satellite_pre |
| `host_ssl_certs_dir` | string | `{{ sat_ssl_certs_dir }}` | Host SSL certificate directory (libvirt TLS) | satellite_pre |
| `host_ssl_rsa_key_pass` | string | — | RSA key passphrase for libvirt TLS certificates (references vault via `sat_ssl_rsa_key_pass`) | satellite_pre |
| `libvirt_non_idm_ca_crt_path` | string | derived | CA certificate path for non-IdM libvirt TLS | satellite_pre |
| `libvirt_client_private_key_pem_path` | string | derived | Libvirt client private key PEM path | satellite_pre |
| `libvirt_client_key_path` | string | derived | Libvirt client key path | satellite_pre |
| `libvirt_client_csr_path` | string | derived | Libvirt client CSR path | satellite_pre |
| `libvirt_client_crt_path` | string | derived | Libvirt client certificate path | satellite_pre |
| `libvirt_client_crt_service_type` | string | `"libvirtclient"` | IPA service type for the libvirt client certificate | satellite_pre |
| `libvirt_server_private_key_pem_path` | string | derived | Libvirt server private key PEM path | satellite_pre |
| `libvirt_server_key_path` | string | derived | Libvirt server key path | satellite_pre |
| `libvirt_server_csr_path` | string | derived | Libvirt server CSR path | satellite_pre |
| `libvirt_server_crt_path` | string | derived | Libvirt server certificate path | satellite_pre |
| `libvirt_server_crt_service_type` | string | `"libvirt"` | IPA service type for the libvirt server certificate | satellite_pre |

---

## satellite_installer.yml — Satellite Installer Options

Variables driving the `satellite-installer` command line. The disconnected Satellite installer omits IdM authentication, DNS TSIG, realm integration, and has DHCP commented out. Discovery images are disabled.

**Key differences from primary satellite:**
- `--foreman-ipa-authentication false` (vs `true`)
- DNS (`--foreman-proxy-dns false`) and all DNS TSIG options are disabled
- Realm options (`--foreman-proxy-realm`) are commented out
- DHCP options are commented out (intended for environments using external DHCP)
- `--foreman-proxy-plugin-discovery-install-images false` (vs `true`)
- No `--foreman-http-keytab` option
- No `--certs-server-*` options active (commented out)

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `foreman_proxy_realm_principal` | string | `{{ foreman_proxy_realm_principal }}` | Kerberos principal for Smart Proxy realm (self-referential placeholder) | satellite_installer |
| `dhcp_interface` | string | derived from facts | First ethernet interface; used in commented-out DHCP options | satellite_installer |
| `satellite_tuning_size` | string | `"default"` | Satellite tuning profile. Options: `default` (≤5000 hosts, 20 GiB, 4 cores), `medium` (≤10000 hosts, 32 GiB, 8 cores), `large` (≤20000 hosts, 64 GiB, 16 cores), `extra-large` (≤60000 hosts, 128 GiB, 32 cores), `extra-extra-large` (60000+ hosts, 256+ GiB, 64+ cores) | satellite_installer |
| `sat_installer_verbose` | bool | `true` | Run satellite-installer with verbose output | satellite_installer |
| `sat_installer_options` | list of string | — | Complete list of `satellite-installer` flags. See file for full set; key active options described below | satellite_installer |

**Active `sat_installer_options` flags:**

| Flag | Value | Description |
|---|---|---|
| `--skip-checks-i-know-better` | — | Bypass installer pre-flight checks |
| `--foreman-foreman-service-puma-threads-min` | `16` | Minimum Puma threads |
| `--foreman-foreman-service-puma-threads-max` | `16` | Maximum Puma threads |
| `--foreman-foreman-service-puma-workers` | `16` | Number of Puma worker processes |
| `--foreman-dynflow-worker-instances` | `3` | Dynflow worker count (optimized for initial sync) |
| `--foreman-initial-organization` | `{{ satellite_initial_organization }}` | Bootstrap organization name |
| `--foreman-initial-location` | `{{ satellite_initial_location }}` | Bootstrap location name |
| `--foreman-initial-admin-username` | `{{ satellite_username }}` | Initial admin username |
| `--foreman-initial-admin-password` | `{{ satellite_password }}` | Initial admin password |
| `--foreman-initial-admin-email` | `{{ satellite_admin_email }}` | Initial admin email |
| `--tuning` | `{{ satellite_tuning_size }}` | Apply the selected tuning profile |
| `--enable-foreman-compute-ec2` | — | Enable AWS EC2 compute resource plugin |
| `--enable-foreman-compute-libvirt` | — | Enable KVM/libvirt compute resource plugin |
| `--enable-foreman-compute-vmware` | — | Enable VMware vSphere compute resource plugin |
| `--foreman-ipa-authentication` | `false` | **Disabled** — no IdM authentication integration |
| `--foreman-proxy-dns` | `false` | **Disabled** — no DNS integration |
| `--foreman-proxy-dns-managed` | `false` | DNS not managed by Satellite |
| `--foreman-proxy-http` | `true` | Enable HTTP Smart Proxy |
| `--foreman-proxy-registration` | `true` | Enable registration Smart Proxy |
| `--foreman-proxy-templates` | `true` | Enable template Smart Proxy |
| `--foreman-proxy-tftp` | `true` | Enable TFTP Smart Proxy for PXE boot |
| `--foreman-proxy-plugin-discovery-install-images` | `false` | **Disabled** — do not install discovery images |
| `--foreman-proxy-content-enable-ansible` | `true` | Enable Ansible content proxy |
| `--foreman-proxy-content-enable-deb` | `true` | Enable Debian content proxy |
| `--foreman-proxy-content-enable-docker` | `true` | Enable container content proxy |
| `--foreman-proxy-content-enable-file` | `true` | Enable file content proxy |
| `--foreman-proxy-content-enable-yum` | `true` | Enable YUM/RPM content proxy |

---

## satellite_post.yml — Post-Installation PostgreSQL Tuning

PostgreSQL tuning applied after satellite-installer completes.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `satellite_post` | dict | — | Container for all PostgreSQL tuning parameters | satellite_post role |

**`satellite_post` dict schema:**

| Key | Type | Value | Description |
|---|---|---|---|
| `postgres_max_connections` | int | `1000` | Maximum number of PostgreSQL client connections |
| `postgres_shared_buffers` | string | `"16GB"` | PostgreSQL shared memory buffer size |
| `postgres_work_mem` | string | `"8MB"` | Per-operation work memory for sorting/hashing |
| `postgres_avcl` | int | `2000` | autovacuum cost limit |

---

## manifests.yml.j2 — Subscription Manifest (Jinja2)

**Key difference from primary satellite:** `generate: false` — the manifest is not generated from the CDN. A pre-existing manifest ZIP file must be placed in the inventory files directory and uploaded. No CDN account credentials are needed.

The file is Jinja2 (`.j2`) and uses `{% raw %}`/`{% endraw %}` blocks to protect Ansible variable syntax from the outer Jinja2 render.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `redhat_manifests` | list of dict | — | List of manifest definitions. Typically one entry per Satellite | satellite_manifests role |

**`redhat_manifests` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Manifest name (typically the Satellite FQDN) |
| `source` | string | yes | Filename of the manifest ZIP in the inventory files directory |
| `path` | string | yes | Destination path on the Satellite host (e.g. `"/root/bootstrap_manifest.zip"`) |
| `generate` | bool | yes | `false` — upload a pre-existing file; `true` — generate from CDN (uses vault vars for CDN account) |
| `organization` | string | yes | Satellite organization to upload the manifest into |
| `state` | string | yes | `present`, `absent`, or `refreshed` |

**Note:** When `generate: false` (disconnected mode), `account`, `cdn_username`, `cdn_password`, `subs`, and `portal_url` are not required. When `state: refreshed` with `generate: false`, Satellite refreshes the existing manifest from the CDN — this requires CDN connectivity even in disconnected mode.

---

## content_credentials.yml — GPG Keys and SSL Certificates

Content credentials (GPG keys and SSL certificates) for verifying repository content.

**Key difference from primary satellite:** For Red Hat content (`RedHatGPG`, `RedHatSSL`), `content_source` must be `"file"` — the disconnected Satellite cannot reach CDN or external URLs. Only third-party credentials using publicly accessible URLs may use `"url"`. If any URL-sourced credential fails on your disconnected network, change `content_source` to `"file"` and place the key in the files directory.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `content_credentials` | list of dict | — | List of GPG keys and SSL certificates to register in Satellite | satellite_content_credentials role |

**`content_credentials` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Display name of the credential in Satellite |
| `content_type` | string | `gpg_key` or `cert` |
| `content_source` | string | `"file"` (local path) or `"url"` (remote URL). **Must be `"file"` for air-gapped access** |
| `content_path` | string | Local filesystem path (when `content_source: "file"`) or URL (when `content_source: "url"`) |
| `state` | string | `present` or `absent` |

---

## custom_products.yml — Custom Third-Party Products

Custom (non-Red Hat CDN) products and their repositories.

**Difference from primary satellite:** The default active product is a placeholder `MyCustomProduct` used for content upload demos. The extensive list of third-party products (convert2RHEL, CentOS79, OEL79, EPEL8/9, CentOS Stream 9, Microsoft SQL Server, rhel9_containers) are commented out by default, as they require external network access that a disconnected satellite may not have.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `custom_products` | list of dict | — | Custom products to create in Satellite | satellite_content role |

**`custom_products` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Product display name in Satellite |
| `desc` | string | Product description |
| `org` | string | Satellite organization |
| `label` | string | Unique label (no spaces, used in repo paths) |
| `repositories` | list of dict | One or more repository definitions (see schema below) |

**`custom_products[].repositories` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Repository display name |
| `upstream_name` | string | Upstream repository name (empty for YUM; required for Docker) |
| `content_type` | string | `yum`, `docker`, `file`, or `deb` |
| `url` | string | Upstream repository URL (empty if content will be uploaded manually) |
| `username` | string | Upstream repository username (optional) |
| `password` | string | Upstream repository password (optional) |
| `download_policy` | string | `immediate`, `on_demand`, or `background` |
| `gpg_key` | string | Name of GPG key credential (optional) |
| `include_tags` | string | Docker tag filter (Docker only, optional) |
| `exclude_tags` | string | Docker tag exclusion filter (Docker only, optional) |
| `docker_upstream_name` | string | Docker image name on the upstream registry (Docker only) |
| `upstream_username` | string | Registry username for Docker repos (optional) |
| `upstream_password` | string | Registry password for Docker repos (optional) |
| `description` | string | Repository description (optional) |
| `label` | string | Repository label override (optional, Docker often requires explicit label) |

---

## repository_sets.yml — Red Hat CDN Repository Sets

Red Hat repository sets to enable in the Satellite manifest. For the disconnected Satellite, content is received via import rather than direct CDN sync, but the repository set definitions are needed so that Satellite knows which repositories exist.

The repository set list is identical to the primary satellite. Sync control variables are also present.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `skip_sync` | bool | `false` | When `true`, skip synchronizing all repository content | satellite_sync role |
| `skip_publish_all` | bool | `false` | When `true`, skip publishing all content views and CCVs | satellite_content_views role |
| `repository_sets` | list of dict | — | Red Hat CDN repository sets to enable | satellite_repository_sets role |

**`repository_sets` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Exact Red Hat CDN repository set name |
| `product` | string | yes | Red Hat product the set belongs to |
| `repository_list` | list of dict | no | Release versions to enable. Omit to enable the default arch/version |

**`repository_list` entry schema:**

| Key | Type | Description |
|---|---|---|
| `releasever` | string | Release version (e.g. `"9"`, `"9.7"`, `"8.10"`) |
| `basearch` | string | Base architecture (e.g. `"x86_64"`); required for RHEL 7 repos |

---

## repositories.yml — Repository Configuration Overrides

Per-repository settings applied after repository set or custom product creation. All repositories set `download_policy: "immediate"` — required for content export compatibility.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `satellite_repositories` | list of dict | — | Repository configuration overrides | satellite_repositories role |

**`satellite_repositories` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Exact repository name as it appears in Satellite |
| `product` | string | Parent product name |
| `content_type` | string | `yum`, `file`, `docker`, or `deb` |
| `download_policy` | string | `immediate` (required for export), `on_demand`, or `background` |
| `gpg_key` | string | GPG key credential name (optional) |
| `ssl_ca_cert` | string | SSL CA certificate credential name (optional) |
| `unprotected` | bool | Whether to allow unauthenticated access (optional) |

---

## content_views.yml — Content Views and Composite Content Views

Content view (CV) and composite content view (CCV) definitions. This file is identical to the primary satellite — the same CV/CCV structure is used to manage content post-import.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `errata_end_date` | string | `{{ ansible_date_time.date }}` | Cutoff date for errata filters; set to the current date at run time | satellite_content_views role |
| `skip_publish_all` | bool | `false` | When `true`, skip publishing all CVs and CCVs | satellite_content_views role |
| `content_views` | list of dict | — | Content view definitions (CVs and CCVs) | satellite_content_views role |

**`content_views` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Content view display name |
| `desc` | string | no | Description |
| `org` | string | yes | Satellite organization |
| `force_publish` | bool | no | Force publication even if content hasn't changed |
| `publication_threshold_hours` | int | no | Minimum hours between publications |
| `repositories` | list of dict | no | Repositories included (for simple CVs) |
| `components` | list of dict | no | Component CV versions (for CCVs) |
| `filters` | list of dict | no | Content filters applied to this CV |
| `environments` | list of string | no | Lifecycle environments to promote to after publish |

**`repositories` entry schema (within a CV):**

| Key | Type | Description |
|---|---|---|
| `name` | string | Exact repository name in Satellite |
| `product` | string | Parent product name |

**`filters` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Filter name |
| `type` | string | `rpm`, `erratum`, `modulemd`, `package_group`, or `docker` |
| `inclusion` | bool | `true` = include matching; `false` = exclude matching |
| `description` | string | Filter description |
| `original_packages` | bool | Include packages not in errata (for errata filters) |
| `repositories` | string or list | Repositories to apply filter to; `"[]"` means all |
| `rules` | list of dict | Filter rules (errata date ranges, RPM name patterns, etc.) |

---

## lifecycle_environments.yml — Lifecycle Environments

Lifecycle environment pipeline defining the content promotion path.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `lifecycle_environments` | list of dict | — | Ordered list of lifecycle environments | satellite_lifecycle_environments role |

**`lifecycle_environments` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Environment display name |
| `label` | string | Unique label (no spaces) |
| `description` | string | Environment description |
| `organization` | string | Satellite organization |
| `prior` | string | Name of the preceding environment (`"Library"` for the first environment) |

The standard pipeline is: **Library → Development → Qualification → Production → Retired**

---

## activation_keys.yml — Activation Keys

Activation keys used to register hosts to the disconnected Satellite. The key structure is identical to the primary satellite.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `activation_keys` | list of dict | — | Activation key definitions | satellite_activation_keys role |

**`activation_keys` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Activation key name (e.g. `SOE10_dev`, `SOE9_prod`) |
| `state` | string | `present` or `absent` |
| `description` | string | Human-readable description |
| `organization` | string | Satellite organization |
| `auto_attach` | bool | Automatically attach subscriptions on registration |
| `content_overrides` | list of dict | Repository enable/disable overrides; each entry has `label` (repo label) and `override` (`"enabled"` or `"disabled"`) |
| `content_view` | string | Name of the content view to associate |
| `lifecycle_environment` | string | Name of the lifecycle environment to associate |
| `unlimited_hosts` | bool | Allow unlimited host registrations with this key |
| `purpose_role` | string | Subscription purpose role (e.g. `"Red Hat Enterprise Linux Server"`) |
| `purpose_usage` | string | Subscription purpose usage (e.g. `"Development/Test"`, `"Production"`) |
| `service_level` | string | Service level agreement (e.g. `"Self-Support"`, `"Standard"`, `"Premium"`) |

---

## sync_plans.yml — Synchronization Plans

Scheduled content synchronization plans. On the disconnected Satellite, sync plans schedule the import of content received from the primary, not direct CDN sync.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `sync_plans` | list of dict | — | Sync plan definitions | satellite_sync_plans role |

**`sync_plans` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Sync plan name |
| `desc` | string | Sync plan description |
| `interval` | string | `daily`, `weekly`, `hourly`, or `custom cron` |
| `sync_date` | string | Start date and time (format: `YYYY-MM-DD HH:MM:SS`) |
| `enabled` | bool | Whether the plan is active |
| `organization` | string | Satellite organization |
| `location` | string | Satellite location |

Three sync plans are defined: `nightly_os` (00:30), `nightly_infra` (02:30), `nightly_third_party` (03:30).

---

## synchronization.yml — Synchronization Control

Simple controls for on-demand synchronization runs.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `last_sync_threshold_hours` | int | `24` | Threshold in hours; repos synced within this window are skipped in ad hoc sync runs | satellite_sync role |
| `skip_sync_all` | bool | `false` | When `true`, skip all content synchronization | satellite_sync role |

---

## sync_plan_product_map.yml — Product to Sync Plan Assignments

Maps each product to one of the three nightly sync plans.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `product_plans` | list of dict | — | Product-to-sync-plan assignments | satellite_sync_plans role |

**`product_plans` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Exact product name as it appears in Satellite |
| `plan` | string | Name of the sync plan to assign (e.g. `"nightly_os"`) |
| `organization` | string | Satellite organization |

---

## content_exports.yml.j2 — Content Export Definitions (Jinja2)

**Unique to this host as active content:** The primary satellite exports the full Library; the discosatellite exports individual repositories or content view versions (typically to share content with a deeper air-gap tier). The file is Jinja2 (`.j2`) and uses `{% raw %}`/`{% endraw %}` blocks.

The library export example is commented out. The active default exports a single named repository.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `content_exports` | list of dict | — | Content export job definitions | satellite_content_exports role |

**`content_exports` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Export job name |
| `type` | string | yes | Export type: `library`, `repository`, or `cv_version` |
| `organization` | string | yes | Satellite organization |
| `format` | string | yes | `importable` (chunked, for air-gap transfer) or `syncable` (RPM-based, cannot be chunked) |
| `product` | string | conditional | Required when `type: "repository"` |
| `repository` | string | conditional | Required when `type: "repository"` |
| `content_view` | string | conditional | Required when `type: "cv_version"` |
| `content_view_version` | string | conditional | Required when `type: "cv_version"` |
| `chunk_size_gb` | string | no | Export chunk size in GB; only valid with `format: "importable"` |
| `destination_server` | string | no | FQDN of the target Satellite; used to organize export directories |
| `fail_on_missing_content` | bool | no | Fail if content is missing rather than exporting partial data |
| `incremental` | bool | no | Perform an incremental export (only content since last export) |

---

## content_imports.yml — Content Import Definitions

Defines content to import from exported packages. This file is typically **generated by the content_exports role on the source Satellite** and stored at `/var/lib/pulp/exports/{{ content_export.destination_server }}/content_import.yml`.

**Difference from primary satellite:** The primary satellite has a minimal placeholder import entry (`name: "Library"`). The discosatellite file contains detailed instructions and a commented-out example showing repository imports with full path information.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `content_imports` | list of dict | — | Content import job definitions | satellite_content_imports role |

**`content_imports` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Import job name (e.g. repository or content view name) |
| `type` | string | no | Import type: `repository`, `library`, or `cv_version`. Omit for library imports |
| `import_path` | string | conditional | Full path to the export directory containing chunked import files |
| `metadata_file` | string | conditional | Full path to the `metadata.json` file within the import directory |

---

## content_export_copies.yml — Export Copy Definitions

Copies content exports to removable media or external storage for physical transport.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `content_export_copies` | list of dict | — | Export copy job definitions | satellite_content_export_copies role |

**`content_export_copies` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Copy job name |
| `type` | string | Export type being copied: `library`, `repository`, or `cv_version` |
| `destination_server` | string | FQDN of the target Satellite (used to locate the export directory) |
| `export_version` | string | Version string of the export to copy |
| `destination_folder` | string | Target path for the copy (e.g. `"/run/media/ansiblerunner/export"`) |

---

## content_uploads.yml — Direct Content Uploads (unique to discosatellite)

**Unique to the disconnected Satellite.** Defines individual RPM packages or other files to upload directly to a Satellite repository using the Pulp API. This is used when packages need to be added to custom repositories without going through a full content export/import cycle.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `content_uploads` | list of dict | — | Content upload job definitions | satellite_content_uploads role |

**`content_uploads` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Upload job name |
| `organization` | string | yes | Satellite organization |
| `product` | string | yes | Target product name |
| `repository` | string | yes | Target repository name |
| `repository_type` | string | yes | Repository type: `yum`, `file`, or `deb` |
| `upload_from_provisioner` | bool | no | When `true`, copy files from the provisioner host to the Satellite before uploading |
| `source_directory` | string | no | Source directory on the provisioner host (prepended to each `src_files` path for the copy operation) |
| `target_directory` | string | no | Target directory on the Satellite host (e.g. `"/var/lib/pulp/imports/upload_files"`) |
| `src_files` | list of string | yes | List of filenames to upload (relative to `source_directory`) |

---

## domains.yml — DNS Domains

DNS domains registered in Satellite.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `satellite_domains` | list of dict | — | Domain definitions | satellite_domains role |

**`satellite_domains` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | DNS domain name (e.g. `example.com`) |
| `description` | string | Human-readable description |
| `dns_capsule` | string | FQDN of the Smart Proxy managing DNS for this domain |
| `organizations` | list of string | Organizations the domain belongs to |
| `locations` | list of string | Locations the domain belongs to |

---

## subnets.yml — Network Subnets

Network subnets registered in Satellite for IPAM, DHCP, DNS, and TFTP management.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `satellite_subnets` | list of dict | — | Subnet definitions | satellite_subnets role |

**`satellite_subnets` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Subnet display name |
| `description` | string | Human-readable description |
| `network_type` | string | `IPv4` or `IPv6` |
| `network` | string | Network address (e.g. `192.168.1.0`) |
| `prefix` | string | CIDR prefix length |
| `mask` | string | Subnet mask |
| `gateway` | string | Default gateway IP |
| `dns_primary` | string | Primary DNS server IP |
| `dns_secondary` | string | Secondary DNS server IP |
| `ipam` | string | IPAM method: `Internal DB`, `DHCP`, `Random DB`, or `None` |
| `from_ip` | string | Start of IPAM allocation range |
| `to_ip` | string | End of IPAM allocation range |
| `boot_mode` | string | `Static` or `DHCP` |
| `discovery_capsule` | string | Smart Proxy handling discovery for this subnet (optional) |
| `tftp_capsule` | string | Smart Proxy providing TFTP for this subnet (optional) |
| `dns_capsule` | string | Smart Proxy providing DNS for this subnet (optional) |
| `template_capsule` | string | Smart Proxy providing templates for this subnet (optional) |
| `remote_execution_capsules` | list of string | Smart Proxies for remote execution on this subnet (optional) |
| `parameters` | list of dict | Subnet-level parameters; each has `name`, `parameter_type`, `value` |
| `domains` | list of string | DNS domains associated with this subnet |
| `locations` | list of string | Locations the subnet belongs to |
| `organizations` | list of string | Organizations the subnet belongs to |

---

## realms.yml — Kerberos Realms

IdM/Kerberos realms managed by Satellite for automatic host enrollment.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `satellite_realms` | list of dict | — | Realm definitions | satellite_realms role |

**`satellite_realms` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Realm name (always uppercase, e.g. `EXAMPLE.COM`) |
| `organizations` | string | Satellite organization |
| `locations` | string | Satellite location |
| `realm_type` | string | `"Red Hat Identity Management"` or `"Active Directory"` |
| `realm_capsule` | string | FQDN of the Smart Proxy managing realm enrollment |

---

## locations.yml — Satellite Locations

Additional Satellite locations beyond the default. Both entries are commented out with sample disconnected data-centre location names.

| Variable | Type | Description | Used by |
|---|---|---|---|
| `satellite_locations` | list of dict | Optional additional locations. Each entry has `name`, `organizations`, `parameters`, and `state` | satellite_locations role |

---

## organizations.yml — Satellite Organizations

Additional Satellite organizations beyond the default. The example Finance organization is commented out.

| Variable | Type | Description | Used by |
|---|---|---|---|
| `satellite_organizations` | list of dict | Optional additional organizations. Each entry has `name`, `description`, `label`, `parameters`, and `state` | satellite_organizations role |

---

## compute_resources.yml.j2 — Compute Resources (Jinja2)

Compute resource definitions for VMware, KVM/libvirt, Azure, and AWS. This file is Jinja2 (`.j2`).

**Difference from primary satellite:** Identical structure and provider list. The Azure and AWS credential variables reference vault variables directly (without intermediate local variables in some cases). The Azure region and resource group variables use Jinja2 interpolation outside `{% raw %}`/`{% endraw %}` blocks to allow the outer template layer to expand `basevars_global_domain_name`.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `vcenter_service_username` | string | — | VMware vCenter service account username (references vault) | compute_resources role |
| `vcenter_service_password` | string | — | VMware vCenter service account password (references vault) | compute_resources role |
| `vmware_cluster1_name` | string | `"chassis1"` | VMware cluster name | compute_profiles |
| `vmware_cluster1_path` | string | derived | VM folder path in vCenter | compute_profiles |
| `vmware_cluster1_datastore` | string | `"NAS1_VMS"` | Default vCenter datastore | compute_profiles |
| `vmware_cluster1_network` | string | `"VM Network"` | Default VM portgroup | compute_profiles |
| `azure1_tenant_id` | string | — | Azure tenant ID (references vault) | compute_resources role |
| `azure1_subscription_id` | string | — | Azure subscription ID (references vault) | compute_resources role |
| `azure1_client_id` | string | — | Azure service principal client ID (references vault) | compute_resources role |
| `azure1_client_secret_id` | string | — | Azure service principal secret ID (references vault) | compute_resources role |
| `azure1_client_secret` | string | — | Azure service principal secret (references vault) | compute_resources role |
| `azure1_cloud` | string | `"azure"` | Azure cloud environment | compute_resources role |
| `azure1_region` | string | `{{ rhis_azure_region }}` | Azure deployment region | compute_resources role |
| `azure1_resourcegroup1` | string | derived | Primary Azure resource group name | compute_resources role |
| `azure1_rg1_vnet1` | string | derived | Azure virtual network name | compute_resources role |
| `azure1_rg1_vn1_subnet1` | string | derived | Azure subnet name | compute_resources role |
| `azure1_user_ssh_key` | string | — | SSH public key for Azure VMs (references vault) | compute_resources role |
| `aws1_access_key` | string | — | AWS access key ID (references vault) | compute_resources role |
| `aws1_secret_key` | string | — | AWS secret access key (references vault) | compute_resources role |
| `aws1_gov_cloud` | bool | `false` | Use AWS GovCloud region | compute_resources role |
| `aws1_region` | string | `{{ rhis_aws_region }}` | AWS deployment region | compute_resources role |
| `compute_resources` | list of dict | — | List of compute resource definitions | satellite_compute_resources role |

**`compute_resources` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Compute resource display name in Satellite |
| `provider` | string | Provider type: `vmware`, `libvirt`, `AzureRm`, `EC2`, `ovirt`, `GCE`, `Openstack` |
| `description` | string | Human-readable description |
| `locations` | string | Satellite location |
| `organizations` | string | Satellite organization |
| `images` | list of dict | OS images configured on this resource (Azure and EC2 only) |
| `provider_params` | dict | Provider-specific connection parameters |

---

## compute_profiles.yml — Compute Profiles

Reusable VM sizing templates (SOE_Small, SOE_Medium, SOE_Large) for VMware and Azure. Structure is identical to the primary satellite.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `compute_profiles` | list of dict | — | Compute profile definitions | satellite_compute_profiles role |

**`compute_profiles` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Profile name (e.g. `SOE_Small`, `SOE_Medium`, `SOE_Large`) |
| `compute_attributes` | list of dict | One entry per compute resource; each has `compute_resource` (name) and `vm_attrs` (provider-specific VM attributes including CPUs, memory, disks, network) |

---

## operating_systems.yml — Operating System Definitions

Operating system records in Satellite with associated provisioning templates and partition tables.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `operating_systems` | list of dict | — | Operating system definitions | satellite_operating_systems role |

**`operating_systems` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | OS family name (e.g. `RedHat`, `CentOS`) |
| `major` | int | Major version number |
| `minor` | int | Minor version number |
| `description` | string | Human-readable description |
| `family` | string | OS family (`Redhat`, `Debian`, etc.) |
| `password_hash` | string | Password hashing algorithm (e.g. `SHA256`) |
| `organization` | string | Satellite organization |
| `location` | string | Satellite location |
| `state` | string | `present` or `absent` |
| `architectures` | list of string | Supported architectures (e.g. `["x86_64"]`) |
| `provisioning_templates` | list of string | Provisioning template names associated with this OS |
| `ptables` | list of string | Partition table names associated with this OS |

---

## provisioning_templates.yml — Custom Provisioning Templates

Custom SOE kickstart, finish, PXE, iPXE, and snippet templates uploaded from local files.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `provisioning_templates` | list of dict | — | Provisioning template definitions | satellite_provisioning_templates role |

**`provisioning_templates` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Template display name in Satellite |
| `type` | string | Template type: `provision`, `finish`, `PXELinux`, `PXEGrub2`, `iPXE`, `snippet`, `user_data`, `host_init_config` |
| `locked` | bool | Prevent accidental modification of the template |
| `description` | string | Template description |
| `audit_comment` | string | Audit log comment for template creation |
| `path` | string | Path to the template file (relative to the role files directory) |
| `organizations` | list of string | Organizations the template belongs to |
| `locations` | list of string | Locations the template belongs to |

---

## partition_tables.yml — Partition Table Templates

Custom partition table templates for compliance and encrypted disk configurations.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `partition_tables` | list of dict | — | Partition table definitions | satellite_partition_tables role |

**`partition_tables` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Partition table display name (e.g. `RHEL_Server_CIS1`, `RHEL_Server_Compliance_Encrypted`) |
| `os_family` | string | OS family (`Redhat`, `Debian`, etc.) |
| `path` | string | Path to the Jinja2 template file |
| `description` | string | Human-readable description |
| `audit_comment` | string | Audit log comment |
| `organizations` | list of string | Organizations the partition table belongs to |
| `locations` | list of string | Locations the partition table belongs to |

---

## hostgroups.yml — Hostgroups

Hostgroup definitions that group provisioning parameters for a given OS, compute resource, lifecycle environment, content view, and activation key combination.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `satellite_hostgroups` | list of dict | — | Hostgroup definitions | satellite_hostgroups role |

**`satellite_hostgroups` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Hostgroup name |
| `description` | string | Human-readable description |
| `organization` | string | Satellite organization |
| `locations` | string | Satellite location |
| `parent` | string | Parent hostgroup name (for child hostgroups) |
| `compute_resource` | string | Compute resource name (for VM hostgroups) |
| `compute_profile` | string | Compute profile name (for VM hostgroups) |
| `content_source` | string | FQDN of the content Smart Proxy |
| `lifecycle_environment` | string | Lifecycle environment name |
| `content_view` | string | Content view name |
| `activation_keys` | string | Activation key name |
| `openscap_capsule` | string | FQDN of the OpenSCAP Smart Proxy |
| `ansible_roles` | list of string | Ansible roles to assign |
| `domain` | string | DNS domain for provisioned hosts |
| `subnet` | string | Subnet name |
| `realm` | string | Kerberos realm for host enrollment |
| `architecture` | string | CPU architecture (e.g. `x86_64`, `aarch64`) |
| `operatingsystem` | string | Operating system description (e.g. `RHEL 10.1`) |
| `kickstart_repository` | string | Kickstart repository name for OS installation |
| `ptable` | string | Partition table name |
| `pxe_loader` | string | PXE loader type (e.g. `Grub2 UEFI`, `PXELinux BIOS`) |
| `root_pass` | string | Root password for provisioned hosts |
| `parameters` | list of dict | Hostgroup-level parameters; each has `name`, `hidden_value`, `parameter_type`, `value` |

---

## global_parameters.yml — Global Satellite Parameters (Plain YAML)

**Difference from primary satellite:** This file is plain YAML (not `.j2`). It contains a reduced set of parameters — NBDE tang-related parameters (`binding_json`, `binding_type`), grub menu template selection (`grubmenu_pass_cmd`), Lightspeed AI integration parameters, and Insights upload parameters are absent. `remove_default_passphrase` defaults to `true` (vs `false` on the primary satellite). `ansible_tower_provisioning` is `false` (AAP callback is disabled in disconnected mode).

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `global_parameters` | list of dict | — | Satellite global parameters applied to all hosts | satellite_global_parameters role |

**`global_parameters` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Parameter name as referenced in provisioning templates |
| `value` | any | Parameter value (string, bool, int, or list) |
| `parameter_type` | string | `string`, `boolean`, `integer`, `real`, `array`, `hash`, `yaml`, or `json` |
| `hidden_value` | bool | Hide value in Satellite UI (optional) |
| `state` | string | `present` or `absent` (optional; `present` if omitted) |

**Active global parameters (discosatellite):**

| Parameter | Type | Value | Description |
|---|---|---|---|
| `ansible_controller_api_url` | string | `https://{{ groups['aap_controllers'][0] }}/api/v2` | AAP controller API URL |
| `ansible_host_config_key` | string | (vault) | AAP callback configuration key |
| `ansible_job_template_id` | integer | `13` | Default AAP job template ID for callback |
| `ansible_roles_check_mode` | boolean | `false` | Run Ansible roles in check mode |
| `ansible_tower_provisioning` | boolean | `false` | Disable AAP provisioning callback (disconnected mode) |
| `enable-epel` | boolean | `false` | Enable EPEL repository on hosts |
| `enable-remote-execution-pull` | boolean | `false` | Use pull mode for Remote Execution |
| `fips_enabled` | boolean | `false` | Enable FIPS 140 mode during provisioning |
| `encrypt_grub` | boolean | `false` | Encrypt the GRUB bootloader |
| `grubmenu_pass` | string | (hashed) | GRUB menu password (hidden) |
| `host_packages` | string | `"vim"` | Additional packages installed during provisioning |
| `host_registration_insights` | boolean | `true` | Register hosts with Red Hat Insights |
| `host_registration_remote_execution` | boolean | `true` | Configure REX during host registration |
| `install_environment_group` | string | `"server-product-environment"` | Kickstart environment group |
| `install_reboot_kexec` | boolean | `false` | Use kexec for post-install reboot |
| `network_zone` | string | `"public"` | Firewalld zone for provisioned hosts |
| `package_upgrade` | boolean | `true` | Apply all updates during provisioning |
| `redhat_install_agent` | boolean | `false` | Install Red Hat management agent |
| `redhat_install_host_tools` | boolean | `true` | Install Red Hat host tools |
| `redhat_install_host_tracer_tools` | boolean | `true` | Install Red Hat tracer tools |
| `remote_execution_create_user` | boolean | `true` | Create REX user during provisioning |
| `remote_execution_effective_user_method` | string | `"sudo"` | Method for privilege escalation in REX |
| `remote_execution_ssh_keys` | string | (vault) | SSH public keys for REX user |
| `remote_execution_ssh_user` | string | (vault) | SSH username for REX |
| `remove_default_passphrase` | boolean | `true` | Remove default disk encryption passphrase post-provisioning (**`true` here vs `false` on primary**) |
| `use_foreman_users` | boolean | `true` | Create Foreman user accounts on hosts |
| `use_graphical_installer` | boolean | `false` | Use graphical Anaconda installer |
| `use_ntp` | boolean | `false` | Use NTP instead of chrony |

---

## discovery_config.yml — PXE Discovery Configuration

Custom PXE discovery templates with chassis position fact injection.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `rhis_discovery_custom_facts_enable` | bool | `true` | Enable custom fact collection during discovery | satellite_discovery role |
| `rhis_discovery_custom_facts_file` | string | `"boot/discovery_facts.zip"` | ZIP file containing custom fact scripts (relative to role files directory) | satellite_discovery role |
| `rhis_discovery_pxelinux_template` | string | `"prov_template_snippet_soe_pxelinux_discovery.j2"` | PXELinux discovery template filename | satellite_discovery role |
| `rhis_discovery_pxegrub_template` | string | `"prov_template_snippet_soe_pxegrub_discovery.j2"` | PXEGrub discovery template filename | satellite_discovery role |
| `rhis_discovery_pxegrub2_template` | string | `"prov_template_snippet_soe_pxegrub2_discovery.j2"` | PXEGrub2 discovery template filename | satellite_discovery role |
| `rhis_discovery_ipxe_global_default_template` | string | `"ipxe_template_soe_ipxe_global_default.j2"` | iPXE global default template filename | satellite_discovery role |
| `rhis_discovery_pxegrub_global_default_template` | string | `"pxegrub_template_soe_pxegrub_global_default.j2"` | PXEGrub global default template filename | satellite_discovery role |
| `rhis_discovery_pxegrub2_global_default_template` | string | `"pxegrub2_template_soe_pxegrub2_global_default.j2"` | PXEGrub2 global default template filename | satellite_discovery role |
| `rhis_discovery_pxegrub2_default_local_boot_template` | string | `"pxegrub2_template_soe_pxegrub2_default_local_boot.j2"` | PXEGrub2 local boot template filename | satellite_discovery role |
| `rhis_discovery_pxelinux_global_default_template` | string | `"pxelinux_template_soe_pxelinux_global_default.j2"` | PXELinux global default template filename | satellite_discovery role |

---

## discovery_rules.yml — Automatic Provisioning Rules

Rules that automatically provision discovered hosts matching defined criteria.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `discovery_rules` | list of dict | — | Discovery rule definitions | satellite_discovery_rules role |

**`discovery_rules` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Rule display name |
| `enabled` | bool | Whether the rule is active |
| `state` | string | `present` or `absent` |
| `organizations` | string | Satellite organization |
| `locations` | string | Satellite location |
| `search` | string | Foreman search expression matching host facts (e.g. `disk_count = 2 and memory > 32000`) |
| `priority` | int | Rule evaluation order (lower number = higher priority) |
| `hostgroup` | string | Hostgroup to provision matching hosts into |

---

## scap_content.yml — OpenSCAP Content Files

SCAP data streams and tailoring files for compliance scanning.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `scap_contents` | list of dict | — | SCAP data stream definitions | satellite_scap role |
| `scap_tailoring_files` | list of dict | — | SCAP tailoring file definitions | satellite_scap role |

**`scap_contents` entry schema:**

| Key | Type | Description |
|---|---|---|
| `title` | string | Display title in Satellite |
| `scap_file` | string | Filename of the SCAP data stream XML file (relative to the role files directory) |
| `locations` | list of string | Satellite locations |
| `organizations` | list of string | Satellite organizations |

**`scap_tailoring_files` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Display name of the tailoring file |
| `scap_file` | string | Filename of the tailoring XML file |
| `locations` | list of string | Satellite locations |
| `organizations` | list of string | Satellite organizations |

---

## scap_policies.yml — OpenSCAP Compliance Policies

SCAP compliance policy definitions that schedule and assign scanning to hostgroups.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `scap_policies` | list of dict | — | SCAP policy definitions | satellite_scap role |

**`scap_policies` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Policy display name |
| `description` | string | Policy description |
| `deploy_by` | string | Deployment method: `"ansible"`, `"puppet"`, or `"manual"` |
| `scap_content` | string | Name of the SCAP content to use |
| `scap_profile` | string | SCAP profile name within the data stream |
| `period` | string | Scan schedule: `"weekly"`, `"monthly"`, `"custom"` |
| `weekday` | string | Day of week for weekly scans (e.g. `"Monday"`) |
| `day_of_month` | int | Day of month for monthly scans |
| `cron_line` | string | Cron expression for custom schedules |
| `hostgroups` | list of string | Hostgroup names to assign this policy to |
| `tailoring_file` | string | Name of the tailoring file (optional) |
| `tailoring_file_profile` | string | Profile within the tailoring file (optional) |
| `organizations` | list of string | Satellite organizations |
| `locations` | list of string | Satellite locations |

---

## virtwho_configs.yml — virt-who Hypervisor Configurations

virt-who service account and hypervisor configuration for subscription reporting.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `satellite_virtwho_username` | string | — | virt-who Satellite service account username (references vault) | virtwho role |
| `satellite_virtwho_password` | string | — | virt-who Satellite service account password (references vault) | virtwho role |
| `vcenter_virtwho_username` | string | — | vCenter service account for virt-who (references vault) | virtwho role |
| `vcenter_virtwho_password` | string | — | vCenter password for virt-who (references vault) | virtwho role |
| `virtwho_configs` | list of dict | — | virt-who configuration definitions | virtwho role |

**`virtwho_configs` entry schema:**

| Key | Type | Description |
|---|---|---|
| `foreman_virt_who_configure_config` | dict | virt-who configuration parameters (see below) |

**`foreman_virt_who_configure_config` dict schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Configuration display name |
| `hypervisor_type` | string | Hypervisor type: `esx` (VMware), `hyperv`, `xen`, `libvirt`, `kubevirt` |
| `hypervisor_server` | string | Hypervisor server URL or FQDN |
| `hypervisor_username` | string | Username for hypervisor connection |
| `hypervisor_password` | string | Password for hypervisor connection |
| `hypervisor_id` | string | How to identify hypervisors: `hostname`, `uuid`, or `hwuuid` |
| `interval` | string | Reporting interval in minutes |
| `filtering_mode` | int | `0` = no filter, `1` = whitelist, `2` = blacklist |
| `satellite_url` | string | Satellite FQDN for this config |
| `organization_name` | string | Organization name |
| `organization_id` | int | Organization ID (looked up by name if `0`) |

---

## capsules.yml — Smart Proxy Capsule Definitions

Capsule Smart Proxy definitions for the disconnected Satellite. The entire content is **commented out** — the discosatellite does not have capsules by default but the variable structure is provided as a reference.

| Variable | Type | Description | Used by |
|---|---|---|---|
| `capsule_ssl_rsa_key_pass` | string | SSL RSA key passphrase for capsule certificate generation (references vault; commented out) | capsules role |
| `satellite_capsules` | list of dict | List of capsule definitions (commented out); each entry has `fqdn`, `crt_force_regen`, `download_policy`, `lifecycle_environments`, `organizations`, `locations` | capsules role |

---

## rex_kerberos.yml — Remote Execution Kerberos Settings

Kerberos SSH authentication configuration for Remote Execution.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `rex_kerberos_enabled` | bool | `true` | Enable Kerberos-based SSH authentication for REX | satellite_installer, rex role |
| `rex_realm_principal` | string | `"realm-capsule"` | Kerberos principal whose keytab is used for REX SSH | rex role |
| `rex_executor` | string | `"foreman-proxy"` | REX executor backend: `"foreman-proxy"` or `"ssh"` | rex role |

---

## satellite_template_sync.yml — Template Repository Synchronization

Git repositories containing provisioning, job, and report templates to synchronize into Satellite.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `satellite_template_repos` | list of dict | — | Template Git repository definitions | satellite_template_sync role |

**`satellite_template_repos` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Repository display name |
| `repo_url` | string | Git repository URL |
| `dirname` | string | Subdirectory within the repository containing templates |
| `branch` | string | Git branch to sync from |
| `associate` | string | When to associate templates: `"always"`, `"new"`, or `"never"` |
| `force` | string/bool | Force update of locked templates |
| `locked` | bool | Lock templates after sync (optional) |
| `locations` | string | Satellite locations (quoted list syntax) |
| `organizations` | string | Satellite organizations (quoted list syntax) |

---

## template_repos_jobs.yml — Job Template Git Repositories (unique to discosatellite)

**Unique to the disconnected Satellite.** Defines Git repositories containing job templates to synchronize into Satellite. Separate from `satellite_template_sync.yml` to allow independent management of job templates.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `template_repos_jobs` | list of dict | — | Job template Git repository definitions | satellite_template_sync role |

**`template_repos_jobs` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `associate` | string | yes | When to associate: `"always"`, `"new"`, or `"never"` |
| `branch` | string | yes | Git branch to sync from |
| `dirname` | string | yes | Subdirectory containing job templates (e.g. `"job_templates"`) |
| `filter` | string | no | Glob pattern to filter templates (e.g. `"soe*"`) |
| `force` | bool | no | Force update of locked templates |
| `locations` | list of string | no | Satellite locations to associate templates with |
| `lock` | bool | no | Lock templates after sync |
| `negate` | bool | no | Negate the filter pattern |
| `organizations` | list of string | no | Satellite organizations to associate templates with |
| `prefix` | string | no | Prefix to add to imported template names (e.g. `"rhis-"`) |
| `repo` | string | yes | Git repository URL |
| `verbose` | bool | no | Verbose sync output |

---

## template_repos_provisioning.yml — Provisioning Template Git Repositories (unique to discosatellite)

**Unique to the disconnected Satellite.** Defines Git repositories containing provisioning templates (kickstart, PXE, iPXE, finish, snippets).

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `template_repos_provisioning` | list of dict | — | Provisioning template Git repository definitions | satellite_template_sync role |

Entry schema is identical to `template_repos_jobs` above, with `dirname` typically set to `"provisioning_templates"`.

---

## template_repos_ptables.yml — Partition Table Template Git Repositories (unique to discosatellite)

**Unique to the disconnected Satellite.** Defines Git repositories containing partition table templates.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `template_repos_ptables` | list of dict | — | Partition table template Git repository definitions | satellite_template_sync role |

Entry schema is identical to `template_repos_jobs` above, with `dirname` typically set to `"partition_table_templates"`.

---

## imported_git_repos.yml — Compliance Ansible Role Git Clones

Defines Git repositories to clone directly onto the Satellite server OS for use as Ansible compliance roles.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `git_repos` | list of dict | — | Git repository clone definitions | satellite_git_repos role |

**`git_repos` entry schema:**

| Key | Type | Description |
|---|---|---|
| `repository` | string | Git repository URL |
| `dest` | string | Local destination path (e.g. `/etc/ansible/roles/ansible-role-rhel9-e8`) |
| `clone` | bool | Clone the repository if it does not exist |
| `force` | bool | Force update even if the destination already exists |

Repositories cloned include RedHatOfficial compliance Ansible roles for RHEL 7, 8, and 9 across multiple security frameworks (CIS, STIG, HIPAA, PCI-DSS, OSPP, ANSSI, CUI, ISM, and others).

---

## imported_ansible_roles.yml — Ansible Role Import into Satellite

Imports Ansible roles (previously cloned to the Satellite OS) into the Satellite web UI via the API.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `satellite_api_proxy_id_string` | string | `"1-{{ satellite_fqdn }}"` | Smart Proxy identifier used in the Satellite API call for role import (format: `proxy_id-proxy_fqdn`) | satellite_ansible_roles role |
| `ansible_roles_import_list` | list of string | — | List of Ansible role directory names to import from the Smart Proxy | satellite_ansible_roles role |

---

## job_templates.yml — Custom Job Templates

Custom Satellite job templates for Remote Execution.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `job_templates` | list of dict | — | Job template definitions | satellite_job_templates role |

**`job_templates` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Template display name |
| `audit_comment` | string | Audit log comment |
| `path` | string | Path to the Jinja2 template file |
| `job_category` | string | Template category (e.g. `"Provisioning"`, `"Commands"`) |
| `locations` | string | Satellite location |
| `organizations` | string | Satellite organization |
| `locked` | bool | Lock the template against modification |
| `provider_type` | string | Execution provider: `"script"` or `"ansible"` |
| `snippet` | bool | Whether this is a snippet rather than a full template |
| `state` | string | `present` or `absent` |
| `template_inputs` | list of dict | User input definitions (see schema below) |

**`template_inputs` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Input parameter name |
| `advanced` | bool | Show input in advanced section only |
| `default` | string | Default value |
| `description` | string | User-facing description |
| `input_type` | string | `"user"`, `"fact"`, `"variable"`, or `"puppet_parameter"` |
| `options` | list | List of allowed values for the input |
| `required` | bool | Whether the input must be provided |
| `value_type` | string | `"plain"`, `"search"`, or `"date"` |

---

## installation_media.yml — OS Installation Media

Web-based installation media sources for non-Red Hat operating systems.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `installation_media` | list of dict | — | Installation media definitions | satellite_installation_media role |

**`installation_media` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Media display name in Satellite |
| `os_family` | string | OS family (`Redhat`, `Debian`, `Suse`, etc.) |
| `path` | string | URL or path to the installation tree |
| `organization` | string | Satellite organization |
| `location` | string | Satellite location |

---

## role_filters_all.yml — Satellite RBAC Role Permission Reference

A complete reference of all Satellite RBAC permissions organized by resource type. Used to construct custom Satellite roles.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `role_filters_all` | list of dict | — | Permission definitions grouped by resource type | satellite_roles role |

**`role_filters_all` entry schema:**

| Key | Type | Description |
|---|---|---|
| `resource_type` | string | Satellite resource type (e.g. `"Host"`, `"Repository"`, `"AnsibleRole"`, or `"None"` for global permissions) |
| `permissions` | list of string | List of permission names for this resource type |

---

## user_group_role.yml.j2 — Users, Groups, and Roles (Jinja2)

Satellite users, user groups, external IdM group mappings, and custom role definitions. This file is Jinja2 (`.j2`).

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `satellite_users` | list of dict | — | Local Satellite user definitions | satellite_users role |
| `satellite_groups` | list of dict | — | Satellite user group definitions with role and external group mappings | satellite_groups role |
| `satellite_roles` | list of dict | — | Custom Satellite role definitions with associated filter sets | satellite_roles role |

**`satellite_users` entry schema:**

| Key | Type | Description |
|---|---|---|
| `name` | string | Username |
| `firstname` | string | First name |
| `lastname` | string | Last name |
| `email` | string | Email address |
| `description` | string | Description |
| `admin` | string | `"true"` or `"false"` — grant admin rights |
| `user_password` | string | Initial password (use vault for production) |
| `default_location` | string | Default Satellite location |
| `default_organization` | string | Default Satellite organization |
| `auth_source` | string | `"Internal"` or `"External"` |
| `timezone` | string | User timezone |
| `locale` | string | UI locale |
| `locations` | list of string | Locations the user has access to |
| `organizations` | list of string | Organizations the user has access to |
| `state` | string | `present` or `absent` |

---

## Settings Files

Satellite settings are organized into category-specific files, each containing a `settings_<category>` list of setting dictionaries. The structure is identical across all categories.

**Settings files present (same as primary satellite):**
`settings_general.yml`, `settings_content.yml`, `settings_provisioning.yml`, `settings_email.yml`, `settings_discovery.yml`, `settings_remote_execution.yml`, `settings_ansible.yml`, `settings_authentication.yml`, `settings_rhcloud.yml`, `settings_template_sync.yml`, `settings_boot_disk.yml`, `settings_config_management.yml`, `settings_facts.yml`, `settings_notifications.yml`, `settings_tasks.yml`

**Common setting entry schema (all categories):**

| Key | Type | Description |
|---|---|---|
| `name` | string | Setting identifier (Satellite internal name, e.g. `"administrator"`) |
| `id` | string | Setting ID (usually same as `name`) |
| `full_name` | string | Human-readable label |
| `description` | string | Setting description |
| `settings_type` | string | Data type: `"string"`, `"boolean"`, `"integer"`, `"array"`, or `null` |
| `value` | any | Value to apply |
| `category` | string | Internal category key |
| `category_name` | string | Human-readable category |
| `readonly` | bool | Whether the setting can be changed |
| `encrypted` | bool | Whether the value is stored encrypted |
| `hidden_value` | bool | Hide value in UI (optional) |
| `config_file` | string | Related config file (or `null`) |
| `select_values` | list | Allowed values (or `null`) |
| `updated_at` | string | Last update timestamp (informational) |

**Notable discosatellite settings differences from primary satellite:**

In `settings_content.yml`:
- `default_download_policy`: `"immediate"` (both; required for export compatibility)
- `default_redhat_download_policy`: `"on_demand"` (both)
- `pulpcore_export_destination`: `/var/lib/pulp/exports` (both)
- `default_export_format`: `"importable"` (both)
- `unregister_delete_host`: `true` (both)
