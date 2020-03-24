FROM fedora:24
MAINTAINER Daniel Montoya <daniel@entropy.tech>

RUN dnf install certbot -y && dnf clean all
RUN mkdir /etc/letsencrypt

COPY secret-patch-template.json /
COPY deployment-patch-template.json /
COPY entrypoint.sh /

CMD ["/entrypoint.sh"]
