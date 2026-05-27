# Group Variables

Schema Version: 1.0.0

Group variables apply to all hosts that are members of the named Ansible inventory group. In rhis-builder, groups map to infrastructure roles (IdM replicas, Satellite, AAP, etc.). Files ending in `.j2` are Jinja2 templates rendered per deployment.

---

## Files

| File | Group | Contents |
|---|---|---|
| [all.md](all.md) | `all` | Global domain, network, and time variables applied to every host |
| [idm_replicas.md](idm_replicas.md) | `idm_replicas` | Pre-deployment and setup variables for IdM replica servers |
| [imagebuilders.md](imagebuilders.md) | `imagebuilders` | OSBuild Composer configuration for Image Builder hosts |
| [keycloak_servers.md](keycloak_servers.md) | `keycloak_servers` | Keycloak installation parameters |
| [platform_installer.md](platform_installer.md) | `platform_installer` | AAP platform installer: credentials, manifests, settings, templates, and workflows |
| [provisioner.md](provisioner.md) | `provisioner` | Provisioner host configuration: IdM, PIV/YubiKey, host lists, resource limits |
| [quay_servers.md](quay_servers.md) | `quay_servers` | Quay registry configuration and secrets |
