# API Reference

Load the library with:

```lua
local WebSockets = require 'dmc_corona.dmc_websockets'
```

| Item | Kind | Summary |
|---|---|---|
| [`WebSockets{ ... }`](#creating-a-connection) | constructor | Create a connection |
| [`ws:addEventListener()`](#events) | method | Listen for connection events |
| [`ws:send()`](#send) | method | Send a text or binary message |
| [`ws:close()`](#close) | method | Close the connection |
| [`ws:ping()`](#ping) | method | Send a ping; the server answers with `ONPONG` |
| [`ws:connect()`](#connect) | method | Connect, when created with `auto_connect=false` |
| [`ws.readyState`](#readystate) | property | Connection status |
| [`ws.latency`](#latency) | property | Round trip of the last keep-alive ping |
| [`ws.throttle`](#throttle) | property | How often sockets are checked for data |
| [`ws:removeSelf()`](#removeself) | method | Destroy the object |
| [HTML5 builds](#html5-builds) | | What works differently in a browser |
| [Configuration](#configuration) | file | The `[DMC_WEBSOCKETS]` section of `dmc_corona.cfg` |
| [Known issues](#known-issues) | | Behavior that differs from what the API suggests |

## Creating a Connection

```lua
local ws = WebSockets{
	uri='wss://chat.example.com/room/lobby?user=sample-user',
	protocols={ 'chat.v2', 'chat.v1' },
}
```

The connection starts right away, unless `auto_connect` is `false`.

### Options

| Option | Default | Description |
|---|---|---|
| `uri` | (required) | Server address: `ws://` or `wss://`, host, optional port, path and query string |
| `query` | none | Query string to add to `uri`'s: a string (`'user=sam'`) or a table (`{ user='sam' }`, names and values escaped, in sorted order) |
| `origin` | none | Value of the `Origin` header, for servers that check it (browsers always send one; other clients needn't) |
| `protocols` | none | Subprotocols to request, a string or a list. The server may choose one of them; if it chooses one that wasn't requested, the connection fails |
| `port` | from `uri` | Port, overriding the one in `uri` (default 80 for `ws://`, 443 for `wss://`) |
| `auto_connect` | `true` | Connect as soon as the object is created. With `false`, call [`connect()`](#connect) |
| `ssl_params` | see [TLS Settings](#tls-settings) | TLS settings for `wss://` |
| `throttle` | unchanged | How often sockets are checked for data, see [`throttle`](#throttle). Shared by all connections; given here, it's applied when this one connects |
| `keepalive` | off | Milliseconds between keep-alive pings, see [Keep-Alive](#keep-alive) |
| `keepalive_timeout` | `10000` | Milliseconds to wait for each keep-alive pong before failing the connection |

The handshake sends `User-Agent: dmc_websockets/<version>`. Not implemented: `auto_reconnect` is accepted but has no effect, and there is no extension support (such as compression).

### Keep-Alive

A connection that silently dies (a phone changing networks, a router dropping it) isn't noticed until the app sends something. With `keepalive`, the library sends a ping that many milliseconds after the connection opens and after each pong; if no pong arrives within `keepalive_timeout`, the connection fails with `ONERROR`, code 3003.

```lua
local ws = WebSockets{
	uri='wss://chat.example.com/',
	keepalive=15000,          -- ping every 15 seconds
	keepalive_timeout=5000,   -- give up after 5 seconds without an answer
}
```

Each answered ping updates [`ws.latency`](#latency) and gives `ONPONG` with `event.latency`. Reconnecting is up to the app: create a new object.

### TLS Settings

`ssl_params` is a table passed to luasec (or Solar2D's OpenSSL plugin) for `wss://` connections. The defaults suit most servers:

| Field | Default | Values |
|---|---|---|
| `protocol` | `'any'` | `'any'` negotiates the highest version both sides support. `'tlsv1_3'`, `'tlsv1_2'`, `'tlsv1_1'`, `'tlsv1'` and `'sslv3'` force one version; most servers refuse TLS 1.0 and older |
| `verify` | `'none'` | `'none'` or `'peer'` |
| `mode` | `'client'` | `'client'` |
| `options` | `'all'` | `'all'` |

The server name is sent during the handshake (SNI), which servers on shared hosts and CDNs require.

`verify='none'` means the server's certificate is not checked. The connection is encrypted, but not protected against someone impersonating the server.

## Events

All events arrive through one listener:

```lua
ws:addEventListener( ws.EVENT, function( event )
	if event.type == ws.ONMESSAGE then
		print( event.message.type, event.message.data )
	end
end )
```

| `event.type` | When | Fields |
|---|---|---|
| `ws.ONOPEN` | The connection is ready to send and receive | |
| `ws.ONMESSAGE` | A complete message arrived | `event.message.data` (string), `event.message.type` (`ws.TEXT` or `ws.BINARY`) |
| `ws.ONPONG` | A pong arrived, answering [`ping()`](#ping) or a keep-alive ping | `event.data` (the ping's data), `event.latency` (milliseconds, keep-alive pings only) |
| `ws.ONCLOSE` | The connection closed | `event.code`, `event.reason` |
| `ws.ONERROR` | The connection failed: it couldn't be opened, or failed after it was | `event.code`, `event.reason`, `event.emsg` (the socket's message, when there is one), `event.isError` (`true`) |

After `ONCLOSE` or `ONERROR` the object is closed; create a new one to reconnect.

If the server can't be reached, or the TLS handshake fails, you get `ONERROR` with code 3000 and the reason in `event.emsg` (such as `'timeout'`, or the TLS library's message).

### Close and Error Codes

`event.code` is either a [WebSocket close code](https://www.rfc-editor.org/rfc/rfc6455#section-7.4.1) sent by the server or by this library, or one of the library's own codes:

| Code | Meaning |
|---|---|
| 1000 | Normal close |
| 1001 | Going away (server shutting down, or the page/app leaving) |
| 1002 | Protocol error: the server sent something RFC 6455 doesn't allow |
| 1007 | Invalid data: a text message or close reason that isn't valid UTF-8 |
| 1012-1014 | Service restart, try again later, bad gateway |
| 3000 | Network error: the server couldn't be reached, the TLS handshake failed, or sending failed |
| 3001 | The handshake request could not be sent |
| 3002 | The server's handshake response was invalid |
| 3003 | No pong to a keep-alive ping within `keepalive_timeout` |
| 9999 | Internal error in the library (please [report it](https://github.com/dmccuskey/dmc-websockets/issues)) |

## Methods

### send()

```lua
ws:send( 'hello' )                          -- text
ws:send( png_bytes, { type=ws.BINARY } )    -- binary
```

`data` must be a string. Text must be valid UTF-8, as RFC 6455 requires (`send()` raises an error otherwise); send other data as `ws.BINARY`. Messages are queued until they can be written, so `send()` doesn't block, and large messages are sent in pieces over several frames of the app.

### close()

```lua
ws:close()
```

Starts the closing handshake with code 1000. `ONCLOSE` follows once the server answers, or after a timeout.

### ping()

```lua
ws:ping()            -- no data
ws:ping( 'abc' )     -- up to 125 bytes, echoed back in the pong
```

The server answers with a pong, which gives `ONPONG` with the same `event.data`. Does nothing unless the connection is open. For regular pings with a timeout, use the [`keepalive`](#keep-alive) option instead.

### connect()

Opens the connection. Only needed when the object was created with `auto_connect=false`.

### removeSelf()

Destroys the object and its listeners. Close the connection first.

## Properties

### latency

The round trip of the last answered keep-alive ping, in milliseconds; `nil` until one is answered, or without [`keepalive`](#keep-alive). It includes the time until the socket is next checked, so it's at least one frame with the default `throttle`.

### readyState

The connection status, one of:

| Constant | Value | Meaning |
|---|---|---|
| `ws.NOT_ESTABLISHED` | 0 | Connecting |
| `ws.ESTABLISHED` | 1 | Open |
| `ws.CLOSING_HANDSHAKE` | 2 | Closing |
| `ws.CLOSED` | 3 | Closed |

### throttle

How often the library checks sockets for incoming data, shared by all connections. The default, `OFF`, checks once per frame, so a round trip takes one frame (see [Performance](compliance.md#performance-140)). The other settings check less often, which saves a little work per frame but adds latency: with `MEDIUM`, a round trip takes about 66 ms.

| Constant | Checks sockets |
|---|---|
| `ws.OFF` | every frame (the default) |
| `ws.LOW` | at most every 33 ms, about 30 times a second |
| `ws.MEDIUM` | at most every 66 ms, about 15 times a second |
| `ws.HIGH` | at most once a second |

Setting `ws.throttle` changes the setting for all connections. A connection created with the `throttle` option also applies it when it connects; one created without it leaves the setting as it is.

## Constants

| Constant | Value |
|---|---|
| `ws.EVENT` | Event name to listen for |
| `ws.ONOPEN`, `ws.ONMESSAGE`, `ws.ONPONG`, `ws.ONCLOSE`, `ws.ONERROR` | Event types |
| `ws.TEXT`, `ws.BINARY` | Message types |
| `WebSockets.VERSION` | Library version, e.g. `'1.5.0'` |
| `WebSockets.USER_AGENT` | `'dmc_websockets/1.5.0'`, sent in the handshake's `User-Agent` header |

## HTML5 Builds

In the browser there are no sockets, so the library uses the browser's own WebSocket, through a small JavaScript bridge. The API and events are the same, and the browser does the handshake, framing, TLS and the answers to the server's pings. Events are delivered from `enterFrame`, as with sockets, but every frame: `throttle` has no effect there.

The browser keeps some things to itself:

| Option or method | In an HTML5 build |
|---|---|
| [`ping()`](#ping), `keepalive` | Raise an error: browsers don't let scripts send pings or see pongs, so `ONPONG` never comes. To notice a dead connection, have the app and server exchange their own messages |
| `origin`, `ssl_params` | Raise an error: the browser sends its own `Origin` and uses its own TLS settings and certificate checks. The `User-Agent` header is the browser's too |
| `ws.latency` | Always `nil` |

Failures look the same as elsewhere, but with less detail: browsers don't say why a connection failed, so an unreachable server, a refused handshake, a TLS problem and a dropped connection all give `ONERROR` code 3000, with a generic `event.emsg`. A close from the server gives `ONCLOSE` with its code and reason. `close()` while still connecting gives `ONCLOSE` right away. Pages served over `https://` can only open `wss://` connections.

An HTML5 app only runs while its page has the focus: Solar2D suspends it when the browser window loses focus, and a browser stops drawing a tab it can't see. Nothing is delivered while it is suspended, and timers don't run. The browser keeps the connection open and answers the server's pings; the events which arrived meanwhile are delivered, in order, once the page has the focus again.

Binary messages cross the bridge as one character per byte, which JSON carries as UTF-8: a byte from 0x80 up takes two bytes and a control byte six, so a large binary message costs more than its size in transit. Text crosses as it is.

## Configuration

dmc-websockets has no settings in effect. Its `dmc_corona.cfg` section, `[DMC_WEBSOCKETS]`, can be left out or left empty:

| Option | Default | Description |
|---|---|---|
| `DEBUG_ACTIVE` | `false` | Read, but has no effect yet |

Connection settings go in the [options](#options) of each connection instead. How often sockets are checked can also be set for the whole app in dmc-sockets' `[DMC_SOCKETS]` section ([dmc-sockets Configuration](https://github.com/dmccuskey/dmc-sockets/blob/master/docs/api.md#configuration)), but a connection's `throttle` option, when given, overrides it when it connects. The file's format, and the `[DMC_CORONA]` section every DMC library uses, are described in [dmc-corona-boot's Configuration](https://github.com/dmccuskey/dmc-corona-boot/blob/master/docs/configuration.md).

## Known Issues

- **No reconnecting:** `auto_reconnect` is accepted but does nothing. Create a new object to reconnect; [keep-alive](#keep-alive) tells you when it's needed ([#17](https://github.com/dmccuskey/dmc-websockets/issues/17)).
- **Certificates aren't checked** by default for `wss://` (`verify='none'`, see [TLS Settings](#tls-settings); [#18](https://github.com/dmccuskey/dmc-websockets/issues/18)).
- **`throttle` is shared** by every connection.
- Extensions (such as compression) aren't supported ([#21](https://github.com/dmccuskey/dmc-websockets/issues/21)).

Fixes are listed under [Possible Future Changes](development.md#possible-future-changes).
