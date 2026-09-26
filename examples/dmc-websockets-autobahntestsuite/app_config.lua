local Config = {}

Config.app = {
	version = '2.0.0',
	build = '00',
}

Config.autobahn = {
	-- where the fuzzing server runs; 127.0.0.1 when it runs in Docker on the
	-- same computer as the Simulator, else that computer's LAN address
	host = '127.0.0.1',
	port = 9001,

	-- name the results are filed under in the reports
	agent = 'dmc_websockets_solar2d',

	-- run only these cases, eg { '1.1.1', '6.4.3', '9.1.3' }; nil runs all
	cases = nil,

	-- seconds before a case that hangs is abandoned
	case_timeout = 60,
}

return Config
