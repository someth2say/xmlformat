#! /bin/sh
VERSION="1.9"
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
CVS_REF=$(git rev-parse HEAD)

podman build . \
  --label "version=${VERSION}" \
  --label "build-date=${BUILD_DATE}" \
  --label "org.label-schema.build-date=${BUILD_DATE}" \
  --label "vcs-ref=${CVS_REF}" \
  --label "org.label-schema.vcs-ref=${CVS_REF}" \
  --tag "quay.io/someth2say/xmlformat:${VERSION}"
