# Host: quay1 — Quay Registry Host Variables

Schema Version: 1.0.0

These variables configure a self-hosted Red Hat Quay container registry instance. Quay provides image storage, vulnerability scanning via Clair, and mirroring capabilities.

Upstream collection: `infra.quay_configuration` — refer to the upstream collection documentation for authoritative variable references.

---

## Server Identity

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `quay_server_hostname` | string | `"quay1.{{ basevars_global_domain_name }}"` | Fully-qualified hostname that clients use to reach the Quay registry. Constructed from `basevars_global_domain_name` at template render time. | `quay.yml.j2` |

---

## Network and Port Configuration

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `quay_http_port` | int | `8080` | Host port published for HTTP traffic to the Quay container | `quay.yml.j2` |
| `quay_https_port` | int | `8443` | Host port published for HTTPS traffic to the Quay container | `quay.yml.j2` |

---

## TLS and URL Scheme

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `quay_preferred_url_scheme` | string | `"https"` | URL scheme advertised to clients and used for redirect generation. Set to `"https"` when TLS certificates are present in the Quay config volume; set to `"http"` when TLS is terminated externally. | `quay.yml.j2` |
| `quay_external_tls_termination` | bool | `false` | When `true`, Quay assumes a reverse proxy (e.g. Nginx, HAProxy) terminates TLS before traffic reaches the container and does not handle TLS itself. When `false`, Quay handles TLS directly using certificates from its config volume. | `quay.yml.j2` |

---

## Feature Toggles

These boolean flags enable or disable optional Quay subsystems.

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `quay_feature_security_scanner` | bool | `true` | Enable the Clair security scanner integration. When enabled, Quay submits images to Clair for CVE scanning and displays vulnerability reports in the UI. | `quay.yml.j2` |
| `quay_feature_repo_mirror` | bool | `true` | Enable the repository mirroring feature. Allows Quay repositories to be configured as mirrors of upstream registries, with configurable sync schedules. | `quay.yml.j2` |
| `quay_feature_mailing` | bool | `false` | Enable Quay's e-mail notification subsystem. Requires SMTP configuration (not set in this template). Disabled by default. | `quay.yml.j2` |

---

## Superuser Accounts

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `quay_superusers` | list of strings | (commented out — no default) | Optional list of Quay usernames to grant superuser (administrator) privileges. When omitted the first user created through the UI setup wizard receives superuser access. Uncomment and populate to pre-configure superuser accounts. | `quay.yml.j2` |
