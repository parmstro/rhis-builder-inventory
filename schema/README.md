# rhis-builder-inventory Schema Documentation

Schema Version: 1.0.0

The schema version corresponds to the value in `version.txt` at the repository root. When variables are added, removed, or renamed, `version.txt` is bumped and the relevant schema file is updated in the same commit. This keeps the documentation and the implementation in lockstep.

---

## Directory structure

```
schema/
  README.md                         this file — index and conventions
  TODO.md                           outstanding documentation work, backlog items
  audit_findings.md                 variable audit findings across all rhis-builder projects
  inventory_ordering_conventions.md ordering and formatting rules for satellite config files
  shared_variable_contract.md       cross-project shared variable interface (IdM, Satellite, KVM)
  soe_build_requirements.md         SOE build dependency model, checklist, and lessons learned
  soe_bundle_model.md               SOE bundle and snippet ordering design
  variable_migration.md             variable rename registry with migration scripts
  scripts/
    migrate_inventory_variables.yml  Ansible playbook to apply variable renames to deployments
    migrations.yml                   machine-readable migration registry
  vault/
    README.md             vault overview: creation, encryption, mounting, annotation conventions
    common.md             global credentials, SSH keys, Red Hat tokens, CDN registration
    cloud_aws.md          AWS landing zone secrets
    cloud_azure.md        Azure landing zone secrets and IDP configuration
    cloud_kvm.md          KVM hypervisor and libvirt secrets
    cloud_ocp_virt.md     OpenShift Virtualization secrets
    cloud_vmware.md       VMware vCenter secrets
    phase2_idm.md         Phase 2 — Red Hat IdM secrets
    phase3_satellite.md   Phase 3 — Red Hat Satellite secrets
    phase4_aap.md         Phase 4 — Ansible Automation Platform secrets
    quay.md               Red Hat Quay secrets
    yubikey.md            YubiKey PIV management secrets
  variables/              (planned) non-vault variable documentation
```

---

## Variable classification

Each variable entry in the schema files carries one of the following classifications:

| Classification | Meaning |
|---|---|
| `secret` | A genuinely sensitive value (password, token, private key). Must be stored in an Ansible Vault encrypted file and never committed in plaintext. |
| `notsecret` | Marked with `# notsecret` in the vault sample file. See below. |
| `alias` | A variable that references another variable by name (e.g. `cdn_organization_vault: "{{ default_org_number_vault }}"`). At runtime the alias resolves to the sensitive value of the underlying variable and must be treated with the same care. `no_log: true` is used throughout rhis-builder to prevent secrets from being logged or inadvertently displayed. |
| `derived` | A value computed at runtime from other variables or facts (e.g. a URL assembled from a hostname). Does not need to be set manually unless overriding the default. |

### Why aliases exist

Aliases serve two distinct purposes in rhis-builder:

**1. Cross-project naming normalization** — rhis-builder integrates a large number of Ansible collections and upstream projects. Not all of them follow the same variable naming conventions. Rather than forcing users to track multiple naming schemes, rhis-builder defines variables using a consistent naming convention across the entire project group and uses aliases to map those names to whatever the underlying collection or project actually expects. At runtime the alias resolves to the sensitive value of the underlying variable, so it carries the same sensitivity. `no_log: true` is used throughout rhis-builder to prevent secrets from being logged or inadvertently displayed.

**2. POC defaults vs. production isolation** — Many security-sensitive variables (usernames, passwords) are aliased to shared defaults such as `default_environment_password_vault` or `default_environment_username_vault`. This makes it straightforward to stand up a proof-of-concept environment with a single shared credential. Each aliased variable also has its own unique counterpart so that, in production deployments where security takes precedence over convenience, every service can be given a distinct credential. Setting the unique variable to an explicit value rather than the aliased expression is all that is required to override the default.

---

## The `# notsecret` annotation

Variables marked `# notsecret` in the vault sample files carry an annotation used by repository scanning plugins to indicate that the value, while present in the vault file, is not considered sensitive data. Examples include usernames, public URLs, region identifiers, and activation key names.

The annotation does not change how the variable is handled at runtime — all variables in the vault file are encrypted together. It exists solely as a signal to automated secret-scanning tooling that the flagged value does not represent a leaked credential.

> **Note:** The `# notsecret` values present in the vault sample files are examples only. They are not used in any production or testing environment and must be replaced with real values before use.

> **Note:** Whether secret-scanning plugins are active in your repository depends on your GitHub organization configuration. Consult your organization's security posture documentation to confirm.

---

## How to read the variable tables

Each schema file contains one or more tables in the following format:

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `variable_name_vault` | secret / notsecret / alias / derived | What the variable represents | Where to get or how to generate the value | Which rhis-builder phase or project consumes it |
