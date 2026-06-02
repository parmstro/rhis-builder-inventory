# Variable Audit Findings — All rhis-builder Projects

Audit date: 2026-05-26
Scope: rhis-builder-satellite, idm, kvm, aap, day-2-ops, nbde, quadlet-deploy, baremetal-init, rhis-provisioner-container, plus inventory_template

---

## Scanner Limitation Note

The grep-based scanner has two known blind spots:

**1. Bare Jinja2 conditions** — Variables used in `when:`, `failed_when:`, or `until:` without `{{ }}` delimiters (e.g., `when: crt_force_regen`, `when: cockpit_all`) are not detected as USED. All "false positive dead defaults" are annotated below.

**2. Extra-vars dispatch pattern** — Several rhis-builder projects use a shell-script dispatch pattern where a generic playbook variable is assigned a named inventory list at invocation time:

```bash
--extra-vars "platform_hosts={{ capsule_hosts }}"
--extra-vars "bootstrap_init_hosts={{ idm_bootstrap_init_hosts }}"
```

The scanner detects the LHS generic variable (`platform_hosts`, `bootstrap_init_hosts`) from the `"var=` shell script grep, but is blind to the RHS payload variables (`capsule_hosts`, `idm_bootstrap_init_hosts`) because they are Jinja2 references inside shell string arguments — not `{{ }}` patterns in YAML task files. These variables are not dead; they are the named inventory-level lists that the dispatch layer passes to the reusable playbook. Projects using this pattern: **rhis-builder-baremetal-init** and **rhis-provisioner-container** (and the `group_vars/provisioner/` configuration that feeds it).

---

## Section 1: Dead Defaults — Defined in Role Defaults but Never Used

### rhis-builder-satellite

| Role | Variable | Status |
|---|---|---|
| `capsule_pre` | `capsule_pre_min_var_storage_gb` | **Confirmed dead** — no task reference found |
| `capsule_pre` | `capsule_pre_sat_fqdn` | **Confirmed dead** — no task reference found |
| `capsule_pre` | `capsule_pre_assert_not_users` | **Confirmed dead** — no task reference found |
| `capsule_pre` | `capsule_pre_assert_selinux` | **Confirmed dead** — no task reference found |
| `capsule_pre` | `capsule_pre_time_servers` | **Confirmed dead** — not referenced in tasks (inventory defines this for capsule host_vars instead) |
| `capsule_pre` | `capsule_pre_firewalld_service` | **Confirmed dead** — note: `capsule_pre_firewalld_config` IS used; this singular form is not |
| `satellite_pre` | `async_timeout` | **Naming violation** (see Section 3) + questionable use |
| `satellite_pre` | `async_delay` | **Naming violation** (see Section 3) + questionable use |

### rhis-builder-kvm

| Role | Variable | Status |
|---|---|---|
| `kvm_host` | `ssl_public_key_path` | **Confirmed dead** — no task reference |
| `kvm_host` | `ssl_public_key_format` | **Confirmed dead** — no task reference |
| `kvm_host` | `csr_digest` | **Confirmed dead** — cipher argument uses `ssl_private_key_cipher` instead |
| `kvm_host` | `csr_email_address` | **Confirmed dead** — no CSR task references email |
| `kvm_host` | `host_ssl_ca_crt_path` | **Confirmed dead** — only used inside defaults to set itself from `ipa_server_ca_crt_path` |
| `kvm_host` | `crt_force_regen` | **Scanner false positive** — used in `when:` without `{{ }}` in `ensure_libvirt_cert.yml` |
| `kvm_host` | `async_timeout` | **Naming violation** (see Section 3); no async tasks exist in the role |
| `kvm_host` | `async_delay` | **Naming violation** (see Section 3); no async tasks exist in the role |

### rhis-builder-baremetal-init

| Location | Variable | Status |
|---|---|---|
| `group_vars/provisioner/idm1_init_vars.yml` | `idm_bootstrap_init_hosts` | **Scanner false positive** — payload variable consumed via extra-vars dispatch: `-e "bootstrap_init_hosts={{ idm_bootstrap_init_hosts }}"`. Not dead. |
| `group_vars/provisioner/satellite1_init_vars.yml` | `satellite_bootstrap_init_hosts` | **Scanner false positive** — same extra-vars dispatch pattern. Not dead. |

### rhis-builder-day-2-ops

| Role/Location | Variable | Status |
|---|---|---|
| `cockpit` defaults | `cockpit_all` | **Scanner false positive** — used in `when: cockpit_all or …` without `{{ }}` |
| `cockpit` defaults | `cockpit_composer` | **Scanner false positive** — same |
| `cockpit` defaults | `cockpit_dashboard` | **Scanner false positive** — same |
| `cockpit` defaults | `cockpit_leapp` | **Scanner false positive** — same |
| `cockpit` defaults | `cockpit_machines` | **Scanner false positive** — same |
| `cockpit` defaults | `cockpit_podman` | **Scanner false positive** — same |
| `cockpit` defaults | `cockpit_pcp` | **Scanner false positive** — same |
| `cockpit` defaults | `cockpit_session_recording` | **Scanner false positive** — same |
| `auth_debug` defaults | `auth_debug_default_normal_level` | Likely scanner false positive — verify in tasks |
| `sysmessage` defaults | `sysmessage_allowable_types` | **Scanner false positive** — used in assertion/validation logic |
| `sysmessage` defaults | `sysmessage_default_type` | **Scanner false positive** — controls which message template is selected |
| `sysmessage` defaults | `sysmessage_default_custom_message` | **Intentional option** — activated when `sysmessage_default_type: "custom"`; provides the message body for the `custom` type, which is one of the declared `sysmessage_allowable_types`. Not dead. |
| `time` defaults | `time_timedaemon` | Likely scanner false positive |
| `time` defaults | `time_timeservers` | Likely scanner false positive |
| `group_vars/all` | `debug_output` | **Confirmed dead** — debugging code was removed; variable is an orphan artifact |
| `group_vars/all` | `force_regen` | **Scanner false positive** — bare boolean in `when:` |
| `group_vars/all` | `ssl_public_key_path` | **Confirm dead** — no task reference expected |
| `group_vars/all` | `ssl_public_key_format` | **Confirm dead** — no task reference expected |
| `group_vars/all` | `csr_email_address` | **Confirm dead** — no task reference expected |
| `group_vars/all` | `csr_digest` | **Confirm dead** — no task reference expected |
| `group_vars/all` | `create_crt_key_bundle` | Likely scanner false positive — verify |
| `group_vars/all` | `cockpit_bundle_path` | Used in template — may be scanner false positive |
| `group_vars/all` | `cockpit_self_ca_crt` | Verify — may be template reference |
| `group_vars/all` | `cockpit_self_crt` | Verify — may be template reference |
| `host_vars/ah.*/repositories.yml` | `collection_remotes` | **Scanner false positive** — `ah_repositories_sync` role uses it |

---

## Section 2: Variables Used But Missing From Role Defaults

### rhis-builder-kvm — Critical Gap

The 10 `libvirt_client_*` and `libvirt_server_*` certificate path variables appear in `test_vars.yml` but are **absent from `roles/kvm_host/defaults/main.yml`**. The role will fail without them if not supplied by inventory.

Variables to add to `kvm_host/defaults/main.yml`:
- `libvirt_client_crt_path`, `libvirt_client_crt_service_type`, `libvirt_client_csr_path`
- `libvirt_client_key_path`, `libvirt_client_private_key_pem_path`
- `libvirt_client_non_idm_ca_crt_path`
- `libvirt_server_crt_path`, `libvirt_server_crt_service_type`, `libvirt_server_csr_path`
- `libvirt_server_key_path`, `libvirt_server_private_key_pem_path`

### rhis-builder-aap — No Defaults at All

Zero role defaults defined anywhere. All variables must arrive from inventory. Key variables expected from inventory that have no fallback:
- Connection: `aap_platform_host`, `aap_platform_username`, `aap_platform_password`, `aap_validate_certs`
- `active_controller` vs `aap_platform_host` inconsistency (`ensure_aap_setting.yml` uses one, rest uses other)
- Hub: `aap_hub_admin_username`, `aap_hub_admin_password`, `aap_hub_validate_certs`
- Installer: `platform_installer`, `platform_installer_config`, `platform_topology`, `platform_version`, `platform_hosts`
- Object lists: `aap_settings`, `aap_credentials`, `aap_organizations`, `aap_inventories`, etc.

---

## Section 3: Naming Convention Violations (NOPREFIX)

### rhis-builder-kvm — All 27 defaults lack `kvm_host_` prefix

All defaults in `roles/kvm_host/defaults/main.yml` carry `# noqa: var-naming[no-role-prefix]` suppressions as a blanket workaround. This is intentional (shared variable contract with satellite and idm roles) but the suppressions mask the issue.

**Shared variable contract variables** (same name used across kvm, satellite, idm):
`crt_service_type`, `csr_*`, `ssl_private_key_*`, `passfile`, `host_ssl_*`, `ipa_server_ca_crt_path`, `keytab_retrieval_*`, `ipa_admin_principal`

**Recommendation:** These variables represent a cross-role shared interface. Document them formally in the schema as "shared infrastructure variables" rather than attempting to rename. The `# noqa` suppressions are the correct approach — consider adding a comment block in each defaults file explaining the shared contract.

### rhis-builder-satellite — satellite_pre role

| Variable | Issue |
|---|---|
| `async_timeout` | Should be `satellite_pre_async_timeout` per convention |
| `async_delay` | Should be `satellite_pre_async_delay` per convention |

### rhis-builder-idm — idm_pre role

| Variable | Issue |
|---|---|
| `async_timeout` | Should be `idm_pre_async_timeout` |
| `async_delay` | Should be `idm_pre_async_delay` |

### rhis-builder-baremetal-init — baremetal_init role

| Variable | Issue |
|---|---|
| `oem_dir` | Should be `baremetal_init_oem_dir` — inconsistent with `bootstrap_init_oem_dir` naming |
| `host` (loop var) | Should be `baremetal_init_host` |

---

## Section 4: FQDN Pattern Violations

**Principle:** `inventory.j2` is the single source of truth for host FQDNs. Variables referencing tracked infrastructure hosts must use `groups['group_name'][N]` — never pattern-reconstruct as `prefix.{{ _global_domain_name }}`.

### Category A — Infrastructure hosts that MUST use groups[] (fix required)

| File | Variable/Value | Fix |
|---|---|---|
| `host_vars/satellite/satellite_pre.yml:52` | `ipa_server_fqdn: "idm1.{{ _global_domain_name }}"` | Remove — `group_vars/all/main.yml.j2` already sets `{{ groups['idm_primary'][0] }}` correctly; host_vars silently wins |
| `host_vars/discosatellite/satellite_pre.yml:52` | `ipa_server_fqdn: "{{ groups['idm_primary'][0] }}"` | Already correct — no change needed |
| `group_vars/all/main.yml.j2:40` | `vm_compute_resource: "vcenter.{{ _global_domain_name }}"` | `"{{ groups['vmware_vcenter_hosts'][0] }}"` — vcenter IS in inventory.j2 as `vmware_vcenter_hosts` member |
| `host_vars/satellite/compute_resources.yml.j2:55` | vcenter URL `"vcenter.{{ _global_domain_name }}"` | `"{{ groups['vmware_vcenter_hosts'][0] }}"` |
| `host_vars/discosatellite/compute_resources.yml.j2:52` | vcenter URL `"vcenter.{{ _global_domain_name }}"` | `"{{ groups['vmware_vcenter_hosts'][0] }}"` |
| `host_vars/satellite/virtwho_configs.yml:14` | `hypervisor_server: "vcenter.{{ _global_domain_name }}"` | `"{{ groups['vmware_vcenter_hosts'][0] }}"` |
| `host_vars/discosatellite/virtwho_configs.yml:14` | `hypervisor_server: "vcenter.{{ _global_domain_name }}"` | `"{{ groups['vmware_vcenter_hosts'][0] }}"` |
| `host_vars/idm/prerequisites.yml:41` | `fqdn: "provisioner.{{ _global_domain_name }}"` | `"{{ groups['provisioner'][0] }}"` |
| `host_vars/idm/prerequisites.yml:43` | `fqdn: "satellite.{{ _global_domain_name }}"` | `"{{ groups['satellite_servers'][0] }}"` |
| `host_vars/idm/hbac_policy.yml:47` | `"satellite.{{ _global_domain_name }}"` | `"{{ groups['satellite_servers'][0] }}"` |
| `host_vars/idm/dns_configuration.yml.j2:33` | `srv_target: "satellite1.{{ _global_domain_name }}."` | `"{{ groups['satellite_servers'][0] }}."` (trailing dot required for SRV) |
| `group_vars/idm_replicas/idm_pre_vars.yml:35` | `fqdn: "provisioner.{{ _global_domain_name }}"` | `"{{ groups['provisioner'][0] }}"` |
| `group_vars/idm_replicas/idm_pre_vars.yml:37` | `fqdn: "satellite1.{{ _global_domain_name }}"` | `"{{ groups['satellite_servers'][0] }}"` |
| `host_vars/discosatellite/content_exports.yml.j2:30` | `destination_server: "discosatellite1.{{ global_domain_name }}"` | Uses `global_domain_name` (no underscore) — likely a bug; should be `_global_domain_name` or use `groups['satellite_servers'][0]` |
| `host_vars/quay1/quay.yml.j2:7` | `quay_server_hostname: "quay1.{{ global_domain_name }}"` | Uses `global_domain_name` (no underscore prefix) — verify variable name; likely should be `_global_domain_name` |

### Category B — Workload/demo VMs (intentional, not in rhis-builder inventory)

Pattern `name.{{ _global_domain_name }}` is correct for managed workload hosts that are NOT tracked in the rhis-builder inventory (testjboss2, testlamp2, testwordpress2, qatestjboss2, centosdemo1, oeldemo1, centostest1, oeltest1, etc.). These appear in `FQD.aap_static_hosts.yml`, `FQD.aap_static_groups.yml`, `FQD.aap_templates_*.yml`, `convert2rhel_test_hosts.yml`, `hostgroup_test_hosts_rhel*.yml`.

**No change required.** These are intentional.

### Category C — Provisioner host lists passed to Satellite roles

FQDNs in `aap26_hosts.yml.j2`, `aap24_hosts.yml.j2`, `capsule_hosts.yml.j2`, `quadlet_hosts.yml.j2`, `idm_replica_hosts.yml.j2`, `bond_test_hosts.yml.j2` use `name.{{ _global_domain_name }}` as FQDN values passed to Satellite hostgroup/provisioner configurations. These hosts ARE in the rhis-builder inventory.

**Status:** These `.j2` files are themselves rendered from `_global_domain_name` during `inventory_update.yml`. The pattern is consistent — the FQDN ends up in the rendered output. Acceptable as-is, but should be reviewed when CIDR rework happens to ensure `inventory.j2`-generated names and these values remain in sync.

### Category D — Disconnected/highside external server references

`destination_server: "satellite_disconnected.{{ _global_domain_name }}"` in `content_export_copies.yml` and `content_exports.yml` for both satellite and discosatellite. This represents an external (highside) server not in this inventory — pattern construction is the only option.

**No change required.** Consider adding an explicit variable in basevars (e.g., `rhis_disconnected_satellite_hostname`) so users don't need to find this deep in host_vars.

---

## Section 5: Security Finding

### rhis-builder-aap

`roles/platform_post/tasks/test_node.yml` contains hardcoded credentials in an active (non-commented) task block. This must be remediated before any public release.

**Action required:** Replace hardcoded credentials with vault variables. Assign to rhis-builder-aap backlog.

---

## Section 6: Structural Issues

### rhis-builder-kvm

- `roles/kvm_networks/tasls/` — directory name is a typo for `tasks/`. No task files exist inside. Either rename and add tasks, or remove the stub.
- `roles/kvm_cr` and `roles/kvm_images` — stub roles that reference tasks not yet implemented.

---

## Action Plan

### Immediate (safe, no functional impact)

1. **Remove** dead capsule_pre defaults: `capsule_pre_min_var_storage_gb`, `capsule_pre_sat_fqdn`, `capsule_pre_assert_not_users`, `capsule_pre_assert_selinux` from `rhis-builder-satellite` — already commented out pending test confirmation
2. ~~Remove `idm_bootstrap_init_hosts` and `satellite_bootstrap_init_hosts`~~ — **RETRACTED**: these are extra-vars dispatch payload variables, not dead. See Scanner Limitation Note.
3. ~~**Fix** `tasls/` typo in `rhis-builder-kvm/roles/kvm_networks/`~~ — **RESOLVED 2026-05-28**: empty `tasls/` stub removed; `tasks/` created with `.gitkeep`. Note: `kvm_networks/` was entirely untracked in git.
4. ~~**Fix** `global_domain_name` → `_global_domain_name` in `quay.yml.j2` and `content_exports.yml.j2`~~ — **FALSE POSITIVE 2026-05-28**: both references are outside `{% raw %}`/`{% endraw %}` blocks and are intentional render-time Jinja2 substitutions. `inventory_update.yml` replaces them with the domain from `<domain>_inventory_basevars.yml`. No fix needed.

### FQDN fixes (requires inventory_update.yml rerender)

5. **Remove** `ipa_server_fqdn` override in `host_vars/satellite/satellite_pre.yml` (line 52)
6. **Fix** `vm_compute_resource` in `group_vars/all/main.yml.j2` → `groups['vmware_vcenter_hosts'][0]`
7. **Fix** vcenter URL/hypervisor_server in `compute_resources.yml.j2` and `virtwho_configs.yml` for both satellite and discosatellite
8. **Fix** provisioner/satellite fqdn references in `host_vars/idm/` and `group_vars/idm_replicas/`

### Deferred (requires broader design work)

9. **Add** libvirt cert variables to `kvm_host/defaults/main.yml` (see Section 2)
10. **Resolve** `active_controller` vs `aap_platform_host` inconsistency in rhis-builder-aap
11. **Remediate** hardcoded credentials in rhis-builder-aap `test_node.yml`
12. ~~**Rename** `oem_dir` → `baremetal_init_oem_dir` in baremetal_init role~~ — **WONT_FIX 2026-05-29**: the `baremetal_init` role is deprecated.
13. ~~**Document** shared infrastructure variables in schema~~ — **RESOLVED 2026-05-29**: `schema/shared_variable_contract.md` created, documenting the architectural rationale, full variable list, and rules for managing the contract across rhis-builder projects.

---

## Notes on Variables Without Schema Entries

The following variable families are used across multiple projects but lack schema documentation entries:

- `async_timeout` / `async_delay` — used as unqualified names in satellite_pre, idm_pre, kvm_host defaults; need a schema entry clarifying these are Ansible async control variables, not project variables
- `passfile` — used across kvm, satellite, idm, day-2-ops; schema entry exists but should document all consumers
- `libvirt_client_*` / `libvirt_server_*` — 10 variables; need schema entries
- `platform_node_pre_*` — AAP node pre-configuration variables defined in aapcontroller/aaphub host_vars; no schema entry
- `piv_*` — PIV certificate management variables in `group_vars/provisioner`; large family, no schema section
