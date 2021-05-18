#!/bin/bash
set -o pipefail

# Preferences in behaviour.
readonly progress=${SHOW_PROGRESS:-no}
readonly dry_run=${DRY_RUN:-no}
readonly order=${TASK_ORDER:-push pull}
readonly bwlimit=${BWLIMIT}

# Defaults that correspond to how we're expecting the server to be configured.
# Probably don't need to chance if you're using the same container.
readonly push_dir=${PUSH_DIRECTORY:-/media/push/}
readonly pull_dir=${PULL_DIRECTORY:-/media/pull/}

# Derived variables, need if-guards later on though.
readonly push_remote="push@${PUSH_TO}:${push_dir}"
readonly pull_remote="pull@${PULL_FROM}:${pull_dir}"

# Prepare id keypair.
mkdir -p ~/.ssh
[ "$(whoami)" == "root" ] || echo "Warning: expecting to run as root, instead running as $(whoami)"
[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ''

# Log version for sanity.
echo "Client rsync version: $(rsync --version | head -n1)"

# Log key for easier setup.
echo "Make sure to authorize the following public key:"
cat ~/.ssh/id_ed25519.pub
echo

# Allow servers to catch up in tests.
[ -n "${START_DELAY}" ] && sleep "${START_DELAY}"

# Include custom ssh config.
if [ -n "${SSH_CONFIG}" ]; then
	echo "Writing custom \$SSH_CONFIG to ${HOME}/.ssh/config:"
	echo "${SSH_CONFIG}" > ~/.ssh/config
	cat ~/.ssh/config
fi

# Mention it if we've not set either.
if [ -z "${PUSH_TO}${PULL_FROM}" ]; then
	echo "Neither \$PUSH_TO nor \$PULL_FROM was set."
	echo "Make sure to provide the domain/ip for an rsync-over-ssh server for at least one."
	exit 1
fi

printf "%-4s | %-7s | %-20s | %-3s | %s\n" "task" "timeout" "local path" "" "remote uri"
printf "%-4s-|-%-7s-|-%-20s-|-%-3s-|-%s\n" "----" "-------" "--------------------" "---" "--------------------"
for task in ${order}; do
	case "${task}" in
		push ) [ -n "${PUSH_TO}" ] 	 && printf "%-4s | %-7s | %-20s | %-3s | %s\n" "push" "${PUSH_TIMEOUT}" "${push_dir}" "-->" "${push_remote}";;
		pull ) [ -n "${PULL_FROM}" ] && printf "%-4s | %-7s | %-20s | %-3s | %s\n" "pull" "${PULL_TIMEOUT}" "${pull_dir}" "<--" "${pull_remote}";;
		* )
			echo "Unknown task in \$TASK_ORDER: ${task}"
			exit 1
			;;
	esac
done
echo

# Compile options
opts="-aAXv --delete --partial --numeric-ids --open-noatime --stats --no-protect-args"
[ "${progress}" == "yes" ] && opts="$opts --progress"
[ "${dry_run}" == "yes" ] && opts="$opts --dry-run"
[ -n "${bwlimit}" ] && opts="$opts --bwlimit=${bwlimit}"

for task in ${order}; do
	case "${task}" in
		push )
			if [ -n "${PUSH_TO}" ]; then
				echo "Pushing data to: ${push_remote}"
				readonly pushcmd="rsync ${opts} ${push_dir} ${push_remote}"
				if [ -n "${PUSH_TIMEOUT}" ]; then
					time timeout --preserve-status "${PUSH_TIMEOUT}" $pushcmd
				else
					time $pushcmd
				fi
				echo "Push task exit with status code: $?"
				echo
			fi
			;;
		pull )
			if [ -n "${PULL_FROM}" ]; then
				echo "Pulling data from: ${pull_remote}"
				readonly pullcmd="rsync ${opts} ${pull_remote} ${pull_dir}"
				if [ -n "${PULL_TIMEOUT}" ]; then
					time timeout --preserve-status "${PULL_TIMEOUT}" $pullcmd
				else
					time $pullcmd
				fi
				echo "Pull task exit with status code: $?"
				echo
			fi
			;;
	esac
done
