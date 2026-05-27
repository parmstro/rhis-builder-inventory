# Standard Operating Environment Bundle Model for Red Hat Satellite

**Author:** Paul Armstrong, Senior Principal Technical Specialist, RHEL — Red Hat Canada (parmstro@redhat.com | GitHub: [@parmstro](https://github.com/parmstro))
**Date:** 2026-05-23
**Status:** Design Proposal — Draft for Community Discussion

---

## Abstract

Large-scale automated Red Hat Satellite deployments suffer from a configuration management problem: the variable files that define Standard Operating Environments (SOEs) grow to tens of thousands of lines, become brittle, and are difficult to explain, extend, or hand over to customers. This document proposes a **bundle model** — a self-contained configuration unit that groups all Satellite objects required to deliver a single SOE — and resolves the key design challenges that arise when applying this model within Satellite's existing phase-ordered execution architecture. It also proposes a convention for **priority-weighted dynamic snippet ordering** that addresses a longstanding limitation in Satellite kickstart template composition, and identifies this convention as a candidate for upstream adoption in the Foreman community.

An SOE model does not imply a single base image applied uniformly across an organisation. In practice, an organisation maintains **multiple concurrent SOEs** — one per workload class or value stream. An SOE can be thought of as the output of a value stream aligned platform team; the end-to-end capability a platform team delivers to enable a specific class of product teams with distinct content, configuration, security, and lifecycle requirements. The bundle model is designed to express each value stream's SOE as an independent, composable unit, allowing a platform team to add, modify, or retire individual SOEs without disturbing others.

This is not new.

---

## 1. Problem Statement

When working with customers in the field on Satellite-based infrastructure automation, a recurring set of problems emerges with the conventional approach to SOE configuration:

1. **Explanation cost.** A configuration file spanning thousands of lines requires significant time to explain. Customers must understand the full structure before they can identify what is relevant to their environment.

2. **Configuration cost.** Unwanted configurations must be manually commented out. Currently, there is no mechanism to select a subset of the overall configuration that matches what a customer actually needs.

3. **Debugging cost.** Controlling multiple SOEs across many interdependent files is error-prone. All changes for a given SOE need to be implement, or an error in one file can break deployment for multiple SOEs. Missed components can result in stale configurations or silent misconfigurations that do not get caught until much further down stream.

4. **Maintenance cost.** Over time, the configuration becomes brittle. As environments evolve, the manual process of keeping large flat files consistent across SOEs degrades into a fragile, institution-knowledge-dependent system. This is the kind of technical debt that we are trying to get away from.

5. **Extension cost.** There is no well-defined path for users to add new SOEs without understanding and modifying the entire configuration surface.

The goal of the bundle model is to reduce all five costs by expressing each SOE as a self-contained, composable configuration unit. This is exactly analogous to container builds, where we create the target implementation in layers.

---

## 2. Background: Standard Operating Environments in Red Hat Satellite

A Standard Operating Environment is the complete specification of an operating environment: the OS version, patch level, installed software, security configuration, and operational tooling that a class of workload requires. In Red Hat Satellite, an SOE is not a single object — it is the end result of a dependency chain spanning almost every major Satellite subsystem.

### 2.1 The SOE Dependency Chain

```
Base Content 
    └── Content Credentials
    └── Products and Repository Sets (Red Hat)
    └── Custom Products and Repositories (non-Red Hat: vendor, internal)
            │
            ▼
    [ SYNCHRONIZATION GATE ]
            │
            ▼
Realized Content
    └── Lifecycle Environments (Dev → QA → Prod promotion path)
    └── Content Views (filter and publish selected repositories)
    └── Activation Keys (bind host registration to CV + LE + subscriptions)
            │
            ▼
OS Definitions
    └── Media (OS version, kickstart repo, etc.)
    └── Partition Tables (disk layout for this SOE)
    └── Provisioning Templates (kickstart, PXE, finish scripts)
    └── OS ↔ Template Associations (post-creation binding — see §4.2)
            │
            ▼
Infrastructure Primitives (site-specific — not owned by an SOE bundle)
    └── Compute Resources (vCenter, KVM, bare-metal discovery)
    └── Compute Profiles (hardware sizing)
    └── Domains and Realms
    └── Subnets (linked to Capsule for DHCP/DNS/TFTP)
            │
            ▼
Ansible Roles (local build related implementations)
    └── Security Hardening Roles (Compliance as Code, related)
    └── SOE Specific Roles variables (defaults, overides and validators)
            │
            ▼
Hostgroups (bind all of the above into a deployable specification)
            │
            ▼
Security Policy
    └── SCAP Content (or related/future)
    └── SCAP Tailoring content
    └── SCAP Scanning Policy (Content + Tailoring + scheduling + hostgroups)
```

**Custom Products** represent non-Red Hat content: vendor repositories (Microsoft SQL Server for Linux, MongoDB, Elastic), internal RPM repositories, or third-party package mirrors. They participate in the same content view and lifecycle pipeline as Red Hat content and must be declared before the synchronization gate.

### 2.2 The Synchronization Gate

The synchronization gate is should be considered a hard architectural constraint: all content sources — Red Hat repository sets and custom products — must be fully defined and synchronized before content views can be created and published. This means the pre-sync content declaration across all SOEs in a deployment must be aggregated into a single flat list before synchronization begins. Although it is possible to define SOEs and iterate over them to synchronize incrementally, dependencies get created and order-based synchronization requirements creep into the configuration. It is not really feasible to synchronize incrementally, one SOE at a time.

### 2.3 Current rhis-builder-satellite Phase Structure

The RHIS automation for Satellite (`rhis-builder-satellite`) implements this dependency chain in three phases separated by two gates:

- **Phase 1:** Satellite prerequisites, binary installation, and definition of all content sources — credentials, Red Hat products and repository sets, custom products.
- **[Sync Gate]:** All defined products synchronised. Pulp workers handle repositories within a product concurrently; products are processed sequentially at the Ansible level.
- **Phase 2:** Content views, lifecycle environments, activation keys, OS definitions, partition tables, provisioning templates, compute resources, compute profiles, domains, realms, subnets, and hostgroups.
- **[Publication Gate]:** All content views published and promoted before host provisioning begins.
- **Phase 3:** OS-template associations (a post-creation binding), host build defaults, and provisioning readiness validation.
- **[Capsule Deployment]:** A four-step sequence coordinated via `rhis-provisioner-container` helper scripts — Capsule hosts are provisioned with Base OS via Satellite; Satellite generates and distributes TLS certificates to each Capsule host; Capsule software is installed; Satellite is updated with Capsule organisation/location assignments, trusted host reconfiguration, and content synchronisation initiation.
- **Phase 4 (not yet implemented):** Capsule-dependent Satellite objects — subnets referencing a Capsule for DHCP/DNS/TFTP smart proxy services — belong here but currently have no implementation home in `rhis-builder-satellite`.

---

## 3. The Bundle Model Proposal

### 3.1 Core Concept

A bundle is a named YAML object that declares everything Satellite needs to deliver one SOE. The bundle is the configuration surface; execution remains flat and phase-ordered as today.
(Simplified Sample)

```yaml
soe_bundles:
  - name: "RHEL 9 JBoss EAP"
    content:
      repository_sets:
        - product: "Red Hat Enterprise Linux for x86_64"
          basearch: "x86_64"
          releasever: "9"
          name: "Red Hat Enterprise Linux 9 for x86_64 - BaseOS (RPMs)"
        - product: "JBoss Enterprise Application Platform"
          name: "JBoss Enterprise Application Platform 7.4 RHEL 9 (RPMs)"
      custom_products:
        - name: "Internal Middleware Repo"
          url: "https://repo.internal.example.com/middleware/el9/"
      content_views:
        - name: "cv_rhel9_jboss"
          repositories: [...]
    templates:
      provisioning_templates:
        - name: "RHEL 9 JBoss Kickstart"
          template_kind: "provision"
      partition_tables:
        - name: "RHEL 9 JBoss Partitions"
      snippets:
        - priority: 200
          name: "subscription_manager_registration"
        - priority: 210
          name: "freeipa_register"
        - priority: 600
          name: "rhis_jboss_packages"
        - priority: 700
          name: "rhis_jboss_config"
    lifecycle:
      lifecycle_environments:
        - name: "JBoss-Dev"
        - name: "JBoss-QA"
        - name: "JBoss-Prod"
      activation_keys:
        - name: "ak_rhel9_jboss_dev"
          lifecycle_environment: "JBoss-Dev"
          content_view: "cv_rhel9_jboss"
      hostgroups:
        - name: "RHEL9/JBoss/Dev"
          activation_key: "ak_rhel9_jboss_dev"
          compute_resource_ref: "vcenter.example.com"
          subnet_ref: "provision.example.com"
    infrastructure_refs:
      compute_resource: "vcenter.example.com"
      subnet: "provision.example.com"
      domain: "example.com"
      realm: "EXAMPLE.COM"
```

### 3.2 Aggregation to Flat Execution Lists

When the deployment inventory is rendered in rhis-builder-inventory, an aggregation step walks all declared bundles and merges each section into the corresponding flat list consumed by the existing phase structure making use of defined configuration content:

- `content:` sections merge into pre-sync flat lists (repository sets, custom products, content views)
- `templates:` sections merge into Phase 2 flat lists
- `lifecycle:` sections merge into Phase 2/3 flat lists
- `infrastructure_refs:` are assertions only — validated against existing site infrastructure, not created by the bundle

Duplicate objects (e.g. the same repository set declared by two bundles) are deduplicated at merge time. The existing phase-ordered execution code consumes these flat lists unchanged. The bundle model is purely a configuration surface; no changes to the Satellite play execution are required. This preserves the value that exists in the current mass of configuration code and eases composability.

### 3.3 Infrastructure as a Separate Concern

Compute resources, subnets, domains, realms, and Capsule assignments are site-specific infrastructure primitives. They are not owned by any SOE bundle — they exist before bundles are applied and are referenced by bundles via `infrastructure_refs`. This distinction is important: bundles declare what infrastructure they *require*, not what they *create*. The aggregation step validates that all satellite objects are defined and referenced infrastructure objects exist before SOE bundle objects are created.

---

## 4. Key Design Challenges

### 4.1 The Pre-Sync Content Constraint

Because synchronization is a global gate, all content sources across all selected bundles must be aggregated into a single flat list before sync begins. A bundle cannot declare "sync my repositories, then build my content view" independently — it participates in a shared sync operation with all other bundles. The aggregation step handles this by collecting all `content:` sections into a unified pre-sync list. This is not a limitation of the bundle model; it reflects a genuine architectural constraint of ensuring a valid set of SOEs.

### 4.2 The OS ↔ Template Post-Creation Binding

OS definitions and provisioning templates must both exist before they can be associated. This association is a Phase 3 operation — it cannot be done during Phase 2 when the objects are created. Bundles declare their OS-template bindings as a separate `os_template_bindings:` list, which the aggregation step collects and executes in Phase 3. This maps directly onto the existing phase structure.

### 4.3 Cross-Project and Capsule Dependencies

Capsule deployment is coordinated across `rhis-builder-satellite` and `rhis-provisioner-container`: Capsule hosts are first provisioned with Base OS via Satellite, then Satellite generates and distributes TLS certificates to each host, then Capsule software is installed on the hosts, and finally Satellite is updated with Capsule organisation/location assignments, trusted host reconfiguration, and content synchronisation. Satellite-side preparation must bracket the on-host installation — the certificate distribution step must precede it and the Satellite reconfiguration step must follow it.

Subnets that reference a Capsule for DHCP/DNS/TFTP smart proxy services cannot be configured until the full sequence completes. These belong in Phase 4 (§2.3), which is currently an identified gap with no implementation in `rhis-builder-satellite`. The bundle model should treat Capsule-dependent subnet refs as a distinct class, validated and applied only after Capsule deployment rather than at initial aggregation time.

**Multi-site deployments** escalate this further. A remote Capsule may require a local IdM replica and a distinct Satellite realm object before it can enroll hosts — both of which have their own deployment prerequisites. The full ordering becomes: central Satellite (Phases 1–3) → remote IdM replicas → Capsule deployment → Capsule-dependent Satellite objects. This cross-project chain cannot be abstracted within the bundle model alone; it requires explicit operator-level sequencing. The bundle model should represent remote-site infrastructure as a distinct `remote_site_refs:` section validated only after the full chain for that site completes.

---

## 5. Kickstart Snippet Ordering

Kickstart snippet composition is a dependency of the bundle model's `templates:` section but is a sufficiently self-contained problem to warrant its own RFC. The chosen approach — a priority-weighted host parameter (`foreman_extra_snippets`) that drives dynamic snippet inclusion and ordering via a single ERB block in the base template — is documented separately and is independently adoptable without the full bundle model.

> **See:** [RFC: Priority-Weighted Kickstart Snippet Ordering for Foreman/Satellite](soe_snippet_ordering_rfc.md)
> **Discussion:** [GitHub Discussion #29](https://github.com/parmstro/rhis-builder-inventory/discussions/29)

Within the bundle model, each bundle declares its snippet set as a list of `priority:name` pairs in the `templates:` section. The aggregation step merges these lists across all active bundles, sorts by priority, deduplicates, and writes the result to the hostgroup parameter before any Satellite play runs.

---

## 6. Community Proposal

The bundle model is an inventory-level pattern that does not require changes to Foreman or Satellite core. It is implementable today within the RHIS automation layer as an aggregation step in `inventory_update.yml`. The value is in the configuration surface — self-contained, composable SOE declarations that are easier to explain, configure, debug, maintain, and extend than monolithic flat variable files.

Community engagement is sought on two questions:

1. **Does the bundle declaration structure map cleanly onto real-world SOE definitions?** The model as proposed covers the full Satellite dependency chain. Feedback from practitioners managing large or complex Satellite deployments — particularly around Custom Products, multi-site Capsule topologies, and security policy integration — is especially valued.

2. **Should the aggregation model be standardised across Satellite automation projects?** If the bundle model gains traction, a common bundle schema would allow SOE definitions to be portable between automation frameworks. This is a longer-term consideration.

The companion [snippet ordering RFC](soe_snippet_ordering_rfc.md) is a separate, narrower proposal aimed at the Foreman community and is independently evaluable.

Community discussion is open at [GitHub Discussion #28](https://github.com/parmstro/rhis-builder-inventory/discussions/28).

---

## 7. Summary of Design Decisions

| Decision | Chosen Approach | Rationale |
|---|---|---|
| Bundle execution model | Flat phase-ordered lists aggregated from bundles | Preserves existing phase gates; natural deduplication of shared objects; existing tag system maps perfectly |
| Pre-sync content | All bundles aggregate to a single flat pre-sync list | Pulp sync is a global gate; incremental per-bundle sync creates ordering dependencies |
| Snippet ordering | Companion RFC — priority-weighted `foreman_extra_snippets` parameter | Separable concern; independently adoptable; see [soe_snippet_ordering_rfc.md](soe_snippet_ordering_rfc.md) |
| Infrastructure refs | Site primitives are refs, not bundle-owned | Compute resources, subnets, domains, Capsules are prerequisites; bundles declare requirements, not creation |
| Capsule-dependent refs | Validated post-Capsule deployment, not at aggregation time | Subnets with smart proxy assignments require a registered Capsule |
| OS↔Template binding | Declared as a separate Phase 3 list | Both objects must exist before association; maps onto existing phase structure |

---

## 8. Next Steps

1. Gather community feedback via [GitHub Discussion #28](https://github.com/parmstro/rhis-builder-inventory/discussions/28).
2. Implement the aggregation step in the RHIS inventory layer (`inventory_update.yml`) to merge bundle declarations into flat execution lists.
3. Define the Phase 4 implementation in `rhis-builder-satellite` for Capsule-dependent Satellite objects.
4. Evaluate bundle schema standardisation if community adoption warrants it.
