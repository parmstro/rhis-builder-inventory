# Group: idm_replicas — IdM Replica Variables

Schema Version: 1.0.0

These variables configure IdM replica servers. Replicas provide high availability for the IdM domain and are deployed after the primary IdM server is operational.

Upstream collection: `redhat.rhel_idm` — refer to the [collection documentation](https://console.redhat.com/ansible/automation-hub/repo/published/redhat/rhel_idm/) for authoritative variable references.

---

## Pre-Installation Setup (`idm_pre_vars.yml`)

Variables applied before the IdM replica packages are installed. These control host registration, repository enablement, firewall configuration, and DNS resolver bootstrapping — all of which must be in place before the `ipareplica` role runs.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `rhc_insights_state` | string | `"absent"` | Controls whether Red Hat Insights is registered on replica hosts. `"absent"` disables and removes the Insights connection; set to `"present"` to enable. | rhis-builder-idm (pre-install phase) |
| `rhc_enable_auto_update` | bool | `false` | Whether to enable the `rhcd` auto-update feature during Satellite registration. Disabled by default to prevent unexpected package upgrades during deployment. | rhis-builder-idm (pre-install phase) |
| `repository_ids` | list | RHEL BaseOS, AppStream, Supplementary, Satellite Client RPMs (version-dynamic) | List of Satellite/CDN repository IDs to enable on replica hosts during pre-installation. Uses `ansible_distribution_major_version` to target the correct RHEL major version. | rhis-builder-idm (pre-install phase) |
| `idm_pre_dns_resolvers` | list | `["8.8.8.8", "8.8.4.4"]` | Temporary DNS resolver addresses configured on replica hosts before IdM DNS is operational. Replace with internal resolvers if the deployment network does not have public internet access. | rhis-builder-idm (pre-install phase) |
| `ipa_firewalld_zone` | string | `"public"` | Firewalld zone to which IdM-related firewall rules are applied. | rhis-builder-idm (pre-install phase) |
| `ipa_prime_interface` | string | dynamically computed | The network interface carrying the host's default IPv4 address, determined at runtime by filtering `ansible_interfaces` for the interface whose address matches `ansible_default_ipv4.address`. Used to bind firewall rules to the correct interface. | rhis-builder-idm (pre-install phase) |
| `ipa_firewalld_services` | list | `["freeipa-4", "freeipa-ldap", "freeipa-ldaps", "freeipa-replication", "freeipa-trust"]` | Firewalld service names to open on replica hosts. Covers LDAP, LDAPS, replication, and AD trust traffic. | rhis-builder-idm (pre-install phase) |
| `ipa_required_umask` | string | `"0022"` | Required umask for the system during IdM installation. FreeIPA's installer enforces this to ensure correct file permissions on generated configuration files. | rhis-builder-idm (pre-install phase) |
| `ipa_crypto_policy` | string | `"DEFAULT"` | RHEL system-wide crypto policy applied before IdM installation. Supported values: `"DEFAULT"` (standard policy) and `"FIPS"` (FIPS 140 compliant). | rhis-builder-idm (pre-install phase) |
| `etc_hosts_list` | list of maps | Two example entries for `provisioner` and `satellite1` | List of static `/etc/hosts` entries to add on replica hosts before IdM DNS is operational. Each entry has `ip` (string) and `fqdn` (string) keys. Populate with any hosts that must be resolvable before IdM DNS comes up. The default values are illustrative and should be updated per deployment. | rhis-builder-idm (pre-install phase) |

`etc_hosts_list` entry structure:

| Field | Type | Description |
|---|---|---|
| `ip` | string | IPv4 address to map. |
| `fqdn` | string | Fully qualified domain name to resolve to that address. |

---

## Replica Deployment (`idm_replica_setup_vars.yml`)

Variables passed to the `redhat.rhel_idm.ipareplica` role during replica promotion. These control DNS forwarding, optional component installation, and Kerberos realm assignment.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `register_to_satellite` | bool | `true` | Whether to register replica hosts to Satellite before promoting them. When `false`, hosts are assumed to already be registered or will be registered separately. | rhis-builder-idm (replica deployment) |
| `ipareplica_forwarders` | list | `["8.8.8.8", "8.8.4.4"]` | DNS forwarder addresses configured in the IdM replica's BIND instance. Queries not answered by the IdM zone are forwarded to these servers. Replace with internal resolvers as appropriate. | rhis-builder-idm (replica deployment) |
| `ipareplica_forward_policy` | string | `"only"` | DNS forwarding policy for the replica. `"only"` sends all non-local queries exclusively to the configured forwarders; `"first"` tries the IdM zone first and falls back to forwarders. | rhis-builder-idm (replica deployment) |
| `ipareplica_install_packages` | bool | `true` | Whether the `ipareplica` role should install required IdM packages before promoting the host. Set to `false` if packages are pre-installed via a custom task. | rhis-builder-idm (replica deployment) |
| `ipareplica_setup_firewalld` | bool | `false` | Whether the `ipareplica` role should configure firewalld. Set to `false` here because firewall rules are managed in the pre-install phase via `ipa_firewalld_services`. | rhis-builder-idm (replica deployment) |
| `ipareplica_firewalld_zone` | string | `"public"` | Firewalld zone used if `ipareplica_setup_firewalld` is enabled. Kept consistent with `ipa_firewalld_zone`. | rhis-builder-idm (replica deployment) |
| `ipareplica_no_host_dns` | bool | `true` | When `true`, suppresses the pre-check that verifies the host's own FQDN is resolvable via DNS before promotion. Required when the replica is being promoted before IdM DNS propagates its own record. | rhis-builder-idm (replica deployment) |
| `ipareplica_mem_check` | bool | `true` | Enables the IdM installer's memory check. The installer will abort if the host does not meet the minimum RAM requirement. | rhis-builder-idm (replica deployment) |
| `ipareplica_setup_ca` | bool | `true` | Whether to install the IdM Certificate Authority (Dogtag) on the replica. Strongly recommended for HA — without this, CA operations are not distributed across replicas. | rhis-builder-idm (replica deployment) |
| `ipareplica_setup_adtrust` | bool | `true` | Whether to configure the Active Directory Trust component on the replica. Required if cross-forest trust with AD is used or planned. | rhis-builder-idm (replica deployment) |
| `ipareplica_setup_kra` | bool | `true` | Whether to install the Key Recovery Authority (KRA) on the replica. Distributes secret-archival capability for HA. | rhis-builder-idm (replica deployment) |
| `ipareplica_setup_dns` | bool | `true` | Whether to configure BIND/DNS on the replica. Must be `true` for replicas to participate in IdM DNS HA. | rhis-builder-idm (replica deployment) |
| `ipareplica_auto_reverse` | bool | `true` | When `true`, the installer automatically creates reverse DNS zones for all configured IP subnets. | rhis-builder-idm (replica deployment) |
| `ipaclient_realm` | string | `"{{ _runtime_global_domain_name \| upper }}"` | Kerberos realm used during the client-enrollment phase of replica promotion. Overrides the global default here to ensure the replica-specific context is explicit. | rhis-builder-idm (replica deployment) |
| `makehomedir` | bool | `true` | Whether to configure PAM `oddjobd`/`mkhomedir` on the replica so IdM user home directories are created automatically on first login. | rhis-builder-idm (replica deployment) |
| `sshtrustdns` | bool | `true` | When `true`, configures SSHD to trust host key fingerprints published in IdM DNS (SSHFP records), enabling verified SSH connections without manual `known_hosts` entries. | rhis-builder-idm (replica deployment) |

> **Note:** The following variables must NOT be set for replicas — setting any of them causes the `ipareplica` role to fail with `"NTP configuration cannot be updated during promotion"`:
> - `ipaclient_no_ntp`
> - `ipaclient_ntp_servers`
> - `ipaclient_ntp_pool`

---

## Async and Timing (`main_vars.yml`)

Variables that control the asynchronous task behaviour of rhis-builder-idm playbooks. IdM replica promotion is a long-running operation and is executed asynchronously.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `async_timeout` | int | `3600` | Maximum number of seconds an async IdM task (e.g. replica promotion) is allowed to run before being considered failed. 3600 seconds = 1 hour. | rhis-builder-idm |
| `async_delay` | int | `60` | Polling interval in seconds when checking the status of a running async task. | rhis-builder-idm |
