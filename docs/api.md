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
| [`ws:connect()`](#connect) | method | Connect, when created with `auto_connect=false` |
| [`ws.readyState`](#readystate) | property | Connection status |
| [`ws.throttle`](#throttle) | property | How often sockets are checked for data |
| [`ws:removeSelf()`](#removeself) | method | Destroy the object |

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
| `protocols` | none | Subprotocols to request, a string or a list. The server may choose one of them; if it chooses one that wasn't requested, the connection fails |
| `port` | from `uri` | Port, overriding the one in `uri` (default 80 for `ws://`, 443 for `wss://`) |
| `auto_connect` | `true` | Connect as soon as the object is created. With `false`, call [`connect()`](#connect) |
| `ssl_params` | see [TLS Settings](#tls-settings) | TLS settings for `wss://` |
| `throttle` | `MEDIUM` | See [`throttle`](#throttle) |

Not implemented: `auto_reconnect` is accepted but has no effect, and `query` is ignored (put the query string in `uri`). There is no `Origin` header and no extension support (such as compression).

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
| `ws.ONCLOSE` | The connection closed normally, or could not be opened | `event.code`, `event.reason` |
| `ws.ONERROR` | The connection failed after it was opened | `event.code`, `event.reason`, `event.isError` (`true`) |

After `ONCLOSE` or `ONERROR` the object is closed; create a new one to reconnect.

If the server can't be reached, or the TLS handshake fails, you get `ONCLOSE` with no `code`.

### Close and Error Codes

`event.code` is either a [WebSocket close code](https://www.rfc-editor.org/rfc/rfc6455#section-7.4.1) sent by the server or by this library, or one of the library's own codes:

| Code | Meaning |
|---|---|
| 1000 | Normal close |
| 1001 | Going away (server shutting down, or the page/app leaving) |
| 1002 | Protocol error: the server sent something RFC 6455 doesn't allow |
| 1007 | Invalid data: a text message or close reason that isn't valid UTF-8 |
| 1012-1014 | Service restart, try again later, bad gateway |
| 3000 | Network error while sending |
| 3001 | The handshake request could not be sent |
| 3002 | The server's handshake response was invalid |
| 9999 | Internal error in the library (please [report it](https://github.com/dmccuskey/dmc-websockets/issues)) |

## Methods

### send()

```lua
ws:send( 'hello' )                          -- text
ws:send( png_bytes, { type=ws.BINARY } )    -- binary
```

`data` must be a string. Text messages should be valid UTF-8. Messages are queued until they can be written, so `send()` doesn't block, and large messages are sent in pieces over several frames of the app.

### close()

```lua
ws:close()
```

Starts the closing handshake with code 1000. `ONCLOSE` follows once the server answers, or after a timeout.

### connect()

Opens the connection. Only needed when the object was created with `auto_connect=false`.

### removeSelf()

Destroys the object and its listeners. Close the connection first.

## Properties

### readyState

The connection status, one of:

| Constant | Value | Meaning |
|---|---|---|
| `ws.NOT_ESTABLISHED` | 0 | Connecting |
| `ws.ESTABLISHED` | 1 | Open |
| `ws.CLOSING_HANDSHAKE` | 2 | Closing |
| `ws.CLOSED` | 3 | Closed |

### throttle

How often the library checks sockets for incoming data. The setting is shared by all connections, and each new connection resets it to its own `throttle` option (`MEDIUM` if not given).

| Constant | Check interval |
|---|---|
| `ws.OFF` | every frame |
| `ws.LOW` | about 30 times a second |
| `ws.MEDIUM` | about 15 times a second (default) |
| `ws.HIGH` | once a second |

## Constants

| Constant | Value |
|---|---|
| `ws.EVENT` | Event name to listen for |
| `ws.ONOPEN`, `ws.ONMESSAGE`, `ws.ONCLOSE`, `ws.ONERROR` | Event types |
| `ws.TEXT`, `ws.BINARY` | Message types |
| `WebSockets.VERSION` | Library version, e.g. `'1.4.0'` |
| `WebSockets.USER_AGENT` | `'dmc_websockets/1.4.0'`; defined for apps to use, not sent in the handshake |
