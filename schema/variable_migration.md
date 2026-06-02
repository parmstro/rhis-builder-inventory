# Variable Migration Registry

This file tracks variable renames across rhis-builder projects. Each entry
documents a deprecated name, its replacement, the affected inventory_template
files, and the status of the migration.

The schema update script (`schema/scripts/migrate_variables.sh`) reads this file
and applies renames to a user's existing deployed inventory. Users who regenerate
their inventory from the updated `inventory_template` receive the new names
automatically and do not need to run the script.

---

## How to Add an Entry

Add a new `## Migration` block below, following the format of existing entries.
Set `status` to `pending` until the rename is applied to `inventory_template`
and the consuming project, then change to `complete`.

---

## Migration: async_timeout → satellite_async_timeout

```
deprecated:    async_timeout
replacement:   satellite_async_timeout
project:       rhis-builder-satellite
date:          2026-05-26
status:        complete
```

**Reason:** `async_timeout` violated the role-prefix naming convention. The
unqualified name risked collision with similarly-named variables in rhis-builder-idm
and rhis-builder-kvm, which define their own async control variables.

**Inventory_template files updated (already renamed):**
- `host_vars/satellite/satellite_pre.yml`
- `host_vars/discosatellite/satellite_pre.yml`

**Script target pattern:**
Search satellite and discosatellite host_vars for lines matching
`^async_timeout:` and rename to `satellite_async_timeout:`.

```bash
# satellite_async_timeout migration
sed -i 's/^async_timeout:/satellite_async_timeout:/' \
    "${INVENTORY_DIR}/host_vars/satellite/satellite_pre.yml" \
    "${INVENTORY_DIR}/host_vars/discosatellite/satellite_pre.yml"
```

---

## Migration: async_delay → satellite_async_delay

```
deprecated:    async_delay
replacement:   satellite_async_delay
project:       rhis-builder-satellite
date:          2026-05-26
status:        complete
```

**Reason:** Same as `async_timeout` above — unqualified name, shared with idm
and kvm contexts.

**Inventory_template files updated (already renamed):**
- `host_vars/satellite/satellite_pre.yml`
- `host_vars/discosatellite/satellite_pre.yml`

**Script target pattern:**

```bash
# satellite_async_delay migration
sed -i 's/^async_delay:/satellite_async_delay:/' \
    "${INVENTORY_DIR}/host_vars/satellite/satellite_pre.yml" \
    "${INVENTORY_DIR}/host_vars/discosatellite/satellite_pre.yml"
```

---

## Migration: async_timeout → kvm_host_async_timeout

```
deprecated:    async_timeout
replacement:   kvm_host_async_timeout
project:       rhis-builder-kvm
date:          2026-05-26
status:        complete
```

**Reason:** `async_timeout` violated the role-prefix naming convention. Unqualified
name risked collision with satellite and idm async variables.

**Note:** No async tasks currently exist in `kvm_host`. The variable is retained
for future use and convention compliance.

**Inventory_template files updated:** None — no kvm hypervisor host_vars override
this variable. If a deployed inventory has overridden `async_timeout` for kvm hosts,
apply the sed pattern below manually.

**Script target pattern:**

```bash
# kvm_host_async_timeout migration — apply only to kvm hypervisor host_vars
# (no standard inventory_template file uses this override)
# grep -rl '^async_timeout:' "${INVENTORY_DIR}/host_vars/" to locate overrides first
```

---

## Migration: async_delay → kvm_host_async_delay

```
deprecated:    async_delay
replacement:   kvm_host_async_delay
project:       rhis-builder-kvm
date:          2026-05-26
status:        complete
```

**Reason:** Same as `async_timeout` above.

**Inventory_template files updated:** None — see note above.

**Script target pattern:**

```bash
# kvm_host_async_delay migration — same caveat as kvm_host_async_timeout
```

---

## Migration: split_global_domain_name → split_basevars_global_domain_name

```
deprecated:    split_global_domain_name
replacement:   split_basevars_global_domain_name
project:       rhis-builder-inventory (inventory_update.yml + inventory_template)
date:          2026-05-28
status:        complete
```

**Reason:** `split_global_domain_name` was derived from `global_domain_name` (now
`basevars_global_domain_name`). Renaming both the source variable and this derived
split list maintains naming consistency. The `basevars_` prefix makes it clear this
is a render-time computed value sourced from the user's basevars file.

**Context:** This variable splits `basevars_global_domain_name` on `.` to produce a
list used by cloud resource naming conventions (Azure resource groups, VNets, subnets)
of the form `element#_<part0>_<part1>`. See `schema/TODO.md` for a tracked issue on
improving this naming scheme.

**Note:** This rename was also a corruption fix — an earlier sed pass had incorrectly
transformed the name to `split_runtime_global_domain_name` in template files.
The definition in `inventory_update.yml` was unaffected by that pass but used the
old source variable name `global_domain_name`.

**Files updated:**
- `inventory_update.yml:60` — `set_fact` definition renamed; source variable updated
- `host_vars/satellite/compute_resources.yml.j2`
- `host_vars/discosatellite/compute_resources.yml.j2`
- `host_vars/aapcontroller24/platform_post.yml.j2`
- `host_vars/aapcontroller26/platform_post.yml.j2`
- `host_vars/aaphub24/platform_post.yml.j2`
- `host_vars/aaphub26/platform_post.yml.j2`
- `group_vars/provisioner/testyubiuser.yml.j2`
- `group_vars/provisioner/generic_user.yml.j2`

**Script target pattern:**

```bash
find "${INVENTORY_DIR}" -type f -name "*.yml" -o -name "*.yml.j2" | \
    xargs sed -i 's/split_global_domain_name/split_basevars_global_domain_name/g'
sed -i 's/split_global_domain_name/split_basevars_global_domain_name/g' inventory_update.yml
```

---

## Migration: global_domain_name → basevars_global_domain_name

```
deprecated:    global_domain_name
replacement:   basevars_global_domain_name
project:       rhis-builder-inventory (inventory_basevars.yml + inventory_template)
date:          2026-05-28
status:        complete
```

**Reason:** `global_domain_name` gave no indication of where it was defined or what
lifecycle it belonged to. `basevars_` makes the source explicit: this is a user-supplied
value from `<domain>_inventory_basevars.yml`, consumed at render time by
`inventory_update.yml`. It is never an Ansible runtime variable in a deployed inventory.

**Backwards compatibility:** Existing deployed inventories are not affected — the variable
is consumed during rendering and does not appear in rendered output files. No alias is
needed. Checked: zero occurrences found in `deployments/` at time of migration.

**Files updated:**
- `inventory_basevars.yml` — definition renamed
- All `inventory_template/` files referencing `global_domain_name` — render-time substitution sites updated

**Script target pattern for users with custom basevars files:**

```bash
# Rename in any <domain>_inventory_basevars.yml files
# (the standard inventory_basevars.yml has already been updated)
sed -i 's/^global_domain_name:/basevars_global_domain_name:/' \
    "${DOMAIN}_inventory_basevars.yml"
```

---

## Migration: _global_domain_name → _runtime_global_domain_name

```
deprecated:    _global_domain_name
replacement:   _runtime_global_domain_name
project:       rhis-builder-inventory (inventory_template)
date:          2026-05-28
status:        complete
```

**Reason:** The `_` prefix alone was ambiguous between render-time Jinja2 substitution
and runtime Ansible variables. `_runtime_` makes the lifecycle explicit: this variable
is available to Ansible at playbook runtime (after `inventory_update.yml` renders the
deployment), not evaluated during template rendering. Contrast with bare `global_domain_name`
which is a render-time variable substituted directly by `inventory_update.yml`.

**Backwards compatibility:** `_global_domain_name` is retained as a deprecated alias in
`group_vars/all/main.yml.j2`:

```yaml
_runtime_global_domain_name: "{{ global_domain_name }}"
_global_domain_name: "{{ _runtime_global_domain_name }}"  # deprecated — use _runtime_global_domain_name
```

Deployed inventories regenerated from the updated `inventory_template` receive the new
name automatically. Existing deployed inventories (under `deployments/<domain>/`) that
have not been regenerated will continue to work via the alias until they are re-rendered.

**Inventory_template files updated (373 occurrences across 58 files):**
All files in `inventory_template/` that referenced `_global_domain_name` — see
`git diff` for the full list. Key definition point:
- `group_vars/all/main.yml.j2` — definition and alias

**Script target pattern for existing deployed inventories:**

```bash
# _runtime_global_domain_name migration
# Run against a deployed inventory directory (deployments/<domain>/)
# The alias in group_vars/all/main.yml keeps things working, but apply
# this to clean up after re-rendering.
find "${INVENTORY_DIR}" -type f -name "*.yml" | \
    xargs sed -i 's/_global_domain_name/_runtime_global_domain_name/g'
```

---

## Pending Migrations

The following renames are identified but not yet applied. They are blocked on
completing the rename in the consuming project first.

| Deprecated name | Replacement | Project | Blocked on |
|---|---|---|---|
| `async_timeout` | `idm_async_timeout` | rhis-builder-idm | Rename in `rhis-builder-idm` roles |
| `async_delay` | `idm_async_delay` | rhis-builder-idm | Rename in `rhis-builder-idm` roles |

**Inventory_template files that will need updating when the above are complete:**
- `group_vars/idm_replicas/main_vars.yml` — rename `async_timeout`/`async_delay` to `idm_async_timeout`/`idm_async_delay`
- `host_vars/idm/main_vars.yml` — same rename
