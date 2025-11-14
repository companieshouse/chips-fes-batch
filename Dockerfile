# Using the newer Java 21 runtime image
FROM 300288021642.dkr.ecr.eu-west-2.amazonaws.com/ch-serverjre:2.0.0

ARG ARTIFACTORY_URL
ARG ARTIFACTORY_USERNAME
ARG ARTIFACTORY_PASSWORD

# Environment variables
ENV FES_HOME=/apps/fes \
    ARTIFACTORY_BASE_URL=${ARTIFACTORY_URL}/virtual-release

# Install required packages (for Oracle Linux 8 base)
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

# Set up FES home and user
RUN mkdir -p /apps && \
    chmod a+xr /apps && \
    useradd -u 2001 -d ${FES_HOME} -m -s /bin/bash fes

USER fes

# Copy batch jobs
COPY --chown=fes fes-batch ${FES_HOME}/

# Download the batch libs and set permissions
RUN mkdir -p ${FES_HOME}/libs && \
    mkdir -p ${FES_HOME}/fes-file-loader && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" \
        "${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/fes-file-loader/2.0.0/fes-file-loader-2.0.0.jar" \
        -o "${FES_HOME}/fes-file-loader/fes-file-loader.jar" && \
    chmod -R 750 ${FES_HOME}/*

# Set working directory
WORKDIR $FES_HOME

# Use root to allow future maintenance if needed
USER root

# Default command
CMD ["bash"]
