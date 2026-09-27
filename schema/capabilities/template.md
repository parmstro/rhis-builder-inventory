# Feature Record Template

Copy this file to `schema/capabilities/FEAT-NNN_short_name.md` and fill in all fields.
Fields marked `—` are empty until work is done. Do not delete them — an empty field is
an honest statement that work or evidence is pending.

See `vocabulary.md` for valid values for each field.

---

```markdown
---
feature_id:     FEAT-NNN
name:           Feature Name
capability:     CNN — Capability Name
component:      rhis-builder-satellite | rhis-builder-idm | rhis-builder-aap | rhis-provisioner-container | rhis-builder-imagebuilder | rhis-builder-yubikey | rhis-builder-inventory
status:         implemented | partial | designed | aspirational
last_verified:  YYYY-MM-DD
---

## Outcome

What the operator can do when this feature exists. One or two sentences.

## Authority

Which systems are involved. List from vocabulary.md authority names.

## Workflow Type

read-only | preflight | check-mode | mutating

## Preconditions

What must be true before this feature applies or can be tested.

- Precondition 1
- Precondition 2

## Out of Scope

What this feature explicitly does not do.

## Acceptance Criteria

| ID | Statement | Evidence Shape | Evidence | Status |
|---|---|---|---|---|
| AC-1 | First thing that must be true for this feature to be done | play-recap | — | pending |
| AC-2 | Second thing | pipeline-run | — | pending |

## Pipeline Integration

pipeline_phase:   content-update | host-provision | snapshot | deploy | smoke-test | qa-test | prod-test | n/a
test_playbook:    path/to/test_playbook.yml (or — if not yet written)

If `pipeline_phase: n/a`, describe the alternative test procedure here.

## Hypothesis / Change History

Use this section when a change to this feature is testing an assumption rather
than applying a confirmed fix.

```
date:              YYYY-MM-DD
hypothesis:        what we believed to be true
workflow_type:     mutating
test_criteria:     what we needed to observe
evidence_shape:    type of proof
evidence:          what actually happened
result:            confirmed | refuted
```

## Verification Record

| Date | Result | AC IDs Passed | Evidence Location | Notes |
|---|---|---|---|---|
| — | — | — | — | — |

## Open Questions / Known Gaps

List anything that is unresolved, partially understood, or known to be missing.
```

---

## Example: RHEL 9.8 Kickstart Repo — CDN Duplicate Content (aadsshlogin)

```markdown
---
feature_id:     FEAT-005a
name:           RHEL 9.8 Kickstart repos in SOE9 content view
capability:     C05 — Content Lifecycle Management
component:      rhis-builder-satellite
status:         partial
last_verified:  —
---

## Outcome

SOE9 and SOE9_aarch64 content views include RHEL 9.8 kickstart repositories,
enabling hosts to be provisioned from current 9.8 kickstart media.

## Authority

satellite, pulp, cdn

## Workflow Type

mutating

## Preconditions

- Red Hat CDN must no longer include duplicate aadsshlogin package entries
  in the 9.8 kickstart repos

## Out of Scope

Does not include RHEL 9.8 point-in-time RPM repos (already present in LEAPP CVs).

## Acceptance Criteria

| ID | Statement | Evidence Shape | Evidence | Status |
|---|---|---|---|---|
| AC-1 | SQL query for aadsshlogin duplicates returns zero rows after fresh sync | sql-query | — | pending |
| AC-2 | SOE9 CV publish completes with failed=0 | play-recap | — | pending |
| AC-3 | SOE9_aarch64 CV publish completes with failed=0 | play-recap | — | pending |

## Pipeline Integration

pipeline_phase:   content-update
test_playbook:    —

## Hypothesis / Change History

date:              2026-06-04
hypothesis:        Red Hat had resolved the aadsshlogin CDN duplicate content bug
workflow_type:     mutating
test_criteria:     SOE9 CV publish completes with failed=0
evidence_shape:    play-recap
evidence:          Build failed. ASYNC FAILED on satellite1.example.ca:
                   "Cannot create repository version. More than one rpm.package
                   content with the duplicate values for name, epoch, version,
                   release, arch, location_href."
                   Foreman log: request fd7c394a, Pulp task 019e9287-1c5f-7e2e-80aa-65938a35c20f
                   39 aadsshlogin versions confirmed duplicated in Pulp DB.
result:            refuted — CDN bug NOT resolved

## Verification Record

| Date | Result | AC IDs Passed | Evidence Location | Notes |
|---|---|---|---|---|
| 2026-06-04 | FAIL | none | deployments/example.ca/vars/build_sat_primary.log:6114 | aadsshlogin CDN duplicate content bug confirmed present |

## Open Questions / Known Gaps

- No Red Hat advisory or bug tracker reference confirming CDN fix. Monitor and
  re-run SQL verification before next re-enable attempt.
- Verification SQL: `SELECT name, epoch, version, release, arch, location_href, COUNT(*)
  FROM rpm_package WHERE name = 'aadsshlogin'
  GROUP BY name, epoch, version, release, arch, location_href HAVING COUNT(*) > 1;`
```
