FROM 300288021642.dkr.ecr.eu-west-2.amazonaws.com/ch-serverjre:1.2.5

ENV FES_HOME=/apps/fes \
    ARTIFACTORY_BASE_URL=https://artifactory.companieshouse.gov.uk/artifactory/virtual-release

RUN yum -y install gettext && \
    yum -y install cronie && \
    yum -y install oracle-instantclient-release-el7 && \
    yum -y install oracle-instantclient-basic && \
    yum -y install oracle-instantclient-sqlplus && \
    yum -y install https://archives.fedoraproject.org/pub/archive/epel/7/x86_64/Packages/e/epel-release-7-14.noarch.rpm && \
    yum -y install openssh-clients && \
    yum --enablerepo ol7_optional_latest install -y sharutils && \
    yum -y install msmtp && \
    yum clean all && \
    rm -rf /var/cache/yum

RUN mkdir -p /apps && \
    chmod a+xr /apps && \
    useradd -u 2001 -d ${FES_HOME} -m -s /bin/bash fes

USER fes

# Copy all batch jobs to FES_HOME
COPY --chown=fes fes-batch ${FES_HOME}/

# Download the batch libs and set permission on scripts
RUN mkdir -p ${FES_HOME}/libs && \
    cd ${FES_HOME}/libs && \
    curl ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/fes-file-loader/1.2.0/fes-file-loader-1.2.0.jar -o ../fes-file-loader/fes-file-loader.jar && \
    chmod -R 750 ${FES_HOME}/*

WORKDIR $FES_HOME
USER root
CMD ["bash"]
