# RHIS Highside Bundle — READ THIS FIRST

This drive contains everything needed to build a disconnected Red Hat Infrastructure
Standard (RHIS) environment. Follow these steps in order.

---

## What's on this drive

| Item | Description |
|---|---|
| `import_bundle.sh` | **Start here** — delivers drive contents to the highside hosts |
| `import_bundle.yml` | Ansible playbook called by `import_bundle.sh` |
| `prepare_highside.sh` | **Run second** — loads containers, mounts DVDs, distributes repo files |
| `rhis_export_manifest.yml` | Checksums and metadata for the bundle — used for integrity verification |
| `validate_import_bundle.sh` | Run before importing to verify bundle completeness |
| `<Org_Folder>/` | Red Hat Pulp content export — RPMs, kickstart repos (large, do not modify) |
| `bootstrap/bootstrap_isos/` | OEMDRV kickstart ISOs for provisioner, IdM, and satellite |
| `bootstrap/infra_isos/` | RHEL DVD ISO and Satellite DVD ISO |
| `bootstrap/rhis-builder-bootstrap-init/` | Kickstart ISO tooling repo — regenerate ISOs if needed |
| `provisioner/inventory/` | rhis-builder-inventory archive for the highside deployment |
| `provisioner/containers/` | Provisioner and Tang container images |
| `satellite/ansible_roles/` | Compliance Ansible roles for the satellite |
| `satellite/discovery_images/` | Foreman discovery PXE images (includes `fdi-image-latest.tar`) |

---

## Step 0 — Build the highside hosts (if not already done)

Before running `import_bundle.sh`, the provisioner, IdM, and satellite hosts must exist
with a base RHEL OS install. If they are already built and reachable, skip to Prerequisites.

### Kickstart ISOs

The bundle includes OEMDRV kickstart ISOs for each highside host:

```
bootstrap/bootstrap_isos/
  provisioner.<domain>.iso
  idm1.<domain>.iso
  satellite1.<domain>.iso
```

Each ISO is an unattended kickstart image.
Attach it as a second virtual CD-ROM alongside the RHEL installation DVD when booting the host on a hypervisor or on baremetal.
Anaconda automatically picks up the OEMDRV volume and uses the embedded ks.cfg to install the systems without prompts.
You can also connect these iso file to the BMC for your baremetal servers or copy them to USB drives. If you are running a disconnected environment in a cloud hyperscalar, you can use one of the rhis-builder project's cloud landing zone repos to build your cloud landing zone. The process is similar.

The `bootstrap/rhis-builder-bootstrap-init/` directory contains the
`rhis-builder-bootstrap-init` repo used to regenerate ISOs if needed. If you need to make changes to the base system builds, follow the README.md in that project and modify the templates accordingly.

### Build order

Although you can install the bases operating systems in any order or in parallel, once you start the "Operational" builds (i.e. installing and configuring the RHIS components on top of RHEL), there is a defined order in which RHIS environments are built. 
Operational builds proceed in this order — each depends on the previous:

1. **Provisioner** — boots first, becomes the Ansible controller for all subsequent builds
2. **IdM** — Identity Management; provides identity, certificate services, dns and other core service necessary for the RHIS environment. 
3. **Satellite** — largest build; requires the infrastructure services provided by IdM. This allows you to fully integrate all remaining systems in your infrastructure at build time. Identity Management and Satellite work tightly together to ensure your a secure environment.

### Booting a host with the kickstart ISO

**Hypervisor:**
1. Create the VM with the correct disk layout (see disk sizing below)
2. Attach the RHEL DVD ISO as CD-ROM 1
3. Attach the host's OEMDRV ISO as CD-ROM 2
4. Boot — Anaconda detects OEMDRV and installs unattended
5. Host reboots and ejects the disc automatically

**Baremetal:**
1. Write the OEMDRV ISO to a USB key (second key alongside the RHEL DVD boot key)
2. Boot from the RHEL DVD; Anaconda finds the OEMDRV key automatically

### Satellite disk sizing — WARNING

> **The satellite requires substantial `/var` space. Undersizing is the most common
> cause of a failed or unusable satellite build.**

The satellite stores all Pulp content under `/var/lib/pulp/`. During a disconnected
import, a temporary staging area (`/var/satellite_stage/`) is also required. Both must
fit on the same filesystem.

**Minimum `/var` sizing for a disconnected satellite:**

| Space needed | Purpose |
|---|---|
| Size of Pulp export on this drive | `/var/satellite_stage/pulp_stage/` — pre-installer staging |
| Size of Pulp export on this drive | `/var/lib/pulp/imports/` — post-installer import location |
| Size of Pulp library (post-import) | `/var/lib/pulp/` — permanent Pulp content store |
| Working headroom (~10%)* | Export/import operations, metadata, temp files |
\* Not an exact value (10% of a 2TB volume is a lot of space!!) +10-20GB typically suffices. 

Plan for at least **2× the Pulp export size** in `/var` at install time **if you are mounting this drive directly to the satellite**, plus some headroom.

Plan for at least **3× the Pulp export size** in `/var` at install time **if you are CAN NOT mount this drive directly to the satellite and must use the rsync method**,plus some headroom.

Check the export size on this drive before provisioning:

```bash
du -sh /run/media/<user>/TRANSFER_DRV/<Org_Folder>/
```

The kickstart template provisions `/var` with `--grow` so it consumes all remaining
space on the root disk after other partitions are allocated. Size the root disk
accordingly — the other partitions (boot, EFI, swap, home, tmp, var/log, var/log/audit)
consume roughly 50 GB combined, so root disk size ≈ 50 GB + required `/var`. 

You can customize the templates in the included rhis-builder-baremetal-init project to create whatever partition layout that meets your requirements or standards and then easily regenerate the kickstarts and isos.

---

## Prerequisites

Before running the import script, ensure:

1. **RHEL workstation** — ansible-core is installed (`ansible-playbook --version`)
2. **SSH access** to the highside provisioner and satellite using the ansiblerunner key
<!-- MANDATORY: vault password callout — do not remove or consolidate (C14) -->
3. **Vault password** — delivered via a separate trusted channel (it is NOT on this drive)
4. **Drive mounted** — this drive is mounted and readable (you're reading this, so it is)

---

## How to run

There are three steps. Run them in order.

### Step 1 — Deliver data to the highside hosts

Run from the operator workstation (this machine):

```bash
cd /run/media/<user>/TRANSFER_DRV     # or wherever this drive is mounted
./import_bundle.sh
```

The script prompts for:
- **Delivery method** — how to get data to the highside hosts (see below)
- **Provisioner IP** — the highside provisioner node
- **Satellite IP** — the highside satellite node
- **Deployment name** — e.g. `highside.example.ca`
- **SSH user** — default: `ansiblerunner`
- **SSH key path** — default: `~/.ssh/id_ed25519`

### Step 2 — Prepare the provisioner

SSH to the provisioner and run `prepare_highside.sh` from the location it was
delivered to in Step 1:

```bash
ssh ansiblerunner@<provisioner_ip>
~/rhis_transfer/prepare_highside.sh \
  --deployment highside.example.ca \
  --idm-host   idm1.highside.example.ca \
  --sat-host   satellite1.highside.example.ca
```

This script:
- Loads the provisioner and Tang container images into podman
- Places the inventory at `~/rhis/rhis-builder-inventory/`
- Loop-mounts the RHEL and Satellite DVD ISOs from the path given by `--iso-path`
- Starts a persistent local HTTP server (default port 7778) serving both ISOs as package repos
- Distributes repo files to `idm1` and `satellite1` (`/etc/yum.repos.d/rhis-highside.repo`)

> **The HTTP server must remain running for the duration of Steps 3a and 3b.**
> It is the only package source for IdM and Satellite during their builds.
> See the script's summary output for the stop command.

### Step 3 — Build IdM, then Satellite

Run both build scripts from **inside the provisioner container**, in this order:

**3a — Build IdM first:**
```bash
build_idm_primary.sh \
  --deployment highside.example.ca
```

**3b — Build Satellite (after IdM is up):**
```bash
build_sat_disconnected_import.sh \
  --delivery-method rsync \
  --deployment highside.example.ca
```

IdM must be fully operational before Satellite is built — Satellite uses IdM
as its certificate authority and realm provider.

---

## Delivery methods

### `usb` — Physical connection to satellite baremetal
The drive is physically connected to (or USB-attached to) the satellite server.

- Script pauses and asks you to connect the drive
- No network transfer happens from this workstation
- The provisioner discovers and mounts the drive by label (`TRANSFER_DRV`)
- **Do NOT mount the drive on the satellite yourself** — the build script handles that

Best for: baremetal satellite with a USB port or hot-plug storage.

In some hypervisor environments you may also be able to perform a pass through to connect the drive via the virtual USB interface.

### `rsync` — Network push from this workstation (recommended for VMs)
**Recommended method.**

The script pushes data directly from this workstation to its destination over the network:

- Pulp content (`<Org_Folder>/`) → satellite `/var/satellite_stage/pulp_stage/`
- Bundle artifacts (`provisioner/`, `satellite/`, `bootstrap/`) → provisioner `~/rhis_transfer/`

No double-hop through the provisioner for the large Pulp content.

Best for: operator workstation has network access to both provisioner and satellite.
This methodology is used most frequently. 

### `virtual_disk` — Push everything to provisioner
The script pushes all drive content to the provisioner. The provisioner then delivers everything to the satellite during the build.

- All content → provisioner `~/rhis_transfer/`

This relies on converting the content for the satellite into a virtual disk for the  target hypervisor and attaching it to the satellite. 
This tends to be a more complicated automation scenario. 

Only use this when the provisioner is the only system reachable from the operator workstation.

---

## After data delivery

When `import_bundle.sh` finishes, it prints the next steps to follow.
Continue with Step 2 and Step 3 from the **How to run** section above.

---

## Security notes

<!-- MANDATORY: vault password callout — do not remove or consolidate (C14) -->
- **The vault password is NOT on this drive.** It must arrive via a separate trusted
  channel (encrypted email, out-of-band verbal, physical paper, etc.).
- Do not leave this drive connected to systems when not in active use.
- The drive is formatted ext4 — it requires a Linux system to mount.
- SSH keys used for the transfer are the operator's own keys, not embedded in this bundle.

---

## Troubleshooting

| Problem | Likely cause | Fix |
|---|---|---|
| `ansible-playbook: command not found` | ansible-core not installed | `dnf install ansible-core` |
| `Permission denied (publickey)` | SSH key not loaded or wrong path | Check `~/.ssh/id_ed25519` exists and matches `ansiblerunner` authorized_keys |
| `validate_import_bundle.sh` reports FAIL | Drive not fully written or transfer interrupted | Re-run `transfer_to_drive.sh` on the lowside workstation |
| `rsync: mkdir failed: Permission denied` | Target path needs sudo | Ensure ansiblerunner has NOPASSWD sudo on the target |
| `bootstrap/`, `provisioner/`, `satellite/` missing | Staging not complete on lowside | Re-run `export_deployment.sh` on the lowside provisioner |
| IdM build fails: `DNS server 8.8.8.8: query '. SOA': The resolution lifetime expired` | `ipaserver_no_forwarders` not set — the IPA installer validates every configured forwarder and 8.8.8.8 is unreachable in a disconnected environment | Verify `idm_disconnected: true` is in the inventory at `~/rhis/rhis-builder-inventory/deployments/<deployment>/group_vars/all/main.yml`. If missing, add `ipaserver_no_forwarders: true` directly to `host_vars/idm1.<domain>/idm_primary_setup_vars.yml` and re-run `build_idm_primary.sh` |

---

## Support

If you encounter issues not covered here, contact the lowside RHIS team.
Log files are written to `deployments/<deployment>/logs/` on the provisioner.
