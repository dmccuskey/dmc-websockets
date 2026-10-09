# Changelog

## 1.5.0 (2026-10-09)

### Added

- HTML5 builds: in the browser the library uses the browser's own WebSocket, through a small JavaScript bridge (`dmc_corona/dmc_websockets/html5_js.js`), with the same API and events. Browsers don't let scripts send pings or set handshake headers, so `ping()`, `ONPONG`, `keepalive`, `origin` and `ssl_params` aren't available there. See [HTML5 Builds](docs/api.md#html5-builds).

### Changed

- `send()` raises an error for text that isn't valid UTF-8. RFC 6455 requires text to be UTF-8, and a server fails the connection (1007) when it isn't; send other data as `ws.BINARY`.

## 1.4.1 (unreleased)

### Fixed

- The global `_extend` is no longer created: 1.4.0 removed it from dmc-websockets' own module, but the bundled dmc-sockets still set it. Rebuilt with dmc-sockets without it.

## 1.4.0 (2026-10-01)

Passes the Autobahn|Testsuite (sections 1-10: 296 OK, 2 non-strict, 3 informational, 0 failed; 1.3.1 had 117 failures). See [Protocol compliance](docs/compliance.md).

### Fixed

- The echo example failed with `ONERROR`: echo.websocket.org now only answers `wss://`. It also closed before the last echo arrived.
- Messages split across network reads were misread, which caused random disconnects and protocol errors ([#5](https://github.com/dmccuskey/dmc-websockets/issues/5), [#8](https://github.com/dmccuskey/dmc-websockets/issues/8)).
- Messages larger than the socket's send buffer (roughly 64-256KB) were cut short (fixed in dmc-sockets).
- `wss://` connections failed with `attempt to call method 'setoption'`, servers on shared hosts and CDNs refused them (no SNI), and TLS 1.0 was forced ([#6](https://github.com/dmccuskey/dmc-websockets/issues/6); fixed in dmc-sockets). The TLS version is now negotiated.
- Close frames sent the reason as a number (`"1002"`) instead of text.
- Handshake: accept `Connection` headers with several tokens and headers without a space after the colon.
- A server that can't be reached, or a failed TLS handshake, now gives `ONERROR` (code 3000, with the socket's message in `event.emsg`) instead of `ONCLOSE` with no code.
- A connection created without the `throttle` option no longer resets the shared setting to `OFF`.
- The `query` option was ignored; it's now added to the `uri`'s query string.
- A handshake response that arrived in more than one network read was never finished.
- Close-code error messages needed a string patch that only another module happened to load.
- The global `_extend` is no longer created (the module uses lua_utils instead of its own copy).
- The `throttle` setting had no effect (fixed in dmc-sockets). It now spaces out socket checks; see the change to its default below.

### Changed

- Text messages and close reasons are checked for valid UTF-8; invalid ones close the connection with 1007.
- Stricter protocol checks: masked frames from the server and close codes of 5000 and above are rejected, and the connection fails if the server selects a subprotocol or extension the client didn't request. Close codes 1012-1014 are accepted.
- `ssl_params.protocol` defaults to `'any'` (was `'tlsv1'`) and accepts `'tlsv1_1'`, `'tlsv1_2'` and `'tlsv1_3'`.
- `WebSockets.VERSION` and the user agent now match the library version.
- The default `throttle` is `OFF` (a check every frame; it was nominally `MEDIUM`), so apps behave as before now that the setting works.
- The bundled libraries (dmc-sockets, DMC Lua library, dmc-corona-boot) are updated.
- Documentation: a Configuration section (`[DMC_WEBSOCKETS]`) and Known Issues in the API reference, an examples overview, and source headers link to this repository instead of the old docs site. The examples' `dmc_corona.cfg` hold only the sections this library uses.
- Receiving large messages is faster: incoming data is kept as a list of pieces and joined once the frame is complete, instead of being copied again with each network read. A 16MB message arriving in 64KB reads takes 0.01 s instead of 0.6 s to buffer (headless). The Autobahn 16MB echo, whose data arrives in fewer, larger reads, is unchanged at about 1 s.
- The handshake sends a `User-Agent` header (`WebSockets.USER_AGENT`).
- Sending large messages is faster: masking the outgoing frame used a bit-library call per byte and now uses lookup tables. Echoing a 16MB message takes 1.0 s instead of 3.9 s headless, and 1.1 s instead of 1.5 s in Solar2D.

### Added

- `ONPONG` event and `ping()` (pong events from [#2](https://github.com/dmccuskey/dmc-websockets/pull/2), thanks to @chkuendig). Pongs are reported as they arrive, even in the middle of a fragmented message.
- Keep-alive: the `keepalive` and `keepalive_timeout` options ping on a timer and fail the connection (`ONERROR`, code 3003) when no pong comes back; `ws.latency` gives the last round trip ([#3](https://github.com/dmccuskey/dmc-websockets/issues/3)).
- `origin` option, sent as the handshake's `Origin` header ([#1](https://github.com/dmccuskey/dmc-websockets/issues/1)).
- Headless test suites: unit tests (`tests/run_unit.sh`) and an Autobahn|Testsuite harness (`tests/autobahn/`), both in plain Lua without Solar2D.
- Documentation: Quick Start, installation, API reference, compliance results, development guide.

### Removed

- `docs/autobahn-test-results.pdf` (2014 results), replaced by [docs/compliance.md](docs/compliance.md).
