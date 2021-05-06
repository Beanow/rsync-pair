FROM alpine:3

RUN apk add --no-cache sudo bash shadow coreutils rsync openssh-client openssh-server; \
	useradd -p '*' --no-user-group push; \
	useradd -p '*' --no-user-group pull;

COPY src/sshd_config /etc/ssh/sshd_config
COPY --chown=0:0 --chmod=0440 src/sudoers /etc/sudoers
COPY src/*.sh /bin/
COPY LICENSE.md /LICENSE.md
COPY README.md /README.md

ENTRYPOINT ["/bin/entry.sh"]
