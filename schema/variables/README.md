# rhis-builder-inventory Variable Documentation

Schema Version: 1.0.0

This directory documents the non-vault variables defined in `inventory_template/group_vars/` and `inventory_template/host_vars/`. These variables drive the configuration of every component in the rhis-builder stack.

Vault-encrypted secrets are documented separately under [../vault/](../vault/).

---

## Directory structure

```
schema/variables/
  README.md               this file — index and conventions
  group_vars/
    README.md             group_vars overview and index
    all.md                variables applied to all hosts (domain, network, time)
    idm_replicas.md       IdM replica pre-deployment and setup variables
    imagebuilders.md      OSBuild / Image Builder configuration
    keycloak_servers.md   Keycloak installation parameters
    platform_installer.md AAP platform installer variables (credentials, manifests, settings, templates, workflows)
    provisioner.md        Provisioner host variables (IdM, PIV, host lists, timeouts)
    quay_servers.md       Quay registry configuration
  host_vars/
    README.md             host_vars overview and index
    idm.md                IdM primary server variables (DNS, HBAC, users, hardening)
    satellite.md          Primary Satellite server variables
    discosatellite.md     Disconnected Satellite server variables
    aap.md                AAP Controller and Hub host variables (versions 2.4 and 2.6)
    capsule.md            Satellite Capsule host variables
    quadlet.md            Quadlet container host variables
    quay.md               Quay registry host variables
```

---

## Conventions

- Variable files ending in `.j2` are Jinja2 templates rendered by `inventory_update.yml` into your `deployments/<domain>/` directory. Do not edit the rendered output — edit the template source in `inventory_template/`.
- Variables prefixed with `_` (e.g. `_runtime_global_domain_name`) are internal computed values derived at runtime and should not be set manually.
- Variables referencing vault secrets follow the pattern `some_var: "{{ some_var_vault }}"`. The `_vault` suffix always indicates the value lives in the encrypted vault file. See [../vault/](../vault/) for documentation of vault variables.
- Where variables are consumed by upstream Ansible collections, the authoritative reference for allowed values and behaviour is the upstream collection documentation. Links are provided in each section.

---

## How to read the variable tables

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `variable_name` | string / list / dict / bool / int | The default value if one exists, or `—` if required | What the variable controls | Which rhis-builder phase or upstream collection consumes it |
