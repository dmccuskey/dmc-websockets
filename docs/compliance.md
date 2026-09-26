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

The results are the same whether the client runs headless in plain Lua or in the Solar2D Simulator (build 2026.3731): no case differs. The [Autobahn example](../examples/dmc-websockets-autobahntestsuite/) runs the whole suite in the Simulator and shows its progress on screen:

<img src="../examples/dmc-websockets-autobahntestsuite/images/autobahn-running.png" width="320" alt="The example mid-run: 166 of 301 cases, case 6.21.6, 163 OK and 2 non-strict so far">
<img src="../examples/dmc-websockets-autobahntestsuite/images/autobahn-complete.png" width="320" alt="The finished run: 301 of 301 cases, 296 OK, 2 non-strict, 3 informational, 0 failed, with the cases that weren't OK listed">

For comparison, version 1.3.1 (2015) had 177 OK and 117 failed, mostly in UTF-8 handling (73 failed), large messages (37 failed in section 9) and messages split across network reads (sections 1, 2 and 5).

### Not Plain OK

- **Non-strict, 6.4.3 and 6.4.4:** invalid UTF-8 arrives in pieces within a single frame. dmc-websockets rejects it correctly, but only once the whole frame has arrived rather than at the first invalid byte. Autobahn accepts this, as "non-strict".
- **Informational, 7.1.6:** the server sends a 256KB message, a close and then a ping. The spec leaves the client's exact behavior open; Autobahn records it for information only.
- **Informational, 7.13.1 and 7.13.2:** the server closes with codes 5000 and 65535, which the spec leaves undefined. dmc-websockets treats them as protocol errors.

## Performance (1.4.0)

Autobahn section 9 times each case. These are the 1.4.0 numbers on an Apple M1 Mac, with the Autobahn server in Docker on the same machine (under x86 emulation, so the server is likely the slower side of each exchange).

| Test (case) | Headless, plain Lua 5.1 | Solar2D Simulator, 30 fps |
|---|---|---|
| Echo a 1MB text message (9.1.3) | 0.08 s | 0.30 s |
| Echo a 16MB text message (9.1.6) | 1.02 s | 1.09 s |
| Echo a 16MB binary message (9.2.6) | 0.83 s | 1.09 s |
| 1000 round trips, empty messages (9.7.1) | 2.0 s (2 ms each) | 33.0 s (33 ms each) |
| 1000 round trips, 4KB messages (9.8.6) | 2.8 s (2.8 ms each) | 33.1 s (33 ms each) |

- **Large messages move at about 30 MB/s**, counting both directions: a 16MB message comes in and goes back out in about a second. Headless, about half of that time goes to masking the outgoing copy, which the protocol requires of every client frame. Masking uses lookup tables rather than a bit-library call per byte; before that change, the 16MB echo took 3.9 s headless and 1.5 s in Solar2D.
- **In Solar2D a round trip takes one frame**, whatever the message size. LuaSocket has no callbacks, so dmc-sockets polls its sockets once per frame. At 30 fps that is 33 ms; set `fps = 60` in `config.lua` and the same 1000 round trips take 16.2 s, 16 ms each. Headless, the event loop polls far more often, which is where 2 ms comes from; those times vary by about 20% from run to run.
- In Solar2D, messages that fit in a few frames (1MB and less) take a whole number of frames, so their times say more about the frame rate than about the library.
- Every one of the 54 performance cases passes, up to 16MB messages and 1000-message bursts.

## Running the Suite

- Headless, without Solar2D, using Docker for the fuzzing server and plain Lua for the client: see [Development](development.md#autobahn-testsuite).
- In Solar2D, with the results on screen: see the [Autobahn example](../examples/dmc-websockets-autobahntestsuite/).
