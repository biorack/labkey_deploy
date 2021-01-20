#!/bin/bash

set -euf -o pipefail

# mount points of the persistant volumes
FILES_MNT=/labkey_files
BACKUP_MNT=/backups
NAMESPACE="${NAMESPACE:-lims}"
PROJECT="${PROJECT:-c-tmq7p:p-gqfz8}" # default value is production cluster for m2650. Run 'rancher context switch' to get other values.

SPIN_MODULE="spin/2.0"
RANCHER_MAJOR_VERSION_REQUIRED=2

# default options to pass to kubectl
FLAGS="--namespace=${NAMESPACE}"

# location of backup directories on global file system (cori)
ROOT_BACKUP_DIR="/global/cfs/cdirs/metatlas/projects/lims_backups/pg_dump/"

# initialize variables to avoid errors
BACKUP_RESTORE=""
LABKEY=""
NEW=0
# default to the most recent directory with a timestamp for a name
TIMESTAMP=$(ls -1pt "${ROOT_BACKUP_DIR}" | grep -E "^2[0-9]{11}/$" | head -1 | tr -d '/')
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -b|--backup) BACKUP_RESTORE="$2"; shift ;;
    -l|--labkey) LABKEY="$2"; shift ;;
    -n|--new) NEW="1" ;;
    -t|--timestamp) TIMESTAMP="$2"; shift ;;
    -h|--help)
        echo -e "$0 [options]"
        echo ""
        echo "   -h, --help          show this command refernce"
	echo "   -b, --backup        source of backup_restore image (required)"
	echo "   -l, --labkey        source of labkey image (required)"
        echo "   -n, --new           delete all resources in namespace and start new instances"
	echo "   -t, --timestamp     timestamp of the backup to use (defaults to most recent)"
        exit 0
        ;;
    *)echo "Unknown parameter passed: $1"; exit 1 ;;
  esac
  shift
done

function required_flag_or_error() {
  if [[ -z  "$1" ]]; then
    >&2 echo "ERROR: ${2}"
    exit 1
  fi
}

function file_exists_readable_not_empty_or_error () {
  if [[ ! -e "$1" ]]; then
    >&2 echo "ERROR: file ${1} does not exist."
    exit 2 
  fi
  if [[ ! -r "$1" ]]; then
    >&2 echo "ERROR: file ${1} is not readable."
    exit 2 
  fi
  if [[ ! -s "$1" ]]; then
    >&2 echo "ERROR: file ${1} is empty."
    exit 2 
  fi
  return 0
}

function file_safe_secret_or_error() {
  if [ $(stat -c %a "$1") != 600 ]; then
    >&2 echo "ERROR: ${1} must have file permissions 600."
    exit 3 
  fi
  return 0
}

function create_file_with_substitution() {
  # arguments are input_filename, search_regex, replacement, output_filename
  sed -e "s%${2}%${3}%" $1 > $4
}

required_flag_or_error "$TIMESTAMP" "You are required to supply a backup timestamp via -t or --timestamp."
required_flag_or_error "$BACKUP_RESTORE" "You are required to supply a source for the backup_restore image via -b or --backup."
required_flag_or_error "$LABKEY" "You are required to supply a source for the labkey image via -l or --labkey."

# directory containing this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# root directory of this git repo
REPO_DIR="${SCRIPT_DIR}"

SECRETS_FILE="${REPO_DIR}/.secrets"
CERT_FILE="${REPO_DIR}/.tls.cert"
KEY_FILE="${REPO_DIR}/.tls.key"

# these are relative to the global filesystem:
ROOT_BACKUP_DIR="/global/cfs/cdirs/metatlas/projects/lims_backups/pg_dump/"
DB_BACKUP="${ROOT_BACKUP_DIR}/${TIMESTAMP}/labkey_db_${TIMESTAMP}"
FILES_BACKUP="${ROOT_BACKUP_DIR}/${TIMESTAMP}/labkey_files_${TIMESTAMP}.tar.gz"

# these are the backup file locations within the backup_restore container:
DB_BACKUP_INTERNAL="${BACKUP_MNT}/${TIMESTAMP}/labkey_db_${TIMESTAMP}"
FILES_BACKUP_INTERNAL="${BACKUP_MNT}/${TIMESTAMP}/labkey_files_${TIMESTAMP}.tar.gz"

file_exists_readable_not_empty_or_error "$DB_BACKUP"
file_exists_readable_not_empty_or_error "$FILES_BACKUP"
file_exists_readable_not_empty_or_error "$SECRETS_FILE"
file_exists_readable_not_empty_or_error "$CERT_FILE"
file_exists_readable_not_empty_or_error "$KEY_FILE"

file_safe_secret_or_error "${SECRETS_FILE}"
file_safe_secret_or_error "${KEY_FILE}"

DEPLOY_TMP="${SCRIPT_DIR}/deploy_tmp"
mkdir -p "$DEPLOY_TMP"
rm -rf "$DEPLOY_TMP/*"
create_file_with_substitution "${SCRIPT_DIR}/labkey/labkey.yaml.template" \
	"@@LABKEY_IMAGE_TAG@@" "$LABKEY" "${DEPLOY_TMP}/labkey.yaml"
create_file_with_substitution "${SCRIPT_DIR}/backup_restore/backup.yaml.template" \
	"@@BACKUP_RESTORE_IMAGE_TAG@@" "$BACKUP_RESTORE" "${DEPLOY_TMP}/backup.yaml"
create_file_with_substitution "${SCRIPT_DIR}/backup_restore/restore.yaml.template" \
	"@@BACKUP_RESTORE_IMAGE_TAG@@" "$BACKUP_RESTORE" "${DEPLOY_TMP}/restore.yaml"
create_file_with_substitution "${SCRIPT_DIR}/backup_restore/restore-root.yaml.template" \
	"@@BACKUP_RESTORE_IMAGE_TAG@@" "$BACKUP_RESTORE" "${DEPLOY_TMP}/restore-root.yaml"

source ${SECRETS_FILE}
if [[ -z "${POSTGRES_PASSWORD}" ]]; then
  >&2 echo "ERROR: Envionmental variable POSTGRES_PASSWORD not defined in .secrets file."
  exit 4
fi

if [[ -z "${MASTER_ENCRYPTION_KEY}" ]]; then
  >&2 echo "ERROR: Envionmental variable MASTER_ENCRYPTION_KEY not defined in .secrets file."
  exit 5
fi

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

if [[ "$NEW" -eq 1 ]]; then
  # clean up any existing resources to start a new deployment
  rancher kubectl delete deployments,statefulsets,cronjobs,services,secrets,pods --all $FLAGS
fi

# I think it is safe to delete secrets if they are recreated immediately
rancher kubectl delete secrets --all $FLAGS

# start building up the new instance
rancher kubectl create secret generic db $FLAGS \
	"--from-literal=postgres_password=${POSTGRES_PASSWORD}"
rancher kubectl create secret generic labkey $FLAGS \
	"--from-literal=master_encryption_key=${MASTER_ENCRYPTION_KEY}"
rancher kubectl create secret tls metatlas-cert $FLAGS \
	"--cert=${CERT_FILE}" \
	"--key=${KEY_FILE}"

## Create persistant volumes
# rancher kubectl apply $FLAGS -f "${REPO_DIR}/db/db-data.yaml"
# rancher kubectl apply $FLAGS -f "${REPO_DIR}/labkey/labkey-files.yaml"

## Create database pod
rancher kubectl apply $FLAGS -f "${REPO_DIR}/db/db.yaml"

## Create restore pods
rancher kubectl apply $FLAGS -f "${DEPLOY_TMP}/restore.yaml"
rancher kubectl apply $FLAGS -f "${DEPLOY_TMP}/restore-root.yaml"

rancher kubectl rollout status $FLAGS statefulset/db
if [[ "$NEW" -eq 1 ]]; then
  ## Restore labkey database
  rancher kubectl wait $FLAGS deployment.apps/restore --for=condition=available --timeout=60s
  rancher kubectl exec deployment.apps/restore $FLAGS -- /restore.sh "${DB_BACKUP_INTERNAL}"

  # Restore labkey files
  # The container that copies the archive from global filesystem to the
  # persistant volume cannot be running as root and therefore cannot
  # correctly set the ownership of the unarchived files. Therefore
  # a second pod (restore-root) does not mount the global filesystem
  # and can therefore untar the archive with the correct ownership.
  FILES_TEMP="${FILES_MNT}/$(basename ${FILES_BACKUP_INTERNAL})"
  rancher kubectl wait $FLAGS deployment.apps/restore-root --for=condition=available --timeout=60s
  rancher kubectl exec deployment.apps/restore-root $FLAGS -- rm -rf "${FILES_MNT}"/*
  rancher kubectl exec deployment.apps/restore-root $FLAGS -- chmod 777 "${FILES_MNT}"
  rancher kubectl wait $FLAGS deployment.apps/restore --for=condition=available --timeout=600s
  rancher kubectl exec deployment.apps/restore $FLAGS -- cp "${FILES_BACKUP_INTERNAL}" "${FILES_TEMP}"
  rancher kubectl exec deployment.apps/restore-root $FLAGS -- tar xzpf "${FILES_TEMP}" -C "${FILES_MNT}"
  rancher kubectl exec deployment.apps/restore-root $FLAGS -- rm "${FILES_TEMP}"
fi  
  
## Create labkey pod
rancher kubectl apply $FLAGS -f "${DEPLOY_TMP}/labkey.yaml"

## Create load balancer
rancher kubectl apply $FLAGS -f "${REPO_DIR}/labkey/lb.yaml"

## Create backup pod
rancher kubectl apply $FLAGS -f "${DEPLOY_TMP}/backup.yaml"

# scale down the pods used for restoring
rancher kubectl scale --replicas=0 deployment.apps/restore $FLAGS
rancher kubectl scale --replicas=0 deployment.apps/restore-root $FLAGS

rm -rf "${DEPLOY_TMP}"
