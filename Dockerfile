FROM scratch
ADD rootfs.tar.gz /

MAINTAINER sparklyballs

# set arch for s6 overlay
ARG OVERLAY_ARCH="${OVERLAY_ARCH:-amd64}"

# environment variables
ENV PS1="$(whoami)@$(hostname):$(pwd)$ " \
PATH="/usr/local/bin:$PATH" \
HOME="/root" \
TERM="xterm"

# copy busybox id to /usr/local/bin, coreutils (gnu) version of id, bug with group ids.
RUN \
 cp /usr/bin/id /usr/local/bin/id && \

# install packages
 apk add --no-cache --virtual=build-dependencies \
	curl \
	tar && \
 apk add --no-cache \
	bash \
	ca-certificates \
	coreutils \
	shadow \
	tzdata && \

# add s6 overlay
  OVERLAY_VERSION=$(curl -sX GET "https://api.github.com/repos/just-containers/s6-overlay/releases/latest" \
	| awk '/tag_name/{print $4;exit}' FS='[""]') && \
 curl -o \
 /tmp/s6-overlay.tar.gz -L \
	"https://github.com/just-containers/s6-overlay/releases/download/${OVERLAY_VERSION}/s6-overlay-${OVERLAY_ARCH}.tar.gz" && \
 tar xfz \
	/tmp/s6-overlay.tar.gz -C / && \

# create abc user
 groupmod -g 1000 users && \
 useradd -u 911 -U -d /config -s /bin/false abc && \
 usermod -G users abc && \

# make our folders
 mkdir -p \
	/app \
	/config \
	/defaults && \

# clean up
 apk del --purge \
	build-dependencies && \
 rm -rf \
	/tmp/*

# add local files
COPY root/ /

ENTRYPOINT ["/init"]
