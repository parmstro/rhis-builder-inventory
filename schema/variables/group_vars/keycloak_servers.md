# Group: keycloak_servers — Keycloak Variables

Schema Version: 1.0.0

These variables configure Red Hat Build of Keycloak (RHBK) identity and access management servers. Keycloak is used as an SSO provider in environments that require it alongside or instead of IdM.

> **Note:** The current RHIS Keycloak implementation is intentionally basic. It is strictly focused on deployment — getting a functional RHBK instance installed — and does not yet include post-deployment realm, client, or federation configuration. The implementation will be extended over time.

Upstream collection: `middleware_automation.keycloak` — refer to the [collection documentation](https://ansible-middleware.github.io/keycloak/) for authoritative variable references.

---

## Source Files

| File | Format |
|---|---|
| `group_vars/keycloak_servers/main.yml.j2` | Jinja2 template (rendered to YAML per deployment) |
| `group_vars/keycloak_servers/valid_configs.yml` | YAML |

---

## Keycloak Installation

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `keycloak_admin_username` | string | `"admin"` | Username for the Keycloak administrative console account. | Keycloak installation and configuration |
| `keycloak_install_version` | string | `"26.0"` | Version of Keycloak (or Red Hat build of Keycloak) to install. Must match a supported combination in `keycloak_valid_configs`. | Keycloak installation role |
| `keycloak_postgresql_install_version` | string | `"16"` | PostgreSQL major version to install as the Keycloak backing database. Must match a supported combination in `keycloak_valid_configs`. | Keycloak database setup |
| `keycloak_openjdk_install_version` | string | `"21"` | OpenJDK major version to install as the Keycloak Java runtime. Must match a supported combination in `keycloak_valid_configs`. | Keycloak installation role |
| `keycloak_local_user` | string | `"keycloak"` | Local system user account under which the Keycloak service process runs. | Keycloak service setup |
| `keycloak_db_user` | string | `"keycloakuser"` | PostgreSQL database user created for Keycloak's database connection. | Keycloak database setup |
| `keycloak_install_dir` | string | `"/opt/{{ keycloak_installer_info.keycloak_installer_version }}"` | Absolute path where Keycloak is installed on the host. Derived from `keycloak_installer_info.keycloak_installer_version`. | Keycloak installation and fapolicyd trust |

---

## Keycloak Installer Info

`keycloak_installer_info` is a mapping that groups installer metadata.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `keycloak_installer_info.keycloak_product` | string | `"Red Hat build of Keycloak"` | Human-readable product name used in logging and documentation. | Keycloak installation role |
| `keycloak_installer_info.keycloak_file_repo_name` | string | `"keycloak_files"` | Name of the file repository (e.g., on Satellite or a local file server) from which the Keycloak installer archive is fetched. | Keycloak installation role |
| `keycloak_installer_info.keycloak_destination_dir` | string | `"/opt"` | Parent directory under which Keycloak is extracted. The versioned subdirectory (`keycloak_installer_version`) is created inside this path. | Keycloak installation role |
| `keycloak_installer_info.keycloak_installer_version` | string | `"rhbk-26.0.14"` | Versioned directory name for the Keycloak installation. Determines the value of `keycloak_install_dir`. | Keycloak installation role |

---

## Satellite / RHSM Registration

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `register_satellite` | boolean | `true` | When `true`, registers the host with Satellite (or any RHSM target) using the activation keys listed in `satellite_activation_keys`. | System registration role |
| `satellite_activation_keys` | list of strings | `["SOE9_Keycloak_dev"]` | One or more Satellite or RHSM activation keys applied when registering the host. | System registration role |

---

## Upstream (Non-Satellite) Installer URL

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `keycloak_zipfile_upstream_url` | string | `"https://github.com/keycloak/keycloak/releases/download/26.0.8/keycloak-26.0.8.tar.gz"` | Direct download URL for the upstream Keycloak archive. Used only in non-Satellite environments where the installer cannot be fetched from a file repository. | Keycloak installation role (non-Satellite path) |

---

## fapolicyd Integration

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `fapolicyd_setup_enable_service` | boolean | `true` | Enables and starts the `fapolicyd` service after configuration. | `fapolicyd` role |
| `fapolicyd_setup_integrity` | string | `"sha256"` | File integrity algorithm used by `fapolicyd` when validating executables. | `fapolicyd` role |
| `fapolicyd_setup_trust` | string | `"rpmdb,file"` | Comma-separated trust sources that `fapolicyd` consults when deciding whether to permit execution. | `fapolicyd` role |
| `fapolicyd_add_trusted_file` | list of strings | `["{{ keycloak_install_dir }}"]` | Paths added to the `fapolicyd` trust database so that Keycloak binaries are permitted to execute. | `fapolicyd` role |

---

## Firewall Configuration

`firewalld_services` and `firewalld_ports` are lists of firewall rule mappings. Each entry shares the same keys.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `firewalld_services` | list of mappings | HTTPS and PostgreSQL services enabled in the `public` zone | Named firewalld services to open. Each entry has `service`, `permanent`, `immediate`, `zone`, and `state` keys. | `firewalld` role |
| `firewalld_ports` | list of mappings | Port `8080/tcp` (Keycloak HTTP) and `7800/udp` (JGroups clustering) enabled in the `public` zone | Explicit port/protocol pairs to open. Each entry has `port`, `permanent`, `immediate`, `zone`, and `state` keys. | `firewalld` role |

---

## IdM Client Registration

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `register_idm` | boolean | `true` | When `true`, enrolls the host as an IdM/IPA client. | IdM client role |
| `ipaclient_domain` | string | `"{{ _runtime_global_domain_name }}"` | DNS domain name of the IdM realm. Derived from the global `_runtime_global_domain_name` computed variable. | IdM client role |
| `ipaclient_mkhomedir` | boolean | `true` | When `true`, automatically creates home directories for IdM users on first login via PAM. | IdM client role |
| `ipaclient_ntp_servers` | list of strings | Rendered from `rhis_time_servers` at template time | NTP server addresses configured on the IdM client. Populated by iterating `rhis_time_servers` during Jinja2 rendering. | IdM client role |

---

## IdM Certificate Management

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `certificates_idm` | boolean | `true` | When `true`, certificates are requested from the IdM CA rather than from an external source. Set to `false` to use manually provided certificate paths instead. | Certificate management role |
| `ipa_server_fqdn` | string | `"{{ groups['idm_primary'][0] }}"` | FQDN of the primary IdM server used as the certificate authority endpoint. | Certificate management role |
| `force_regen` | boolean | `true` | When `true`, forces certificate regeneration even if a valid certificate already exists on the host. | Certificate management role |
| `ssl_private_key_cipher` | string | `"aes256"` | Cipher algorithm used to encrypt the generated private key. | Certificate management role |
| `ssl_private_key_size` | integer | `2048` | RSA key size in bits for the generated private key. | Certificate management role |
| `csr_email_address` | string | `"bobsurunkle@{{ _runtime_global_domain_name }}"` | Email address embedded in the Certificate Signing Request (CSR). Should be updated to a real address for production deployments. | Certificate management role |
| `csr_organization_name` | string | `"Bob Surunkle"` | Organization name embedded in the CSR. Should be updated for production deployments. | Certificate management role |
| `csr_organization_unit_name` | string | `"Surunkle Lab"` | Organizational unit name embedded in the CSR. Should be updated for production deployments. | Certificate management role |
| `csr_country_name` | string | `"CA"` | Two-letter ISO 3166-1 country code embedded in the CSR. | Certificate management role |
| `csr_state_or_province_name` | string | `"ON"` | State or province name embedded in the CSR. | Certificate management role |
| `csr_locality_name` | string | `"Cambridge"` | Locality (city) name embedded in the CSR. | Certificate management role |
| `csr_digest` | string | `"aes256"` | Digest algorithm used when signing the CSR. | Certificate management role |
| `crt_dir` | string | `"/etc/ipa/private"` | Directory on the host where generated certificates and keys are stored. | Certificate management role |
| `passfile` | string | `"{{ crt_dir }}/passout.txt"` | Path to the file that stores the private key passphrase, used during certificate operations. | Certificate management role |
| `ssl_private_key_pem_path` | string | `"{{ crt_dir }}/{{ ansible_fqdn }}.pem"` | Path to the PEM-encoded private key file for the host. | Certificate management role |
| `ssl_private_key_path` | string | `"{{ crt_dir }}/{{ ansible_fqdn }}.key"` | Path to the private key file consumed by Keycloak's TLS configuration. | Certificate management role, Keycloak TLS |
| `ssl_public_key_path` | string | `"{{ crt_dir }}/{{ ansible_fqdn }}.pub"` | Path to the public key file derived from the private key. | Certificate management role |
| `ssl_public_key_format` | string | `"PEM"` | Encoding format of the public key file. | Certificate management role |
| `csr_path` | string | `"{{ crt_dir }}/{{ ansible_fqdn }}.csr"` | Path to the Certificate Signing Request file generated during enrollment. | Certificate management role |
| `crt_service_type` | string | `"HTTP"` | Kerberos service principal type used when requesting the certificate from the IdM CA (e.g., `HTTP` maps to `HTTP/<fqdn>@REALM`). | Certificate management role |
| `ssl_crt_path` | string | `"{{ crt_dir }}/{{ ansible_fqdn }}.crt"` | Path to the signed certificate file consumed by Keycloak's TLS configuration. | Certificate management role, Keycloak TLS |

---

## Valid Configuration Matrix

Defined in `valid_configs.yml`. The `keycloak_valid_configs` list enumerates supported combinations of Keycloak, PostgreSQL, and OpenJDK versions. Playbooks should validate that the chosen `keycloak_install_version`, `keycloak_postgresql_install_version`, and `keycloak_openjdk_install_version` values appear together in this list before proceeding.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `keycloak_valid_configs` | list of mappings | Three entries (26.2/PG17/JDK21, 26.0/PG16/JDK21, 24.0/PG16/JDK17) | Enumerated valid combinations of `keycloak_version`, `postgresql_version`, and `openjdk_version`. Each mapping has exactly those three keys. | Pre-flight validation tasks |
