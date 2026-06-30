# Bash / Ansible Boundary Design Principle

## The Rule

**Implementation logic belongs in Ansible. Bash exists for usability.**

This is not a preference — it is a design constraint that governs every rhis-builder project.
Violating it produces a codebase that looks disjointed, is harder to maintain, and reduces
adoption by making contributors hold two mental models simultaneously.

---

## Why Bash Exists in rhis-builder At All

The shell scripts in the rhis-provisioner container (`build_idm_primary.sh`,
`build_sat_primary.sh`, `build_sat_disconnected_import.sh`, etc.) exist for a single
explicit reason: **operator usability**.

It is far easier to tell an operator:

```bash
./build_idm_primary.sh --deployment example.ca
```

than it is to tell them:

```bash
ansible-playbook \
    --inventory /rhis/vars/external_inventory/inventory \
    --user ansiblerunner \
    --private-key /root/.ssh/id_ed25519 \
    --vault-password-file /root/.ssh/vault.txt \
    --extra-vars "vault_dir=/rhis/vars/vault vars_dir=/rhis/vars/host_vars" \
    --limit=idm_primary \
    main.yml
```

The shell scripts are **thin wrappers** — argument parsing, input validation, and
`ansible-playbook` invocation. They contain no implementation logic. Their entire purpose
is to give operators a simple, memorable, discoverable entry point.

---

## The Boundary

| Belongs in Bash | Belongs in Ansible |
|---|---|
| Argument parsing (`getopts`, `case`) | Package installation and version querying |
| Pre-flight checks (is the container running? does the file exist?) | File creation, templating, permissions |
| `ansible-playbook` invocation with correct switches | Data collection from managed hosts |
| Orchestration that must run before Ansible inventory exists | Conditional logic over managed host state |
| Operator-facing entry points | Error handling with structured output |
| Transfer script generation (pre-inventory, host-agnostic) | Manifest content generation |

The deciding question: **does Ansible exist yet in this execution context?**

- Before the inventory is rendered, before the container is running, before SSH keys are
  in place — bash is legitimate because Ansible has nothing to work with yet.
- Once Ansible is running against a managed host, all logic belongs in Ansible. Any bash
  at that point is fighting against the grain of the project.

---

## Where This Principle Has Been Violated (and Why It Matters)

### Pattern to avoid: data collection in bash when Ansible is already running

```bash
# Wrong — SSH to collect data that Ansible could gather natively
SAT_VERSION=$(ssh ansiblerunner@${SAT_HOST} "rpm -q satellite --queryformat '%{VERSION}'")
```

This duplicates capability that Ansible provides idiomatically:

```yaml
- name: "Gather package facts"
  ansible.builtin.package_facts:
    manager: rpm
```

The bash version introduces a second SSH connection, a separate error-handling path,
and a different mental model — all for something Ansible already does cleanly.

### Pattern to avoid: data transformation in bash/Python when a template suffices

Manifest generation via Python heredoc in a bash script, when the data is already
available as Ansible variables, belongs in an Ansible template task.

### The accumulation effect

Each individual violation seems minor. Cumulatively they make the project feel like
a collection of scripts rather than a coherent system. Contributors who understand
Ansible will hesitate to touch bash sections. Operators debugging failures have to
understand two execution models. Inconsistency reduces trust and slows adoption.

---

## Legitimate Exceptions

- `export_deployment.sh` — outer orchestrator that runs before the inventory exists.
  The SHA256 checksum walk of the staging directory is a filesystem operation with no
  managed host — Python heredoc is acceptable here. Ansible is not yet running.
- `prepare_highside.sh` — runs on the highside operator workstation before the
  provisioner container is loaded. No Ansible context exists at this point.
- `rhis_build_provisioner.sh` — builds the container image itself. Ansible is the
  thing being built, not a tool available to use.

In all three cases: bash is legitimate because Ansible does not yet have an execution
context. The moment Ansible is running against a managed host, control returns to Ansible.

---

## Guidance for New Code

When you are about to write a bash or Python block inside a script that already calls
`ansible-playbook`, stop and ask:

1. Could this be a task in the playbook being called?
2. Could this be a task in a role that the playbook includes?
3. Am I about to SSH to a managed host from bash to collect data that `ansible.builtin.package_facts`,
   `ansible.builtin.stat`, or `ansible.builtin.slurp` would collect cleanly?

If the answer to any of these is yes, the logic belongs in Ansible.

The shell script stays thin. The playbook stays complete.
