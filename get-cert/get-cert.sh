#!/bin/bash

set -euf -o pipefail

# mount points of the persistant volumes
NAMESPACE="${NAMESPACE:-lims}"
PROJECT="${PROJECT:-c-tmq7p:p-gqfz8}" # default value is production cluster for m2650. Run 'rancher context switch' to get other values.

SPIN_MODULE="spin/2.0"
RANCHER_MAJOR_VERSION_REQUIRED=2

# default options to pass to kubectl
FLAGS="--namespace=${NAMESPACE}"

# directory containing this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# root directory of this git repo
REPO_DIR="$(dirname ${SCRIPT_DIR})"

CERT_FILE="${REPO_DIR}/.tls.cert"
KEY_FILE="${REPO_DIR}/.tls.key"

if declare -F module; then
  module load "${SPIN_MODULE}"
fi

if ! which rancher; then
  >&2 echo "ERROR: Required program 'rancher' not found."
  exit 6
fi

RANCHER_VERSION=$(rancher --version | sed -e 's/rancher version v\([0-9.]\+\)/\1/')
RANCHER_MAJOR_VERSION="${RANCHER_VERSION%%.*}"

if [[ "${RANCHER_MAJOR_VERSION}" -ne "${RANCHER_MAJOR_VERSION_REQUIRED}" ]]; then
  >&2 echo "ERROR: rancher v${RANCHER_MAJOR_VERSION_REQUIRED}.x required, version v${RANCHER_VERSION} found."
  exit 7
fi

if ! rancher project; then
  >&2 echo "ERROR: No rancher authentication token is present."
  exit 8 
fi

rancher context switch "${PROJECT}"

if ! rancher inspect --type namespace "${NAMESPACE}"; then
  rancher namespace create "${NAMESPACE}"
fi

## Create get-cert pod
rancher kubectl apply $FLAGS -f "${REPO_DIR}/get-cert/get-cert.yaml"
rancher kubectl scale --replicas=1 --namespace=lims deployment.apps/get-cert

echo 'add load balancer via web UI before continuing.'

rancher kubectl exec get-cert $FLAGS -i -t -- certbot certonly
