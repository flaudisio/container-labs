FROM caddy:2.9.1-alpine

ARG S6_OVERLAY_VERSION=3.2.0.2

RUN set -ex \
 && DL_ARCH="$( arch )" \
 && wget -q -O - "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" \
        | tar -C / -Jxp -f - \
 && wget -q -O - "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${DL_ARCH}.tar.xz" \
        | tar -C / -Jxp -f -

RUN set -ex \
 && apk add --no-cache \
        fcgiwrap \
        git \
        git-daemon \
        shadow

ENV PUID="1000" \
    PGID="1000"

# Configure and enable services
COPY s6-rc.d/ /etc/s6-overlay/s6-rc.d/

ENTRYPOINT ["/init"]
