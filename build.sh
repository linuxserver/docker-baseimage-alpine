#!/bin/bash

set -e  # Exit on error

# Parse Arguments
ARCH=${1:-x86_64}
VERSION=${2:-latest-stable}

# See: http://dl-cdn.alpinelinux.org/alpine/MIRRORS.txt
#!     No valid HTTPS support at the time of writing this -- shame on them!
#!     Thats why we don't use alpinelinux.org here...
BASEREPO=https://mirror.leaseweb.com/alpine/
SIGNING_KEY=https://alpinelinux.org/keys/ncopa.asc

# Parse Version to different representations used later on
VERSION_NUMERIC=${VERSION}  # Needed for Docker Tagging
VERSION_SHORT=v${VERSION}  # Needed for BASEURI

# Complete URI Example
# http://dl-cdn.alpinelinux.org/alpine/v3.8/releases/x86_64/alpine-minirootfs-3.8.0-x86_64.tar.gz
# [BASEREPO]/v[VERSION]/release/[ARCH]/alpine-minirootfs-[VERSION LATEST RELEASE]-[ARCH].tar.gz

BASEURI=${BASEREPO}/${VERSION_SHORT}/releases/${ARCH}

# Latest Release Detection!
DETECTED_VERSION_NUMERIC=$(curl --silent "${BASEURI}/latest-releases.yaml" | grep -i 'version:' | awk '{print $2}' | head -n 1)
ROOTFS="alpine-minirootfs-${DETECTED_VERSION_NUMERIC}-${ARCH}.tar.gz"
ROOTFS_HASH="alpine-minirootfs-${DETECTED_VERSION_NUMERIC}-${ARCH}.tar.gz.sha256"
ROOTFS_SIG="alpine-minirootfs-${DETECTED_VERSION_NUMERIC}-${ARCH}.tar.gz.asc"

BUILD_DIR="build/${ARCH}/${VERSION}"

# Clean and create build Directory for our arch and version
if [[ -e ${BUILD_DIR} ]]; then
    rm -r "${BUILD_DIR}"
fi
mkdir -p "build/${ARCH}/${VERSION}"

# Change to that directory for all following operations
pushd "build/${ARCH}/${VERSION}" > /dev/null
    separator(){
        COLUMNS=$(tput cols)
        printf "${1}"'%.0s' $(seq 1 "${COLUMNS:-72}")
    }

    # Download and verify the rootfs
    separator '#'
    echo "Downloading Alpine ${ARCH} ${VERSION} base Image."
    (curl --silent --output "${ROOTFS}" "${BASEURI}/${ROOTFS}" 2> /dev/null && echo "    Using RootFS: ${ROOTFS}") || (echo "    ERROR - ${ROOTFS}" && exit 10)
    curl --silent --output "${ROOTFS_HASH}" "${BASEURI}/${ROOTFS_HASH}" 2> /dev/null || (echo "    ERROR - ${ROOTFS_HASH}" && exit 11)
    curl --silent --output "${ROOTFS_SIG}" "${BASEURI}/${ROOTFS_SIG}" 2> /dev/null || (echo "    ERROR - ${ROOTFS_SIG}" && exit 12)
    echo -n "    Check GPG-Signature: "
    (gpg --verify "${ROOTFS_SIG}" 2> /dev/null && echo "OK") || (echo "    ERROR (You need to import ${SIGNING_KEY} manually)" && exit 21)
    echo -n "    Check Content-Checksum: "
    (sha256sum --quiet --check "${ROOTFS_HASH}" 2> /dev/null && echo "OK") || (echo "    ERROR" && exit 30)

    # Clean directory and name file as needed
    rm "${ROOTFS_HASH}"
    rm "${ROOTFS_SIG}"
    echo "    Convert compression from .tar.gz to .tar.xz"
    mv "${ROOTFS}" "rootfs.tar.gz"
    gunzip "rootfs.tar.gz"
    xz -z "rootfs.tar"

    echo "    Copy Docker build dependencies"
    # Copy Dockerbuild Files.
    cp -a ../../../Dockerfile ../../../root .

    # Build Dockerfile
    echo "    Docker Build..."
    separator '='
    docker build --tag "alpine:${VERSION_NUMERIC}" .
    separator '='
    separator '#'
popd > /dev/null