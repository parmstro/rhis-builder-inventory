# KVM Vault Variables

Schema Version: 1.0.0

These variables are used by `rhis-builder-kvm` to configure KVM hypervisor hosts and by `rhis-builder-satellite` to configure the libvirt compute resource in Satellite for provisioning virtual machines on bare metal KVM hypervisors.

---

## KVM / libvirt credentials

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `kvm_host_username_vault` | secret | Username for SSH access to KVM hypervisor hosts for management operations. Typically the automation user (`ansiblerunner`). | Set to the SSH user present on KVM hypervisor hosts. | rhis-builder-kvm, rhis-builder-satellite |
| `kvm_host_password_vault` | secret | Password for the KVM hypervisor management user. Aliased to `default_environment_password_vault` in POC environments. **Set individually in production.** | Set to the password for the KVM management user. | rhis-builder-kvm |
| `kvm_ssl_rsa_key_pass_vault` | secret | Passphrase for the SSL RSA key used to secure the libvirt TLS connection between Satellite and KVM hypervisors. Required when Satellite uses TLS to connect to libvirt. Aliased to `default_environment_password_vault` in POC environments. **Set individually in production.** | Generate a strong unique passphrase. | rhis-builder-satellite, rhis-builder-kvm |
