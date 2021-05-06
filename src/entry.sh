#!/bin/bash
set -eo pipefail

case "${1:-server}" in
	server )
		exec /bin/server.sh ${@:2}
		;;
	client )
		exec /bin/client.sh ${@:2}
		;;

	* )
		echo "Unknown command ${1}, try 'server' or 'client'."
		;;
esac
