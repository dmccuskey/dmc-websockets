# Installation

The [Quick Start](../README.md#quick-start) is the short path: copy three items into your project and add one plugin. This page covers the options around it.

## What to Copy

From this repository, copy into your Solar2D project:

| Item | What it is |
|---|---|
| `dmc_corona/` | dmc-websockets and the libraries it uses: dmc-sockets and the DMC Lua library (classes, events, ByteArray) |
| `dmc_corona_boot.lua` | Loader that reads `dmc_corona.cfg` and lets the libraries find each other |
| `dmc_corona.cfg` | Configuration for the DMC libraries |

`dmc_corona_boot.lua` and `dmc_corona.cfg` must be at the top of the project, next to `main.lua`. The `dmc_corona/` folder is self-contained: if your project already has one from another DMC library, merge the two (files with the same name are the same library; keep the newer copy).

## Project Layout

By default `dmc_corona/` sits next to `main.lua` and you load the library with:

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

`wss://` (TLS) connections need Solar2D's OpenSSL plugin. Add it to `build.settings`:

```lua
settings = {
	plugins = {
		["plugin.openssl"] = { publisherId = "com.coronalabs" },
	},
}
```

Plain `ws://` connections need no plugins.

## Android

Android apps need permission to use the network. Add it to `build.settings`:

```lua
settings = {
	android = {
		usesPermissions = { "android.permission.INTERNET" },
	},
}
```

## Updating

Copy `dmc_corona/` and `dmc_corona_boot.lua` again from the newer version, replacing the old ones. Keep your own `dmc_corona.cfg` if you have changed it. The [changelog](../CHANGELOG.md) says what changed between versions.

## Outside Solar2D

The library also runs in plain Lua 5.1 with [lua-corovel](https://github.com/dmccuskey/lua-corovel), which provides the Solar2D objects it uses (`Runtime`, `timer`, `system`). That is how the tests run; see [Development](development.md#tests). It needs `luasocket`, plus `luasec` for `wss://`.
