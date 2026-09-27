# dmc-websockets Documentation

New here? The [Quick Start](../README.md#quick-start) gets a Solar2D app talking to a WebSocket server in about 10 minutes.

## Start

- [Quick Start](../README.md#quick-start): copy the library in, connect, send and receive
- [Installation](installation.md): project layout, plugins, Android, running outside Solar2D

## Use

- [API reference](api.md): connection options, TLS settings, events, close codes, methods and constants
- [Examples](../examples/README.md): an echo client, the Autobahn test client, and a Pusher client over `wss://`

## Internals

- [Protocol compliance](compliance.md): Autobahn|Testsuite results, section by section
- [RFC 6455](https://www.rfc-editor.org/rfc/rfc6455): the WebSocket protocol

## Contribute

- [Development](development.md): tests, rebuilding the bundled libraries, branches, possible future changes
- [Changelog](../CHANGELOG.md)
- [Issues](https://github.com/dmccuskey/dmc-websockets/issues)

## Project Structure

```text
README.md                   landing page and Quick Start
CHANGELOG.md
LICENSE
docs/                       this documentation
dmc_corona/                 what apps copy
├── dmc_websockets.lua      the WebSocket client (source)
├── dmc_websockets/         frames, handshake, messages, UTF-8, errors (source)
├── dmc_sockets*            from dmc-sockets (generated copy)
└── lib/                    sha1.lua (source) and dmc_lua/ (generated copy)
dmc_corona_boot.lua         loader, from dmc-corona-boot (generated copy)
dmc_corona.cfg              library configuration
main.lua                    runs the unit tests in the Solar2D Simulator
examples/                   sample apps, each with its own generated dmc_corona/
tests/
├── run_unit.sh             unit tests in plain Lua
├── *_spec.lua              unit test specs (lunatest)
└── autobahn/               Autobahn|Testsuite harness
    └── reports/            test reports (gitignored, regenerated)
Snakefile                   build rules for the generated copies
```
