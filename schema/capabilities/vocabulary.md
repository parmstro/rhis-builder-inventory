# RHIS Capability and Feature Vocabulary

Controlled terms used across all capability records, feature records, commit messages,
and TODO entries. Adapt Greg Procunier's eigenstate-ipa model to the rhis-builder context.

---

## Status Values

Applied to both capabilities (overall) and individual features (per component).

| Status | Meaning |
|---|---|
| `implemented` | Code exists, has been run end-to-end, `last_verified` is set |
| `partial` | Core function works; integration, automation, or test coverage incomplete |
| `broken` | Was fully implemented and working; broken by an external change (dependency, API, platform update). Code exists but does not currently function. Distinct from `partial` — this was working, something external broke it. |
| `designed` | Implementation plan is clear and agreed; code not yet written |
| `aspirational` | Direction set; design work still needed before implementation can begin |

A feature cannot move from `partial` → `implemented` without a `last_verified` date
and at least one completed evidence entry in the verification record.

---

## Workflow Boundary Types

Describes the blast radius and reversibility of a capability or feature.
Adapted from Greg Procunier's eigenstate-ipa `workflow_boundary` vocabulary.

| Boundary | Meaning |
|---|---|
| `read-only` | Reads state only; no changes to any system |
| `preflight` | Checks prerequisites or policy before a mutating workflow runs |
| `check-mode` | Dry-run; predicts changes without applying them |
| `mutating` | Changes live infrastructure state (Satellite, IdM, AAP, hosts, cloud) |

---

## Evidence Shape Types

Describes what kind of artifact proves a feature works.
A feature record must name at least one evidence shape before it can be `designed`.
Evidence must be captured before it can be `implemented`.

| Shape | Meaning |
|---|---|
| `play-recap` | Ansible play recap line: `ok=N changed=N failed=0` |
| `pipeline-run` | Full SOE Content Delivery Pipeline run — the primary proof mechanism for RHIS |
| `build-log` | Container build, image build, or satellite-installer log output |
| `sql-query` | Database query result (e.g. Pulp DB duplicate check for aadsshlogin) |
| `api-response` | Satellite, Pulp, or cloud provider API response |
| `host-test` | Outcome of testing on a provisioned host (boot, auth, encryption, compliance) |
| `satellite-ui` | Visual confirmation in Satellite web UI (used when no API equivalent exists) |
| `journal` | systemd journal or application log confirming service state |
| `idm-vault` | Content retrieved from an IdM vault entry (escrow proof) |

---

## Authority / Component Names

The systems that own state in RHIS. Used in `authority:` fields in capability
and feature records to declare which components are involved and who owns what.

| Name | What it owns |
|---|---|
| `satellite` | Content management, host provisioning, activation keys, compute resources, settings |
| `pulp` | Content repository storage underlying Satellite |
| `cdn` | Red Hat CDN — external, not controlled by RHIS; treated as upstream source |
| `idm` | Identity, DNS, Kerberos, certificates, vaults, HBAC, sudo rules, user/group policy |
| `aap` | Automation orchestration, workflow templates, job templates, execution mesh |
| `receptor` | Mesh overlay network transport — underlies AAP execution node connectivity |
| `kvm` | KVM/libvirt hypervisor — local virtualization compute resource |
| `provisioner` | rhis-provisioner-container — the execution engine that runs rhis-builder plays |
| `imagebuilder` | RHEL Image Builder service — builds cloud and disk images from blueprints |
| `tang` | Tang server — provides key material for NBDE unlock at boot |
| `tpm` | Trusted Platform Module (physical or virtual vTPM) — machine identity binding |
| `yubikey` | YubiKey PIV hardware token — smart card authentication device |
| `quay` | Container image registry — internal distribution of container images |
| `vault` | `rhis_builder_vault.yml` — secrets store for cloud credentials, passwords, tokens |
| `cloud` | Cloud provider (Azure, AWS, GCP, etc.) — external compute and storage |
| `eigenstate-ipa` | Greg Procunier's IdM vault and break-glass automation library (planned integration) |

---

## Hypothesis Convention

Used in commit messages and TODO entries when a change is testing an assumption
rather than applying a confirmed fix. Prevents "suspected resolved" from being
written as "is resolved."

```
hypothesis:        what we believe to be true (not what we know)
workflow_type:     mutating | preflight | read-only
test_criteria:     what we need to observe to confirm the hypothesis
evidence_shape:    type of proof required
evidence:          actual result (empty until the test runs)
residual_risk:     what breaks and how to recover if the hypothesis is wrong
last_verified:     YYYY-MM-DD (empty until confirmed)
```

**Example** (what the aadsshlogin commit should have said):
```
hypothesis:        Red Hat may have resolved the aadsshlogin CDN duplicate content
                   bug based on recent advisories — re-enabling 9.8 kickstart repos
                   to test
workflow_type:     mutating
test_criteria:     SOE9 CV publish completes with failed=0
evidence_shape:    play-recap
evidence:          —
residual_risk:     SOE9 publish fails; recovery is to re-comment 9.8 kickstart repos
                   in content_views.yml (reversible in one commit)
last_verified:     —
```

---

## Pipeline Integration Fields

Every feature that can be tested through the SOE Content Delivery and Validation
Pipeline should declare these fields in its feature record. This is the primary
proof mechanism for RHIS — `last_verified` for a feature is the last time the
pipeline ran successfully with that feature enabled.

```
pipeline_phase:    content-update | host-provision | snapshot | deploy | smoke-test | qa-test | prod-test
test_playbook:     path to the playbook that produces evidence for this feature
```

Features that cannot be tested through the pipeline (e.g. IdM-only features)
use `pipeline_phase: n/a` and must specify an alternative evidence shape and
test procedure.
