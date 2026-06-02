# Inventory Template Ordering Conventions

This document defines the standard ordering and formatting conventions for all
configuration files under `inventory_template/host_vars/satellite/`. Consistent
ordering makes it easy to find entries, spot gaps, detect version mismatches,
and validate that all required SOE elements are present.

---

## General Rules

### 1. Product Ordering — Red Hat First, Third Party Last

Within any configuration file, group entries by vendor:

1. **Red Hat products** — alphabetically A→Z by full product name
2. **Third-party products** — alphabetically A→Z by product name

Red Hat products include: JBoss Enterprise Application Platform, Red Hat Ansible
Automation Platform, Red Hat Edge Manager, Red Hat Enterprise Linux (all variants),
Red Hat Satellite Capsule, etc.

Third-party products include: CentOS, EPEL, Microsoft SQL Server, Oracle Enterprise
Linux, and any custom/community repos.

### 2. Version Ordering — Newest to Oldest

Within each product, list versions from most recent to oldest:

- RHEL 10.2 before RHEL 10.1 before RHEL 10.0
- RHEL 9 before RHEL 8 before RHEL 7
- AAP 2.6 before AAP 2.4
- x86_64 before aarch64 (primary architecture first)

### 3. Deprecated Entries — Comment, Don't Delete

Entries for deprecated OS versions, products, or configurations should be **commented
out**, not deleted. This preserves context and makes it easy to restore when needed
(e.g. when a Pulp upstream bug is fixed and a kickstart version can be re-enabled).

Add a `# Deprecated — reason` comment explaining why.

### 4. Spacing

- **One blank line** between individual entries within a section
- **Two blank lines** between major product sections or top-level YAML keys
  (e.g. between `content_views:` and `composite_content_views:`)

---

## Section Header Format

Use the following consistent header style for major sections:

```yaml
############## Section Name ##################
```

Use sub-comments (no decoration) for groupings within a section:

```yaml
# RHEL 10 x86_64 Baremetal
  - name: "hg_x86_64_rhel10_metal"
    ...

# RHEL 10 x86_64 Virtual Machine
  - name: "hg_x86_64_rhel10_vm"
    ...
```

---

## File-Specific Conventions

### `repository_sets.yml`

Sections by product A→Z (Red Hat first, then third party). Within each product,
newest OS version first. Kickstart repo sets list `releasever` values newest→oldest.

Point-in-time releasever entries used for LEAPP migrations are annotated:
```yaml
      - releasever: "9.8"  # Used for LEAPP
```

Third-party products are referenced via a comment at the bottom:
```yaml
# Please see custom_products.yml for:
# CentOS Stream 9, CentOS Stream 8, ...
```

### `repositories.yml`

Same product ordering as `repository_sets.yml`. Within each product section,
group by OS version (newest→oldest), then within each version:
1. Kickstart repos (AppStream then BaseOS)
2. Streaming RPM repos (AppStream, BaseOS, Supplementary, Extensions)
3. Satellite Client
4. Point-in-time RPM repos (LEAPP) annotated with `# Used for LEAPP`
5. HA repos (under their own product section)

Red Hat Satellite Capsule and Maintenance are grouped together under their own section.

### `sync_plan_product_map.yml`

Two sections: `# Red Hat Products` and `# Third Party Products`. Within each,
alphabetical A→Z. Deprecated entries commented with reason.

### `operating_systems.yml`

Ordered by major version newest→oldest, then minor newest→oldest within each major.
Each entry must include: `architectures`, `provisioning_templates`, `ptables`,
`default_templates`. Active entries precede deprecated (commented) entries.

### `content_views.yml`

Two top-level YAML sections: `content_views:` and `composite_content_views:`.
Two blank lines between them.

**`content_views:`** — Red Hat product CVs first, third party at end:
1. AAP (newest version, newest RHEL first)
2. convert2rhel (newest RHEL target first)
3. JBoss (newest RHEL, newest EAP version first)
4. LEAPP (newest migration target first)
5. Red Hat Edge Manager
6. SOE OS views (newest RHEL first, x86_64 before aarch64, deprecated at bottom)
7. Third party (CentOS, EPEL, MSSQL, OEL)

**`composite_content_views:`** — grouped by base OS, newest first:
1. SOE10 composites
2. SOE9 composites
3. SOE8 composites
4. LEAPP / Migration
5. Deprecated

### `activation_keys.yml`

Grouped by base content view (infrastructure first, then newest OS first):
1. Infrastructure (`satellite_capsule`)
2. LEAPP / Migration (newest target first)
3. SOE10 (base, then composites)
4. SOE9 (base, then composites)
5. SOE8 (base, then composites)
6. Deprecated (commented)

Within each group, order: Development → Qualification → Production.

### `hostgroups.yml`

Grouped by OS version (newest→oldest), then within each OS by type
(Baremetal before Virtual Machine). Children must always follow their parent.
Within a parent's children, AAP newest→oldest, then other tooling alphabetically.
Deprecated (commented) entries at the bottom under `############## Deprecated ##################`.

---

## Validation Checklist

Before committing changes to any satellite configuration file:

- [ ] Red Hat products precede third-party products
- [ ] Versions are ordered newest→oldest within each product
- [ ] Section headers use the `############## Name ##################` format
- [ ] One blank line between entries, two blank lines between major sections
- [ ] Deprecated entries are commented (not deleted) with a reason comment
- [ ] `# Used for LEAPP` annotation on point-in-time releasever entries
- [ ] No `Satellite 6 Client 2` references in active content views (empty repos — see schema/TODO.md)
- [ ] All kickstart repo versions match the OS version referenced in `operating_systems.yml` and `hostgroups.yml`
