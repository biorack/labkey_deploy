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

ARG BASE_IMAGE="tomcat:9-jdk17-temurin-focal"

# temp image that we will copy some files from
FROM mambaorg/micromamba:0.24.0 as micromamba

#temp containter only used for building
FROM curlimages/curl:7.83.1 as labkey_build

ARG LABKEY_EDITION="community"
ARG LABKEY_MAJOR_VERSION="22"
ARG LABKEY_MINOR_VERSION="3"
ARG LABKEY_PATCH_VERSION="4"
ARG LABKEY_BUILD_NUM="6"
ARG LABKEY_VERSION="${LABKEY_MAJOR_VERSION}.${LABKEY_MINOR_VERSION}.${LABKEY_PATCH_VERSION}"
ARG LABKEY_DISTRIBUTION="${LABKEY_VERSION}-${LABKEY_BUILD_NUM}-${LABKEY_EDITION}"
ARG LABKEY_BUILD_HOME="/labkey/labkey"
ARG CATALINA_BUILD_HOME="/labkey/apps/tomcat"
ARG DOWNLOAD_URL_START="https://lk-binaries.s3-us-west-2.amazonaws.com/downloads/release"
ARG DOWNLOAD_URL="${DOWNLOAD_URL_START}/${LABKEY_EDITION}/${LABKEY_VERSION}/LabKey${LABKEY_DISTRIBUTION}.tar.gz"
ARG DOWNLOAD_PATH="/tmp/labkey.tar.gz"

USER root

RUN mkdir -p "${LABKEY_BUILD_HOME}/externalModules" "${CATALINA_BUILD_HOME}/lib" && \
    curl --silent --location -o "$DOWNLOAD_PATH" "$DOWNLOAD_URL" && \
    cd "$(dirname "$LABKEY_BUILD_HOME")" && \
    tar -xzf "$DOWNLOAD_PATH" && \
    cp -R LabKey${LABKEY_DISTRIBUTION}/labkeywebapp ${LABKEY_BUILD_HOME} && \
    cp -R LabKey${LABKEY_DISTRIBUTION}/modules ${LABKEY_BUILD_HOME} && \
    cp -R LabKey${LABKEY_DISTRIBUTION}/pipeline-lib ${LABKEY_BUILD_HOME} && \
    cp LabKey${LABKEY_DISTRIBUTION}/tomcat-lib/* ${CATALINA_BUILD_HOME}/lib/

COPY bin ${LABKEY_BUILD_HOME}/bin
RUN chmod +x ${LABKEY_BUILD_HOME}/bin/*

# Build complete. Now compile release on final containter.
FROM "$BASE_IMAGE"

ARG LABKEY_BUILD_HOME=/labkey/labkey
ARG CATALINA_BUILD_HOME=/labkey/apps/tomcat

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y \
    graphviz \
    xvfb && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf ${CATALINA_HOME}/webapps

# setup micromamba so we can use conda to create isolated R environments
ARG MAMBA_USER=labkey
ARG MAMBA_USER_ID=1000
ARG MAMBA_USER_GID=1000
ENV MAMBA_USER=$MAMBA_USER
ENV MAMBA_ROOT_PREFIX="/opt/conda"
ENV MAMBA_EXE="/bin/micromamba"
COPY --from=micromamba "$MAMBA_EXE" "$MAMBA_EXE"
COPY --from=micromamba /usr/local/bin/_activate_current_env.sh /usr/local/bin/_activate_current_env.sh
COPY --from=micromamba /usr/local/bin/_entrypoint.sh /usr/local/bin/_entrypoint.sh
COPY --from=micromamba /usr/local/bin/_activate_current_env.sh /usr/local/bin/_activate_current_env.sh
RUN echo "source /usr/local/bin/_activate_current_env.sh" >> /etc/skel/.bashrc && \
    groupadd -g "${MAMBA_USER_GID}" "${MAMBA_USER}" && \
    useradd -u "${MAMBA_USER_ID}" -g "${MAMBA_USER_GID}" -ms /bin/bash "${MAMBA_USER}" && \
    echo "${MAMBA_USER}" > "/etc/arg_mamba_user" && \
    mkdir -p "$MAMBA_ROOT_PREFIX/conda-meta" && \
    chmod -R a+rwx "$MAMBA_ROOT_PREFIX" "/home" "/etc/arg_mamba_user" && \
    :

ENV LABKEY_HOME=/usr/local/labkey

# Session timeout to 1 week. Default was 30 minutes
RUN sed 's%<session-timeout>.*</session-timeout>%<session-timeout>10080</session-timeout>%' -i /usr/local/tomcat/conf/web.xml

COPY --from=labkey_build ${LABKEY_BUILD_HOME} ${LABKEY_HOME}
COPY --from=labkey_build ${CATALINA_BUILD_HOME}/lib ${CATALINA_HOME}/lib

# labkey.xml will get moved later by start-labkey.sh based on $LABKEY_URL_PATH
COPY config/labkey.xml ${CATALINA_HOME}/conf/Catalina/localhost/labkey.xml

WORKDIR ${LABKEY_HOME}

ENV PATH="${PATH}:${LABKEY_HOME}/bin"
ENV DATABASE_HOST=db
ENV DATABASE_PORT=5432

USER $MAMBA_USER

COPY --chown=$MAMBA_USER:$MAMBA_USER python.lock /tmp/python.lock
COPY --chown=$MAMBA_USER:$MAMBA_USER R_tidyverse.lock /tmp/R_tidyverse.lock
COPY --chown=$MAMBA_USER:$MAMBA_USER R_smkosina01.lock /tmp/R_smkosina01.lock
RUN micromamba create --yes --name python --file /tmp/python.lock && \
    micromamba create --yes --name R_tidyverse --file /tmp/R_tidyverse.lock && \
    micromamba create --yes --name R_smkosina01 --file /tmp/R_smkosina01.lock && \
    micromamba run --name R_smkosina01 \
        R --slave -e "install.packages('growthrates', repos='http://cran.us.r-project.org')" && \
    micromamba clean --all --yes

ENTRYPOINT ["wait-for-system.sh"]
CMD ["start-labkey.sh"]
