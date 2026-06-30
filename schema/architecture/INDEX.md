# RHIS Architectural Design Discussions

This directory captures design-level discussions and architectural decisions that span
multiple capabilities or that require more context than a capability registry entry can hold.
These documents are not workflow instructions (see `disconnected_satellite_workflow.md`) and
not variable references (see `variables/`) — they are the "why and how we thought about it"
layer that informs both implementation choices and operator decisions.

Each document is a living record. Decisions get made, context gets added, open questions
get answered — update in place rather than creating a new file per revision.

---

## Index

| Document | Topic | Related Capabilities |
|---|---|---|
| [disconnected_deployment_model.md](disconnected_deployment_model.md) | Spectrum of disconnected deployment configurations — from basic (IdM + Satellite) to digital twin (NASA mission systems). Export scoping, AAP git source, content authorization per tier. | C10 |
| [soe_selection_model.md](soe_selection_model.md) | SOE selection problem — the "big box store" template vs. real customer deployments. Dependency cascade across 10+ files per SOE. Four approaches (selection-driven templates, profile modules, post-generation prune, wizard). Connection to disconnected export scoping. | C05, C06, C07, C10, C27 |
| [highside_import_workflow.md](highside_import_workflow.md) | **Verified from code.** Complete highside import workflow — main.yml execution flow for disconnected builds, satellite_disconnected_pre role (ISO staging), content_imports role (Pulp import, SELinux handling), drive mount paths (lowside: /var/lib/pulp/exports; highside: /var/lib/pulp/imports), prefix remapping requirement for _content_imports.yml, three delivery scenarios (usb/virtual_disk/rsync), design for build_sat_disconnected_import.sh and bundle_delivery role. | C10 |
| [bash_ansible_boundary.md](bash_ansible_boundary.md) | Design principle governing where bash is legitimate vs. where logic belongs in Ansible. Shell scripts exist solely as operator usability wrappers. All implementation logic — data collection, file operations, templating, host queries — belongs in Ansible once an execution context exists. Includes the boundary table, anti-patterns, and legitimate exceptions. | All |

---

## When to add a document here

- The decision affects more than one capability or crosses repo boundaries
- The rationale is non-obvious and will matter to the next person who reads the code
- There are real trade-offs between approaches — not just one obviously correct answer
- The topic has come up more than once and keeps needing re-explanation
