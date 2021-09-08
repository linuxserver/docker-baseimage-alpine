FROM alpine:3.13 as rootfs-stage

# environment
ENV REL=v3.14
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

# Runtime stage
FROM scratch
COPY --from=rootfs-stage /root-out/ /
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="TheLamer"

# set version for s6 overlay
ARG OVERLAY_VERSION="v2.2.0.3"
ARG OVERLAY_ARCH="amd64"

# add s6 overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/${OVERLAY_VERSION}/s6-overlay-${OVERLAY_ARCH}-installer /tmp/
RUN chmod +x /tmp/s6-overlay-${OVERLAY_ARCH}-installer && /tmp/s6-overlay-${OVERLAY_ARCH}-installer / && rm /tmp/s6-overlay-${OVERLAY_ARCH}-installer
COPY patch/ /tmp/patch

# environment variables
ENV PS1="$(whoami)@$(hostname):$(pwd)\\$ " \
HOME="/root" \
TERM="xterm"

RUN \
 echo "**** install build packages ****" && \
 apk add --no-cache --virtual=build-dependencies \
	curl \
	patch \
	tar && \
 echo "**** install runtime packages ****" && \
 apk add --no-cache \
	bash \
	ca-certificates \
	coreutils \
	procps \
	shadow \
	tzdata && \
 echo "**** create abc user and make our folders ****" && \
 groupmod -g 1000 users && \
 useradd -u 911 -U -d /data -s /bin/false abc && \
 usermod -G users abc && \
 mkdir -p \
	/app \
	/config \
  /data \
	/defaults && \
 mv /usr/bin/with-contenv /usr/bin/with-contenvb && \
 patch -u /etc/s6/init/init-stage2 -i /tmp/patch/etc/s6/init/init-stage2.patch && \
 echo "**** cleanup ****" && \
 apk del --purge \
	build-dependencies && \
 rm -rf \
	/tmp/*

# add local files
COPY root/ /

ENTRYPOINT ["/init"]
