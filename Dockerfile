FROM registry.access.redhat.com/ubi8/ubi-minimal as perl
MAINTAINER Jordi Sola <jordisola@redhat.com>

LABEL maintainer="Jordi Sola <jordisola@redhat.com>" \
      name="XMLFormat" \
      vcs-ref="TBD" \
      version="0.1-SNAPSHOT" \
      build-date="TBD" \
      description="Container image wrapping XML formater by Kitebird (http://www.kitebird.com/software/xmlformat/)" \
      summary="Container image wrapping XML formater by Kitebird (http://www.kitebird.com/software/xmlformat/)" \
      io.k8s.description="Container image wrapping XML formater by Kitebird (http://www.kitebird.com/software/xmlformat/)" \
      io.k8s.display-name="XMLFormat" \
      io.openshift.tags="xml format perl" 

# Install perl interpreter
RUN microdnf install -y perl

###

FROM perl

# Docker arguments to facilitate image extension
ARG SCRIPTS_DIR="/xmlformat" 
ARG EXTRA_ARGS="-i"
ARG CFG_FILE="${SCRIPTS_DIR}/xmlformat.cfg" 

# Environment to be used by the xmlformat.sh script
ENV PATH=${SCRIPTS_DIR}:$PATH \
    XMLFORMAT_CFG_FILE=${CFG_FILE} \
    XMLFORMAT_SCRIPTS_DIR=${SCRIPTS_DIR} \
    XMLFORMAT_EXTRA_ARGS=${EXTRA_ARGS}

# Copy the root scripts to the scripts folder
ADD scripts ${SCRIPTS_DIR}

# Make scripts executable by root group, just in case
RUN chgrp -R 0 ${SCRIPTS_DIR} && \
    chmod -R g=u ${SCRIPTS_DIR}

ENTRYPOINT [ "xmlformat.sh" ]