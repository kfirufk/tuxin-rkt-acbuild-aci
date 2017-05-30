#!/usr/bin/env bash
set -e
GPG_KEY="<KEY>"
if [ "$EUID" -ne 0 ]; then
    echo "This script uses functionality which requires root privileges"
    exit 1
fi
rm serviio-1.0-linux-amd64.aci* || echo "old aci image not found"

SERVIIO_VERSION=1.8
JAVA_VERSION=8
JAVA_BUILD=131
JAVA_URL_PATH=${JAVA_VERSION}u${JAVA_BUILD}
JAVA_B_VERSION=11
# Start the build with an empty ACI
acbuild --debug begin docker://alpine:3.6

# In the event of the script exiting, end the build
acbuildEnd() {
    export EXIT=$?
    acbuild --debug end && exit $EXIT 
}
trap acbuildEnd EXIT

ACBUILD_FLAGS="--engine=chroot --debug"
# Name the ACI
acbuild --debug set-name tux-in.com/serviio
acbuild --debug label add version 0.1
acbuild --debug label add arch amd64
acbuild --debug label add os linux

# Based on alpine
#acbuild --debug dep add quay.io/coreos/alpine-sh

#acbuild --debug run -- sed -i -e 's/v3\.2/v3.5/g' /etc/apk/repositories
acbuild ${ACBUILD_FLAGS} run -- sed -r -i -e 's/nameserver\s+\d+\.\d+\.\d+\.\d+/nameserver 8.8.8.8\nnameserver 8.8.4.4/g' /etc/resolv.conf
acbuild ${ACBUILD_FLAGS} run -- cat /etc/resolv.conf
acbuild ${ACBUILD_FLAGS} run -- apk upgrade -U

acbuild ${ACBUILD_FLAGS} run -- apk add curl wget bash ffmpeg
acbuild ${ACBUILD_FLAGS} run -- apk --no-cache add ca-certificates
acbuild ${ACBUILD_FLAGS} run -- curl -L -o /etc/apk/keys/sgerrand.rsa.pub https://raw.githubusercontent.com/sgerrand/alpine-pkg-glibc/master/sgerrand.rsa.pub
acbuild ${ACBUILD_FLAGS} run -- curl -L -o glibc-2.25-r0.apk https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.25-r0/glibc-2.25-r0.apk
acbuild ${ACBUILD_FLAGS} run -- curl -L -o glibc-bin-2.25-r0.apk https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.25-r0/glibc-bin-2.25-r0.apk
acbuild ${ACBUILD_FLAGS} run -- curl -L -o glibc-i18n-2.25-r0.apk https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.25-r0/glibc-i18n-2.25-r0.apk
acbuild ${ACBUILD_FLAGS} run -- apk add glibc-2.25-r0.apk glibc-bin-2.25-r0.apk glibc-i18n-2.25-r0.apk
acbuild ${ACBUILD_FLAGS} run -- rm glibc-2.25-r0.apk glibc-bin-2.25-r0.apk glibc-i18n-2.25-r0.apk
acbuild ${ACBUILD_FLAGS} run -- /usr/glibc-compat/bin/localedef -i en_US -f UTF-8 en_US.UTF-8

acbuild ${ACBUILD_FLAGS} run --  wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/${JAVA_URL_PATH}-b${JAVA_B_VERSION}/jre-${JAVA_URL_PATH}-linux-x64.tar.gz


acbuild ${ACBUILD_FLAGS} run -- mkdir -p /opt/config/serviio
acbuild ${ACBUILD_FLAGS} mount add serviio-config /opt/config/serviio
acbuild ${ACBUILD_FLAGS} run -- mkdir -p /mnt/video-storage
acbuild ${ACBUILD_FLAGS} mount add video-storage /mnt/video-storage --read-only
acbuild ${ACBUILD_FLAGS} run -- tar xvfz jre-${JAVA_URL_PATH}-linux-x64.tar.gz -C /opt
acbuild ${ACBUILD_FLAGS} run -- rm jre-${JAVA_URL_PATH}-linux-x64.tar.gz
acbuild ${ACBUILD_FLAGS} environment add JAVA_HOME /opt/jre1.${JAVA_VERSION}.0_${JAVA_BUILD}

acbuild ${ACBUILD_FLAGS} run -- curl -o serviio-${SERVIIO_VERSION}-linux.tar.gz http://download.serviio.org/releases/serviio-${SERVIIO_VERSION}-linux.tar.gz
acbuild ${ACBUILD_FLAGS} run -- tar xvfz serviio-${SERVIIO_VERSION}-linux.tar.gz -C /opt
acbuild ${ACBUILD_FLAGS} run -- ln -s serviio-${SERVIIO_VERSION} /opt/serviio
acbuild ${ACBUILD_FLAGS} run -- rm serviio-${SERVIIO_VERSION}-linux.tar.gz
acbuild ${ACBUILD_FLAGS} run -- mv /opt/serviio/config /opt/config/serviio 
acbuild ${ACBUILD_FLAGS} run -- ln -s /opt/config/serviio/config /opt/serviio/config
acbuild ${ACBUILD_FLAGS} run -- apk del curl wget

acbuild ${ACBUILD_FLAGS} port add serviio tcp 8895

acbuild ${ACBUILD_FLAGS} set-exec -- /opt/serviio/bin/serviio.sh

# Save the ACI
acbuild ${ACBUILD_FLAGS} write --overwrite serviio-1.0-linux-amd64.aci

#rkt trust --prefix tux-in.com ./gpg/pubkeys.gpg
#gpg --no-default-keyring \
#--secret-keyring ./gpg/rkt.sec \
#--keyring ./gpg/rkt.pub \
#--edit-key $GPG_KEY \
#trust
#gpg --no-default-keyring --armor \
#--secret-keyring ./gpg/rkt.sec --keyring ./gpg/rkt.pub \ #--output
#serviio-1.0-linux-amd64.aci.asc \ #--detach-sig serviio-1.0-linux-amd64.aci
echo "execute: systemd-run rkt --debug --insecure-options=image run  --volume serviio-config,kind=host,source=/usr/local/rkt/config/serviio --volume video-storage,kind=host,source=/usr/local/rkt/storage/videos /home/ufk/images/serviio-1.0-linux-amd64.aci"
