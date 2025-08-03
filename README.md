# rhis-builder-inventory
Provide the configuration definitions to the rhis-provisioner container for all RHIS repositories for a given Organization including:

* external_tasks directory
    * this folder will contain tasks external to RHIS repositories that may be needed by the customer to prepare an environment or extend the RHIS environment.

* files directory
    * this folder contains files required by RHIS to build the environment. Examples are the OpenSCAP contents and tailoring files and scripts necessary to install roles consumed by the RHIS Satellite installation.

* group_vars directory
    * this folder contains a folder for each of the groups in the inventory that require group specific configuration. Each group's folder will contain the variable files necessary for that group's configuration. All files in the folders with a yaml or yml extension will be consumed by RHIS plays when executing against the specified group systems.

* host_vars directory
    * this folder contains a folder for each of the hosts in the inventory that require host specific configuration. Each host's folder will contain the variable files necessary for that host's configuration. All files in the folders with a yaml or yml extension will be consumed by RHIS plays when executing against the specified host systems.

* inventory directory
    * an inventory folder is used to contain one or more inventory files for the organization (e.g. a DEV inventory vs. a QA inventory). Only one inventory file is used at a time. 

* templates directory
    * this folder contains templates required by RHIS to build the environment. Examples are all the Satellite provisioning, job and partition table templates. You can modify or extend these configurations by addin your own templates, or customizing existing templates. The example.ca organization templates are provided as examples and can be used directly in your own configurations.

* vars directory
    * this folder contains vars files to be used in the RHIS build environment that are:
        * not secrets
        * are not specific to a particular group or host. There should be very few of these!

* vault directory
    * the vault folder contains your secrets files, in particular, your rhis_builder_vault.yml file.

