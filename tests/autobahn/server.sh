#!/bin/sh
#
# Start or stop the Autobahn fuzzingserver on its own, for clients that
# run elsewhere (e.g. the Solar2D example in examples/dmc-websockets-autobahntestsuite).
#
# usage: tests/autobahn/server.sh start [label]   default label: solar2d
#        tests/autobahn/server.sh stop
#   reports are written to tests/autobahn/reports/<label>/clients/

set -e

HERE=$(cd "$(dirname "$0")" && pwd)
CONTAINER=autobahn-fuzzingserver

case "$1" in
start)
	OUT=$HERE/reports/${2:-solar2d}
	docker rm -f $CONTAINER >/dev/null 2>&1 || true
	rm -rf "$OUT"
	mkdir -p "$OUT"
	docker run -d --rm --name $CONTAINER -p 9001:9001 \
		-v "$HERE/config:/config" \
		-v "$OUT:/reports" \
		--platform linux/amd64 crossbario/autobahn-testsuite \
		wstest -m fuzzingserver -s /config/fuzzingserver.json >/dev/null

	printf "waiting for fuzzingserver"
	i=0
	# the server buffers its stdout, so probe the port instead of the logs
	until [ "$(curl -s -m 2 -o /dev/null -w '%{http_code}' http://127.0.0.1:9001/)" != "000" ]; do
		i=$((i+1)); [ $i -gt 120 ] && { echo " timed out"; docker logs $CONTAINER; exit 1; }
		printf "."; sleep 1
	done
	echo
	echo "fuzzingserver listening on ws://127.0.0.1:9001"
	echo "reports: $OUT/clients/index.html (after the client asks for updateReports)"
	echo "stop with: $0 stop"
	;;
stop)
	docker stop $CONTAINER >/dev/null 2>&1 && echo "stopped" || echo "not running"
	;;
*)
	echo "usage: $0 start [label] | stop" >&2
	exit 2
	;;
esac
