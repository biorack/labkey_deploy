#!/bin/bash

set -euf -o pipefail

# next line from https://stackoverflow.com/questions/59895/
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

"${SCRIPT_DIR}"/../build.sh --image $(basename "${SCRIPT_DIR}") "$@"

