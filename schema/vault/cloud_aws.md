# AWS Vault Variables

Schema Version: 1.0.0

These variables are used by `rhis-builder-aws-lz` to bootstrap the AWS landing zone and management zone, and by `rhis-builder-satellite` to configure the AWS compute resource in Satellite. They are also used by Image Builder when deploying cloud images to AWS.

> **Multiple cloud targets:** rhis supports multiple AWS account targets. Variables for each target follow the pattern `<cloud_name><number>_<variable_name>_vault`. For example, `aws1_access_key_vault` is the IAM access key for the first AWS target; a second target would use `aws2_access_key_vault`, and so on. Users can apply the same aliasing technique used throughout the vault file to extend their model with minimal duplication. Unique credentials per target are always recommended in production.

---

## AWS credentials

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `aws1_account_id_vault` | secret | Your 12-digit AWS account number. | Found in the AWS console under your account name (top-right menu). | rhis-builder-aws-lz, rhis-builder-satellite |
| `aws1_access_key_vault` | secret | The AWS IAM access key ID for the service account used by RHIS. | Generate an IAM access key for a dedicated service account in the AWS IAM console. Use a service account with least-privilege permissions. | rhis-builder-aws-lz, rhis-builder-satellite |
| `aws1_secret_key_vault` | secret | The AWS IAM secret access key paired with `aws1_access_key_vault`. | Generated alongside the access key — copy it immediately as it is only shown once. | rhis-builder-aws-lz, rhis-builder-satellite |
| `aws1_gov_cloud_vault` | secret | Boolean flag indicating whether the target account is an AWS GovCloud account. Set to `false` for standard commercial accounts. | Set based on your AWS account type. | rhis-builder-aws-lz |
| `aws1_region_vault` | alias | Alias for `rhis_aws_region` from `inventory_basevars.yml`. The AWS region for all resource operations. | Derived from `inventory_basevars.yml` — set `rhis_aws_region` there. | rhis-builder-aws-lz, rhis-builder-satellite |

---

## Image Builder cloud-init

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `imagebuilder_cloudinit_password_vault` | alias | Password injected via cloud-init when deploying Image Builder images to AWS. Aliased to `default_environment_password_vault` in POC environments. **Set individually in production.** | Set to a strong unique password in production. | rhis-builder-day-2-ops |
