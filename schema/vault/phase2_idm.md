# Phase 2 — IdM Vault Variables

Schema Version: 1.0.0

These variables are used by `rhis-builder-idm` to install and configure Red Hat Identity Management (IdM / FreeIPA). IdM must be fully operational before Phase 3 (Satellite) begins, as Satellite registers to IdM for Kerberos authentication and certificate services.

CDN registration for IdM hosts uses `cdn_activation_key_vault` and `cdn_organization_vault` defined in [common.md](common.md).

---

## IdM administrator credentials

The `redhat.rhel_idm` collection uses different variable names than the rest of rhis-builder. The variables below follow that collection's naming convention and are aliased from the common defaults in POC environments.

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `ipa_admin_principal_vault` | notsecret | The IdM administrator username. Aliased to `default_admin_username_vault` (`admin`) in POC environments. | Set to your chosen IdM admin username. | rhis-builder-idm |
| `ipa_admin_password_vault` | secret | The password for the IdM administrator account. Aliased to `default_environment_password_vault` in POC environments. **Set individually in production.** | Generate a strong unique password. | rhis-builder-idm |
| `ipa_dm_password_vault` | secret | The Directory Manager (DM) password for the IdM LDAP directory. The DM account has unrestricted access to the directory and is separate from the admin account. Aliased to `default_environment_password_vault` in POC environments. **Set individually in production.** | Generate a strong unique password — different from `ipa_admin_password_vault`. | rhis-builder-idm |

---

## IdM service account (principal)

These variables are used for ongoing API interactions with IdM from other rhis-builder phases after the initial installation.

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `ipa_principal_username_vault` | alias | Alias for `ipa_admin_principal_vault`. Used by roles that interact with the IdM API post-installation. | — | rhis-builder-satellite, rhis-builder-aap |
| `ipa_principal_password_vault` | alias | Alias for `ipa_admin_password_vault`. | — | rhis-builder-satellite, rhis-builder-aap |
