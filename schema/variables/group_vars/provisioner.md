# Group: provisioner — Provisioner Variables

Schema Version: 1.0.0

The files and variables under this directory are multipurpose and serve two distinct roles:

**Provisioner configuration** — Variables in `main.yml` configure the provisioner node itself: DNS resolver, parallelism limits, and which platform host list is currently active.

**Host deployment definitions** — All `*_hosts.yml` and `*_hosts.yml.j2` files define the hosts that the provisioner will build as part of the overall RHIS environment. Once IdM and Satellite are operational, these configurations drive the deployment of the remaining infrastructure hosts (AAP, Satellite Capsule, IdM replicas, KVM hypervisors, Quadlet hosts, and test hosts) through Satellite.

Inside the rhis-provisioner container, helper scripts named `deploy_*` exist to launch these deployments. Each script calls the underlying `create_host` role in `rhis-builder-pipelines`, which uses Satellite to provision the target host. This provides a consistent configuration and workflow regardless of the target platform — bare-metal, hypervisor PXE, image-based, or cloud.

---

## Source Files

| File | Purpose |
|---|---|
| `main.yml` | Core provisioner settings: DNS resolver, parallelism controls, active platform host list |
| `satellite_vars.yml` | Placeholder for Satellite reference variables (currently empty) |
| `certificate_profiles.yml` | IdM certificate profile definitions for smartcard enrollment |
| `piv_config.yml` | PIV application configuration for YubiKey smartcard provisioning |
| `yubikey_defaults.yml` | Factory-default PIV PIN, PUK, and management key values |
| `yubikey_reset_ctl.yml` | Per-application reset flags for YubiKey factory reset |
| `generic_user.yml.j2` | Template stub documenting the per-user PIV variable pattern |
| `testyubiuser.yml.j2` | Rendered example of a concrete PIV user configuration |
| `bond_test_hosts.yml.j2` | Rendered host list for network bonding test hosts |
| `capsule_hosts.yml.j2` | Rendered host list for Satellite Capsule servers |
| `idm_replica_hosts.yml.j2` | Rendered host list for IdM replica servers |
| `quadlet_hosts.yml.j2` | Rendered host list for Podman Quadlet container hosts |
| `aap24_hosts.yml.j2` | Rendered host list for AAP 2.4 growth deployment |
| `aap26_hosts.yml.j2` | Rendered host list for AAP 2.6 growth deployment |
| `hostgroup_test_hosts_rhel8.yml` | Static host list for RHEL 8 hostgroup validation tests |
| `hostgroup_test_hosts_rhel9.yml` | Static host list for RHEL 9 hostgroup validation tests |
| `hostgroup_test_hosts_rhel10.yml` | Static host list for RHEL 10 hostgroup validation tests |
| `convert2rhel_test_hosts.yml` | Static host list for Convert2RHEL workflow tests |
| `kvm_hypervisor_hosts.yml` | Static host list for KVM hypervisor provisioning |

---

## Core Provisioner Settings

Source: `main.yml`

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `ipa_client_dns_servers` | string | `"{{ _default_network }}.5"` | DNS resolver address used when enrolling the provisioner as an IdM client. Derived from the default network prefix, pointing to `.5` (typically the IdM primary). | IdM client enrollment plays |
| `build_release_limit` | integer | `4` | Maximum number of hosts to submit to Satellite for build simultaneously. Tune to match the number of hypervisors and avoid overwhelming the storage array. | Parallel host provisioning plays |
| `build_release_timeout` | integer | `1800` | Seconds to wait for each build batch to complete before timing out. 1800 seconds (30 minutes) accommodates slow storage. Baremetal hosts typically build in under 10 minutes. | Parallel host provisioning plays |
| `platform_hosts` | string (reference) | `"{{ aap24_hosts }}"` | The active host list that drives the current build phase. Assigned at runtime by the `deploy_*` helper script to whichever role-specific host list is currently being built (e.g. `aap24_hosts`, `capsule_hosts`, `bond_test_hosts`). Other options are commented out in the template. | All host provisioning plays |

`platform_hosts` uses the same aggregator pattern as `aap_job_templates_list` and `aap_workflow_templates_list`. Each `deploy_*` script selects the correct host list by assigning it to `platform_hosts`, giving the provisioning plays a single consistent variable to consume regardless of which hosts are being built.

---

## Platform Host Lists

Each host list variable is a list of host definition maps. The common fields shared by all host list types are documented below, followed by per-list notes.

### Bare-metal host discovery and selection

For bare-metal hosts, the host definition can include Satellite search criteria rather than a fixed MAC address or IP. Any field indexed by Satellite's host search API is a valid search term — hardware model, memory, CPU count, disk count, BIOS UUID, or any custom Facter fact reported by the host. This allows the provisioner to select discovered hosts dynamically based on physical characteristics rather than pre-assigned identifiers.

Custom facts can be injected at discovery time by supplying a ZIP file containing Ruby code that is executed when a bare-metal system boots from the Satellite Discovery image. The facts collected by that code are reported back to Satellite as part of the Facter fact set and become immediately queryable as search fields. This mechanism was used to encode pre-configured datacenter deployment values directly into discovery facts, enabling RHIS to fully deploy an entire datacenter — selecting, provisioning, and configuring all hosts — in under 7.5 hours.

### Common Host Definition Fields

These keys appear in every host definition map across all host list variables.

| Field | Type | Description |
|---|---|---|
| `fqdn` | string | Fully qualified domain name of the host, typically using `{{ _runtime_global_domain_name }}` or `{{ _default_domain }}` |
| `delete_host` | boolean | When `true`, the host will be removed from Satellite rather than created. Usually `false` during provisioning. |
| `organization` | string | Satellite organization the host belongs to. References `{{ satellite_organization }}`. |
| `location` | string | Satellite location the host belongs to. References `{{ satellite_location }}`. |
| `hostgroup` | string | Satellite hostgroup path determining the OS, content view, lifecycle environment, and configuration classes applied at build time. |
| `compute_resource` | string | Satellite compute resource for provisioning. `"baremetal"` for physical hosts; `"VMware_Lab"` for virtual machines. |
| `kickstart_repository` | string | Satellite kickstart repository name used at OS install time. |
| `comment` | string | Free-text comment stored on the host record. Used to tag test hosts for easy identification and cleanup (e.g. `"rhis_test_host deleteme"`). |
| `pxe_loader` | string | PXE bootloader type. Typically `"Grub2 UEFI"` for UEFI-booting hardware. |
| `parameters` | list of maps | Satellite host parameters. Each entry has `name`, `parameter_type`, and `value`. Common parameters are `boot_disk` and `root_disk`. |
| `interfaces_attributes` | list of maps | Network interface definitions. Each entry describes one interface: `type`, `identifier`, `domain`, `mac`, `ip`, `subnet`, `execution`, `managed`, `primary`, `provision`. Bond interfaces also include `attached_devices`, `bond_options`, `mode`, and `virtual`. |
| `activation_keys` | string | Satellite activation key(s) to register the host. Only present when the hostgroup does not supply this. |
| `lifecycle_environment` | string | Satellite lifecycle environment override (e.g. `"Development"`). |
| `content_view` | string | Satellite content view override (e.g. `"SOE9"`). |
| `compute_profile` | string | Satellite compute profile selecting VM size for virtual hosts (e.g. `"SOE_Medium"`). |
| `ptable` | string | Satellite partition table name for virtual hosts (e.g. `"Kickstart default"`). |
| `mac` | string | MAC address shorthand for VM hosts where the interface is managed by the hypervisor (`"00:50:56:ff:ff:ff"` as a placeholder for VMware dynamic assignment). |
| `name` | string | Short hostname (no domain). Used as the Satellite host display name. Not always present — some entries use only `fqdn`. |
| `crt_force_regen` | boolean | When `true`, forces certificate regeneration during IdM enrollment. Present on IdM replica host entries. |
| `host_packages` | string | Space-separated list of additional packages to install at build time. Passed as a Satellite host parameter (e.g. `"vim container-tools"`). |

### `aap24_hosts` — AAP 2.4 Growth Deployment

Source: `aap24_hosts.yml.j2`

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `aap24_hosts` | list of host maps | See template | Defines the controller and hub nodes for an AAP 2.4 growth-topology deployment. Default members: `aapcontroller1` (`.14`) and `aaphub1` (`.15`), both using hostgroup `hg_x86_64_rhel9_metal/aap9_24`. | AAP provisioning plays; assigned to `platform_hosts` to activate. |

### `aap26_hosts` — AAP 2.6 Growth Deployment

Source: `aap26_hosts.yml.j2`

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `aap26_hosts` | list of host maps | See template | Defines the controller and hub nodes for an AAP 2.6 growth-topology deployment. Default active members: `aapcontroller1` (`.14`) and `aaphub1` (`.15`), both using hostgroup `hg_x86_64_rhel9_metal/aap9_26`. Additional nodes (database, gateway, EDA controller) are commented out in the template pending full growth topology build-out. | AAP provisioning plays; assigned to `platform_hosts` to activate. |

### `capsule_hosts` — Satellite Capsule Servers

Source: `capsule_hosts.yml.j2`

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `capsule_hosts` | list of host maps | See template | Defines Satellite Capsule servers. Default member: `capsule1` (`.81`) using hostgroup `hg_x86_64_rhel9_metal/satellite_capsule`. | Capsule provisioning plays; assigned to `platform_hosts` to activate. |

### `idm_replica_hosts` — IdM Replica Servers

Source: `idm_replica_hosts.yml.j2`

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `idm_replica_hosts` | list of host maps | See template | Defines IdM replica servers. Default member: `idm2` (`.6`) using hostgroup `hg_x86_64_rhel9_metal/dev`. Includes `crt_force_regen` to control certificate regeneration at enrollment. The file comment notes that lists may be concatenated when building multiple replicas. | IdM replica provisioning plays; assigned to `platform_hosts` to activate. |

### `quadlet_hosts` — Podman Quadlet Container Hosts

Source: `quadlet_hosts.yml.j2`

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `quadlet_hosts` | list of host maps | See template | Defines bare-metal hosts that run Podman Quadlet container workloads. Default members: `quadlet1` (`.71`) and `quadlet2` (`.72`), both using hostgroup `hg_x86_64_rhel9_metal`. The `host_packages` parameter installs `vim container-tools` at build time. | Quadlet host provisioning plays; assigned to `platform_hosts` to activate. |

### `bond_test_hosts` — Network Bond Test Hosts

Source: `bond_test_hosts.yml.j2`

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `bond_test_hosts` | list of host maps | See template | Defines bare-metal hosts used to validate 802.3ad network bonding configuration. Default members: `bondtest1` (provision `.66`, bond `.66`) and `bondtest2` (provision `.77`, bond `.77`). Each host has one primary provision interface, two child physical interfaces, and one 802.3ad bond interface using `miimon=100 xmit_hash_policy=layer3+4`. | Bond testing plays; assigned to `platform_hosts` to activate. |

### `kvm_hypervisor_hosts` — KVM Hypervisor Hosts

Source: `kvm_hypervisor_hosts.yml`

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `kvm_hypervisor_hosts` | list of host maps | See file | Defines bare-metal KVM hypervisor hosts. The active entry is `kvm1` (`.41`) using hostgroup `hg_x86_64_rhel9_metal/kvm_host`. Template stubs for `kvm2`–`kvm7` with pre-assigned MACs and IPs (`.42`–`.47`) are commented out. Bond interface support is also commented out but pre-configured for future use. | KVM hypervisor provisioning plays; assigned to `platform_hosts` to activate. |

### `convert2rhel_test_hosts` — Convert2RHEL Test Hosts

Source: `convert2rhel_test_hosts.yml`

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `convert2rhel_test_hosts` | list of host maps | See file | Defines virtual machines used to test Convert2RHEL content and conversion workflows. Contains two CentOS 7.9 hosts (`centostest1`, `centostest2`) and two Oracle Enterprise Linux 7.9 hosts (`oeltest1`, `oeltest2`), all using `VMware_Lab` with the `SOE_Medium` compute profile. | Convert2RHEL workflow testing plays; assigned to `platform_hosts` to activate. |

---

## Hostgroup Validation Test Hosts

These static files define host lists used to exercise Satellite hostgroup configurations across each supported RHEL major version. They are not template-rendered and use internal computed variables directly.

### `hostgroup_test_hosts_rhel8` — RHEL 8 Hostgroup Test Hosts

Source: `hostgroup_test_hosts_rhel8.yml`

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `hostgroup_test_hosts_rhel8` | list of host maps | See file | Test host list covering RHEL 8 hostgroups. Includes one bare-metal host (`hg-x86-64-rhel8-metal1`, MAC `94:c6:91:a3:1d:6a`, IP `.201`) and eight VM hosts covering `dev` and `qa` lifecycle environments across `soe8_dev_cis2`, `soe8_dev_jboss`, `soe8_dev_lamp`, `soe8_dev_wordpress`, `soe8_qa_jboss`, `soe8_qa_lamp`, and `soe8_qa_wordpress` child hostgroups. All hosts tagged with `comment: "rhis_test_host deleteme"`. | Satellite hostgroup testing plays |

### `hostgroup_test_hosts_rhel9` — RHEL 9 Hostgroup Test Hosts

Source: `hostgroup_test_hosts_rhel9.yml`

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `hostgroup_test_hosts_rhel9` | list of host maps | See file | Test host list covering RHEL 9 hostgroups. Includes one bare-metal host (`hg-x86-64-rhel9-metal1`, MAC `94:c6:91:a3:1b:79`, IP `.202`) and eight VM hosts covering `dev` and `qa` lifecycle environments across `soe9_dev_cis2`, `soe9_dev_jboss`, `soe9_dev_lamp`, `soe9_dev_wordpress`, `soe9_qa_jboss`, `soe9_qa_lamp`, and `soe9_qa_wordpress` child hostgroups. All hosts tagged with `comment: "rhis_test_host deleteme"`. | Satellite hostgroup testing plays |

### `hostgroup_test_hosts_rhel10` — RHEL 10 Hostgroup Test Hosts

Source: `hostgroup_test_hosts_rhel10.yml`

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `hostgroup_test_hosts_rhel10` | list of host maps | See file | Test host list covering RHEL 10 hostgroups. Includes one bare-metal host (`hg-x86-64-rhel10-metal1`, MAC `94:c6:91:a3:1d:fb`, IP `.203`) and one VM host (`hg-x86-64-rhel10-vm1`) using `hg_x86_64_rhel10_vm` with content view `SOE10`. Last validated 2025-11-16. All hosts tagged with `comment: "rhis_test_host deleteme"`. | Satellite hostgroup testing plays |

---

## PIV / YubiKey Smartcard Configuration

These variables are consumed by the `rhis-builder-yubi` project, which drives `ykman` (YubiKey Manager CLI) to initialize, configure, and provision user certificates onto YubiKey hardware tokens. See `rhis-builder-yubi` for the full set of plays.

### PIV Application Settings

Source: `piv_config.yml`

Variables ending in `_vault` are vault-encrypted and not documented here.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `piv_generate_random_key` | boolean | `true` | When `true`, generates a new random PIV management key rather than using a static value. | rhis-builder-yubi PIV init plays |
| `piv_mgmt_key_algorithm` | string | `"AES256"` | Algorithm used for the PIV management key (`AES256` recommended for modern YubiKeys). | rhis-builder-yubi PIV init plays |
| `piv_mgmt_key_protect` | boolean | `false` | When `true`, protects the management key with the PIN (requires PIN entry to use the management key). | rhis-builder-yubi PIV init plays |
| `piv_tmp_private_key_file` | string | `"{{ piv_tmp_secure_dir }}/{{ piv_current_username }}-piv-9a-private.pem"` | Temporary file path for the private key during CSR generation. Stored in `piv_tmp_secure_dir` (vault-set). | rhis-builder-yubi cert generation plays |
| `piv_tmp_public_key_file` | string | `"{{ piv_tmp_secure_dir }}/{{ piv_current_username }}-piv-9a-public.pub"` | Temporary file path for the extracted public key. | rhis-builder-yubi cert generation plays |
| `piv_tmp_csr_file` | string | `"{{ piv_tmp_secure_dir }}/{{ piv_current_username }}-piv-9a-request.csr"` | Temporary file path for the certificate signing request. | rhis-builder-yubi cert generation plays |
| `piv_tmp_certificate_file` | string | `"{{ piv_tmp_secure_dir }}/{{ piv_current_username }}-piv-9a-certificate.crt"` | Temporary file path for the issued certificate before importing to the YubiKey. | rhis-builder-yubi cert import plays |
| `piv_fips_enabled` | boolean | `false` | Set to `true` for FIPS-compliant YubiKey models. Affects PIN/PUK length requirements (FIPS requires 8-digit PINs). | rhis-builder-yubi PIV init plays |
| `piv_pinpuk_default_retries` | integer | `5` | Default retry count template used by `piv_pin_retries` and `piv_puk_retries`. | rhis-builder-yubi PIV init plays |
| `piv_pin_retries` | integer | `{{ piv_pinpuk_default_retries }}` | Number of incorrect PIN attempts allowed before the PIV application locks. | rhis-builder-yubi PIV init plays |
| `piv_puk_retries` | integer | `{{ piv_pinpuk_default_retries }}` | Number of incorrect PUK attempts allowed before PUK is blocked. | rhis-builder-yubi PIV init plays |
| `piv_random_password_generator` | string | `"python3 ~/piv_random.py"` | Command used to generate random PIN and PUK values during initialization. | rhis-builder-yubi PIV init plays |
| `piv_private_key_passfile_path` | string | `"~/yubico/passfile"` | Path to the passphrase file used to protect the private key during generation. | rhis-builder-yubi cert generation plays |
| `piv_rsa_private_key_size` | integer | `2048` | RSA key size in bits for PIV slot 9a. | rhis-builder-yubi cert generation plays |
| `piv_rsa_private_key_outform` | string | `"PEM"` | Output format for the private key file. | rhis-builder-yubi cert generation plays |
| `piv_rsa_private_key_algorithm` | string | `"RSA"` | Key algorithm. Used with OpenSSL during key generation. | rhis-builder-yubi cert generation plays |
| `piv_rsa_private_key_cipher` | string | `"aes-256-cbc"` | Cipher used to encrypt the private key file at rest. | rhis-builder-yubi cert generation plays |
| `piv_rsa_private_key_pubexp` | integer | `65537` | RSA public exponent. Standard value for RSA key generation. | rhis-builder-yubi cert generation plays |
| `piv_certificate_profile` | string | `"caRSAUserCertSmartCard"` | Name of the IdM certificate profile to request during smartcard enrollment. Must match an entry in `idm_certificate_profiles`. | rhis-builder-yubi cert request plays |
| `piv_slot` | string | `"9a"` | PIV slot to use for the authentication certificate. `9a` is the standard PIV authentication slot. | rhis-builder-yubi cert import plays |
| `piv_pin_policy` | string | `"DEFAULT"` | PIN policy for the PIV slot. Options: `DEFAULT`, `NEVER`, `ONCE`, `ALWAYS`. | rhis-builder-yubi cert import plays |
| `piv_touch_policy` | string | `"DEFAULT"` | Touch policy for the PIV slot. Options: `DEFAULT`, `NEVER`, `ALWAYS`, `CACHED`. | rhis-builder-yubi cert import plays |
| `piv_secure_idm_store` | boolean | `true` | When `true`, copies the final key material into the vault directory (`piv_vault_dir`) for secure long-term storage in IdM. | rhis-builder-yubi cert storage plays |
| `piv_private_key_file` | string | `"{{ piv_vault_dir }}/{{ piv_current_username }}-piv-9a-private.pem"` | Permanent vault-directory path for the private key. | rhis-builder-yubi cert storage plays |
| `piv_public_key_file` | string | `"{{ piv_vault_dir }}/{{ piv_current_username }}-piv-9a-public.pub"` | Permanent vault-directory path for the public key. | rhis-builder-yubi cert storage plays |
| `piv_csr_file` | string | `"{{ piv_vault_dir }}/{{ piv_current_username }}-piv-9a-request.csr"` | Permanent vault-directory path for the CSR. | rhis-builder-yubi cert storage plays |
| `piv_certificate_file` | string | `"{{ piv_vault_dir }}/{{ piv_current_username }}-piv-9a-certificate.crt"` | Permanent vault-directory path for the issued certificate. | rhis-builder-yubi cert storage plays |
| `piv_current_username_vault_file` | string | `"{{ piv_vault_dir }}/{{ piv_current_username }}.vault"` | Path to the per-user Ansible vault file storing the user's PIN/PUK. | rhis-builder-yubi vault management plays |

### Per-User PIV Identity Variables

Source: `generic_user.yml.j2` (pattern template), `testyubiuser.yml.j2` (concrete example)

These variables identify the specific user being provisioned in a given run. They are set per-user in a rendered `.yml.j2` file (one file per user). The `testyubiuser.yml.j2` template ships as a concrete reference deployment.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `piv_current_username` | string | (required) | The IdM username of the person receiving the smartcard certificate. Example: `"testyubiuser"`. Drives all file paths that include the username. | rhis-builder-yubi all PIV plays |
| `piv_current_user_csr_subject` | string | (required) | The X.509 subject string for the CSR. Format: `/CN=<username>/DC=<dc1>/DC=<dc2>/emailAddress=<username>@<domain>`. | rhis-builder-yubi cert request plays |
| `piv_current_realm` | string | (required) | The Kerberos realm, typically the domain name uppercased. Example: `"{{ basevars_global_domain_name \| upper }}"`. | rhis-builder-yubi cert request plays |

### YubiKey Factory Defaults

Source: `yubikey_defaults.yml`

These are the well-known factory default values for PIV PIN, PUK, and management key. They are used during the reset and initialization workflow to authenticate before changing credentials.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `piv_factory_default_management_key` | string | `"010203040506070801020304050607080102030405060708"` | YubiKey factory default PIV management key (48 hex characters). Used to authenticate the initial management key change. | rhis-builder-yubi PIV init plays |
| `piv_factory_default_pin` | string | `"123456"` | YubiKey factory default PIV PIN. Used to authenticate before setting a new PIN. | rhis-builder-yubi PIV init plays |
| `piv_factory_default_puk` | string | `"12345678"` | YubiKey factory default PIV PUK. Used to authenticate before setting a new PUK. | rhis-builder-yubi PIV init plays |
| `piv_factory_default_fips_pin` | string | `"12345678"` | Factory default PIN for FIPS-compliant YubiKey models, which require an 8-digit PIN at initialization. | rhis-builder-yubi PIV init plays (FIPS path) |

### YubiKey Application Reset Controls

Source: `yubikey_reset_ctl.yml`

These flags control which YubiKey applications are reset to factory defaults during the `ykman` reset workflow in `rhis-builder-yubi`. Resetting an application destroys all keys and credentials stored in it.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `reset_fido` | boolean | `true` | Reset the FIDO2 application (WebAuthn/FIDO2 credentials). | rhis-builder-yubi YubiKey reset plays |
| `reset_oauth` | boolean | `true` | Reset the OATH application (TOTP/HOTP OTP credentials). | rhis-builder-yubi YubiKey reset plays |
| `reset_openpgp` | boolean | `true` | Reset the OpenPGP application (GPG keys). | rhis-builder-yubi YubiKey reset plays |
| `reset_otp` | boolean | `false` | Reset the OTP application (Yubico OTP / static password slots). Set to `false` by default to preserve any pre-programmed OTP slot configuration. | rhis-builder-yubi YubiKey reset plays |
| `reset_piv` | boolean | `true` | Reset the PIV application (all PIV keys and certificates). Required before re-initializing the token. | rhis-builder-yubi YubiKey reset plays |

---

## IdM Certificate Profiles

Source: `certificate_profiles.yml`

These entries define IdM certificate profiles used for smartcard authentication. Each profile is a configuration file (`.cfg`) submitted to the IdM CA via the `redhat.rhel_idm` collection. The profiles correspond to certificate templates loaded into the IdM Dogtag CA and referenced by PIV provisioning workflows.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `idm_certificate_profiles` | list of profile maps | See below | List of IdM certificate profile definitions to ensure are present in the IdM CA. Consumed by `redhat.rhel_idm` certificate profile management tasks. | redhat.rhel_idm collection; rhis-builder-yubi cert request plays |

#### Profile map fields

| Field | Type | Description |
|---|---|---|
| `idmcp_profile_name` | string | Name of the certificate profile in the IdM CA (e.g. `"caRSAUserCertSmartCard"`). Must match the value of `piv_certificate_profile` when used for PIV enrollment. |
| `idmcp_cfg_path` | string | Path to the Dogtag CA `.cfg` file on the control node, relative to `playbook_dir`. |
| `idmcp_descripion` | string | Human-readable description stored with the profile in IdM. (Note: field name contains a typo — one `p` — matching the upstream variable name in `redhat.rhel_idm`.) |
| `idmcp_store` | string | Whether IdM should store issued certificates in the LDAP directory. `"TRUE"` or `"FALSE"`. |
| `idmcp_state` | string | Desired state of the profile. `"present"` creates it if absent; `"updated"` creates or replaces with the current `.cfg` content. |

#### Default profiles

| Profile Name | Algorithm | State | Purpose |
|---|---|---|---|
| `caRSAUserCertSmartCard` | RSA | `updated` | RSA user smartcard authentication certificate. This is the profile referenced by `piv_certificate_profile` in `piv_config.yml`. |
| `caECCUserCertSmartCard` | ECC | `present` | ECC user smartcard authentication certificate. Available as an alternative to RSA for environments that support elliptic-curve certificates. |
