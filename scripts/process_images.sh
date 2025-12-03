#!/usr/bin/env bash
set -euo pipefail
COMPOSE_FILE="docker-compose.yml"
REGISTRY="${REGISTRY:-ghcr.io}"
REGISTRY_USER="${REGISTRY_USER:-}"
REGISTRY_TOKEN="${REGISTRY_TOKEN:-}"
COSIGN_PRIVATE_KEY_B64="${COSIGN_PRIVATE_KEY_B64:-}"
COSIGN_PUBLIC_KEY_B64="${COSIGN_PUBLIC_KEY_B64:-}"
TMP_DIR="$(mktemp -d)"
trap "rm -rf ${TMP_DIR}" EXIT
if [ -n "${COSIGN_PRIVATE_KEY_B64}" ]
then
    echo "${COSIGN_PRIVATE_KEY_B64}" | base64 -d > "${TMP_DIR}/cosign.key"
    chmod 600 "${TMP_DIR}/cosign.key"
fi
if [ -n "${COSIGN_PUBLIC_KEY_B64}" ]
then
    echo "${COSIGN_PUBLIC_KEY_B64}" | base64 -d > "${TMP_DIR}/cosign.pub"
fi
docker login "${REGISTRY}" -u "${REGISTRY_USER}" --password-stdin <<< "${REGISTRY_TOKEN}"
IMAGES_FILE="${TMP_DIR}/images.txt"
grep -E '^\s*image:' "${COMPOSE_FILE}" | sed -E 's/^\s*image:\s*//g' | tr -d '"' | sort -u > "${IMAGES_FILE}"
while IFS= read -r IMAGE
do
    if [ -z "${IMAGE}" ]
    then
        continue
    fi
    docker pull "${IMAGE}"
    trivy image --exit-code 1 --severity HIGH,CRITICAL "${IMAGE}"
    IMAGE_NAME="$(echo "${IMAGE}" | awk -F/ '{print $NF}' | sed 's/:/-/g')"
    TAG="$(echo "${IMAGE}" | awk -F: '{if (NF>1) print $NF; else print "latest"}')"
    TARGET_IMAGE="${REGISTRY}/${GITHUB_REPOSITORY_OWNER}/${IMAGE_NAME}:${TAG}"
    docker tag "${IMAGE}" "${TARGET_IMAGE}"
    docker push "${TARGET_IMAGE}"
    if [ -f "${TMP_DIR}/cosign.key" ]
    then
        cosign sign --key "${TMP_DIR}/cosign.key" "${TARGET_IMAGE}"
        cosign verify --key "${TMP_DIR}/cosign.pub" "${TARGET_IMAGE}"
    fi
done < "${IMAGES_FILE}"
