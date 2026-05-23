# Phase 3 — Satellite Vault Variables

Schema Version: 1.0.0

These variables are used by `rhis-builder-satellite` to install and configure Red Hat Satellite. Satellite must be fully operational before Phase 4 (AAP) begins, as AAP depends on Satellite for host registration, content, and dynamic inventory sources.

---

## Satellite administrator credentials

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `satellite_username_vault` | secret | Satellite administrator username. Aliased to `default_admin_username_vault` in POC environments. | Set to your chosen Satellite admin username. | rhis-builder-satellite |
| `satellite_password_vault` | secret | Satellite administrator password. Aliased to `default_environment_password_vault` in POC environments. **Set individually in production.** | Generate a strong unique password. | rhis-builder-satellite |
| `sat_ssl_rsa_key_pass_vault` | secret | Passphrase for the Satellite SSL RSA private key. Aliased to `default_environment_password_vault` in POC environments. **Set individually in production.** | Generate a strong unique passphrase. | rhis-builder-satellite |

---

## Satellite manifest and CDN

These variables authenticate to the Red Hat CDN to create or pull the Satellite subscription manifest.

> These credentials are extremely sensitive — they provide access to your Red Hat subscription entitlements. Do not publish them.

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `cdn_username_vault` | secret | Red Hat Customer Portal username for manifest operations. | Your Red Hat account login (typically an email address). | rhis-builder-satellite |
| `cdn_password_vault` | secret | Red Hat Customer Portal password. | Your Red Hat account password. | rhis-builder-satellite |
| `cdn_account_number_vault` | secret | Your Red Hat account number. | Found on the Red Hat Customer Portal under your account profile. | rhis-builder-satellite |
| `cdn_organization_id_vault` | secret | Your Red Hat organization ID (may differ from account number in multi-org environments). | Found on the Red Hat Customer Portal under your organization settings. | rhis-builder-satellite |
| `cdn_sat_activation_key_vault` | secret | The activation key name used specifically for Satellite CDN registration. | Create an activation key configured for Satellite on the Customer Portal or console.redhat.com. | rhis-builder-satellite |
| `manifest_subs_vault` | secret | A list of subscription pool IDs and quantities to include in the Satellite manifest. Each entry requires `name`, `pool_id`, and `qty`. The `name` field is arbitrary — it exists only to help the user identify subscriptions within the configuration and has no effect on the manifest or build. Pool IDs are tied to your active subscriptions and change as subscriptions are added, renewed, or removed. They should be verified at subscription renewal time and periodically otherwise to prevent failed builds. | Find pool IDs via `subscription-manager list --available` on a registered host or via the Red Hat Customer Portal. | rhis-builder-satellite |

---

## IdM integration

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `ipa_keytab_dn_vault` | secret | The LDAP distinguished name used to pull an existing Kerberos keytab from IdM. Defaults to `cn=Directory Manager`. Only the DM can pull an existing user keytab by default. | Set to an account with sufficient IdM directory permissions. | rhis-builder-satellite |

---

## Remote Execution (REX)

These variables configure the SSH keys and user that Satellite uses for Remote Execution jobs.

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `remote_execution_ssh_keys_vault` | secret | The SSH public key(s) that Satellite will distribute to managed hosts for remote execution. Edwards 25519 (`ssh-keygen -t ed25519`) is recommended for a balance of speed and security. rhis-builder will move to ML-based post-quantum ciphers when stable implementations exist for all relevant projects. | Generate a dedicated REX key pair with `ssh-keygen -t ed25519 -C "satellite-rex"` and use the contents of the resulting `.pub` file. | rhis-builder-satellite |
| `remote_execution_ssh_user_vault` | secret | The username Satellite uses for SSH remote execution connections. Aliased to `rhis_builder_default_user`. On AWS instances this is typically `ec2-user`. | Set to the username present on managed hosts that allows SSH access. | rhis-builder-satellite |

---

## Compute resources

These variables configure Satellite's connection to VMware vCenter for provisioning virtual machines.

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `vcenter_service_username_vault` | alias | Alias for `vmware1_vcenter_username_vault`. The vCenter service account username used by Satellite compute resources. See [cloud_vmware.md](cloud_vmware.md). | — | rhis-builder-satellite |
| `vcenter_service_password_vault` | alias | Alias for `vmware1_vcenter_password_vault`. | — | rhis-builder-satellite |

---

## virt-who

virt-who reports hypervisor guest mappings to Satellite for subscription management. It requires its own service account credentials for both vCenter access and Satellite API access.

See: [Red Hat KB — virt-who configuration](https://access.redhat.com/solutions/495683), [virt-who article](https://access.redhat.com/articles/1553923)

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `vcenter_virtwho_username_vault` | alias | vCenter username for virt-who. Aliased to `vcenter_service_username_vault` in POC environments. virt-who only reads guest-to-hypervisor mappings and requires no write access — in production, use a dedicated read-only vCenter service account to reduce attack surface. | — | rhis-builder-satellite |
| `vcenter_virtwho_password_vault` | alias | vCenter password for virt-who. Aliased to `vmware1_vcenter_password_vault`. | — | rhis-builder-satellite |
| `satellite_virtwho_username_vault` | alias | Satellite username that virt-who uses to update Satellite with discovered VMs and hypervisors. Unlike the vCenter account, this account requires write access to Satellite. Create a dedicated account with the minimum necessary privileges — consult the KB articles and documentation linked in the virt-who section above for exact role requirements. Aliased to `satellite_username_vault` in POC environments. | — | rhis-builder-satellite |
| `satellite_virtwho_password_vault` | alias | Satellite password for virt-who. Aliased to `default_environment_password_vault` in POC environments. **Set individually in production.** | — | rhis-builder-satellite |

---

## Email (SMTP)

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `satellite_smtp_user_name_vault` | secret | The SMTP username for Satellite email notifications. Convention is `satellite@<domain>`. | Set to the email account Satellite will send from. | rhis-builder-satellite |
| `satellite_smtp_password_vault` | secret | The SMTP password or app password for the Satellite email account. | For Gmail, generate an app password under your Google account security settings. | rhis-builder-satellite |
| `satellite_smtp_authentication` | notsecret | The SMTP authentication method. Typically `login` for app-password based auth. | Set based on your mail server requirements. | rhis-builder-satellite |

---

## Provisioning

> **Planned:** A future release of rhis-builder will integrate the [`eigenstate-ipa`](https://github.com/gprocunier/eigenstate-ipa) collection to automatically generate random values for provisioning secrets and escrow them in the IdM Vault. This will provide break-glass and checkout capabilities for the LUKS encryption password and root password, enabling secure, auditable credential recovery without storing plaintext secrets outside the vault.

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `nbde_encryption_password_vault` | secret | The LUKS encryption password used by NBDE (Network-Bound Disk Encryption) during provisioning. Aliased to `default_environment_password_vault` in POC environments. **Set individually in production.** | Generate a strong unique passphrase. | rhis-builder-satellite, rhis-builder-nbde |
| `default_provisioning_root_password_vault` | secret | The root password set on hosts provisioned by Satellite. Aliased to `default_environment_password_vault` in POC environments. **Set individually in production.** | Generate a strong unique password. | rhis-builder-satellite |
