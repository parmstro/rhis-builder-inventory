# Adversarial Analysis — Disconnected Satellite Deployment
**Date:** 2026-06-09
**Analyst:** Claude deep-research workflow (synthesized from project state, Red Hat documentation, Pulp upstream docs)
**Branch:** disconnected_satellite
**Status:** Working document — items resolved in-session are marked

> **Note:** This report was generated via the deep-research workflow and reconstructed
> from project state after context compaction. Items 1 and 2 were resolved during the
> 2026-06-09 session. Items 3–12 are open for review.

---

## Item 1 — Download policy not enforced at export time
**Risk:** Silent export — RESOLVED
**Status:** ✅ Resolved 2026-06-09

Repositories not set to `download_policy: immediate` produce export archives with complete
repodata XML but missing RPM artifacts. This surfaces only when clients on the highside try
to install packages — not at export time.

**Resolution:**
- `settings_content.yml` already sets `default_download_policy: immediate` at server level
- All active repos in `repositories.yml` have explicit `download_policy: immediate`
- Runtime preflight checks added to each `perform_*.yml` in the `content_exports` role —
  fail-fast before the export runs if any scoped repos are non-immediate

**Upstream gap identified:** `redhat.satellite.resource_info` index response omits
`download_policy` — should be fixed in foreman-ansible-modules. Workaround: use
`download_policy != immediate` as a scoped_search filter.

---

## Item 2 — Highside manifest configuration incorrect
**Risk:** Build failure when redhat_manifests role runs — RESOLVED
**Status:** ✅ Resolved 2026-06-09

**Technical finding:** `satellite1.highside.example.ca/manifests.yml` had `generate: true`,
which calls `subscription.rhsm.redhat.com`. The highside has no outbound internet access.
This would fail before SCA mode has any bearing.

**Legal finding:** The highside Satellite requires its own separate manifest allocation in
the Red Hat Customer Portal. SCA mode removes technical enforcement but not the contractual
obligation. The lowside manifest cannot be reused.

**Resolution:**
- `satellite1.highside.example.ca/manifests.yml` corrected to `generate: false` with
  `source: satellite1.highside.example.ca_manifest.zip` (matching `discosatellite1` pattern)
- `schema/disconnected_satellite_workflow.md` section 6.2 updated with:
  - Explicit note on legal requirement for separate allocation
  - Pre-export staging procedure: copy to `files/manifests/`, update `source:` in
    `manifests.yml`, then run the export so the bundle assembly picks it up

---

## Item 3 — Transfer bundle completeness not automated or validated
**Risk:** Silent incomplete transfer — HIGH
**Status:** ✅ Resolved 2026-06-09

Investigation found that bundle assembly was already implemented in
`export_disconnected.yml` (10 steps). The remaining gaps were:

**Gap A — Container image save (Step 7) was broken.** The playbook used
`delegate_to: provisioner_host` to save the image, but `provisioner_host` is not in
the satellite inventory scope. Tasks were silently skipped. Fix: replaced with a simple
`ansible.builtin.copy` from `{{ provisioner_image_tar }}` (a mounted tar file path).
`export_deployment.sh` runs `podman save` on the host before launching the container
and mounts the result (Option A — avoids chicken-and-egg).

**Gap B — `_manifests_src` path was wrong.** The playbook hardcodes
`_manifests_src: "files/manifests"` which resolves to `/rhis/rhis-builder-satellite/files/manifests/`
inside the container — a directory that doesn't exist. Manifest ZIPs were never
included in export bundles. Fix: `export_deployment.sh` mounts the highside deployment's
`files/` directory at `/rhis/vars/highside_files` and passes
`_manifests_src=/rhis/vars/highside_files/manifests` as an extra-var.

**Gap C — No outer wrapper script.** Operator had to manually enter an interactive
container shell and call multiple scripts. Fix: `export_deployment.sh` in
`rhis-builder-inventory/` provides a single command covering: validate → save image →
Stage 1 (export playbook) → Stage 2 (copy to media) → report.

**Resolved artifact table:**

| Artifact | Automation status |
|---|---|
| Pulp Library export | ✅ `content_exports` role |
| rhis-builder-inventory archive | ✅ Step 6 in `export_disconnected.yml` |
| rhis-provisioner container image | ✅ Step 7 — via `export_deployment.sh` + Option A |
| Compliance-as-code Ansible roles | ✅ Steps 3–4 in `export_disconnected.yml` |
| Foreman discovery images | ✅ Step 4 (warn if absent — see Item 4) |
| Highside subscription manifests | ✅ Step 5 — `export_deployment.sh` sets correct `_manifests_src` |
| Bundle manifest + checklist | ✅ Steps 9–10 in `export_disconnected.yml` |
| Copy to transfer media | ✅ Stage 2 via `copy_to_transfer_media.yml` |
| Operator steps | ✅ Reduced to: mount drive, run one command, disconnect drive |

---

## Item 4 — Discovery image pre-staging on highside fails silently
**Risk:** Foreman discovery not functional on highside — HIGH
**Status:** ✅ Resolved 2026-06-10

`--foreman-proxy-plugin-discovery-install-images true` in the highside
`satellite_installer.yml` caused satellite-installer to download the FDI image tarball
from `http://downloads.theforeman.org/discovery/releases/latest/` — which fails with no
internet access. This is a hard failure (puppet catalog fails, satellite-installer exits
non-zero). The `--foreman-proxy-plugin-discovery-source-url` installer option exists
(confirmed from `satellite-installer --full-help` on `satellite1.example.ca`) but
requires a running HTTP server reachable from the highside — unnecessary complexity.

**Resolution (Option A — Ansible-managed staging):**
- `satellite_installer.yml` for the highside: changed `install-images true` → `false`
- Template `satellite_installer.yml`: added comment documenting the disconnected change
- New `satellite_disconnected_discovery_images_src` variable added to `satellite_pre.yml`
  (template and highside deployment) — set to the bundle's `discovery_images/` path
- `satellite_post/tasks/main.yml`: new block inside the `when: satellite_disconnected`
  guard — after satellite-installer creates `/var/lib/tftpboot/`, copies images from
  `{{ satellite_disconnected_discovery_images_src }}/` to `/var/lib/tftpboot/boot/`

**Operator action required before highside build:**
Set `satellite_disconnected_discovery_images_src` in
`host_vars/satellite1.<highside>/satellite_pre.yml` to the `discovery_images/` path
from the mounted transfer bundle.

---

## Item 5 — Compliance-as-code roles not extractable on highside (GAP 1pt2)
**Risk:** Imported_git_repos role failure or silent skip — HIGH
**Status:** ✅ Resolved 2026-06-10

**Part 2 (role code)** was already implemented in `imported_git_repos/tasks/main.yml`:
an assert verifying `satellite_roles_source_path` is set when disconnected, then an
`ansible.posix.synchronize` that rsync's the bundle's `ansible_roles/` tree into
`/etc/ansible/roles/` on the highside. The subsequent `ansible.builtin.git` calls run
with `clone: false` (verify local repo state, no GitHub access needed).

Export bundle Step 3 copies the full `/etc/ansible/roles/` directory tree (including
`.git/` subdirectories) to `<bundle>/ansible_roles/` — so the sync'd repos are valid
git repositories on the highside.

**Part 1 (host_vars)** was applied to `discosatellite1.highside.example.ca` but NOT to
`satellite1.highside.example.ca`. Fixed 2026-06-10:
- Added `satellite_roles_source_path: "/home/ansiblerunner/rhis_export/ansible_roles"`
  to `satellite1.highside.example.ca/imported_git_repos.yml`
- Changed all 24 active `clone: true` → `clone: false` entries in that file
- Added header comment explaining the disconnected build pattern (matching discosatellite)

**Root cause of the gap:** When the `discosatellite` host type was retired in favour of a
generic `satellite` deployment, disconnected-specific customizations in the discosatellite
template were lost. The generic satellite template rsync'd `clone: true` to the highside
deployment on every `inventory_update.sh` run, silently overwriting any manual fix.

**Template fix (2026-06-10):**
- `inventory_template/host_vars/satellite/imported_git_repos.yml` converted to
  `imported_git_repos.yml.j2`
- Template conditionally renders `clone: false` and `satellite_roles_source_path` when
  `basevars_disconnected_domain: true` — regenerating a highside deployment with
  `inventory_update.sh` now produces the correct file automatically
- Note: `satellite_installer.yml` still has runtime Ansible variables (e.g. cert paths,
  IdM vars) that prevent clean `.j2` conversion. The `install-images false` change for
  disconnected deployments must be handled in `rhis-builder-satellite` role logic
  (filter `sat_installer_options` when `satellite_disconnected: true`) — open task.

**Operator action required before highside build:**
Confirm `satellite_roles_source_path` points to the extracted `ansible_roles/` directory
from the import bundle on the highside satellite host.

---

## Item 6 — No import orchestration script (GAP 8)
**Risk:** Manual error-prone import sequence — HIGH
**Status:** Open

The `content_imports` role works. There is no `build_sat_disconnected_import.sh` helper
script to drive the full highside import sequence. Operators must manually:
1. Mount transfer media
2. Stage bundle artifacts to correct paths
3. Construct and invoke the correct `ansible-playbook` command with right inventory and limit
4. Manage the `satellite_import_content` flag across re-runs

**What's needed:** `build_sat_disconnected_import.sh` in rhis-provisioner-container that:
1. Validates `rhis_disconnected_manifest.yml` checksums before starting
2. Stages bundle artifacts to configured highside paths
3. Invokes `main.yml` with `satellite_disconnected: true` and `satellite_import_content: true`
4. Provides clear output on completion with next steps

---

## Item 7 — Content view promotion after import requires documentation (GAP 9)
**Risk:** Activation key failures post-import — MEDIUM
**Status:** Partially addressed (mechanism is correct, documentation is unclear)

After `content_imports` runs, imported content is in Library but NOT promoted through
lifecycle environments (Development → Qualification → Staging → Production).
Activation keys referencing non-Library environments fail until promotion is complete.

The `content_views` role runs unconditionally in `main.yml` AFTER content import and
handles publication and promotion — this is already correct. The gap is operator
awareness: without clear documentation, operators may assume the import is complete
and attempt host registration before lifecycle promotion has run.

**Action:** Clarify in `disconnected_satellite_workflow.md` section 6.3 that the
`content_views` role run after import handles promotion, and that host registration
should not be attempted until the full `main.yml` play completes.

---

## Item 8 — aadsshlogin CDN bug blocks RHEL 9.8 kickstart content views
**Risk:** RHEL 9.8 kickstart repos unusable — MEDIUM
**Status:** Open (workaround documented in TODO.md)

Pulp rejects CV publish with a duplicate content error on all RHEL 9.8 kickstart repos
(AppStream and BaseOS, x86_64 and aarch64). Root cause: `aadsshlogin` has 39 duplicate
content unit records with identical `(name, epoch, version, release, arch, location_href)`.

**Current state:** 9.8 kickstart repos remain commented out in `content_views.yml`.
The repos are synced and working — only CV publish fails.

**Test plan (from TODO.md):**

| Scenario | Contents | Filter | Expected |
|---|---|---|---|
| 1 | 9.8 Kickstart + RPMs 9 | none | FAIL (control) |
| 2 | 9.8 Kickstart + RPMs 9 | rpm exclude `aadsshlogin*` | unknown |
| 3 | 9.8 Kickstart only | none | unknown |

Run scenario 1 first. If the CDN has resolved the duplicate, skip 2/3 and re-enable
the repos in templates.

**Verification query (run on satellite PostgreSQL):**
```sql
SELECT name, epoch, version, release, arch, location_href, COUNT(*)
FROM rpm_package WHERE name = 'aadsshlogin'
GROUP BY name, epoch, version, release, arch, location_href HAVING COUNT(*) > 1;
```

---

## Item 9 — All exports are full Library exports — no incremental path
**Risk:** Impractical transfer cadence for large libraries — MEDIUM
**Status:** Open

The active export configuration sets `incremental: false`. Every transfer cycle requires
a full Library export regardless of what has changed since the last export. For a 1.27 TB+
library, this means the transfer media must carry the full volume every cycle.

Satellite and the `content_exports` role support incremental exports via `from_history_id`.
The lowside export playbook (when implemented) should capture the export history ID from
each run and make it available for the next incremental export. The operator or automation
must manage the `from_history_id` value between runs.

**Architectural decision point:** Incremental exports are only useful if the highside
can also do incremental imports. Confirm that `content_imports` + the highside Satellite
support incremental import before building the incremental export workflow.

---

## Item 10 — Vault password transport has no technical enforcement
**Risk:** Vault password included in bundle (security breach) — HIGH if misconfigured
**Status:** Partially mitigated (documented, not enforced)

The vault password must cross the air gap via a separate trusted channel — never in the
transfer bundle. The planned bundle manifest will include a checklist item for this.
The export checklist template has a warning. But there is no technical control preventing
an operator from including the vault password in the bundle.

**Mitigations in place:**
- Vault password is not a file in the inventory tree — it must be provided manually to
  `ansible-vault` or via `--vault-password-file`
- The default `.gitignore` excludes vault password files
- The bundle checklist documents this requirement

**What cannot be enforced technically:**
- Whether the operator emails/slacks the vault password alongside the transfer media
- Whether the vault password file ends up copied into the inventory archive accidentally

**Recommended:** Add a note in the export playbook final output explicitly stating the
vault password must NOT accompany the bundle, and log this as a required manual
attestation step in the bundle manifest.

---

## Item 11 — Lab prerequisites not met for end-to-end validation
**Risk:** Untested workflow shipped as production-ready — HIGH
**Status:** Open

The disconnected satellite workflow has not been validated end-to-end in a proper air-gap
environment. The current `discosatellite1.example.ca` is reachable from the lowside but
is not truly isolated (it still has a network path to CDN).

**Prerequisites before C10 (disconnected satellite capability) can be declared complete:**

- [ ] Choose highside domain name (e.g. `disconnected.local`)
- [ ] Configure OPNsense — highside segment: no outbound route, inbound from lowside only
- [ ] Verify lowside provisioner can reach highside hosts (SSH test)
- [ ] Verify highside cannot reach CDN (curl test from highside host)
- [ ] Allocate Chassis 3 hardware for the highside segment
- [ ] Build highside inventory in rhis-builder-inventory (new deployment)
- [ ] Run end-to-end: export → transfer → import → host registration

Until this is done, the workflow is designed but not proven.

---

## Item 12 — Bootstrap_init migration leaves dual sources of truth
**Risk:** Stale baremetal_init repo used in new builds — MEDIUM
**Status:** Open (transition in progress)

The `bootstrap_init` role was copied (not moved) from `rhis-builder-baremetal-init` to
`rhis-builder-bootstrap-init`. PRs #8/#10/#31/#4 are open for heatmiser review. The old
repo retains the role during the transition.

**Risk:** If any rhis-builder project still references `rhis-builder-baremetal-init` for
`bootstrap_init`, it will receive stale code after the new repo diverges. Conversely,
contributors who find the role in the old repo may submit PRs there rather than the
canonical new location.

**Resolution path:** Once all consumer PRs are merged and the new repo is confirmed
working in a build, deprecate the role in `rhis-builder-baremetal-init` with a README
redirect and remove the task files, leaving only the deprecation notice.

---

## Summary — Priority Order

| # | Item | Risk | Status |
|---|---|---|---|
| 1 | Download policy not enforced at export time | Silent incomplete export | ✅ Resolved |
| 2 | Highside manifest configuration incorrect | Build failure | ✅ Resolved |
| 3 | Transfer bundle completeness not automated | Silent incomplete transfer | ✅ Resolved |
| 4 | Discovery image pre-staging fails on highside | Discovery non-functional | ✅ Resolved |
| 5 | Compliance-as-code roles not extractable (GAP 1pt2) | Role import failure | ✅ Resolved |
| 6 | No import orchestration script (GAP 8) | Manual error-prone import | Open |
| 7 | CV promotion after import undocumented (GAP 9) | Activation key failures | Open |
| 8 | aadsshlogin bug blocks RHEL 9.8 kickstart CVs | Missing content | Open |
| 9 | No incremental export path | Impractical transfer cadence | Open |
| 10 | Vault password transport not technically enforced | Security risk if misconfigured | Open |
| 11 | Lab prerequisites not met for end-to-end validation | Untested workflow | Open |
| 12 | Bootstrap_init migration — dual sources of truth | Stale code risk | Open |
