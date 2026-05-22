# rhis-builder-inventory

### Getting started fast
---
You need a system with git and podman tools.
VSCode is very helpful.
Having ansible language, ansible linter and wolfmah's ansible-vault inline is also super useful.

We are currently running fedora and rhel 9.latest systems. Your mileage may vary.

Get this repository:
```
wget https://github.com/parmstro/rhis-builder-inventory/archive/refs/heads/main.zip
unzip main.zip
mv rhis-builder-inventory-main rhis-builder-inventory   # rename it for convenience
cd rhis-builder-inventory
git init -b main                                        # you should ensure that the branch is main
git add * --all
git commit -m "Initial commit"
git remote add origin https://github.com/<your_org_or_login>/rhis-builder-inventory.git  # or whatever your url is
git remote -v
git push -u origin main
```

This repository supports multiple simultaneous RHIS deployments. Each deployment has its own directory under `deployments/` and its own basevars file.

Copy `inventory_basevars.yml` to a domain-specific file and edit it for your environment:
```
cp inventory_basevars.yml your.domain_inventory_basevars.yml
```

Review and edit `your.domain_inventory_basevars.yml`, then run the inventory_update shell script passing your domain basevars file:
```
./inventory_update.sh -b your.domain_inventory_basevars.yml
```

`inventory_update.sh` will build a new directory at `deployments/your.domain/` containing the customized RHIS build configuration based on the parameters you have provided. Running it again with a different domain basevars file creates an independent deployment alongside the first.

The inventory_update script will also create a custom launch script at the repo root (`your.domain.24.sh` or `your.domain.25.sh`) to pull and launch the rhis-provisioner container mounted against your deployment.

See below for information on customizing your build further.

---

## inventory_basevars.yml reference

`inventory_basevars.yml` is the committed template that you copy to `<your.domain>_inventory_basevars.yml` before customizing. Domain-specific basevars files are gitignored so each user's environment details stay out of the shared repository. The file controls how your deployment directory is generated — the host names, network parameters, location metadata, and system counts. It does **not** configure the hosts themselves; that is done through the generated `host_vars/` and `group_vars/` files inside your deployment directory.

> **Note:** Networks, datastores, and other underlying hypervisor or hyperscaler resources referenced in your configurations **must already exist** before running the RHIS provisioner. Satellite will attempt to validate compute resources and profiles at runtime and will fail if they are absent.

### global_domain_name

```yaml
global_domain_name: "example.ca"
```

The fully-qualified domain name for your RHIS deployment. This value drives:

- The name of the generated deployment directory: `deployments/<global_domain_name>/`
- The FQDN of every generated host: `<role><N>.<global_domain_name>` (e.g. `satellite1.example.ca`, `idm2.example.ca`)
- The name of the generated container launch scripts at the repo root: `<global_domain_name>.24.sh` / `<global_domain_name>.25.sh`
- The prefix of all `group_vars/platform_installer/` files

Set this to the actual DNS domain you will use for your environment.

### default_network / default_network_prefix / default_network_mask

```yaml
default_network: "192.168.140.0"
default_network_prefix: "22"
default_network_mask: "255.255.252.0"
```

The primary network for your RHIS hosts. All three values are required:

- `default_network` — the network address (not a host address)
- `default_network_prefix` — CIDR prefix length as a string
- `default_network_mask` — dotted-decimal mask, used by templates that require it alongside the prefix

These values are used to calculate the reverse DNS zone name and to populate network-related templates (chrony, IdM DNS configuration, subnets). They define the network your hosts live on; they do **not** create that network.

### default_bond_network / default_bond_network_prefix / default_bond_network_mask

```yaml
default_bond_network: "192.168.142.0"
default_bond_network_prefix: "22"
default_bond_network_mask: "255.255.252.0"
```

The network used for bonded interface test hosts. Same format as `default_network`. Only relevant if you are deploying `bond_test_hosts`. If you are not using bonded interfaces, set this to match your primary network or leave the example values in place.

### rhis_primary_city / rhis_primary_state

```yaml
rhis_primary_city: "Hespeler"
rhis_primary_state: "Ontario"
```

The physical location of your primary site. Used to populate Satellite location configuration. Set these to the city and state/province where your infrastructure resides.

### rhis_timezone

```yaml
rhis_timezone: "America/Toronto"
```

The timezone for your RHIS hosts in tz database format. Used in chrony configuration templates and kickstart generation. Must be a valid tz identifier (e.g. `America/New_York`, `Europe/London`, `Asia/Tokyo`).

### rhis_locale

```yaml
rhis_locale: "en"
```

The locale prefix for your hosts (e.g. `en`, `fr`, `de`). Used in system locale configuration templates.

### rhis_time_servers

```yaml
rhis_time_servers:
  - "0.rhel.pool.ntp.org"
  - "1.rhel.pool.ntp.org"
  - "2.rhel.pool.ntp.org"
  - "3.rhel.pool.ntp.org"
```

The list of NTP time servers to configure on your hosts via chrony. Use your organization's internal NTP servers if available. The public RHEL pool servers are a reasonable default if you have internet access.

### rhis_aap_release_version

```yaml
rhis_aap_release_version: "2.4"
```

The AAP release version to deploy. Accepted values are `"2.4"` and `"2.6"`. This controls:

- Which AAP `host_vars` templates are used (`aapcontroller24`/`aaphub24` vs `aapcontroller26`/`aaphub26`)
- The container image selected when launching the rhis-provisioner

This does **not** install AAP itself; it selects the correct configuration templates that the provisioner will use when it runs the AAP installation role.

### rhis_system_count

```yaml
rhis_system_count:
  satellite: 1
  discosatellite: 0
  capsule: 1
  idm: 2
  aapcontroller: 1
  aaphub: 1
  quadlet: 2
```

Controls how many instances of each host role are included in your deployment. For each role key, `inventory_update.sh` generates numbered host directories under `host_vars/` and corresponding inventory entries: `<role>1.<domain>`, `<role>2.<domain>`, and so on.

| Key | Role | Notes |
|---|---|---|
| `satellite` | Red Hat Satellite | Primary Satellite server |
| `discosatellite` | Disconnected Satellite | Satellite in a secure enclave that receives exported content from the primary Satellite for air-gapped environments; set to `0` if not needed |
| `capsule` | Satellite Capsule | Remote Capsule servers |
| `idm` | Red Hat IdM | Identity Management; typically 1 primary + 1 replica (count of 2) |
| `aapcontroller` | AAP Controller | Automation controller nodes |
| `aaphub` | AAP Private Automation Hub | Hub nodes |
| `quadlet` | Quadlet hosts | Container hosts managed via Quadlet |

Setting a count to `0` skips that role entirely — no `host_vars` directory or inventory entry is generated for it.

`rhis_system_count` controls **quantity only**. Per-host configuration (IP addresses, disk layout, credentials, etc.) is done in the generated `host_vars/<hostname>/` files inside your deployment directory after running `inventory_update.sh`.

### rhis_aws_region / rhis_azure_region

```yaml
rhis_aws_region: "us-east-2"
rhis_azure_region: "East US 2"
```

Cloud region identifiers used when configuring Satellite compute resources for AWS and Azure respectively. These are passed into the compute resource templates. If you are not using cloud providers, these values are still required by the templates but will not be evaluated unless you configure cloud-based compute resources in your deployment.

---

## Before running the container

Review the generated content in `deployments/<your.domain>/` before launching the container. Many entries in `group_vars/`, `host_vars/`, and `templates/` are intentionally broad — they are designed to demonstrate RHIS concepts and techniques in a proof-of-concept context. Not all of them will apply to your environment, and you should remove or simplify anything that does not.

### Infrastructure as Code and GitOps

Your deployment directory is a complete, file-based description of your infrastructure. Every host, Satellite setting, AAP template, and IdM policy lives in a file that can be read, reviewed, and changed like any other code.

Once you are comfortable with how the generated content maps to the underlying roles and plays, modify the source templates in `inventory_template/` to match your organization's standards. This moves you from a proof-of-concept toward a true **Infrastructure as Code** practice: your environment is declared in code, not built by hand.

That practice fits naturally into a **GitOps** pipeline:

- Infrastructure changes are proposed as pull requests against your inventory repository
- Approved changes are merged and drive the rhis-provisioner container to apply the updated configuration
- The repository becomes the single source of truth for the state of your environment

---

## Running the rhis-provisioner container

Once your deployment directory is generated, run the domain launch script from the repo root:

```
./your.domain.24.sh    # for AAP 2.4
./your.domain.25.sh    # for AAP 2.5 / 2.6
```

The script starts the `rhis-provisioner` container interactively. Your deployment configuration is mounted read-write into the container at startup. The container hostname is set to `provisioner` and it is named `rhis-builder`.

> **Note:** Any files you add to the mounted directories after the container starts will not be visible inside the container. You must stop and restart the container to pick up new files.

### What is mounted inside the container

| Host path | Container path | Contents |
|---|---|---|
| `deployments/<domain>/inventory/` | `/rhis/vars/external_inventory/` | Inventory file(s) |
| `deployments/<domain>/external_tasks/` | `/rhis/vars/external_tasks/` | External task files |
| `deployments/<domain>/files/` | `/rhis/vars/files/` | Supporting files (RPMs, SCAP content, scripts) |
| `deployments/<domain>/group_vars/` | `/rhis/vars/group_vars/` | Group variable files |
| `deployments/<domain>/host_vars/` | `/rhis/vars/host_vars/` | Host variable files |
| `deployments/<domain>/templates/` | `/rhis/vars/templates/` | Jinja2 templates |
| `deployments/<domain>/vars/` | `/rhis/vars/vars/` | Non-secret variable files |
| `deployments/<domain>/vault/` | `/rhis/vars/vault/` | Vault-encrypted secrets |
| `~/.ssh/` | `/root/.ssh/` | SSH keys for reaching provisioned hosts |

### Build phases

The RHIS build runs in phases inside the container. Complete each phase before starting the next:

**Phase 2 — Identity Management (IdM)**
Configure the primary IdM server and any replicas. IdM must be fully operational before Satellite is installed, as Satellite registers to IdM for Kerberos and certificate services.

**Phase 3 — Red Hat Satellite**
Configure Satellite including content, lifecycle environments, activation keys, provisioning templates, and compute resources. Satellite must be operational before AAP is configured, as AAP uses Satellite for host registration and content.

**Phase 4 — Ansible Automation Platform (AAP)**
Configure the AAP Controller, Private Automation Hub, and any additional nodes. AAP is configured last as it depends on both IdM (for authentication) and Satellite (for content and inventory sources).

> **Phase 1 — Baremetal bootstrap** (runs outside the container, before the above phases): Use `rhis-builder-baremetal-init` to generate OEMDRV kickstart images and bootstrap your physical or virtual hosts to a base RHEL 9 install before running the container.

### Stopping and restarting the container

The container is started with `--rm`, so it is automatically removed when you exit. To restart it with the same configuration, simply run the domain launch script again.

If the container is already running and you need to access it from another terminal:

```
podman exec -it rhis-builder /bin/bash
```

---

## What is in this repository

NOTE:
The rhis-builder-inventory now contains a version.txt file. Its purpose is to allow users to recognize change and updates to the schema and to help align the sample data with the rhis-provisioner container. This capability will be enhanced through releases with the intention of eventually providing configuration validation. As we consume a huge number of projects under rhis-builder this task will be ongoing.

Provide the configuration definitions to the rhis-provisioner container for all RHIS repositories for a given Organization including:

* external_tasks directory
    * this folder will contain tasks external to RHIS repositories that may be needed by the customer to prepare an environment or extend the RHIS environment.

* files directory
    * this folder contains files required by RHIS to build the environment. Examples are the OpenSCAP contents and tailoring files and scripts necessary to install roles consumed by the RHIS Satellite installation.

* group_vars directory
    * this folder contains a folder for each of the groups in the inventory that require group specific configuration. Each group's folder will contain the variable files necessary for that group's configuration. All files in the folders with a yaml or yml extension will be consumed by RHIS plays when executing against the specified group systems.

* host_vars directory
    * this folder contains a folder for each of the hosts in the inventory that require host specific configuration. Each host's folder will contain the variable files necessary for that host's configuration. All files in the folders with a yaml or yml extension will be consumed by RHIS plays when executing against the specified host systems.

* inventory directory
    * an inventory folder is used to contain one or more inventory files for the organization (e.g. a DEV inventory vs. a QA inventory). Only one inventory file is used at a time.

* templates directory
    * this folder contains templates required by RHIS to build the environment. Examples are all the Satellite provisioning, job and partition table templates. You can modify or extend these configurations by adding your own templates, or customizing existing templates. The example.ca organization templates are provided as examples and can be used directly in your own configurations.

* vars directory
    * this folder contains vars files to be used in the RHIS build environment that are:
        * not secrets
        * are not specific to a particular group or host. There should be very few of these!

* vault directory
    * the vault directory is created only within your deployment directory (`deployments/<your.domain>/vault/`). It is never present at the repository root. Because the entire `deployments/` tree is gitignored, secrets stored here will never be committed to the repository. All secrets files — in particular your `rhis_builder_vault.yml` — must be placed here and nowhere else. Reference vault file structures are provided in `inventory_template/vault_SAMPLES/` to help you get started.
