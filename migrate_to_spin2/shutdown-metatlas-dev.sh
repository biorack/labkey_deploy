#!/bin/bash

set -euf -o pipefail

RANCHER_ENVIRONMENT=dev-cattle

# pod names in rancher
APP="metlims-nersc/app"
DB_BACKUP="metlims-nersc/db-backup"
FILE_BACKUP="metlims-nersc/file-backup"

# mount points of the persistant volumes
FILES_MNT=/labkey_files
BACKUP_MNT=/pg_dump

TIMESTAMP=$(date +%Y%m%d%H%M)
DEST_DIR="${BACKUP_MNT}/${TIMESTAMP}"

module load spin

rancher stop "${APP}"

POSTGRES_PASSWORD=$(rancher exec -it metlims-nersc/db \
        find /run/secrets -type f -printf '%p\t' -exec cat {} \; | \
        grep db.metlims-nersc.postgres_password2 | \
        cut -f2 | \
        tr -d '\r')

# due to file permissions, the same container cannot tar up and copy off the files.
# must have root to tar up the files, as they are not readable by user
# but must run as a non-root user to be able to write to the global filesystem.
# So use two containers, first to tar up files and chmod a+rw
# second container then copies that tar file to the global filesystem

echo 'starting ubuntu container'
ID=$(rancher run \
        --name "${FILE_BACKUP}" \
        --cap-drop ALL \
        --volume "app.metlims-nersc:${FILES_MNT}" \
        ubuntu:20.04 \
        tail -f /dev/null)

echo 'waiting for ubuntu container'
rancher wait "${ID}"

FILES_TAR="${FILES_MNT}/labkey_files_${TIMESTAMP}.tar.gz"

echo 'starting to tar files'
rancher exec -it "${FILE_BACKUP}" \
        /bin/bash -c "tar czpf ${FILES_TAR} --exclude='labkey_files_*.tar.gz' -C ${FILES_MNT} . && chmod a+rw ${FILES_TAR}"

echo 'stoping ubuntu container'
rancher stop "${FILE_BACKUP}"

echo 'removing ubuntu container'
rancher rm "${FILE_BACKUP}"

echo 'starting postgres container'
ID=$(rancher run \
        --name "${DB_BACKUP}" \
        --user 94014:94014 \
        --cap-drop ALL \
        --env "PGPASSWORD=${POSTGRES_PASSWORD}" \
        --volume "/global/cfs/cdirs/metatlas/projects/lims_backups/pg_dump/:${BACKUP_MNT}" \
        --volume "app.metlims-nersc:${FILES_MNT}" \
        postgres:12 \
        tail -f /dev/null)

echo 'waiting for postgres container'
rancher wait "${ID}"

echo 'make timestamped directory for backups'
rancher exec -it "${DB_BACKUP}" \
        mkdir -p "${DEST_DIR}"

echo 'move tar to global filesystem'
rancher exec -it "${DB_BACKUP}" \
        cp "${FILES_TAR}" "${DEST_DIR}/"

echo 'dumping labkey database'
rancher exec -it "${DB_BACKUP}" \
        pg_dump -Fc -h db -U postgres --file "${DEST_DIR}/labkey_db_${TIMESTAMP}" labkey

echo 'stoping postgres container'
rancher stop "${DB_BACKUP}"

echo 'removing postgres container'
rancher rm "${DB_BACKUP}"

