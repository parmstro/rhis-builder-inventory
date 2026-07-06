# SOE Catalog

This directory contains the authoritative catalog of Standard Operating Environment
(SOE) bundle definitions for rhis-builder. Each YAML file describes one SOE bundle.
The `rhis-builder-ui` reads this catalog to populate the SOE selection interface.
The `inventory_update.yml` aggregation step reads the operator's selections and
renders the active entries into the flat Satellite variable files consumed by
`rhis-builder-satellite`.

See [`../soe_catalog_schema.yml`](../soe_catalog_schema.yml) for the full field
vocabulary, global provisioning defaults, and aggregation guidance.

---

## Current catalog

### Base SOEs

| File | ID | Status | Architectures |
|---|---|---|---|
| [rhel10_base.yml](rhel10_base.yml) | `rhel10_base` | active | x86_64, aarch64 |
| [rhel9_base.yml](rhel9_base.yml) | `rhel9_base` | active | x86_64, aarch64 |
| [rhel8_base.yml](rhel8_base.yml) | `rhel8_base` | aspirational | x86_64 |

### Layered SOEs

| File | ID | Status | Requires |
|---|---|---|---|
| [rhel9_epel.yml](rhel9_epel.yml) | `rhel9_epel` | active | rhel9_base |
| [rhel9_jboss.yml](rhel9_jboss.yml) | `rhel9_jboss` | active | rhel9_base |
| [rhel9_mssql.yml](rhel9_mssql.yml) | `rhel9_mssql` | active | rhel9_base |
| [rhel9_aap.yml](rhel9_aap.yml) | `rhel9_aap` | active | rhel9_base |
| [rhel10_aap.yml](rhel10_aap.yml) | `rhel10_aap` | active | rhel10_base |
| [rhel9_edge_manager.yml](rhel9_edge_manager.yml) | `rhel9_edge_manager` | active | rhel9_base |

---

## Adding a new catalog entry

1. Copy the appropriate template:
   - Base SOE: copy `rhel9_base.yml` or `rhel10_base.yml`
   - Layered SOE: copy the closest existing layered entry

2. Set a unique `id` in snake_case. The file name must match: `{id}.yml`.

3. Fill in all required fields. See `soe_catalog_schema.yml` for the full
   field reference. Omit optional fields rather than leaving them empty.

4. Set `status: aspirational` until the entry has been deployed and verified
   end-to-end in at least one deployment.

5. Add the entry to the table above.

6. If the entry introduces new EUS repository sets, verify the exact Satellite
   repository set names against a subscribed Satellite instance:

   ```bash
   subscription-manager repos --list | grep "Repo Name" | grep -i EUS
   ```

   EUS repository set names differ from their streaming equivalents. Using the
   wrong name causes silent aggregation failures.

---

## Entry types

### Base entry

A base entry owns the full OS content for one major RHEL release × architecture
combination. It generates:

- Repository sets (streaming RPMs + kickstart + Satellite Client)
- EUS repository sets (when `eus_enabled: true` at deployment selection time)
- LEAPP source repos (tagged `[leapp]`)
- Content views per architecture
- Activation keys per lifecycle level
- Hostgroups per platform type (VM, baremetal) per architecture

### Layered entry

A layered entry adds content on top of one or more base entries. It generates:

- Additional repository sets or custom products (the layer-specific content only)
- An independent content view carrying only the layer content (promotes to Library)
- A composite content view combining the base CV + layer CV
- Activation keys referencing the composite CV

Layered entries declare their dependency in the `requires:` list. The aggregation
step validates that all required base entries are selected before rendering the
flat variable files.

---

## Template variables

These substitution markers appear in catalog entries and are resolved by
`inventory_update.yml` at aggregation time. Do not resolve them in the catalog.

| Variable | Resolved from |
|---|---|
| `{{ kickstart_version }}` | Operator kickstart pin selection (x86_64) |
| `{{ kickstart_version_aarch64 }}` | Operator kickstart pin selection (aarch64) |
| `{{ eus_minor }}` | Operator EUS minor selection (e.g. `9.4`) |
| `{{ satellite_organization }}` | Deployment config |
| `{{ satellite_location }}` | Deployment config |

---

## EUS repository names

EUS repository sets have **distinct names** in Satellite from their streaming
equivalents — they are separate CDN content sets, not the same set with a
different `releasever`. The naming convention is:

```
Red Hat Enterprise Linux {major} for {arch} - {Repo} - Extended Update Support (RPMs)
```

Example (RHEL 9 BaseOS EUS):
```
Red Hat Enterprise Linux 9 for x86_64 - BaseOS - Extended Update Support (RPMs)
```

Always verify exact names on a Satellite instance with EUS subscriptions before
adding entries to `eus_repository_sets`. Using the streaming name with an EUS
`releasever` will silently fail or pull incorrect content.

---

## EUS supported minor derivation

Each base catalog entry carries a `supported_minors` list under `os.eus`. This list
must be recomputed whenever a new RHEL minor is released. Use the **n-4 sliding
window** algorithm.

### Why n-4

Red Hat ships RHEL minor releases approximately every 6 months. EUS is offered for
2 years by default (there is a 4-year extended option, but RHIS limits scope to the
2-year default). Four minor releases at ~6 months each = ~2 years of look-behind.
The n-4 window therefore tracks the 2-year default EUS support horizon exactly. When
Red Hat changes the minor release cadence or EUS default term, this policy should be
revisited.

### Design intent and future direction

Red Hat is evolving its subscription and lifecycle models. Emerging models may reduce
or eliminate the operational distinction between streaming and EUS content — making
much of this complexity obsolete over time. RHIS does not attempt to model every
possible lifecycle eventuality. The goal is to be opinionated and to drive deployments
toward currency: systems should track the current minor release unless there is a
specific, deliberate reason to pin to an EUS minor.

If future subscription models increase the number of concurrently supported EUS minors,
the n-4 algorithm does not change — the window simply produces a longer list. The
operator experience does become more complex as the list grows, but RHIS makes no
attempt to manage that complexity beyond what the n-4 window defines. Operators who require coverage beyond what the catalog offers can bypass the UI
entirely and configure rhis-builder directly through the inventory templates and
variable files. The templates impose no artificial limits — any configuration that
Satellite supports can be expressed there. The UI and catalog are the opinionated
layer; the underlying rhis-builder is the full-flexibility layer.

### Rules

1. **Even minors only.** EUS is offered for even minor releases only (9.2, 9.4, 9.6, …).
   Odd minors never appear in `supported_minors`.

2. **No last-minor EUS.** The terminal minor release of a major version is never offered
   as an EUS target (e.g. 8.10, and eventually 9.10 and 10.10). Exclude it even if it
   is even.

3. **n-4 lower bound.** The lower bound on the supported minor is
   `current_minor − 4` (clamped to 0). Minors below this threshold are dropped from
   the list regardless of whether they were previously offered.

4. **Highest EUS minor.** The upper bound is the largest even, non-last minor ≤
   `current_minor`.

### Algorithm

```
lower_bound  = max(0, current_minor − 4)
highest_eus  = largest even M ≤ current_minor where M is not the last minor
supported    = even integers from lower_bound to highest_eus inclusive
```

### Worked examples

| Current release | Last minor? | lower bound | highest EUS | `supported_minors`    |
|-----------------|-------------|-------------|-------------|-----------------------|
| 9.6             | no          | 9.2         | 9.6         | 9.2, 9.4, 9.6         |
| 9.7             | no          | 9.3         | 9.6         | 9.4, 9.6              |
| 9.8             | no          | 9.4         | 9.8         | 9.4, 9.6, 9.8         |
| 9.9             | no          | 9.5         | 9.8         | 9.6, 9.8              |
| 9.10            | yes         | 9.6         | 9.8         | 9.6, 9.8              |
| 8.10            | yes         | 8.6         | 8.8         | 8.6, 8.8              |
| 10.2            | no          | 10.0 (min)  | 10.2        | 10.0, 10.2            |

### Update procedure

When a new RHEL minor is released:

1. Apply the algorithm above to compute the new `supported_minors` list.
2. Update `current_minor` in the relevant `os.eus` block.
3. Replace the `supported_minors` list — remove minors that fell out of the n-4
   window, add any new EUS minor that entered it.
4. If the release is a last-minor (e.g. 9.10), note this in the EUS `note` field
   so the next maintainer does not re-add it.
5. Consider whether existing EUS CVs and activation keys in active deployments
   need to be retired as minors age out (catalog maintenance — deferred topic).

---

## UI selection behavior — dependency resolution

When an operator selects SOE entries in a UI (CLI wizard or web form), the `requires:`
field in each catalog entry drives automatic dependency resolution. The model is
**auto-enable with lock**.

### Rules

1. **Auto-enable.** When a layered SOE is selected, the UI immediately selects every
   catalog entry listed in its `requires:` list. The operator does not need to select
   the base SOE manually.

2. **Lock while required.** A base SOE that was auto-selected cannot be deselected
   while at least one layered SOE that depends on it remains selected. The UI renders
   the base entry as non-deselectable (e.g. greyed checkbox) and surfaces which layered
   entries are holding it: *"Required by: rhel9_jboss, rhel9_epel"*.

3. **Lock release.** When the last layered SOE that depends on a base is deselected,
   the lock is released. The base entry reverts to optional and the operator may
   deselect it independently.

4. **Recursive resolution.** If a `requires:` entry is itself a layered entry, its
   own `requires:` list is resolved recursively until all transitive dependencies are
   satisfied.

### Implementation

The UI maintains a `required_by` reverse index alongside the `requires` forward
declarations in each catalog file. The forward index comes from catalog YAML; the
reverse index is computed at selection time:

```
# Forward (from catalog YAML)
rhel9_jboss → requires: [rhel9_base]
rhel9_epel  → requires: [rhel9_base]
rhel9_mssql → requires: [rhel9_base]

# Reverse (computed at selection time — only selected entries)
rhel9_base  → required_by: [rhel9_jboss, rhel9_epel]   # rhel9_mssql not selected
```

When a layered entry is deselected, remove it from `required_by` for each of its
dependencies. If `required_by` for a base entry becomes empty, release the lock on
that base entry.

### Relationship to aggregation validation

The aggregation step in `inventory_update.yml` independently validates that all
`requires:` entries are satisfied before rendering variable files. The UI lock is
defence-in-depth — it prevents the invalid selection state from being saved. The
aggregation validation catches any case where the selection was produced outside the
UI (e.g. hand-editing the selection file).

---

## UI selection behavior — EUS and layered release instances

Each basket entry is a fully-specified, independently deployable **SOE instance**. A
catalog entry can produce multiple instances: one streaming and one per selected EUS
minor. The model is **Add/Remove**, not On/Off.

### Base SOE — streaming and EUS instances

Selecting a base SOE card adds the **streaming instance** to the basket. If the entry
has `os.eus.available: true`, an "Add EUS" button opens a minor picker populated from
`os.eus.supported_minors`. Each minor picked creates a separate basket entry. Each
entry has its own Remove button.

- **Streaming instance kickstart:** multi-select — the operator chooses which kickstart
  versions to include (e.g. 9.7 and 9.8 for different hardware targets).
- **EUS instance kickstart:** locked to the EUS minor automatically. A host cannot be
  provisioned from a later kickstart and pinned to an earlier EUS minor.

### Layered SOE — release picker

Selecting a layered SOE card adds the **streaming instance** by default. An "Add" button
opens a release picker showing only the base releases currently in the basket (streaming
+ any EUS minors). Each pick creates a separate layered instance. The "Add" button is
greyed unless at least one EUS base instance exists in the basket.

### Basket entry schema

`eus_minor` is part of entry identity. Two entries with the same `id` and `arch` but
different `eus_minor` are distinct instances:

```yaml
{ id: "rhel9_base",  arch: "x86_64", eus_minor: null,  options: { kickstart_versions: ["9.7","9.8"] } }
{ id: "rhel9_base",  arch: "x86_64", eus_minor: "9.4", options: { kickstart_version: "9.4" } }
{ id: "rhel9_jboss", arch: "x86_64", eus_minor: null  }
{ id: "rhel9_jboss", arch: "x86_64", eus_minor: "9.4" }
```

### Satellite naming convention

| `id`        | `eus_minor` | Satellite object name  |
|-------------|-------------|------------------------|
| rhel9_base  | null        | SOE9                   |
| rhel9_base  | "9.4"       | SOE94_EUS              |
| rhel9_jboss | null        | SOE9_JBoss             |
| rhel9_jboss | "9.4"       | SOE94_JBoss_EUS        |

The dependency lock from the previous section applies per `eus_minor`: a base EUS
instance is locked while a layered instance with the same `eus_minor` depends on it.

Full design rationale and worked examples:
[`schema/architecture/soe_selection_model.md — Add/Remove SOE Instance Model`](../architecture/soe_selection_model.md#decided-addremove-soe-instance-model)

---

## Lifecycle levels

Catalog entries reference lifecycle levels symbolically. The deployment maps
each symbol to a named Satellite lifecycle environment.

| Symbol | Default Satellite environment |
|---|---|
| `dev` | Development |
| `qa` | Qualification |
| `stage` | Staging |
| `prod` | Production |

Entries that are not yet validated across the full lifecycle list only the levels
they support (e.g. a new entry might list `[dev, qa]` until Staging/Production
CV promotion is verified).
