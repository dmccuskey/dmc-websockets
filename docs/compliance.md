# Protocol Compliance

dmc-websockets is tested with the [Autobahn|Testsuite](https://github.com/crossbario/autobahn-testsuite), the standard conformance suite for WebSocket implementations. Its fuzzing server sends a client hundreds of valid and invalid conversations and grades how the client responds.

## Results

Version 1.4.0, sections 1 to 10 (301 cases). Sections 12 and 13 test compression (permessage-deflate), which dmc-websockets doesn't support, so they are excluded.

| Section | Cases | OK | Non-strict | Informational | Failed |
|---|---|---|---|---|---|
| 1 Framing | 16 | 16 | | | |
| 2 Pings and pongs | 11 | 11 | | | |
| 3 Reserved bits | 7 | 7 | | | |
| 4 Opcodes | 10 | 10 | | | |
| 5 Fragmentation | 20 | 20 | | | |
| 6 UTF-8 handling | 145 | 143 | 2 | | |
| 7 Close handling | 37 | 34 | | 3 | |
| 9 Limits and performance | 54 | 54 | | | |
| 10 Miscellaneous | 1 | 1 | | | |
| **Total** | **301** | **296** | **2** | **3** | **0** |

The results are the same whether the client runs headless in plain Lua or in the Solar2D Simulator (build 2026.3731): no case differs.

For comparison, version 1.3.1 (2015) had 177 OK and 117 failed, mostly in UTF-8 handling (73 failed), large messages (37 failed in section 9) and messages split across network reads (sections 1, 2 and 5).

### Not Plain OK

- **Non-strict, 6.4.3 and 6.4.4:** invalid UTF-8 arrives in pieces within a single frame. dmc-websockets rejects it correctly, but only once the whole frame has arrived rather than at the first invalid byte. Autobahn accepts this, as "non-strict".
- **Informational, 7.1.6:** the server sends a 256KB message, a close and then a ping. The spec leaves the client's exact behavior open; Autobahn records it for information only.
- **Informational, 7.13.1 and 7.13.2:** the server closes with codes 5000 and 65535, which the spec leaves undefined. dmc-websockets treats them as protocol errors.

## Running the Suite

- Headless, without Solar2D, using Docker for the fuzzing server and plain Lua for the client: see [Development](development.md#autobahn-testsuite).
- In Solar2D, with the results on screen: see the [Autobahn example](../examples/dmc-websockets-autobahntestsuite/).
