#!/bin/bash

make LABKEY_VERSION=24.3.4-6 DEBUG=1 NEW_DOWNLOAD=1 LABKEY_BUILD_DATE=$(date "+%Y-%m-%d-%H-%M") all
