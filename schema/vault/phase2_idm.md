# Phase 2 — IdM Vault Variables

Schema Version: 1.0.0

These variables are used by `rhis-builder-idm` to install and configure Red Hat Identity Management (IdM / FreeIPA).

---

## Why IdM is strongly recommended

RHIS strongly recommends deploying IdM for centralized, comprehensive, and secure policy management across a RHEL infrastructure. IdM provides a unified control plane for identity, access, and certificate services that would otherwise require multiple independent solutions to replicate.

**If using IdM with RHIS, IdM must be deployed prior to Satellite.** Satellite integrates with IdM for Kerberos authentication, certificate issuance, and DNS — these integrations are configured at Satellite install time and require a functioning IdM environment.

RHIS supports deploying Satellite without IdM integration, however there are significant advantages lost and a corresponding increase in the external automation that must be created and maintained to achieve equivalent results. Users who choose not to deploy IdM are responsible for providing their own automation to manage:

- Host domain and realm registration
- Sudo policy configuration and distribution
- DNS record management
- Host-based access control (HBAC)
- PKI / certificate management and renewal
- And more

CDN registration for IdM hosts uses `cdn_activation_key_vault` and `cdn_organization_vault` defined in [common.md](common.md).

---

## IdM administrator credentials

The `redhat.rhel_idm` collection uses different variable names than the rest of rhis-builder. The variables below follow that collection's naming convention and are aliased from the common defaults in POC environments.

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `ipa_admin_principal_vault` | secret | The IdM administrator username. Must be `admin` — do not change this value. IdM requires an `admin` user to exist at installation time; changing it will cause installation failures. Aliased to `default_admin_username_vault`. | Fixed value: `admin`. | rhis-builder-idm |
| `ipa_admin_password_vault` | secret | The password for the IdM administrator account. Aliased to `default_environment_password_vault` in POC environments. **Set individually in production.** | Generate a strong unique password. | rhis-builder-idm |
| `ipa_dm_password_vault` | secret | The Directory Manager (DM) password for the IdM LDAP directory. The DM principal is fixed at `cn='Directory Manager'` and cannot be changed. **This is an extremely sensitive secret.** The DM account has unrestricted superuser privilege over the entire IdM domain — it bypasses all access controls and can read, modify, or delete any entry in the directory. It is separate from the admin account and must be set to a strong, unique value in all environments. Aliased to `default_environment_password_vault` in POC environments. **Set individually in production.** | Generate a strong unique password — must differ from `ipa_admin_password_vault`. | rhis-builder-idm |

---

## IdM service account (principal)

These variables are used for ongoing API interactions with IdM from other rhis-builder phases after the initial installation.

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `ipa_principal_username_vault` | alias | Alias for `ipa_admin_principal_vault`. Used by roles that interact with the IdM API post-installation. | — | rhis-builder-satellite, rhis-builder-aap |
| `ipa_principal_password_vault` | alias | Alias for `ipa_admin_password_vault`. | — | rhis-builder-satellite, rhis-builder-aap |
