FROM alpine:3 AS base

ARG gosu_version=1.19
ARG tini_version=0.19.0

RUN set -ex \
 && DL_ARCH="amd64" \
 && if [ "$( arch )" = "aarch64" ] ; then DL_ARCH="arm64" ; fi \
 && wget -q -O /gosu "https://github.com/tianon/gosu/releases/download/${gosu_version}/gosu-${DL_ARCH}" \
 && wget -q -O /tini "https://github.com/krallin/tini/releases/download/v${tini_version}/tini-static-${DL_ARCH}"

# Ref: https://github.com/Shlomob/ocmonitor-share/blob/main/Dockerfile
FROM python:3.13-slim

COPY --from=base --chown=root:root --chmod=0755 /gosu /bin/gosu
COPY --from=base --chown=root:root --chmod=0755 /tini /bin/tini

RUN set -ex \
 && pip install --no-cache-dir \
      'opencode-monitor' \
 && find /usr/local -depth -type d -name '__pycache__' -exec rm -rf '{}' \; \
 && rm -rf ~/.cache

ARG PUID=1000
ARG PGID=1000
ENV APP_DIR="/app"

RUN set -ex \
 && addgroup --gid "$PGID" ocmonitor \
 && adduser --disabled-password --gecos '' --uid "$PUID" --ingroup ocmonitor --home "$APP_DIR" ocmonitor

COPY entrypoint.sh /bin/entrypoint.sh

ENTRYPOINT ["tini", "--", "/bin/entrypoint.sh"]

CMD ["ocmonitor", "metrics"]
