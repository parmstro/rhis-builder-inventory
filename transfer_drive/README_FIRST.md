# RHIS Highside Bundle — READ THIS FIRST

This drive contains everything needed to build a disconnected Red Hat Infrastructure
Standard (RHIS) environment. Follow these steps in order.

---

## What's on this drive

| Item | Description |
|---|---|
| `import_bundle.sh` | Start here — launches the delivery survey |
| `import_bundle.yml` | Ansible playbook called by the script |
| `<Org_Folder>/` | Red Hat Pulp content export — RPMs, kickstart repos (large, do not modify) |
| `rhis_transfer_<timestamp>/` | RHIS configuration bundle |
| `rhis_transfer_<timestamp>/isos/` | OEMDRV kickstart ISOs for provisioner, IdM, and satellite |
| `rhis_transfer_<timestamp>/bootstrap_init/` | rhis-builder-bootstrap-init repo — regenerate ISOs if needed |
| `rhis_transfer_<timestamp>/ansible_roles/` | Compliance Ansible roles for the satellite |
| `rhis_transfer_<timestamp>/discovery_images/` | Foreman discovery PXE images |

---

## Step 0 — Build the highside hosts (if not already done)

Before running `import_bundle.sh`, the provisioner, IdM, and satellite hosts must exist
with a base RHEL OS install. If they are already built and reachable, skip to Prerequisites.

### Kickstart ISOs

The bundle includes OEMDRV kickstart ISOs for each highside host:

```
rhis_transfer_<timestamp>/isos/
  provisioner.<domain>.iso
  idm1.<domain>.iso
  satellite1.<domain>.iso
```

Each ISO is an unattended kickstart image.
Attach it as a second virtual CD-ROM alongsidethe RHEL installation DVD when booting the host on a hypervisor or on baremetal.
Anaconda automatically picks up the OEMDRV volume and uses the embedded ks.cfg to install the systems without prompts.

The `rhis_transfer_<timestamp>/bootstrap_init/` directory contains the
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
3. **Vault password** — delivered via a separate trusted channel (it is NOT on this drive)
4. **Drive mounted** — this drive is mounted and readable (you're reading this, so it is)

---

## How to run

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

---

## Delivery methods

### `usb` — Physical connection to satellite baremetal
The drive is physically connected to (or USB-attached to) the satellite server.

- Script pauses and asks you to connect the drive
- No network transfer happens from this workstation
- The provisioner discovers and mounts the drive by label (`TRANSFER_DRV`)
- **Do NOT mount the drive on the satellite yourself** — the build script handles that

Best for: baremetal satellite with a USB port or hot-plug storage.

### `rsync` — Network push from this workstation (recommended for VMs)
The script pushes data directly from this workstation to its destination over the network:

- Pulp content (`<Org_Folder>/`) → satellite `/var/satellite_stage/pulp_stage/`
- Bundle artifacts (`rhis_transfer_<ts>/`) → provisioner `/mnt/rhis_transfer/`

No double-hop through the provisioner for the large Pulp content.

Best for: operator workstation has network access to both provisioner and satellite.

### `virtual_disk` — Push everything to provisioner
The script pushes all drive content to the provisioner. The provisioner then delivers
everything to the satellite during the build.

- All content → provisioner `/mnt/rhis_transfer/`

Best for: only the provisioner is reachable from the operator workstation.

---

## After data delivery

When `import_bundle.sh` finishes, it prints the exact command to run.

In summary:

1. SSH to the provisioner:
   ```bash
   ssh ansiblerunner@<provisioner_ip>
   ```

2. Run the satellite import build script inside the provisioner container:
   ```bash
   build_sat_disconnected_import.sh \
     --delivery-method <method> \
     --deployment <deployment_name>
   ```

   This script:
   - Runs `bundle_delivery.yml` — validates and stages content on the satellite
   - Prepares `content_imports.yml` and disconnected extra-vars
   - Runs `main.yml` — installs and fully configures the satellite (60–90 minutes)

---

## Security notes

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
| `No rhis_transfer_* directory found` | Drive not fully written | Re-run `export_deployment.sh` on the lowside |
| `rsync: mkdir failed: Permission denied` | Target path needs sudo | Ensure ansiblerunner has NOPASSWD sudo on the target |
| `bundle_delivery.yml` fails on satellite | Drive label not TRANSFER_DRV | Check `blkid` output on satellite; re-label with `e2label /dev/sdX TRANSFER_DRV` |

---

## Support

If you encounter issues not covered here, contact the lowside RHIS team.
Log files are written to `deployments/<deployment>/logs/` on the provisioner.
