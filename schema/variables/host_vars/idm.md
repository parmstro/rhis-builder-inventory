# Host: idm — Identity Management Variables

Schema Version: 1.0.0

These variables configure the Red Hat Identity Management (IdM / FreeIPA) primary server. IdM provides centralized authentication, authorization, DNS, PKI, and policy management for the entire RHIS infrastructure.

Upstream collection: `redhat.rhel_idm` — refer to the [collection documentation](https://console.redhat.com/ansible/automation-hub/repo/published/redhat/rhel_idm/) for authoritative variable references.

---

## Table of Contents

1. [Behaviour Control (`main_vars.yml`)](#behaviour-control-main_varsyml)
2. [Prerequisites (`prerequisites.yml`)](#prerequisites-prerequisitesyml)
3. [Server Setup (`idm_primary_setup_vars.yml`)](#server-setup-idm_primary_setup_varsyml)
4. [Global Realm Configuration (`idm_global_config.yml`)](#global-realm-configuration-idm_global_configyml)
5. [Directory Server Hardening (`idm_hardening.yml`)](#directory-server-hardening-idm_hardeningyml)
6. [Host Groups (`host_groups.yml`)](#host-groups-host_groupsyml)
7. [Password Policy (`password_policy.yml`)](#password-policy-password_policyyml)
8. [HBAC Policy (`hbac_policy.yml`)](#hbac-policy-hbac_policyyml)
9. [HBAC Policy Tests (`hbac_policy_tests.yml`)](#hbac-policy-tests-hbac_policy_testsyml)
10. [Sudo Policy (`sudo_policy.yml`)](#sudo-policy-sudo_policyyml)
11. [Identity Provider References (`idp_references.yml`)](#identity-provider-references-idp_referencesyml)
12. [DNS Configuration (`dns_configuration.yml.j2`)](#dns-configuration-dns_configurationymlj2)
13. [Automount (`automount.yml.j2`)](#automount-automountymlj2)
14. [Users and Groups (`users_and_groups.yml.j2`)](#users-and-groups-users_and_groupsymlj2)

---

## Behaviour Control (`main_vars.yml`)

Top-level knobs that control how the `rhis-builder-idm` playbook runs. These affect async task timing and diagnostic logging.

> **Note:** The sample configuration provided is intentionally broad. The underlying code supports the full range of configuration allowed by the corresponding `redhat.rhel_idm` module. Users can extend the configuration to meet their specific requirements. To ensure consistent and reproducible builds, update the relevant file directly in `inventory_template` — treat your inventory as code (GitOps).

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `async_timeout` | int | `3600` | Maximum seconds an async task may run before it is considered timed out. | rhis-builder-idm async tasks |
| `async_delay` | int | `60` | Polling interval in seconds when waiting for an async task to complete. | rhis-builder-idm async tasks |
| `main_logging` | bool | `false` | Set to `true` to enable verbose logging across the IdM role. Note: has no effect due to a `no_log` variable interpolation bug (upstream issue [#83323](https://github.com/ansible/ansible/issues/83323)). As of 2026-05-23 this issue persists in ansible-core 2.20 and remains open upstream. | rhis-builder-idm roles |

---

## Prerequisites (`prerequisites.yml`)

Configures the host state required before IdM installation: subscription/repository enablement, time synchronisation, firewall, and `/etc/hosts` bootstrap entries.

> **Note:** The sample configuration provided is intentionally broad. The underlying code supports the full range of configuration allowed by the corresponding `redhat.rhel_idm` module. Users can extend the configuration to meet their specific requirements. To ensure consistent and reproducible builds, update the relevant file directly in `inventory_template` — treat your inventory as code (GitOps).

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `rhc_insights_state` | string | `"absent"` | Controls Red Hat Insights registration. `"absent"` disables Insights on the IdM host. | `rhc` role |
| `rhc_enable_auto_update` | bool | `false` | Whether `rhc` should enable automatic system updates via Insights. | `rhc` role |
| `idm_repository_ids` | list\<string\> | see below | RHSM repository IDs enabled on the IdM host before installation. Templated with `ansible_distribution_major_version`. | `idm_pre` role |
| `rhis_time_servers` | list\<string\> | `["0.rhel.pool.ntp.org", "1.rhel.pool.ntp.org", "2.rhel.pool.ntp.org"]` | Ordered list of NTP servers written to the chrony configuration on the IdM host. | `idm_pre` chrony config |
| `idm_pre_dns_resolvers` | list\<string\> | `[8.8.8.8, 8.8.4.4]` | DNS resolvers written to the host's resolver configuration before IdM DNS takes over. | `idm_pre` role |
| `ipa_firewalld_zone` | string | `"public"` | Firewalld zone to which IdM firewall rules are applied. | `idm_pre` firewall tasks |
| `ipa_prime_interface` | string | (computed) | The network interface that carries the host's default IPv4 address. Resolved at runtime from `ansible_interfaces`. | `idm_pre` firewall tasks |
| `ipa_firewalld_services` | list\<string\> | see below | Firewalld service names opened on `ipa_firewalld_zone`. | `idm_pre` firewall tasks |
| `ipa_required_umask` | string | `"0022"` | Process umask required for correct IdM file permissions. | `idm_pre` role |
| `ipa_crypto_policy` | string | `"DEFAULT"` | System-wide crypto policy applied before installation. Supported values: `"DEFAULT"` (standard policy) and `"FIPS"` (FIPS 140 compliant). | `idm_pre` role |
| `etc_hosts_list` | list\<dict\> | see below | Static host entries added to `/etc/hosts` before IdM DNS is operational. | `idm_pre` role |

**Default `idm_repository_ids`:**
```
rhel-<major>-for-x86_64-baseos-rpms
rhel-<major>-for-x86_64-appstream-rpms
rhel-<major>-for-x86_64-supplementary-rpms
satellite-client-6-for-rhel-<major>-x86_64-rpms
```

**Default `ipa_firewalld_services`:**
```
freeipa-4, freeipa-ldap, freeipa-ldaps, freeipa-replication, freeipa-trust
```

**`etc_hosts_list` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `ip` | string | yes | IPv4 address of the host entry. |
| `fqdn` | string | yes | Fully qualified domain name for the entry. |

---

## Server Setup (`idm_primary_setup_vars.yml`)

Core variables consumed by the `ipaserver` role (from the `redhat.rhel_idm` collection) during initial IdM server installation. These map directly to the `ipaserver` role's variable namespace.

> **Note:** The sample configuration provided is intentionally broad. The underlying code supports the full range of configuration allowed by the corresponding `redhat.rhel_idm` module. Users can extend the configuration to meet their specific requirements. To ensure consistent and reproducible builds, update the relevant file directly in `inventory_template` — treat your inventory as code (GitOps).

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `register_to_satellite` | bool | `false` | Set to `false` for the IdM primary because Satellite is not yet deployed when IdM is built. After Satellite is operational, the provisioner node is responsible for registering the IdM primary to Satellite as a post-installation task (when IdM integration is in use). | rhis-builder-idm pre-tasks |
| `ipaserver_ip_addresses` | string | `"{{ _default_network }}.5"` | IP address of the IdM primary server. Derived from the deployment's default network prefix. | `ipaserver` role |
| `ipaserver_hostname` | string | `"{{ ansible_fqdn }}"` | FQDN of the IdM server as used during installation. | `ipaserver` role |
| `ipaserver_forwarders` | list\<string\> | `["8.8.8.8"]` | Upstream DNS forwarders for the IdM-managed DNS service. | `ipaserver` role |
| `ipaserver_forward_policy` | string | `"only"` | DNS forwarding policy. `"only"` sends all non-local queries exclusively to the configured forwarders; `"first"` tries local resolution before forwarding. | `ipaserver` role |
| `default_password` | string | `"{{ ipa_default_user_password }}"` | Default initial password applied to newly created IdM users. References the vault variable `ipa_default_user_password`. | rhis-builder-idm user tasks |
| `ipaserver_domain` | string | `"{{ ipa_server_domain }}"` | Kerberos/DNS domain name for the IdM realm (e.g. `example.com`). Set in group_vars. | `ipaserver` role |
| `ipaserver_realm` | string | `"{{ ipa_server_realm }}"` | Kerberos realm name (e.g. `EXAMPLE.COM`). Typically the uppercase domain. Set in group_vars. | `ipaserver` role |
| `ipaserver_no_host_dns` | bool | `true` | Skips DNS validation of the server's own hostname during install. Useful when IdM is the authoritative DNS. | `ipaserver` role |
| `ipaserver_mem_check` | bool | `false` | Disables the installer's memory requirement check. | `ipaserver` role |
| `ipaserver_install_packages` | bool | `false` | When `false`, assumes IdM packages are pre-installed (e.g. via Satellite). | `ipaserver` role |
| `ipaserver_setup_firewalld` | bool | `true` | Whether the `ipaserver` role should configure firewalld rules. | `ipaserver` role |
| `ipaserver_setup_adtrust` | bool | `false` | Enables Active Directory trust integration (AD Trust). Requires Samba packages. | `ipaserver` role |
| `ipaserver_setup_kra` | bool | `true` | Installs the Key Recovery Authority component for certificate vault operations. | `ipaserver` role |
| `ipaserver_setup_dns` | bool | `true` | Installs the integrated BIND DNS server managed by IdM. | `ipaserver` role |
| `ipaserver_auto_reverse` | bool | `true` | Automatically creates reverse DNS zones during installation. | `ipaserver` role |
| `ipaserver_external_ca` | bool | `false` | When `true`, the IdM CA is signed by an external CA rather than being self-signed. | `ipaserver` role |
| `makehomedir` | bool | `true` | Enables PAM `mkhomedir` so home directories are created on first login. | `ipaserver` role / PAM |
| `sshtrustdns` | bool | `true` | Configures SSH to trust DNS-based host key fingerprints (SSHFP records). | `ipaserver` role |

---

## Global Realm Configuration (`idm_global_config.yml`)

Variables consumed by the `idm_config` role to set realm-wide defaults after IdM is installed. These control authentication behaviour, search limits, SELinux user mapping, and directory-wide defaults.

> **Note:** The sample configuration provided is intentionally broad. The underlying code supports the full range of configuration allowed by the corresponding `redhat.rhel_idm` module. Users can extend the configuration to meet their specific requirements. To ensure consistent and reproducible builds, update the relevant file directly in `inventory_template` — treat your inventory as code (GitOps).

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `idm_config_ca_renewal_master_server` | string | `"{{ groups['idm_primary'][0] }}"` | FQDN of the server designated as the CA certificate renewal master. | `idm_config` role |
| `idm_config_configstring_list` | list\<string\> | `["AllowNThash", "KDC:Disable Last Success"]` | Extra hash types and KDC configuration strings to enable in the password plug-in. | `idm_config` role |
| `idm_config_defaultgroup` | string | `"ipausers"` | Default POSIX group assigned to every new user. | `idm_config` role |
| `idm_config_defaultshell` | string | `"/bin/bash"` | Default login shell for new IdM users. | `idm_config` role |
| `idm_config_domain_resolution_order` | list\<string\> | `["{{ ansible_domain }}"]` | Ordered list of domains used to qualify short names during resolution. | `idm_config` role |
| `idm_config_emaildomain` | string | `"{{ ansible_domain }}"` | Default e-mail domain appended when a user's e-mail address is not explicitly set. | `idm_config` role |
| `idm_config_enable_migration` | bool | `false` | Enables IdM migration mode, allowing LDAP password migration from a legacy directory. | `idm_config` role |
| `idm_config_enable_sid` | bool | `true` | Enables SID (Security Identifier) generation required for AD trust. Cannot be disabled once activated. | `idm_config` role |
| `idm_config_homedirectory` | string | `"/home"` | Default base path for user home directories. | `idm_config` role |
| `idm_config_pwdexpnotify` | int | `14` | Number of days before password expiry that users receive an expiration notice. | `idm_config` role |
| `idm_config_searchrecordslimit` | int | `100` | Maximum number of entries returned by a single LDAP search. | `idm_config` role |
| `idm_config_searchtimelimit` | int | `10` | Maximum number of seconds the server will spend on a single LDAP search. | `idm_config` role |
| `idm_config_selinuxusermapdefault` | string | `"unconfined_u:s0-s0:c0.c1023"` | Default SELinux user context applied to IdM-authenticated users who do not match a more specific mapping. | `idm_config` role |
| `idm_config_selinuxusermaporder_list` | list\<string\> | see below | Ordered list of SELinux user labels defining mapping priority. Highest priority last. | `idm_config` role |

**Default `idm_config_selinuxusermaporder_list`** (lowest to highest priority):
```
guest_u:s0
xguest_u:s0
user_u:s0
staff_u:s0-s0:c0.c1023
sysadm_u:s0-s0:c0.c1023
unconfined_u:s0-s0:c0.c1023
```

**Commented-out / optional variables** (uncomment and set as needed):

| Variable | Type | Description |
|---|---|---|
| `idm_config_add_sids` | bool | Add SIDs to all existing users and groups. Requires IPA 4.9.8+ and SID generation already active. |
| `idm_config_auth_type_list` | list\<string\> | Override the realm-wide default authentication types. Valid values: `disabled`, `password`, `radius`, `otp`, `pkinit`, `hardened`, `idp`. |
| `idm_config_groupobjectclasses_list` | list\<string\> | Custom LDAP object classes for group entries. |
| `idm_config_groupsearch_list` | list\<string\> | LDAP attributes searched during group look-ups. |
| `idm_config_maxhostname` | int | Maximum hostname length enforced by IdM. |
| `idm_config_maxusername` | int | Maximum username length enforced by IdM. |
| `idm_config_netbios_name` | string | NetBIOS name for the domain, required for AD trust. |
| `idm_config_pac_type_list` | list\<string\> | PAC types to include in Kerberos tickets (e.g. `MS-PAC`, `PAD`, `nfs:NONE`). |
| `idm_config_userobjectclasses_list` | list\<string\> | Custom LDAP object classes for user entries. |
| `idm_config_usersearch_list` | list\<string\> | LDAP attributes searched during user look-ups (e.g. `uid`, `givenname`, `sn`). |

---

## Directory Server Hardening (`idm_hardening.yml`)

Controls 389 Directory Server (nsslapd) security settings applied after installation via `ldapmodify` or equivalent automation.

> **Note:** The sample configuration provided is intentionally broad. The underlying code supports the full range of configuration allowed by the corresponding `redhat.rhel_idm` module. Users can extend the configuration to meet their specific requirements. To ensure consistent and reproducible builds, update the relevant file directly in `inventory_template` — treat your inventory as code (GitOps).

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `idm_nsslapd_allow_anonymous_access` | string | `"rootdse"` | Controls anonymous LDAP access. `"on"` allows full anonymous access (insecure default). `"off"` disables all anonymous access. `"rootdse"` (recommended) permits anonymous access only to root DSE configuration metadata required by web clients, but prevents unauthenticated reads of directory data. | `idm_hardening` role / ldapmodify |

---

## Host Groups (`host_groups.yml`)

Defines IdM host groups created during day-1 configuration. Hosts are added to these groups at deployment or registration time, not here.

> **Note:** The sample configuration provided is intentionally broad. The underlying code supports the full range of configuration allowed by the corresponding `redhat.rhel_idm` module. Users can extend the configuration to meet their specific requirements. To ensure consistent and reproducible builds, update the relevant file directly in `inventory_template` — treat your inventory as code (GitOps).

**`idm_host_groups`** — list of host group definitions.

| Variable | Type | Description | Used by |
|---|---|---|---|
| `idm_host_groups` | list\<dict\> | List of IdM host groups to create. | `redhat.rhel_idm.ipahostgroup` module |

**`idm_host_groups` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Name of the host group (e.g. `hg-production`). |
| `description` | string | yes | Human-readable description of the group's purpose. |

**Default groups defined:**

| Name | Description |
|---|---|
| `hg-production` | Production Servers |
| `hg-qualification` | Quality assurance and testing servers |
| `hg-development` | Development and research servers |
| `hg-pipeline` | Pipeline and build servers |
| `hg-satellite-primary-servers` | Satellite Servers |
| `hg-satellite-capsule-servers` | Satellite Capsule servers |
| `hg-aap-servers` | Ansible Automation Platform Servers |
| `hg-container-hosts` | Container Hosts (tang, discovery, etc.) |
| `hg-webservers` | Web Servers |

---

## Password Policy (`password_policy.yml`)

Defines one or more IdM password policies. Policies are applied to user groups; the built-in `global_policy` acts as the realm-wide baseline. Policies with lower `priority` values take precedence. Priority must be unique within the policy list. The `global_policy` entry does not accept a `priority` key.

> **Note:** The sample configuration provided is intentionally broad. The underlying code supports the full range of configuration allowed by the corresponding `redhat.rhel_idm` module. Users can extend the configuration to meet their specific requirements. To ensure consistent and reproducible builds, update the relevant file directly in `inventory_template` — treat your inventory as code (GitOps).

**`idm_password_policies`** — list of password policy definitions.

| Variable | Type | Description | Used by |
|---|---|---|---|
| `idm_password_policies` | list\<dict\> | List of password policies to create or update in IdM. | `redhat.rhel_idm.ipapwpolicy` module |

**`idm_password_policies` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `group_name` | string | yes | Name of the group this policy applies to, or `"global_policy"` for the realm-wide default. |
| `priority` | string (int) | yes (except `global_policy`) | Policy priority. Lower number wins. Must be unique. |
| `dictcheck` | bool | yes | Reject passwords that appear in the system dictionary. |
| `usercheck` | bool | yes | Reject passwords that contain the username. |
| `minlength` | string (int) | yes | Minimum password length in characters. |
| `minclasses` | string (int) | yes | Minimum number of character classes required (Upper, Lower, Digits, Special, UTF-8). |
| `maxrepeat` | string (int) | yes | Maximum number of consecutive identical characters (e.g. `"3"` rejects `mmmm`). |
| `maxsequence` | string (int) | yes | Maximum number of monotone sequence characters (e.g. `"3"` rejects `1234`). |
| `history` | string (int) | yes | Number of previous passwords remembered; `"0"` disables history. |
| `maxlife` | string (int) | yes | Maximum password age in days; `"0"` means the password never expires. |
| `minlife` | string (int) | yes | Minimum password age in hours before a user can change it again. |
| `maxfail` | string (int) | yes | Number of consecutive failed authentication attempts before the account is locked. |
| `failinterval` | string (int) | yes | Seconds after which the failed-attempt counter resets. |
| `lockouttime` | string (int) | yes | Seconds an account remains locked after exceeding `maxfail`. |
| `gracelimit` | string (int) | yes | Number of grace logins allowed after password expiry. `"-1"` means unlimited grace logins (the system default). |

**Policies defined in template:**

| `group_name` | `priority` | `minlength` | `minclasses` | `maxlife` | `maxfail` | Notes |
|---|---|---|---|---|---|---|
| `global_policy` | — | 8 | 3 | 90 days | 6 | Realm-wide baseline; no priority key. |
| `ipausers` | 65535 | 8 | 3 | 90 days | 6 | Mirrors global_policy; very low priority so other groups override it. |
| `admins` | 1 | 12 | 4 | 30 days | 3 | Strongest policy, highest priority. |
| `ug-admins` | 2 | 12 | 4 | 30 days | 3 | Environment administrators. |
| `ug-services` | 3 | 8 | 4 | ~55 years | 3 | Service accounts; very long `maxlife` to avoid disruption. |

---

## HBAC Policy (`hbac_policy.yml`)

Defines Host-Based Access Control services, service groups, and rules that restrict which users may authenticate to which hosts using which services. These supplement the default HBAC services created by IdM at install time.

> **Note:** The sample configuration provided is intentionally broad. The underlying code supports the full range of configuration allowed by the corresponding `redhat.rhel_idm` module. Users can extend the configuration to meet their specific requirements. To ensure consistent and reproducible builds, update the relevant file directly in `inventory_template` — treat your inventory as code (GitOps).

### HBAC Services

**`idm_hbac_services`** — list of custom HBAC service definitions.

| Variable | Type | Description | Used by |
|---|---|---|---|
| `idm_hbac_services` | list\<dict\> | Custom PAM services registered in IdM for use in HBAC rules. | `redhat.rhel_idm.ipahbacsvc` module |

**`idm_hbac_services` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | PAM service name (must match the PAM service entry on target hosts). |
| `description` | string | no | Human-readable description of the service. |

### HBAC Service Groups

**`idm_hbac_service_groups`** — list of HBAC service group definitions.

| Variable | Type | Description | Used by |
|---|---|---|---|
| `idm_hbac_service_groups` | list\<dict\> | Groups of HBAC services that can be referenced together in HBAC rules. | `redhat.rhel_idm.ipahbacsvcgroup` module |

**`idm_hbac_service_groups` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Name of the service group (e.g. `hbacsg-boot-services`). |
| `description` | string | no | Human-readable description of the group's purpose. |
| `services` | list\<string\> | yes | List of HBAC service names (must exist in IdM) to include in this group. |

### HBAC Rules

**`idm_hbac_rules`** — list of HBAC rule definitions.

| Variable | Type | Description | Used by |
|---|---|---|---|
| `idm_hbac_rules` | list\<dict\> | Access control rules binding users, hosts, and services. | `redhat.rhel_idm.ipahbacrule` module |

**`idm_hbac_rules` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Unique name for this HBAC rule. |
| `description` | string | no | Human-readable description. |
| `action` | string | yes | Module action. Use `"hbacrule"` to manage the rule itself; `"member"` to add/remove members to an existing rule. |
| `state` | string | yes | `"present"` to ensure the rule exists, `"absent"` to remove it. |
| `user_groups` | list\<string\> | no | User group names whose members this rule applies to. |
| `users` | list\<string\> | no | Individual user login names this rule applies to. |
| `host_groups` | list\<string\> | no | Host group names whose members are target hosts for this rule. |
| `hosts` | list\<string\> | no | Individual host FQDNs that are target hosts for this rule. |
| `servicecategory` | string | no | Set to `"all"` to allow all services. Mutually exclusive with `hbac_services` / `hbac_service_groups`. |
| `hbac_services` | list\<string\> | no | Specific HBAC service names this rule permits. |
| `hbac_service_groups` | list\<string\> | no | HBAC service group names this rule permits. |

**Default HBAC services created by IdM at install time** (for reference; not managed here):

`crond`, `ftp`, `gdm`, `gdm-password`, `gssftp`, `kdm`, `login`, `proftpd`, `pure-ftpd`, `sshd`, `su`, `su-l`, `sudo`, `sudo-i`, `systemd-user`, `vsftpd`

---

## HBAC Policy Tests (`hbac_policy_tests.yml`)

Defines test cases used to validate HBAC rules. Tests are executed via the IPA API using the URI module (no native Ansible module exists yet). These verify that the correct access decisions are made before deploying to production.

> **Note:** The sample configuration provided is intentionally broad. The underlying code supports the full range of configuration allowed by the corresponding `redhat.rhel_idm` module. Users can extend the configuration to meet their specific requirements. To ensure consistent and reproducible builds, update the relevant file directly in `inventory_template` — treat your inventory as code (GitOps).

**`idm_hbac_policy_tests`** — list of HBAC test case definitions.

| Variable | Type | Description | Used by |
|---|---|---|---|
| `idm_hbac_policy_tests` | list\<dict\> | Test cases for HBAC rule validation. Executed via the IdM REST API. | rhis-builder-idm HBAC test tasks |

**`idm_hbac_policy_tests` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `user` | string | yes | Login name of the user to test access for. |
| `host` | string | yes | FQDN of the target host to test access against. |
| `service` | string | yes | PAM service name to test (e.g. `sshd`). |
| `rules` | list\<string\> | no | Specific HBAC rule names to test against. If omitted, all matching rules are evaluated. |
| `enabled` | bool | no | Whether to include all currently enabled rules in the test. Default `false`. |
| `disabled` | bool | no | Whether to include all currently disabled rules in the test. Default `false`. |
| `sourcehost` | string | no | Source host for the access request (deprecated in modern IPA; optional). |
| `nodetail` | bool | no | Suppress per-rule detail in the test output. Default `false`. |

---

## Sudo Policy (`sudo_policy.yml`)

Defines sudo commands, command groups, and rules that are managed centrally in IdM and applied to enrolled hosts via SSSD. This provides a host-independent, centrally-audited alternative to local sudoers files.

> **Note:** The sample configuration provided is intentionally broad. The underlying code supports the full range of configuration allowed by the corresponding `redhat.rhel_idm` module. Users can extend the configuration to meet their specific requirements. To ensure consistent and reproducible builds, update the relevant file directly in `inventory_template` — treat your inventory as code (GitOps).

### Sudo Commands

**`idm_sudo_commands`** — list of individual privileged commands registered in IdM.

| Variable | Type | Description | Used by |
|---|---|---|---|
| `idm_sudo_commands` | list\<dict\> | Individual commands that may be referenced in sudo rules or command groups. | `redhat.rhel_idm.ipasudocmd` module |

**`idm_sudo_commands` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | The full command string (e.g. `"systemctl start httpd"`). |
| `description` | string | no | Human-readable description of what the command does. |
| `state` | string | no | `"present"` (default) or `"absent"` to remove the command. |

### Sudo Command Groups

**`idm_sudo_command_groups`** — list of sudo command group definitions.

| Variable | Type | Description | Used by |
|---|---|---|---|
| `idm_sudo_command_groups` | list\<dict\> | Named collections of sudo commands that can be referenced together in sudo rules. | `redhat.rhel_idm.ipasudocmdgroup` module |

**`idm_sudo_command_groups` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Name of the command group (e.g. `scg-webserver-service-control`). |
| `description` | string | no | Human-readable description. |
| `state` | string | no | `"present"` (default) or `"absent"` to remove the group. |
| `commands` | list\<string\> | yes | List of command name strings to include in this group. Commands must exist in `idm_sudo_commands`. |

### Sudo Rules

**`idm_sudo_rules`** — list of sudo rule definitions.

| Variable | Type | Description | Used by |
|---|---|---|---|
| `idm_sudo_rules` | list\<dict\> | Rules binding users, hosts, commands, and run-as targets into a complete sudo policy. | `redhat.rhel_idm.ipasudorule` module |

**`idm_sudo_rules` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Unique name for this sudo rule. |
| `description` | string | no | Human-readable description. |
| `state` | string | no | `"present"` (default) or `"absent"` to remove the rule. |
| `action` | string | no | `"sudorule"` (default) manages the rule itself. `"member"` adds/removes members from an existing rule. |
| `order` | string (int) | no | Numeric ordering hint for rule precedence when multiple rules match. |
| `sudo_options` | list\<string\> | no | List of sudo option flags (e.g. `"!authenticate"` to skip password prompt). |
| `user_category` | string | no | Set to `"all"` to apply the rule to all users. Mutually exclusive with `users` / `user_groups`. |
| `users` | list\<string\> | no | Individual user logins this rule applies to. |
| `user_groups` | list\<string\> | no | User group names this rule applies to. |
| `host_category` | string | no | Set to `"all"` to apply the rule on all hosts. Mutually exclusive with `hosts` / `host_groups`. |
| `hosts` | list\<string\> | no | Individual host FQDNs this rule applies to. |
| `host_groups` | list\<string\> | no | Host group names this rule applies to. |
| `command_category` | string | no | Set to `"all"` to allow all commands. Use with caution. Mutually exclusive with `allow_commands` / `allow_command_groups`. |
| `allow_commands` | list\<string\> | no | Individual command names permitted by this rule. |
| `allow_command_groups` | list\<string\> | no | Command group names permitted by this rule. |
| `deny_commands` | list\<string\> | no | Individual command names explicitly denied by this rule. |
| `deny_command_groups` | list\<string\> | no | Command group names explicitly denied by this rule. |
| `runas_user_category` | string | no | Set to `"all"` to allow running as any user. |
| `runas_users` | list\<string\> | no | Specific users that can be impersonated. |
| `runas_group_category` | string | no | Set to `"all"` to allow running as any group. |
| `runas_groups` | list\<string\> | no | Specific groups that can be impersonated. |

---

## Identity Provider References (`idp_references.yml`)

Configures external OpenID Connect (OIDC) identity providers that IdM can federate with, enabling users to authenticate to IdM-enrolled systems using their external IdP credentials.

> **Note:** The sample configuration provided is intentionally broad. The underlying code supports the full range of configuration allowed by the corresponding `redhat.rhel_idm` module. Users can extend the configuration to meet their specific requirements. To ensure consistent and reproducible builds, update the relevant file directly in `inventory_template` — treat your inventory as code (GitOps).

**`idm_idp_references`** — list of external IdP connection definitions.

| Variable | Type | Description | Used by |
|---|---|---|---|
| `idm_idp_references` | list\<dict\> | External OIDC identity providers configured in IdM. | `redhat.rhel_idm.ipaidp` module |

**`idm_idp_references` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Identifier for this IdP reference within IdM (e.g. `"azure_entra"`). |
| `provider` | string | no | Named provider shortcut (e.g. `"microsoft"`). When set, IdM fills in known OIDC endpoints automatically. Mutually exclusive with explicit URI fields. |
| `idp_organization` | string | no | Tenant or organisation identifier (for Microsoft: the Azure AD tenant domain). References a vault variable. |
| `client_id` | string | yes | OIDC application (client) ID registered in the external IdP. References a vault variable. |
| `user_id_attribute` | string | yes | The OIDC claim used to match the external identity to an IdM user (e.g. `"email"`). |
| `scope` | string | no | Space-separated OIDC scopes to request from the IdP (e.g. `"openid email"`). |
| `auth_uri` | string | no | OIDC authorization endpoint URI. Use when `provider` is not set. |
| `dev_auth_uri` | string | no | OIDC device authorization endpoint URI (for device-flow authentication). Use when `provider` is not set. |
| `token_uri` | string | no | OIDC token endpoint URI. Use when `provider` is not set. |
| `keys_uri` | string | no | OIDC JWKS (JSON Web Key Set) URI for token signature validation. Use when `provider` is not set. |
| `userinfo_uri` | string | no | OIDC userinfo endpoint URI. Use when `provider` is not set. |

> Note: `secret` (the OIDC client secret) is a `_vault`-suffixed variable and is excluded from this schema per project convention.

---

## DNS Configuration (`dns_configuration.yml.j2`)

This is a Jinja2 template rendered per deployment. It configures IdM-managed DNS zones and records after the IdM server is installed. Some fields use raw Jinja2 to interpolate deployment-specific values (network CIDR, domain names).

> **Note:** The sample configuration provided is intentionally broad. The underlying code supports the full range of configuration allowed by the corresponding `redhat.rhel_idm` module. Users can extend the configuration to meet their specific requirements. To ensure consistent and reproducible builds, update the relevant file directly in `inventory_template` — treat your inventory as code (GitOps).

### Forward Zones (optional)

**`idm_dns_forward_zones`** — list of DNS forward zone definitions (commented out by default; uncomment if forwarding specific zones).

| Variable | Type | Description | Used by |
|---|---|---|---|
| `idm_dns_forward_zones` | list\<dict\> | Forward zones that delegate resolution for a domain to specific nameservers. | `redhat.rhel_idm.ipadnsforwardzone` module |

**`idm_dns_forward_zones` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | DNS zone name to forward (e.g. `"{{ _runtime_global_domain_name }}"`). |
| `forwarders` | list\<dict\> | yes | List of forwarder objects with an `ip_address` key. |
| `forward_policy` | string | no | `"first"` (try local, then forwarder) or `"only"` (always forward). |
| `skip_overlap_check` | bool | no | Skip validation that this zone does not overlap an existing zone. |

### Dynamic Update Zones

**`idm_dns_update_zones`** — list of existing IdM-managed zones whose update policy and sync behaviour should be configured. Typically includes the forward and reverse zones for the deployment domain.

| Variable | Type | Description | Used by |
|---|---|---|---|
| `idm_dns_update_zones` | list\<dict\> | IdM DNS zones to configure with dynamic update policies. | `redhat.rhel_idm.ipadnszone` module |

**`idm_dns_update_zones` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | DNS zone name (e.g. `"{{ _runtime_global_domain_name }}"` or the reverse zone name). |
| `foreman_proxy_BIND_update_policy` | string | yes | BIND `update-policy` grant statement. Controls which Kerberos principals may dynamically update DNS records. Rendered by the template with actual domain and realm names. The policy is intentionally broad to grant the foreman-proxy user the permissions required to create and update DNS entries. In the RHIS default configuration with IdM, the foreman-proxy user is a realm user with a specific RBAC role configured in IdM. The user authenticates via a keytab used for both IdM management and Ansible remote execution. The keytab is properly protected and access is restricted to the foreman-proxy process. If desired, a stricter update policy may be substituted; however, thorough testing is strongly recommended as the default policy is tested and documented. |
| `allow_sync_ptr` | bool | yes | Allow IdM to automatically create and remove PTR (reverse) records when A/AAAA records change. |
| `dynamic_update` | bool | yes | Enable DNS dynamic updates for this zone. |

### DNS Records

**`idm_dns_records`** — list of DNS resource records to create or manage in IdM-controlled zones.

| Variable | Type | Description | Used by |
|---|---|---|---|
| `idm_dns_records` | list\<dict\> | DNS records (A, AAAA, SRV, PTR, CNAME, etc.) to ensure exist in IdM DNS. | `redhat.rhel_idm.ipadnsrecord` module |

**`idm_dns_records` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Record name (host label or service label, e.g. `"router"`, `"_tcp._foreman"`). |
| `zone_name` | string | yes | DNS zone in which this record resides. |
| `record_type` | string | yes | DNS record type: `"A"`, `"AAAA"`, `"SRV"`, `"PTR"`, `"CNAME"`, `"TXT"`, etc. |
| `state` | string | yes | `"present"` to ensure the record exists, `"absent"` to remove it. |
| `ip_address` | string | no | IPv4 address for A records. Rendered by the template using `ansible.utils.next_nth_usable` on the deployment CIDR. |
| `a_create_reverse` | bool | no | Automatically create a corresponding PTR record in the reverse zone. Applicable to A records. |
| `srv_port` | string (int) | no | Port number for SRV records. |
| `srv_priority` | string (int) | no | Priority for SRV records (lower is higher priority). |
| `srv_weight` | string (int) | no | Relative weight for SRV records with equal priority. |
| `srv_target` | string | no | Target FQDN (with trailing dot) for SRV records. |

---

## Automount (`automount.yml.j2`)

This is a Jinja2 template rendered per deployment. It configures IdM automount locations, maps, and keys for NFS and other network filesystem automounting across enrolled hosts.

> **Note:** The sample configuration provided is intentionally broad. The underlying code supports the full range of configuration allowed by the corresponding `redhat.rhel_idm` module. Users can extend the configuration to meet their specific requirements. To ensure consistent and reproducible builds, update the relevant file directly in `inventory_template` — treat your inventory as code (GitOps).

### Automount Locations

**`idm_automount_locations`** — list of automount location definitions.

| Variable | Type | Description | Used by |
|---|---|---|---|
| `idm_automount_locations` | list\<dict\> | Named automount locations (analogous to NIS automount maps per site). | `redhat.rhel_idm.ipaautomountlocation` module |

**`idm_automount_locations` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Name of the automount location (e.g. `"raleigh"`). |
| `state` | string | yes | `"present"` to create, `"absent"` to remove the location and all its maps. |

### Automount Maps

**`idm_automount_maps`** — list of automount map definitions within a location.

| Variable | Type | Description | Used by |
|---|---|---|---|
| `idm_automount_maps` | list\<dict\> | Named automount maps (e.g. `auto.master`, `auto.devel`) within a location. | `redhat.rhel_idm.ipaautomountmap` module |

**`idm_automount_maps` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Name of the automount map (e.g. `"auto.master"`, `"auto.devel"`). |
| `location` | string | yes | The automount location this map belongs to. Must match an entry in `idm_automount_locations`. |

### Automount Keys

**`idm_automount_keys`** — list of automount key/entry definitions within a map.

| Variable | Type | Description | Used by |
|---|---|---|---|
| `idm_automount_keys` | list\<dict\> | Individual automount entries (key + mount options) within a map. | `redhat.rhel_idm.ipaautomountkey` module |

**`idm_automount_keys` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `key` | string | yes | The automount key (mount point path or wildcard, e.g. `"project1"`, `"/projects"`). |
| `location` | string | yes | The automount location this key belongs to. |
| `mapname` | string | yes | The automount map this key is an entry in. |
| `info` | string | yes | The mount information string. For direct maps: NFS mount options and server:/path. For indirect maps referencing another map: the map name. |

---

## Users and Groups (`users_and_groups.yml.j2`)

This is a Jinja2 template rendered per deployment. It defines the initial set of IdM users and user groups created as part of RHIS bootstrapping. Some fields reference deployment-specific values (`_runtime_global_domain_name`, `rhis_primary_city`, etc.) resolved at render time.

> **Note:** The sample configuration provided is intentionally broad. The underlying code supports the full range of configuration allowed by the corresponding `redhat.rhel_idm` module. Users can extend the configuration to meet their specific requirements. To ensure consistent and reproducible builds, update the relevant file directly in `inventory_template` — treat your inventory as code (GitOps).

### Users

**`idm_users`** — list of user definitions.

| Variable | Type | Description | Used by |
|---|---|---|---|
| `idm_users` | list\<dict\> | IdM users to create during environment bootstrapping. | `redhat.rhel_idm.ipauser` module |

**`idm_users` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `login` | string | yes | Username (UID) of the user. |
| `first` | string | yes | Given (first) name. |
| `last` | string | yes | Family (last) name. |
| `password` | string | yes | Initial password. Should reference `default_environment_password` which is backed by a vault variable. |
| `email` | string | no | User's e-mail address. Typically `login@{{ _runtime_global_domain_name }}`. |
| `title` | string | no | Job title. |
| `employeetype` | string | no | Employment type (e.g. `"full-time"`). |
| `employnumber` | string | no | Employee ID number. |
| `departmentnumber` | string | no | Department number. |
| `city` | string | no | City of the user's office location. May reference a deployment variable (e.g. `rhis_primary_city`). |
| `userstate` | string | no | State/province of the user's office location. May reference a deployment variable (e.g. `rhis_primary_state`). |

**Default users defined in template:**

| Login | Name | Role / Purpose |
|---|---|---|
| `poc-admin` | POC Admin | Primary POC / demo environment administrator |
| `developer1` | Developer One | Senior Developer (example user) |
| `developer2` | Developer Two | Senior Developer (example user) |
| `developer3` | Developer Three | Principal Data Scientist (example user) |
| `sat-admin` | Sat Admin | Satellite server administrator |
| `sat-org-admin` | Org Admin | Satellite organisation administrator |
| `site-admin` | Site Admin | Satellite location/site administrator |
| `comply-mgr` | Comply Mgr | Compliance content manager |
| `comply-aud` | Comply Aud | Compliance content auditor (read-only) |
| `pfy-operator` | PFY Operator | Junior operator (example user) |
| `bofh` | B OperatorFH | Experienced operator / god-mode admin (example user) |
| `content-mgr` | Content Mgr | Satellite content manager |

### User Groups

**`idm_user_groups`** — list of user group definitions.

| Variable | Type | Description | Used by |
|---|---|---|---|
| `idm_user_groups` | list\<dict\> | IdM user groups created and populated during bootstrapping. | `redhat.rhel_idm.ipausergroup` module |

**`idm_user_groups` entry schema:**

| Key | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Name of the user group. |
| `description` | string | no | Human-readable description of the group's purpose. |
| `user_list` | list\<string\> | no | Login names of users to add as direct members of this group. |
| `group_list` | list\<string\> | no | Names of other user groups to nest inside this group (group-of-groups). |

**Default user groups defined in template:**

| Name | Description | Notable members |
|---|---|---|
| `admins` | Built-in IdM admins group | `admin`, `poc-admin` |
| `ug-services` | Service Accounts | — |
| `ug-admins` | Environment Administrators | `admin`, `poc-admin`, `bofh` |
| `ug-satellite-administrators` | Satellite Server Administrators | Includes `ug-admins` group |
| `ug-satellite-org-administrators` | Satellite Default Org Administrators (Manager role) | `sat-org-admin`, `poc-admin` |
| `ug-satellite-site-administrators` | Satellite Default Site Administrators (Location Manager role) | `sat-org-admin`, `poc-admin` |
| `ug-satellite-compliance-managers` | Satellite Systems Compliance Managers | `comply-mgr`, `poc-admin` |
| `ug-satellite-compliance-auditors` | Satellite Systems Compliance Auditors (read-only) | `comply-aud`, `poc-admin` |
| `ug-satellite-operators` | Satellite Server Operators (full host/content host control) | `pfy-operator`, `bofh` |
| `ug-satellite-content-managers` | Satellite Content Managers | `content-mgr`, `poc-admin` |
| `ug-aap-administrators` | Ansible Automation Platform Administrators | Includes `ug-admins` group |
| `ug-aap-auditors` | Ansible Automation Platform Auditors | — |
| `ug-aap-operators` | Ansible Automation Platform Server Operators | — |
| `ug-aap-project-managers` | Ansible Automation Platform Project Managers | — |
| `ug-aap-template-managers` | Ansible Automation Platform Template Managers | — |
| `ug-aap-users` | AAP Users (can run basic Templates and Workflows) | `poc-admin`, `bofh`, developers |
| `ug-aap-developers` | AAP Programmers (power users) | `developer1`, `developer2`, `developer3` |
| `ug-prod-sysadmins` | Production System Administrators | — |
| `ug-non-prod-sysadmins` | Non-production System Administrators | — |
| `ug-web-server-administrators` | Web Server Administrators | — |
