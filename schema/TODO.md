### Schema TODO list

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

**Principle:** The rendered inventory (`inventory.j2`) is the single source of truth for host FQDNs. Variables referencing tracked infrastructure hosts must use `groups['group_name'][N]` notation — never pattern-reconstruct (`prefix.{{ _global_domain_name }}`).

**Full findings:** See `schema/audit_findings.md` Section 4.

**Summary of violations found (Category A — fix required):**

| Location | Variable | Current (wrong) | Fix |
|---|---|---|---|
| `host_vars/satellite/satellite_pre.yml:52` | `ipa_server_fqdn` | `"idm1.{{ _global_domain_name }}"` | Remove line — `group_vars/all` already correct |
| `host_vars/discosatellite/satellite_pre.yml:52` | `ipa_server_fqdn` | `"{{ groups['idm_primary'][0] }}"` | Already correct — no change |
| `group_vars/all/main.yml.j2:40` | `vm_compute_resource` | `"vcenter.{{ _global_domain_name }}"` | `"{{ groups['vmware_vcenter_hosts'][0] }}"` |
| `host_vars/satellite/compute_resources.yml.j2:55` | vcenter url | `"vcenter.{{ _global_domain_name }}"` | `"{{ groups['vmware_vcenter_hosts'][0] }}"` |
| `host_vars/discosatellite/compute_resources.yml.j2:52` | vcenter url | `"vcenter.{{ _global_domain_name }}"` | `"{{ groups['vmware_vcenter_hosts'][0] }}"` |
| `host_vars/satellite/virtwho_configs.yml:14` | `hypervisor_server` | `"vcenter.{{ _global_domain_name }}"` | `"{{ groups['vmware_vcenter_hosts'][0] }}"` |
| `host_vars/discosatellite/virtwho_configs.yml:14` | `hypervisor_server` | `"vcenter.{{ _global_domain_name }}"` | `"{{ groups['vmware_vcenter_hosts'][0] }}"` |
| `host_vars/idm/prerequisites.yml:41` | fqdn | `"provisioner.{{ _global_domain_name }}"` | `"{{ groups['provisioner'][0] }}"` |
| `host_vars/idm/prerequisites.yml:43` | fqdn | `"satellite.{{ _global_domain_name }}"` | `"{{ groups['satellite_servers'][0] }}"` |
| `host_vars/idm/hbac_policy.yml:47` | host | `"satellite.{{ _global_domain_name }}"` | `"{{ groups['satellite_servers'][0] }}"` |
| `host_vars/idm/dns_configuration.yml.j2:33` | `srv_target` | `"satellite1.{{ _global_domain_name }}."` | `"{{ groups['satellite_servers'][0] }}."` |
| `group_vars/idm_replicas/idm_pre_vars.yml:35` | fqdn | `"provisioner.{{ _global_domain_name }}"` | `"{{ groups['provisioner'][0] }}"` |
| `group_vars/idm_replicas/idm_pre_vars.yml:37` | fqdn | `"satellite1.{{ _global_domain_name }}"` | `"{{ groups['satellite_servers'][0] }}"` |
| `host_vars/discosatellite/content_exports.yml.j2:30` | `destination_server` | `"discosatellite1.{{ global_domain_name }}"` | Fix typo: `_global_domain_name` (or use groups[]) |
| `host_vars/quay1/quay.yml.j2:7` | `quay_server_hostname` | `"quay1.{{ global_domain_name }}"` | Fix typo: `_global_domain_name` |

**Pending fixes:**
- [ ] Remove `ipa_server_fqdn` override from `host_vars/satellite/satellite_pre.yml`
- [ ] Fix `vm_compute_resource` in `group_vars/all/main.yml.j2`
- [ ] Fix vcenter URL in both `compute_resources.yml.j2` files
- [ ] Fix vcenter `hypervisor_server` in both `virtwho_configs.yml` files
- [ ] Fix provisioner/satellite fqdn refs in `host_vars/idm/` and `group_vars/idm_replicas/`
- [ ] Fix `global_domain_name` typo (missing `_` prefix) in `quay.yml.j2` and `content_exports.yml.j2`
- [ ] Add naming convention rule to schema documentation

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
