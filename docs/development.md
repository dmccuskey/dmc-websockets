# Development

How to test dmc-websockets, rebuild the libraries it bundles, and where it could go next.

## Tests

Both test suites run in plain Lua 5.1 on macOS or Linux, without Solar2D. The client runs inside [lua-corovel](https://github.com/dmccuskey/lua-corovel), which provides the Solar2D objects the library uses (`Runtime`, `timer`, `system`).

Setup: Lua 5.1 with `luasocket`, `luafilesystem`, `dkjson` and `luabitop` (add `luasec` for `wss://`), and a lua-corovel checkout. The [Autobahn harness README](../tests/autobahn/README.md) has the commands to build Lua with hererocks and the folder layout the scripts expect.

### Unit Tests

```sh
tests/run_unit.sh
```

Runs the lunatest specs in `tests/`: frame reading, UTF-8 validation, close codes and the handshake, and the `WebSocket` class itself (receiving, pongs, keep-alive, failed connections, options) against stand-ins for dmc-sockets and Solar2D's `timer`. Expected output ends with:

```text
  37 passed, 0 failed, 0 error(s), 0 skipped.
```

### HTML5 Bridge

```sh
node --test tests/html5_bridge.test.js
```

Runs the JavaScript bridge (`dmc_corona/dmc_websockets/html5_js.js`) in Node 18 or later against a stand-in for the browser's `WebSocket`: event order, binary data, closing, and connections kept apart. Neither suite runs a browser; check changes to the HTML5 transport in a real HTML5 build too.

### Autobahn Testsuite

```sh
tests/autobahn/run.sh after                 # full run, about 5 minutes
CASES=2.6,9.1.3 tests/autobahn/run.sh quick # selected cases
python3 tests/autobahn/summarize.py tests/autobahn/reports/before tests/autobahn/reports/after
```

Starts the Autobahn fuzzing server in Docker, runs every case against dmc-websockets, and saves the reports to `tests/autobahn/reports/<label>/` (not committed). `summarize.py` prints counts per section, or the cases that changed between two runs. The Docker image is x86-only and runs under emulation on Apple Silicon; the first start takes a minute or two. Current results are on the [compliance page](compliance.md). To run the client in Solar2D instead, start only the server with `tests/autobahn/server.sh start` and open the [Autobahn example](../examples/dmc-websockets-autobahntestsuite/) in the Simulator.

Run the full suite before merging any change to framing, the handshake or the socket code, and compare against the previous run.

## Bundled Libraries

`dmc_corona/` holds copies of the libraries dmc-websockets uses, so an app only has to copy one folder. The copies are generated, not edited by hand:

| Code | Lives in |
|---|---|
| `dmc_corona/dmc_websockets*` | this repository (the source) |
| `dmc_corona/dmc_sockets*` | [dmc-sockets](https://github.com/dmccuskey/dmc-sockets) |
| `dmc_corona/lib/dmc_lua/` | [DMC-Lua-Library](https://github.com/dmccuskey/DMC-Lua-Library) |
| `dmc_corona_boot.lua` | [dmc-corona-boot](https://github.com/dmccuskey/dmc-corona-boot) |

To fix something in a bundled library, change it in its own repository, then rebuild the copies here and in `examples/` with [Snakemake](https://snakemake.readthedocs.io/) (version 7). The build expects the other repositories checked out beside this one, and uses DMC-Corona-Library's shared rules:

```sh
snakemake --cores 1 --forceall build_all
```

The copies come from the sibling checkouts as they are on disk, on whatever branch each has checked out.

## Branches

Changes go on a short-lived branch (`fix/...`, `feat/...`, `docs/...`) and reach `master` through a pull request once the tests pass.

## Possible Future Changes

These are ideas, not plans. Each needs discussion and a concrete use case before it is worked on; decided work goes in [GitHub issues](https://github.com/dmccuskey/dmc-websockets/issues).

- **Reconnecting** ([#17](https://github.com/dmccuskey/dmc-websockets/issues/17)): make `auto_reconnect` work, building on keep-alive (which detects a dead connection): when to retry, how often, and which state carries over to the new connection.
- **Wait for the server's close after a protocol error** ([#19](https://github.com/dmccuskey/dmc-websockets/issues/19)): RFC 6455 section 7.1.7 prefers that the client stop reading and let the server close the TCP connection; the client currently closes it itself.
- **Strict mid-frame UTF-8 checks** ([#20](https://github.com/dmccuskey/dmc-websockets/issues/20)): validate text as each piece of a frame arrives, which would make Autobahn cases 6.4.3 and 6.4.4 strict.
- **Faster bit operations outside Solar2D:** the bit-operations shim (lua-bit-shim) tries `plugin.bit`, then a pure-Lua version; trying LuaBitOp (`bit`) in between would make plain-Lua use, including the test suites, faster.
- **Certificate verification by default** ([#18](https://github.com/dmccuskey/dmc-websockets/issues/18)) for `wss://`, with a way to supply CA certificates on each platform.
- **Extensions** ([#21](https://github.com/dmccuskey/dmc-websockets/issues/21)), such as permessage-deflate compression (Autobahn sections 12 and 13).
