#!/bin/bash

# Normal mode
make LABKEY_VERSION=24.7.0-1 NEW_DOWNLOAD=0 LABKEY_BUILD_DATE=$(date "+%Y-%m-%d-%H-%M") all

# Debug mode
#make LABKEY_VERSION=24.3.4-6 NEW_DOWNLOAD=0 DEBUG=1 LABKEY_BUILD_DATE=$(date "+%Y-%m-%d-%H-%M") all
