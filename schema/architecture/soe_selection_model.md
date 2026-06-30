# SOE Selection Model

**Status:** Problem defined — solution approach under discussion  
**Related capability:** C05, C06, C07, C10, C15, C27  
**Last updated:** 2026-06-10

---

## Problem Statement

The RHIS inventory template is a "big box store" — it defines multiple Standard Operating
Environments across several RHEL versions (7, 8, 9, 10), multiple architectures (x86_64,
aarch64), and all associated content, compliance roles, and provisioning infrastructure.
This is intentional for demonstrating capability breadth. It is not realistic for any
actual customer deployment.

Every real deployment is a subset. A customer that manages RHEL 8 and RHEL 9 x86_64
workloads does not need RHEL 7 content, aarch64 activation keys, RHEL 10 hostgroups, or
SCAP policies for OSes they do not run. The current workflow for reaching a realistic
deployment is:

1. Run `inventory_update.sh` to generate the full deployment from the template
2. Manually comment out all content, keys, hostgroups, OS definitions, media, policies,
   and SCAP content for every non-selected SOE
3. Cross-reference across a cascade of interdependent files to catch everything
4. Discover missed dependencies during the build — late, confusing, hard to diagnose

This process is:
- **Massively time-consuming.** A single SOE selection ripples across 10+ files with
  no tooling to trace the dependency chain.
- **Error-prone.** Missing one cross-reference (e.g. commenting out a hostgroup but
  leaving its activation key) produces a build-time failure or a silent misconfiguration.
- **Confusing for customers.** The template in its unedited form is overwhelming. The
  comment-out process is the opposite of "opinionated" — it forces the customer to learn
  what everything is before they can remove it.
- **Not scalable.** As RHIS adds new content (RHEL 10, new architectures, new custom
  products), the editing burden grows with it.

The disconnected / air-gapped deployment model amplifies this problem. On the highside,
the content authorization policy determines what is allowed — and the export scope should
match the highside's authorized content selection. Today's full Library export includes
content that the highside may not be authorized to hold, and the tooling has no mechanism
to enforce or validate that boundary. See also:
[Disconnected Deployment Model — Export Scoping](disconnected_deployment_model.md#content-export-scoping)

---

## What Is a SOE in RHIS Terms

A Standard Operating Environment (SOE) selection is the declaration of:
- **OS version** (RHEL 8, RHEL 9, RHEL 10, ...)
- **Architecture** (x86_64, aarch64, ppc64le, s390x)

This two-dimensional selection drives everything downstream. For a given `(os, arch)` pair,
the following template files each contain entries that are active only for that pair:

| File | What changes per SOE |
|---|---|
| `repository_sets.yml` | Repository sets enabled for that OS/arch |
| `repositories.yml` | Individual repos (BaseOS, AppStream, SAT maintenance, kickstart) |
| `content_views.yml` | Content views scoped to that OS's repos |
| `activation_keys.yml` | Activation keys referencing those CVs and lifecycle environments |
| `hostgroups.yml` | Hostgroup hierarchy for hosts running that OS |
| `operating_systems.yml` | OS definition in Satellite |
| `installation_media.yml` | Boot media for that OS/arch |
| `scap_content.yml` | SCAP data stream files for that OS |
| `scap_policies.yml` | Compliance scan policies for that OS/arch |
| `imported_git_repos.yml` | Compliance role repos (RHEL 7/8/9 role sets) |

Composite content views and activation keys that span multiple SOEs add another layer —
removing one SOE from a composite requires editing the composite definition, not just the
per-SOE leaf objects.

---

## The SOE Selection Declaration

The goal is a single declaration that drives the entire downstream configuration:

```yaml
# In basevars or a separate SOE profile file
rhis_soe_selections:
  - os: rhel9
    arch: x86_64
  - os: rhel8
    arch: x86_64
```

Everything the template generates should follow from this declaration. An operator working
with a single-SOE customer should need to express one entry, not trace and comment out
hundreds of lines across a dozen files.

---

## Why This Is Hard

### The cascade is wide

A single `(os, arch)` pair touches at minimum 10 files with structural interdependencies.
Activation keys reference content views. Content views reference repositories. Repositories
reference repository sets. Hostgroups reference activation keys and operating system
definitions. SCAP policies reference OS definitions. Removing one layer without removing
the others leaves orphaned references that produce Satellite API errors.

### The template files mix SOE-specific and SOE-independent content

`content_views.yml` has per-OS content views and also composite content views that span
multiple OSes. `activation_keys.yml` has per-OS keys and keys for shared content
(custom products, middleware). `hostgroups.yml` has OS-scoped groups and role-scoped groups
that inherit from OS parents. The selection boundary is not clean.

### The current template is structurally flat

Each template file lists all items in YAML. There is no grouping or tagging by SOE that a
selection processor could filter on. The files would need to be restructured — either into
per-SOE include files that compose, or into loop-driven `.j2` templates parameterized by
the selection list.

### The `.j2` constraint applies at scale

As noted in the disconnected deployment model, files containing Ansible runtime variables
cannot be cleanly converted to Jinja2 templates without `{% raw %}`/`{% endraw %}` wrappers.
Most of the affected files DO contain runtime variable references. This complicates a naive
"make everything a `.j2` loop" approach.

---

## Possible Approaches

### Approach A — Selection-driven templates (clean, high effort)

Convert the affected template files to `.j2` with `{% for soe in rhis_soe_selections %}`
loop logic. `inventory_update.sh` renders only the items that match the selected SOEs.

**Pros:**
- Generated deployment contains exactly what was selected — no dead entries
- Regeneration is safe — running `inventory_update.sh` again produces the same correct output
- The template is authoritative; customization lives in the basevars selection

**Cons:**
- Requires converting many files to `.j2` with runtime variable wrapping or restructuring
- Loop logic in YAML templates is complex and brittle
- A high-volume refactor that touches many files simultaneously

### Approach B — SOE profile modules (medium effort, more flexible)

Instead of one flat template file per Satellite object type, maintain per-SOE module files:

```
inventory_template/soe_profiles/
  rhel9_x86_64/
    repositories.yml      # only RHEL 9 x86_64 repos
    content_views.yml     # only RHEL 9 x86_64 CVs
    activation_keys.yml   # only RHEL 9 x86_64 activation keys
    hostgroups.yml        # only RHEL 9 x86_64 hostgroups
    ...
  rhel8_x86_64/
    repositories.yml
    ...
  common/
    repositories.yml      # custom products, shared content
    composite_cvs.yml     # CVs that span SOEs
    ...
```

`inventory_update.sh` reads `rhis_soe_selections`, merges the selected profile modules
into a single deployment configuration, and writes the composed files.

**Pros:**
- Profile modules are small, readable, and independently maintainable
- Adding a new SOE (e.g. RHEL 10 aarch64) adds one profile directory without touching others
- The composition logic is in `inventory_update.yml`, not in the template files themselves
- No `.j2` conversion of the content files required

**Cons:**
- Requires restructuring the existing flat template files into profile modules — migration
  effort comparable to Approach A
- Common/composite objects (CCVs, shared activation keys) need careful placement

### Approach C — Post-generation pruning (low effort, imperfect)

Keep the current template structure. After `inventory_update.sh` generates the full
deployment, run a separate "SOE prune" playbook that reads `rhis_soe_selections` and
removes non-selected items from the generated YAML files.

**Pros:**
- No changes to the template files — current structure preserved
- Incremental: can be implemented before a full template restructure
- Reversible: re-running `inventory_update.sh` regenerates the full set; re-running prune
  re-applies the selection

**Cons:**
- Pruning YAML programmatically while preserving comments and structure is fragile
- Generated files still start as "big box" — pruned output can drift from the template
  if prune logic is incomplete
- Does not address the export scoping problem directly (export scope must be computed
  separately, or from the pruned files)
- Still "generate everything then remove" — philosophically the wrong direction

### Approach D — Customer-facing SOE wizard (high effort, highest value)

A guided configuration tool (CLI or simple web form) that asks the operator what they need:
- Which RHEL versions and architectures?
- Which custom products (MSSQL, Oracle, EPEL...)?
- Which compliance frameworks?
- Connected or disconnected?
- Which deployment components (IdM only, IdM+Satellite, full stack)?

The wizard generates a `basevars.yml` and a `soe_profile.yml` that drive the template
rendering. The result is a deployment configuration that contains exactly what was declared
and nothing else.

This is C27 (Deployment Model Selection and Sequencing) made concrete.

**Pros:**
- Customer-facing — removes the need for the customer to understand the template at all
- Ensures consistency — the selection drives both the deployment config AND the export scope
- Aligns with "opinionated model" in the RHIS design statement

**Cons:**
- Significant design and implementation effort
- Requires the profile module restructure (Approach B) as a foundation
- Out of scope until the template structure supports it

---

## Recommended Path

The approaches are not mutually exclusive. A realistic path:

1. **Near term:** Document the SOE dependency chain for each file (what to change when
   removing a SOE). This reduces the manual error rate while the structural solution
   is designed. → Add to `disconnected_satellite_workflow.md` as a "highside content
   reduction checklist".

2. **Medium term:** Restructure the template into SOE profile modules (Approach B).
   Begin with the files that are purely SOE-specific and have no runtime variable
   complexity: `repository_sets.yml`, `repositories.yml`, `installation_media.yml`,
   `operating_systems.yml`. These are the cleanest starting point.

3. **Medium term:** Use the profile module structure to drive export scope. The highside
   deployment's selected profiles define exactly which repos are in scope for the export.
   This closes the export scoping gap in the disconnected model.

4. **Long term:** Build Approach D (wizard / guided config) on top of the profile structure.
   This is C27 and makes RHIS genuinely customer-facing at the onboarding stage.

---

## Connection to Disconnected Export Scoping

The SOE selection is the authoritative statement of what belongs in the transfer bundle.
If the highside is declared as `rhel9_x86_64` and `rhel8_x86_64` only:

- The export scope is the union of repos referenced by those two profiles
- Content from non-selected profiles should not cross the air gap
- The export playbook can derive its scope from `rhis_soe_selections` rather than
  requiring a full Library export

This makes SOE selection the single source of truth for both the deployment configuration
AND the export scope — eliminating the gap documented in
[Disconnected Deployment Model — Export Scoping](disconnected_deployment_model.md#content-export-scoping).

---

## Open Questions

1. **Profile granularity:** Should a profile be `(os, arch)` only, or should custom
   products (EPEL, MSSQL, Oracle) be separate selectable modules composed alongside
   OS profiles?

2. **Composite CV strategy:** Composite content views (CCVs) combine multiple OS-scoped
   CVs. When a SOE is deselected, what happens to CCVs that referenced it? Rebuild with
   remaining members, or leave a gap that produces a Satellite warning?

3. **Activation key inheritance:** Some activation keys are shared across OSes (custom
   product content overrides). How are these handled in a profile module model?

4. **Migration of existing deployments:** The `example.ca` deployment currently has
   all SOEs. If the profile module structure is adopted, how is the existing deployment
   migrated without losing operator customizations that live alongside the SOE-specific
   content?

5. **SOE addition workflow:** When a new RHEL version (e.g. RHEL 10) is added to RHIS,
   what is the process for adding a new profile module and ensuring it is consistent
   across all the file types? Today this is the SOE consistency problem documented in
   `feedback_SOE_consistency.md`.
