--====================================================================--
-- tests/autobahn/corovel_cfg.lua
--
-- Corovel config for the headless Autobahn run
--====================================================================--

local Config = {}

-- corovel uses 'tps' both as the frame-timer delay (ms) and as the
-- loop sleep (seconds), so keep it tiny to get a fast event loop
Config.corovel = {
	tps=0.001
}

Config.system = {}

return Config
