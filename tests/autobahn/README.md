# Autobahn test harness

Runs the [Autobahn|Testsuite](https://github.com/crossbario/autobahn-testsuite)
fuzzing server against dmc-websockets **headless**: the client runs in plain
Lua 5.1 inside [lua-corovel](https://github.com/dmccuskey/lua-corovel), which
provides Corona's `Runtime`, `timer` and `system` objects. No Solar2D needed.

## Requirements

- Docker. The Autobahn image is x86-only and runs under emulation on Apple Silicon.
- Lua 5.1 with `luasocket`, `luafilesystem`, `dkjson` (e.g. via `hererocks`)
- a `lua-corovel` checkout

By default `run.sh` expects Lua and lua-corovel beside this repo:

```
my-projects/
  dmc-websockets/          this repo
  lua-corovel/             git clone https://github.com/dmccuskey/lua-corovel.git
  tools/lua51/bin/lua      Lua 5.1 (see below)
```

To use other locations, set `LUA=` and `COROVEL=` to absolute paths, e.g.
`COROVEL=/path/to/lua-corovel tests/autobahn/run.sh after`. To build the Lua
tools, from the folder that holds this repo:

```sh
python3 -m venv tools/py && tools/py/bin/pip install hererocks
tools/py/bin/hererocks tools/lua51 -l 5.1 -r latest
for r in luasocket luafilesystem dkjson luabitop; do tools/lua51/bin/luarocks install $r; done
```

`tests/run_unit.sh` uses the same `LUA` default.

## Usage

```sh
tests/autobahn/run.sh before          # full run, saved to reports/before/
tests/autobahn/run.sh after
python3 tests/autobahn/summarize.py tests/autobahn/reports/before tests/autobahn/reports/after
```

Options (environment variables):

| var | default | |
|---|---|---|
| `CASE_TIMEOUT` | 60 | seconds before a hung case is abandoned |
| `MAX_CASES` | all | run only the first N cases (smoke test) |
| `AUTOBAHN_URL` | `ws://127.0.0.1:9001` | |

The HTML report is at `reports/<label>/clients/index.html`.
Sections 12 and 13 (permessage-deflate) are excluded in `config/fuzzingserver.json`
because the library doesn't implement compression.
