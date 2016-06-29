FROM gliderlabs/alpine:3.4
MAINTAINER sparklyballs

# set version for s6 overlay
ARG OVERLAY_VERSION="v1.18.1.0"

# set some environment variables
ENV PS1="$(whoami)@$(hostname):$(pwd)$ " \
HOME="/root" \
TERM="xterm"

# add packages
RUN \
 apk add --no-cache --virtual=build-dependencies \
	curl \
	tar && \

 apk add --no-cache \
	bash \
	s6 \
	s6-portable-utils \
	tzdata && \

apk add --no-cache --repository http://nl.alpinelinux.org/alpine/edge/testing \
	shadow && \

# add s6 overlay
 curl -o \
	/tmp/s6-overlay.tar.gz -L \
	https://github.com/just-containers/s6-overlay/releases/download/"${OVERLAY_VERSION}"/s6-overlay-nobin.tar.gz && \
	tar xvfz /tmp/s6-overlay.tar.gz -C / && \

# clean up
 apk del --purge \
	build-dependencies && \
 rm -rf /var/cache/apk/* /tmp/*

# create abc user
RUN \
	groupmod -g 1000 users && \
	useradd -u 911 -U -d /config -s /bin/false abc && \
	usermod -G users abc && \

# create some folders
	mkdir -p /config /app /defaults

# add local files
COPY root/ /

ENTRYPOINT ["/init"]
