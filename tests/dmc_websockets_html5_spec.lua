--====================================================================--
-- tests/dmc_websockets_html5_spec.lua
--
-- Testing the WebSocket class in an HTML5 build using Luna Test,
-- against a stand-in for the JavaScript bridge (html5_js.js) and
-- Solar2D's timer, Runtime and system
--====================================================================--


module(..., package.seeall)




--====================================================================--
--== Test: DMC WebSockets, HTML5 transport
--====================================================================--


-- Semantic Versioning Specification: http://semver.org/

local VERSION = "0.1.0"



--====================================================================--
--== Stand-ins
--====================================================================--


--== Timers and frames: run by hand

local timers = {}
local frame_listeners = {}

local function pendingTimers()
	local n = 0
	for _, t in ipairs( timers ) do
		if not t.cancelled then n = n + 1 end
	end
	return n
end

-- one enterFrame
--
local function frame()
	local list = {}
	for i, f in ipairs( frame_listeners ) do list[i] = f end
	for _, f in ipairs( list ) do f{ name='enterFrame' } end
end


--== Bridge: what html5_js.js does, with a browser socket the test drives

local Bridge

local function newBridge()
	local b = { conns={}, count=0 }

	function b.open( p )
		if b.open_error then
			return { ok=false, error={ kind='constructor', name='SyntaxError', message=b.open_error } }
		end
		b.count = b.count + 1
		local conn = { id='ws:' .. b.count, url=p.url, protocols=p.protocols, events={}, sent={}, readyState=0 }
		b.conns[ conn.id ] = conn
		b.last = conn
		return { ok=true, id=conn.id }
	end
	function b.send( p )
		local conn = b.conns[ p.id ]
		if conn.readyState ~= 1 then return { ok=false, error={ kind='not_open' } } end
		table.insert( conn.sent, { type=p.type, data=p.data } )
		return { ok=true }
	end
	function b.close( p )
		local conn = b.conns[ p.id ]
		conn.close_call = { code=p.code, reason=p.reason }
		conn.readyState = 2
		return { ok=true }
	end
	function b.poll( p )
		local conn = b.conns[ p.id ]
		local events = conn.events
		conn.events = {}
		return { ok=true, events=events }
	end
	function b.dispose( p )
		local conn = b.conns[ p.id ]
		if conn then conn.disposed = true end
		b.conns[ p.id ] = nil
		return { ok=true }
	end

	return b
end

-- the browser socket's side

local function serverOpen( conn )
	conn.readyState = 1
	table.insert( conn.events, { kind='open' } )
end
local function serverMessage( conn, data, mtype )
	table.insert( conn.events, { kind='message', type=mtype or 'text', data=data } )
end
local function serverClose( conn, code, reason )
	conn.readyState = 3
	table.insert( conn.events, { kind='close', code=code, reason=reason or '', wasClean=code ~= 1006 } )
end
local function serverFail( conn )
	conn.readyState = 3
	table.insert( conn.events, { kind='error' } )
	table.insert( conn.events, { kind='close', code=1006, reason='', wasClean=false } )
end


local WebSocket

local MODULES = {
	'dmc_corona.dmc_websockets',
	'dmc_corona.dmc_websockets.html5',
	'dmc_corona.dmc_websockets.html5_js'
}

local saved = {}



--====================================================================--
--== Helpers
--====================================================================--


-- load the library as in an HTML5 build, with a new bridge
--
local function loadLibrary( bridge )
	for _, name in ipairs( MODULES ) do package.loaded[ name ] = nil end
	Bridge = bridge
	package.loaded[ 'dmc_corona.dmc_websockets.html5_js' ] = bridge
	WebSocket = require 'dmc_websockets'
end

local function newSocket( params )
	params = params or {}
	params.uri = params.uri or 'ws://example.com/chat'
	local ws = WebSocket( params )
	local events = {}
	ws:addEventListener( ws.EVENT, function( event )
		table.insert( events, event )
	end )
	return ws, Bridge and Bridge.last, events
end

local function openSocket( params )
	local ws, conn, events = newSocket( params )
	serverOpen( conn )
	frame()
	return ws, conn, events
end

local function eventsOf( events, etype )
	local list = {}
	for _, e in ipairs( events ) do
		if e.type == etype then table.insert( list, e ) end
	end
	return list
end

-- run f without its print output
--
local function quietly( f, ... )
	local print_ = _G.print
	_G.print = function() end
	local result = { pcall( f, ... ) }
	_G.print = print_
	assert_true( result[1], result[2] )
	return unpack( result, 2 )
end

-- bytes as the bridge carries them: each byte as a character U+0000-U+00FF
--
local function latin1( bytes )
	return ( bytes:gsub( '[\128-\255]', function( c )
		local b = c:byte()
		return string.char( 0xC0 + math.floor( b / 0x40 ), 0x80 + b % 0x40 )
	end ) )
end



--====================================================================--
--== Testing Setup
--====================================================================--


function suite_setup()
	saved.getInfo = system.getInfo
	saved.getTimer = system.getTimer
	saved.timer = _G.timer
	saved.Runtime = _G.Runtime
	for _, name in ipairs( MODULES ) do saved[ name ] = package.loaded[ name ] end

	system.getInfo = function( key )
		if key == 'platform' then return 'html5' end
	end
	system.getTimer = function() return 0 end
	_G.timer = {
		performWithDelay=function( ms, f )
			local t = { ms=ms, f=f }
			table.insert( timers, t )
			return t
		end,
		cancel=function( t ) t.cancelled = true end
	}
	_G.Runtime = {
		addEventListener=function( self, name, f )
			if name == 'enterFrame' then table.insert( frame_listeners, f ) end
		end,
		removeEventListener=function( self, name, f )
			for i = #frame_listeners, 1, -1 do
				if frame_listeners[i] == f then table.remove( frame_listeners, i ) end
			end
		end
	}

	require 'dmc_corona_boot'
end

function suite_teardown()
	system.getInfo = saved.getInfo
	system.getTimer = saved.getTimer
	_G.timer = saved.timer
	_G.Runtime = saved.Runtime
	for _, name in ipairs( MODULES ) do package.loaded[ name ] = saved[ name ] end
end

function setup()
	timers = {}
	frame_listeners = {}
	loadLibrary( newBridge() )
end



--====================================================================--
--== Tests
--====================================================================--


function test_openAndMessages()
	local ws, conn, events = newSocket()
	assert_equal( 'ws://example.com:80/chat', conn.url )
	assert_equal( ws.NOT_ESTABLISHED, ws.readyState )

	serverOpen( conn )
	serverMessage( conn, 'one' )
	serverMessage( conn, 'two' )
	serverClose( conn, 1000, 'bye' )
	assert_equal( 0, #events, "events wait for enterFrame" )
	frame()
	assert_equal( 4, #events )
	assert_equal( ws.ONOPEN, events[1].type )
	assert_equal( 'one', events[2].message.data )
	assert_equal( ws.TEXT, events[2].message.type )
	assert_equal( 'two', events[3].message.data )
	assert_equal( ws.ONCLOSE, events[4].type )
end

function test_binary()
	local ws, conn, events = openSocket()
	local bytes = {}
	for i = 0, 255 do bytes[ #bytes+1 ] = string.char( i ) end
	bytes = table.concat( bytes )

	ws:send( bytes, { type=ws.BINARY } )
	assert_equal( 'binary', conn.sent[1].type )
	assert_equal( latin1( bytes ), conn.sent[1].data )

	serverMessage( conn, latin1( bytes ), 'binary' )
	serverMessage( conn, 'a\196\128b', 'binary' ) -- U+0100: not a byte
	frame()
	local msgs = eventsOf( events, ws.ONMESSAGE )
	assert_equal( 1, #msgs )
	assert_equal( ws.BINARY, msgs[1].message.type )
	assert_true( msgs[1].message.data == bytes, "bytes intact" )
	assert_equal( 1, #eventsOf( events, ws.ONERROR ) )
	assert_true( conn.disposed )
end

function test_sendsBeforeOpenWait()
	local ws, conn = newSocket()
	ws:send( 'first' )
	ws:send( 'second' )
	frame()
	assert_equal( 0, #conn.sent )

	serverOpen( conn )
	frame()
	assert_equal( 2, #conn.sent )
	assert_equal( 'first', conn.sent[1].data )
	assert_equal( 'second', conn.sent[2].data )
	assert_equal( 'text', conn.sent[1].type )
end

function test_queuedSendsDroppedWhenConnectFails()
	local ws, conn = newSocket()
	ws:send( 'never sent' )
	serverFail( conn )
	frame()
	frame()
	assert_equal( 0, #conn.sent )
	assert_equal( 0, #frame_listeners, "no listener left behind" )
end


--== Closing

function test_closeFromServer()
	local ws, conn, events = openSocket()
	serverClose( conn, 4001, 'game over' )
	frame()
	local closes = eventsOf( events, ws.ONCLOSE )
	assert_equal( 1, #closes )
	assert_equal( 4001, closes[1].code )
	assert_equal( 'game over', closes[1].reason )
	assert_equal( 0, #eventsOf( events, ws.ONERROR ) )
	assert_equal( ws.CLOSED, ws.readyState )
	assert_true( conn.disposed )
	assert_equal( 0, pendingTimers() )
end

function test_close()
	local ws, conn, events = openSocket()
	ws:close()
	assert_equal( ws.CLOSING_HANDSHAKE, ws.readyState )
	assert_equal( 1000, conn.close_call.code )
	assert_equal( 'Purpose for connection has been fulfilled', conn.close_call.reason )
	assert_equal( 1, pendingTimers(), "waits for the server's close" )

	serverClose( conn, 1000, 'ok' )
	frame()
	local closes = eventsOf( events, ws.ONCLOSE )
	assert_equal( 1, #closes )
	assert_equal( 1000, closes[1].code )
	assert_equal( 0, pendingTimers() )
	assert_true( conn.disposed )

	-- scripts may only send 1000 and 3000-4999: for others the browser picks
	ws, conn = openSocket()
	ws:_close{ code=1001, reason='Going Away' }
	assert_not_nil( conn.close_call )
	assert_nil( conn.close_call.code )
end

function test_closeWhileConnecting()
	local ws, conn, events = newSocket()
	ws:close()
	assert_equal( 1, #eventsOf( events, ws.ONCLOSE ) )
	assert_true( conn.disposed )

	-- the browser connects anyway: nothing more
	serverOpen( conn )
	frame()
	assert_equal( 1, #events )
	assert_equal( ws.STATE_CLOSED, ws:getState() )
end


--== Failures: browsers don't say why, so each is one ONERROR 3000

function test_failures()
	local cases = {
		{ name='connect fails', run=function( conn ) serverFail( conn ) end,
			emsg='Browser WebSocket failed' },
		{ name='dropped', open=true, run=function( conn ) serverFail( conn ) end },
		{ name='closed before open', run=function( conn ) serverClose( conn, 1002 ) end },
		{ name='URL refused', before=function() Bridge.open_error = 'The URL is invalid' end,
			emsg='SyntaxError: The URL is invalid' },
		{ name='no bridge', before=function() loadLibrary( nil ) end, emsg='html5_js.js' },
	}
	for _, c in ipairs( cases ) do
		setup()
		if c.before then c.before() end
		local ws, conn, events = quietly( c.open and openSocket or newSocket )
		if c.run then c.run( conn ) end
		frame()
		local errs = eventsOf( events, ws.ONERROR )
		assert_equal( 1, #errs, c.name )
		assert_equal( 3000, errs[1].code, c.name )
		if c.emsg then assert_match( c.emsg, errs[1].emsg, c.name ) end
		assert_equal( 0, #eventsOf( events, ws.ONCLOSE ), c.name )
		if conn then assert_true( conn.disposed, c.name ) end
	end
end

function test_errorInListenerFailsConnection()
	local ws, conn, events = openSocket()
	ws:addEventListener( ws.EVENT, function( event )
		if event.type == ws.ONMESSAGE then error( 'app bug' ) end
	end )
	serverMessage( conn, 'hello' )
	quietly( frame )
	local errs = eventsOf( events, ws.ONERROR )
	assert_equal( 1, #errs )
	assert_equal( 9999, errs[1].code )
	assert_true( conn.disposed )
end

function test_lateEventsOfReplacedConnection()
	local ws1, conn1 = openSocket()
	ws1:close()
	local ws2, conn2, events2 = openSocket()
	assert_not_equal( conn1.id, conn2.id )

	-- the first browser socket's close arrives late
	serverClose( conn1, 1000, '' )
	serverMessage( conn2, 'still here' )
	frame()
	assert_equal( 1, #eventsOf( events2, ws2.ONMESSAGE ) )
	assert_equal( 0, #eventsOf( events2, ws2.ONCLOSE ) )
	assert_equal( ws2.ESTABLISHED, ws2.readyState )
end


--== Options

function test_urlAndProtocols()
	local ws, conn = newSocket{ uri='wss://example.com/chat?x=y', query={ b='two words', a=1 } }
	assert_equal( 'wss://example.com:443/chat?x=y&a=1&b=two%20words', conn.url )

	ws, conn = newSocket{ uri='ws://example.com', port=8080, protocols='chat' }
	assert_equal( 'ws://example.com:8080/', conn.url )
	assert_equal( 'chat', conn.protocols[1] )

	ws, conn = newSocket{ uri='ws://[::1]:9000/a#frag', protocols={ 'v2', 'v1' } }
	assert_equal( 'ws://[::1]:9000/a', conn.url )
	assert_equal( 'v1', conn.protocols[2] )
end

function test_whatBrowsersDontAllow()
	assert_error( function() newSocket{ keepalive=1000 } end )
	assert_error( function() newSocket{ origin='https://example.com' } end )
	assert_error( function() newSocket{ ssl_params={} } end )
	newSocket{ keepalive=0 }

	local ws = openSocket()
	assert_error( function() ws:ping( 'hi' ) end )
end
