ARG BUILD_FROM=alpine:3.21
FROM ${BUILD_FROM}

ARG BUILD_ARCH
ARG BUILD_VERSION
LABEL \
  io.hass.version="${BUILD_VERSION}" \
  io.hass.type="addon" \
  io.hass.arch="${BUILD_ARCH}"

RUN apk add --no-cache busybox-extras logrotate rsyslog tzdata

COPY run.sh rotate.sh /usr/local/bin/
RUN chmod 0755 /usr/local/bin/run.sh /usr/local/bin/rotate.sh

CMD ["/usr/local/bin/run.sh"]
