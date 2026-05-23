# KVM Vault Variables

Schema Version: 1.0.0

These variables will be used by `rhis-builder-kvm-lz` (planned) to bootstrap KVM hypervisor hosts and by `rhis-builder-satellite` to configure the libvirt compute resource in Satellite for provisioning virtual machines on bare metal KVM hypervisors.

> **Multiple cloud targets:** rhis supports multiple KVM hypervisor targets. Variables for each target follow the pattern `<cloud_name><number>_<variable_name>_vault`. For example, `kvm1_host_username_vault` is the management username for the first KVM target; a second target would use `kvm2_host_username_vault`, and so on. Users can apply the same aliasing technique used throughout the vault file to extend their model with minimal duplication. Unique credentials per target are always recommended in production.

---

## KVM / libvirt credentials

rhis-builder creates TLS-encrypted connections between Satellite and KVM hypervisors exclusively. When IdM is present, certificates for this connection are generated automatically by IdM as part of the build process. If IdM is not used, users must update the relevant configuration and supply their own certificate files before running the build.

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `kvm_host_username_vault` | secret | Username for SSH access to KVM hypervisor hosts for management operations. Typically the automation user (`ansiblerunner`). | Set to the SSH user present on KVM hypervisor hosts. | rhis-builder-kvm-lz, rhis-builder-satellite |
| `kvm_host_password_vault` | secret | Password for the KVM hypervisor management user. Aliased to `default_environment_password_vault` in POC environments. **Set individually in production.** | Set to the password for the KVM management user. | rhis-builder-kvm-lz |
| `kvm_ssl_rsa_key_pass_vault` | secret | Passphrase for the RSA key used to secure the libvirt TLS connection between Satellite and KVM hypervisors. When IdM is used, the certificate is issued by IdM; this passphrase protects the private key. Aliased to `default_environment_password_vault` in POC environments. **Set individually in production.** | Generate a strong unique passphrase. | rhis-builder-satellite, rhis-builder-kvm-lz |
