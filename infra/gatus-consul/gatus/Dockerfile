FROM hashicorp/consul:1.20 AS consul-base
FROM hashicorp/consul-template:0.39 AS consul-template-base
FROM twinproduction/gatus:v5.15.0 AS gatus-base

FROM alpine:3.21

COPY --from=consul-base /bin/consul /bin/consul
COPY --from=consul-template-base /bin/consul-template /bin/consul-template
COPY --from=gatus-base /gatus /bin/gatus

ARG S6_OVERLAY_VERSION=3.2.0.2

RUN set -ex \
 && DL_ARCH="$( arch )" \
 && wget -q -O - "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" \
        | tar -C / -Jxp -f - \
 && wget -q -O - "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${DL_ARCH}.tar.xz" \
        | tar -C / -Jxp -f -

# Configure services
COPY s6-rc.d/consul-agent /etc/s6-overlay/s6-rc.d/consul-agent
COPY s6-rc.d/consul-template /etc/s6-overlay/s6-rc.d/consul-template
COPY s6-rc.d/gatus /etc/s6-overlay/s6-rc.d/gatus

# Enable services
RUN set -ex \
 && touch /etc/s6-overlay/s6-rc.d/user/contents.d/consul-agent \
 && touch /etc/s6-overlay/s6-rc.d/user/contents.d/consul-template \
 && touch /etc/s6-overlay/s6-rc.d/user/contents.d/gatus

ENV GATUS_CONFIG_PATH=/gatus/config

ENTRYPOINT ["/init"]
