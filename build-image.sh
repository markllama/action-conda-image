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

    # Quit fast if no registry password is provided
    [ -n "${REGISTRY_PASSWORD}" ] || fatal "missing required parameter: registry-token"

    # Quit fast if env file isn't provided
    [ -f ${CONDA_ENV} ] || fatal "missing required file: ${CONDA_ENV}"

    login_to_registry ${REGISTRY_NAME} ${REGISTRY_USERNAME} ${REGISTRY_PASSWORD} ||
        fatal "Error logging into registry ${REGISTRY_NAME}"

    echo REGISTR
    local image_path=${REGISTRY_NAME}/${IMAGE_NAME}
    echo "image_path=${image_path}"
    local hash_tag="v7-$(conda_env_hash ${CONDA_ENV} ${CONDA_PYTHON})"
    echo "hash_tag={hash_tag}"
    
    # The image needs rebuilding if:
    #   The user requests rebuild
    #   The image does not exist with the appropriate tag
    #   Or the image does not exist with the appropriate hash
    #   Or the two images are not identical

    local hashed_digest=$(image_digest ${image_path}/${hash_tag})
    echo "hashed_digest=${hashed_digest}"
    if force_build || [ "${hashed_digest}" == 'unknown' ] ; then
        local build_dir=${GITHUB_ACTION_PATH}/build
        mkdir -p ${build_dir}
        prepare_conda_rc ${CONDA_RC} > ${build_dir}/condarc.yaml
        prepare_conda_env ${CONDA_ENV} ${CONDA_PYTHON} > ${build_dir}/environment.yaml
        
        echo "building ${image_path}:${hash_tag}"
        #echo "building ${image_path}:${IMAGE_TAG}"
        build_image ${image_path} ${hash_tag} ${IMAGE_TAG} ${REGISTRY_PASSWORD}
    else
        local tagged_digest=$(image_digest ${image_path}/${IMAGE_TAG} 2>/dev/null)
        echo "tagged_digest=${tagged_digest}"
        if [ "${tagged_digest}" == "${hashed_digest}" ] ; then
            echo "re-tagging the existing image: ${hash_tag} -> ${IMAGE_TAG}"
            retag_image ${image_path} ${hash_tag} ${IMAGE_TAG}
        else
            echo "cache exists: using it"
        fi
    fi
    
    echo "image=${image_path}/${hash_tag}" >> ${GITHUB_OUTPUT}
}

function fatal() {
    local message="$1"
    
    echo "FATAL: ${message}"
    exit 1
}

function login_to_registry() {
    local registry=$1
    local username=$2
    local password=$3

    echo ${password} | ${DOCKER} login ${registry} --username ${username} --password-stdin
}

function force_build() {
    [ "${FORCE_BUILD}" == "true" ]
}

# A cached image must exist with the provided name *and* tag
function image_digest() {
    local image_path=$1

    ${DOCKER} manifest inspect ${image_path} 2>/dev/null || echo "unknown"    
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
    local rc_file=$1

    if [ -n "${rc_file}" -a -r ${rc_file} ] ; then
        cat ${rc_file}
    else
        cat <<EOF
channels:
  - conda-forge
EOF
    fi    
}

function prepare_conda_env() {
    local env_file=$1
    local new_version=$2

    # get the python version string from the env file (if set)
    local old_version=$(yq eval '.dependencies[] | select(test("^python( |$)"))' ${env_file})

    if [ "${old_version}x" == 'x' ] ; then
        # The python version is not specified: Append it
        yq eval ".dependencies += [\"python == ${new_version}\"]"
    else
        # replace the default python version with the provided value
        local python_index=$(yq ".dependencies[] | select(test(\"${old_version}\")) | path | .[-1]" ${env_file})
        yq eval ".dependencies[${python_index}] |= \"python ==${new_version}\"" ${env_file}
    fi
}

function build_image() {
    local image_path=$1
    local hash_tag=$2
    local python_tag=$3
    local token=$4

    docker buildx build \
           --no-cache \
           --pull \
           --push \
           --build-arg PULL_TOKEN="${token}" \
           --tag "${image_path}:${python_tag}" \
           --tag "${image_path}:${hash_tag}" \
           ${GITHUB_ACTION_PATH} ||
        fatal "docker build failed"
}

function retag_image() {
    local image_path=$1
    local hash_tag=$2
    local python_tag=$3

    ${DOCKER} pull ${image_path}:${hash_tag} ||
        fatal "failed to pull existing image: ${image_path}:${hash_tag}"
    ${DOCKER} tag ${image_path}:${hash_tag} ${image_path}:${python_tag} ||
        fatal "failed to tag existing image: ${image_path}:${hash_tag} as ${image_path}:${python_tag}"
    ${DOCKER} push ${image_path}:${python_tag} ||
        fatal "failed to push retagged image: ${image_path}:${python_tag}"
}

# =========
# CALL MAIN
# =========
main $*
