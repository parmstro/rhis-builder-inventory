# RFC: Priority-Weighted Kickstart Snippet Ordering for Foreman/Satellite

**Author:** Paul Armstrong, Senior Principal Technical Specialist, RHEL — Red Hat Canada (parmstro@redhat.com | GitHub: [@parmstro](https://github.com/parmstro))
**Date:** 2026-05-24
**Status:** Design Proposal — Draft for Community Discussion
**Related:** [SOE Bundle Model RFC](soe_bundle_model.md) | [GitHub Discussion #28](https://github.com/parmstro/rhis-builder-inventory/discussions/28)

---

## Abstract

Satellite kickstart templates include snippets via static ERB calls — each snippet name is a string literal embedded in the base template. This creates a maintenance problem: adding a new SOE-specific snippet requires modifying the shared base template, and there is no standard mechanism to control snippet execution order when multiple snippets are composed together. This RFC proposes a lightweight convention — a host parameter carrying a priority-weighted snippet list — that resolves both problems without requiring changes to Foreman core and is independently adoptable by any Foreman or Satellite user.

---

## 1. The Problem

### 1.1 The Static Inclusion Constraint

The standard mechanism for including a snippet in a Satellite kickstart template is:

```erb
<%= snippets('subscription_manager_registration') %>
```

This call is static — the snippet name is a string literal. Adding a new SOE-specific snippet requires modifying the base template to add a new static call. In a multi-SOE environment where different workload classes need different snippet sets, this creates a chicken-and-egg problem: the base template must know about every snippet in advance, and the shared base template becomes a maintenance bottleneck for all SOEs.

### 1.2 The Ordering Problem

Kickstart snippets have ordering requirements. A snippet that installs an application must run after a snippet that configures repositories. A positional list (first item runs first) encodes order implicitly — adding a new snippet requires finding the correct insertion point, and composing snippet sets from multiple sources requires manually reconciling their relative ordering. This is error-prone and does not scale when snippets are managed as independent units.

### 1.3 Built-in Satellite Snippets

Satellite ships with built-in snippets — `subscription_manager_registration`, `freeipa_register`, `remote_execution_pull_setup`, `insights_client_setup`, `ansible_provisioning_callback`, `eject_cdrom` — that cannot be modified. Any ordering solution must accommodate these alongside user-authored snippets without requiring changes to snippet content.

---

## 2. Alternatives Considered

**Systemd dependency graph model:** Each snippet declares `After=`, `Before=`, `Requires=`, and `Wants=` relationships in a metadata block. An aggregation step builds a directed graph and performs a topological sort to determine render order.

*Rejected because:* The problem scope does not justify the complexity. Systemd's dependency graph solves ordering across hundreds of units with intricate interdependencies spanning a full OS boot. A SOE's snippet set is small and has predictable phase relationships. The machinery required — metadata parsing, graph construction, topological sort, cycle detection — is disproportionate to the problem and difficult to explain or extend.

---

## 3. Proposed Convention

### 3.1 Dynamic Inclusion via Host Parameter

Satellite's ERB template system is full Ruby. The `snippets()` helper accepts a string expression, not just a string literal. A single ERB block added to the base template enables fully data-driven snippet inclusion:

```erb
<% if @host.params['foreman_extra_snippets'] %>
  <%
    snippet_list = @host.params['foreman_extra_snippets']
      .split(';')
      .map  { |s| parts = s.split(':', 2); [parts[0].to_i, parts[1].strip] }
      .sort_by { |priority, _| priority }
  %>
  <% snippet_list.each do |_, name| %>
    <%= snippets(name) %>
  <% end %>
<% end %>
```

The `foreman_extra_snippets` hostgroup parameter is a semicolon-separated list of `priority:snippet_name` pairs. The block sorts by priority before rendering. The base template requires no further modification when snippets are added or removed.

### 3.2 Priority-Weighted Ordering with Phase Ranges

The priority number replaces positional ordering. Phase ranges are a documented convention — gaps between ranges allow new snippets to be inserted without renumbering existing entries. This is the same reasoning behind SysV init script numbering:

| Range | Phase |
|---|---|
| 100–199 | Pre-partition and disk layout |
| 200–299 | Subscription and host registration |
| 300–399 | Repository configuration |
| 400–499 | Base package selection |
| 500–599 | Service and daemon configuration |
| 600–699 | Application package installation |
| 700–799 | Application configuration |
| 800–899 | Post-install hooks |
| 900–999 | Cleanup and finalization |

Example parameter value:

```
foreman_extra_snippets = "200:subscription_manager_registration;210:freeipa_register;300:rhis_repos;600:rhis_jboss_packages;700:rhis_jboss_config;820:ansible_provisioning_callback;950:eject_cdrom"
```

**Key properties:**
- Order is declared by priority number, not by list position. Adding a snippet requires choosing a number in the right range — no existing entry is touched.
- The priority lives in the parameter value, not in the snippet content. Built-in and user-authored snippets participate identically.
- Tie-breaking within a shared priority value is alphabetical by name — deterministic, no user intervention required.
- The model requires no tooling beyond sorting.

### 3.3 Recommended Priority Assignments for Built-in Snippets

| Snippet | Recommended Priority |
|---|---|
| `subscription_manager_registration` | 200 |
| `freeipa_register` | 210 |
| `remote_execution_pull_setup` | 220 |
| `insights_client_setup` | 230 |
| `ansible_provisioning_callback` | 820 |
| `eject_cdrom` | 950 |

### 3.4 The Skeleton Base Template

For the convention to work cleanly, the base kickstart template should contain no static snippet calls. Static calls alongside the dynamic block create a double-execution risk. The base template should contain only the structural minimum — partitioning directives, `%packages` block, `%post` header and footer — with all snippet inclusion routed through `foreman_extra_snippets`. This makes all SOE-specific content visible in the hostgroup parameter rather than hidden in the base template.

---

## 4. Relationship to the SOE Bundle Model

This convention is a component of the broader [SOE Bundle Model RFC](soe_bundle_model.md). In the bundle model, each SOE bundle declares its snippet set with priority assignments. An aggregation step merges snippet lists from all active bundles, sorts by priority, deduplicates, and writes the result to the hostgroup parameter. The snippet ordering convention is independently adoptable without the full bundle model.

---

## 5. Community Proposal

### 5.1 Near-Term: Adopt as a Convention

This proposal requires no changes to Foreman core. Any Foreman or Satellite user can adopt it today by:

1. Adding the ERB block to each base kickstart template
2. Standardising on `foreman_extra_snippets` as the parameter name
3. Following the priority phase ranges when assigning snippet priorities

Standardising the parameter name across the community ensures snippets, tooling, and documentation are interoperable between projects.

### 5.2 Longer-Term: Native Foreman Feature

If the community validates the convention, a native implementation could:

- Add a `priority` attribute to snippet template objects in the Foreman data model
- Provide UI for managing snippet priority assignments per hostgroup or OS
- Render snippets natively in priority order without the ERB boilerplate block
- Include default priority values for built-in snippets

This would make dynamic, ordered snippet composition a first-class Foreman capability.

---

## 6. Next Steps

1. Gather community feedback on the parameter name, priority ranges, and skeleton base template approach via [GitHub Discussion #29](https://github.com/parmstro/rhis-builder-inventory/discussions/29).
2. Author the skeleton base RHEL 9 kickstart template and initial RHIS snippet set with documented priority assignments.
3. Post to the Foreman community forum (community.theforeman.org) once the RHIS community has validated the approach.
4. Evaluate native Foreman feature request if community adoption warrants it.
