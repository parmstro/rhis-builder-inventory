# Azure Vault Variables

Schema Version: 1.0.0

These variables are used by `rhis-builder-azure-lz` to bootstrap the Azure landing zone and by `rhis-builder-satellite` to configure the Azure compute resource in Satellite. A separate set of IDP variables configures Azure Entra ID as an external identity provider for IdM.

> **Multiple cloud targets:** rhis supports multiple Azure subscription targets. Variables for each target follow the pattern `<cloud_name><number>_<variable_name>_vault`. For example, `azure1_client_id_vault` is the service principal client ID for the first Azure target; a second target would use `azure2_client_id_vault`, and so on. Users can apply the same aliasing technique used throughout the vault file to extend their model with minimal duplication. Unique credentials per target are always recommended in production.

See the Microsoft documentation for creating a service principal: [howto-create-service-principal-portal](https://learn.microsoft.com/en-us/entra/identity-platform/howto-create-service-principal-portal)

---

## Azure service principal credentials

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `azure1_cloud_vault` | secret | The Azure cloud environment identifier. Use `azure` for Azure Commercial, `azure_us_government` for Azure Government. | Set based on your Azure subscription type. | rhis-builder-azure-lz, rhis-builder-satellite |
| `azure1_tenant_id_vault` | secret | The Azure Entra ID tenant (directory) GUID for your organization. | Found in the Azure portal under Entra ID → Overview → Tenant ID. | rhis-builder-azure-lz, rhis-builder-satellite |
| `azure1_subscription_id_vault` | secret | The Azure subscription GUID that RHIS resources will be deployed into. | Found in the Azure portal under Subscriptions. | rhis-builder-azure-lz, rhis-builder-satellite |
| `azure1_client_id_vault` | secret | The application (client) GUID of the service principal used by RHIS. | Found in the Azure portal under Entra ID → App Registrations → your app → Application (client) ID. | rhis-builder-azure-lz, rhis-builder-satellite |
| `azure1_client_secret_desc_vault` | secret | A human-readable label for the client secret (used for identification only). | Choose a meaningful name such as `rhis-builder-secret`. | rhis-builder-azure-lz |
| `azure1_client_secret_id_vault` | secret | The GUID identifier of the client secret. | Found in the Azure portal under Entra ID → App Registrations → your app → Certificates & secrets → Secret ID. | rhis-builder-azure-lz |
| `azure1_client_secret_vault` | secret | The client secret value for the service principal. | Generated in the Azure portal under Entra ID → App Registrations → your app → Certificates & secrets → New client secret. Copy the value immediately — it is only shown once. | rhis-builder-azure-lz, rhis-builder-satellite |
| `azure1_region_vault` | secret | The Azure region for resource deployment (e.g. `canadacentral`, `eastus`). | Set to the Azure region where your resources will be deployed. | rhis-builder-azure-lz, rhis-builder-satellite |
| `azure1_resource_group_vault` | secret | The name of the Azure resource group that will contain RHIS resources. | Create or identify a resource group in the Azure portal. | rhis-builder-azure-lz, rhis-builder-satellite |
| `azure1_user_ssh_key` | notsecret | The public SSH key injected into Azure VM instances for the login user. Edwards 25519 (`ssh-keygen -t ed25519`) is recommended for a balance of speed and security. rhis-builder will move to ML-based post-quantum ciphers when stable implementations exist for all relevant projects. | Generate with `ssh-keygen -t ed25519 -C "ansiblerunner"` and use the contents of `~/.ssh/id_ed25519.pub`. | rhis-builder-azure-lz |

---

## Azure IDP (Identity Provider) configuration

These variables configure Azure Entra ID as an external identity provider for Red Hat IdM, enabling SSO for RHIS users.

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `azure1_idp_secret_vault` | secret | The client secret used by IdM to authenticate to Azure Entra ID as an IDP. | Generated in the Azure portal for the IDP app registration — separate from the deployment service principal. | rhis-builder-idm |
| `azure1_idp_secret_id_vault` | secret | The GUID identifier of the IDP client secret. | Found alongside the secret in the Azure portal → Certificates & secrets. | rhis-builder-idm |
| `azure1_idp_app_id_vault` | secret | The application (client) GUID of the IDP app registration. Equivalent to the client ID for this registration. | Found in the Azure portal under Entra ID → App Registrations → your IDP app → Application (client) ID. | rhis-builder-idm |
