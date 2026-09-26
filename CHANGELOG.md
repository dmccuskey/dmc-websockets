# Changelog

## 1.4.0 (unreleased)

Passes the Autobahn|Testsuite (sections 1-10: 296 OK, 2 non-strict, 3 informational, 0 failed; 1.3.1 had 117 failures). See [Protocol compliance](docs/compliance.md).

### Fixed

- Messages split across network reads were misread, which caused random disconnects and protocol errors ([#5](https://github.com/dmccuskey/dmc-websockets/issues/5), [#8](https://github.com/dmccuskey/dmc-websockets/issues/8)).
- Messages larger than the socket's send buffer (roughly 64-256KB) were cut short (fixed in dmc-sockets).
- `wss://` connections failed with `attempt to call method 'setoption'`, servers on shared hosts and CDNs refused them (no SNI), and TLS 1.0 was forced ([#6](https://github.com/dmccuskey/dmc-websockets/issues/6); fixed in dmc-sockets). The TLS version is now negotiated.
- Close frames sent the reason as a number (`"1002"`) instead of text.
- Handshake: accept `Connection` headers with several tokens and headers without a space after the colon.

### Changed

- Text messages and close reasons are checked for valid UTF-8; invalid ones close the connection with 1007.
- Stricter protocol checks: masked frames from the server and close codes of 5000 and above are rejected, and the connection fails if the server selects a subprotocol or extension the client didn't request. Close codes 1012-1014 are accepted.
- `ssl_params.protocol` defaults to `'any'` (was `'tlsv1'`) and accepts `'tlsv1_1'`, `'tlsv1_2'` and `'tlsv1_3'`.
- `WebSockets.VERSION` and the user agent now match the library version.
- The bundled libraries (dmc-sockets, DMC Lua library) are updated.

### Added

- Headless test suites: unit tests (`tests/run_unit.sh`) and an Autobahn|Testsuite harness (`tests/autobahn/`), both in plain Lua without Solar2D.
- Documentation: Quick Start, installation, API reference, compliance results, development guide.

### Removed

- `docs/autobahn-test-results.pdf` (2014 results), replaced by [docs/compliance.md](docs/compliance.md).
