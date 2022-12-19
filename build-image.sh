#!/bin/bash
#
# === Environment Variables ===
# VERBOSE
# DEBUG

# GITHUB_TOKEN

# REGISTRY_NAME
# REGISTRY_USERNAME
# REGISTRY_PASSWORD

# IMAGE_NAME
# IMAGE_TAG
# IMAGE_CACHED

# CONDA_RC
# CONDA_ENV
# CONDA_PYTHON_VERSION

: ${DOCKER:=docker}

function main() {
    login_to_registry ${REGISTRY_NAME} ${REGISTRY_USERNAME} ${REGISTRY_PASSWORD} ||
        fail "Error logging into registry ${REGISTRY_NAME}"

    local image_path=${REGISTRY_NAME}/${IMAGE_NAME}
    local image_hash=$(conda_env_hash ${CONDA_ENV} ${CONDA_PYTHON_VERSION})

    # The image needs rebuilding if:
    #   The user requests rebuild
    #   The image does not exist with the appropriate tag
    #   Or the image does not exist with the appropriate hash
    #   Or the two images are not identical
    if !use_cached_image ||
            !(image_exists ${image_path}/${IMAGE_TAG} && image_exists ${image_path}/${image_hash})
    then 
        prepare_conda_rc
        prepare_conda_env
        build_image
    fi

    # The image is not cached or the caller requires rebuild
    echo "image=${image_path}/${image_hash}" >> ${GITHUB_OUTPUT}
    
}

function fail() {
    local message="$1"
    
    echo "FAIL: ${message}"
    exit 1
}

function login_to_registry() {
    local registry=$1
    local username=$2
    local password=$3

    echo ${password} | ${DOCKER} login ${registry} --username ${username} --password-stdin
}

function use_cached_image() {
    [ "${IMAGE_CACHED}" == "true" ]
}

# A cached image must exist with the provided name *and* tag
function image_exists() {
    local image_name=$1

    ${DOCKER} manifest inspect ${image_name}
}

# Generate a hash using a conda env file and the desired Python version string
function conda_env_hash() {
    local conda_env_file=$1
    local conda_python_version=$2

    # Add one line to the end of the file
    sed -e "\$aPYTHON_VERSION=${conda_python_version}" ${conda_env_file} |
        sha256sum |
        cut -d' ' -f1
}

#
function prepare_conda_rc() {
    echo Preparing condarc file
}

function prepare_conda_env() {
    echo Preparing conda environment file
}

function build_image() {
    echo building image
}


main $*

echo "image-id=testvalue"
