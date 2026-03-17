# rhis-builder-inventory

<<<<<<< Updated upstream
=======
### Getting started fast
---
You need a system with git and podman tools.
VSCode is very helpful.
Having ansible language, ansible linter and wolfmah's ansible-vault inline is also super useful.

We are currently running fedora and rhel 9.latest systems. Your mileage may vary.

Get this repository:
```
wget https://github.com/parmstro/rhis-builder-inventory/archive/refs/heads/main.zip
unzip main.zip
mv rhis-builder-inventory-main rhis-builder-inventory   # rename it for convenience
cd rhis-builder-inventory
git init -b main                                        # you should ensure that the branch is main
git add * --all
git commit -m "Initial commit"
git remote add origin https://github.com/<your_org_or_login>/rhis-builder-inventory.git  # or whatever your url is
git remote -v
git push -u origin main
```

Review and edit inventory_basevars.yml file, then run the inventory_update shell script.
```
./inventory_update.sh
```
inventory_update.sh will build a new directory for your domain under the executing directory. The directory will contain the customized version of the sample RHIS build configuration based on the parameters you have provided in inventory_basevars.yml.
This is not meant to be a full customization facility yet, but rather a way to help you get started quickly in your own environment.

The inventory_update script will also create a custom script to pull and launch the rhis-provisioner container and connect to your inventory. 

See the 

See below for information on customizing your build further.

## What is in this repository
>>>>>>> Stashed changes
NOTE:
The rhis-builder-inventory now contains a version.txt file. Its purpose is to allow users to recognize change and updates to the schema and to help align the sample data with the rhis-provisioner container. This capabiloty will be enhanced through releases with the intention of eventually providing configuration validation. As we consume a huge number of projects under rhis-builder this task will be ongoing.



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

