# main eclipse-temurin jre, which is debian-based
ARG FROM_REPO_IMAGE=eclipse-temurin
ARG FROM_TAG=17-jre

# uncomment for alpine-based eclipse-temurin jre
# ARG FROM_TAG=17-jre-alpine

FROM ${FROM_REPO_IMAGE}:${FROM_TAG} as base

LABEL maintainer="LabKey Systems Engineering <ops@labkey.com>"

FROM base

# this will assume whatever FROM_TAG was set in first stage above
ARG FROM_TAG

ARG DEBUG=
ARG LABKEY_VERSION
ARG LABKEY_DISTRIBUTION
ARG LABKEY_EK

# dependent ENVs declared separately
ENV POSTGRES_USER="postgres" \
    \
    LABKEY_PORT="8443" \
    LABKEY_HOME="/usr/local/labkey" \
    LABKEY_DEFAULT_DOMAIN="localhost" \
    LABKEY_SYSTEM_SHORT_NAME="Sirius Cybernetics" \
    \
    TOMCAT_BASE_DIR="/usr/local/tomcat/"

ENV LABKEY_SYSTEM_EMAIL_ADDRESS="noreply@${LABKEY_DEFAULT_DOMAIN}"

ENV DEBUG="${DEBUG}" \
    \
    CATALINA_HOME="${TOMCAT_BASE_DIR}" \
    \
    POSTGRES_PASSWORD= \
    POSTGRES_HOST="db" \
    POSTGRES_PORT="5432" \
    POSTGRES_DB="${POSTGRES_USER}" \
    POSTGRES_PARAMETERS= \
    \
    POSTGRES_MAX_TOTAL_CONNECTIONS=50 \
    POSTGRES_MAX_IDLE_CONNECTIONS=10 \
    POSTGRES_MAX_WAIT_MILLIS=120000 \
    POSTGRES_ACCESS_UNDERLYING_CONNECTIONS=true \
    POSTGRES_VALIDATION_QUERY="SELECT 1" \
    \
    LABKEY_VERSION="${LABKEY_VERSION}" \
    LABKEY_DISTRIBUTION="${LABKEY_DISTRIBUTION}" \
    LABKEY_EK="${LABKEY_EK}" \
    \
    LABKEY_FILES_ROOT="${LABKEY_HOME}/files" \
    \
    LABKEY_COMPANY_NAME="${LABKEY_SYSTEM_SHORT_NAME}" \
    LABKEY_SYSTEM_DESCRIPTION="${LABKEY_SYSTEM_SHORT_NAME}" \
    LABKEY_BASE_SERVER_URL="https://${LABKEY_DEFAULT_DOMAIN}:${LABKEY_PORT}" \
    \
    LABKEY_STARTUP_BASIC_EXTRA= \
    LABKEY_STARTUP_DISTRIBUTION_EXTRA= \
    \
    LABKEY_CREATE_INITIAL_USER= \
    LABKEY_INITIAL_USER_EMAIL="toor@localhost" \
    LABKEY_INITIAL_USER_ROLE="SiteAdminRole" \
    LABKEY_INITIAL_USER_GROUP="Administrators" \
    \
    LABKEY_CREATE_INITIAL_USER_APIKEY= \
    LABKEY_INITIAL_USER_APIKEY= \
    \
    LOG_LEVEL_TOMCAT="OFF" \
    LOG_LEVEL_SPRING_WEB="OFF" \
    LOG_LEVEL_SQL="OFF" \
    \
    TOMCAT_KEYSTORE_FILENAME="labkey.p12" \
    TOMCAT_KEYSTORE_FORMAT="PKCS12" \
    TOMCAT_KEYSTORE_ALIAS="tomcat" \
    \
    TOMCAT_SSL_CIPHERS="HIGH:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!kRSA:!EDH:!DHE:!DH:!CAMELLIA:!ARIA:!AESCCM:!SHA:!CHACHA20" \
    TOMCAT_SSL_ENABLED_PROTOCOLS="TLSv1.3,TLSv1.2" \
    TOMCAT_SSL_PROTOCOL="TLS" \
    \
    TOMCAT_ENABLE_ACCESS_LOG= 

ENV CERT_C="US" \
    CERT_ST="Washington" \
    CERT_L="Seattle" \
    CERT_O="${LABKEY_COMPANY_NAME}" \
    CERT_OU="IT" \
    CERT_CN="localhost" \
    \
    CSP_REPORT= \
    CSP_ENFORCE= \
    \
    SMTP_HOST="smtp" \
    SMTP_USER="root" \
    SMTP_PORT="25" \
    SMTP_PASSWORD= \
    SMTP_FROM="${LABKEY_SYSTEM_EMAIL_ADDRESS}" \
    SMTP_STARTTLS= \
    SMTP_AUTH="false" \
    \
    MAX_JVM_RAM_PERCENT="90.0" \
    \
    JAVA_PRE_JAR_EXTRA= \
    JAVA_POST_JAR_EXTRA= \
    JAVA_TMPDIR="/var/tmp" \
    JAVA_TIMEZONE="America/Los_Angeles" \
    \
    LOGGER_PATTERN="%-40.40logger{39}" \
    LOG_LEVEL_DEFAULT= \
    \
    LOG_LEVEL_LABKEY_DEFAULT= \
    LOG_LEVEL_API_MODULELOADER= \
    LOG_LEVEL_API_SETTINGS= \
    LOG_LEVEL_API_PIPELINE=

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y \
    graphviz \
    xvfb \
    tree \
    gettext

COPY entrypoint.sh /entrypoint.sh

WORKDIR ${LABKEY_HOME}

# add labkey jar
COPY labkeyServer.jar .
ENV PATH="${PATH}:${LABKEY_HOME}"

# add xvfb script
# COPY xvfb.sh .

# add spring properties
COPY application.properties config/

# add basic + distribution startup properties
COPY startup/basic.properties \
    startup/50_basic.properties

# add distribution startup properties
COPY "startup/${LABKEY_DISTRIBUTION}.properties" \
    startup/49_distribution.properties

# add logging config files
COPY log4j2.xml log4j2.xml

# install datadog tracing agent
RUN mkdir -p datadog \
    && wget -q -O datadog/dd-java-agent.jar https://dtdg.co/latest-java-tracer

VOLUME "${LABKEY_FILES_ROOT}/@files"
VOLUME "${LABKEY_HOME}/externalModules"
VOLUME "${LABKEY_HOME}/logs"

EXPOSE ${LABKEY_PORT}

STOPSIGNAL SIGTERM

RUN if [ -z "${DEBUG}" ]; then \
        find / -xdev -perm /6000 -type f -exec chmod a-s {} \; || true; \
    fi;

# shell form e.g. executed w/ /bin/sh -c
ENTRYPOINT ["/entrypoint.sh"]

###############################################################
####### Carryover from previous LIMS deployment ###############
###############################################################    

# FROM mambaorg/micromamba:1.4.9 as micromamba

# # setup micromamba so we can use conda to create isolated R environments
# ARG MAMBA_USER=labkey
# ARG MAMBA_USER_ID=1000
# ARG MAMBA_USER_GID=1000
# ENV MAMBA_USER=$MAMBA_USER
# ENV MAMBA_ROOT_PREFIX="/opt/conda"
# ENV MAMBA_EXE="/bin/micromamba"
# COPY --from=micromamba "$MAMBA_EXE" "$MAMBA_EXE"
# COPY --from=micromamba /usr/local/bin/_activate_current_env.sh /usr/local/bin/_activate_current_env.sh
# COPY --from=micromamba /usr/local/bin/_entrypoint.sh /usr/local/bin/_entrypoint.sh
# RUN echo "source /usr/local/bin/_activate_current_env.sh" >> /etc/skel/.bashrc && \
#     #groupadd -g "${MAMBA_USER_GID}" "${MAMBA_USER}" && \
#     #useradd -u "${MAMBA_USER_ID}" -g "${MAMBA_USER_GID}" -ms /bin/bash "${MAMBA_USER}" && \
#     echo "${MAMBA_USER}" > "/etc/arg_mamba_user" && \
#     mkdir -p "$MAMBA_ROOT_PREFIX/conda-meta" && \
#     chmod -R a+rwx "$MAMBA_ROOT_PREFIX" "/home" "/etc/arg_mamba_user" && \
#     :

# USER $MAMBA_USER

# COPY --chown=$MAMBA_USER:$MAMBA_USER python-lock.yaml /tmp/python-lock.yaml
# COPY --chown=$MAMBA_USER:$MAMBA_USER R_tidyverse-lock.yaml /tmp/R_tidyverse-lock.yaml
# COPY --chown=$MAMBA_USER:$MAMBA_USER R_smkosina01-lock.yaml /tmp/R_smkosina01-lock.yaml
# RUN micromamba create --yes --name python --file /tmp/python-lock.yaml && \
#     micromamba create --yes --name R_tidyverse --file /tmp/R_tidyverse-lock.yaml && \
#     micromamba create --yes --name R_smkosina01 --file /tmp/R_smkosina01-lock.yaml && \
#     micromamba run --name R_smkosina01 \
#         R --slave -e "install.packages('growthrates', repos='http://cran.us.r-project.org')" && \
#     micromamba clean --all --yes

###############################################################
####### Carryover from previous LIMS deployment ###############
###############################################################