#!/bin/bash
set -eo pipefail

# Behaviour options
readonly loglevel=${LOG_LEVEL:-INFO}
readonly bwlimit=${BWLIMIT:-0}

# Store the bwlimit
echo "${bwlimit}" > /etc/rsync_bwlimit

# Prepare server IDs
[ -f /keys/ssh_host_ed25519_key ] || ssh-keygen -t ed25519 -f /keys/ssh_host_ed25519_key -N '';
[ -f /keys/ssh_host_rsa_key ] || ssh-keygen -t rsa -b 4096 -f /keys/ssh_host_rsa_key -N '';

# Write the authorized_keys for push and/or pull.
printf "%-12s | %-19s | %s\n" "username" "destination" "authorized_keys"
echo "-------------|---------------------|---------------------------"
if [ -n "${PUSH_KEY}" ]; then
	printf "%-12s | %-19s | %s\n" "push" "/media/push" "${PUSH_KEY}"
	mkdir -p "/home/push/.ssh"
	echo "${PUSH_KEY}" > "/home/push/.ssh/authorized_keys"
fi

if [ -n "${PULL_KEY}" ]; then
	printf "%-12s | %-19s | %s\n" "pull" "/media/pull" "${PULL_KEY}"
	mkdir -p "/home/pull/.ssh"
	echo "${PULL_KEY}" > "/home/pull/.ssh/authorized_keys"
fi
echo

# Server command
exec /usr/sbin/sshd -o "LogLevel ${loglevel}" -D -e
