# Host: capsule — Satellite Capsule Variables

Schema Version: 1.0.0

These variables configure a Red Hat Satellite Capsule server. Capsules extend Satellite functionality to remote locations, providing content mirroring, DHCP, DNS, TFTP, and remote execution services.

Upstream collection: `redhat.satellite` — refer to the [collection documentation](https://console.redhat.com/ansible/automation-hub/repo/published/redhat/satellite/) for authoritative variable references.

---

## Pre-installation Node Configuration (`capsule_pre.yml`)

These variables are applied by the RHIS capsule pre-configuration role before the Satellite capsule installer runs. They prepare the node's subscription, storage, SELinux state, firewall, and enabled repositories.

> Note: All core `satellite_*` connection variables (URL, username, password) are inherited from `group_vars/all/main.yml` and are not redefined here.

### Subscription and Feature Flags

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `capsule_pre_activation_key` | string | `"satellite_capsule"` | Name of the Satellite activation key used to register the capsule host during pre-configuration | `capsule_pre.yml` |
| `capsule_pre_disable_cockpit` | bool | `true` | Whether to disable the Cockpit web console on the capsule node | `capsule_pre.yml` |

### Storage

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `volume` | dict | see below | A single logical volume definition that overrides any group-level default. The capsule needs a large `/var` for content mirroring. | `capsule_pre.yml` |
| `volume.lv_name` | string | `"lv_var"` | Logical volume name | `capsule_pre.yml` |
| `volume.vg_name` | string | `"vg_root"` | Volume group containing the LV | `capsule_pre.yml` |
| `volume.minimum_size` | string | `"110G"` | Minimum required size; the LV is grown to this size if smaller | `capsule_pre.yml` |
| `volume.state` | string | `"present"` | Ensures the LV exists | `capsule_pre.yml` |

### Time Services

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `capsule_pre_time_servers` | list | `"{{ timeservers }}"` | List of NTP server addresses; resolved from the `timeservers` group variable at render time | `capsule_pre.yml` |

### SELinux

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `capsule_pre_selinux_state` | string | `"enforcing"` | Desired SELinux enforcement state on the capsule node | `capsule_pre.yml` |
| `capsule_pre_selinux_policy` | string | `"targeted"` | SELinux policy type | `capsule_pre.yml` |

### Firewall (`capsule_pre_firewalld_config`)

A list of firewalld rule dictionaries to apply to the capsule node.

| Key | Type | Description |
|---|---|---|
| `service` | string | Firewalld service name to enable or disable |
| `state` | string | `"enabled"` or `"disabled"` |
| `zone` | string | Firewalld zone to apply the rule in |

**Default configuration:** enables the `RH-Satellite-6-capsule` service in the `public` zone. This service definition opens all ports required by the Satellite capsule (HTTPS, Pulp API, RHSM, TFTP, DNS, DHCP, etc.) in a single named service.

### Enabled Repository Sets (`capsule_pre_repositories`)

A list of repository set labels that must be enabled on the capsule node via Subscription Manager before the installer is run.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `capsule_pre_repositories` | list | see below | Repository IDs to enable | `capsule_pre.yml` |

**Default list:**

| Repository ID |
|---|
| `rhel-9-for-x86_64-baseos-rpms` |
| `rhel-9-for-x86_64-appstream-rpms` |
| `satellite-capsule-6.18-for-rhel-9-x86_64-rpms` |
| `satellite-maintenance-6.18-for-rhel-9-x86_64-rpms` |

---

## Capsule Installer Reference (`capsule.yml`)

The `capsule.yml` file is a comprehensive reference document for `satellite-installer --scenario capsule` options. It is fully commented out and does not define any active Ansible variables. It documents the available installer switches and their current defaults, serving as an operator guide for customising the capsule installer command line.

Key installer modules documented in the file (all presented as commented-out flags):

| Module | Purpose |
|---|---|
| Certificate management (`--certs-*`) | Update, reset, or skip checks on HTTPS certificates and CA |
| `foreman_proxy` | Core proxy settings: bind host, BMC, DHCP, DNS, HTTP/S ports, logging, OAuth, realm, SSL, TFTP, templates |
| `foreman_proxy_plugin_ansible` | Ansible remote execution plugin |
| `foreman_proxy_plugin_dhcp_infoblox` | Infoblox DHCP integration |
| `foreman_proxy_plugin_dhcp_remote_isc` | Remote ISC DHCP integration |
| `foreman_proxy_plugin_discovery` | Foreman Discovery plugin |
| `foreman_proxy_plugin_dns_infoblox` | Infoblox DNS integration |
| `foreman_proxy_plugin_openscap` | OpenSCAP compliance scanning integration |
| `foreman_proxy_plugin_remote_execution_script` | Remote execution via SSH |
| Content features (`--foreman-proxy-content-enable-*`) | Enable/disable Ansible, Deb, container, file, OSTree, Python, and RPM (Yum) content types |

> The actual capsule installer command is generated by the Satellite primary during its own setup phase; RHIS captures this generated command and executes it on the capsule node directly. The `capsule.yml` reference will be used in a future enhancement to allow per-capsule installer option overrides.
