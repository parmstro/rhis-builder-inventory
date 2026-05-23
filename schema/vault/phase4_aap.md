# Phase 4 — AAP Vault Variables

Schema Version: 1.0.0

These variables are used by `rhis-builder-aap` to install and configure Ansible Automation Platform (AAP), including the Controller, Private Automation Hub, and container registry access. AAP is configured last as it depends on both IdM (for LDAP authentication) and Satellite (for content and inventory sources).

---

## CDN credentials for AAP

AAP Controller requires its own subscription manifest. By default these alias the common CDN credentials, but they can be set independently if your AAP subscriptions are held in a different Red Hat account.

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `aap_cdn_username_vault` | alias | Alias for `cdn_username_vault`. Red Hat Customer Portal username for the AAP manifest. Override if AAP subs are in a different account. | — | rhis-builder-aap |
| `aap_cdn_password_vault` | alias | Alias for `cdn_password_vault`. | — | rhis-builder-aap |
| `aap_cdn_account_number_vault` | alias | Alias for `cdn_account_number_vault`. | — | rhis-builder-aap |
| `aap_controller_manifest_zip_vault` | secret | The filesystem path where the AAP Controller manifest ZIP will be staged inside the container. Default is `/tmp/rhis_aap_manifest.zip`. | Set to a writable path inside the container. | rhis-builder-aap |

---

## AAP Controller

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `aap_controller_ssl_rsa_key_pass_vault` | secret | Passphrase for the AAP Controller SSL RSA private key. **Set individually in production.** | Generate a strong unique passphrase. | rhis-builder-aap |
| `aap_admin_username_vault` | secret | AAP Controller administrator username. Must be `admin` — do not change this value. AAP requires an `admin` user to exist at installation time; changing it will cause installation failures. Aliased to `default_admin_username_vault`. | Fixed value: `admin`. | rhis-builder-aap |
| `aap_admin_password_vault` | secret | AAP Controller administrator password. Aliased to `default_environment_password_vault` in POC environments. **Set individually in production.** | Generate a strong unique password. | rhis-builder-aap |
| `aap_pg_password_vault` | secret | PostgreSQL database password for the AAP Controller database. **Set individually in production.** | Generate a strong random password. | rhis-builder-aap |
| `aap_auth_ldap_bind_dn_vault` | secret | The LDAP bind DN used by AAP Controller to query IdM for user authentication. Typically a dedicated service account in IdM. | Create a service account in IdM and use its full DN (e.g. `uid=ldap-lookup,cn=users,cn=accounts,dc=example,dc=ca`). | rhis-builder-aap |
| `aap_auth_ldap_bind_password_vault` | secret | Password for the LDAP bind account. Aliased to `default_environment_password_vault` in POC environments. **Set individually in production.** | Set when creating the IdM service account. | rhis-builder-aap |

---

## Container registry access

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `redhat_registry_username_vault` | secret | Username for authenticating to `registry.redhat.io` to pull AAP container images. This is a registry service account token, not a standard Red Hat login. | Generate a registry service account at console.redhat.com/openshift/create/source-secret. | rhis-builder-aap |
| `redhat_registry_password_vault` | secret | Password (token) for the `registry.redhat.io` service account. | Generated alongside the registry service account. | rhis-builder-aap |

---

## AAP Private Automation Hub

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `aap_hub_ssl_rsa_key_pass_vault` | secret | Passphrase for the Private Automation Hub SSL RSA private key. **Set individually in production.** | Generate a strong unique passphrase. | rhis-builder-aap |
| `aap_registry_username_vault` | alias | Username for authenticating to the upstream Red Hat registry to sync content to Private Hub. Aliased to `cdn_username_vault`. Override if using a separate registry account. | — | rhis-builder-aap |
| `aap_registry_password_vault` | alias | Password for the upstream registry. Aliased to `cdn_password_vault`. | — | rhis-builder-aap |
| `aap_hub_admin_password_vault` | secret | Private Automation Hub administrator password. Aliased to `default_environment_password_vault` in POC environments. **Set individually in production.** | Generate a strong unique password. | rhis-builder-aap |
| `aap_hub_pg_password_vault` | secret | PostgreSQL database password for the Private Automation Hub database. **Set individually in production.** | Generate a strong random password. | rhis-builder-aap |
| `aap_hub_ldap_bind_password_vault` | secret | Password for the LDAP bind account used by Private Hub to authenticate against IdM. Aliased to `default_environment_password_vault` in POC environments. **Set individually in production.** | Set when creating the IdM LDAP service account. | rhis-builder-aap |
| `private_hub_username_vault` | secret | Administrator username for the Private Automation Hub. Must be `admin` — do not change this value. Aliased to `default_admin_username_vault`. | Fixed value: `admin`. | rhis-builder-aap, rhis-builder-day-2-ops |
| `private_hub_password_vault` | secret | Administrator password for the Private Automation Hub. Aliased to `default_environment_password_vault` in POC environments. **Set individually in production.** | Generate a strong unique password. | rhis-builder-aap, rhis-builder-day-2-ops |
| `private_automation_hub_token_vault` | secret | API token generated for a standalone AAP 2.4 Private Automation Hub instance. Used for collection synchronization. | Generate via the Private Hub UI under Collections → API token. | rhis-builder-day-2-ops |

---

## Container host registry

These variables configure container hosts (Quadlet hosts) to authenticate to a container registry.

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `containerhost_registry_vault` | notsecret | The container registry FQDN. Default is `registry.redhat.io`. | Set to your registry hostname. | rhis-builder-quadlet-deploy |
| `containerhost_registry_username_vault` | alias | Registry username for container hosts. Aliased to `cdn_username_vault`. | — | rhis-builder-quadlet-deploy |
| `containerhost_registry_password_vault` | alias | Registry password for container hosts. Aliased to `cdn_password_vault`. | — | rhis-builder-quadlet-deploy |

---

## GitHub integration

These variables allow AAP to interact with GitHub for pulling playbooks, roles, and demo project content.

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `ansible_github_username_vault` | secret | GitHub username for the automation account used by AAP to clone repositories. | Set to the GitHub account that owns the RHIS repositories. | rhis-builder-aap |
| `ansible_github_gpat_vault` | secret | GitHub Personal Access Token (PAT) for the automation account. Requires repo read access at minimum. | Generate at github.com → Settings → Developer settings → Personal access tokens. | rhis-builder-aap |
| `github_demo_username_vault` | secret | GitHub username for the account used to pull and push demo project content. | Set to the GitHub account used for demo repositories. | rhis-builder-day-2-ops |
| `github_demo_gpat_vault` | secret | GitHub Personal Access Token for the demo account. | Generate at github.com → Settings → Developer settings → Personal access tokens. | rhis-builder-day-2-ops |

---

## AAP machine credentials (IdM-managed hosts)

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `aap_idm_machine_username_vault` | secret | Username for the AAP machine credential used to connect to IdM-managed hosts. Aliased to `default_admin_username_vault`. | Set to the user account present on managed hosts. | rhis-builder-aap |
| `aap_idm_machine_password_vault` | secret | Password for the AAP machine credential. Aliased to `default_environment_password_vault` in POC environments. **Set individually in production.** | Set to the password for the machine credential user. | rhis-builder-aap |

---

## Ansible callback

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `satellite_ansible_callback_config_key_vault` | secret | The shared secret key used by the Satellite Ansible callback plugin to authenticate job status updates from managed hosts back to Satellite. | Generate a random hex string: `python3 -c "import secrets; print(secrets.token_hex(16))"` | rhis-builder-satellite, rhis-builder-aap |
