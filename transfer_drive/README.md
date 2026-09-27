# transfer_drive/

Source directory for all operator-facing content that ends up on the RHIS transfer drive.

Files here fall into two categories: **static files** copied as-is into the export staging
directory, and **templates** rendered by `export_deployment.sh` before being placed in staging.
Neither category is used directly from this directory at runtime.

---

## Files

### Static — copied as-is to the staging root (highside operator tools)

| File | Destination on drive | Purpose |
|---|---|---|
| `README_FIRST.md` | `README_FIRST.md` | Highside operator guide — step-by-step instructions for bundle delivery and satellite build |
| `import_bundle.sh` | `import_bundle.sh` | Thin bash wrapper; entry point for the highside operator; launches `import_bundle.yml` |
| `import_bundle.yml` | `import_bundle.yml` | Survey-driven Ansible playbook that delivers bundle content to the highside hosts via one of three methods: `usb`, `rsync`, or `virtual_disk` |

### Templates — rendered by `export_deployment.sh` Stage 2 (lowside operator tools)

The `.tmpl` files are never copied raw. Stage 2 substitutes `@@TOKEN@@` placeholders with
run-specific values (provisioner hostname, satellite hostname, staging path, Pulp export path,
ISO paths, timestamp) and writes the rendered output to the staging directory.

| Template | Rendered output on drive | Purpose |
|---|---|---|
| `transfer_to_drive.sh.tmpl` | `transfer_to_drive.sh` | Lowside operator entry point; generates an Ansible inventory and runs `transfer_to_drive.yml` |
| `transfer_to_drive.yml.tmpl` | `transfer_to_drive.yml` | Ansible playbook that rsyncs staging artifacts from the provisioner and Pulp content from the satellite directly to the mounted transfer drive |

---

## What is NOT sourced from this directory

`validate_import_bundle.sh` also lands at the drive root but originates from the
`rhis-provisioner-container` repo — copied from
`../rhis-provisioner-container/rhis-provisioner/validate_import_bundle.sh` during Stage 1.5.

---

## How content reaches the drive

```
export_deployment.sh
  Stage 1.5 — copies static files from transfer_drive/ into the staging directory
  Stage 2   — renders .tmpl files into the staging directory

transfer_to_drive.sh (run by the lowside operator on their workstation)
  Transfer 1   — rsyncs the staging directory from the provisioner to the drive
  Transfer 1b  — copies infra ISOs from the provisioner to the drive
  Transfer 3   — rsyncs Pulp content from the satellite directly to the drive
```
