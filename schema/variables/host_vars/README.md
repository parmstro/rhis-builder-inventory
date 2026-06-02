# Host Variables

Schema Version: 1.0.0

Host variables apply to a single named host in the Ansible inventory. In rhis-builder, each host directory under `inventory_template/host_vars/` corresponds to a logical infrastructure role rather than a literal hostname. The actual hostname is substituted at render time by `inventory_update.yml`.

Files ending in `.j2` are Jinja2 templates rendered per deployment into `deployments/<domain>/host_vars/<actual-hostname>/`.

---

## Files

| File | Host role | Contents |
|---|---|---|
| [idm.md](idm.md) | `idm` | IdM primary server: DNS, HBAC, users, groups, hardening, password policy |
| [satellite.md](satellite.md) | `satellite` | Primary Satellite: content, provisioning, compute resources, settings |
| [discosatellite.md](discosatellite.md) | `discosatellite` | Disconnected Satellite: content imports, exports, and air-gapped configuration |
| [aap.md](aap.md) | `aapcontroller24`, `aapcontroller26`, `aaphub24`, `aaphub26` | AAP Controller and Private Hub host variables for versions 2.4 and 2.6 |
| [capsule.md](capsule.md) | `capsule` | Satellite Capsule server configuration |
| [quadlet.md](quadlet.md) | `quadlet` | Quadlet container host configuration |
| [quay.md](quay.md) | `quay1` | Quay registry host configuration |
