# VMware Vault Variables

Schema Version: 1.0.0

These variables authenticate to VMware vCenter for bootstrapping RHIS hosts on VMware infrastructure and for configuring the vCenter compute resource in Satellite. A service account with appropriate permissions is strongly recommended over using a personal administrator account.

See: [Red Hat KB — Permissions required for vCenter service account](https://access.redhat.com/solutions/1339483)

---

## vCenter credentials

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `vmware1_vcenter_username_vault` | secret | Username for the vCenter service account used by RHIS. Format is typically `user@vsphere.local` or `DOMAIN\user`. | Create a dedicated vCenter service account with the minimum permissions documented in the KB article above. | rhis-builder-vmwarelz, rhis-builder-satellite |
| `vmware1_vcenter_password_vault` | secret | Password for the vCenter service account. | Set when creating the vCenter service account. | rhis-builder-vmwarelz, rhis-builder-satellite |
| `vmware1_datacenter_name_vault` | notsecret | The name of the vCenter datacenter object that RHIS resources will be deployed into. In greenfield environments this defaults to the global domain name. Set explicitly for brownfield deployments. | Found in the vSphere client under the datacenter tree. | rhis-builder-vmwarelz, rhis-builder-satellite |
| `vmware1_vcenter_hostname_vault` | derived | The FQDN or IP address of the vCenter server. Derived from the inventory (`groups['vmware_vcenter_hosts'][0]`). Override manually if not using a vCenter inventory group. | Set the `vmware_vcenter_hosts` group in your inventory, or override with the literal vCenter hostname. | rhis-builder-vmwarelz, rhis-builder-satellite |
