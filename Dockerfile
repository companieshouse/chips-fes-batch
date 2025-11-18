#############################
# 1) BUILDER STAGE
#############################
FROM 300288021642.dkr.ecr.eu-west-2.amazonaws.com/ch-serverjre:2.0.0 AS builder

# These ARGS are NOT stored in final image
ARG ARTIFACTORY_URL
ARG ARTIFACTORY_USERNAME
ARG ARTIFACTORY_PASSWORD

ENV FES_HOME=/apps/fes \
    ARTIFACTORY_BASE_URL=${ARTIFACTORY_URL}/virtual-release

RUN mkdir -p /apps && \
    chmod a+xr /apps && \
    useradd -d ${FES_HOME} -m -s /bin/bash fes

USER fes

# Copy batch code
COPY --chown=fes fes-batch ${FES_HOME}/

# Download JARs into builder (secrets do NOT leak because builder is not copied fully)
RUN mkdir -p ${FES_HOME}/libs && \
    mkdir -p ${FES_HOME}/fes-file-loader && \
    cd ${FES_HOME}/libs && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" \
        "${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/fes-file-loader/2.0.0/fes-file-loader-2.0.0.jar" \
        -o ${FES_HOME}/fes-file-loader/fes-file-loader.jar && \
    chmod -R 750 ${FES_HOME}/*

#############################
# 2) RUNTIME STAGE
#############################
FROM 300288021642.dkr.ecr.eu-west-2.amazonaws.com/ch-serverjre:2.0.0

ENV FES_HOME=/apps/fes

# Install OL8 packages
RUN dnf install -y oracle-instantclient-release-el8 && \
    dnf install -y \
        oracle-instantclient-basic \
        oracle-instantclient-sqlplus \
        gettext \
        cronie \
        openssh-clients \
        xmlstarlet \
        dos2unix \
        jq \
        ftp && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# Create user
RUN mkdir -p /apps && \
    chmod a+xr /apps && \
    useradd -u 2001 -d ${FES_HOME} -m -s /bin/bash fes

USER fes

# Copy everything from the builder stage EXCEPT secrets
COPY --from=builder --chown=fes ${FES_HOME} ${FES_HOME}

WORKDIR ${FES_HOME}

USER root
CMD ["bash"]
