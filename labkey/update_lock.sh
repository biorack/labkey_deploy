#!/bin/bash

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [ "$#" -ne 1 ]; then
    echo "Usage $0 environment.yaml"
    exit 1
fi

docker run -it --rm -v "${script_dir}:/tmp" -w '/tmp' "doejgi/conda-lock:latest" \
     conda-lock -f "$1" -p linux-64 --lockfile "${1%.yaml}-lock.yaml"
