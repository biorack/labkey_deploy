#!/bin/bash

set -euf -o pipefail

DB="${1:-}"
if [[ -z "$DB" ]]; then
  >&2 echo "ERROR: Usage $0 dbname"
  exit 1
fi

if [ "$( psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DB'" )" != '1' ]
then
  echo "Database does not exist. Not futhere action needed."
  exit 0
fi

psql << END
-- Disallow new connections
UPDATE pg_database SET datallowconn = 'false' WHERE datname = '$DB';
ALTER DATABASE $DB CONNECTION LIMIT 0;

-- Terminate existing connections
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB';
END

