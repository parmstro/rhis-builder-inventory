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
| `default_admin_username_vault` | notsecret | The administrator username expected by IdM, Satellite, and AAP installations. Convention is `admin`. | Set to your chosen admin username. | Phase 2, 3, 4 |

---

## SSH keys

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `default_ssh_pub_key_vault` | notsecret | The public SSH key embedded in provisioned hosts so the provisioner can reach them after installation. | Run `ssh-keygen` on the provisioner and use the contents of `~/.ssh/id_rsa.pub` or equivalent. | Phase 1 (baremetal-init kickstart), all phases |
| `ssh_pub_key_vault` | alias | Alias for `default_ssh_pub_key_vault`. | — | All phases |

---

## Red Hat Hybrid Cloud Console tokens

These tokens authenticate to the Red Hat Hybrid Cloud Console for Automation Hub collection sync and Image Builder. Obtain them from [console.redhat.com/ansible/automation-hub/token](https://console.redhat.com/ansible/automation-hub/token).

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `automation_hub_url_vault` | notsecret | The URL for the published Automation Hub content. | Fixed value — use the Red Hat hosted URL. | rhis-builder-provisioner, rhis-builder-day-2-ops |
| `automation_hub_auth_url_vault` | notsecret | The SSO URL used to authenticate to Automation Hub. | Fixed value — use the Red Hat SSO URL. | rhis-builder-provisioner, rhis-builder-day-2-ops |
| `redhat_automation_hub_token_vault` | secret | The offline token for authenticating to the Red Hat Automation Hub to sync collections. | Generate at console.redhat.com/ansible/automation-hub/token. Rotates — regenerate if expired. | rhis-builder-provisioner, rhis-builder-day-2-ops |
| `automation_hub_token_refresh_cmd_vault` | derived | The curl command used to refresh the Automation Hub token. | Derived from `redhat_automation_hub_token_vault` — do not set manually unless customizing the refresh flow. | rhis-builder-provisioner |
| `imagebuilder_offline_token_vault` | secret | The offline token for authenticating to the Red Hat Image Builder service. | Generate at console.redhat.com/ansible/automation-hub/token (same page, separate token). | rhis-builder-day-2-ops |
| `imagebuilder_offline_token_refresh_cmd_vault` | derived | The curl command used to refresh the Image Builder token. | Derived from `imagebuilder_offline_token_vault` — do not set manually unless customizing. | rhis-builder-day-2-ops |

---

## Red Hat CDN registration

These credentials register the primary Satellite server and any bootstrap hosts to the Red Hat CDN. The `cdn_` aliases are used by roles that require a specific naming convention.

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `default_org_number_vault` | notsecret | Your Red Hat organization number (a plain integer, no quotes). | Found on the Activation Keys page at console.redhat.com or access.redhat.com. | Phase 1, 3 |
| `default_activation_key_vault` | notsecret | The name of the Red Hat activation key used for registering bootstrap hosts. | Create an activation key at console.redhat.com/insights/connector/activation-keys. | Phase 1, 3 |
| `cdn_organization_vault` | alias | Alias for `default_org_number_vault`. Used by roles that expect this naming convention. | — | Phase 1, 3 |
| `cdn_activation_key_vault` | alias | Alias for `default_activation_key_vault`. Used by roles that expect this naming convention. | — | Phase 1, 3 |
