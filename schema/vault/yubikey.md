# YubiKey Vault Variables

Schema Version: 1.0.0

These variables are used by `rhis-builder-yubi` to configure YubiKey PIV smart card management for RHIS administrators. PIV (Personal Identity Verification) enables certificate-based authentication to IdM and SSH.

---

## PIV management credentials and paths

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `piv_mgmt_pin_vault` | secret | The PIV card management PIN. Used to perform administrative operations on the YubiKey (e.g. generating keys, writing certificates). Default PIV management key PINs are `123456` — change immediately on first use. | Set to a unique PIN of 6–8 digits. | rhis-builder-yubi |
| `piv_mgmt_fips_pin_vault` | secret | The FIPS-mode PIV management PIN. Required when operating YubiKeys in FIPS 140-2 mode, which enforces an 8-digit minimum PIN. | Set to a unique 8-digit PIN. | rhis-builder-yubi |
| `piv_secure_dir_vault` | secret | The filesystem path on the provisioner where YubiKey PIV certificates and keys are staged during configuration. Default is `/root/yubico`. | Set to a directory accessible only by root on the provisioner. | rhis-builder-yubi |
| `piv_vault_dir_vault` | secret | The filesystem path on the provisioner where the PIV vault files (encrypted key material) are stored. Default is `/root/vault`. | Set to a directory accessible only by root on the provisioner. | rhis-builder-yubi |
