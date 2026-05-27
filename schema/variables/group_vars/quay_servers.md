# Group: quay_servers — Quay Registry Variables

Schema Version: 1.0.0

These variables configure self-hosted Red Hat Quay container registries.

Upstream collection: `infra.quay_configuration` — refer to the upstream collection documentation for authoritative variable references.

---

## Source Files

| File | Format |
|---|---|
| `group_vars/quay_servers/main.yml` | YAML |

---

## Registry Authentication

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `quay_registry` | string | `"registry.redhat.io"` | Hostname of the upstream container registry from which Quay and Clair images are pulled. | Quay deployment tasks |

---

## Container Images

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `quay_image` | string | `"registry.redhat.io/quay/quay-rhel9"` | Full image name (without tag) for the Red Hat Quay application container. | Quay container deployment |
| `quay_image_tag` | string | `"v3.16"` | Image tag for the Quay container, pinning the deployed Quay version. | Quay container deployment |
| `clair_image` | string | `"registry.redhat.io/quay/clair-rhel9"` | Full image name (without tag) for the Clair vulnerability scanner container. | Clair container deployment |
| `clair_image_tag` | string | `"v3.16"` | Image tag for the Clair container, pinning the deployed Clair version. Should match `quay_image_tag`. | Clair container deployment |
| `postgres_image` | string | `"registry.redhat.io/rhel9/postgresql-16"` | Full image name (without tag) for the PostgreSQL database container used by Quay and Clair. | Database container deployment |
| `postgres_image_tag` | string | `"latest"` | Image tag for the PostgreSQL container. | Database container deployment |
| `redis_image` | string | `"registry.redhat.io/rhel9/redis-7"` | Full image name (without tag) for the Redis cache container used by Quay. | Redis container deployment |
| `redis_image_tag` | string | `"latest"` | Image tag for the Redis container. | Redis container deployment |

---

## Host Storage Paths

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `quay_config_dir` | string | `"/srv/containers/quay/config"` | Host directory bind-mounted into the Quay container for its configuration files. | Quay container deployment |
| `quay_clair_config_dir` | string | `"/srv/containers/quay/clair-config"` | Host directory bind-mounted into the Clair container for its configuration files. | Clair container deployment |
| `quay_quadlet_dir` | string | `"/etc/containers/systemd"` | Directory where Podman Quadlet unit files are written so that systemd manages the Quay and Clair containers. | Quay/Clair service setup |

---

## Storage Backend

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `quay_storage_backend` | string | `"LocalStorage"` | Quay storage driver. `LocalStorage` stores image blobs on the local filesystem. Other supported values (e.g., `S3`, `Azure`) require additional backend-specific variables. | Quay configuration |
| `quay_storage_path` | string | `"/datastorage/registry"` | Filesystem path on the host where Quay stores image layer blobs when `quay_storage_backend` is `LocalStorage`. | Quay configuration |

---

## Clair Resource Limits

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `quay_clair_cpus` | integer | `2` | CPU limit assigned to the Clair vulnerability scanner container. | Clair container deployment |
| `quay_clair_postgres_cpus` | integer | `2` | CPU limit assigned to the PostgreSQL container used by Clair. | Database container deployment |
| `quay_clair_postgres_max_connections` | integer | `300` | Maximum number of concurrent client connections allowed by the Clair PostgreSQL instance. | Database container deployment |

---

## Repository Mirror Settings

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `quay_repo_mirror_interval` | integer | `30` | Interval in minutes between automatic repository mirror synchronisation runs. | Quay configuration |
| `quay_repo_mirror_tls_verify` | boolean | `true` | When `true`, Quay verifies TLS certificates of upstream mirror sources. Set to `false` only for registries with self-signed certificates that have been explicitly trusted. | Quay configuration |

---

## Firewall Configuration

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `quay_firewall_zone` | string | `"public"` | Firewalld zone in which Quay-related port rules are applied. | Firewall configuration tasks |
