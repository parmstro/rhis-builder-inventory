# SOE Build Requirements — Dependency Model

This document captures the required elements and correct dependency order for a
successful Satellite SOE build using rhis-builder. Missing or misconfigured elements
at any layer cause failures in downstream layers.

---

## Required Elements for a Complete SOE

For each supported OS version (e.g. RHEL 9.7, RHEL 10.2), the following Satellite
objects must all exist and be consistent with each other:

| Layer | Object | File | Key Constraint |
|---|---|---|---|
| 1 | Repository Set | `repository_sets.yml` | Must be enabled with correct `releasever` values |
| 2 | Repository | `repositories.yml` | Name must exactly match what Satellite creates from the repo set |
| 3 | Content View | `content_views.yml` | Kickstart repo version must match OS version in hostgroup |
| 4 | Lifecycle Environment | `lifecycle_environments.yml` | Must exist and be in sequence before CV promotion |
| 5 | Content View promotion | (Satellite internal) | CV must be published AND promoted to the correct lifecycle environment |
| 6 | Operating System | `operating_systems.yml` | `major`, `minor`, provisioning templates, and ptables must all be set |
| 7 | Activation Key | `activation_keys.yml` | Content view + lifecycle environment combination must exist |
| 8 | Hostgroup | `hostgroups.yml` | `operatingsystem`, `kickstart_repository`, `content_view`, and `activation_keys` must all be consistent |

---

## SOE Bundle Checklist

When adding a **new OS version** (e.g. moving from RHEL 9.7 → RHEL 9.8), every
item in this checklist must be addressed:

### repository_sets.yml
- [ ] Add new `releasever` to the BaseOS, AppStream, Supplementary (Kickstart) repo sets
- [ ] Add new `releasever` to the BaseOS, AppStream, Supplementary (RPMs) if point-in-time is needed (LEAPP)

### repositories.yml
- [ ] Add Kickstart repositories for the new version (BaseOS + AppStream)
- [ ] Add `# Used for LEAPP` comment on point-in-time RPM repos

### content_views.yml
- [ ] Add new kickstart version to the affected SOE content view's `repositories:` list
- [ ] Comment out older kickstart versions if no longer needed
- [ ] **Do NOT mix kickstart repos and streaming RPM repos** — causes Pulp duplicate content errors (see Known Issues below)
- [ ] Ensure `Staging` environment is in the `environments:` list if it exists

### operating_systems.yml
- [ ] Add new OS entry (`name`, `major`, `minor`, `description`)
- [ ] Set all `provisioning_templates` — all required template types must be listed
- [ ] Set all `ptables`
- [ ] Set `architectures`
- [ ] Order: newest version first within each major version

### activation_keys.yml
- [ ] Update or add activation keys referencing the new content view + lifecycle environment
- [ ] Verify content overrides include Satellite Client 6 label

### hostgroups.yml
- [ ] Update `operatingsystem` to match the new OS entry name (e.g. `"RHEL 9.8"`)
- [ ] Update `kickstart_repository` to match the repo enabled in Satellite
- [ ] Verify `content_view` and `activation_keys` are consistent

---

## Known Issues and Lessons Learned

### Pulp Duplicate Content (aadsshlogin / RHEL 9.8 Kickstart)
**Symptom:** `Cannot create repository version. More than one rpm.package content with
duplicate values for name, epoch, version, release, arch, location_href.`

**Cause:** The `aadsshlogin` package exists in both the RHEL 9.8 kickstart repo
AND the streaming AppStream RPMs repo. Including both in the same content view
triggers a Pulp uniqueness violation.

**Workaround:** Use the previous minor version kickstart (e.g. 9.7) in the content
view until Red Hat publishes a corrected 9.8 content sync. The `aadsshlogin` duplicate
affects both x86_64 and aarch64. Track the Red Hat Satellite/Pulp bug tracker for resolution.

**Note:** This is a Red Hat upstream packaging issue, not a rhis-builder or Satellite
configuration issue.

### Adding a New Lifecycle Environment to an Existing Deployment
**Symptom:** `Cannot promote environment out of sequence.` when the `activation_keys`
or `content_views` roles run.

**Cause:** Content views that were promoted to Production before the new environment
(e.g. Staging) was inserted must be re-promoted through the new environment to
close the gap.

**Fix:** Manually promote affected content views through the new environment via the
Satellite UI, then re-run the role. Or: add `force_promote: true` support to the
`content_views` role (see `schema/TODO.md`).

**Prevention:** When adding `Staging` to `environments:` lists in `content_views.yml`,
ensure ALL content views that already have `Production` also have `Staging` listed
between `Qualification` and `Production`. The script `schema/scripts/check_cv_environments.py`
(to be written) can audit this automatically.

### Lifecycle Environment Sequencing
The correct promotion path is:
```
Library → Development → Qualification → Staging → Production
```
Content views MUST be promoted in this exact sequence. Skipping an environment
requires `force_promote`.

### Activation Keys Require Promoted Content Views
An activation key will fail to create if its content view has not been promoted to
the specified lifecycle environment. The `activation_keys` role runs after
`content_views` — if `content_views` fails partway through, activation key creation
will fail on any key that references an unpromoted view.

### Operating System Definition Must Precede Hostgroup Creation
Satellite's hostgroup creation validates that the referenced operating system,
kickstart repository, content view, and lifecycle environment all exist and are
compatible. A hostgroup creation will fail if:
- The OS version doesn't exist in Satellite
- The kickstart repo is not in the content view
- The content view is not promoted to the hostgroup's lifecycle environment

### Static IP / DNS Dependency
The kickstart for each host must specify correct nameservers at install time.
If the IdM DNS server address changes (e.g. `.5` → `.10`), the kickstart files must
be regenerated via `bootstrap_init` — the IPA client installer bakes the DNS address
into `/etc/NetworkManager/conf.d/zzz-ipa.conf` during enrollment, overriding any
subsequent `nmcli` changes.

See `schema/TODO.md` — **Static IP Address Assignment Cross-Project Brittleness**
for the full remediation plan.

---

## Content View Promotion Model

| Content View Type | Promotes to |
|---|---|
| Non-OS single CVs (AAP, EPEL, EdgeManager, JBoss, MSSQL, etc.) | Library only |
| OS content views (SOE8, SOE9, SOE10, etc.) | Up to Production |
| OS content views — dev/test only (CentOS Stream 9) | As far as used |
| Composite content views | Follow OS rules (up to Production) |

See `schema/TODO.md` — **Deprecation Tagging Model** for the planned `rhis_lifecycle`
field that will make this model machine-readable.
