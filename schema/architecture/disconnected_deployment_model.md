# Disconnected Deployment Model

**Status:** Active design  
**Related capability:** C10 — Disconnected / Air-Gapped Operation  
**Last updated:** 2026-06-10

---

## Problem Statement

"Disconnected" covers an enormous range. At one end: a lab satellite moved behind a firewall
to test the export/import workflow. At the other end: a NASA-style mission system where the
highside is a complete operational environment with its own identity, automation, compliance
posture, and content scope — and where what is allowed on the highside is a deliberate
security and policy decision, not a copy of the lowside.

The RHIS disconnected model must support the full spectrum. The tooling and templates cannot
assume a digital twin — they must be flexible enough for an operator to build the minimal
authorized environment — but the default starting point should be a digital twin, which the
operator then reduces to their required configuration.

This document captures how the spectrum is structured, what changes at each tier, and what
the current implementation provides or leaves to operator configuration.

---

## The Deployment Spectrum

### Tier 1 — Basic: Core infrastructure only

**Operator profile:** MIC (Mission Impact Classified) or similar high-security environment.
The highside hosts IdM and Satellite. Minimal content — only what managed hosts on the
highside need to function. No AAP on the highside.

**What's on the highside:**
- Red Hat IdM (identity, DNS, Kerberos, certificates)
- Red Hat Satellite (content delivery, provisioning, subscription management)
- Minimal content: RHEL base + a small set of authorized packages for the target workloads

**Export scope:** Scoped — not the full Library. Only the repositories and content views
that feed the highside's authorized workloads. A full Library export and import is wasteful
and potentially contrary to the content authorization policy (content that is not authorized
for the highside should not cross the air gap, even if it is never published to a CV).

**AAP on highside:** No. Automation on the highside is driven by the rhis-provisioner
container (which crosses the air gap as a pre-packaged container image in the transfer bundle)
running against the highside inventory. The provisioner does not need a git endpoint once
the container image and bundle are imported.

**Ansible role set:** Minimal — only roles required for the build workflow. The compliance
role library (imported via `imported_git_repos`) is typically reduced or omitted unless the
highside has a specific compliance scanning requirement.

**Content authorization model:** What is permitted on the highside is defined by the highside
`content_views.yml` and `repositories.yml`. An operator building a Tier 1 deployment should
edit these files to contain only authorized content before generating the deployment config,
not rely on the template default.

---

### Tier 2 — Managed: Full RHIS stack with authorized content scope

**Operator profile:** Defense or intelligence environments where RHIS capabilities are
required on the highside but content is filtered by classification, program, or authorization
boundary. AAP is present but project sources must be available locally.

**What's on the highside:**
- Red Hat IdM
- Red Hat Satellite (full capability — provisioning, compliance scanning, subscription)
- Red Hat AAP (automation controller, execution nodes, event-driven automation)
- Content scoped to the highside authorization — not necessarily a full mirror of the lowside

**Export scope:** Scoped or full, depending on authorization model. The content view
configuration on the highside governs what is available — but the export scope should
not exceed the authorization boundary. If the highside is not authorized to hold RHEL 9
AppStream content unrestricted, that should be reflected in the export scope, not just
in CV filters.

**AAP on highside:** Present. This is the critical difference from Tier 1. AAP requires
git-hosted project source for all job templates. On the highside there is no external
git endpoint. This requires a Gitea (or equivalent) instance running on the highside
provisioner node, with all AAP project repos bundled in the transfer package and loaded
into the highside Gitea at import time. See [Open Architectural Questions](#open-architectural-questions).

**Ansible role set:** Full compliance role library, same as lowside — required for AAP-driven
compliance scanning and remediation on the highside. All repos bundled with `clone: false`
(verified from bundle sync, not GitHub).

**Content authorization model:** The highside `content_views.yml` diverges from the lowside.
Filters are more restrictive. Lifecycle environments may be different. Activation keys scope
to what is authorized. This is operator-defined, not template-generated.

---

### Tier 3 — Digital Twin: Complete mirror of the lowside

**Operator profile:** NASA-style mission systems, or test/validation environments where
exact replication of the lowside capability is required. The highside is operationally
equivalent to the lowside — same content, same automation, same compliance posture.

**What's on the highside:**
- Complete RHIS stack identical to the lowside
- Full Library content export and import — same repos, same CVs, same LCE topology
- AAP with same project source and same workflow definitions
- Same compliance role library and same SCAP policies

**Export scope:** Full Library. Every sync'd repository is included. The highside mirrors
the lowside content state at the time of the last export.

**AAP on highside:** Full digital twin — same workflows, same projects, same credentials
(adapted for highside endpoints). Gitea required as on Tier 2.

**Content authorization model:** Identical to the lowside. No content filtering beyond
what the lowside already applies. The digital twin policy assumes equivalence.

---

## Tier Comparison Summary

| Dimension | Tier 1 Basic | Tier 2 Managed | Tier 3 Digital Twin |
|---|---|---|---|
| IdM | ✓ | ✓ | ✓ |
| Satellite | ✓ | ✓ | ✓ |
| AAP | ✗ | ✓ | ✓ |
| Export scope | Scoped to authorization | Scoped or full | Full Library |
| Git source on highside | Not needed | Gitea required | Gitea required |
| Ansible role set | Minimal or none | Full | Full |
| Content authorization | Operator-defined subset | Operator-defined subset | Mirror of lowside |
| Highside `content_views.yml` | Custom — diverges from lowside | Custom — diverges from lowside | Copy of lowside |
| Template default | ← operator reduces from this | | Tier 3 → |

---

## How the Template System Handles This

The inventory template (`inventory_template/host_vars/satellite/`) generates a **Tier 3
starting point**. Running `inventory_update.sh` with `basevars_disconnected_domain: true`
produces a deployment that mirrors the lowside structure. The template handles:

- `imported_git_repos.yml` — `clone: false` and `satellite_roles_source_path` rendered
  automatically for disconnected deployments (`.j2` template conditional)
- `satellite_pre.yml` — `satellite_disconnected: true` derived from basevars flag
- `satellite_installer.yml` — `install-images false` must be manually set (file contains
  Ansible runtime variables that prevent clean Jinja2 conversion — see below)

**For Tier 1 or Tier 2 deployments**, the operator edits the generated deployment to reduce
scope. The primary files to customize after generation are:
- `content_views.yml` — remove unauthorized content views
- `repositories.yml` — remove unauthorized repositories
- `repository_sets.yml` — disable unauthorized repository sets
- `imported_git_repos.yml` — reduce or remove compliance role list
- `satellite_installer.yml` — set `install-images false`

The operator customization is deliberate: content authorization policy is a human decision,
not a template decision. The template cannot know what is authorized on the highside.

---

## Template Architecture Constraints

### Files that can be Jinja2-conditional on `basevars_disconnected_domain`

Files with only static values (hardcoded strings and booleans, no Ansible runtime variables)
can be converted to `.j2` templates that render different content for connected vs. disconnected
deployments. Current examples:

- `imported_git_repos.yml.j2` — renders `clone: false` and `satellite_roles_source_path`
  when disconnected

### Files that require Ansible role logic instead

Files that contain Ansible runtime variables (fact references, vault variable references,
other `{{ var }}` expressions evaluated at play execution time) cannot be cleanly converted
to `.j2` without wrapping every runtime variable in `{% raw %}`/`{% endraw %}`. For these
files, disconnected-specific behavior is handled in the Ansible role code rather than the
template.

Example: `satellite_installer.yml` contains `{{ sat_ssl_crt_path }}`, `{{ ipa_server_fqdn }}`,
`{{ foreman_proxy_realm_principal }}`, and many others. The `--foreman-proxy-plugin-discovery-install-images`
flag must be `false` on the highside, but this is handled by:

1. A comment in the template directing operators to change the value post-generation
2. **Open task:** A task in `rhis-builder-satellite` that conditionally removes the
   `install-images true` entry from `sat_installer_options` when `satellite_disconnected: true`
   — eliminating the need for manual post-generation edits

---

## Content Export Scoping

**Current state:** All exports are full Library exports. Every sync'd repository is included
in the transfer bundle regardless of the highside authorization model.

**The gap:** For Tier 1 and Tier 2 deployments, a full Library export may:
1. Include content that is not authorized for the highside (policy violation)
2. Be impractically large for the highside's actual needs (operational burden)

**Future direction:** The export should be driven by the highside's `content_views.yml` and
`repositories.yml`. The export scope is the union of repositories referenced by active content
views in the highside deployment configuration. This requires:
- The lowside export playbook to accept a manifest of what the highside needs
- Scoped CV exports rather than full Library export (Pulp supports this via `content_view`
  scoped exports)
- The `from_history_id` incremental export path (Adversarial Analysis Item 9)

Until scoped exports are implemented, Tier 1 and Tier 2 deployments require operators to
manually validate that the transfer bundle contents are within the authorization boundary.
This is a process control, not a technical enforcement.

---

## AAP on the Highside — The Gitea Requirement

AAP (Tier 2 and Tier 3) requires every project to have a reachable git endpoint. On the
highside there is no external git service. The solution is a Gitea container running on
the highside provisioner node.

**Bundle requirements for Gitea:**
- The Gitea container image must be included in the transfer bundle
- Every AAP project repository must be included as a bare git repo archive
- The import process must load repos into the highside Gitea and configure AAP projects to
  reference `http://<provisioner-node>/gitea/...` rather than external URLs

**Scope of change:**
- The transfer bundle assembly playbook (`export_disconnected.yml`) gains steps to export
  bare git repos from the lowside git server
- `export_deployment.sh` gains steps to bundle the Gitea container image
- The import playbook gains steps to start Gitea and load repos
- The highside AAP inventory (`group_vars/platform_installer/`) references the Gitea endpoint

This is not yet designed in detail. It is captured as an open architectural gap.

---

## Security Boundary Implications

The air gap is a security boundary, not just a connectivity constraint. Content that crosses
the boundary is subject to the highside authorization policy. RHIS currently has no technical
enforcement of this policy — it is a process control (operator validates the manifest before
transferring). Future controls could include:

- Manifest signing: the lowside operator signs the bundle manifest; the highside operator
  verifies before importing
- Content fingerprinting: SHA256 checksums of every artifact in the bundle (already
  implemented in the bundle manifest) allow the highside operator to verify integrity
- Policy-as-code: the highside `content_views.yml` is the authoritative statement of what
  is authorized; the export scope should be validated against it before transfer

The vault password is a special case: it must cross the air gap separately from the bundle.
It must never be included in the transfer media. This is documented in the operator checklist
but is not technically enforced.

---

## Open Architectural Questions

1. **Scoped export implementation:** What is the correct Pulp/Satellite API to export only
   the content referenced by a set of content views? Is it a CV-scoped export or a filtered
   Library export?

2. **Content authorization enforcement:** Should RHIS implement a technical check that
   validates the export scope against the highside's authorized repository list before
   the bundle is assembled? Where does that check live?

3. **Gitea on highside — operator model:** Who manages the highside Gitea? Is it the
   provisioner operator (one-time setup at import time) or an ongoing managed service?
   What is the upgrade path when the lowside AAP project repos change?

4. **Incremental export path:** Once scoped exports are implemented, incremental exports
   become practical. What is the correct pairing of lowside export history ID and highside
   import state tracking to make incremental transfers reliable?

5. **Digital twin synchronization cadence:** For Tier 3, how frequently does the digital twin
   need to be updated? Does the mission requirement define a maximum delta between lowside
   and highside state (e.g. "within 24 hours of a new RHEL errata")?

6. **Highside-only content:** Some environments require content to exist on the highside that
   does not exist on the lowside (classified patches, mission-specific packages). How does
   the RHIS model accommodate content that flows into the highside from a source other than
   the lowside export?
