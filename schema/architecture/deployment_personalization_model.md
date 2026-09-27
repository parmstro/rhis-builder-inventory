# Deployment Personalization Model

**Status:** Design agreed — implementation not started
**Related capabilities:** C05, C06, C07, C10, C15, C27
**Last updated:** 2026-09-10

---

## Problem Statement

The RHIS inventory template ships as a complete reference implementation (example.ca)
that demonstrates the full capability set. Real deployments are subsets with
environment-specific customizations. Today, customization happens by editing the
rendered deployment output. Re-rendering (to pick up template updates, add a new
SOE, or regenerate after a basevars change) destroys those edits.

Managing multiple deployments (e.g. parmstrong.ca, example.ca, highside.example.ca)
amplifies this — each re-render risks losing deployment-specific work.

The core requirement: **updates to the shipped reference must not destroy
customer customizations.**

---

## Design Model

The architecture uses three input layers that feed a rendering pipeline.
The deployment directory is output — never hand-edited.

```
Layer 1: Shipped reference (Red Hat/Community maintains)
         SOE catalog entries, reference landing zones, best-practice templates
         Updated when new RHEL versions ship, security practices change, etc.

Layer 2: Customer selections (which modules to compose)
         soe_selections.yml, landing_zone_selections.yml

Layer 3: Customer overrides (per-deployment customizations)
         CV filters, additional repos, custom products, infrastructure specifics
         Persist across re-renders because they are inputs, not edits

         --- aggregation + rendering ---

Output:  Deployment directory (generated, reproducible)
```

Re-rendering with an updated catalog produces a correct deployment that includes
both the shipped updates AND the customer's overrides.

---

## The Two Composition Domains

### Content (Satellite-managed objects)

Everything Satellite manages: repository sets, repositories, content views,
composite content views, activation keys, hostgroups, operating systems,
installation media, SCAP content/policies, custom products (including OCP
containers, EPEL, bootc, MSSQL, etc.).

Custom products are content, not infrastructure. From Satellite's perspective,
OCP container repos are just another product with repositories to sync and
manage in content views.

Content is driven by SOE catalog entries. Each entry (rhel9_base, rhel9_jboss,
ocp_420) defines the repos, CVs, AKs, and hostgroups for that SOE or content
module. The aggregation step composes selected entries into the flat files
that Satellite roles consume.

This follows the same assembly pattern used in the AAP platform_installer
configuration: individual definition files (aap_templates_soe_content_dev.yml,
etc.) are self-contained, and a list file (aap_templates_list.yml) composes
them by reference. The consuming role iterates over the composed list.

### Landing Zone (infrastructure Satellite deploys onto)

Compute resources, networks, storage, DNS — the infrastructure that hosts
deploy into. Each cloud/hypervisor provider has its own variable namespace
(vmware1_*, azure1_*, aws1_*, gcp1_*).

Landing zone variables serve double duty:
1. **Input to creation** — landing zone repos (rhis-builder-vmware, future
   rhis-builder-aws/azure/gcp) read the specification and create the objects
2. **Input to Satellite config** — compute_resources.yml and compute_profiles.yml
   reference the created objects

The rhis-builder-vmware roles (vcenter_datacenter, vcenter_networking,
vcenter_storage, vcenter_satellite_integration) already implement this pattern
for VMware. The same model extends to AWS/Azure/GCP.

Landing zone specifications are inherently per-deployment but should provide
deep enough reference samples (example.ca with private networks, standardized
names, addressing) that someone can stand up a demo or POC without significant
architectural work. This is the "Northwind" model — a complete, tested,
working reference that demonstrates all the integration points.

---

## Layer Details

### Layer 1 — Shipped Reference

What Red Hat/Community maintains in the repository:

- `soe_catalog/` — SOE entry definitions (rhel9_base.yml, rhel9_jboss.yml, etc.)
- `inventory_template/` — reference infrastructure configuration for example.ca
  (DNS records, compute resources, subnets, provisioning templates, etc.)
- `.j2` templates — structural glue that wires basevars scalars into output files
- `soe_catalog_schema.yml` — schema and vocabulary for catalog entries

This layer is version-controlled and updated when:
- New RHEL versions ship (new catalog entries)
- Security practices change (template updates)
- New capabilities are added (new provisioning templates, SCAP profiles)
- Best practices evolve (compute profile changes, hostgroup restructuring)

### Layer 2 — Customer Selections

Render-time inputs that live alongside basevars (per-deployment, gitignored):

- `soe_selections.yml` — which SOE entries to include
  (e.g. rhel9_base + rhel9_jboss + ocp_420)
- Eventually `landing_zone_selections.yml` — which landing zones to include
  (e.g. vmware_lab + azure_eastus2)

The aggregation step reads the selected catalog entries and composes the
flat variable files. Adding a new SOE to a deployment means adding one
entry to the selection file and re-rendering.

### Layer 3 — Customer Overrides

Per-deployment customizations that persist across re-renders:

**Content overrides:**
- Add content view filters (date filters, package filters)
- Add custom products not in the standard catalog
- Extend CV repository lists
- Modify activation key parameters
- Create new SOE combinations

**Infrastructure overrides:**
- DNS records for actual hardware
- Compute resource connection parameters
- Network topology (subnets, VLANs)
- Discovery rules
- VirtWho configurations

Override files are inputs to the rendering pipeline, not post-generation edits.
They live alongside basevars and selections, not inside the deployment directory.

---

## Precedence

Clear, unambiguous precedence:

```
Customer override > Composed from selections > Shipped default
```

---

## Override Granularity

Three types of override operations are needed:

1. **Replace** — substitute the shipped/composed value entirely
   (e.g. DNS records: customer's records replace example.ca's records)

2. **Extend** — add items to a composed list
   (e.g. add a custom product to the custom_products list)

3. **Modify** — change properties of a composed item
   (e.g. add a date filter to an existing content view)

The mechanism must support all three without relying on YAML deep merge,
which has undefined list semantics.

---

## Design Constraints

1. **Overrides are inputs, not post-generation edits.** They live alongside
   basevars, not inside the deployment directory.

2. **Clear precedence: override > composed > shipped default.** No ambiguity
   about what wins.

3. **Content and infrastructure remain separate namespaces.** Different
   composition domains, different aggregation concerns.

4. **The reference must work with zero overrides.** example.ca with no
   customer overrides must deploy cleanly from shipped defaults alone.
   This is the integration test baseline.

5. **Override granularity matters.** Replace, extend, and modify operations
   all needed. No deep merge.

6. **Landing zone variables are self-contained per provider.** vmware1_*,
   azure1_*, aws1_* prefixes. No cross-provider dependencies. Each
   provider block is a potential future catalog entry.

7. **Templates consume variables, not contain structural data.** Templates
   iterate over variables; the data comes from composition + overrides.

8. **Selection inputs live alongside basevars.** soe_selections.yml and
   landing_zone_selections.yml are render-time inputs with the same
   lifecycle as basevars — not runtime Ansible variables.

---

## Relationship to Existing Architecture

### SOE Selection Model (soe_selection_model.md)

The personalization model implements Approach B (SOE profile modules) from
the SOE selection model, using the existing catalog entries as the modules.
The aggregation step is the missing component that composes selected entries
into flat deployment files.

### Disconnected Deployment Model

SOE selections are the authoritative statement of what belongs in the
transfer bundle. The export scope derives from the same selections that
drive the deployment configuration.

### AAP Platform Installer Pattern

The list-of-references assembly pattern (aap_templates_list.yml →
individual definition files → role iterates over composed list) is the
same pattern used for SOE content aggregation.

### Landing Zone Repos

rhis-builder-vmware already implements the creation side. The landing zone
specification variables are the shared contract between the creation
automation and the Satellite configuration.

---

## Future Compatibility

This design preserves the path to:

- **Landing zone catalog** — landing zone specifications become selectable
  catalog entries, same model as SOE entries
- **Automated infrastructure creation** — rhis-builder-aws/azure/gcp repos
  consume landing zone specifications to create cloud objects
- **UI management of overrides** — UI manages selections today, adds
  override management in a future phase
- **Automated aggregation** — manual composition now, automated engine later
- **Collection packaging** — ELISE/RHIS Ansible collection can include
  catalog entries and aggregation logic

---

## Open Questions

1. **Override file format and location.** Per-deployment override files
   alongside basevars? A structured directory? How are replace vs extend
   vs modify operations expressed?

2. **Aggregation engine design.** Inside inventory_update.yml as tasks?
   A separate playbook? A Python script? Must be runnable inside the
   provisioner container.

3. **AAP pipeline templates.** The platform_installer job templates
   (Dev1PublishContent, etc.) hardcode CV names. Should pipeline
   configuration also be generated from SOE selections?

4. **Custom content catalog entries.** Does OCP get type: layered
   (with no requires)? A new type: custom? How does it interact with
   the selection/dependency model?

5. **Migration path for existing deployments.** How do parmstrong.ca,
   example.ca, and highside.example.ca adopt this model without losing
   current customizations?

6. **POC minimum viable scope.** What is the smallest SOE selection +
   landing zone that still demonstrates RHIS value? rhel9_base on KVM
   with IdM + Satellite only (no AAP)? Or does the POC need the full
   stack to be meaningful?

7. **CI validation infrastructure.** RESOLVED — each environment can
   host CI/CD. Real Satellite integration tests are available per
   profile tier, not just structural validation.

8. **Profile format.** Are profiles standalone files that bundle
   basevars + selections + overrides, or are they a directory
   containing separate files for each input type?

---

## Testability and Deployment Profiles

### The three concerns

The same codebase serves three audiences with different requirements:

1. **Internal dev/test** — full capability, all SOEs, all landing zones.
   Contains deployment-specific artifacts (real IPs, MAC addresses,
   VMware resource names, hardware hostnames). May be broken at any
   given commit. Must not be published.

2. **Shipped reference** — the "Northwind" implementation (example.ca).
   Complete enough to demonstrate all integration points. Stable at
   each release, fully documented, no deployment-specific artifacts.
   What people study and learn from.

3. **Minimal POC** — the on-ramp for new users. Single landing zone
   (KVM for on-premise, Azure for public cloud), single SOE
   (rhel9_base), minimal infrastructure. Must work out of the box — a
   broken POC loses the user immediately.

### Deployment profiles

A deployment profile is a predefined set of Layer 2 (selections) +
Layer 3 (overrides) that produces a tested, working deployment for a
specific audience and infrastructure target.

```
profiles/
  dev_full_vmware.yml       # internal: all SOEs, VMware landing zone
  reference_example.yml     # shipped: broad SOEs, VMware landing zone
  poc_kvm.yml               # minimal: rhel9_base, KVM landing zone
  poc_azure.yml             # minimal: rhel9_base, Azure landing zone
```

Each profile bundles:
- SOE selections (which catalog entries to compose)
- Landing zone selection (which infrastructure target)
- Override values appropriate for that configuration level
- Test assertions (what "works" means for this profile)

Dev profiles are gitignored — they contain deployment-specific values.
POC and reference profiles are shipped and version-controlled.

### Profile tiers and testing

Each profile tier defines its own validation scope:

**Minimal POC (poc_kvm, poc_azure):**
- Renders without error
- Produced YAML is structurally valid
- All referenced catalog entries exist and pass dependency checks
- Satellite roles complete without error against a real instance
- Smoke test: provision one VM from the SOE, verify it boots and
  registers

**Shipped reference (reference_example):**
- Everything in Minimal POC
- All SOE content syncs, publishes, and promotes through lifecycle
- Full pipeline test: Dev publish → promote → deploy test hosts →
  build applications → QA promote
- Disconnected export/import workflow completes
- Cross-file consistency: every CV referenced by an AK exists, every
  repo referenced by a CV is enabled, every hostgroup references a
  valid AK and OS definition

**Internal dev/test (dev_full_vmware):**
- Everything in Shipped reference
- Additional landing zone validation (VMware compute resources,
  profiles, network connectivity)
- Hardware-specific tests (discovery, kexec, baremetal provisioning)
- Multi-chassis topology validation

### CI/CD infrastructure

Each environment (production demo, dev lowside, dev highside) can host
CI/CD pipelines. This means profile validation is not limited to
structural checks — real Satellite integration tests can run per
profile tier:

- **POC profiles** validated on KVM or Azure with a real Satellite
  instance in CI. No VMware dependency.
- **Reference profiles** validated on VMware in the dev lowside
  environment.
- **Disconnected profiles** validated end-to-end (export + import)
  using the dev lowside → dev highside pair.

The test matrix maps profiles to environments: POC profiles run
in any environment with KVM or cloud access. Reference profiles
run in VMware-equipped environments. Disconnected profiles require
the paired lowside/highside topology.

### Lab topology reference

Each of the three environments follows the same physical pattern:

```
3x independent NUC (64GB RAM, 4TB NVMe, 4 cores)
   — infrastructure hosts (Satellite, IdM, AAP, provisioner)
14x NUC compute chassis (32GB RAM, 256GB NVMe, 4 cores each)
   — 7 nodes configured as a VMware vSphere 8 cluster
   — 7 nodes available for KVM cluster or baremetal
     (NAS volume for shared storage enables live migration)
   — internal 16-port unmanaged switch
1x external NAS (16TB storage, 2TB write cache)
   — 2 datastores: 1 for vCenter Server, 1 for VMs (1.6TB)
1x external 16-port managed switch
   — network fabric
         ↓
OPNsense router interconnects all three environments
```

A minimal POC collapses this entire hierarchy to:

```
1x workstation or server with sufficient resources
   — KVM hypervisor, bridge network, local storage
   — all RHIS components as VMs on a single host
```

The landing zone abstraction must support both extremes without
the RHIS content layer caring which one it runs on. The same SOE
selections, the same Satellite configuration, the same content
views — only the compute resources and provisioning targets differ.

### Separation mechanism

The personalization model provides the natural separation:

- **Layer 1 (shipped)** — catalog entries, templates, reference
  infrastructure. Version-controlled, same for all users.
- **Dev-specific data** — gitignored Layer 2 + Layer 3 files for
  parmstrong.ca, example.ca, highside.example.ca. Never published.
- **POC profiles** — shipped Layer 2 + Layer 3 presets that produce
  a minimal working deployment on KVM or Azure.
- **Reference profile** — shipped Layer 2 + Layer 3 presets that
  produce the full example.ca deployment.

Dev/test configurations are just profiles that happen to be gitignored.
The same rendering pipeline produces all three tiers. The only
difference is which selections and overrides feed the pipeline.

### Landing zone considerations for POC

VMware is the overwhelming majority of on-premise hypervisor
deployments today but is rapidly losing customer base. The minimal
POC should target platforms that new users can access without
commercial licenses:

- **KVM** — available on any RHEL host, no licensing. Natural choice
  for on-premise POC. Requires a host with sufficient resources
  (CPU, memory, storage) but no additional software.
- **Azure** — accessible via pay-as-you-go, MSDN, or free tier
  credits. Natural choice for public cloud POC.
- **AWS** — alternative public cloud option. May be added as a
  second cloud POC profile.

VMware landing zone support continues for the shipped reference and
internal testing. KVM and cloud landing zone implementations are
prioritized for POC accessibility.

---

## Bootstrap Ordering and Self-Extension

The RHIS build has a strict bootstrap sequence. Landing zones, CI/CD
infrastructure, and the git server are **prerequisites** — they exist
before RHIS does.

### Phase 0 — Bootstrap infrastructure (created separately)

The bootstrap landing zone is created outside RHIS. This is whatever
platform the core services will run on: baremetal (current dev model),
VMware, KVM, Azure, AWS, GCP, OCP Virt. The CI/CD host (Gitea + runner)
also lives here — it must exist before the environment it tests.

### Phase 1 — RHIS bootstrap (CI/CD validates this)

The three core services, in strict order:
1. **IdM primary** — DNS, authentication, certificates
2. **Satellite primary** — content and provisioning services
3. **AAP** — automation workflows for the whole infrastructure

The CI/CD runner drives this phase from outside the environment
under test. It cannot use AAP because AAP is being built.

### Phase 2 — RHIS is operational (AAP takes over)

Once AAP is running, the environment is self-extending. AAP can:
- Create additional landing zones (VMware clusters, AWS VPCs,
  Azure resource groups, KVM clusters, OCP Virt instances)
- Register new landing zones as Satellite compute resources
- Provision hosts into any landing zone
- Build the "beyond" services: IdM replicas, Satellite capsules,
  container hosts (Tang, Discovery, Gitea, Quay), KVM hosts

### Phase 3+ — Self-extending

The operational RHIS environment can build anything it has a
landing zone definition for. Need a new cloud region? AAP creates
the landing zone. Need a disconnected clone? AAP builds the export
bundle. Need a dev/test instance? AAP bootstraps another environment.

### CI/CD architecture

The CI/CD infrastructure is bootstrap-level — it lives outside all
test environments but can reach them:

```
CI/CD host (independent, Phase 0 infrastructure)
  — Gitea container (git server, webhooks)
  — CI runner container (ansible-playbook capable)
  — reaches all environment provisioner nodes
         ↓
  Phase 1: drives bootstrap build, validates each step
  Phase 2: triggers AAP for post-bootstrap validation
  Reports: Slack notifications (once AAP Slack is wired)
```

The CI runner uses the same provisioner container image
(`quay.io/s4v0/centosstream10-ansible`) already used for builds.
Gitea Actions provides the workflow orchestration (GitHub Actions
syntax). The CI host can be a dedicated NUC, a VM on infrastructure
not part of any test environment, or a cloud instance.

---

## Implementation Sequence (Proposed)

1. Refactor content files to be traceable to catalog entries (content_views.yml
   as starting point)
2. Define override file format and location convention
3. Build aggregation step for content composition
4. Migrate one file end-to-end: catalog → selection → aggregation → override → render
5. Extend to remaining content files
6. Define deployment profile format and create poc_kvm profile
7. Build structural validation for profile rendering (CI-testable)
8. Address landing zone composition
9. Create poc_azure profile
10. Connect to UI
