#!/bin/bash
#
#
# Copyright (c) 2020-2021 Joint Genome Institute
#
# Copyright (c) 2016-2017 LabKey Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# This file has been modified by Joint Genome Institue to enhance security and
# increase configuration options.

# Start X Virtual Frame Buffer and Tomcat Services
#
# This entry point script will perform the following steps
# 1) Read secrets
#   - The required secrets are password for accessing LabKey database on
#     PostgreSQL server and Master Encryption Key used to access LabKey
#     PropertyStore
#   - The secrets are provided at RUN time using ENV variables 
#       * DATABASE_PASSWORD or DATABASE_PASSWORD_FILE
#       * MASTER_ENCRYPTION_KEY or MASTER_ENCRYPTION_KEY_FILE
# 2) Start X virtual frame buffer (required for R reports)
# 4) Using secrets read above start Tomcat server and the LabKey application
#

DATABASE_USER=${DATABASE_USER:-postgres}
DATABASE_NAME=${DATABASE_NAME:-labkey}

SMTP_HOST=${SMTP_HOST:-smtp}
SMTP_PORT=${SMTP_PORT:-25}
SMTP_USER=${SMTP_USER:-}

LABKEY_SERVER_HOSTNAME=${LABKEY_SERVER_HOSTNAME:-labkey}
LABKEY_HOME=${LABKEY_HOME:-/usr/local/labkey}
LABKEY_URL_PATH=${LABKEY_URL_PATH:-ROOT}

MAX_UPLOAD_SIZE=${MAX_UPLOAD_SIZE:-52428800}

export CATALINA_OPTS=${CATALINA_OPTS:-"-Xms2g -Xmx2g -XX:-HeapDumpOnOutOfMemoryError"}

if [ -z "$DATABASE_PASSWORD" ]
then
    echo "ERROR: DATABASE_PASSWORD environment variable does not exist. This is required to start LabKey Server"
    exit 1
fi

if [ -z "$MASTER_ENCRYPTION_KEY" ]
then
    echo "ERROR: MASTER_ENCRYPTION_KEY environment variable does not exist. This is required to start LabKey Server"
    exit 1
fi

# Pass parameters that will get used in labkey.xml
# but this method isn't appropriate for secrets, as the values will show up in the catalina log files
export JAVA_OPTS="${JAVA_OPTS} \
-Dlabkey.home=${LABKEY_HOME} \
-Ddatabase.host=${DATABASE_HOST} \
-Ddatabase.port=${DATABASE_PORT} \
-Ddatabase.user=${DATABASE_USER} \
-Ddatabase.name=${DATABASE_NAME} \
-Dsmtp.host=${SMTP_HOST} \
-Dsmtp.port=${SMTP_PORT} \
-Dsmtp.user=${SMTP_USER} \
-Dlabkey.server.hostname=${LABKEY_SERVER_HOSTNAME}" 

# this way prevents secrets from being logged
sed -i s/'@@DATABASE_PASSWORD@@'/"${DATABASE_PASSWORD}"/g ${CATALINA_HOME}/conf/Catalina/localhost/labkey.xml
sed -i s/'@@MASTER_ENCRYPTION_KEY@@'/"${MASTER_ENCRYPTION_KEY}"/g ${CATALINA_HOME}/conf/Catalina/localhost/labkey.xml

# Copy in the max upload size
if [ -f "${CATALINA_HOME}/webapps/manager/WEB-INF/web.xml" ]
then
	sed -i "s#.*max-file-size.*#\t<max-file-size>${MAX_UPLOAD_SIZE}</max-file-size>#g" ${CATALINA_HOME}/webapps/manager/WEB-INF/web.xml
	sed -i "s#.*max-request-size.*#\t<max-request-size>${MAX_UPLOAD_SIZE}</max-request-size>#g" ${CATALINA_HOME}/webapps/manager/WEB-INF/web.xml
fi

# Make sure the labkey.xml file is in the correct path location
>&2 echo "Labkey available at path ${LABKEY_URL_PATH}"
mv ${CATALINA_HOME}/conf/Catalina/localhost/labkey.xml ${CATALINA_HOME}/conf/Catalina/localhost/${LABKEY_URL_PATH}.xml

## Start X Virtual Frame Buffer for R
>&2 echo "Starting xvfb..."
xvfb.sh start

# Start Tomcat
>&2 echo "Starting Labkey"
catalina.sh run

