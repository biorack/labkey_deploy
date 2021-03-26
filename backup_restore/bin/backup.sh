#!/bin/bash

set -eu -o pipefail
shopt -s failglob

PGHOST="${PGHOST:-db}"
PGUSER=${PGUSER:-postgres}
DB=${DB:-labkey}
BACKUP_ROOT="${BACKUP_ROOT:-/backups}"
FILES_GID="${FILES_GID:-60734}" # metatlas group on cori
FILES_SRC="${FILES_SRC:-/usr/local/labkey/files}"

TIMESTAMP=$(date +%Y%m%d%H%M)
BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"
mkdir -p "${BACKUP_DIR}"
chmod 775 "${BACKUP_DIR}"

pg_dumpall --globals-only | gzip > "${BACKUP_DIR}/postgres_globals_${TIMESTAMP}.gz"
pg_dump -Fc --file "${BACKUP_DIR}/labkey_db_${TIMESTAMP}" ${DB}
tar czpf "${BACKUP_DIR}/labkey_files_${TIMESTAMP}.tar.gz" -C "${FILES_SRC}" .

chown -R "$(id -u):${FILES_GID}" "${BACKUP_DIR}"
chmod 660 ${BACKUP_DIR}/*
