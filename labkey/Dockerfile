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

#temp containter only used for building
FROM alpine:latest AS labkey_build

ARG LABKEY_MAJOR_VERSION=19
ARG LABKEY_MINOR_VERSION=3.0
ARG LABKEY_BUILD_VERSION=64757.2-community
ARG LABKEY_BUILD_HOME=/labkey/labkey
ARG CATALINA_BUILD_HOME=/labkey/apps/tomcat
ARG DOWNLOAD_URL_START=http://labkey.s3.amazonaws.com/downloads/general/r

ARG LABKEY_FULL_VERSION=$LABKEY_MAJOR_VERSION.$LABKEY_MINOR_VERSION-$LABKEY_BUILD_VERSION
ARG DOWNLOAD_URL_VERSION=${LABKEY_MAJOR_VERSION}.${LABKEY_MINOR_VERSION}

RUN apk add --update curl && \
    mkdir -p ${LABKEY_BUILD_HOME}
WORKDIR /labkey

RUN mkdir -p ${LABKEY_BUILD_HOME}/externalModules && \
    mkdir -p ${CATALINA_BUILD_HOME}/lib

RUN curl -LO ${DOWNLOAD_URL_START}/${DOWNLOAD_URL_VERSION}/LabKey${LABKEY_FULL_VERSION}-bin.tar.gz && \
    tar xzf LabKey${LABKEY_FULL_VERSION}-bin.tar.gz

RUN cp -R LabKey${LABKEY_FULL_VERSION}-bin/labkeywebapp ${LABKEY_BUILD_HOME} && \
    cp -R LabKey${LABKEY_FULL_VERSION}-bin/modules ${LABKEY_BUILD_HOME} && \
    cp -R LabKey${LABKEY_FULL_VERSION}-bin/pipeline-lib ${LABKEY_BUILD_HOME} && \
    cp LabKey${LABKEY_FULL_VERSION}-bin/tomcat-lib/* ${CATALINA_BUILD_HOME}/lib/

COPY bin ${LABKEY_BUILD_HOME}/bin
RUN chmod +x ${LABKEY_BUILD_HOME}/bin/*

# Build complete. Now compile release on final containter.
FROM tomcat:9-jdk13-openjdk-slim-buster

ARG LABKEY_BUILD_HOME=/labkey/labkey
ARG CATALINA_BUILD_HOME=/labkey/apps/tomcat

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y \
    graphviz \
    postgresql-client-11 \
    r-base \
    r-base-dev \
    xvfb && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf ${CATALINA_HOME}/webapps

ENV LABKEY_HOME=/usr/local/labkey

COPY --from=labkey_build ${LABKEY_BUILD_HOME} ${LABKEY_HOME}
COPY --from=labkey_build ${CATALINA_BUILD_HOME}/lib ${CATALINA_HOME}/lib

# labkey.xml will get moved later by start-labkey.sh based on $LABKEY_URL_PATH
COPY config/labkey.xml ${CATALINA_HOME}/conf/Catalina/localhost/labkey.xml

WORKDIR ${LABKEY_HOME}

ENV PATH="${PATH}:${LABKEY_HOME}/bin"
ENV DATABASE_HOST=db
ENV DATABASE_PORT=5432

ENTRYPOINT ["wait-for-system.sh"]
CMD ["start-labkey.sh"]
