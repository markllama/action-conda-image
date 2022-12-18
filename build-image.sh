#!/bin/bash
#
# === Environment Variables ===
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

function main() {
    echo "I am running!"
    echo "=== BEGIN Environment ==="
    env | sort
    echo "===  END  Environment ==="
}

main $*

echo "image-id=testvalue"
