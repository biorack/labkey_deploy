#!/bin/bash

set -euf -o pipefail

PGHOST="${PGHOST:-db}"
PGUSER="${PGUSER:-postgres}"
DB="${PGDATABASE:-labkey}"

if [[ "${1-}" == "--help" || "${1-}" == "-h" ]]; then
  echo "$0 filename"
  echo "filename - a single database backup created with pg_dump"
  echo
  echo "Before running you should stop the labkey container by pausing"
  echo "orchestration on the labkey pod and then scale down the labkey"
  echo "pod to zero instances."
  exit 0
fi

BACKUP="$1"

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

file_exists_readable_not_empty_or_error "$BACKUP"

/dropdbconnections.sh "$DB"
dropdb --if-exists "$DB"
createdb "$DB"
pg_restore --single-transaction "--dbname=${DB}" "${BACKUP}"

