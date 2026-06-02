# Shared Variable Contract — rhis-builder Cross-Project Interface

## Why This Exists

rhis-builder is a collection of independent Ansible projects, each responsible for
a distinct infrastructure component:

- `rhis-builder-idm` — Identity Management (FreeIPA)
- `rhis-builder-satellite` — Red Hat Satellite
- `rhis-builder-kvm` — KVM hypervisors
- `rhis-builder-aap` — Ansible Automation Platform
- `rhis-builder-day-2-ops` — Post-deployment operations

Each project was intentionally designed to grow independently. Tight coupling through
shared libraries or a monolithic variable namespace would make it harder to develop,
test, and release each component on its own schedule. The trade-off is that a small
set of variables must carry the same name across projects so that a single inventory
can drive all of them coherently.

These variables form the **shared variable contract** — the stable interface between
rhis-builder components. They are not naming convention violations to be fixed; they
are intentional. The `# noqa: var-naming[no-role-prefix]` suppressions in role
defaults files are correct and should be preserved.

---

## The Contract

### IdM / Kerberos Authentication

These variables are consumed by any role that enrolls a host into IdM, retrieves a
Kerberos keytab, or generates an IdM-signed certificate.

| Variable | Value | Consumers |
|---|---|---|
| `ipa_admin_principal` | `{{ ipa_admin_principal_vault }}` | idm, satellite, kvm |
| `ipa_admin_password` | `{{ ipa_admin_password_vault }}` | idm, satellite, kvm |
| `ipa_server_ca_crt_path` | `/etc/ipa/ca.crt` | idm, satellite, kvm |
| `keytab_retrieval_password` | `{{ ipa_admin_password_vault }}` | satellite, kvm |
| `keytab_retrieval_dn` | `{{ ipa_keytab_dn_vault }}` | satellite, kvm |

There is one IdM deployment in rhis-builder and one set of admin credentials. These
variables are defined globally in `group_vars/all/main.yml.j2` and need not be
overridden per host.

### TLS Certificate Generation

These variables drive the shared certificate generation logic used by any host that
receives an IdM-signed TLS certificate.

| Variable | Default | Consumers |
|---|---|---|
| `crt_service_type` | `"HTTP"` | idm, satellite, kvm |
| `crt_force_regen` | `true` | idm, satellite, kvm |
| `passfile` | derived from `host_ssl_certs_dir` | idm, satellite, kvm |
| `ssl_private_key_cipher` | `"aes256"` | idm, satellite, kvm |
| `ssl_private_key_size` | `4096` | idm, satellite, kvm |
| `ssl_private_key_pem_path` | derived | idm, satellite, kvm |
| `host_ssl_certs_dir` | `/etc/ipa/private/{{ ansible_fqdn }}/` | satellite, kvm |
| `host_ssl_rsa_key_pass` | `{{ host_ssl_rsa_key_pass_vault }}` | satellite, kvm |
| `host_ssl_crt_path` | derived | satellite, kvm |
| `host_ssl_key_path` | derived | satellite, kvm |
| `host_ssl_csr_path` | derived | satellite, kvm |

### CSR Subject Fields

Used by any role that generates a Certificate Signing Request. Values are
site-specific and should be overridden in `inventory_basevars.yml`.

| Variable | Default | Consumers |
|---|---|---|
| `csr_organization_name` | `{{ ansible_domain \| upper }}` | idm, satellite, kvm |
| `csr_organization_unit_name` | `"Demo Lab"` | idm, satellite, kvm |
| `csr_locality_name` | `"Hespeler"` | idm, satellite, kvm |
| `csr_state_or_province_name` | `"ON"` | idm, satellite, kvm |
| `csr_country_name` | `"CA"` | idm, satellite, kvm |
| `csr_digest` | `"aes256"` | satellite, kvm |
| `csr_email_address` | derived | satellite, kvm |

---

## Rules for Managing the Contract

1. **Do not rename these variables** without coordinating changes across every
   consuming project simultaneously. A rename in one project silently breaks
   the others.

2. **Do not remove `# noqa: var-naming[no-role-prefix]` suppressions** from role
   defaults files. These suppressions are correct — the variables intentionally
   lack role prefixes because they are shared.

3. **New shared variables** should be discussed before being added. The contract
   should grow slowly and deliberately. If a variable is only needed by one project,
   it belongs in that project's own defaults, not here.

4. **Overrides** at the host or group level in `inventory_template` are valid and
   expected for site-specific values (CSR subject fields, cert paths, etc.).

---

## Where Each Project Defines These

| Project | Location |
|---|---|
| `rhis-builder-kvm` | `roles/kvm_host/defaults/main.yml` |
| `rhis-builder-satellite` | `inventory_template/host_vars/satellite/satellite_pre.yml` and `host_vars/discosatellite/satellite_pre.yml` |
| `rhis-builder-idm` | `roles/idm_pre/defaults/main.yml` (pending migration — see `schema/variable_migration.md`) |

---

## See Also

- `schema/variables/host_vars/kvm.md` — full variable listing for KVM hypervisors
- `schema/variables/host_vars/satellite.md` — full variable listing for Satellite
- `schema/variables/host_vars/idm.md` — full variable listing for IdM
- `schema/audit_findings.md` Section 3 — original audit findings on naming conventions
- `schema/variable_migration.md` — tracked renames affecting the contract
