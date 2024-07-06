#https://github.com/shawly/docker-keepalived/blob/main/Dockerfile
#https://github.com/NeoAssist/docker-keepalived/blob/master/docker-keepalived/keepalived.sh
#
FROM debian:stable-slim

ARG BUILD_DATE
#ARG VCS_REF
ARG VERSION

LABEL org.opencontainers.image.authors="Erwin Herzog <e.herzog76@live.de>" \
      architecture="x86_64"                       \
      build-date="$BUILD_DATE"                    \
      license="MIT"                               \
      name="eherzog/keepalived"                   \
      summary="Alpine based keepalived container" \
      version="$VERSION"                          \
      vcs-type="git"                              \
      vcs-url="https://github.com/EHerzog76/keepalived-LoadBalancer"
#      vcs-ref="$VCS_REF"

ENV KEEPALIVED_VERSION=2.3.1 \
    TZ=Europe/Vienna \
    ENABLE_LB=true \
    INTERFACE="" \
    LBMode=main \
    VIRTUAL_ROUTER_ID=51 \
    PRIORITY=200 \
    PRIORITYBACKUP=180 \
    VIRTUAL_IP=192.168.254.254 \
    PASSWORD=s3cr3t \
    LB_KIND=NAT \
    LB_ALGO=rr
#ENV NOTIFY_SCRIPT_PATH=/etc/keepalived/notify.sh

#keepalived=${KEEPALIVED_VERSION}
#tini
RUN apt-get update && \
    apt-get install --no-install-recommends --no-install-suggests -y keepalived ipvsadm ipset socat iptables nftables && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY keepalived /etc/keepalived/
COPY entrypoint.sh /entrypoint.sh

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN useradd -m  -s /bin/bash keepalived_script && mkdir -p /etc/sudoers.d
RUN usermod -aG sudo keepalived_script && echo "keepalived_script ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/keepalived_script
RUN chmod 0440 /etc/sudoers.d/keepalived_script
#USER keepalived_script:keepalived_script
USER root:root

ENTRYPOINT ["/entrypoint.sh"]
#ENTRYPOINT ["/tini", "-g", "--", "/entrypoint.sh"]
