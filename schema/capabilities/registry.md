# RHIS Capability Registry

## Design Statement

> RHIS exists so that a Red Hat Infrastructure operator has an opinionated model of what
> good looks like to guide the design of their own environment. RHIS provides the foundational
> templates and build code to realize the model. A RHIS infrastructure operator should be able
> to select a set of components that meet a high level operational need — such as "secure content
> curation and delivery" or "centralized identity and security policy enforcement" — and RHIS can
> integrate the Red Hat specific tooling in a way that connects them to meet the customer intent
> while configuring them to meet Red Hat recommended practice and configuration.

---

## Architectural Note: The RHIS Node Standard (Meta-Capability)

Once IdM (C01) and Satellite (C05/C06/C07/C14) are stood up and validated, a RHIS operator
can deploy any remaining RHIS infrastructure node from Satellite and receive a host that is
automatically enrolled in IdM, registered to Satellite, and — if AAP is deployed — configured
to the current RHIS baseline via Ansible callback.

**Current RHIS baseline** (applied by `SOE_Base_Ansible_Callback` in AAP):
- Appropriate issue and message of the day (legal/compliance banner)
- Time sync (chrony configured and synchronized)
- Cockpit deployed with IdM-issued service certificate

The baseline is a living standard — it grows as the RHIS standard footprint is defined.
Next additions: log forwarding (audit + system logs) to a central aggregator.

**Validated by:** Test host builds (`hostgroup_test_hosts_rhel8/9/10.yml`). When test hosts
complete end-to-end — provisioned, IdM-enrolled, Satellite-registered, callback applied —
that is the proof the meta-capability is working. `last_verified` = last successful test
host build.

**Integrates:** C01 (IdM enrollment) + C06 (provisioning) + C07 (subscription) +
C13 (REX/callback) + C15 (pipeline validation)

---

## Architectural Note: The Pipeline as Integration Layer

The SOE Content Delivery and Validation Pipeline (C15) is not one capability among many —
it is the integration and verification layer that all other capabilities feed through.
A capability is not `implemented` until it can be tested through the pipeline and produce
evidence. `last_verified` for any RHIS capability is the last time the pipeline ran
successfully with that capability enabled.

---

## Status Summary

| ID | Capability | Overall Status |
|---|---|---|
| META-1 | RHIS Node Standard — baseline applied to every managed host | `partial` — issue/MOTD + time sync + Cockpit implemented; log forwarding `designed` |
| META-2 | SOE Content Delivery and Validation Pipeline — integration and verification layer | see C15 |
| C01 | Centralized Identity Management | `partial` |
| C02 | Hardware Token Authentication (Smart Card) | `partial` |
| C03 | Network Bound Disk Encryption (NBDE) | `partial` |
| C04 | Per-host Password and Passphrase Escrow | `partial` |
| C05 | Content Lifecycle Management | `implemented` |
| C06 | Host Provisioning and Lifecycle | `implemented` |
| C07 | Subscription and Entitlement Management | `implemented` |
| C08 | Compliance and Security Posture | `partial` |
| C09 | Distributed Content Delivery (Capsule) | `implemented` |
| C10 | Disconnected / Air-Gapped Operation | `partial` |
| C11 | Hybrid Infrastructure Integration | `implemented` |
| C12 | Organizational Governance | `partial` |
| C13 | Automation Integration | `implemented` |
| C14 | Opinionated Platform Configuration | `implemented` |
| C15 | SOE Content Delivery and Validation Pipeline | `partial` |
| C16 | Cloud Image Build and Registration | `partial` |
| C17 | Outbound-Only Managed Node Connectivity | `aspirational` |
| C18 | Enterprise Linux to RHEL Conversion (Convert2RHEL) | `broken` |
| C19 | Infrastructure Landing Zone — KVM/Libvirt | `partial` |
| C20 | Infrastructure Landing Zone — VMware | `partial` |
| C21 | Infrastructure Landing Zone — OCP Virt / KubeVirt | `partial` |
| C22 | Infrastructure Landing Zone — Azure | `partial` |
| C23 | Infrastructure Landing Zone — AWS | `partial` |
| C24 | Infrastructure Landing Zone — GCP | `aspirational` |
| C25 | Quadlet / Podlet Host Deployment | `partial` |
| C26 | Additional Infrastructure Services (observability, logging) | `partial` |
| C27 | Deployment Model Selection and Sequencing | `designed` |
| C28 | GitOps Infrastructure Management | `aspirational` |
| C29 | Full SOE Lifecycle — IdM + Satellite + AAP, build to retirement | `aspirational` |
| C30 | Edge Manager Deployment | `partial` |
| C31 | ImageMode / Bootc Image Build and Deployment | `partial` |

---

## C01 — Centralized Identity Management

**Operator need:** A single authoritative source for user identity, host identity, DNS, Kerberos
authentication, certificates, access policy, and sudo rules across all managed infrastructure.

**Authority:** `idm`
**Workflow type:** `mutating`
**Repo:** `rhis-builder-idm`

| Feature | Status | Notes |
|---|---|---|
| Core IdM deployment | `implemented` | |
| DNS management | `implemented` | |
| Kerberos configuration | `implemented` | |
| Host enrollment | `implemented` | |
| HBAC rules | `implemented` | |
| Sudo rules | `implemented` | |
| User and group management | `implemented` | |
| Certificate authority | `implemented` | |
| RHIS-specific RBAC role definitions | `partial` | Standard IdM roles exist; RHIS operator roles not yet defined. Prerequisite for scoping escrow access (C04) and break-glass (C02). |

---

## C02 — Hardware Token Authentication (Smart Card)

**Operator need:** Users authenticate with a physical YubiKey (PIV/smart card mode) rather
than passwords. Hardware-bound two-factor authentication for RHIS operators and managed
system access.

**Authority:** `idm`, `yubikey`
**Workflow type:** `mutating`
**Repo:** `rhis-builder-yubikey`

| Feature | Status | Notes |
|---|---|---|
| YubiKey certificate provisioning via IdM | `implemented` | Basic provisioning works |
| Smart card authentication policy configuration | `implemented` | |
| Operator onboarding integration workflow | `partial` | How provisioning fits into operator lifecycle not yet defined |
| Connection to break-glass / escrow access | `partial` | Smart card auth should gate escrow retrieval (C04); integration not designed |
| RHIS RBAC scope for YubiKey provisioning | `partial` | Depends on C01 RBAC gap being closed |

---

## C03 — Network Bound Disk Encryption (NBDE)

**Operator need:** Encrypted volumes that are cryptographically bound to machine identity
and network presence, making disks, VM images, and whole machines non-portable outside
the trusted environment.

**Authority:** `satellite`, `tang`, `tpm`, `idm`
**Workflow type:** `mutating`
**Repos:** `rhis-builder-satellite` (Satellite config), `rhis-provisioner-container` (Tang quadlet)

### Binding Models

**Tang-only:** Volume unlocks only when Tang is reachable on boot. Prevents boot without
network access. Does not prevent disk theft by an attacker who has network access.

**Shamir's Secret Sharing (Tang + TPM):** Volume bound to the specific physical or virtual
TPM *and* Tang. Both must be present to unlock. Prevents disk theft (no TPM), VM image
theft (vTPM is hypervisor-bound), and physical machine removal (no Tang reachable).

### Provisioning Flow

1. **Anaconda phase:** LUKS volume created with a bootstrap passphrase (`default_passphrase`
   global parameter, or per-host random). Anaconda requires a passphrase to create the volume —
   this is a bootstrap necessity, not the operational unlock mechanism.
2. **Kickstart %post phase:** Clevis makes the actual Tang binding (and TPM binding if
   Shamir's model is selected).
3. **Policy decision:** Bootstrap passphrase is either removed from LUKS keyslots (strict —
   Tang+TPM is the *only* unlock path) or retained (provides a manual recovery path).

| Feature | Status | Notes |
|---|---|---|
| Tang server deployment as quadlet | `implemented` | |
| NBDE-aware (encrypted) partition table in Satellite | `implemented` | |
| Global parameters (binding type, binding definition) | `implemented` | `default_passphrase`, LUKS binding type, binding definition |
| Kickstart %post Clevis binding | `implemented` | Tang-only and SSS (Tang+TPM) |
| Bootstrap passphrase remove/retain policy | `implemented` | Operator choice via parameter |
| Physical TPM binding (bare metal) | `implemented` | |
| Virtual TPM binding (KVM/VMware vTPM) | `implemented` | |
| Random per-host LUKS bootstrap passphrase generation | `designed` | Currently uses `default_passphrase`; random generation not yet implemented |
| LUKS passphrase escrow to IdM vault | `designed` | Depends on C04 escrow implementation |
| Pipeline test playbook for NBDE verification | `designed` | No `deployment_test.yml` equivalent exists to prove binding is correct |

**Known gap:** Without random bootstrap passphrase generation, all hosts share the same
`default_passphrase` as the LUKS backup key (if retained). This is a security risk in
multi-tenant or multi-customer environments.

---

## C04 — Per-host Password and Passphrase Escrow

**Operator need:** Every provisioned host has a unique, randomly generated root password
and LUKS bootstrap passphrase that are stored securely in IdM and retrievable by authorized
administrators. No shared passwords, no locked-out hosts, no plaintext in automation layer.

**Authority:** `idm`, `satellite`, `eigenstate-ipa`
**Workflow type:** `mutating`

| Feature | Status | Notes |
|---|---|---|
| Random root password generation at provision time | `designed` | Currently uses `default_passphrase` pattern; per-host random not yet implemented |
| Random LUKS bootstrap passphrase generation | `designed` | See C03 — same implementation work |
| IdM vault escrow for root password | `partial` | External private repo (another Red Hatter); RHIS does not own the code |
| IdM vault escrow for LUKS passphrase | `designed` | Not yet implemented |
| Break-glass retrieval workflow | `aspirational` | eigenstate.ipa integration planned but not designed |
| Retrieval authorization (who can access which host's escrow) | `aspirational` | Depends on C01 RBAC and C02 smart card gating |

**Implementation path:** Random generation + IdM escrow will be implemented by integrating
`eigenstate.ipa` (Greg Procunier's IdM vault and break-glass library). RHIS will own this
integration rather than depending on an external private repo.

---

## C05 — Content Lifecycle Management

**Operator need:** Synchronize, filter, and manage Red Hat and third-party package content
across multiple RHEL versions with defined lifecycle promotion paths.

**Authority:** `satellite`, `pulp`, `cdn`
**Workflow type:** `mutating`
**Repo:** `rhis-builder-satellite`

| Feature | Status | Notes |
|---|---|---|
| Repository set management (CDN enable/disable) | `implemented` | |
| Custom product and repository configuration | `implemented` | EPEL, CentOS, MSSQL, Oracle, etc. |
| Content synchronization and sync plans | `implemented` | |
| Lifecycle environment topology | `implemented` | Library → Dev → QA → Staging → Production → Retired |
| Content view creation with filters | `implemented` | RPM, modulemd, erratum filters |
| Composite content view management | `implemented` | |
| Content view publication and promotion | `implemented` | |
| Errata end-date filter management | `implemented` | Used by SOE pipeline (C15) |
| Content credential management (GPG keys, SSL) | `partial` | Import works; export for disconnected transfer not yet automated |
| Repository download policy configuration | `implemented` | immediate / lazy per repo |
| RHEL 9.8 kickstart repos | `partial` | Repos sync correctly; excluded from CVs due to aadsshlogin CDN duplicate content bug (see schema/TODO.md). Re-enable only after SQL verification passes. |

---

## C06 — Host Provisioning and Lifecycle

**Operator need:** Automated bare-metal and VM provisioning with standardized OS builds,
partition layouts, and post-build configuration, driven by a hostgroup hierarchy that
encodes opinionated defaults.

**Authority:** `satellite`, `idm`, `kvm`, `cloud`
**Workflow type:** `mutating`
**Repo:** `rhis-builder-satellite`

| Feature | Status | Notes |
|---|---|---|
| Operating system definitions (RHEL 7/8/9/10) | `implemented` | |
| Partition table management | `implemented` | Standard and NBDE-encrypted variants |
| Provisioning template management | `implemented` | Kickstart templates with custom snippets |
| Installation media configuration | `implemented` | |
| Hostgroup hierarchy with inheritance | `implemented` | RHEL version → arch → bare metal/VM with parameter inheritance |
| PXE boot and Foreman discovery | `implemented` | |
| Network configuration (domains, subnets, realms) | `implemented` | |
| `create_host.yml` — YAML-driven host creation | `implemented` | Used by SOE pipeline (C15) |
| Job template configuration | `partial` | Basic scaffolding; not fully built out |
| Template repository synchronization | `implemented` | External template repos synced to Satellite |

---

## C07 — Subscription and Entitlement Management

**Operator need:** Manage Red Hat subscriptions, manifests, and activation keys so that
provisioned hosts are correctly entitled and content-scoped from first boot.

**Authority:** `satellite`, `cdn`
**Workflow type:** `mutating`
**Repo:** `rhis-builder-satellite`

| Feature | Status | Notes |
|---|---|---|
| Subscription manifest creation and import | `implemented` | |
| Activation key management | `implemented` | Keys define CV, lifecycle environment, content overrides |
| Virt-who configuration | `implemented` | Virtual-to-physical host mapping for subscription compliance |

---

## C08 — Compliance and Security Posture

**Operator need:** Measure and enforce host configuration compliance against standard
security frameworks. Provide the compliance role library so hosts can be hardened
to any required standard.

**Authority:** `satellite`, `idm`, `aap`
**Workflow type:** `mutating`
**Repo:** `rhis-builder-satellite`

| Feature | Status | Notes |
|---|---|---|
| SCAP content upload (RHEL 8/9 DS files) | `implemented` | |
| SCAP tailoring file management | `implemented` | Custom tailoring files for policy adjustment |
| SCAP policy assignment to hostgroups | `partial` | Basic scaffolding; policy enforcement workflow not complete |
| Compliance role library import | `implemented` | STIG, CIS, PCI-DSS, HIPAA, OSPP, ANSSI, ISM, E8, CUI |
| Compliance role execution via Satellite REX | `implemented` | |
| Compliance results reporting | `partial` | Results visible in Satellite; no automated reporting pipeline |
| SCAP scan as pipeline phase | `designed` | Should be a QA pipeline phase; not yet wired in |

---

## C09 — Distributed Content Delivery (Capsule)

**Operator need:** Deliver content and proxy services to remote network segments without
requiring every managed host to reach the primary Satellite directly.

**Authority:** `satellite`, `idm`
**Workflow type:** `mutating`
**Repo:** `rhis-builder-satellite`

| Feature | Status | Notes |
|---|---|---|
| Primary Satellite installation and configuration | `implemented` | |
| Capsule server installation | `implemented` | |
| Capsule pre-configuration (DNS, certs, packages) | `implemented` | |
| Capsule certificate generation and distribution | `implemented` | |
| Capsule content sync | `implemented` | |

---

## C10 — Disconnected / Air-Gapped Operation

**Operator need:** Deploy and manage a full RHIS stack in an environment with no connection
to the Red Hat CDN. Content crosses the air gap via a transfer bundle produced on the
connected (lowside) satellite and imported on the disconnected (highside) satellite.

**Authority:** `satellite`, `pulp`, `provisioner`
**Workflow type:** `mutating`
**Repos:** `rhis-builder-satellite`, `rhis-provisioner-container`, `rhis-builder-inventory`
**Active branch:** `disconnected_satellite`

| Feature | Status | Notes |
|---|---|---|
| Disconnected satellite pre-configuration | `implemented` | `satellite_disconnected_pre` role |
| Content export (Pulp library export) | `implemented` | `export_disconnected.yml` playbook. Export config defined in `content_exports.yml` |
| Transfer drive preparation and mount | `implemented` | `configure_export.sh` — auto-discovers drive by label `TRANSFER_DRV`, validates size, mounts at `/var/lib/pulp/exports/` with `pulpcore_var_lib_t` SELinux context |
| Bundle manifest generation with SHA256 checksums | `implemented` | |
| Operator export checklist generation | `implemented` | Includes transfer drive readiness checks |
| ISO pre-stage and mount (rsync-based) | `implemented` | `satellite_disconnected_iso_prestaged/mounted` variables |
| Compliance role bundle (rsync to transfer media) | `implemented` | `satellite_roles_source_path` |
| rhis-builder-baremetal-init bundle | `implemented` | Synced to `baremetal_init/` in export bundle. Provides highside operator with kickstart ISO generation tools — used to prepare bare metal or VMware VMs (upload ISO to vCenter) before IdM and Satellite are operational. |
| Content import on highside | `implemented` | `content_imports` role |
| `content_imports.yml` auto-generation for highside | `designed` | Pre-populated import config; not yet implemented |
| Content credential export | `designed` | GPG keys and SSL certs for custom products; not yet automated |
| Container image transfer for highside services | `aspirational` | Placeholder; specific images TBD based on workload |
| Production patching workflow (disconnected) | `designed` | |

**Transfer drive convention:** ext4, labelled `TRANSFER_DRV`, mounted at `/var/lib/pulp/exports/`
on the lowside satellite. `configure_export.sh` auto-discovers by label — no hardcoded device
paths. Drive capacity must meet or exceed current `/var/lib/pulp` usage for a full Library export.

---

## C11 — Hybrid Infrastructure Integration

**Operator need:** Connect Satellite to multiple compute environments so that host
provisioning and image management work consistently across bare metal, local
hypervisors, and public clouds.

**Authority:** `satellite`, `kvm`, `cloud`
**Workflow type:** `mutating`
**Repo:** `rhis-builder-satellite`

| Feature | Status | Notes |
|---|---|---|
| Compute resource management | `implemented` | VMware, AWS, Azure, GCP, OpenStack, KVM/libvirt, oVirt, Proxmox |
| Compute profile management | `implemented` | VM hardware profiles (CPU, RAM, storage) per compute resource |
| Virt-who configuration | `implemented` | |

---

## C12 — Organizational Governance

**Operator need:** Define and enforce who can do what in Satellite and across managed
infrastructure, with multi-tenant organizational structure and external identity integration.

**Authority:** `satellite`, `idm`
**Workflow type:** `mutating`
**Repo:** `rhis-builder-satellite`

| Feature | Status | Notes |
|---|---|---|
| Organization and location management | `implemented` | Multi-tenant structure |
| User role definitions with granular permissions | `implemented` | |
| User account management | `implemented` | |
| User group management | `implemented` | |
| External IdM group synchronization | `implemented` | IdM groups → Satellite groups |
| RHIS-specific role definitions | `partial` | Mirrors C01 gap — RHIS operator roles not yet defined in either IdM or Satellite |

---

## C13 — Automation Integration

**Operator need:** Managed hosts can be reached for remote task execution using
Kerberos-authenticated SSH. Ansible compliance roles are available and current.

**Authority:** `satellite`, `idm`, `aap`
**Workflow type:** `mutating`
**Repo:** `rhis-builder-satellite`

| Feature | Status | Notes |
|---|---|---|
| Kerberos remote execution (REX) configuration | `implemented` | |
| Ansible role import and availability | `implemented` | |
| Hammer CLI configuration | `implemented` | |

---

## C14 — Opinionated Platform Configuration

**Operator need:** Satellite is configured to Red Hat recommended practice out of the box,
without requiring operators to know the correct values for hundreds of settings. This is
the "what good looks like" layer — the most distinctly RHIS capability in the codebase.

**Authority:** `satellite`
**Workflow type:** `mutating`
**Repo:** `rhis-builder-satellite` / `rhis-builder-inventory`

| Feature | Status | Notes |
|---|---|---|
| General settings (email, logging, facts) | `implemented` | |
| Provisioning settings (root password, tokens, PXE) | `implemented` | |
| Content settings (default templates, PXE loaders) | `implemented` | |
| Discovery settings (bare-metal PXE defaults) | `implemented` | |
| Authentication settings (LDAP/IdM, SSL/TLS) | `implemented` | |
| Remote execution settings (SSH, Kerberos, workers) | `implemented` | |
| Ansible settings (Tower integration, playbook paths) | `implemented` | |
| Red Hat Cloud / Insights settings | `implemented` | |
| Boot disk settings | `implemented` | |
| 15 settings files, ~2000 lines total | `implemented` | |

---

## C15 — SOE Content Delivery and Validation Pipeline

**Operator need:** A repeatable, end-to-end pipeline that updates content, provisions
test hosts, deploys applications, validates them, and produces evidence of correctness —
for any application that meets the AO contract. All other RHIS capabilities are proven
through this pipeline.

**Authority:** `satellite`, `aap`, `kvm`, `cloud`
**Workflow type:** `mutating`
**Repo:** `rhis-builder-pipelines` (canonical), AAP workflow template `SOE_ContentDeliveryPipeline`
**Definitions:** `group_vars/platform_installer/` (job templates + workflow templates as YAML)

### Pipeline Phases

| Phase | Playbook | Description | Status |
|---|---|---|---|
| Content update | `publish_only.yml` | Update errata end date; publish CVs and CCVs to Library | `implemented` |
| Promotion | `promote_only.yml` | Promote CVs/CCVs from source to target lifecycle environments | `implemented` |
| Host provisioning | `platform_node_build.yml` / `create_hosts.yml` | Build hosts from YAML definition via Satellite hostgroup | `implemented` |
| Snapshot | `vmware/vmw_create_snapshot.yml` | Checkpoint hosts before testing | `partial` — VMware only; bare metal and cloud `designed` |
| Application deployment | AO `main.yml` / `deployment.yml` | Deploy application | `implemented` |
| Smoke test | AO `deployment_test.yml` | Did it deploy correctly? | `implemented` |
| QA test | AO `qa_test.yml` | Do all defined use cases pass? | `implemented` |
| Production validation | AO `prod_test.yml` | Can this return to production rotation? | `designed` — not yet written for any app |
| CV version cleanup | `cv_cleanup.yml` | Keep only `num_cvs_to_keep` versions in Satellite | `implemented` |
| Host teardown | `delete_hosts.yml` | Remove test hosts from Satellite | `implemented` |
| Production patching workflow | — | Full promotion + validation cycle for production | `designed` |

### The Application Owner (AO) Contract

Any application can be onboarded to the pipeline by providing four playbooks in a git repo:

```
main.yml / deployment.yml  — deploy the application
deployment_test.yml        — smoke test: did it deploy correctly?
qa_test.yml                — comprehensive: do all defined use cases pass?
prod_test.yml              — production validation: can this return to production rotation?
```

The contract is application-agnostic. The pipeline shape is identical for any AO. RHIS owns
infrastructure phases; the AO owns application phases. This contract is also the pattern
RHIS uses to prove its own capabilities.

### Implemented AO Applications (in `rhis-builder-pipelines/testcontent/`)

| Application | Deploy | Smoke test | QA test | Prod test |
|---|---|---|---|---|
| JBoss EAP standalone | `implemented` | `implemented` | `implemented` | `designed` |
| LAMP stack (Apache+PHP+MySQL) | `implemented` | `implemented` | `implemented` | `designed` |
| WordPress + Nginx + MariaDB | `implemented` | `implemented` | `implemented` | `designed` |

### Host Definition Pattern

Host definitions live in `rhis-builder-inventory/group_vars/provisioner/` as YAML.
Dispatched to `create_hosts.yml` via `--extra-vars "platform_hosts={{ var_name }}"`.

**MAC address conventions:**
- Real MAC (e.g. `94:c6:91:a3:1b:79`) → bare metal PXE via Foreman discovery by MAC
- `ff:ff:ff:ff:ff:ff` → find first available discovered host (any MAC)
- `00:50:56:ff:ff:ff` → VMware VM (placeholder, replaced by vSphere)

### Testing Models

| Model | Description | Status |
|---|---|---|
| Multi-application, shared content | JBoss + LAMP + WordPress against common SOE content | `implemented` |
| Single application, multiple footprints | One app across bare metal, hypervisor, cloud | `designed` |
| Bonded interface provisioning | 802.3ad LACP via `rhis_test_hosts_with_bonds.yml` | `implemented` |
| Convert2RHEL migration | CentOS7/OEL7 → RHEL7 | `broken` — see note below |

### Convert2RHEL Pipeline — Broken (not deprecated)

The CentOS 7.9 / OEL 7.9 → RHEL 7 conversion pipeline (`c2r_pipeline` AAP workflow,
`rhis-builder-convert2rhel` project) was **fully implemented and working**. It was broken
by a mid-major-release `ansible-core` update that changed Python dependency resolution in a
way that broke the collections required by convert2rhel automation. All repository sets,
repositories, content views, and activation keys are commented out until the EE is fixed.

Restoring it requires research and testing to identify the correct pinned collection and
Python requirements, then building a dedicated EE. The pipeline structure itself is sound —
it is the execution environment that needs work.

**Restoration paths (pick one when ready):**
1. Fix the EE for CentOS 7/OEL 7 → RHEL 7 — pin specific collection/Python requirements
2. Extend to CentOS 8/9 or other EL derivatives → RHEL — pipeline reusable, only source
   OS content and hostgroups change

**Patch JBoss Prod** templates (3 WIP templates in AAP) represent early work toward the
production patching workflow — `partial`, not `designed`.

### QA Workflow
A corresponding QA workflow (`SOE_ContentDeliveryPipeline_QA`) exists. `implemented`

---

## C16 — Cloud Image Build and Registration

**Operator need:** Build a cloud-ready OS image from a blueprint using curated Satellite
content, upload it to a cloud provider, and register it back to Satellite so it is
available for pipeline-driven deployments.

**Authority:** `satellite`, `imagebuilder`, `cloud`, `vault`
**Workflow type:** `mutating`
**Repo:** `rhis-builder-imagebuilder`

**Key design decisions:**
- ImageBuilder is pointed at Satellite (not CDN) — images get the same curated, filtered
  content that managed hosts receive. Operators cannot accidentally build images with
  unrestricted CDN content.
- The activation key is the content scope mechanism — same model as host provisioning.
  The image inherits the same content restrictions as hosts in that CV/environment.
- Images are registered back to Satellite as Compute Resource images — closing the loop
  so the SOE pipeline can provision cloud hosts from RHIS-managed images.

| Feature | Status | Notes |
|---|---|---|
| ImageBuilder node provisioning via Satellite | `implemented` | Provisions if no imagebuilder exists |
| ImageBuilder configuration (point at Satellite, add repos) | `implemented` | Uses activation key to scope content |
| Image build from AO-provided blueprint | `implemented` | |
| Target-specific image format (VHD, QCOW2, etc.) | `implemented` | |
| Cloud storage upload | `partial` | Implemented manually; automation not yet written |
| Satellite Compute Resource image registration | `partial` | Implemented manually; automation not yet written |
| Pipeline-driven deployment from registered image | `implemented` | Works once upload and registration are done |
| Pipeline test coverage (deployment_test.yml) | `designed` | Not yet written |

---

## C17 — Outbound-Only Managed Node Connectivity (Phone-Home Mesh)

**Operator need:** Manage, patch, and access service components deployed on a customer's
premises where only outbound port 443 is permitted — no inbound connections. The Organization
needs to reach its managed nodes for automation, patching, compliance, and break-glass
administration access.

**Authority:** `receptor`, `aap`, `satellite`
**Workflow type:** `mutating`
**Status:** `aspirational` — direction clear; design work needed

### Background

Red Hat Receptor (github.com/ansible/receptor) creates a mesh overlay network where
connections are outbound-initiated but become bidirectional. A receptor node behind a
customer firewall dials out on port 443 to a receptor peer at The Organization's NOC.
Once connected, the control plane can send work back through that connection without
any inbound ports. Receptor is the transport layer underlying AAP's execution node mesh
and Red Hat Cloud Connector.

### Proposed Architecture

```
Customer premises                         The Organization NOC
─────────────────                         ─────────────────────
Satellite (on-prem, manages patching)     AAP Controller
Managed service components                Receptor hop node
  └── receptor agent (quadlet) ──443──►  ◄── REX jobs, automation, admin access
```

| Feature | Status | Notes |
|---|---|---|
| Receptor agent deployment as quadlet on managed nodes | `aspirational` | |
| Receptor hop node at NOC | `aspirational` | |
| AAP execution over receptor mesh | `aspirational` | |
| Satellite on-prem patching and compliance | `aspirational` | Content sourcing model TBD — local cache or mesh-connected? |
| Automation-driven remediation and redeployment | `aspirational` | Uses existing RHIS build automation over mesh |
| Interactive SSH session via mesh | `aspirational` | Hard problem — REX covers automation; interactive terminal needs additional design |
| Web console access via mesh | `aspirational` | Cockpit tunnelled through receptor is one option |
| NOC administrator authorization workflow | `aspirational` | How admins are granted access; ties to C01 (IdM) and C02 (smart card) |

### Open Design Questions

1. **Satellite content sourcing:** Does the on-prem Satellite connect back through the
   receptor mesh to sync content, or does it use the disconnected export model (C10)?
2. **Interactive access mechanism:** Receptor handles automation traffic cleanly.
   Interactive SSH/web sessions need a separate design — options include Cockpit
   tunnelling, receptor work units for SSH proxy, or a dedicated bastion approach.
3. **Authorization model:** Who at The Organization can access which customer's nodes,
   under what conditions, with what audit trail? This is an IdM (C01) + YubiKey (C02)
   + eigenstate.ipa (C04) integration question.
4. **RHIS initial build:** If RHIS performs the initial build automation, the receptor
   agent must be deployed as part of the provisioning flow — likely a kickstart snippet
   or a post-build Ansible play via the SOE pipeline (C15).

---

## C18 — Enterprise Linux to RHEL Conversion (Convert2RHEL)

**Operator need:** Migrate existing CentOS, Oracle Linux, or other Enterprise Linux
derivative hosts to RHEL without reinstalling, preserving workloads and data. Includes
pre-conversion analysis, remediation, rollback via LVM snapshot, and post-conversion
validation.

**Authority:** `satellite`, `aap`
**Workflow type:** `mutating`
**Repo:** `rhis-builder-convert2rhel`
**Status:** `broken` — was fully implemented and working; broken by a mid-major-release
`ansible-core` update that broke EE Python/collection dependency resolution. Pipeline
structure is sound; the execution environment needs to be rebuilt with pinned requirements.

### Pipeline (AAP workflow: `c2r_pipeline`)

```
Prereqs (Satellite config)
  ↓
Pre-convert remediate
  ↓
Analyze → (always) Export report to Splunk
  ↓ (success)
Prepare LVM snapshot devices → Create snapshot → Convert → Post remediate → Post validate
  ↓ (success)                                                               ↓ (failure)
Approve commit [3hr timeout]                              Approve revert [3hr timeout]
  ├→ approved → Commit (remove snapshot) → Cleanup           ├→ approved → Revert snapshot
  └→ rejected → [END]                                         └→ rejected → [END]
```

| Feature | Status | Notes |
|---|---|---|
| Full c2r_pipeline AAP workflow | `broken` | Was working; broken by ansible-core EE dependency change |
| Pre/post conversion remediation | `broken` | Playbooks exist; EE broken |
| LVM snapshot create/revert/commit | `broken` | Pipeline structure sound |
| Splunk report export | `broken` | Always-on report regardless of analysis outcome |
| Approval gate (commit vs revert) | `broken` | 3-hour timeout, dual path |
| CentOS 7.9 → RHEL 7 | `broken` | Hostgroups and content commented out pending EE fix |
| Oracle EL 7.9 → RHEL 7 | `broken` | Same |
| CentOS 8/9 → RHEL 8/9 | `aspirational` | Pipeline reusable; content and hostgroups not yet defined |

### Restoration Path

Fix the execution environment (`rhis_ansible_ee`) with pinned collection and Python
requirements for convert2rhel automation. Re-enable the commented-out repository sets,
repositories, content views, and activation keys in the inventory template.

### Extension Path

The pipeline workflow is source-OS-agnostic in structure. Extending to CentOS 8/9
or other EL derivatives requires only: new source OS content in Satellite, new hostgroups,
and updated host definitions in `group_vars/provisioner/convert2rhel_test_hosts.yml`.
