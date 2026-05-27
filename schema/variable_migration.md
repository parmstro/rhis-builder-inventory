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
