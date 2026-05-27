# Host: quadlet — Quadlet Container Host Variables

Schema Version: 1.0.0

These variables configure Quadlet container hosts. Quadlet is a systemd-native container management approach used in RHIS for running persistent container workloads (e.g. Tang server for NBDE).

---

## Registry Credentials

These variables provide access to the container registry from which images are pulled. They are referenced from vault variables.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `containerhost_registry` | string | — | Hostname or URL of the container registry (e.g. `registry.redhat.io`) | `containers.yml` |
| `containerhost_registry_username` | string | — | Username for authenticating to the container registry | `containers.yml` |
| `containerhost_registry_password` | string | — | Password or token for authenticating to the container registry | `containers.yml` |

---

## Container Definitions (`containers`)

A list of container specification dictionaries. Each entry describes a container workload to be deployed as a systemd-managed Quadlet unit. The containerhost role iterates this list to pull images, configure firewall rules, publish ports, set SELinux labels, generate systemd unit files, and validate the running container.

Each list item supports the following keys:

### Identity and Image

| Key | Type | Description |
|---|---|---|
| `name` | string | Human-readable name for the container (e.g. `tang`) |
| `image` | string | Container image name without tag or registry prefix (e.g. `rhel9/tang`) |
| `id` | string | Short identifier used in generated unit file names and labels |
| `tag` | string | Image tag to pull (e.g. `latest`) |
| `registry` | string | Registry from which to pull the image; references `containerhost_registry` |
| `registry_username` | string | Registry login username; references `containerhost_registry_username` |
| `registry_password` | string | Registry login password; references `containerhost_registry_password` |
| `force` | bool | Force a re-pull of the image even if it already exists locally (`false` = use cached image) |
| `validate_certs` | bool | Whether to validate TLS certificates when pulling from the registry |

### Runtime Behaviour

| Key | Type | Description |
|---|---|---|
| `detach` | bool | Run the container in the background (`true` = detached mode) |
| `state` | string | Desired container state: `started`, `stopped`, `absent` |
| `systemd` | bool | Whether to manage this container as a systemd unit |
| `dependencies` | list of strings | Host packages that must be installed before the container can be tested or started (e.g. `clevis` for Tang testing) |

### Port Publishing (`publish`)

A list of port mapping strings in Docker/Podman format (`"host_port:container_port"`).

**Default (tang):** `"8080:8080"`

### Firewall Rules (`firewall`)

A list of firewalld rule dictionaries applied to the host to permit inbound traffic to the container's published ports.

| Key | Type | Description |
|---|---|---|
| `port` | string | Port and protocol string (e.g. `"8080/tcp"`) |
| `zone` | string | Firewalld zone to apply the rule in (e.g. `"public"`) |
| `state` | string | `enabled` or `disabled` |

### Systemd Unit Generation (`generate_systemd`)

Controls how Podman generates the systemd unit file for this container.

| Key | Type | Description |
|---|---|---|
| `path` | string | Directory where the unit file is written (`/usr/lib/systemd/system/`) |
| `restart_policy` | string | Systemd restart policy for the container unit (e.g. `"on-failure"`) |
| `time` | int | Stop timeout in seconds before systemd sends SIGKILL (default: `120`) |
| `names` | bool | Whether to use container names in unit file names (`true`) |
| `container_prefix` | string | Prefix prepended to unit file names (e.g. `"rhis"` produces `rhis-tang.service`) |
| `wants` | string | Systemd `Wants=` dependency (e.g. `"network-online.target"`) |

### SELinux Port Labels (`selinux_ports`)

A list of SELinux port context assignments applied to the host before the container starts. Ensures the container's published ports have the correct SELinux type so policy is not violated.

| Key | Type | Description |
|---|---|---|
| `ports` | int | Port number to label |
| `protocol` | string | Protocol (`tcp` or `udp`) |
| `setype` | string | SELinux type to assign (e.g. `tangd_port_t`) |
| `state` | string | `present` or `absent` |

### Volume Mounts (`volume`)

A list of volume mount strings in Podman format (`"volume_name:container_path"`). Named volumes are created automatically by Podman if they do not exist.

**Default (tang):** `"tang-keys:/var/db/tang"` — persists Tang key material across container restarts.

### Container Validation (`test_shell_command`, `test_value`, `test_expected_result`)

Optional fields used by the containerhost role to validate that the container is functioning correctly after start.

| Key | Type | Description |
|---|---|---|
| `test_shell_command` | string | Shell command to execute on the host to test the container service. For Tang, this performs a round-trip encrypt/decrypt using `clevis`. |
| `test_value` | string | The plaintext value passed to the encrypt step of the test command |
| `test_expected_result` | string | The string the decrypted output must equal for the test to pass |

---

## Configured Container: `tang`

The default configuration deploys a single Tang server for Network-Bound Disk Encryption (NBDE). Tang allows LUKS-encrypted hosts to automatically decrypt their disks at boot when they can reach the Tang server, without requiring a passphrase.

| Property | Value |
|---|---|
| Image | `rhel9/tang:latest` from `containerhost_registry` |
| Published port | `8080/tcp` (host) → `8080/tcp` (container) |
| SELinux port type | `tangd_port_t` on port 8080/tcp |
| Persistent data | Named volume `tang-keys` mounted at `/var/db/tang` |
| Systemd unit | `rhis-tang.service`, restart on failure, network dependency |
| Validation | clevis encrypt/decrypt round-trip against `{{ ansible_fqdn }}:8080` |
