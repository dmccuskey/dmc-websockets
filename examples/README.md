# Examples

Each folder is a complete Solar2D project with its own copy of the library: open its `main.lua` in the Solar2D Simulator. The echo and Pusher examples draw nothing; they print to the Simulator's console.

One of them also runs in your browser: [try the echo demo](https://dmccuskey.github.io/dmc-websockets/).

## Autobahn Testsuite

<img src="dmc-websockets-autobahntestsuite/images/autobahn-running.png" width="240" alt="The example mid-run: 166 of 301 cases, case 6.21.6, 163 OK and 2 non-strict so far">

[dmc-websockets-autobahntestsuite](dmc-websockets-autobahntestsuite/): runs the 301 [Autobahn|Testsuite](https://github.com/crossbario/autobahn-testsuite) conformance cases against the library inside the Simulator, with a progress bar and a running tally of results. It needs the fuzzing server running in Docker; its [README](dmc-websockets-autobahntestsuite/README.md) has the steps.

## Echo

[dmc-websockets-echo](dmc-websockets-echo/): connects to the public echo server at `wss://echo.websocket.org`, sends five messages half a second apart, prints each echo, and closes the connection. The server greets each connection with a `Request served by` message before it echoes. The console shows:

```text
Received event: ONOPEN
=== Sending 5 messages ===

Sending message (1): 'Current app time: 434.379'
Received event: ONMESSAGE
echoed message: 'Request served by 2867542a161128'

Received event: ONMESSAGE
echoed message: 'Current app time: 434.379'

...

Sending message (5): 'Current app time: 3189.219'
Received event: ONMESSAGE
echoed message: 'Current app time: 3189.219'

Received event: ONCLOSE
code:reason	1000	Purpose for connection has been fulfilled
```

## Echo Demo for the Browser

<img src="dmc-websockets-html5/images/demo-open.png" width="240" alt="The demo connected: the server's greeting, then three messages sent and echoed back">

[dmc-websockets-html5](dmc-websockets-html5/): the echo example with a screen. A button sends a message to `wss://echo.websocket.org`, a list shows what was sent and what came back, and a second button closes the connection or opens a new one. The same code runs in the Simulator and, as an HTML5 build, in the browser: [try it](https://dmccuskey.github.io/dmc-websockets/). Its [README](dmc-websockets-html5/README.md) has the build steps.

## Pusher

[dmc-websockets-pusher](dmc-websockets-pusher/): connects to the [Pusher](https://pusher.com/) Channels service over `wss://` with a public app key, and prints the messages it receives. Pusher answers with its `connection_established` event; the example doesn't subscribe to a channel, so the connection then stays open and quiet:

```text
webSocketsEvent_handler	onopen
Received event: ONOPEN
webSocketsEvent_handler	onmessage
Received event: ONMESSAGE
message: '{"event":"pusher:connection_established","data":"{\"socket_id\":\"913651.3296207\",\"activity_timeout\":120}"}'
```
