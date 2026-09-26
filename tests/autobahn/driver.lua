--====================================================================--
-- tests/autobahn/driver.lua
--
-- Headless Autobahn fuzzingserver client for dmc-websockets.
-- Runs inside Corovel (Corona event loop for plain Lua).
--
-- Environment:
--   AUTOBAHN_URL   default ws://127.0.0.1:9001
--   AUTOBAHN_AGENT default dmc_websockets
--   CASE_TIMEOUT   seconds before a hung case is abandoned, default 60
--   MAX_CASES      only run the first N cases (for smoke tests)
--====================================================================--


require 'dmc_corona_boot'
require 'dmc_corona.lib.dmc_lua.lua_bytearray'

local WebSockets = require 'dmc_corona.dmc_websockets'


--====================================================================--
--== Setup, Constants


local SERVER = os.getenv( 'AUTOBAHN_URL' ) or 'ws://127.0.0.1:9001'
local AGENT = os.getenv( 'AUTOBAHN_AGENT' ) or 'dmc_websockets'
local CASE_TIMEOUT = tonumber( os.getenv( 'CASE_TIMEOUT' ) or 60 ) * 1000
local MAX_CASES = tonumber( os.getenv( 'MAX_CASES' ) or '' )

local ws
local case_count = 0
local case_idx = 0
local case_timer

local runCase, nextCase, updateReports


--====================================================================--
--== Support Functions


local function log( ... )
	io.stdout:write( table.concat( { ... }, ' ' ), '\n' )
	io.stdout:flush()
end

local function cancelCaseTimer()
	if case_timer then
		timer.cancel( case_timer )
		case_timer = nil
	end
end

-- open a new connection, replacing any previous one
local function openSocket( path, handler )
	if ws then
		ws:removeEventListener( ws.EVENT, ws._driver_handler )
		ws:removeSelf()
	end
	ws = WebSockets{ uri=SERVER..path }
	ws._driver_handler = handler
	ws:addEventListener( ws.EVENT, handler )
end


--====================================================================--
--== Main Functions


local function getCaseCount()
	openSocket( '/getCaseCount', function( event )
		if event.type == ws.ONMESSAGE then
			case_count = tonumber( event.message.data )
			if MAX_CASES then case_count = math.min( case_count, MAX_CASES ) end
			log( 'Autobahn case count:', case_count )

		elseif event.type == ws.ONCLOSE or event.type == ws.ONERROR then
			if case_count == 0 then
				log( 'ERROR: could not get case count from', SERVER, tostring( event.reason ) )
				os.exit( 1 )
			end
			nextCase()
		end
	end )
end

runCase = function( idx )
	local path = string.format( '/runCase?case=%d&agent=%s', idx, AGENT )
	local case_start = system.getTimer()

	openSocket( path, function( event )
		if event.type == ws.ONMESSAGE then
			local msg = event.message
			ws:send( msg.data, { type=msg.type } )

		elseif event.type == ws.ONCLOSE or event.type == ws.ONERROR then
			cancelCaseTimer()
			log( string.format( 'case %3d/%d  %-7s code=%-5s %6dms', idx, case_count,
				event.type, tostring( event.code ), system.getTimer()-case_start ) )
			nextCase()
		end
	end )

	case_timer = timer.performWithDelay( CASE_TIMEOUT, function()
		case_timer = nil
		log( string.format( 'case %3d/%d  TIMEOUT after %ds', idx, case_count, CASE_TIMEOUT/1000 ) )
		nextCase()
	end )
end

nextCase = function()
	-- defer so we're not tearing down the socket inside its own event
	timer.performWithDelay( 1, function()
		case_idx = case_idx + 1
		if case_idx <= case_count then
			runCase( case_idx )
		else
			updateReports()
		end
	end )
end

updateReports = function()
	log( 'Updating Autobahn reports' )
	openSocket( '/updateReports?agent='..AGENT, function( event )
		if event.type == ws.ONCLOSE or event.type == ws.ONERROR then
			log( 'Done' )
			os.exit( 0 )
		end
	end )
end


getCaseCount()

-- keep Corovel's event loop running; we exit via os.exit()
return true
