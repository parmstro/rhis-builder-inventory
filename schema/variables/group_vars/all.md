# Group: all — Global Variables

Schema Version: 1.0.0

These variables apply to every host in the inventory. They establish the global domain identity, network topology, and time configuration for the entire RHIS deployment. `main.yml.j2` is a Jinja2 template rendered per deployment by `inventory_update.yml`.

> **Image Builder variables** (`osbuild_config_dir`, `osbuild_toml_dir`, `repo_file`, `target_activationkey`, `target_organization`, `target_arch`, `target_cloud_repos`) are defined in `group_vars/imagebuilders/imagebuilder_build.yml` — see [imagebuilders.md](imagebuilders.md).

> **Async control variables** (`async_timeout`, `async_delay`) are not set globally. Each consuming project defines its own role-level defaults: `rhis-builder-idm` (`idm_pre/defaults/main.yml`), `rhis-builder-kvm` (`kvm_host/defaults/main.yml`), `rhis-builder-satellite` (`satellite_pre/defaults/main.yml`). This prevents a single global value from overriding per-project timeout requirements (Satellite installation requires a significantly longer timeout than a system update).

---

## Release Versions (`inventory_basevars.yml`)

User-supplied version pins for the major platform components. Changing a value here propagates automatically to all repository IDs, package selections, and content view definitions that reference these variables — no per-host editing required.

| Variable | Type | Example | Description | Used by |
|---|---|---|---|---|
| `rhis_aap_release_version` | string | `"2.6"` | AAP release version (major.minor). Used to construct AAP repository IDs and activation key references. | rhis-builder-aap, inventory template |
| `rhis_satellite_release_version` | string | `"6.18"` | Satellite product release version (major.minor). Used to construct the Satellite and Satellite Capsule repository IDs on both the primary Satellite and Capsule hosts. | host_vars/satellite, host_vars/discosatellite, host_vars/capsule |
| `rhis_satellite_os_major_version` | string | `"9"` | RHEL major version of the Satellite and Capsule host OS. Used alongside `rhis_satellite_release_version` to construct the correct CDN repository IDs for host bootstrapping. | host_vars/satellite, host_vars/discosatellite, host_vars/capsule |

---

## Global Domain Identity (`main.yml.j2` — computed from `basevars_global_domain_name`)

Internal computed aliases for the deployment's primary DNS domain. These are set by the Jinja2 template from the user-supplied `basevars_global_domain_name` value in `inventory_basevars.yml`.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `_runtime_global_domain_name` | string | `"{{ basevars_global_domain_name }}"` | Internal alias for the deployment's DNS domain name (e.g. `example.ca`). Used as the authoritative domain reference throughout all role variable bindings. | All phases |

---

## Network Topology (`main.yml.j2`)

Internal computed network identifiers derived from user-supplied CIDR/prefix values in `inventory_basevars.yml`. All `_default_*` prefixed values are internal and consumed by role variable bindings lower in this same file.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `_default_network` | string | `"{{ default_network \| first 3 octets }}"` | Network address (first three octets) of the primary provisioning network, derived from `default_network`. | All phases |
| `_default_network_prefix` | string | `"{{ default_network_prefix }}"` | CIDR prefix length of the primary provisioning network. | All phases |
| `_default_network_mask` | string | `"{{ default_network_mask }}"` | Subnet mask of the primary provisioning network. | All phases |
| `_default_bond_network` | string | `"{{ default_bond_network \| first 3 octets }}"` | Network address (first three octets) of the bonded network interface subnet. | rhis-builder-satellite, baremetal provisioning phases |
| `_default_bond_network_prefix` | string | `"{{ default_bond_network_prefix }}"` | CIDR prefix length of the bonded network subnet. | rhis-builder-satellite, baremetal provisioning phases |
| `_default_bond_network_mask` | string | `"{{ default_bond_network_mask }}"` | Subnet mask of the bonded network subnet. | rhis-builder-satellite, baremetal provisioning phases |

---

## Time Synchronization (`main.yml.j2`)

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `_default_timeservers` | list | derived from `rhis_time_servers` | List of NTP server hostnames or addresses, populated from the `rhis_time_servers` list in `inventory_basevars.yml`. | All phases |
| `timeserver` | list | `"{{ _default_timeservers }}"` | Alias for `_default_timeservers` consumed by chrony/NTP configuration roles. | rhis-builder-satellite, rhis-builder-idm, rhis-builder-aap |

---

## Satellite — Core Connection (`main.yml.j2`)

Variables used by all phases that communicate with or configure the Satellite server.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `satellite_fqdn` | string | `"{{ groups['sat_primary'][0] }}"` | Fully qualified domain name of the primary Satellite server, resolved from the inventory group. | All phases |
| `satellite_domain` | string | `"{{ _runtime_global_domain_name }}"` | DNS domain associated with the Satellite server. | rhis-builder-satellite |
| `satellite_initial_location` | string | `"Default Location"` | Satellite location created during initial setup. | rhis-builder-satellite |
| `satellite_initial_organization` | string | `"Default Organization"` | Satellite organization created during initial setup. | rhis-builder-satellite |
| `satellite_organization` | string | `"{{ satellite_initial_organization }}"` | Active Satellite organization used for all subsequent operations. | All phases |
| `satellite_location` | string | `"{{ satellite_initial_location }}"` | Active Satellite location used for all subsequent operations. | All phases |
| `satellite_url` | string | `"https://{{ satellite_fqdn }}"` | Base URL of the Satellite API. | All phases |
| `satellite_server_url` | string | `"{{ satellite_url }}"` | Deprecated alias for `satellite_url`. Kept for backwards compatibility with older collection roles. | All phases (deprecated) |
| `satellite_validate_certs` | bool | `false` | Whether to validate the Satellite TLS certificate. Set to `false` during bootstrap before a trusted cert is in place. | All phases |
| `satellite_use_gssapi` | bool | `false` | Whether to use Kerberos/GSSAPI authentication for Satellite API calls. | All phases |

---

## Satellite — Compute and Discovery (`main.yml.j2`)

Variables controlling virtual machine provisioning and bare-metal host discovery through Satellite.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `vm_compute_resource` | string | `"vcenter.{{ _runtime_global_domain_name }}"` | Name of the Satellite compute resource entry for vCenter, used when provisioning virtual machines. | rhis-builder-satellite, VM provisioning phases |
| `search_dh_mac` | string | `"ff:ff:ff:ff:ff:ff"` | Placeholder MAC address used in Satellite DHCP record searches. Broadcast MAC indicates a wildcard/no-filter search. | rhis-builder-satellite |
| `default_vm_mac` | string | `"00:50:56:ff:ff:ff"` | OUI prefix used to identify VMware-provisioned virtual machines in Satellite host searches. | rhis-builder-satellite, VM provisioning phases |
| `post_deploy_timeout` | int | `600` | Seconds to wait for a host to become reachable after Satellite triggers a deployment. | rhis-builder-satellite, provisioning phases |
| `use_sync_build` | bool | `false` | When `true`, forces synchronous (blocking) host builds rather than async. Async is the default for performance. | rhis-builder-satellite, provisioning phases |
| `discovered_hosts_resource` | string | `"discovered_hosts"` | Satellite compute resource name used to search for discovered (PXE-booted, not yet provisioned) hosts. | rhis-builder-satellite (bare-metal discovery) |
| `discovered_hosts_search` | string | `"disk_count = 1 and memory > 32000"` | Satellite search filter applied when selecting discovered hosts to provision. Matches bare-metal nodes with one disk and at least 32 GB RAM. | rhis-builder-satellite (bare-metal discovery) |
| `discovered_host_req_nic_count` | int | `1` | Minimum number of non-loopback NICs a discovered host must have. The comparison is strictly greater-than this value. | rhis-builder-satellite (bare-metal discovery) |
| `host_build_comment` | string | `"Created by rhis-builder"` | Comment string stamped on Satellite host records created by automation. | All provisioning phases |
| `deploy` | bool | `true` | Master switch that controls whether Satellite actually triggers a host deployment. Set to `false` for dry-run/validation passes. | rhis-builder-satellite, provisioning phases |

---

## Network Interface Defaults (`main.yml.j2`)

Default interface names and subnet identifiers used when defining Satellite subnets and building host network configurations.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `_default_domain` | string | `"{{ _runtime_global_domain_name }}"` | Internal alias for the DNS domain, used in Satellite domain and subnet definitions. | rhis-builder-satellite |
| `_default_subnetname` | string | `"{{ _runtime_global_domain_name }}"` | Name of the primary Satellite subnet record, defaulting to the domain name. | rhis-builder-satellite |
| `_default_provision_iface` | string | `"eno1"` | Default provisioning network interface name for physical (bare-metal) hosts. | rhis-builder-satellite, baremetal provisioning |
| `_default_vm_provision_iface` | string | `"ens192"` | Default provisioning network interface name for VMware virtual machines. | rhis-builder-satellite, VM provisioning |
| `_default_bond_subnetname` | string | `"bond_subnet"` | Name of the Satellite subnet record for the bonded network. | rhis-builder-satellite |
| `_default_bond_subnet_prefix` | int | `23` | CIDR prefix length for the bond subnet (overrides the value derived from `_default_bond_network_prefix` for Satellite record creation). | rhis-builder-satellite |
| `_default_bond_default_gateway` | string | `"{{ _default_network }}.1"` | Default gateway for the bonded network interface. Uses `_default_network` (provision network prefix) rather than `_default_bond_network` intentionally — the bond address range is coincident with the provision network and both reside in the same physical subnet sharing the same gateway. Will be revisited as part of the general network address rework. | rhis-builder-satellite, baremetal provisioning |
| `_default_bond_iface` | string | `"bond0"` | Logical bond interface name on bare-metal hosts. | rhis-builder-satellite, baremetal provisioning |
| `_default_child_iface1` | string | `"enp2s0f0"` | First physical interface enslaved to `bond0`. | rhis-builder-satellite, baremetal provisioning |
| `_default_child_iface2` | string | `"enp2s0f1"` | Second physical interface enslaved to `bond0`. | rhis-builder-satellite, baremetal provisioning |

---

## IdM — Domain and Realm Identity (`main.yml.j2`)

Aliased domain/realm variables required by the `redhat.rhel_idm` collection roles. Multiple variable names exist because the collection's `ipaserver`, `ipareplica`, and `ipaclient` roles use different naming conventions; all resolve to the same domain.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `ipa_server_domain` | string | `"{{ _runtime_global_domain_name }}"` | IdM domain name; used by `ipaserver` role and custom tasks. | rhis-builder-idm |
| `ipaserver_domain` | string | `"{{ _runtime_global_domain_name }}"` | IdM domain name; canonical variable name for the `redhat.rhel_idm.ipaserver` role. | rhis-builder-idm |
| `ipa_domain` | string | `"{{ _runtime_global_domain_name }}"` | IdM domain name; generic alias used across multiple roles and playbooks. | All phases |
| `ipa_server_realm` | string | `"{{ _runtime_global_domain_name \| upper }}"` | Kerberos realm name (uppercased domain); used by `ipaserver` role and custom tasks. | rhis-builder-idm |
| `ipaserver_realm` | string | `"{{ _runtime_global_domain_name \| upper }}"` | Kerberos realm name; canonical variable for the `redhat.rhel_idm.ipaserver` role. | rhis-builder-idm |
| `ipa_realm` | string | `"{{ _runtime_global_domain_name \| upper }}"` | Kerberos realm name; generic alias. | All phases |
| `ipa_server_fqdn` | string | `"{{ groups['idm_primary'][0] }}"` | FQDN of the primary IdM server, resolved from the inventory group. | All phases |
| `ipaserver_fqdn` | string | `"{{ groups['idm_primary'][0] }}"` | FQDN of the primary IdM server; canonical variable for the `redhat.rhel_idm.ipaserver` role. | rhis-builder-idm |

---

## IdM — Replica Identity (`main.yml.j2`)

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `ipareplicas` | list | `"{{ groups['ipa_replicas'] }}"` | List of IdM replica FQDNs, resolved from the inventory group. Passed to topology management roles. | rhis-builder-idm |
| `ipareplica_domain` | string | `"{{ _runtime_global_domain_name }}"` | Domain name passed to the `redhat.rhel_idm.ipareplica` role. | rhis-builder-idm |

---

## IdM — Client Configuration (`main.yml.j2`)

Variables consumed by the `redhat.rhel_idm.ipaclient` role when enrolling any host into the IdM domain.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `ipa_client_dns_servers` | string | `"{{ target_net_cidr \| ansible.utils.next_nth_usable(10) }}"` | IP address of the IdM DNS server, computed as the 10th usable host in the target network CIDR (rendered outside `{% raw %}` block so the filter is evaluated at template time). | All phases (client enrollment) |
| `ipaclient_dns_servers` | string | `"{{ ipa_client_dns_servers }}"` | Alias for `ipa_client_dns_servers`; canonical variable for the `ipaclient` role. | rhis-builder-idm, All phases (client enrollment) |
| `ipa_client_domain` | string | `"{{ _runtime_global_domain_name }}"` | DNS domain passed to the `ipaclient` role during enrollment. | All phases (client enrollment) |
| `ipaclient_domain` | string | `"{{ ipa_server_domain }}"` | Canonical `ipaclient` role variable for the client's domain. | rhis-builder-idm, All phases (client enrollment) |
| `ipaclient_realm` | string | `"{{ ipa_server_domain \| upper }}"` | Kerberos realm for the enrolling client; canonical `ipaclient` role variable. | rhis-builder-idm, All phases (client enrollment) |
| `ipa_client_configure_dns_resolver` | bool | `true` | Whether to configure the host's DNS resolver to point at the IdM DNS server after enrollment. | All phases (client enrollment) |
| `ipaclient_configure_dns_resolver` | bool | `"{{ ipa_client_configure_dns_resolver }}"` | Canonical `ipaclient` role alias for `ipa_client_configure_dns_resolver`. | rhis-builder-idm, All phases (client enrollment) |
| `ipa_client_mkhomedir` | bool | `true` | Whether to configure PAM to create home directories for IdM users on first login. | All phases (client enrollment) |
| `ipaclient_mkhomedir` | bool | `"{{ ipa_client_mkhomedir }}"` | Canonical `ipaclient` role alias for `ipa_client_mkhomedir`. | rhis-builder-idm, All phases (client enrollment) |
| `ipasssd_enable_dns_updates` | bool | `true` | Enables SSSD to perform dynamic DNS updates for the enrolled host's A record. | All phases (client enrollment) |
| `ipaclient_force_join` | bool | `true` | Forces re-enrollment of a host even if it is already registered, used when rebuilding Satellite without rebuilding IdM. | rhis-builder-satellite, All phases (client enrollment) |

---

## IdM — Credentials (`main.yml.j2`)

Non-vault aliases that reference vault variables. Documented here to show the variable names consumed by roles; actual secrets are in the vault file.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `ipa_dm_password` | string | `"{{ ipa_dm_password_vault }}"` | IdM Directory Manager password alias. | rhis-builder-idm |
| `ipadm_password` | string | `"{{ ipa_dm_password }}"` | Canonical `redhat.rhel_idm` role alias for the Directory Manager password. | rhis-builder-idm |
| `ipa_admin_password` | string | `"{{ ipa_admin_password_vault }}"` | IdM `admin` user password alias used by custom playbooks. | rhis-builder-idm, All phases |
| `ipaadmin_password` | string | `"{{ ipa_admin_password_vault }}"` | Canonical `redhat.rhel_idm` role alias for the admin password. | rhis-builder-idm, All phases |
| `ipa_password` | string | `"{{ ipa_password_vault }}"` | Generic IdM password alias for contexts where neither `dm` nor `admin` is explicitly distinguished. | All phases |
| `ipa_admin_principal` | string | `"{{ ipa_admin_principal_vault }}"` | IdM admin Kerberos principal name (e.g. `admin`), alias used by custom playbooks. | rhis-builder-idm, All phases |
| `ipaadmin_principal` | string | `"{{ ipa_admin_principal_vault }}"` | Canonical `redhat.rhel_idm` role alias for the admin principal. | rhis-builder-idm, All phases |
| `ipa_principal` | string | `"{{ ipa_principal_vault }}"` | Generic IdM principal alias. | All phases |
| `ipa_default_user_password` | string | `"{{ ipa_default_user_password_vault }}"` | Initial password assigned to new IdM user accounts created by automation. | rhis-builder-idm |

---

## PKI — Certificate Generation (`main.yml.j2`)

Variables that control TLS certificate and key generation for hosts integrated into the IdM CA. Certificates are placed in `crt_dir` and also optionally deployed to Cockpit.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `force_regen` | bool | `true` | When `true`, always regenerates certificates even if they already exist. Useful during rebuilds. | rhis-builder-idm, rhis-builder-satellite, rhis-builder-aap |
| `crt_dir` | string | `"/etc/ipa/private"` | Base directory for all generated certificate and key files. | All phases (cert management) |
| `private_crt_dir` | string | `"{{ crt_dir }}"` | Alias for `crt_dir`; used in roles that reference the private key storage path separately. | All phases (cert management) |
| `passfile` | string | `"{{ private_crt_dir }}/passout.txt"` | Path to the file storing the private key passphrase during key generation. **This file is transient** — the certificate generation code always removes it after use. It is never present on a fully provisioned host. | All phases (cert management) |
| `ssl_private_key_pem_path` | string | `"{{ crt_dir }}/{{ ansible_fqdn }}.pem"` | Path to the host's PEM-encoded private key file. | All phases (cert management) |
| `ssl_private_key_path` | string | `"{{ crt_dir }}/{{ ansible_fqdn }}.key"` | Path to the host's private key file (traditional format). | All phases (cert management) |
| `ssl_private_key_cipher` | string | `"aes256"` | Cipher used to encrypt the private key at rest. Default will change to a PQC cipher when stable implementations are supported across all relevant components. | All phases (cert management) |
| `ssl_private_key_size` | int | `4096` | RSA key size in bits. Default will change when PQC key types are broadly supported. | All phases (cert management) |
| `ssl_public_key_path` | string | `"{{ crt_dir }}/{{ ansible_fqdn }}.pub"` | Path to the host's public key file. | All phases (cert management) |
| `ssl_public_key_format` | string | `"PEM"` | Encoding format for the public key file. | All phases (cert management) |
| `csr_path` | string | `"{{ crt_dir }}/{{ ansible_fqdn }}.csr"` | Path where the Certificate Signing Request (CSR) is written. | All phases (cert management) |
| `csr_email_address` | string | `"parmstro@{{ _runtime_global_domain_name }}"` | Email address embedded in the CSR subject. Should be updated to reflect the actual admin contact. | All phases (cert management) |
| `csr_organization_name` | string | `"Paul Armstrong"` | Organization name embedded in the CSR subject. | All phases (cert management) |
| `csr_organization_unit_name` | string | `"Red Lab"` | Organizational unit embedded in the CSR subject. | All phases (cert management) |
| `csr_country_name` | string | `"CA"` | Two-letter ISO country code embedded in the CSR subject. | All phases (cert management) |
| `csr_state_or_province_name` | string | `"ON"` | Province or state name embedded in the CSR subject. | All phases (cert management) |
| `csr_locality_name` | string | `"Cambridge"` | City/locality embedded in the CSR subject. | All phases (cert management) |
| `csr_digest` | string | `"aes256"` | Digest algorithm used when signing the CSR. | All phases (cert management) |
| `crt_service_type` | string | `"HTTP"` | Kerberos service type used when requesting a certificate from the IdM CA (e.g. `HTTP/host.domain`). | rhis-builder-idm, rhis-builder-satellite, rhis-builder-aap |
| `ssl_crt_path` | string | `"{{ crt_dir }}/{{ ansible_fqdn }}.crt"` | Path to the signed certificate file issued by the IdM CA. | All phases (cert management) |
| `create_crt_key_bundle` | bool | `false` | When `true`, creates a combined certificate+key bundle file for services that require it (e.g. Cockpit). | rhis-builder-aap, Cockpit configuration |
| `crt_key_bundle_path` | string | `"{{ crt_dir }}/{{ ansible_fqdn }}.cockpit.cert"` | Path to the combined certificate+key bundle file. Only used when `create_crt_key_bundle` is `true`. | Cockpit configuration |
| `cockpit_crt_path` | string | `"/etc/cockpit/ws-certs.d/z-{{ ansible_fqdn }}.cockpit.crt"` | Destination path for the Cockpit TLS certificate. | Cockpit configuration |
| `cockpit_key_path` | string | `"/etc/cockpit/ws-certs.d/z-{{ ansible_fqdn }}.cockpit.key"` | Destination path for the Cockpit TLS private key. | Cockpit configuration |
| `cockpit_bundle_path` | string | `"/etc/cockpit/ws-certs.d/z-{{ ansible_fqdn }}.cockpit.cert"` | Destination path for the Cockpit combined cert+key bundle. | Cockpit configuration |
| `cockpit_self_ca_crt` | string | `"/etc/cockpit/ws-certs.d/0-self-signed-ca.pem"` | Path to the Cockpit self-signed CA certificate (present before IdM CA cert is deployed; used as a reference for cleanup). | Cockpit configuration |
| `cockpit_self_crt` | string | `"/etc/cockpit/ws-certs.d/0-self-signed.cert"` | Path to the Cockpit self-signed certificate (replaced by the IdM-issued cert). | Cockpit configuration |
| `ssl_private_key_passphrase` | string | `"{{ ssl_private_key_passphrase_vault }}"` | Passphrase protecting the generated private key; sourced from vault. | All phases (cert management) |

---

## IdM — Replication Topology (`main.yml.j2`)

Variables and data structures that define how IdM replication agreements are wired between the primary server and replicas. The topology selector uses a lookup table (`idm_standard_topologies`) indexed by a computed value derived from `idmreplica_fault_level`.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `idmreplica_fault_level_max` | int | `2` | Upper bound for `idmreplica_fault_level`. Guards against requesting a topology that does not exist in the lookup table. | rhis-builder-idm |
| `idmreplica_fault_level` | int | `2` | Number of simultaneous replica failures the topology must survive without losing replication. Drives the topology graph selection. | rhis-builder-idm |
| `idm_standard_topologies` | list of maps | see below | Lookup table of named topology graphs. Each entry specifies a `name`, an `index` (nodes × fault-level), and a list of `segments` defining replication agreements. Topology graphs supported: `two_node` (index 2), `three_node` (index 3), `four_node_box` (index 4), `four_node_box_x` (index 8), `six_node_geo` (index 9, experimental). | rhis-builder-idm |

Each entry in `idm_standard_topologies` has this structure:

| Field | Type | Description |
|---|---|---|
| `name` | string | Human-readable topology name. |
| `index` | int | Topology index (node count × fault level) used to select this entry. |
| `segments` | list of maps | Replication agreement definitions. Each segment has `left` (int, node index), `right` (int, node index), `state` (`"present"`/`"absent"`), and `suffix` (e.g. `"domain+ca"`). |
