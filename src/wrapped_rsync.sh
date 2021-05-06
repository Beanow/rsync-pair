#!/bin/bash
set -eo pipefail
shopt -s extglob

readonly DIRECTION=${1:?Direction argument is required}
readonly JAIL_PATH_TPL="${2:-/media/%s/}"
readonly JAIL_PATH=$(printf "${JAIL_PATH_TPL}" "${DIRECTION}")

# Read the bwlimit from config file. As the sshd won't pass it to us through ENV.
readonly BWLIMIT_SETTING=$(cat /etc/rsync_bwlimit)
readonly SERVER_BWLIMIT=${BWLIMIT_SETTING:-0}

# Writes to stderr are printed by rsync client as-is.
error() { >&2 echo "$@"; }
die() { error "$@"; exit 1; }

# Later assumptions and parsing requires --no-protect-args mode.
deny_protect_args() {
	# Make sure we include -e, because it's string value likely contains 's'. Which is not the same as '-s'.
	eval set -- "$(getopt --quiet -o s,e: --long protect-args -- ${@})"
	while true; do
		case "$1" in
			-s | --protect-args ) die "Server disallows option: --protect-args (-s)" ;;
			'' ) break ;;
			* ) shift ;;
		esac
	done
}

# Deny any long opts that may escape the jail.
deny_long_opts() {
	eval set -- "${@}"
	local DENIED_OPTS=false
	while true; do
		case "$1" in
			--partial-dir |\
			--backup-dir |\
			--temp-dir |\
			--mkpath |\
			--fake-super |\
			--no-super |\
			--super )
				DENIED_OPTS=true
				error "Server disallows option: $1"
				shift
				;;
			'' ) break ;;
			* ) shift ;;
		esac
	done

	$DENIED_OPTS && exit 1 || true
}

case "${DIRECTION}" in
	# Being pushed to as the server, means we're receiving/downloading.
	# Being pulled from as the server, means we're sending/uploading.
	push ) readonly SENDER=false ;;
	pull ) readonly SENDER=true ;;
	* ) die "Unknown direction ${1}, try 'push' or 'pull'." ;;
esac

# Note: must use qoutes here.
eval set -- "${SSH_ORIGINAL_COMMAND}"

# --server and --sender MUST be at the start of the options list.
# We're shifting these off to isolate the remainder.
REQUESTED_SERVER=false
REQUESTED_SENDER=false
while true; do
	case "$1" in
		rsync ) shift ;;
		--server ) REQUESTED_SERVER=true; shift ;;
		--sender ) REQUESTED_SENDER=true; shift ;;
		* ) break; ;;
	esac
done

[ $REQUESTED_SERVER == false ] && die "Server is expecting --server option."
[ $REQUESTED_SENDER != $SENDER ] && die "Mismatched direction, user is only allowed to '${DIRECTION}'."

# Below assumptions and parsing requires --no-protect-args mode.
deny_protect_args "${@}"

# Preserve the arguments given by the client.
let OPTS_END=${#@}-2
readonly REST_OPTS=${@: 1:OPTS_END}
readonly REQUESTED_SRC_PATH=${@: -2:1}
readonly REQUESTED_DST_PATH=${@: -1:1}

[ "${REQUESTED_SRC_PATH}" != "." ] && die "First positional argument must always be '.' (dot)."
[ "${REQUESTED_DST_PATH}" != "${JAIL_PATH}" ] && error "Warning: requested path '${REQUESTED_DST_PATH}' will be ignored, using server enforced path '${JAIL_PATH}'!"

# Deny any long opts that may escape the jail.
deny_long_opts "${@}"

# Special handling of --bwlimit=1234
# Strip the --bwlimit argument, needs extglob support.
readonly REST_OPTS_NO_BWLIMIT=${REST_OPTS/--bwlimit[= ]+([[:digit:]])/}

# Note: must use qoutes here.
eval set -- "$(getopt --quiet --long bwlimit: -- ${REST_OPTS})"

REQUESTED_BWLIMIT='0'
while true; do
  case "$1" in
    --bwlimit ) REQUESTED_BWLIMIT="$2"; shift 2 ;;
	-- ) break ;;
    * ) shift ;;
  esac
done

# Treat the server's bwlimit setting as a maximum. On request by the client we can lower it.
readonly CLIENT_BWLIMIT=${REQUESTED_BWLIMIT:-0}
BWLIMIT=${SERVER_BWLIMIT}
# Should either limit be 0 (unlimited), use the other.
# As that could only be more restrictive or also unlimited.
if [ "$SERVER_BWLIMIT" -eq "0" ]; then
	BWLIMIT=$CLIENT_BWLIMIT
# When both have a finite limit, pick the smallest one. Like a min(a, b) function.
elif [ "$SERVER_BWLIMIT" -gt "$CLIENT_BWLIMIT" ] && [ "$CLIENT_BWLIMIT" -gt "0" ]; then
	BWLIMIT=$CLIENT_BWLIMIT
fi

# Log server rsync version for sanity.
error "Server rsync version: $(rsync --version | head -n1)"

if ${SENDER}; then
	error "Server limiting bandwidth to --bwlimit=${BWLIMIT} from min(server:${SERVER_BWLIMIT}, client:${CLIENT_BWLIMIT})"
else
	error "Bandwidth is dictated by client: --bwlimit=${CLIENT_BWLIMIT}"
fi

# Reconstruct desired command.
$SENDER && readonly SENDER_OPT="--sender"

readonly CMD="sudo rsync --server ${SENDER_OPT} ${REST_OPTS_NO_BWLIMIT} --bwlimit=${BWLIMIT} . ${JAIL_PATH}"
error "Final server command: $CMD"
exec $CMD
