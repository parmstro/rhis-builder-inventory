# Group: imagebuilders — Image Builder Variables

Schema Version: 1.0.0

These variables configure OSBuild Composer on Image Builder hosts. Image Builder creates custom RHEL images for cloud and on-premises deployments.

**Purpose of this configuration:** By default, OSBuild Composer sources content directly from the Red Hat CDN. This configuration redirects Image Builder to consume content from Satellite instead. This serves two goals:

1. **Content curation** — Satellite acts as a controlled content gateway, allowing RHIS to govern exactly which packages and versions are permitted in built images. Only content that has been synchronized, promoted, and published through Satellite content views is available to Image Builder, providing the same governance as any other Satellite-managed host.

2. **Build consistency** — By using Satellite activation keys to define repository sets, OSBuild Composer images and kickstart-provisioned instances receive identical content. The same activation key that registers a kickstart-deployed host also governs the repositories available inside an OSBuild image, resulting in near-identical builds from both paths. The primary difference between an OSBuild cloud image and a kickstart instance is the inclusion of cloud platform-specific components (drivers, agents, and tools) required to function correctly on the target cloud platform.

Upstream collection: `infra.osbuild` — refer to the [collection documentation](https://github.com/redhat-cop/infra.osbuild) for authoritative variable references.

---

## Source Files

| File | Format |
|---|---|
| `group_vars/imagebuilders/imagebuilder_build.yml` | YAML |

---

## OSBuild Composer Directories

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `osbuild_config_dir` | string | `"/etc/osbuild-composer/repositories"` | Directory where OSBuild Composer repository JSON definitions are stored on the Image Builder host. | OSBuild Composer service |
| `osbuild_toml_dir` | string | `"/etc/osbuild-composer/toml"` | Directory where OSBuild Composer TOML configuration files are stored on the Image Builder host. | OSBuild Composer service |
| `repo_file` | string | `"/etc/yum.repos.d/redhat.repo"` | Path to the system DNF/YUM repository file used as the source repository list for image builds. | Image build tasks |

---

## Target Image Registration

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `target_activationkey` | string | `"SOE9_JBoss"` | Satellite or RHSM activation key applied to images built by this host. Determines what content is available inside the built image. A commented alternative (`bootstrap9`) is also present for initial bootstrapping use cases. | Image build tasks |
| `target_organization` | string | `"Default_Organization"` | Satellite or RHSM organization name associated with the activation key used during image builds. | Image build tasks |
| `target_arch` | string | `"x86_64"` | CPU architecture of the target images to be built. Passed to OSBuild Composer to select the correct repository metadata. | Image build tasks |

---

## Target Cloud Repositories

| Variable | Type | Default | Description | Used by |
|---|---|---|---|---|
| `target_cloud_repos` | multiline string (JSON fragment) | Google Compute Engine and Google Cloud SDK repo entries | A JSON fragment appended to the OSBuild Composer repository definition for cloud image types. Each entry includes a `name`, `baseurl`, `check_gpg` flag, and `image_type_tags` list that gates inclusion to specific image types (e.g., `gce`). The leading comma is intentional — the fragment is embedded inside a larger JSON array. | OSBuild Composer repository configuration templates |
