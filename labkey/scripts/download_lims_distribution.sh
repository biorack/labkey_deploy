#!/bin/bash

# Check if the correct number of arguments was provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 lims_version_number lims_deploy_directory"
    exit 1
fi

# Construct the URL and define the location to save the file
url="https://lk-binaries.s3-us-west-2.amazonaws.com/downloads/release/community/${1%%-*}/LabKey$1-community-embedded.tar.gz"
location=$2/src/$(basename $url)

# Download the file
curl -o $location --create-dirs $url

# Move to the labkey repo directory and extract jar
tar xzvf $location --include='LabKey*labkeyServer*.jar' --strip-components 1 -C $2

# Remove the tar file
rm $location