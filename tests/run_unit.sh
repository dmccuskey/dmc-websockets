#!/bin/sh
#
# Run the lunatest unit specs with plain Lua 5.1.
#
# usage: tests/run_unit.sh
#   override the interpreter with LUA=

set -e

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
LUA=${LUA:-$ROOT/../tools/lua51/bin/lua}

cd "$ROOT"
LUA_PATH="$ROOT/?.lua;$HERE/?.lua;$($LUA -e 'io.write(package.path)')"
LUA_CPATH="$($LUA -e 'io.write(package.cpath)')"
export LUA_PATH LUA_CPATH

# dmc_corona_boot needs a json module and Corona's system.pathForFile
"$LUA" -e "
package.preload.json = package.preload.json or function() return require 'dkjson' end
system = system or { pathForFile=function( f ) return f end, ResourceDirectory='.' }
local lunatest = require 'lunatest'
lunatest.suite( 'dmc_websockets_spec' )
lunatest.suite( 'dmc_websockets_frame_spec' )
lunatest.suite( 'dmc_websockets_class_spec' )
lunatest.suite( 'dmc_websockets_html5_spec' )
lunatest.run()
" 2>&1 | grep -v '^Lua Patch::'
