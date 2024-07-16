#!/bin/bash

set -eu -o pipefail
shopt -s failglob

print_if_debug() {
  if [[ -v DEBUG ]]; then
	echo "$0 DEBUG: $1"
  fi
}

print_var_if_debug() {
   print_if_debug "${1}=${!1}"
}

print_if_debug "Running LabKey backup job..."

PGHOST="${PGHOST:-db}"
PGUSER=${PGUSER:-postgres}
DB=${DB:-labkey}
BACKUP_ROOT="${BACKUP_ROOT:-/backups}"
FILES_GID="${FILES_GID:-60734}" # metatlas group on cori
FILES_SRC="${FILES_SRC:-/usr/local/labkey/files}"

TIMESTAMP=$(date +%Y%m%d%H%M)
BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"

for var_name in PGHOST PGUSER DB BACKUP_ROOT FILES_GID FILES_SRC TIMESTAMP BACKUP_DIR; do
  print_var_if_debug "$var_name"
done

print_if_debug "Making BACKUP_DIR..."
mkdir -p "${BACKUP_DIR}"
chmod 775 "${BACKUP_DIR}"

print_if_debug "Dumping database globals..."
pg_dumpall --globals-only | gzip > "${BACKUP_DIR}/postgres_globals_${TIMESTAMP}.gz"

print_if_debug "Dumping database ${DB}..."
pg_dump -Fc --file "${BACKUP_DIR}/labkey_db_${TIMESTAMP}" ${DB}

print_if_debug "Creating tar ball of non-database files..."
tar czpf "${BACKUP_DIR}/labkey_files_${TIMESTAMP}.tar.gz" -C "${FILES_SRC}" .

print_if_debug "Setting owner and permissions of generated files..."
chown -R "$(id -u):${FILES_GID}" "${BACKUP_DIR}"
chmod 660 ${BACKUP_DIR}/*

print_if_debug "LabKey backup job completed sucessfully."
