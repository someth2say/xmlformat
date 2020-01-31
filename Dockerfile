FROM registry.access.redhat.com/ubi8/ubi-minimal as ubi8-perl-ruby
MAINTAINER Jordi Sola <jordisola@redhat.com>

LABEL maintainer="Jordi Sola <jordisola@redhat.com>" \
      name="ubi8-perl-ruby" \
      version="0.1-SNAPSHOT" \
      description="UBI8 based image containing perl and ruby interpreters" \
      summary="UBI8 based image containing perl and ruby interpreters" \
      io.k8s.description="UBI8 based image containing perl and ruby interpreters" \
      io.k8s.display-name="ubi8-perl-ruby" \
      io.openshift.tags="perl ruby" 

# Install perl and ruby interpreter
RUN microdnf install -y perl ruby
###

FROM ubi8-perl-ruby
LABEL name="XMLFormat" \
      version="0.3-SNAPSHOT" \
      description="Container image wrapping XML formater by Kitebird (http://www.kitebird.com/software/xmlformat/)" \
      summary="Container image wrapping XML formater by Kitebird (http://www.kitebird.com/software/xmlformat/)" \
      io.k8s.description="Container image wrapping XML formater by Kitebird (http://www.kitebird.com/software/xmlformat/)" \
      io.k8s.display-name="XMLFormat" \
      io.openshift.tags="xml format perl" 

# Docker arguments to facilitate image extension
ARG SCRIPTS_DIR="/bin" 
ARG EXTRA_ARGS=""
ARG CFG_FILE="${SCRIPTS_DIR}/xmlformat.conf" 

# Environment to be used by the xmlformat.sh script
ENV PATH=${SCRIPTS_DIR}:$PATH \
    XMLFORMAT_CONF=${CFG_FILE} \
    XMLFORMAT_ARGS=${EXTRA_ARGS}

# Copy the root scripts to the scripts folder
ADD bin ${SCRIPTS_DIR}

# Make scripts executable by root group, just in case
RUN chgrp -R 0 ${SCRIPTS_DIR} && \
    chmod -R g=u ${SCRIPTS_DIR}

ENTRYPOINT [ "xmlformat_rb.sh" ]
