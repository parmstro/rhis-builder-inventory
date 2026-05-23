# OpenShift Virtualization Vault Variables

Schema Version: 1.0.0

These variables will be used by `rhis-builder-ocp-virt-lz` (planned) to bootstrap OpenShift Virtualization infrastructure and by `rhis-builder-satellite` to configure the OCP Virt compute resource in Satellite for provisioning. OCP Virt enables VM workloads to run on OpenShift clusters alongside containerized workloads.

> **Tech preview:** The OpenShift Virtualization compute resource in Red Hat Satellite is available as a tech preview feature in Satellite 6.19. It is not yet supported for production use and will be fully supported in a future release.

> **Multiple cloud targets:** rhis supports multiple OpenShift Virtualization cluster targets. Variables for each target follow the pattern `<cloud_name><number>_<variable_name>_vault`. For example, `ocp_virt1_api_url_vault` is the API URL for the first OCP Virt target; a second target would use `ocp_virt2_api_url_vault`, and so on. Users can apply the same aliasing technique used throughout the vault file to extend their model with minimal duplication. Unique credentials per target are always recommended in production.

---

## OpenShift cluster credentials

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `ocp_virt_api_url_vault` | secret | The API URL of the OpenShift cluster hosting OCP Virt (e.g. `https://api.cluster.example.ca:6443`). | Found in the OpenShift console under the Help menu → Command line tools, or via `oc cluster-info`. | rhis-builder-satellite, rhis-builder-ocp-virt-lz |
| `ocp_virt_username_vault` | secret | Username for authenticating to the OpenShift API. Use a service account with appropriate RBAC permissions for VM management. | Create a dedicated OpenShift service account with `kubevirt.io:edit` or equivalent role binding. | rhis-builder-satellite, rhis-builder-ocp-virt-lz |
| `ocp_virt_password_vault` | secret | Password or token for the OpenShift service account. For token-based auth, use a long-lived service account token. **Set individually per deployment.** | Retrieve the service account token via `oc sa get-token <service-account> -n <namespace>`. | rhis-builder-satellite, rhis-builder-ocp-virt-lz |
| `ocp_virt_token_vault` | secret | Bearer token for OpenShift API authentication. Alternative to username/password. Takes precedence when set. | Generate via `oc create token <service-account> --duration=8760h -n <namespace>`. | rhis-builder-satellite, rhis-builder-ocp-virt-lz |

---

## Satellite OCP Virt compute resource

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `ocp_virt_namespace_vault` | secret | The OpenShift namespace (project) where Satellite will create VMs via OCP Virt. | Create a dedicated namespace: `oc new-project rhis-vms`. | rhis-builder-satellite |
| `ocp_virt_ca_cert_vault` | secret | The PEM-encoded CA certificate bundle for the OpenShift API TLS endpoint. Required if the cluster uses a private CA. | Retrieve via `oc get secret -n openshift-config-managed default-ingress-cert -o jsonpath='{.data.tls\.crt}' \| base64 -d` or from the cluster's kubeconfig. | rhis-builder-satellite |
