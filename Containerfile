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
RUN microdnf update -y && \
    microdnf install -y perl ruby && \
    microdnf clean all
###

FROM ubi8-perl-ruby

# Docker arguments to facilitate image extension
ARG SCRIPTS_DIR="/bin" 
ARG EXTRA_ARGS=""
ARG CFG_FILE="${SCRIPTS_DIR}/xmlformat.conf" 

LABEL \
    name="XMLFormat" \
    version="1.9" \
    License="GPLv3+" \
    vendor="" \
    description="Container image wrapping XML formater by Kitebird (http://www.kitebird.com/software/xmlformat/)" \
    summary="Container image wrapping XML formater by Kitebird (http://www.kitebird.com/software/xmlformat/)" \
    org.label-schema.name="XMLFormat" \
    org.label-schema.description="Container image wrapping XML formater by Kitebird (http://www.kitebird.com/software/xmlformat/)" \
    org.label-schema.url="https://github.com/someth2say/xmlformat" \
    org.label-schema.vcs-url="https://github.com/someth2say/xmlformat" \
    org.label-schema.vcs-ref="" \
    org.label-schema.schema-version="1.0" \
    io.k8s.description="Container image wrapping XML formater by Kitebird (http://www.kitebird.com/software/xmlformat/)" \
    io.k8s.display-name="XMLFormat" \
    io.openshift.tags="xml format perl ruby" 


# Environment to be used by the xmlformat.sh script
ENV PATH=${SCRIPTS_DIR}:$PATH \
    XMLFORMAT_CONF=${CFG_FILE} \
    XMLFORMAT_ARGS=${EXTRA_ARGS}

# Copy the root scripts to the scripts folder
ADD bin ${SCRIPTS_DIR}

# Make scripts executable by root group, just in case
RUN chgrp -R 0 ${SCRIPTS_DIR} && \
    chmod -R g=u ${SCRIPTS_DIR}

ENTRYPOINT [ "xmlformat.rb" ]
