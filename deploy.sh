#!/bin/bash

set -eo pipefail

if [ -z $AWS_ACCOUNT_ID ]; then
    echo "AWS_ACCOUNT_ID environment variable is not set."
    exit 1
fi

if [ -z $AWS_DEFAULT_REGION ]; then
    echo "AWS_DEFAULT_REGION environment variable is not set."
    exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
ECR_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
COLOR_TELLER_IMAGE=${COLOR_TELLER_IMAGE:-"${ECR_URL}/colorteller"}
GO_PROXY=${GO_PROXY:-"https://proxy.golang.org"}
PLATFORMS=${PLATFORMS:-"linux/amd64,linux/arm64"}
AWS_CLI_VERSION=$(aws --version 2>&1 | cut -d/ -f2 | cut -d. -f1)

ecr_login() {
    if [ $AWS_CLI_VERSION -gt 1 ]; then
        aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | \
            docker login --username AWS --password-stdin ${ECR_URL}
    else
        $(aws ecr get-login --no-include-email)
    fi
}

describe_create_ecr_registry() {
    local repo_name=$1
    local region=$2
    aws ecr describe-repositories --repository-names ${repo_name} --region ${region} \
        || aws ecr create-repository --repository-name ${repo_name} --region ${region}
}

ensure_buildx_builder() {
    # The default "docker" driver can't produce multi-platform images,
    # so use (or create) a docker-container builder.
    local builder=colorapp-multiarch
    docker buildx inspect ${builder} >/dev/null 2>&1 \
        || docker buildx create --name ${builder} --driver docker-container >/dev/null
    docker buildx use ${builder}
}

ecr_login
describe_create_ecr_registry colorteller ${AWS_DEFAULT_REGION}

# build and push a multi-arch image (a manifest list can't be loaded into the
# local image store, so buildx pushes it directly to the registry)
ensure_buildx_builder
docker buildx build \
    --platform ${PLATFORMS} \
    --build-arg GO_PROXY=$GO_PROXY \
    -t $COLOR_TELLER_IMAGE \
    --push \
    ${DIR}

