# Export/Import Refactor — Programming Activities

**Date:** 2026-06-13
**Status:** In progress — analysis not yet complete. This list will grow as remaining
concerns (C12-C18, import side) are evaluated. Final workflow design will be clearer
once the full analysis is done; activities with overlapping scope should be grouped
into cohesive implementation tasks before a working session begins.

---

## From C7 — Drive validation timing

- [ ] Archive/retire `content_export_prepare_drv` role entirely — all tasks
  (`validate_drive.yml`, `discover_drive.yml`, `mount_drive.yml`, `unmount_drive.yml`,
  `validate_mount.yml`) are deprecated; fresh implementation replaces them
- [ ] Add pre-export satellite warning to export playbook: emit free space on
  `/var/lib/pulp` and size of most recent previous export as operator reference;
  warning only — do not assert or block (incremental export size is unpredictable)
- [ ] Add post-staging size report: after Pulp export and all RHIS staging complete,
  compute total across all staged areas (Pulp api path + satellite staging + provisioner
  staging + bootstrap staging) and report required drive capacity to operator
- [ ] Implement pre-transfer drive check in generated `transfer_to_drive.sh`: assert
  `df_avail(media_path) >= total_staged_bytes` and filesystem type in `[ext4, xfs]`
  before any rsync starts; exit with clear message on failure — no partial transfers

---

## From C8 — Containers/other list

- [ ] Interim: add Tang `podman pull` + `podman save` to export staging; write tar to
  `rhis_export_staging/provisioner/<timestamp>/containers/tang_<timestamp>.tar` using
  explicit reference to `hostvars[quadlet_host].containers` — not a generic loop
- [ ] Provisioner image: write `podman save` output to
  `rhis_export_staging/provisioner/<timestamp>/containers/rhis-provisioner_<timestamp>.tar`
  (replaces current mechanism of mounting the tar into the container via extra-var)
- [ ] Design and implement export manifest: record resolved image digest for provisioner
  image and Tang at export time; annotate `:latest` references as "latest at export time";
  manifest format to be defined during implementation
- [ ] Ecosystem refactor (future): implement generic aggregation of `containers:` lists
  across all quadlet hosts; determine canonical highside scope variable; replace Tang
  explicit reference with generic mechanism

---

## From C9 — RHEL and Satellite DVD ISO sourcing

- [ ] Add disconnected ISO path variables to `inventory_basevars.yml` template:
  `basevars_rhel_dvd_iso_path` and `basevars_satellite_dvd_iso_path`; document
  explicitly as paths ON THE PROVISIONER NODE, required when disconnected is true
- [ ] Add render-time validation: fail deployment render if `basevars_disconnected_domain`
  is true and either ISO path is absent or empty string
- [ ] Render ISO paths into deployment as non-basevars variables (available to Ansible
  at playbook runtime)
- [ ] Add pre-flight assert tasks to export playbook: verify both ISO files exist at
  rendered paths ON THE PROVISIONER before any staging begins; fail fast with named
  file in error message
- [ ] Add infra ISO copy operations to generated transfer script: copy
  `basevars_rhel_dvd_iso_path` and `basevars_satellite_dvd_iso_path` directly from
  provisioner to `TRANSFER_DRV/bootstrap/infra_isos/` (no intermediate staging)

---

## From C10 — Bootstrap artifacts staleness and staging

- [ ] Integrate `build_highside_isos.sh` bootstrap ISO generation into the export
  playbook as a mandatory non-optional step; ISO generation always runs as part of
  every export — never a separate manual script call
- [ ] Implement as an Ansible role or task file (not a shell script call) that runs
  the `bootstrap_init` playbook via `ansible.builtin.include_role` or equivalent;
  requires vault access for encrypted password variables
- [ ] Write generated ISOs to `rhis_export_staging/bootstrap/<timestamp>/bootstrap_isos/`
  so the transfer script rsyncs them to `TRANSFER_DRV/bootstrap/bootstrap_isos/`;
  remove the separate SSH push step from the current `build_highside_isos.sh`
- [ ] Stage `rhis-builder-bootstrap-init` repo at export time to
  `rhis_export_staging/bootstrap/<timestamp>/rhis-builder-bootstrap-init/`
  (git clone or rsync from provisioner's local checkout); transfer script rsyncs it
  to `TRANSFER_DRV/bootstrap/rhis-builder-bootstrap-init/`
- [ ] Retire or archive `build_highside_isos.sh` once the integrated Ansible
  implementation is verified

---

## From C11 — `rhis-builder-inventory` archive in export workflow

- [ ] Add inventory archive step to export workflow: `git archive HEAD | tar -x -C
  rhis_export_staging/provisioner/<timestamp>/inventory/` — extracts full committed
  repo as a directory (not tar.gz); no log files, temp state, or uncommitted changes
- [ ] Inject `content_imports.yml` into the extracted directory at
  `rhis_export_staging/provisioner/<timestamp>/inventory/deployments/<highside_domain>/host_vars/satellite1/content_imports.yml`
  after git archive extraction completes and after Pulp export path is known (C6 step);
  injection must complete before transfer script runs
- [ ] Transfer script rsyncs `rhis_export_staging/provisioner/<timestamp>/inventory/`
  to `TRANSFER_DRV/provisioner/inventory/` as a ready-to-use directory — highside
  operator can rsync directly onto provisioner node with no extraction step
- [ ] Include UC1/UC2/UC3 use cases and fork-per-security-target pattern in the
  operator-facing `README_FIRST.md` at the transfer drive root so the structural
  approach to security separation is clear to the highside operator

---

## From C12 — `export_rhis_container.sh` orphan

- [x] Delete `export_rhis_container.sh` — fully superseded by `export_disconnected.yml`
  Step 7; no replacement needed. Chain verified: `podman save` → mounted into container
  → `copy` to `{{ _bundle_dir }}/container/` on satellite → rsynced to drive by
  `copy_to_transfer_media.yml`. **DONE 2026-06-14 — file deleted.**

---

## From C6 — `content_imports.yml` lifecycle (code gaps identified 2026-06-15)

- [ ] Apply `/exports/` → `/imports/` prefix remap in `generate_content_imports_file.yml`:
  `import_path` is currently set directly from `_export_path` with no transformation;
  remap must be applied so the highside import path is correct without manual editing
- [ ] Change placement: file must be written to the provisioner staging inventory at
  `rhis_export_staging/provisioner/<timestamp>/inventory/deployments/<highside_domain>/host_vars/satellite1/content_imports.yml`
  rather than the current `/var/lib/pulp/exports/rhis_import_export_data/<timestamp>_content_imports.yml`
  on the satellite — this injection step runs after `git archive` extraction (see C11)

---

## From C19 — RHIS transfer manifest generation and highside validation

**RECOVERED CONCERN** — `validate_import_bundle.sh` already implements the highside
validation side against `rhis_export_manifest.yml`. The generate side and the
path updates to match the C3 drive layout are not yet implemented.

- [ ] Implement manifest generation step in export playbook: after all staging completes,
  compute SHA256 for each staged artifact (inventory tar.gz, container tars, bootstrap ISOs,
  infra ISOs, bootstrap-init tar.gz); include resolved container digests (C8) as metadata
  alongside each container tar entry; write to
  `rhis_export_staging/provisioner/<timestamp>/rhis_export_manifest.yml`
- [ ] Include `rhis_export_manifest.yml` in the transfer script rsync so it lands
  at `TRANSFER_DRV/` root (alongside `README_FIRST.md` and `import_bundle.sh`)
- [ ] Update `validate_import_bundle.sh` artifact paths to match C3 drive layout:
  replace old `rhis_transfer_*/` bundle discovery with C3 top-level directories
  (`bootstrap/`, `provisioner/`, `satellite/`); update all artifact path references
- [ ] Replace stale `manifests/` check in `validate_import_bundle.sh` with a check
  for `*.zip` inside `provisioner/inventory/deployments/<highside>/files/` — subscription
  manifests travel inside the inventory tar.gz, not as a separate drive directory
- [ ] Confirm Pulp integrity check in `validate_import_bundle.sh` remains as-is:
  check for `metadata.json` present within the Pulp export path — do not checksum
  Pulp chunks in the RHIS manifest (Pulp's own metadata covers this)

---

## From C13 — Checkpoint and resume

- [ ] Write Pulp export completion marker file (`rhis_export_staging/.pulp_export_complete`)
  after the Pulp export step succeeds; record export timestamp and Pulp API path in the
  marker so downstream steps can reference it without re-querying the API
- [ ] Update `export_deployment.sh` wrapper to read the marker file on startup: if present,
  automatically pass `--skip-tags tags_content_exports` to the Ansible playbook invocation;
  log a clear message to the operator ("Pulp export already complete — skipping to staging")
- [ ] Delete the marker file at the start of a fresh export run (before Pulp export begins)
  so a prior run's marker cannot suppress a new export
- [ ] Add non-Pulp staging reset as the first task in the staging phase: remove and recreate
  `rhis_export_staging/provisioner/<timestamp>/` and `rhis_export_staging/bootstrap/<timestamp>/`
  directories on every run (Pulp export path on satellite is never reset by this step)

---

## From C14 — Vault password reminder

- [ ] Ensure the refactored `export_deployment.sh` wrapper retains the vault password
  reminder as its final printed output before exit — after all staging and validation
  completes, immediately before the operator takes possession of the drive
- [ ] Treat `transfer_drive/README_FIRST.md` vault callouts (lines 112, 193-194) as
  mandatory — do not remove or consolidate them during any future README edits

---

## From C15 — Drive root tooling runtime dependency

- No action required — `ansible-core` is present by default on RHEL including minimal
  installs; Ansible dependency on highside workstation is a non-concern
- [ ] Update `import_bundle.yml` bundle discovery and rsync destination paths to match
  C3 drive layout — tracked as part of import-side refactor (not export-side work)

---

## From C16 — Container version pinning

No action required — addressed by C8 (resolved digest in `podman save` step) and C19
(`rhis_export_manifest.yml` records resolved digest at export time). Explicit inventory
pinning deferred to full ecosystem refactor if strict version governance is required.

---

## From C17 — Logging

- [ ] Pipe the unified `export_disconnected.yml` playbook invocation in the refactored
  `export_deployment.sh` wrapper via `tee` to
  `deployments/<domain>/logs/export_deployment_<timestamp>.log`; use a timestamp in the
  filename so multiple export runs do not overwrite each other
- [ ] Add a local log write to the generated `transfer_to_drive.sh`: write rsync output
  to a log file in the current working directory on the operator's workstation; echo the
  log path on completion
- [ ] Write drive validation output to
  `deployments/<domain>/logs/export_deployment_validate_<timestamp>.log`
- [ ] Include all log paths in the final summary output of `export_deployment.sh`

---

## From C18 — Drive root tool idempotency

- No action required for current drive root tools — all delivery methods in
  `import_bundle.yml` use `mkdir -p` and `rsync -a` (both idempotent); `validate_import_bundle.sh`
  is read-only
- [ ] Any new tools added to the drive root during the full ecosystem refactor must be
  reviewed for idempotency before inclusion — document this as a design gate

---

## Import side — I1 through I6

### I1 — Initial import orchestration gap (steps 2–5)

- [ ] Document full greenfield import sequence (steps 1–8) in `README_FIRST.md` and
  operator runbook — all manual steps must be unambiguous
- [ ] Add provisioner setup automation to `import_bundle.yml` or a new companion script:
  extract inventory archive to `/rhis/vars/external_inventory/` (or equivalent) on the
  provisioner after drive content is pushed
- [ ] Add `podman load` step to load provisioner container from drive tar — can be part
  of the same provisioner setup script
- [ ] Step 5 (IdM build) requires no new automation — operator triggers from provisioner
  after container is loaded; document the command in the runbook

### I2 — Incremental import pathway

- [ ] Define incremental import playbook or tagged `main.yml` invocation that:
  rsyncs new Pulp chunks directly to `/var/lib/pulp/imports/` on the existing satellite;
  runs `content_imports` role with updated `content_imports.yml`; runs any other changed
  roles (CVs, activation keys, sync plans) — does NOT run satellite installer
- [ ] Define operator entry point for incremental import (script or documented
  ansible-playbook invocation) equivalent to `build_sat_disconnected_import.sh`
  but scoped to content-only update

### I3 — Pulp staging paths

- [ ] Fix `content_imports/tasks/main.yml`: replace `rsync -a {{ satellite_bundle_stage_path }}/
  /var/lib/pulp/imports/` + `file: state: absent` with a single
  `ansible.builtin.command: cmd: mv {{ satellite_bundle_stage_path }} /var/lib/pulp/imports/pulp_stage`
  — both paths are on the same filesystem so `mv` is an atomic rename with no data
  movement and no disk space overhead; also removes the need for a separate delete task
- [ ] Document that `/var/satellite_stage/` must be on the same filesystem as
  `/var/lib/pulp/` — this is a deployment prerequisite for the greenfield staging path
- [ ] Add 3x space pre-flight check to operator runbook and `README_FIRST.md`:
  `/var` must have at least 3x the export size free before greenfield import begins
  (1x import chunks + 1x Pulp temp untar + 1x Pulp final write); for a 1.2TB export
  this means ~3.6TB free on `/var`
- [ ] Incremental path: rsync directly to `/var/lib/pulp/imports/` — no staging
  directory needed (implemented as part of I2)

### I4 — Drive layout path updates (import-side scripts)

- [ ] Update `import_bundle.yml`: replace `rhis_transfer_*/` discovery with C3
  workflow-stage layout; update rsync destination from `/mnt/rhis_transfer` to
  correct provisioner paths per C3
- [ ] Update `bundle_delivery.yml` and `bundle_delivery` role: navigate C3 drive layout
  for all three delivery methods (usb/rsync/virtual_disk); update artifact path
  references from `rhis_transfer_*/` structure to C3 paths
- [ ] Update `build_sat_disconnected_import.sh`: replace `rhis_transfer_*/` discovery
  and `/mnt/rhis_transfer` default with C3 layout paths

### I5 — `build_sat_disconnected_import.sh` Step 2 remap cleanup

- [ ] After C6 is implemented: remove `_content_imports.yml` fetch and `sed` remap from
  Step 2 of `build_sat_disconnected_import.sh` — `content_imports.yml` arrives in
  `host_vars` from inventory extraction (I1), no import-side transformation needed
- [ ] Retain Step 2 runtime extra-vars writing (bundle path, satellite_disconnected,
  satellite_import_content, etc.) — these are runtime-determined and cannot be done
  on the export side

### I6 — Highside configuration merge

- No action — deferred to future design discussion

---

## Cross-cutting activities (to be identified after full analysis)

*(to be populated once all concerns are evaluated and overlaps are visible)*
