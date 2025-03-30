# syntax=docker/dockerfile:1

## Build arguments provided via cli arguments
ARG VERSION
ARG BUILD_DATE

## Runtime stage defaults
# Labels
ARG RUNTIME_LABEL_BUILD_VERSION="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
ARG RUNTIME_LABEL_MAINTAINER="TheLamer"
# User: root
ARG RUNTIME_ROOT_HOME="/root"
ARG RUNTIME_ROOT_TERM="xterm"
# User: abc
ARG RUNTIME_ABC_HOME=/config
ARG RUNTIME_ABC_SHELL=/bin/false
ARG RUNTIME_ABC_GROUP=users
ARG RUNTIME_ABC_GID=1000
ARG RUNTIME_ABC_UID=911
# Shell prompt
ARG RUNTIME_PS1="$(whoami)@$(hostname):$(pwd)\\$ "
# s6 overlay
ARG RUNTIME_S6_CMD_WAIT_FOR_SERVICES_MAXTIME="0"
ARG RUNTIME_S6_VERBOSITY=1
ARG RUNTIME_S6_STAGE2_HOOK=/docker-mods
# Virtual environment location of lsiopy
ARG RUNTIME_VIRTUAL_ENV=/lsiopy
# mod-scripts URL
ARG RUNTIME_MOD_SCRIPTS_URL_PREFIX=https://raw.githubusercontent.com/linuxserver/docker-mods/refs/heads/mod-scripts

## Build argument defaults
# Globals
ARG ROOTFS=/root-out
ARG REL=v3.21
ARG ARCH=x86_64
ARG MIRROR=http://dl-cdn.alpinelinux.org/alpine
ARG PACKAGES=alpine-baselayout,\
alpine-keys,\
apk-tools,\
busybox,\
libc-utils
# s6 overlay
ARG S6_OVERLAY_RELEASES_URL_PREFIX=https://github.com/just-containers/s6-overlay/releases/download
ARG S6_OVERLAY_VERSION="3.2.0.2"
ARG S6_OVERLAY_ARCH=${ARCH}
# Package versions
ARG MODS_VERSION="v3"
ARG PKG_INST_VERSION="v1"
ARG LSIOWN_VERSION="v1"
ARG WITHCONTENV_VERSION="v1"


# RootFS stage
FROM alpine:3.20 AS rootfs-stage

# import global arguments
ARG ROOTFS
ARG REL
ARG ARCH
ARG MIRROR
ARG PACKAGES

# import s6 overlay arguments
ARG S6_OVERLAY_RELEASES_URL_PREFIX
ARG S6_OVERLAY_VERSION
ARG S6_OVERLAY_ARCH


# install packages
RUN \
  apk add --no-cache \
    bash \
    xz

# build rootfs
RUN \
  mkdir -p "${ROOTFS}/etc/apk" && \
  { \
    echo "${MIRROR}/${REL}/main"; \
    echo "${MIRROR}/${REL}/community"; \
  } > "${ROOTFS}/etc/apk/repositories" && \
  apk --root "${ROOTFS}" --no-cache --keys-dir /etc/apk/keys add --arch $ARCH --initdb ${PACKAGES//,/ } && \
  sed -i -e 's/^root::/root:!:/' ${ROOTFS}/etc/shadow

# add s6 overlay
ADD ${S6_OVERLAY_RELEASES_URL_PREFIX}/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C ${ROOTFS} -Jxpf /tmp/s6-overlay-noarch.tar.xz

ADD ${S6_OVERLAY_RELEASES_URL_PREFIX}/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz /tmp
RUN tar -C ${ROOTFS} -Jxpf /tmp/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz

# add s6 optional symlinks
ADD ${S6_OVERLAY_RELEASES_URL_PREFIX}/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz /tmp
RUN tar -C ${ROOTFS} -Jxpf /tmp/s6-overlay-symlinks-noarch.tar.xz && unlink ${ROOTFS}/usr/bin/with-contenv

ADD ${S6_OVERLAY_RELEASES_URL_PREFIX}/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-arch.tar.xz /tmp
RUN tar -C ${ROOTFS} -Jxpf /tmp/s6-overlay-symlinks-arch.tar.xz


# Runtime stage
FROM scratch

# import Runtime stage label arguments
ARG RUNTIME_LABEL_BUILD_VERSION
ARG RUNTIME_LABEL_MAINTAINER

# import global arguments
ARG ROOTFS

# import Package version arguments
ARG MODS_VERSION
ARG PKG_INST_VERSION
ARG LSIOWN_VERSION
ARG WITHCONTENV_VERSION

# import runtime stage arguments
ARG RUNTIME_ROOT_HOME
ARG RUNTIME_ROOT_TERM
ARG RUNTIME_ABC_HOME
ARG RUNTIME_ABC_SHELL
ARG RUNTIME_ABC_GROUP
ARG RUNTIME_ABC_GID
ARG RUNTIME_ABC_UID
ARG RUNTIME_S6_CMD_WAIT_FOR_SERVICES_MAXTIME
ARG RUNTIME_S6_VERBOSITY
ARG RUNTIME_S6_STAGE2_HOOK
ARG RUNTIME_PS1
ARG RUNTIME_VIRTUAL_ENV
ARG RUNTIME_MOD_SCRIPTS_URL_PREFIX

LABEL build_version="${RUNTIME_LABEL_BUILD_VERSION}"
LABEL maintainer="${RUNTIME_LABEL_MAINTAINER}"

COPY --from=rootfs-stage ${ROOTFS} /

ADD --chmod=755 "${RUNTIME_MOD_SCRIPTS_URL_PREFIX}/docker-mods.${MODS_VERSION}" "${RUNTIME_S6_STAGE2_HOOK}"
ADD --chmod=755 "${RUNTIME_MOD_SCRIPTS_URL_PREFIX}/package-install.${PKG_INST_VERSION}" "/etc/s6-overlay/s6-rc.d/init-mods-package-install/run"
ADD --chmod=755 "${RUNTIME_MOD_SCRIPTS_URL_PREFIX}/lsiown.${LSIOWN_VERSION}" "/usr/bin/lsiown"
ADD --chmod=755 "${RUNTIME_MOD_SCRIPTS_URL_PREFIX}/with-contenv.${WITHCONTENV_VERSION}" "/usr/bin/with-contenv"

# environment variables
ENV PS1=${RUNTIME_PS1} \
  HOME=${RUNTIME_ROOT_HOME} \
  TERM=${RUNTIME_ROOT_TERM} \
  S6_CMD_WAIT_FOR_SERVICES_MAXTIME=${RUNTIME_S6_CMD_WAIT_FOR_SERVICES_MAXTIME} \
  S6_VERBOSITY=${RUNTIME_S6_VERBOSITY} \
  S6_STAGE2_HOOK=${RUNTIME_S6_STAGE2_HOOK} \
  VIRTUAL_ENV=${RUNTIME_VIRTUAL_ENV} \
  PATH="${RUNTIME_VIRTUAL_ENV}/bin:${PATH}"

RUN \
  echo "**** install runtime packages ****" && \
  apk add --no-cache \
    alpine-release \
    bash \
    ca-certificates \
    catatonit \
    coreutils \
    curl \
    findutils \
    jq \
    netcat-openbsd \
    procps-ng \
    shadow \
    tzdata && \
  echo "**** create abc user and make our folders ****" && \
  groupmod -g ${RUNTIME_ABC_GID} ${RUNTIME_ABC_GROUP} && \
  useradd -u ${RUNTIME_ABC_UID} -U -d ${RUNTIME_ABC_HOME} -s ${RUNTIME_ABC_SHELL} abc && \
  usermod -G ${RUNTIME_ABC_GROUP} abc && \
  mkdir -p \
    /app \
    ${RUNTIME_ABC_HOME} \
    /defaults \
    ${RUNTIME_VIRTUAL_ENV} && \
  echo "**** cleanup ****" && \
  rm -rf \
    /tmp/*

# add local files
COPY root/ /

ENTRYPOINT ["/init"]
