# KVM Hypervisor Host Variables

Variables defined in `rhis-builder-kvm/roles/kvm_host/defaults/main.yml` and
consumed by the `kvm_host` role. KVM hypervisors are provisioned hosts and do not
have dedicated `host_vars/` files in `inventory_template` — these defaults apply
to all members of the `kvm_hypervisor_hosts` inventory group unless overridden in
`group_vars/provisioner/kvm_hypervisor_hosts.yml`.

---

## Async Control

| Variable | Type | Default | Description |
|---|---|---|---|
| `kvm_host_async_timeout` | integer | `14400` | Maximum seconds for async tasks in the kvm_host role |
| `kvm_host_async_delay` | integer | `15` | Poll interval in seconds for async tasks |

---

## Shared Infrastructure Variables — Cross-Role Contract

The following variables form a shared interface contract with **rhis-builder-satellite**
and **rhis-builder-idm**. They carry `# noqa: var-naming[no-role-prefix]` suppressions
intentionally — see `schema/shared_variable_contract.md` for the full rationale.

### IdM / Kerberos Integration

| Variable | Type | Default | Description |
|---|---|---|---|
| `keytab_retrieval_password` | string | `{{ ipa_admin_password_vault }}` | Password used to retrieve the libvirt service keytab from IdM |
| `keytab_retrieval_dn` | string | `{{ ipa_keytab_dn_vault }}` | LDAP DN used for keytab retrieval |
| `ipa_admin_principal` | string | `{{ ipa_admin_principal_vault }}` | IdM admin principal for certificate and keytab operations |
| `service_keytab` | string | `/etc/{{ crt_service_type }}/krb5.keytab` | Path where the libvirt service Kerberos keytab is stored |

### TLS Certificate Paths (host cert and key)

| Variable | Type | Default | Description |
|---|---|---|---|
| `host_ssl_certs_dir` | string | `/etc/ipa/private/{{ ansible_fqdn }}/` | Directory for all TLS certificate files on this host |
| `host_ssl_rsa_key_pass` | string | `{{ host_ssl_rsa_key_pass_vault }}` | Passphrase protecting the RSA private key |
| `host_ssl_crt_path` | string | derived | Path to the host's primary TLS certificate |
| `host_ssl_key_path` | string | derived | Path to the host's primary TLS private key |
| `host_ssl_csr_path` | string | derived | Path to the host's primary CSR |
| `ipa_server_ca_crt_path` | string | `/etc/ipa/ca.crt` | Path to the IdM CA certificate |
| `passfile` | string | derived | Path to the passphrase file used during key generation |
| `ssl_private_key_cipher` | string | `"aes256"` | Cipher algorithm for the private key |
| `ssl_private_key_size` | integer | `4096` | RSA key size in bits |
| `ssl_private_key_pem_path` | string | derived | Path to the PEM-format private key |
| `crt_service_type` | string | `"HTTP"` | IPA service type for the host's primary certificate |
| `crt_force_regen` | boolean | `true` | Force certificate regeneration even if one already exists |

### CSR Subject Fields

| Variable | Type | Default | Description |
|---|---|---|---|
| `csr_organization_name` | string | `{{ ansible_domain \| upper }}` | Organization name in the CSR subject |
| `csr_organization_unit_name` | string | `"Demo Lab"` | Organizational unit in the CSR subject |
| `csr_locality_name` | string | `"Hespeler"` | Locality in the CSR subject |
| `csr_state_or_province_name` | string | `"ON"` | Province or state in the CSR subject |
| `csr_country_name` | string | `"CA"` | Country code in the CSR subject |

---

## libvirt Mutual TLS Certificate Variables

KVM hypervisors connect to Satellite as a compute resource via `qemu+tls://`. This
requires **mutual TLS authentication** — both the KVM hypervisor and the Satellite
server carry client and server certificates, so either end can initiate a connection.

Both the `libvirt_client_*` and `libvirt_server_*` variable sets are provisioned on
**both** the KVM hypervisor (by `rhis-builder-kvm`) and the Satellite server (by
`rhis-builder-satellite`). The service types are IdM service principals enrolled via
the IPA certificate API.

**Why both sides need both certificate types:**
- The KVM hypervisor runs the libvirt daemon (`qemu+tls://` server) — needs a **server** cert
- The Satellite server connects to libvirt as a client — needs a **client** cert
- Satellite can also be contacted by libvirt — needs a **server** cert
- The KVM hypervisor connects back to Satellite — needs a **client** cert

See also: `schema/variables/host_vars/satellite.md` — libvirt TLS section.

### libvirt Client Certificate (presented when this host connects to a remote libvirt)

| Variable | Type | Default | Description |
|---|---|---|---|
| `libvirt_client_private_key_pem_path` | string | derived | PEM-format private key for the libvirt client certificate |
| `libvirt_client_key_path` | string | derived | Path to the libvirt client private key |
| `libvirt_client_csr_path` | string | derived | Path to the libvirt client CSR |
| `libvirt_client_crt_path` | string | derived | Path to the libvirt client certificate |
| `libvirt_client_crt_service_type` | string | `"libvirtclient"` | Kerberos service type for the libvirt client certificate |

### libvirt Server Certificate (presented when remote hosts connect to this host's libvirt daemon)

| Variable | Type | Default | Description |
|---|---|---|---|
| `libvirt_server_private_key_pem_path` | string | derived | PEM-format private key for the libvirt server certificate |
| `libvirt_server_key_path` | string | derived | Path to the libvirt server private key |
| `libvirt_server_csr_path` | string | derived | Path to the libvirt server CSR |
| `libvirt_server_crt_path` | string | derived | Path to the libvirt server certificate |
| `libvirt_server_crt_service_type` | string | `"libvirt"` | Kerberos service type for the libvirt server certificate |

### Default path pattern

All certificate paths follow the convention:

```
{{ host_ssl_certs_dir }}{{ ansible_fqdn }}.libvirt.<role>.<ext>
```

Where `<role>` is `client` or `server` and `<ext>` is `pem`, `key`, `csr`, or `crt`.

---

## Non-IdM TLS Path

The libvirt mutual TLS setup described above assumes Satellite is registered to IdM
and certificates are enrolled via the IPA certificate API. If Satellite is **not**
registered to IdM but the customer still wants a secure `qemu+tls://` connection:

1. Obtain or generate the required certificate files externally.
2. Place them in the `files/` directory of the inventory.
3. Override the `libvirt_client_*` and `libvirt_server_*` path variables in the
   appropriate `host_vars` to point to those file locations.
4. Set `libvirt_non_idm_ca_crt_path` to the path of the CA certificate that signed
   the libvirt certificates, so the connecting host can verify the server's identity.

`libvirt_non_idm_ca_crt_path` is unused in the IdM-integrated path and has no
default — it only needs to be set when operating outside IdM.
