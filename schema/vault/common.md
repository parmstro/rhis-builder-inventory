# Common Vault Variables

Schema Version: 1.0.0

These variables are global across the entire rhis-builder project family. They establish the default user identity, a shared password baseline for POC environments, SSH key distribution, and the Red Hat CDN and Hybrid Cloud Console credentials that all phases depend on.

---

## Default user and password

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `rhis_builder_default_user` | notsecret | The username of the automation user that runs Ansible against platform systems during the build. Convention is `ansiblerunner`. | Set to the OS user that will execute the provisioner. | All phases |
| `default_environment_username_vault` | alias | Alias for `rhis_builder_default_user`. | — | All phases |
| `default_environment_password_vault` | secret | The default password for the automation user and, in POC environments, all service accounts. **Set individually per account in production.** | Generate a strong random password. | All phases |
| `default_admin_username_vault` | notsecret | The administrator username expected by IdM and AAP at installation time. Must be `admin` — do not change this value. IdM and AAP both require an `admin` user to exist during initial setup; changing it will cause installation failures. Satellite has a separate initial admin username concept documented in the Phase 3 schema. | Fixed value: `admin`. | Phase 2, 3, 4 |

---

## SSH keys

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `default_ssh_pub_key_vault` | notsecret | The public SSH key embedded in provisioned hosts so the provisioner can reach them after installation. A strong cryptographic cipher is recommended. The current recommendation for a balance of speed and security is Edwards 25519 (`ssh-keygen -t ed25519`). Post-quantum cryptography (PQC) ML-based algorithms are the future direction, but not all components in rhis-builder support them at this time. | Generate with `ssh-keygen -t ed25519 -C "ansiblerunner"` on the provisioner and use the contents of `~/.ssh/id_ed25519.pub`. | Phase 1 (baremetal-init kickstart), all phases |
| `ssh_pub_key_vault` | alias | Alias for `default_ssh_pub_key_vault`. | — | All phases |

---

## Red Hat service tokens

Two separate Red Hat services require offline tokens:

- **Ansible Automation Hub** — tokens are generated at [console.redhat.com/ansible/automation-hub/token](https://console.redhat.com/ansible/automation-hub/token). Used to authenticate collection sync from the Red Hat hosted Automation Hub.
- **Red Hat Image Builder** — tokens are generated at [access.redhat.com/management/api](https://access.redhat.com/management/api). Used to authenticate requests to the Image Builder service for building cloud images.

Both tokens are offline tokens but will expire after 30 days of inactivity. It is strongly recommended to configure Ansible scheduled tasks to refresh them periodically to prevent unexpected authentication failures mid-deployment. The `_refresh_cmd_vault` derived variables below provide the curl commands used for this purpose.

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `automation_hub_url_vault` | notsecret | The URL for the published Automation Hub content. | Fixed value — use the Red Hat hosted URL. | rhis-builder-provisioner, rhis-builder-day-2-ops |
| `automation_hub_auth_url_vault` | notsecret | The SSO URL used to authenticate to Automation Hub. | Fixed value — use the Red Hat SSO URL. | rhis-builder-provisioner, rhis-builder-day-2-ops |
| `redhat_automation_hub_token_vault` | secret | The offline token for authenticating to the Red Hat Automation Hub to sync collections. | Generate at [console.redhat.com/ansible/automation-hub/token](https://console.redhat.com/ansible/automation-hub/token). Regenerate if revoked or rotated. | rhis-builder-provisioner, rhis-builder-day-2-ops |
| `automation_hub_token_refresh_cmd_vault` | derived | The curl command used to refresh the Automation Hub token. | Derived from `redhat_automation_hub_token_vault` — do not set manually unless customizing the refresh flow. | rhis-builder-provisioner |
| `imagebuilder_offline_token_vault` | secret | The offline token for authenticating to the Red Hat Image Builder service. | Generate at [access.redhat.com/management/api](https://access.redhat.com/management/api). Regenerate if revoked or rotated. | rhis-builder-day-2-ops |
| `imagebuilder_offline_token_refresh_cmd_vault` | derived | The curl command used to refresh the Image Builder token. | Derived from `imagebuilder_offline_token_vault` — do not set manually unless customizing. | rhis-builder-day-2-ops |

---

## Red Hat CDN registration

These credentials register the primary Satellite server and any bootstrap hosts to the Red Hat CDN. The `cdn_` aliases are used by roles that require a specific naming convention.

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `default_org_number_vault` | secret | Your Red Hat organization number (a plain integer, no quotes). **This is a critical secret — treat it with the same care as a password.** It uniquely identifies your Red Hat account and can be used to gain access to your subscription entitlements. Guard it carefully and do not share it outside your organization. | Found on the Activation Keys page at console.redhat.com or access.redhat.com. | Phase 1, 3 |
| `default_activation_key_vault` | secret | The name of the Red Hat activation key used for registering bootstrap hosts. | Create an activation key at console.redhat.com/insights/connector/activation-keys. | Phase 1, 3 |
| `cdn_organization_vault` | alias | Alias for `default_org_number_vault`. Used by roles that expect this naming convention. | — | Phase 1, 3 |
| `cdn_activation_key_vault` | alias | Alias for `default_activation_key_vault`. Used by roles that expect this naming convention. | — | Phase 1, 3 |
