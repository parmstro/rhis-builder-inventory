#!/bin/bash

# This script exports the rhis-containers to tar for transfer to a disconnected network.
# default to AAP 2.4
ansiblever="2.4"
# Inuit word for packed snow used for building :-)
build="aniyu"

pull_registry="quay.io"
pull_registry_repo="parmstro"
pull_registry_login=""
pull_registry_token=""

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -a|--ansible-ver)
            ansiblever="$2"
            shift # Shift past the value
            ;;
        -p|--pull-registry)
            pull_registry="$2"
            shift
            ;;
        -r|--pull-registry-repo)
            pull_registry_repo="$2"
            shift
            ;;
        -u|--pull-registry-login)
            pull_registry_login="$2"
            shift
            ;;
        -t|--pull-registry-token)
            pull_registry_token="$2"
            shift
            ;; 
        *)
            echo "Unknown option: $1"
            echo "Usage: export_rhis_container.sh [options]"
            echo "Options:"
            echo "    --ansible-ver - specify the AAP API version - one of '2.4' (default) or '2.5' of the container to export"
            echo ""
            echo "    --pull-registry - the name of the remote registry to pull the image from (default: quay.io)"
            echo "    --pull-registry-repo - the name of the repo in the remote pull registry (default: parmstro)"
            echo "    --pull-registry-login - the login for the pull registry when required (e.g. mybot)"
            echo "    --pull-registry-token - the authentication token for the pull registry when required"
            echo ""
            echo "Specifying 'localhost' for either the pull or push registry will ignore the corresponding repo option."
            exit 1
            ;;
    esac
    shift # Shift past the option
done


# based on selection, either pull from the local host or pull from the remote registry
if [[ $ansiblever == '2.4' || $ansiblever == '2.5' ]]; then
    output_file="./rhis-provisioner-9-$ansiblever-latest.tar"
    if [[ -f $output_file ]]; then
        echo "The archive exists. Overwrite? (Y/n)"
        read delete
        if [[ $delete == 'Y' || $delete == 'y' || $delete == '' ]]; then
            echo "Overwriting..."
            rm -f $output_file
        else
            exit 0
        fi
    fi
    if [[ $pull_registry == 'localhost' ]]; then
        pull_location="localhost"
    else
        pull_location="$pull_registry/$pull_registry_repo"
        podman pull $pull_location/rhis-provisioner-9-$ansiblever:latest
    fi
    container_src="$pull_location/rhis-provisioner-9-$ansiblever:latest"
    echo ""
    echo "Archiving container as tarfile..."
    echo ""
    buildah push $container_src docker-archive:$output_file
    echo ""
    echo "Container archived to $output_file"
else
    echo "Unsupported ansible version. Select 2.4 or 2.5"
    exit 2
fi

