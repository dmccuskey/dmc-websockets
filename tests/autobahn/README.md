# Autobahn test harness

Runs the [Autobahn|Testsuite](https://github.com/crossbario/autobahn-testsuite)
fuzzing server against dmc-websockets **headless**: the client runs in plain
Lua 5.1 inside [lua-corovel](https://github.com/dmccuskey/lua-corovel), which
provides Corona's `Runtime`, `timer` and `system` objects. No Solar2D needed.

## Requirements

- Docker. The Autobahn image is x86-only and runs under emulation on Apple Silicon.
- Lua 5.1 with `luasocket`, `luafilesystem`, `dkjson` (e.g. via `hererocks`)
- a `lua-corovel` checkout

By default `run.sh` looks for `../tools/lua51/bin/lua` and `../lua-corovel`
beside this repo; override with `LUA=` and `COROVEL=`.

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
