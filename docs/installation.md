# Installation

The [Quick Start](../README.md#quick-start) is the short path: copy three items into your project and add two plugins. This page covers the options around it.

## What to Copy

From this repository, copy into your Solar2D project:

| Item | What it is |
|---|---|
| `dmc_corona/` | dmc-websockets and the libraries it uses: dmc-sockets and the DMC Lua library (classes, events, ByteArray) |
| `dmc_corona_boot.lua` | Loader that reads `dmc_corona.cfg` and lets the libraries find each other |
| `dmc_corona.cfg` | Configuration for the DMC libraries |

`dmc_corona_boot.lua` and `dmc_corona.cfg` must be at the root level of the project folder. The `dmc_corona/` folder is self-contained: if your project already has one from another DMC library, merge the two (files with the same name are the same library; keep the newer copy).

## Project Layout

By default `dmc_corona/` is at the root level of the project folder too, and you load the library with:

```lua
local WebSockets = require 'dmc_corona.dmc_websockets'
```

To keep third-party code in a subfolder, for example `lib/`:

```text
main.lua
dmc_corona_boot.lua
dmc_corona.cfg
lib/
└── dmc_corona/
```

tell the loader where the folder is, in `dmc_corona.cfg`:

```ini
[DMC_CORONA]
LUA_PATH:JSON = [ "./lib/dmc_corona" ]
```

and require it with the full path:

```lua
local WebSockets = require 'lib.dmc_corona.dmc_websockets'
```

## Plugins

Add two Solar2D plugins to `build.settings`:

```lua
settings = {
	plugins = {
		["plugin.bit"] = { publisherId = "com.coronalabs" },
		["plugin.openssl"] = { publisherId = "com.coronalabs" },
	},
}
```

- `plugin.bit` provides fast bit operations for framing. Without it the library falls back to a slower pure-Lua version, and the Simulator warns `plugin.bit is not configured in build.settings`.
- `plugin.openssl` is needed for `wss://` (TLS) connections. Plain `ws://` works without it.

## Android

Android apps need permission to use the network. Add it to `build.settings`:

```lua
settings = {
	android = {
		usesPermissions = { "android.permission.INTERNET" },
	},
}
```

## HTML5

HTML5 builds need nothing extra: neither plugin is used there, and `dmc_corona/dmc_websockets/html5_js.js` is the browser side. Keep `dmc_corona/` at the root level of the project folder for HTML5 builds. Solar2D finds a JavaScript module by its full `require` name, and the bridge is loaded as `dmc_corona.dmc_websockets.html5_js`, so it can't follow a `LUA_PATH` to a subfolder. Other builds include the `.js` file but never load it; leave it out of them with `excludeFiles` if you like. What works differently in a browser is described in [HTML5 Builds](api.md#html5-builds).

## Updating

Copy `dmc_corona/` and `dmc_corona_boot.lua` again from the newer version, replacing the old ones. Keep your own `dmc_corona.cfg` if you have changed it. The [changelog](../CHANGELOG.md) says what changed between versions.

## Outside Solar2D

The library also runs in plain Lua 5.1 with [lua-corovel](https://github.com/dmccuskey/lua-corovel), which provides the Solar2D objects it uses (`Runtime`, `timer`, `system`). That is how the tests run; see [Development](development.md#tests). It needs `luasocket`, plus `luasec` for `wss://`.
