#!/bin/bash

podman pull quay.io/parmstro/rhis-provisioner-9-2.4:latest
podman tag  quay.io/parmstro/rhis-provisioner-9-2.4:latest localhost/rhis-provisioner-9-2.4:latest
podman pull quay.io/parmstro/rhis-provisioner-9-2.5:latest
podman tag  quay.io/parmstro/rhis-provisioner-9-2.5:latest localhost/rhis-provisioner-9-2.5:latest

echo "All containers refreshed!"
