# Export/Import Refactor — Design Concerns

**Date:** 2026-06-12
**Context:** Refactoring the disconnected satellite export/import workflow to provide a
single, centralized entry point on the provisioner node, reduce operator complexity,
and lay the groundwork for integrating the larger rhis-builder ecosystem.

An interim solution covering satellite and rhis-builder core content will be implemented
first. A second refactor will extend coverage to the full ecosystem.

---

## Group 1 — Architecture (foundational)

### C1. Drive location

Where does the transfer drive physically attach? Current design: on the satellite
(export streams directly to it). Proposed: on the operator's workstation. These are
fundamentally different data flows with different disk and network requirements.

**Discussion:**

In real customer environments the lowside Satellite server is typically a VM in a
datacenter — inaccessible for direct drive attachment. Attaching the drive directly to
the satellite is only trivial in a lab. Beyond the practical constraint, there is often
a security mandate: the drive and its contents are transferred directly to a workstation
governed by an authorized person with the appropriate credential access. The drive
remains in their possession throughout the process.

Transfer time is governed by library size, network bandwidth, and the operator's choice
of Satellite export chunk size. Rsync resumability means a failed or interrupted
transfer can be restarted without retransferring already-copied data. Our lab operates
on a 1Gb network in an acceptable timeframe. Enterprise customers typically run faster
networks but 1Gb is viable. The README should document this without implying a minimum
bandwidth requirement: "Transfer time scales with library size and network bandwidth;
rsync ensures restartability regardless of connection speed."

**Remediation:**

The drive attaches to the lowside operator's workstation. The operator uses the
provisioner to launch and control all export operations. The provisioner generates a
transfer play/script that the operator uses to pull content from the satellite directly
to their drive. The provisioner does not participate in the data transfer itself — it
produces a runnable artifact and hands it off. The workstation initiates the pull;
no inbound connectivity to the workstation is required from the provisioner or satellite.

---

### C2. Machine topology

Is "provisioner node" the same physical/virtual machine as the operator's workstation,
or is it a separate host? The answer determines how the drive is reached from the script.

**Discussion:**

In a lab or POC the provisioner and the operator's workstation may be the same machine.
In the general case they are separate. The provisioner is a dedicated VM that persists
beyond the initial build to serve day-2 infrastructure operations until AAP takes over
the bulk of automation work. Running the provisioner role on a personal workstation
works but creates state management problems over time.

If a jumpbox or other gating mechanism exists between the provisioner and the operator's
workstation, the operator downloads the generated transfer script from the provisioner
to their workstation and initiates the pull from there.

**Remediation:**

The provisioner is a separate dedicated host (VM or physical). The operator SSHes to
the provisioner to launch and control all export operations. The provisioner orchestrates
via Ansible against the satellite (and in future, against IdM, AAP, and other services).
The transfer phase is operator-initiated from the workstation and does not require the
provisioner to have network access to the workstation.

---

### C3. Staging location

Where does `rhis_export_staging` live — on the satellite, the provisioner, or the
workstation? Follows from C1 and C2.

**Discussion:**

The satellite is both the source of all export content and already sized to hold it
(see C4). Staging on the provisioner would require pulling all content from the satellite
to the provisioner first — adding a full extra copy traversing the network with no
benefit. Staging on the workstation requires the drive to be connected before staging
begins, which removes the size-before-connect benefit.

The satellite has two distinct staging areas that must both be present for a complete
transfer:

1. **Pulp export content** — managed by Satellite's own export engine. Lands at
   `/var/lib/pulp/exports/`. Contains library/content view/repository chunks and
   the Satellite-generated `content_imports.yml`. This is not "staged" in our sense —
   Satellite writes it as part of the export process.

2. **RHIS staging content** — managed by our playbooks. A dedicated staging directory
   for satellite-specific operational content: FDI discovery image tarball, Ansible
   roles from `/etc/ansible/roles`, and any other satellite-specific artifacts that
   need to cross the airgap. Small relative to the Pulp chunks.

In future the model extends: each RHIS service (IdM, AAP, etc.) owns its own staging
area on its own host. The generated transfer script pulls from all staging areas and
consolidates onto the single drive. The directory structure on the drive should
anticipate this from the start even though only the satellite slice is implemented in
the interim.

**Remediation:**

Staging is on the satellite in two areas as described above. The RHIS staging directory
follows a per-service structure. This structure is deliberate and load-bearing — not
merely organizational. The rationale:

1. **Separation of concerns** — satellite staging is satellite's responsibility; IdM
   staging is IdM's. Service content does not commingle. Each service owns exactly its
   own subdirectory.

2. **Extendability** — adding a new RHIS service (AAP, Gitea, Quay, etc.) is a peer
   directory addition with no redesign of the transfer mechanism or the staging root.

3. **Reduced wasteful transfer** — a day-2 satellite content update does not require
   re-transferring IdM or AAP data that has not changed. The operator (or the workflow)
   selects which service/timestamp slices to include in a given transfer run. Only what
   changed crosses the airgap.

4. **Centralized control and data ownership** — the lowside operator owns the staging
   root. No service can autonomously write to another service's staging area. The
   operator decides what goes on the drive for each transfer.

**Transfer drive layout**

The drive layout is organized by **import workflow stage**, not by source host. Each
top-level directory on the drive corresponds to a distinct stage of the highside
operator's import process. The operator works through the stages in order.

```
TRANSFER_DRV/
  README_FIRST.md                    ← operator reads first; describes stages and sequence
  import_bundle.sh                   ← operator entry point; lives beside README_FIRST.md
  <pulp_export>/                     ← Pulp library chunks; referenced by content_imports.yml
    export-<uuid>.tar.0000           ← 2GB chunks
    export-<uuid>.tar.NNNN
    metadata.json
    toc.json
  bootstrap/                         ← Stage 1: build the highside hosts
    rhis-builder-bootstrap-init/     ← tooling to generate kickstart ISOs on highside
    bootstrap_isos/                  ← pre-generated OEMDRV ISOs (provisioner, idm1, satellite1)
    infra_isos/                      ← RHEL DVD ISO + Satellite DVD ISO
    README.md                        ← explains bootstrap stage contents and usage
  provisioner/                       ← Stage 2: stand up the provisioner node
    inventory/                       ← git archive of rhis-builder-inventory (full committed repo)
      deployments/
        <highside_domain>/
          host_vars/
            satellite1/
              content_imports.yml    ← written directly here at export time; /exports/→/imports/
                                        remap already applied; ready to use with no manual steps
    containers/                      ← container images required on the highside provisioner
      rhis-provisioner_<ts>.tar      ← provisioner container image (podman save output)
      tang_<ts>.tar                  ← Tang container (interim scope)
  satellite/                         ← Stage 3: configure the highside satellite
    ansible_roles/                   ← compliance-as-code roles from /etc/ansible/roles
    discovery_images/                ← Foreman FDI image tarballs
  <future service dirs>/             ← idm/, aap/, etc. added as peer dirs; no redesign needed
```

The `content_imports.yml` is written directly into the correct `host_vars` path in the
highside deployment directory at export time, with the `/exports/` → `/imports/` path
prefix remap already applied. When the highside operator extracts `provisioner/inventory/`
onto the provisioner node, the file is already in place — no manual configuration required.
See C6 for the generation and remap details.

**Staging areas on source hosts**

The transfer script pulls from staging areas on each source host and places content
into the appropriate drive directory. For the interim scope (satellite only):

- Satellite: `/home/ansiblerunner/rhis_export_staging/satellite/<timestamp>/`
  → rsynced to `TRANSFER_DRV/satellite/`
- Satellite: `/var/lib/pulp/exports/<api_returned_path>/`
  → rsynced to `TRANSFER_DRV/<pulp_export>/`
- Provisioner: inventory git archive + container images
  → assembled into `TRANSFER_DRV/provisioner/`
- Bootstrap ISOs + infra ISOs + bootstrap-init tooling
  → assembled into `TRANSFER_DRV/bootstrap/`

Future services (IdM, AAP) add staging areas on their own hosts and peer directories
on the drive. The transfer script and drive layout extend without redesign.

---

### C4. Satellite staging disk cost

If staging is satellite-local (C3), the satellite must hold: Pulp export storage plus a
full copy of everything in staging. The current design streams directly to the drive and
avoids this. This may or may not be a constraint depending on satellite disk capacity.

**Discussion:**

Satellite documentation recommends a minimum of 2x the Library size for the
`/var/lib/pulp` volume. Customers researching disconnected environment management with
Satellite already have this expectation before purchase. The RHIS staging content
(FDI images, Ansible roles, discovery images, etc.) is small relative to the Pulp
export chunks and does not materially change the disk requirement.

**Remediation:**

Not a concern in practice. Existing pre-sale sizing guidance covers the disk requirement.
The RHIS README should reference the Satellite sizing documentation and note that the
RHIS staging directory adds negligible overhead beyond the Pulp export volume.

---

## Group 2 — Data flow

### C5. Pulp chunk routing

Pulp exports to `/var/lib/pulp/exports/` on the satellite. The current design mounts
the drive there so chunks stream directly to it. The proposed model must stage chunks
satellite-local first, then copy. The new playbook must reflect this explicitly.

**Discussion:**

Satellite always writes export chunks to its default location (`/var/lib/pulp/exports/`).
The current design mounts the transfer drive at that path so chunks stream directly onto
it — this couples the export process to the physical drive location and requires the
Satellite operator to understand RHIS constraints. In the new model the drive is on the
operator's workstation, not the satellite, so that coupling must be broken.

The correct resolution is to always use Satellite's default export path and never
configure special destinations or mount external storage at Pulp paths. Satellite
operators need no knowledge of RHIS requirements. Future Satellite API changes and
migration code produced by the BU are absorbed transparently because we never diverge
from standard behaviour.

**Remediation:**

Satellite exports chunks to `/var/lib/pulp/exports/` unconditionally. No special export
destination is configured. Drive mounting is entirely the operator's responsibility on
their own workstation — we do not mount, discover, or manage the drive on the satellite
or provisioner. The `content_export_prepare_drv` role's mount/unmount logic is removed
from the export playbook entirely. The role itself is either retired or repurposed for
another function.

The export workflow instead does the following in order:

1. **Prepare all staging** — Pulp export runs to `/var/lib/pulp/exports/<api_path>/`
   on the satellite; RHIS staging content is assembled under
   `rhis_export_staging/` on each source host (see C3).

2. **Calculate required drive size** — after staging is complete, the export workflow
   computes the total size across all staged areas (Pulp export path + all RHIS staging
   directories) and reports the required drive capacity to the operator. The operator
   uses this number to select and prepare appropriate transfer media.

3. **Generate the transfer script** — the export workflow produces a self-contained
   shell script (`transfer_to_drive.sh` or equivalent) that encapsulates all rsync
   operations needed to copy the staged content to the drive. The script is parameterized
   with the exact source paths (API-returned for Pulp, timestamped staging paths for
   RHIS content).

4. **Drive discovery in the transfer script** — the generated script attempts to
   auto-discover the transfer drive on the operator's workstation by filesystem label
   (`TRANSFER_DRV`). If the drive is found by label, the mount point is resolved
   automatically and the rsync proceeds. If the drive is not labelled or cannot be
   discovered, the script accepts the mount point as an explicit parameter:

   ```
   ./transfer_to_drive.sh --media-path /mnt/my_drive
   ```

   The script validates drive free space against the computed transfer size before
   rsyncing a single byte (see C7). If validation fails, it exits with a clear message.

5. **Rsync to drive** — the script executes the rsync operations, copying:
   - Pulp export chunks → `TRANSFER_DRV/<pulp_export>/`
   - RHIS staging areas → `TRANSFER_DRV/provisioner/`, `TRANSFER_DRV/satellite/`, etc.

   See C3 for the full drive layout.

No inventory configuration of export destinations is required. The satellite operator
needs no knowledge of RHIS requirements or transfer media constraints.

---

### C6. `content_imports.yml` lifecycle

This file is generated by the Satellite export engine, not by any playbook task. It
lives at `<drive>/rhis_import_export_data/` after a current export. In the new design
it must be: captured from the Satellite export output → placed in staging → path-remapped
(`/exports/` → `/imports/`) before it goes into the bundle. This step is absent from
the proposed workflow.

**Discussion:**

`content_imports.yml` is generated entirely by our Ansible — specifically by
`rhis-builder-satellite/roles/content_exports/tasks/generate_content_imports_file.yml`.
After each export, the role queries the Satellite API by export history ID to retrieve
the exact export path, then writes the file to
`/var/lib/pulp/exports/{{ destination }}/{{ timestamp }}_content_imports.yml`.
The `import_path` field in the generated file reflects the lowside export path as
returned by the API. The file was confirmed present in the bundle directory on the
transfer drive (`rhis_transfer_Library_2026-06-07_1416/content_imports.yml`).

The `destination_server` variable is currently manually configured in the lowside
satellite's `content_exports.yml` host_vars. This caused the stale hostname bug
(`discosatellite1.example.ca` — a non-existent host) observed in the most recent
export. This value must never be manually configured.

**CONFIRMED — clean test export 2026-06-12 with `destination_server=satellite1.highside.example.ca`:**

Library export path structure with `destination_server` explicitly set:
```
/var/lib/pulp/exports/
  Default_Organization/
    Export-Library-satellite1_highside_example_ca/   ← CV name includes destination_server slug
      1.0/                                           ← version
        satellite1.highside.example.ca/              ← destination_server (FQDN, dots preserved)
          2026-06-12T20-34-00-00-00/                 ← timestamp
            export-<uuid>-<datetime>.tar.XXXX        ← 2GB chunks
```

Key observations:
- `destination_server` IS present in library export paths — consistent with repo/CV export structure
- The content view name incorporates the destination_server as a filesystem-safe slug
  (`Export-Library-satellite1_highside_example_ca`) while the directory path uses the
  full FQDN with dots preserved (`satellite1.highside.example.ca/`)
- The rsync target and `/exports/` → `/imports/` path remap must use the full
  API-returned path, not any derived or constructed path
- The old export on the drive had no `destination_server` component because it was
  generated without `destination_server` set — confirmed

**Additional finding — silent failure in `content_exports.yml` host_vars:**
The `destination_server` template expression:
```yaml
destination_server: "satellite1.{{ active_downstream_deployment | default(basevars_downstream_disconnected_deployment | first | default('')) }}"
```
silently returns an empty/broken value when both variables are undefined, causing the
entire `content_exports` list to fail Jinja2 rendering. Ansible's `when` condition then
sees `content_exports` as empty and skips the export without any error. This is the
root cause of the stale hostname issue and must be eliminated by making `destination_server`
a required runtime injection that fails loudly when absent.

**Remediation:**

`destination_server` is always derived from the highside inventory at export runtime —
`satellite1.<highside_domain>` — and injected as an explicit extra-var into the export
playbook. It is never manually configured in host_vars. The host_vars `content_exports.yml`
must not contain a default fallback chain for this value; if it is not provided at
runtime the playbook must fail with a clear error message. This eliminates the
drift/staleness problem and the silent-skip failure mode entirely. Single-highside
customers use it identically to multi-enclave customers; there are no special cases.

The `content_imports.yml` template applies the `/exports/` → `/imports/` prefix remap
at generation time. The path structure below that prefix is never modified — Satellite
and the import API require the full unmodified path. The highside receives a
ready-to-use file with no further transformation required.

**Placement — written directly into the provisioner staging inventory at export time:**

`content_imports.yml` is not placed at the drive root or in a generic staging location.
It is written directly to its correct operational path within the provisioner staging
inventory:

```
/home/ansiblerunner/rhis_export_staging/provisioner/<timestamp>/
  inventory/
    deployments/
      <highside_domain>/
        host_vars/
          satellite1/
            content_imports.yml    ← written here; remap already applied
```

The transfer script rsyncs the provisioner staging area to `TRANSFER_DRV/provisioner/`,
so on the drive the file lands at:

```
TRANSFER_DRV/provisioner/inventory/deployments/<highside_domain>/host_vars/satellite1/content_imports.yml
```

When the highside operator's `import_bundle.sh` deploys the inventory onto the highside
provisioner node, `content_imports.yml` is already at the correct `host_vars` path —
no manual placement, no path editing, no further transformation required.

`content_imports.yml` is a runtime-generated file, not committed to the repo. It will
not be present in the `git archive` of `rhis-builder-inventory` (see C11). The export
workflow generates it and injects it into the provisioner staging inventory directory
**after** the git archive is extracted — the injection step runs before the transfer
script executes.

The rsync from the satellite to the transfer drive is always scoped to the **specific
path returned by the Satellite API** for each export — never a parent directory. This
prevents transfer of stale timestamp directories from failed or retried export runs,
prevents content bleed-across in multi-enclave environments, and produces a clean drive
regardless of export type. See C3 for the full drive layout.

---

### C7. Drive validation timing

Proposal: calculate size, then ask operator to connect drive. But size calculation
happens after staging, which takes hours. If the drive is too small or the wrong
filesystem, the problem is discovered after the wait. The correct sequence is:
calculate projected size → operator connects drive → validate drive before staging begins.

**Discussion:**

The old design ran: estimate size → validate drive → mount drive at Pulp path → export
directly to drive. This meant the drive had to be connected before the export started,
and the size estimate was necessarily approximate (`du /var/lib/pulp` ≈ export size).

In the new design the sequence changes and C7 resolves itself naturally:

1. **Pre-export satellite check**: Before triggering the export, verify that
   `/var/lib/pulp` has enough *free space* to hold the export output. This is a fast
   check (seconds) that catches disk-full before the 4-6 hour export starts.
   Confirmed necessary by live failure on 2026-06-12 — 1.3T export on a volume with
   only 1.3T free, discovered only after the export failed.

2. **Export runs**: satellite writes chunks to `/var/lib/pulp/exports/` (4-6 hours).

3. **Post-export drive validation**: The exact export size is now *known* (not estimated)
   from the specific API-returned export path. The generated rsync script checks actual
   drive free space against the actual export size before transferring a single byte.
   The operator connects the drive at this point — not before.

This is strictly better than the old design: the drive validation uses the real size
instead of an estimate, the operator does not need the drive connected at export start,
and the pre-export check protects the satellite from a disk-full failure.

**All existing drive-check code on the satellite is deprecated — do not adapt, archive:**

`content_export_prepare_drv` and all its tasks (`validate_drive.yml`, `discover_drive.yml`,
`mount_drive.yml`, `unmount_drive.yml`, `validate_mount.yml`) are retired in favour of a
fresh implementation. None of this code transfers to the new design.

**Remediation:**

**Step 1 — Pre-export satellite warning** (runs on satellite, before content export):

We cannot accurately predict how much space the Pulp export will consume, particularly
for incremental exports where Pulp's internal deduplication and delta logic determines
the actual output size. Providing a hard assertion would be misleading. Instead, the
export workflow emits a warning showing current free space on `/var/lib/pulp` and
(where available) the size of the most recent previous export as a rough reference:

```
WARNING: /var/lib/pulp has X GiB free. Last export used Y GiB.
         Incremental exports may use significantly less. Proceeding.
```

The operator is informed but not blocked. If the export fails due to disk full, the
error from Pulp is clear and the operator knows what to do (free space, retry).

**Step 2 — Size report after staging completes** (after export and all staging is done):

Once the Pulp export and all RHIS staging areas are populated, the export workflow
computes the total required drive size across all staged content:

- Pulp export path (API-returned path): `du -sb <api_path>`
- Satellite RHIS staging: `du -sb rhis_export_staging/satellite/<timestamp>/`
- Provisioner staging: `du -sb rhis_export_staging/provisioner/<timestamp>/`
- Bootstrap content: `du -sb rhis_export_staging/bootstrap/<timestamp>/`

The total, with a buffer, is reported to the lowside operator as the required drive
capacity. The operator selects and mounts appropriate transfer media on their workstation
before running the transfer script.

**Step 3 — Pre-transfer drive check in the generated transfer script** (runs on operator
workstation, before rsync):

The generated transfer script (`transfer_to_drive.sh`) checks the mount point provided
(by label discovery or explicit `--media-path` parameter) before transferring a single
byte:

```
assert: df_avail(media_path) >= total_staged_bytes
assert: drive_filesystem in [ext4, xfs]
fail_msg: "Insufficient space on <media_path>. Required: X GiB, Available: Y GiB"
```

If either assertion fails the script exits with a clear message. No partial transfers.
The filesystem check ensures the drive is compatible with the rsync operations and
highside import tooling.

---

## Group 3 — Content scope

### C8. `containers/other` list

Tang, quay, gitea, discovery containers — where is this list maintained? No current
variable file owns it. Needs a canonical home in the highside inventory before this
can be exported consistently.

*Likely deferred to the full ecosystem refactor.*

**Discussion:**

The `containers:` variable IS canonically defined — it lives in
`host_vars/<quadlet_host>/containers.yml` for each quadlet host in the deployment.
Each entry includes image, tag, and registry fields. The gap is not definition — it
is aggregation and scope:

1. **Aggregation**: the export workflow has no mechanism to collect `containers:` lists
   across all quadlet hosts, deduplicate by image reference, and produce a unified list
   of images to bundle.

2. **Highside scope**: not all lowside containers are needed on the highside. Which
   containers to export must be driven by the highside inventory, not blindly mirroring
   the lowside.

3. **Provisioner container**: already handled separately (`provisioner_image_tar` in the
   existing export playbook). It is not part of the `containers:` variable.

4. **Discovery image**: handled as a satellite artifact, not a container image for bundling.

5. **Image version ownership**: the `containers:` definition in host_vars is authoritative
   — image, tag, and registry are owned by the deployment author, not by the export
   tooling. We respect whatever is specified, including `:latest` tags. We do not
   override or independently pin versions.

6. **Export manifest requirement**: even when `:latest` is specified, the export workflow
   must record the actual resolved image digest (or resolved tag) in the export manifest,
   annotated as "latest at export time." This gives the highside operator an exact audit
   record of what version crossed the airgap, without overriding the owner's intent.

   **No implementation exists yet for the export manifest.** This is a design decision
   captured here for implementation during the refactor.

For the **interim scope** (satellite + rhis-builder core), the only container image
beyond the provisioner that requires explicit handling is Tang. Tang's definition is
available from the quadlet host_vars and is small enough to bundle without further
aggregation complexity.

Quay, Gitea, and any other application containers belong to the full ecosystem refactor.

**Remediation:**

The general aggregation and highside-scope problem is deferred to the full ecosystem
refactor. The interim solution covers the provisioner image, Tang, and the discovery
image only.

**Interim container staging and drive placement:**

All container images for the interim scope are staged on the provisioner and land at
`TRANSFER_DRV/provisioner/containers/` on the drive (see C3 for full drive layout):

```
rhis_export_staging/provisioner/<timestamp>/
  containers/
    rhis-provisioner_<timestamp>.tar    ← provisioner container (podman save)
    tang_<timestamp>.tar                ← Tang container (podman save)
```

- **Provisioner image**: saved via `podman save` on the provisioner host before the
  export playbook launches. Passed into the playbook as `provisioner_image_tar` and
  written to the provisioner staging `containers/` directory.

- **Tang**: the export playbook references `hostvars[quadlet_host].containers` directly
  for the specific quadlet host running Tang. It performs a `podman pull` followed by
  `podman save` and writes the tar to the provisioner staging `containers/` directory.
  This is an explicit, auditable reference — not a generic aggregation loop. When the
  ecosystem refactor introduces a canonical aggregation pattern, this reference is
  replaced.

- **Discovery image**: handled as a satellite artifact, not a provisioner container.
  It is staged on the satellite and lands at `TRANSFER_DRV/satellite/discovery_images/`
  on the drive (see C3 and C9/C10 for staging details).

**Export manifest — resolved image versions:**

The provisioner image and Tang both require a manifest entry recording the actual
resolved image digest at export time, annotated as "latest at export time" when the
source spec used `:latest`. This gives the highside operator an exact audit record of
what version crossed the airgap without overriding the deployment author's version
intent. The manifest format and generation mechanism are to be defined during
implementation. No implementation exists yet.

**Quay, Gitea, and all other application containers** belong to the full ecosystem
refactor. When that refactor introduces generic aggregation of `containers:` lists
across all quadlet hosts and a canonical highside-scope variable, the Tang explicit
reference above is replaced by the generic mechanism.

---

### C9. RHEL and Satellite DVD ISO sourcing

*Implemented — 2026-06-20.*

**Summary:**

The highside satellite uses `satellite_disconnected_pre` to mount RHEL and Satellite DVD
ISOs as local repos during installation. The highside variables define:

```yaml
satellite_disconnected_root: "/var/media"
satellite_os_iso_source:      "rhel9_dvd.iso"
satellite_install_iso_source: "sat617_dvd.iso"
```

The role expects these files at `{{ satellite_disconnected_root }}/{{ satellite_os_iso_source }}`
on the highside satellite. They must arrive via the transfer bundle.

**Variable design — per-product triplet:**

Three basevars per product, defined in the lowside `*_inventory_basevars.yml`:

```yaml
# RHEL DVD ISO
basevars_rhel_dvd_cset: "rhel-9-for-x86_64-baseos-isos"   # content set label in Satellite Other Repos
basevars_rhel_dvd_version: "9.8"                           # specific version, or 'latest'
basevars_rhel_dvd_iso_path: "/home/ansiblerunner/rhis/isos/rhel-9.8-x86_64-dvd.iso"

# Satellite DVD ISO
basevars_satellite_dvd_cset: "satellite-6.19-for-rhel-9-x86_64-isos"
basevars_satellite_dvd_version: "latest"
basevars_satellite_dvd_iso_path: "/home/ansiblerunner/rhis/isos/satellite-6.19-latest-x86_64-dvd.iso"
```

The `iso_path` is the absolute path on the provisioner where the ISO is stored (or will
be downloaded to). The provisioner is the source for the transfer script; paths that do
not resolve on the provisioner will cause the transfer script to skip that ISO.

**Automated download — rh_iso_download.sh:**

`rh_iso_download.sh` exchanges an RHSM offline token for a bearer token, lists available
ISOs via the RHSM API content-set endpoint
(`GET https://api.access.redhat.com/management/v1/images/cset/{content_set}`),
selects the best DVD ISO (by score then `datePublished`), fetches the pre-signed CDN URL,
downloads, and verifies SHA256. If the file already exists with a matching checksum, the
download is skipped.

The offline token is stored at `~/.config/rh_offline_token` (mode 0600) on the provisioner.
Generate one at: https://access.redhat.com/management/api

**Export pre-flight (export_deployment.sh):**

Before staging or Pulp export begins, `export_deployment.sh`:
1. Checks whether each ISO exists at its configured path.
2. If missing, attempts automatic download via `rh_iso_download.sh`.
3. If download fails, warns and prompts before proceeding (matching the manifest ZIP
   handling pattern). The operator can continue but the highside build will fail without
   the ISOs.

This fail-early behaviour prevents committing to a 4-6 hour Pulp export only to discover
missing ISOs at transfer time.

**Drive placement:**

The infra ISOs are copied directly from their provisioner paths to the drive by Transfer
1b in `transfer_to_drive.yml` — no intermediate staging in `rhis_export_staging/` is
needed (avoids double disk-space usage for 9-10 GB files). They land at:

```
TRANSFER_DRV/
  bootstrap/
    infra_isos/
      rhel-9.8-x86_64-dvd.iso
      satellite-6.19-latest-x86_64-dvd.iso
```

The `@@RHEL_DVD_ISO_PATH@@` and `@@SAT_DVD_ISO_PATH@@` tokens in the transfer template
are substituted at Stage 2 render time. Transfer 1b uses `ansible.posix.synchronize`
with `mode: pull` to copy each ISO from the provisioner to the drive, with stat pre-checks
and graceful warnings if an ISO is missing at transfer time. See C3 for the full drive layout.

---

### C10. Bootstrap artifacts staleness and staging

ISOs generated by `bootstrap_init` are specific to the highside network config
(hostnames, IPs, etc.). No mechanism currently detects whether the highside inventory
has changed since the ISOs were built. Stale ISOs will fail silently on the highside.
Additionally, the `rhis-builder-bootstrap-init` tooling repo itself must travel with
the bundle so the highside operator can regenerate or modify ISOs if needed.

**Discussion:**

`build_highside_isos.sh` generates OEMDRV ISOs from `deployments/<domain>/vars/highside_bootstrap_hosts.yml`,
which encodes hostname, IP address, gateway, DNS servers, disk layout, and encrypted
passwords. The script generates correct, fresh ISOs when run — but it is a separate
manual step, not integrated into the export workflow.

The staleness risk: an operator changes the highside inventory (e.g., reassigns an IP,
changes a hostname, rotates a password), then runs the export workflow without re-running
the ISO script. Stale ISOs go into the bundle. On the highside, the kickstart boots with
incorrect network config and fails — with no obvious signal that the ISOs are the cause.

OEMDRV ISOs are small (a few MB each). Regeneration is fast (seconds per host). There
is no cost to generating them on every export run.

Note: `rhis-builder-baremetal-init` is deprecated. The canonical tooling repo is
`rhis-builder-bootstrap-init` (https://github.com/parmstro/rhis-builder-bootstrap-init),
which contains the `bootstrap_init` role. The local `rhis-builder-baremetal-init`
directory has been deleted; `rhis-provisioner-container` already references the new repo.

**Remediation:**

Integrate `build_highside_isos.sh` logic (or its Ansible equivalent) directly into the
export workflow as a non-optional step that runs before staging. ISO generation always
happens as part of every export — it is never a separate manual step. This makes staleness
structurally impossible: the ISOs in every bundle are always generated from the inventory
state at the time of that export.

The ISO generation step runs on the provisioner (already the case in `build_highside_isos.sh`).
The provisioner writes the generated ISOs to the bootstrap staging directory:

```
rhis_export_staging/bootstrap/<timestamp>/bootstrap_isos/
```

The `rhis-builder-bootstrap-init` repo is also staged at export time:

```
rhis_export_staging/bootstrap/<timestamp>/rhis-builder-bootstrap-init/
```

Both are rsynced to the transfer drive by the generated `transfer_to_drive.sh` script:

```
TRANSFER_DRV/bootstrap/bootstrap_isos/
TRANSFER_DRV/bootstrap/rhis-builder-bootstrap-init/
```

See C3 for the full drive layout.

**Encrypted passwords:** kickstart ISOs contain encrypted root and GRUB passwords. These
are sourced from the vault (ISO generation requires vault access). The vault file travels
via a separate trusted channel — the passwords embedded in the ISOs are vault-encrypted
values, not plaintext. This is already the case in `build_highside_isos.sh` and must be
preserved in the Ansible-integrated implementation.

**Design principle — completeness over convenience:** A valid objection is "I already
have Satellite and RHEL installed on the highside — why include DVDs and ISOs on every
day-2 export?" The answer is deliberate: the transfer drive is the complete, authoritative
package on every export. The data volume is trivial. ISOs are always current. The highside
operator has everything they need on the drive and never has to wonder whether a required
artifact is missing, stale, or needs to be sourced separately. Completeness eliminates
a class of "where do I find X?" questions that would otherwise require coordination across
the airgap.

*Designed — not yet implemented. See programming activities.*

---

### C11. `rhis-builder-inventory` tar in-flight

The export script lives inside `rhis-builder-inventory`. Tarring the project while it
is running produces a non-deterministic archive that includes log files, temp state from
the current export, and any uncommitted working changes. Must use `git archive` or
explicit excludes.

**Discussion:**

The current implementation copies three specific files from `transfer_drive/`
(`import_bundle.sh`, `import_bundle.yml`, `README_FIRST.md`) to the drive root — not a
tar of the whole inventory. C11 is a concern about a future design step: bundling the
highside deployment inventory (`deployments/<highside_domain>/`) so that the highside
team has their inventory available after delivery.

If that archive is produced with `tar -czf` against the live directory while the export
is running, the result is non-deterministic: it may include log files, temp files from
the current export run, or uncommitted local changes. Two exports run a day apart with
identical inventory content would produce different archives.

Two additional constraints that must be respected:
1. **Vault files must be excluded** — vault files are in `deployments/<domain>/vault/`
   and contain encrypted secrets. They must not travel in the bundle (the vault password
   travels via a separate trusted channel; including the encrypted vault in the bundle is
   acceptable but must be a deliberate choice, not an accident of the tar command).
2. **Lowside-specific content must be excluded** — only the highside deployment directory
   should be archived, not the entire repo including the lowside deployment.

**Use cases and security model:**

**UC1 — One lowside, one highside:** the basic case. Send the complete bundle including
the full rhis-builder-inventory archive. No security concern with including lowside
deployment configuration — the highside operator uses it as their foundation and extends
it with their own content.

**UC2 — One lowside, many identical highside environments:** simple extension of UC1.
All highside environments receive the same bundle. Secret separation between instances
is handled by generating unique `rhis_builder_vault.yml` files with instance-specific
secrets — not by separate repos or selective archiving.

**UC3 — One lowside, multiple highside environments with separate security concerns:**
one highside must not see another's configuration. The solution is enforced by lowside
operator structure, not by tooling filtering. The operator maintains **separate
rhis-builder-inventory directories** (divergent forks) per security target — e.g. a
top-level directory structure by security target with a separate project copy under each.
Each fork produces its own complete bundle for its respective highside(s). A given
highside never receives another security target's fork.

**Remediation:**

In all use cases, the archive command is the same:

```
git archive HEAD | tar -x -C /home/ansiblerunner/rhis_export_staging/provisioner/<timestamp>/inventory/
```

`git archive` produces a deterministic snapshot of the entire committed repository —
no log files, no temp state, no uncommitted changes. The archive is extracted directly
into the provisioner staging inventory directory rather than kept as a tar.gz. This
allows the subsequent injection step (C6) to write `content_imports.yml` directly into
the extracted directory tree at its correct `host_vars` path before the transfer script
runs.

The resulting staging layout:

```
/home/ansiblerunner/rhis_export_staging/provisioner/<timestamp>/
  inventory/                          ← extracted git archive of rhis-builder-inventory
    deployments/
      <highside_domain>/
        host_vars/
          satellite1/
            content_imports.yml       ← injected after extraction (see C6); NOT in git archive
    schema/
    inventory_template/
    ...
```

On the drive, the transfer script rsyncs this to `TRANSFER_DRV/provisioner/inventory/`
as a ready-to-use directory — the highside operator's `import_bundle.sh` can rsync it
directly onto the highside provisioner node without any extraction step.

Encrypted vault files are included (they are committed, encrypted content). The vault
password travels via a separate trusted channel — that is the security boundary.

**Sequencing within the export workflow:**
1. `git archive HEAD` extracted into provisioner staging inventory directory
2. `content_imports.yml` injected at correct `host_vars` path (C6 step)
3. Transfer script rsyncs provisioner staging → `TRANSFER_DRV/provisioner/`

Steps 1 and 2 must complete before the transfer script runs. Step 2 depends on the
Satellite export having completed so the API-returned path is known.

**From the tooling perspective, nothing changes between use cases.** The archive and
injection steps are always the same. Security outcomes are the implementor's
responsibility through their structural choices — what they commit to the repo, whether
they maintain separate forks per security target. The tooling does not attempt to enforce
security policy inside the archive operation. Conditional or selective archiving would
add complexity and create gaps where content falls through unexpectedly. Simple,
consistent behaviour is easier to reason about and harder to misconfigure.

*Designed — not yet implemented. See programming activities.*

---

### C12. `export_rhis_container.sh` orphan

Uses `buildah push` (not `podman save`), outputs to the current working directory,
has no staging integration, and no exit-code handling. Either replace or delete;
`export_disconnected.yml` Step 7 already does this correctly via `provisioner_image_tar`.

**Discussion:**

Verified by reading `export_deployment.sh`, `export_disconnected.yml`, and
`copy_to_transfer_media.yml` in full. The complete chain is implemented:

- **Stage 0** (`export_deployment.sh` lines 206-216): `podman save "${CONTAINER_IMAGE}" -o
  "${IMAGE_TAR}"` saves the provisioner image to a temp file on the provisioner host.
  Exit code is checked; the script dies on failure.

- **Stage 1** (`export_deployment.sh` lines 223-249): The temp tar is mounted into the
  provisioner container at `/tmp/rhis_provisioner_image.tar:Z` and
  `provisioner_image_tar=/tmp/rhis_provisioner_image.tar` is passed as an extra-var to
  `export_disconnected.yml`.

- **Step 7 of `export_disconnected.yml`** (lines 237-241): Copies
  `{{ provisioner_image_tar }}` (the mounted tar) to
  `{{ _bundle_dir }}/container/rhis-provisioner_{{ _bundle_timestamp }}.tar` on the
  satellite. Guarded by `when: provisioner_image_tar is defined and provisioner_image_tar
  | length > 0`; emits an explicit warning if not provided.

- **`copy_to_transfer_media.yml`** (lines 126-135): Uses `ansible.posix.synchronize`
  with `src: "{{ bundle_dir }}/"`, `recursive: true`, and `--exclude=library_export`.
  The `container/` subdirectory is NOT excluded — it is fully rsynced to the drive.

There is no stub. No gap. The old `export_rhis_container.sh` is completely superseded.

Side note: the summary message in `copy_to_transfer_media.yml` explicitly states "ISOs
are NOT included in this bundle" — confirming that the C9/C10 refactor work (mandatory
ISO inclusion) addresses a real current gap.

**Remediation:**

`export_rhis_container.sh` can be deleted without replacement. The implementation in
`export_disconnected.yml` Step 7 is complete and verified. The programming activity is
a single deletion — no rework needed.

---

## Group 4 — Operator experience

### C13. Checkpoint and resume

A full export (content export plus all artifact copies) can be 4–6 hours. A failure
mid-run has no recovery story — restart from zero. The staged pipeline (Stage 1 /
Stage 2 / Stage 3) in the current design gives partial recovery. The new unified
design needs explicit checkpoints.

**Discussion:**

The 4-6 hour runtime is dominated almost entirely by the Pulp content export. All other
steps — container saves, ISO generation, inventory archive, bootstrap-init staging,
manifest generation, transfer script generation — complete in minutes. This asymmetry
drives the entire checkpoint strategy: the only step worth protecting is the Pulp export.
Everything else is cheap to redo.

The existing tag structure already provides the critical mechanism:
`--skip-tags tags_content_exports` skips the Pulp export and drive-prep steps, allowing
the staging pipeline to run against an already-completed export. This is the primary
resume path.

Non-Pulp staging is intentionally NOT made idempotent at the directory level. On any
resume, all non-Pulp staging is reset and rebuilt from scratch. This avoids partial-state
corruption (e.g. a half-written container tar or manifest from a prior failed run) and is
safe because the rebuild takes minutes, not hours.

**Remediation:**

1. **Pulp export completion detection:** after the Pulp export step completes, write a
   marker file (e.g. `rhis_export_staging/.pulp_export_complete`) recording the export
   timestamp and Pulp API path. On resume, the playbook checks for this marker and
   automatically applies `--skip-tags tags_content_exports` if found — the operator does
   not need to know which tag to pass.

2. **Non-Pulp staging reset on resume:** at the start of every non-Pulp staging run,
   clear and recreate the provisioner and bootstrap staging directories. This ensures no
   stale artifacts from a prior failed run are included in the bundle. The reset takes
   seconds; the rebuild takes minutes.

3. **Operator resume instruction:** if a run fails, the operator re-runs
   `export_deployment.sh` unchanged. The wrapper reads the marker file and skips the
   Pulp export automatically. The failure point is logged; the operator does not need
   to diagnose which stage failed to decide how to resume.

4. **Marker cleanup:** on a fresh export (no `--skip-tags` override), delete any existing
   marker file before the Pulp export begins so that a prior run's marker cannot
   accidentally suppress a new export.

*Designed — not yet implemented. See programming activities.*

---

### C14. Vault password reminder

Not mentioned anywhere in the proposed workflow. The current `export_deployment.sh`
has an explicit final message. Must be preserved — the vault password must travel via a
separate trusted channel and the operator must be told this at the point they pick up
the drive.

**Discussion:**

The vault password reminder already exists in two places and must survive the refactor:

1. `export_deployment.sh` (lines 367-368) — terminal output at the end of the export run:
   ```
   IMPORTANT: Vault password must travel via a separate trusted channel.
   Do NOT include the vault password in or alongside the transfer bundle.
   ```
   Followed by explicit highside next steps (mount drive, run `import_bundle.sh`).

2. `transfer_drive/README_FIRST.md` (lines 112, 193-194) — the operator-facing document
   that travels on the drive itself. Referenced twice: once in the bundle contents list
   ("Vault password — delivered via a separate trusted channel, NOT on this drive") and
   once in a dedicated warnings section.

This is a preservation concern, not a build concern. Both instances are already correctly
implemented. The risk is that a refactor of `export_deployment.sh` drops the terminal
reminder, or that a revision of `README_FIRST.md` removes the vault callout.

**Remediation:**

Treat both reminder locations as mandatory, non-optional output. In the refactored
`export_deployment.sh` wrapper, the vault password reminder must appear as the final
printed output before exit — after all staging and validation is complete, at the moment
the operator is about to hand the drive to the courier or transport it themselves.

`README_FIRST.md` already has two callouts and must retain both through any future edits.

*Implemented in both locations — preservation required through refactor.*

---

### C15. Drive root tooling runtime dependency

Playbooks at the drive root require ansible installed on the highside workstation.
Shell scripts have no runtime dependency beyond bash. For anything the highside operator
runs before the provisioner exists, shell is safer.

**Discussion:**

`import_bundle.sh` calls `ansible-playbook import_bundle.yml`, which runs on `localhost`
(the operator's RHEL workstation) and uses Ansible as a survey and scripting framework for
`rsync` and `ssh` operations. The concern was that Ansible might not be present on the
highside workstation before the provisioner is stood up.

This is a non-concern in the RHEL context. `ansible-core` is installed by default on RHEL,
including minimal installs. The highside operator's workstation is RHEL — Ansible is always
present without any additional installation step.

The Ansible-based survey playbook is retained as-is. It is cleaner and more maintainable
than an equivalent bash `read` loop and there is no runtime dependency to manage.

**Stale paths in `import_bundle.yml`** (tracked separately as an import-side refactor item):
- Still discovers `rhis_transfer_*/` bundle directories — old layout; C3 uses workflow-stage
  directories (`bootstrap/`, `provisioner/`, `satellite/`)
- Still rsyncs to `/mnt/rhis_transfer` on the provisioner — old destination path

These must be updated when the import-side playbook is refactored to match the C3 drive layout.

**Remediation:** No action required for the runtime dependency. Import-side path updates
tracked as part of the import refactor.

*Non-concern resolved. Import-side path updates deferred to import refactor.*

---

## Group 5 — Design quality

### C16. Container version pinning

"Fetch the latest containers" is non-deterministic. Two exports a month apart include
different versions with no signal to the highside. Container image references must be
pinned in the inventory config, not resolved at export time.

**Discussion:**

The concern is valid in principle but the proposed solution — pinning image references in
inventory config — is stricter than necessary and adds maintenance burden. The actual
requirement is that the highside knows exactly what version was shipped and that the
lowside operator controls when versions change.

Both requirements are already satisfied:

1. **Owner controls the version** — the container image included in the bundle is whatever
   is current on the provisioner at export time. The lowside operator controls when they
   update images (via `podman pull`) and when they run the export. The timing of the
   export is the version-control mechanism. Non-determinism across exports is intentional:
   it reflects the owner's decision to ship the current version.

2. **Highside visibility via `rhis_export_manifest.yml`** (C19) — the export manifest
   records the resolved image digest for the provisioner and Tang containers at export
   time, alongside a note that `:latest` references are "latest at export time." The
   highside operator knows exactly what they received and can verify it against the
   manifest.

Explicit pinning (e.g. `registry.example.com/rhis-provisioner:sha256:abc123` in the
inventory) is not required for the interim scope. It would be appropriate in a future
full ecosystem refactor if strict version governance across many highside environments
becomes a requirement.

**Remediation:** Addressed by C8 (resolved digest recording in `podman save` step) and
C19 (`rhis_export_manifest.yml` content). No additional action required.

*Closed — addressed by C8 and C19.*

---

### C17. Logging

The proposed script runs on the provisioner node. Where do logs land? How does the
operator retrieve them? The current design writes to `deployments/<domain>/logs/`.
The new design needs an equivalent.

**Discussion:**

The current `export_deployment.sh` writes per-stage logs to
`deployments/<domain>/logs/export_deployment_stage{1,2,3}.log` using `tee` — output
is visible in the terminal and simultaneously written to file. The log path is echoed
on completion. This pattern is consistent with the rest of the rhis-builder tooling and
must be preserved.

In the refactored workflow the stage boundaries change:

- **Export + staging log** — the unified `export_disconnected.yml` playbook run (Pulp
  export + all artifact staging + manifest generation) is a single Ansible invocation.
  Its output is piped via `tee` to a timestamped log file so multiple export runs do not
  overwrite each other.

- **Transfer log** — `transfer_to_drive.sh` runs on the operator's workstation, not on
  the provisioner. Its output cannot be captured on the provisioner. The script itself
  should write a local log on the workstation and echo the log path on completion. The
  lowside operator is responsible for retaining that log.

- **Validation log** — the drive validation step (SSH to satellite or local check) writes
  to `deployments/<domain>/logs/export_deployment_validate_<timestamp>.log` on the
  provisioner, consistent with the current Stage 3 log.

**Remediation:**

1. `export_deployment.sh` wrapper pipes the Ansible playbook invocation via `tee` to
   `deployments/<domain>/logs/export_deployment_<timestamp>.log`; timestamp in the
   filename prevents overwrite across multiple runs.

2. `transfer_to_drive.sh` (generated script, runs on workstation) writes its own log
   to the workstation's current directory or a path the operator specifies; echoes log
   path on completion.

3. Validation step writes to
   `deployments/<domain>/logs/export_deployment_validate_<timestamp>.log`.

4. The final summary output of `export_deployment.sh` lists all log paths so the
   operator knows where to find them.

*Designed — not yet implemented. See programming activities.*

---

### C18. Drive root tool idempotency

Scripts or playbooks placed at the drive root will be run by highside operators who
may not be experienced. Running them twice or on partial state must be safe. This
requires explicit guards or at minimum clear README instructions about single-use steps.

**Discussion:**

The current drive root contains three items: `README_FIRST.md`, `import_bundle.sh`,
and `import_bundle.yml`. Each delivery method in `import_bundle.yml` uses only
idempotent primitives:

- **usb** — no state changes on the workstation; operator is prompted to physically
  connect the drive. Safe to run multiple times. ✓
- **rsync** — `mkdir -p` on satellite/provisioner (idempotent) followed by `rsync -a`
  (idempotent by design — re-running copies only changed or missing files). ✓
- **virtual_disk** — same as rsync, provisioner only. ✓

`validate_import_bundle.sh` (shipped in the provisioner container, run before import)
is read-only — checksums files against the manifest and reports results. Fully
idempotent. ✓

The provisioner-side operations triggered after `import_bundle.sh` completes are also
idempotent:

- **Satellite software deployment and configuration** — all underlying code is Ansible
  and Puppet. If the system already exists, it is not redeployed. Configuration tasks
  apply only what has drifted. Running twice is safe, just slower.
- **Content import** — Satellite checks imported content against what is already present
  and does not duplicate it. Re-running an import on already-imported content is a no-op
  at the content level.
- **CV promotion** — promoting an already-promoted version is a no-op.

The entire chain from drive root through to satellite configuration is idempotent end to
end. Operations may be time-consuming on repeat runs but are never destructive.

`README_FIRST.md` makes the sequencing explicit: validate → deliver → build. The
idempotency of every step means an operator who re-runs any part of the workflow
produces the correct end state without risk of corruption or duplication.

**Remediation:** No changes required for the current drive root tools — already
idempotent by design. Any new tools added to the drive root in the full ecosystem
refactor must be verified for idempotency before inclusion.

*Resolved for interim scope — design principle documented for future additions.*

---

### C19. RHIS transfer manifest generation and highside validation

**RECOVERED CONCERN** — this design element was implemented in `validate_import_bundle.sh`
before the formal concern review began and was subsequently lost across session interruptions.
It is documented here to prevent further loss and to drive the update work required to align
the existing implementation with the C3 drive layout.

The highside operator receives a drive whose contents were assembled and transferred by
parties they cannot directly verify. There must be a lowside-generated integrity file on
the drive that the highside operator can use to confirm nothing was tampered with, corrupted
in transit, or accidentally omitted.

**Terminology note:** The term "manifest" is overloaded in Red Hat Satellite contexts.
"Satellite manifest" refers to the Red Hat subscription entitlement `.zip` downloaded from
access.redhat.com — a completely separate concept. The word "disconnected" is equally
overloaded — Satellite has its own disconnected content concepts. Both terms were previously
embedded in the old filename (`rhis_disconnected_manifest.yml`) which caused conflation.
The file described here is the **RHIS export manifest**: `rhis_export_manifest.yml`,
generated by the lowside export workflow and validated by the highside operator before import.

**What already exists:**

`validate_import_bundle.sh` (in `rhis-provisioner-container`) already implements
the validation side. It:
- Looks for `rhis_export_manifest.yml` at the bundle root
- Parses `source_satellite:`, `generated:`, `pulp_export_path:` metadata fields
- Parses `- path: "..." sha256: "..."` checksum entries per artifact
- Runs `sha256sum` against each listed file and reports pass/fail per entry
- Checks for Pulp chunks + `metadata.json`, `content_imports.yml`, ansible_roles,
  bootstrap_init, discovery_images, container/, inventory/

The generate side (creating `rhis_export_manifest.yml` on the lowside) is
not yet implemented in the refactored workflow.

**Design:**

The RHIS transfer manifest covers all RHIS-assembled artifacts. Pulp content integrity
is intentionally delegated to Pulp's own `metadata.json` file (already checked by
`validate_import_bundle.sh`). The manifest does NOT attempt to checksum Pulp chunks.

Artifact entries in `rhis_export_manifest.yml`:

| Artifact | Drive path | Checksum |
|----------|-----------|---------|
| Inventory tar.gz | `provisioner/inventory/rhis-builder-inventory_<ts>.tar.gz` | SHA256 of tar.gz |
| Provisioner container tar | `provisioner/containers/rhis-provisioner_<ts>.tar` | SHA256 |
| Tang container tar | `provisioner/containers/tang_<ts>.tar` | SHA256 |
| Bootstrap ISOs (one per host) | `bootstrap/bootstrap_isos/<host>.iso` | SHA256 per file |
| RHEL DVD ISO | `bootstrap/infra_isos/<rhel_dvd>.iso` | SHA256 |
| Satellite DVD ISO | `bootstrap/infra_isos/<satellite_dvd>.iso` | SHA256 |
| rhis-builder-bootstrap-init tar | `bootstrap/rhis-builder-bootstrap-init_<ts>.tar.gz` | SHA256 |

Container image digests (resolved at export time per C8) are included as additional
metadata fields alongside each container tar entry — not a separate section.

Satellite subscription manifest `.zip` files travel inside the inventory tar.gz at
`deployments/<highside>/files/` and are covered by the inventory tar.gz checksum.
No separate drive-level entry is needed.

**Remediation:**

*Generate side (lowside):* After all staging is complete and before `transfer_to_drive.sh`
is generated, the export playbook assembles `rhis_export_manifest.yml` by:
1. Computing SHA256 of each staged artifact
2. Recording resolved container digests (C8)
3. Writing the manifest to `rhis_export_staging/provisioner/<timestamp>/rhis_export_manifest.yml`
4. Including the manifest itself in the transfer script rsync (it lands at `TRANSFER_DRV/` root)

*Validate side (highside):* `validate_import_bundle.sh` is updated to:
1. Find artifacts at C3 layout paths (replacing old `rhis_transfer_*/` bundle discovery)
2. Verify each artifact checksum against `rhis_export_manifest.yml`
3. Confirm `metadata.json` present for Pulp data (delegates Pulp integrity to Pulp)
4. Replace the stale `manifests/` check with a check for `*.zip` inside the extracted
   inventory at `provisioner/inventory/deployments/<highside>/files/`

*Designed — not yet implemented. See programming activities.*

---

---

## Import-side concerns (I1-I6)

Two distinct import pathways exist:

- **Initial (greenfield):** full 8-step process — bootstrap bare metal hosts using OEMDRV
  ISOs, provision nodes, extract inventory and container to provisioner, build IdM, rsync
  Pulp content to satellite staging, build satellite with content import, CV promotion.
- **Incremental:** rsync new content from operator's workstation to existing satellite,
  run `content_imports` role (and any other changed roles) — no rebuild, no staging dance.

**Highside configuration merge** (how changes on the highside are reconciled with a
new lowside export) is explicitly deferred to a future design discussion.

---

### I1. Initial import — orchestration gap (steps 2–5)

`build_sat_disconnected_import.sh` exists and covers steps 6–8 (Pulp delivery →
satellite build → content import). Steps 1–5 of the greenfield workflow have no
equivalent orchestration:

| Step | Description | Status |
|------|-------------|--------|
| 1 | Validate drive (`validate_import_bundle.sh`) | Exists — C19 path updates needed |
| 2 | Boot provisioner, IdM, satellite from OEMDRV ISOs | Manual/physical — no orchestrator |
| 3 | Extract inventory archive to provisioner | Not automated — `import_bundle.yml` pushes content but does not place inventory at the correct provisioner path |
| 4 | Load provisioner container (`podman load`) | Not automated |
| 5 | Build highside IdM | Assumed available — not triggered by any import script |
| 6–8 | Pulp delivery → satellite build → CV promotion | `build_sat_disconnected_import.sh` ✓ |

Steps 2–5 are currently operator-manual. Step 2 is inherently physical (ISO boot from
bare metal). Steps 3–4 can be automated; step 5 is orchestrated via existing
rhis-builder-idm playbooks run from the provisioner once it is operational.

**Remediation:**

Document the full initial import sequence explicitly in `README_FIRST.md` and in an
operator runbook so the manual steps are unambiguous. For steps 3 and 4, add a
provisioner setup script (or extend `import_bundle.yml`) to:
- Place the inventory archive at the correct provisioner path
  (`/rhis/vars/external_inventory/` or equivalent) after extraction
- Run `podman load` to load the provisioner container from the tar on the drive

Step 5 (IdM build) is triggered by the operator from the provisioner after the
container is loaded — no new automation needed beyond what rhis-builder-idm already
provides.

*Partially implemented (steps 6–8). Steps 3–4 automation pending. Step 2 physical.*

---

### I2. Incremental import pathway

No dedicated incremental import script exists. `build_sat_disconnected_import.sh`
always runs the full satellite build (`main.yml`) which is a 60+ minute operation
even when only content needs updating.

**Remediation:**

Define a lightweight incremental import path that:
1. rsyncs new Pulp export chunks from the operator's workstation directly to
   `/var/lib/pulp/imports/` on the existing satellite (no staging dance — Pulp user
   and SELinux context already exist)
2. Runs `content_imports` role with the updated `content_imports.yml` from the new bundle
3. Runs any other roles whose configuration changed in the new inventory export
   (e.g. content views, activation keys, sync plans)

This path does NOT run the full `main.yml`. It requires a dedicated playbook or a
well-tagged invocation of `main.yml` that skips the installer and OS-level steps.

*Not yet implemented.*

---

### I3. Pulp staging — initial vs. incremental

**Initial import:** Pulp is not yet installed when the transfer content arrives on the
satellite. `/var/lib/pulp/imports/` does not yet exist; the `pulp` user and
`pulpcore_var_lib_t` SELinux context do not yet exist. Content must be staged at a
temporary path (currently `/var/satellite_stage/pulp_stage`) before the satellite
installer runs. After the installer completes, `content_imports/tasks/main.yml` moves
the staged content to `/var/lib/pulp/imports/`.

**Critical implementation note — same filesystem:** `/var/satellite_stage/pulp_stage`
and `/var/lib/pulp/imports/` are on the same filesystem. The move from staging to the
Pulp import path is therefore a pure filesystem rename (`mv`) — atomic, instant, no
data copied, no additional disk space consumed. The current implementation uses
`rsync -a` followed by `ansible.builtin.file: state: absent` which copies all content
unnecessarily and must be replaced with `ansible.builtin.command: cmd: mv ...`.

**Space requirements — greenfield initial import (peak 3x export size on `/var`):**

Pulp's import process has three concurrent space consumers at peak:

| Phase | Location | Space | Notes |
|-------|----------|-------|-------|
| Staged chunks (pre-install) | `/var/satellite_stage/pulp_stage` | 1x | Freed by `mv` — no extra space |
| Chunks in import path | `/var/lib/pulp/imports/` | 1x | The `mv` target — same data, renamed |
| Pulp temp untar (validation) | Pulp internal temp dir | 1x | Pulp untars each chunk to validate before import; cleaned up by Pulp on completion |
| Pulp final content store | `/var/lib/pulp/` content dirs | 1x | Pulp's permanent write location |

Peak consumption: **3x** (import chunks + temp untar + final write). After Pulp
completes the import and cleans its temp dir: 2x. After removing `/var/lib/pulp/imports/`:
1x (final content store only).

The `mv` itself consumes no extra space. The 3x peak is driven entirely by Pulp's
internal import process and is unavoidable on a greenfield build.

**This is a deployment sizing prerequisite.** `/var` must have at least 3x the
expected export size available before a greenfield import begins. For a 1.2TB export,
`/var` needs approximately 3.6TB free.

**Incremental import:** Pulp is already installed and running. Content is rsynced
directly to `/var/lib/pulp/imports/` — no temporary staging directory, no move
operation. Space peak is still 3x (import chunks + temp untar + final write) but no
pre-install staging phase.

**Remediation:** Replace `rsync -a` + delete in `content_imports/tasks/main.yml` with
`mv` (single rename). Document the 3x space requirement as a pre-flight check in the
operator runbook and in `README_FIRST.md` for the highside. Ensure `/var/satellite_stage/`
is on the same filesystem as `/var/lib/pulp/`.

*Initial path implemented but uses wrong move mechanism (rsync instead of mv) — fix required.*

---

### I4. Drive layout path updates — import-side scripts

`bundle_delivery.yml`, `build_sat_disconnected_import.sh`, and `import_bundle.yml`
all reference the old `rhis_transfer_*/` bundle directory layout and old staging paths.
These must be updated to match the C3 drive layout.

**Specific stale references:**

- `build_sat_disconnected_import.sh`: discovers `rhis_transfer_*/` under `source_path`;
  uses `/mnt/rhis_transfer` as default source path; hardcodes
  `satellite_bundle_stage_path: "/var/satellite_stage/pulp_stage"`
- `bundle_delivery.yml` / `bundle_delivery` role: expects `rhis_transfer_*/` structure;
  places artifacts at paths matching old layout
- `import_bundle.yml`: discovers `rhis_transfer_*/` on drive; rsyncs to `/mnt/rhis_transfer`
  on provisioner

All must be updated to navigate the C3 workflow-stage layout:
`bootstrap/`, `provisioner/`, `satellite/`, `<pulp_export>/`.

*Not yet implemented — update required across all three files.*

---

### I5. `build_sat_disconnected_import.sh` Step 2 — remap superseded by C6

Step 2 of `build_sat_disconnected_import.sh` currently:
1. Reads `_content_imports.yml` fetched from the bundle to `/tmp/rhis_content_imports_fetch.yml`
2. Applies `/var/lib/pulp/exports/` → `/var/lib/pulp/imports/` remap via `sed`
3. Writes remapped file to `${HOST_VARS_DIR}/content_imports.yml`
4. Reads bundle path from `/tmp/rhis_bundle_path.txt`
5. Writes runtime-determined disconnected extra-vars to `/tmp/rhis_disconnected_extra_vars.yml`

C6 (canonical) applies the remap at export time. `content_imports.yml` arrives in the
inventory archive at `deployments/<highside>/host_vars/satellite1/content_imports.yml`
already with the correct highside import paths. The `sed` remap in Step 2 is superseded.

After C6 is implemented, Step 2 retains only items 4–5: reading the bundle path and
writing the runtime extra-vars. The `_content_imports.yml` fetch and `sed` remap are
removed. `content_imports.yml` is already in `host_vars` from the inventory extraction
step (I1 step 3) — no injection needed at import time.

*Superseded by C6 — cleanup pending until C6 is implemented.*

---

### I6. Highside configuration merge

How changes made on the highside (local customisations, emergency patches, locally
added content) are reconciled with a new lowside export arriving on a subsequent drive
is explicitly deferred. The lowside inventory arriving in the bundle is a complete
snapshot of the lowside state — a naive rsync would overwrite highside changes.

*Deferred to future design discussion.*

---

## Scope summary

| Concern | Description | Interim | Deferred |
|---------|-------------|:-------:|:--------:|
| C1  | Drive location | ✓ | |
| C2  | Machine topology | ✓ | |
| C3  | Staging location | ✓ | |
| C4  | Satellite staging disk cost | ✓ | |
| C5  | Pulp chunk routing | ✓ | |
| C6  | `content_imports.yml` lifecycle | ✓ | |
| C7  | Drive validation timing | ✓ | |
| C8  | `containers/other` list — interim: Tang + provisioner; generic aggregation deferred | ✓ | ✓ |
| C9  | RHEL and Satellite DVD ISO sourcing | ✓ | |
| C10 | Bootstrap artifacts staleness and staging | ✓ | |
| C11 | `rhis-builder-inventory` archive in export workflow | ✓ | |
| C12 | `export_rhis_container.sh` orphan | ✓ | |
| C13 | Checkpoint and resume | ✓ | |
| C14 | Vault password reminder | ✓ | |
| C15 | Drive root tooling runtime dependency — non-concern on RHEL | ✓ | |
| C16 | Container version pinning — closed by C8 + C19 | ✓ | |
| C17 | Logging | ✓ | |
| C18 | Drive root tool idempotency — resolved by design, end-to-end | ✓ | |
| C19 | RHIS transfer manifest generation and highside validation | ✓ | |
| I1  | Initial import orchestration gap (steps 2–5) | ✓ | |
| I2  | Incremental import pathway | ✓ | |
| I3  | Pulp staging — initial vs. incremental | ✓ | |
| I4  | Drive layout path updates — import-side scripts | ✓ | |
| I5  | `build_sat_disconnected_import.sh` Step 2 remap superseded by C6 | ✓ | |
| I6  | Highside configuration merge | | ✓ |
