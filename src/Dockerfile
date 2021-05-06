FROM alpine:3

RUN apk add --no-cache sudo bash shadow coreutils rsync openssh-client openssh-server; \
	useradd -p '*' --no-user-group push; \
	useradd -p '*' --no-user-group pull;

COPY sshd_config /etc/ssh/sshd_config
COPY --chown=0:0 --chmod=0440 sudoers /etc/sudoers
COPY *.sh /bin/

ENTRYPOINT ["/bin/entry.sh"]
