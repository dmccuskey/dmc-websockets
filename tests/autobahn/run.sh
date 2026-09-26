#!/bin/sh
#
# Run the Autobahn fuzzingserver suite against dmc-websockets, headless.
#
# usage: tests/autobahn/run.sh <label>
#   results are saved to tests/autobahn/reports/<label>/
#
# Requires: Docker, Lua 5.1 with luasocket + luafilesystem, and a
# checkout of lua-corovel. Override locations with LUA and COROVEL.

set -e
set -o pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
LABEL=${1:?usage: run.sh <label>}

LUA=${LUA:-$ROOT/../tools/lua51/bin/lua}
COROVEL=${COROVEL:-$ROOT/../lua-corovel}
CONTAINER=autobahn-fuzzingserver
OUT=$HERE/reports/$LABEL

# fresh server each run, so reports only contain this run
docker rm -f $CONTAINER >/dev/null 2>&1 || true
rm -rf "$HERE/reports/.server"
mkdir -p "$HERE/reports/.server"
docker run -d --rm --name $CONTAINER -p 9001:9001 \
	-v "$HERE/config:/config" \
	-v "$HERE/reports/.server:/reports" \
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

# run the client from the repo root so dmc_corona_boot finds dmc_corona.cfg
cd "$ROOT"
# only the project root: dmc_corona_boot searches dmc_corona/ itself, and adding
# it here would load shared modules twice under different names
LUA_PATH="$HERE/?.lua;$COROVEL/?.lua;$COROVEL/corovel/?.lua;$ROOT/?.lua;$($LUA -e 'io.write(package.path)')"
LUA_CPATH="$($LUA -e 'io.write(package.cpath)')"
export LUA_PATH LUA_CPATH
# corovel's network shim requires luasec's ssl.https at load time; plain
# ws:// testing doesn't need it, so stub it when luasec isn't installed
STUB_SSL="if not pcall(require, 'ssl.https') then package.preload['ssl.https']=function() return {} end end"
"$LUA" -e "$STUB_SSL" "$COROVEL/corovel.lua" driver 2>&1 | tee "$HERE/reports/.server/client.log"

docker stop $CONTAINER >/dev/null 2>&1 || true

rm -rf "$OUT"
mv "$HERE/reports/.server" "$OUT"
echo "reports saved to $OUT"
python3 "$HERE/summarize.py" "$OUT"
