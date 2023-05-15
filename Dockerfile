# syntax=docker/dockerfile:1

FROM alpine:3.16 as rootfs-stage

# environment
ENV REL=v3.17
ENV ARCH=x86_64
ENV MIRROR=http://dl-cdn.alpinelinux.org/alpine
ENV PACKAGES=alpine-baselayout,\
alpine-keys,\
apk-tools,\
busybox,\
libc-utils,\
xz

# install packages
RUN \
  apk add --no-cache \
    bash \
    curl \
    tzdata \
    xz

# fetch builder script from gliderlabs
RUN \
  curl -o \
  /mkimage-alpine.bash -L \
    https://raw.githubusercontent.com/gliderlabs/docker-alpine/master/builder/scripts/mkimage-alpine.bash && \
  chmod +x \
    /mkimage-alpine.bash && \
  ./mkimage-alpine.bash  && \
  mkdir /root-out && \
  tar xf \
    /rootfs.tar.xz -C \
    /root-out && \
  sed -i -e 's/^root::/root:!:/' /root-out/etc/shadow

# set version for s6 overlay
ARG S6_OVERLAY_VERSION="3.1.5.0"
ARG S6_OVERLAY_ARCH="x86_64"

# add s6 overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C /root-out -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz /tmp
RUN tar -C /root-out -Jxpf /tmp/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz

# add s6 optional symlinks
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz /tmp
RUN tar -C /root-out -Jxpf /tmp/s6-overlay-symlinks-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-arch.tar.xz /tmp
RUN tar -C /root-out -Jxpf /tmp/s6-overlay-symlinks-arch.tar.xz

# Runtime stage
FROM scratch
COPY --from=rootfs-stage /root-out/ /
ARG BUILD_DATE
ARG VERSION
ARG MODS_VERSION="v3"
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="TheLamer"

ADD --chmod=744 "https://raw.githubusercontent.com/linuxserver/docker-mods/mod-scripts/docker-mods.${MODS_VERSION}" "/docker-mods"

# environment variables
ENV PS1="$(whoami)@$(hostname):$(pwd)\\$ " \
  HOME="/root" \
  TERM="xterm" \
  S6_CMD_WAIT_FOR_SERVICES_MAXTIME="0" \
  S6_VERBOSITY=1 \
  S6_STAGE2_HOOK=/docker-mods \
  VIRTUAL_ENV=/lsiopy \
  PATH="/lsiopy/bin:$PATH"

RUN \
  echo "**** install runtime packages ****" && \
  apk add --no-cache \
    alpine-release \
    bash \
    ca-certificates \
    coreutils \
    curl \
    jq \
    netcat-openbsd \
    procps \
    shadow \
    tzdata && \
  echo "**** create abc user and make our folders ****" && \
  groupmod -g 1000 users && \
  useradd -u 911 -U -d /config -s /bin/false abc && \
  usermod -G users abc && \
  mkdir -p \
    /app \
    /config \
    /defaults \
    /lsiopy && \
  echo "**** cleanup ****" && \
  rm -rf \
    /tmp/*

# add local files
COPY root/ /

ENTRYPOINT ["/init"]
