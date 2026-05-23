# Vault Variables

Schema Version: 1.0.0

This directory documents all Ansible Vault variables used across the rhis-builder project family. Each file covers one logical group of secrets corresponding to a build phase or infrastructure component.

---

## Files

| File | Contents |
|---|---|
| [common.md](common.md) | Global credentials, SSH keys, Red Hat tokens, CDN registration |
| [cloud_aws.md](cloud_aws.md) | AWS landing zone secrets |
| [cloud_azure.md](cloud_azure.md) | Azure landing zone secrets and IDP configuration |
| [cloud_kvm.md](cloud_kvm.md) | KVM hypervisor and libvirt secrets |
| [cloud_ocp_virt.md](cloud_ocp_virt.md) | OpenShift Virtualization secrets |
| [cloud_vmware.md](cloud_vmware.md) | VMware vCenter secrets |
| [phase2_idm.md](phase2_idm.md) | Phase 2 — Red Hat IdM secrets |
| [phase3_satellite.md](phase3_satellite.md) | Phase 3 — Red Hat Satellite secrets |
| [phase4_aap.md](phase4_aap.md) | Phase 4 — Ansible Automation Platform secrets |
| [quay.md](quay.md) | Red Hat Quay secrets |
| [yubikey.md](yubikey.md) | YubiKey PIV management secrets |

---

## Creating and managing the vault file

The vault file lives at `deployments/<your.domain>/vault/rhis_builder_vault.yml`. A sample template is provided at `inventory_template/vault_SAMPLES/rhis_builder_vault_SAMPLE.yml.j2` and is rendered into your deployment directory when you run `inventory_update.sh`.

**Create and encrypt the vault file:**

```bash
cp deployments/<your.domain>/vault_SAMPLES/rhis_builder_vault_SAMPLE.yml \
   deployments/<your.domain>/vault/rhis_builder_vault.yml

# Edit the file and replace all sample values with real values
vi deployments/<your.domain>/vault/rhis_builder_vault.yml

# Encrypt it
ansible-vault encrypt deployments/<your.domain>/vault/rhis_builder_vault.yml
```

**Edit an encrypted vault file:**

```bash
ansible-vault edit deployments/<your.domain>/vault/rhis_builder_vault.yml
```

**View without decrypting to disk:**

```bash
ansible-vault view deployments/<your.domain>/vault/rhis_builder_vault.yml
```

---

## Conventions

- All vault variable names end with the `_vault` suffix to make their origin immediately identifiable in playbooks and templates.
- Many variables are **aliases** — they reference a common base variable (e.g. `cdn_organization_vault: "{{ default_org_number_vault }}"`). This allows a single value to serve multiple roles while keeping variable names meaningful at the point of use. At runtime the alias resolves to the sensitive value of the underlying variable, so it must be treated with the same care. `no_log: true` is used throughout rhis-builder to ensure that secrets are not logged or inadvertently displayed.
- Variables marked `# notsecret` are present in the vault file for structural convenience but do not represent sensitive credentials. See [../README.md](../README.md) for a full explanation of the annotation.
- For POC environments, many passwords are aliased to `default_environment_password_vault`. **In production deployments, every password should be set individually.**
