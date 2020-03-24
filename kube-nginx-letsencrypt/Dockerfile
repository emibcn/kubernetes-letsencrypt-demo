FROM fedora:30
MAINTAINER emibcn <github.com/emibcn>

RUN \
    dnf install certbot -y && \
    dnf install python -y && \
    dnf clean all && \
    mkdir /etc/letsencrypt

COPY secret-patch-template.json /
COPY deployment-patch-template.json /
COPY entrypoint.sh /

CMD ["/entrypoint.sh"]
