### Schema TODO list

#### Add `Red Hat Enterprise Linux Bootc Containers` to repositories.yml

The custom product `Red Hat Enterprise Linux Bootc Containers` (formerly `rhel9_containers`, label: `rh_rhel9_bootc_containers`) is defined in `custom_products.yml` with a Docker content repository (`rhel9/rhel-bootc` from `registry.redhat.io`) but has no corresponding entry in `repositories.yml`. An entry should be added when the repositories file is next reorganized or when the product is activated for use.

---

#### Rename global parameter `host_packages` → `additional-packages`

In `inventory_template/host_vars/satellite/global_parameters.yml.j2` line 102, the global parameter `host_packages` should be renamed to `additional-packages` to match the expected parameter name used by downstream consumers (confirmed with Bryn).

**Action:** Update the `name:` field from `"host_packages"` to `"additional-packages"` in `global_parameters.yml.j2`. Rebuild inventory and re-run the `global_parameters` role to apply the rename in Satellite. Verify downstream consumers (kickstart snippets, host build templates) reference the correct name.

---

#### Ephemeral Diagnostic Container Model

**Concept:** Rather than including powerful diagnostic tools (nmap, wireshark, tcpdump, strace, etc.) in the SOE content views — which broadens the attack surface and complicates compliance scans — deliver them as ephemeral containers stored in Satellite's container registry. Operators deploy the container when needed, run the tools, then destroy it. The image is also removed after the session.

**Benefits:**
1. **Compliance** — SOE hosts carry no diagnostic tools. Scans are clean by design, not by manual cleanup.
2. **InfoSec** — Reduced attack surface. Powerful tools are not persistently available on any host.
3. **Operations** — Engineers still have access to everything they need, on demand.
4. **Release Engineering** — Simpler package management; the exclusion list in the content view filter is a formal, versioned audit artifact.

**Proposed models:**

*Two-container model (simpler — maps directly to role separation):*

| Container | Capabilities | Tools | Approval | TTL |
|---|---|---|---|---|
| `rhis-diagnostic-operator` | `CAP_NET_RAW`, `--network host` | ping, traceroute, nmap (basic), curl, dig, ss, iperf | Team lead | 2 hours |
| `rhis-diagnostic-elevated` | + `CAP_SYS_PTRACE`, `--pid host`, optional filesystem mounts | + tcpdump, tshark, strace, lsof, gdb | Security officer | 1 hour |

*Three-tier model (alternative — one size does not fit all):*

| Tier | Capabilities | Tools | Approval |
|---|---|---|---|
| 1 — Observer | `CAP_NET_RAW`, `--network host` | ping, nmap, traceroute | Team lead |
| 2 — Inspector | + `CAP_SYS_PTRACE`, `--pid host` | + strace, lsof, ss | Security officer |
| 3 — Full | Tier 1+2 + filesystem mounts | Everything | Security officer + CISO |

**Capability concerns:**
- `--network host` + `CAP_NET_RAW` → can capture ALL host traffic including decrypted application traffic
- `--pid host` + `CAP_SYS_PTRACE` → can attach to any host process and read its memory (including vault credential holders)
- Filesystem mounts (even `--read-only`) → exposes private keys, vault files, application configs
- Higher tiers may warrant an ephemeral VM instead of a container for stronger isolation guarantees

**Mitigations (all tiers):**
- `--read-only` container filesystem
- `--security-opt no-new-privileges`
- Custom seccomp profile
- SELinux confined container type
- Auto-destroy TTL enforced by AAP job
- Signed images — provenance verifiable from Satellite
- Command-level audit logging inside container
- Session generates audit report on destruction

**RHIS integration:**
- Both images built from a dedicated content view (`SOE9_Diagnostics`) — the only CV allowed to contain restricted packages, never promoted to managed hosts, feeds container registry only
- Both stored in Satellite container registry — no external registry dependency
- IdM groups control access: `grp-diagnostic-operator`, `grp-diagnostic-elevated`
- AAP Job Templates handle deploy/destroy workflow with approval gates
- HBAC in IdM gates who can trigger which AAP job

**Implementation scope:** rhis-builder-satellite (container registry, content view), rhis-builder-aap (job templates, approval workflow), rhis-builder-inventory (activation keys, content view filter exclusions).

---

#### Deprecation Tagging Model for Satellite Configuration Entries

Satellite configuration files (`content_views.yml`, `sync_plan_product_map.yml`, `repositories.yml`, `repository_sets.yml`, `activation_keys.yml`, `hostgroups.yml`, etc.) contain entries for OS versions and products that are periodically deprecated (RHEL 7, ELS, OEL, legacy AAP versions, etc.). Currently deprecation is handled by commenting entries out manually, which:

1. Is invisible to tooling — grep cannot distinguish "commented for deprecation" from "commented for debugging"
2. Is fragile under `git checkout` — manual deprecation work is easily wiped
3. Provides no audit trail — no record of when or why something was deprecated

**Proposed solution: structured YAML state field (`rhis_lifecycle`)**

Add an optional `rhis_lifecycle` field to list entries in all satellite configuration files:

```yaml
content_views:
  - name: "SOE7"
    rhis_lifecycle: "deprecated"        # active (default) | deprecated | experimental
    rhis_deprecated_since: "2026-06-01"
    rhis_deprecated_reason: "RHEL 7 EOL — transitioning all workloads to RHEL 8+"
    desc: "RHEL 7 Standard Operating Environment Content"
    ...
```

**Implementation requirements:**

- Each consuming role (`content_views`, `sync_plans`, `repositories`, `activation_keys`, etc.) in rhis-builder-satellite gains a pre-filter task that removes `rhis_lifecycle: "deprecated"` entries before processing the list
- Default behaviour when `rhis_lifecycle` is absent: treat as `active`
- `experimental` entries are processed but flagged in output
- A schema linting script in `schema/scripts/` can report all deprecated entries across all files

**Benefits:**
- Deprecated entries remain visible in the file with context (why, when)
- `git checkout` cannot silently erase deprecation state
- Queryable: `grep -r "rhis_lifecycle: deprecated"` gives a full deprecation inventory
- Enables future automation: a script could remove entries deprecated > N months ago

**Scope:** rhis-builder-satellite roles + all `inventory_template/host_vars/satellite/` configuration files. Coordinate with rhis-builder-satellite maintainer before implementing role changes.

**Known candidates for `rhis_lifecycle: "deprecated"` tagging:**

| Entry | Files | Reason |
|---|---|---|
| RHEL 7 / ELS / OEL79 content views, repos, activation keys | `content_views.yml`, `repositories.yml`, `repository_sets.yml`, `activation_keys.yml`, `hostgroups.yml` | RHEL 7 EOL — transitioning all workloads to RHEL 8+ |
| `Red Hat Ansible Engine` sync plan product | `sync_plan_product_map.yml` | Replaced by AAP; product is deprecated |
| `Red Hat Enterprise Linux Server` sync plan product | `sync_plan_product_map.yml` | Legacy RHEL 7 product; disabled in current manifests |
| `Red Hat Satellite 6 Client 2` repos | `content_views.yml`, `repositories.yml` | Red Hat announced these repos but never shipped content to them; they are permanently empty and safe to remove |

---

#### Static IP Address Assignment — Cross-Project Brittleness (HIGH PRIORITY)

The current approach to static IP address assignment is fragile and inconsistent across rhis-builder projects. Failures surface at build time as silent wrong-address bugs that are difficult to trace.

**Known failure points identified during example.ca build (2026-05-29):**

1. **`bootstrap_init` vs `inventory_template` mismatch** — `bootstrap_init` embeds nameserver IPs in kickstart files at provisioning time. When the static IP allocation changes (e.g. IdM moved from `.5`/`.6` to `.10`/`.11`), freshly-provisioned hosts boot with wrong nameservers and can't resolve the CDN or IdM, causing downstream builds to fail.

2. **`ipa_client_dns_servers` override in `satellite_pre.yml`** — hardcoded as `"{{ _default_network }}.5"` which silently overrides the correct value (`192.168.140.10` via `ansible.utils.next_nth_usable(10)`) already set in `group_vars/all/main.yml`. Host_vars always wins, so the group_vars fix is invisible. Removed the override (see commit), but the root cause is the pattern of hardcoding ordinal positions.

3. **`.5`/`.6` vs `next_nth_usable(5)`/`next_nth_usable(6)` inconsistency** — some files use `_default_network` + literal offset, others use `ansible.utils.next_nth_usable`. These give the same result on /24 but diverge on other prefix lengths (see network rework item below).

**Root cause:** There is no single authoritative source for "IdM primary is at position X on the network." Each project inlines its own assumption. When the assumption changes in one place, all others are silently wrong.

**Required fix:**
- Define a small set of named network position variables in `inventory_basevars.yml` (e.g. `rhis_idm_primary_position: 10`, `rhis_idm_replica_position: 11`) and derive IPs from them consistently everywhere using `ansible.utils.next_nth_usable`.
- Update `bootstrap_init` to read these positions from the basevars rather than embedding literal IPs in kickstart templates.
- Remove all host_vars overrides of `ipa_client_dns_servers` — let `group_vars/all/main.yml.j2` be the single source of truth.
- This is a cross-project change: `rhis-builder-inventory`, `rhis-builder-idm`, `rhis-builder-satellite`, `rhis-builder-kvm`, `rhis-builder-baremetal-init` all need updating.

---

#### Network address variable rework (group_vars/all/main.yml.j2)

The current `_default_network`, assigned address, and default gateway derivation logic works correctly only for /24 address spaces where the host portion begins in the last octet. It fails in the general case where the host address starts in an earlier octet (e.g. /16, /8, or non-octet-aligned prefix lengths), leading to incorrect gateway assignments and failed network communications. A general rework is required to handle arbitrary CIDR prefix lengths correctly.

**Note on `_default_bond_default_gateway`:** The use of `_default_network` (provision network prefix) rather than `_default_bond_network` for the bond gateway is an intentional workaround, not a bug. The bond interface address range is coincident with the provision network — both reside within the same physical subnet and share the same gateway. The workaround holds for the current /24-aligned topology but will need to be revisited as part of the general rework. When the rework is done, the shared-gateway assumption should be made explicit either through a dedicated `default_gateway` variable or a comment in the template.

**Known static IP allocation (provision network, /24-aligned):**
- `.1` — default gateway
- `.5` — IdM primary (DNS primary)
- `.6` — IdM replica (DNS secondary)
- `.12` — Satellite server (also serves as PXE server via `--foreman-proxy-dhcp-pxeserver`)
- `.13` — provisioner host (rhis-builder Ansible control node)
- `.14` — AAP controller
- `.15` — AAP Hub
- `.41–.47` — KVM hypervisors
- `.71–.72` — Quadlet hosts
- `.81` — Satellite capsule
- `.100–.254` — DHCP pool (bare-metal discovery / dynamic assignment)

**Additional computed variables needed as part of this rework:**

- `_idm_primary_ip` — compute as `target_net_cidr | ansible.utils.next_nth_usable(5)` in `main.yml.j2`. Set `ipa_client_dns_servers: "{{ _idm_primary_ip }}"` globally. Remove the `ipa_client_dns_servers: "{{ _default_network }}.5"` overrides from `host_vars/satellite/satellite_pre.yml` and `host_vars/discosatellite/satellite_pre.yml` — these exist only because the global value currently points to the wrong host (position 10, unallocated). User can override `_idm_primary_ip` in basevars if IdM primary is at a non-standard position.

- `_default_reverse_zone` — compute in `main.yml.j2` from `default_network` (split into octets) and `default_network_prefix` (to select the appropriate octet depth): `/8` or less → 1-octet zone, `/9`–`/16` → 2-octet zone, `/17`–`/24` → 3-octet zone. For non-octet-aligned prefixes (e.g. /22) use the next coarser octet boundary to avoid RFC 2317 classless delegation complexity. Replace the hardcoded `ipa_dns_reverse_zone: "168.192.in-addr.arpa"` in both satellite_pre files with `ipa_dns_reverse_zone: "{{ _default_reverse_zone }}"`.

**Recommended rework approach (hybrid):**

1. Add `default_network_cidr` to `inventory_basevars.yml` as a full CIDR string (e.g. `"192.168.1.0/24"`). Derive `_default_network_cidr` and `_default_bond_network_cidr` in `main.yml.j2` from the user-supplied values.
2. Define `target_net_cidr` in `inventory_basevars.yml` (or derive it in `main.yml.j2`). This variable is already consumed by `ansible.utils.next_nth_usable` throughout the templates but is currently not defined in `inventory_template`.
3. Replace all `{{ _default_network }}.X` patterns with `{{ _default_network_cidr | ansible.utils.nthhost(X) }}` throughout the ~40 affected template files.
4. Replace all `{{ _default_bond_network }}.X` patterns with `{{ _default_bond_network_cidr | ansible.utils.nthhost(X) }}`.
5. For the default gateway, use `ansible.utils.nthhost(_default_network_cidr, 1)` or introduce a dedicated `default_gateway` variable supplied by the user — making the shared-gateway assumption explicit rather than implicit.
6. Verify that `ansible.utils` collection is available in all execution environments that render these templates.

This approach preserves human readability, handles arbitrary prefix lengths correctly, and requires only an additive change to `inventory_basevars.yml`.

---

#### SOE Bundle Model — Snippet Ordering Design Decision

When including Satellite kickstart snippets dynamically via an ERB host parameter (`rhis_extra_snippets`), snippets must execute in a defined order. The design considered two approaches:

**Option evaluated: systemd dependency graph model**
Snippets declare `After=`, `Before=`, `Requires=`, and `Wants=` relationships in a metadata block. An aggregation step builds a directed graph and performs a topological sort to determine render order. This provides the most expressive ordering contract and detects circular dependencies at aggregation time rather than at kickstart runtime.

**Rejected because:** The problem scope does not justify the complexity. Systemd's dependency graph solves ordering across hundreds of units with intricate interdependencies across a full OS boot. A SOE bundle contains a small, well-understood set of snippets with predictable phase relationships. The machinery required (metadata parsing, graph construction, Kahn's algorithm, cycle detection, target resolution) is disproportionate to the problem and would be difficult to explain to customers or for users to extend.

**Chosen approach: priority-weighted ordering with documented phase ranges**

The `rhis_extra_snippets` host parameter is a semicolon-separated list of `priority:snippet_name` pairs. The ERB block in the base template sorts by priority before rendering:

```
rhis_extra_snippets = "200:rhis_subscription;300:rhis_repos;600:rhis_jboss_packages;700:rhis_jboss_config"
```

Phase ranges (gaps allow insertion without renumbering — same reasoning as SysV init script numbering):

| Range | Phase |
|---|---|
| 100–199 | Pre-partition / disk layout |
| 200–299 | Subscription and registration |
| 300–399 | Repository configuration |
| 400–499 | Base package selection |
| 500–599 | Service and daemon configuration |
| 600–699 | Application package installation |
| 700–799 | Application configuration |
| 800–899 | Post-install hooks |
| 900–999 | Cleanup and finalization |

**Key properties:** Order is declared by the snippet author (not by list position), so adding a new snippet never requires touching existing entries. The aggregation step merges lists from multiple bundles, sorts by priority, and deduplicates. Tie-breaking within a shared priority value is alphabetical by name (deterministic). This model is explainable in two minutes and requires no tooling beyond sorting.

---

#### Disconnected Model — Export Bundle Automation

**Context:** The disconnected (air-gapped / highside) build requires a validated lowside Satellite to export its content and configuration before transfer. The Satellite server is the natural staging point because it already holds the lion's share of the data volume — avoiding an additional multi-terabyte copy step.

**Artifacts to assemble on the Satellite:**

1. **Satellite Library export** — handled by the existing `content_exports` role in rhis-builder-satellite. Chunked 2 GB `importable`-format files land in `/var/lib/pulp/exports/<destination_server>/`. Satellite's own `metadata.json` is generated via `hammer content-export generate-metadata`. A timestamped `_content_imports.yml` for the highside is written by `generate_content_imports_file.yml`. **Already implemented.**

2. **rhis-builder-inventory configuration archive** — tar.gz of the inventory tree (excluding `.git`) pushed from the provisioner to the Satellite staging directory. Small in size. Vault-encrypted vars travel with the bundle; the vault password must cross the air gap separately via a trusted channel and is explicitly documented in the bundle manifest.

3. **rhis-provisioner container image** — `podman save` on the provisioner, pushed to the Satellite staging directory. Moderate size.

4. **Compliance-as-code Ansible roles** — RedHatOfficial repos are already cloned to `/etc/ansible/roles/` on the Satellite during the connected build (defined in `imported_git_repos.yml`). At export time, each repo's HEAD SHA is captured (`git -C <dest> rev-parse HEAD`) and recorded in the bundle manifest. The roles are tarred from their on-disk location — no re-download required.

5. **Foreman discovery image** — pulled directly from the foreman-discovery upstream repo by the Satellite installer during the connected build. Already present on the Satellite filesystem (TFTP boot directory). Located and copied to the staging directory at export time.

6. **Bundle manifest** — generated on the Satellite. Records sha256 checksums of every artifact, git SHAs for each compliance-as-code role, Satellite export history ID, and a checklist of what must travel separately (vault password).

**Transfer step (separate, operator-triggered):** The `content_export_copies` role (not yet implemented) copies the fully staged bundle from `/var/lib/pulp/exports/<destination>/` to physical transfer media (`destination_folder` in `content_export_copies` host_vars). This is a distinct action from export assembly, run only when transfer is authorized.

**Implementation work required:**

- [ ] New `export_disconnected.yml` playbook in rhis-builder-satellite — orchestrates steps 2–6 above on the Satellite host; calls the existing `content_exports` role for step 1
- [ ] New `content_export_copies` role in rhis-builder-satellite — copies staged bundle to transfer media; `content_export_copies` host_vars variable already defined in `inventory_template`
- [ ] Export manifest task — walks `git_repos` list, captures HEAD SHAs, computes sha256sums, writes YAML manifest to staging directory
- [ ] New `build_sat_disconnected_export.sh` helper script in rhis-provisioner-container — wraps the playbook call; handles `podman save` and inventory tar locally then pushes both to the Satellite staging directory; follows existing `build_sat_*` naming and invocation pattern
- [ ] Highside import playbook / role verification — `content_imports` role and `discosatellite` host_vars already exist; validate the full import sequence against a test highside

---

---

#### Cross-Host FQDN Reference Audit — COMPLETE

**Principle:** The rendered inventory (`inventory.j2`) is the single source of truth for host FQDNs. Variables referencing tracked infrastructure hosts must use `groups['group_name'][N]` notation — never pattern-reconstruct (`prefix.{{ _runtime_global_domain_name }}`).

**Full findings:** See `schema/audit_findings.md` Section 4.

**Summary of violations found (Category A — fix required):**

| Location | Variable | Current (wrong) | Fix |
|---|---|---|---|
| `host_vars/satellite/satellite_pre.yml:52` | `ipa_server_fqdn` | `"idm1.{{ _runtime_global_domain_name }}"` | Remove line — `group_vars/all` already correct |
| `host_vars/discosatellite/satellite_pre.yml:52` | `ipa_server_fqdn` | `"{{ groups['idm_primary'][0] }}"` | Already correct — no change |
| `group_vars/all/main.yml.j2:40` | `vm_compute_resource` | `"vcenter.{{ _runtime_global_domain_name }}"` | `"{{ groups['vmware_vcenter_hosts'][0] }}"` |
| `host_vars/satellite/compute_resources.yml.j2:55` | vcenter url | `"vcenter.{{ _runtime_global_domain_name }}"` | `"{{ groups['vmware_vcenter_hosts'][0] }}"` |
| `host_vars/discosatellite/compute_resources.yml.j2:52` | vcenter url | `"vcenter.{{ _runtime_global_domain_name }}"` | `"{{ groups['vmware_vcenter_hosts'][0] }}"` |
| `host_vars/satellite/virtwho_configs.yml:14` | `hypervisor_server` | `"vcenter.{{ _runtime_global_domain_name }}"` | `"{{ groups['vmware_vcenter_hosts'][0] }}"` |
| `host_vars/discosatellite/virtwho_configs.yml:14` | `hypervisor_server` | `"vcenter.{{ _runtime_global_domain_name }}"` | `"{{ groups['vmware_vcenter_hosts'][0] }}"` |
| `host_vars/idm/prerequisites.yml:41` | fqdn | `"provisioner.{{ _runtime_global_domain_name }}"` | `"{{ groups['provisioner'][0] }}"` |
| `host_vars/idm/prerequisites.yml:43` | fqdn | `"satellite.{{ _runtime_global_domain_name }}"` | `"{{ groups['satellite_servers'][0] }}"` |
| `host_vars/idm/hbac_policy.yml:47` | host | `"satellite.{{ _runtime_global_domain_name }}"` | `"{{ groups['satellite_servers'][0] }}"` |
| `host_vars/idm/dns_configuration.yml.j2:33` | `srv_target` | `"satellite1.{{ _runtime_global_domain_name }}."` | `"{{ groups['satellite_servers'][0] }}."` |
| `group_vars/idm_replicas/idm_pre_vars.yml:35` | fqdn | `"provisioner.{{ _runtime_global_domain_name }}"` | `"{{ groups['provisioner'][0] }}"` |
| `group_vars/idm_replicas/idm_pre_vars.yml:37` | fqdn | `"satellite1.{{ _runtime_global_domain_name }}"` | `"{{ groups['satellite_servers'][0] }}"` |
| `host_vars/discosatellite/content_exports.yml.j2:30` | `destination_server` | `"discosatellite1.{{ basevars_global_domain_name }}"` | Fix typo: `_runtime_global_domain_name` (or use groups[]) |
| `host_vars/quay1/quay.yml.j2:7` | `quay_server_hostname` | `"quay1.{{ basevars_global_domain_name }}"` | Fix typo: `_runtime_global_domain_name` |

**Pending fixes:**
- [ ] Remove `ipa_server_fqdn` override from `host_vars/satellite/satellite_pre.yml`
- [ ] Fix `vm_compute_resource` in `group_vars/all/main.yml.j2`
- [ ] Fix vcenter URL in both `compute_resources.yml.j2` files
- [ ] Fix vcenter `hypervisor_server` in both `virtwho_configs.yml` files
- [ ] Fix provisioner/satellite fqdn refs in `host_vars/idm/` and `group_vars/idm_replicas/`
- [ ] Fix `basevars_global_domain_name` typo (missing `_` prefix) in `quay.yml.j2` and `content_exports.yml.j2`
- [ ] Add naming convention rule to schema documentation

---

#### Cloud Resource Element Naming — Unworkable Scheme

**Context:** Azure resource groups, VNets, and subnets are currently named using a
split of `basevars_global_domain_name` on `.`, producing a `element#_<part0>_<part1>`
scheme (e.g., `rg1_savage_test` for domain `savage.test`). This is implemented via
`split_basevars_global_domain_name` computed in `inventory_update.yml` and consumed in:

- `host_vars/satellite/compute_resources.yml.j2`
- `host_vars/discosatellite/compute_resources.yml.j2`
- `host_vars/aapcontroller24/platform_post.yml.j2`
- `host_vars/aapcontroller26/platform_post.yml.j2`
- `host_vars/aaphub24/platform_post.yml.j2`
- `host_vars/aaphub26/platform_post.yml.j2`
- `group_vars/provisioner/testyubiuser.yml.j2`

**Why it is unworkable:**
1. Assumes exactly two domain parts. Domains with more components (e.g., `lab.example.ca`)
   produce wrong resource names — `rg1_lab_example` instead of something meaningful.
2. Resource group names must be stable — if the domain name ever changes, Azure resources
   become orphaned (Satellite loses the compute resource reference, existing VMs are
   unmanaged).
3. The scheme encodes no environment or subscription context, so multi-subscription or
   multi-region deployments produce name collisions.
4. Azure naming constraints (length, allowed characters) are not enforced.

**Recommended fix (future):**
Introduce explicit basevars variables for cloud resource naming that are independent of
the domain name:

```yaml
rhis_azure_resource_prefix: "rg1"       # or customer/env abbreviation
rhis_azure_environment_tag: "lab"       # used consistently across resource names
```

Use these to construct resource names deterministically without relying on domain splitting.
This also allows the same inventory to target different Azure subscriptions or regions
without naming collisions.

**Current state:** The `split_basevars_global_domain_name[0]` / `[1]` scheme is retained
as-is for sample deployments. Do not build production landing zones on this scheme.

---

Document Ansible modules and versions
Document rhis-builder internal configuration variables and allowable values
  - names
  - aliases
  - required/optional and conditions
  - defaults
  - dependencies
  - descriptions
  - function
