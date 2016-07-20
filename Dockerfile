FROM gliderlabs/alpine:3.4
MAINTAINER sparklyballs

# set version for s6 overlay
ARG OVERLAY_VERSION="v1.18.1.3"
ARG OVERLAY_ARCH="amd64"
ARG OVERLAY_URL="https://github.com/just-containers/s6-overlay/releases/download"
ARG OVERLAY_WWW="${OVERLAY_URL}"/"${OVERLAY_VERSION}"/s6-overlay-"${OVERLAY_ARCH}".tar.gz

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
	tzdata && \

apk add --no-cache --repository http://nl.alpinelinux.org/alpine/edge/testing \
	shadow && \

# add s6 overlay
 curl -o \
 /tmp/s6-overlay.tar.gz -L \
	"${OVERLAY_WWW}" && \
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
