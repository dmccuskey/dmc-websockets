--====================================================================--
-- tests/dmc_websockets_class_spec.lua
--
-- Testing the WebSocket class using Luna Test, against a stand-in
-- for dmc_sockets and Solar2D's timer, Runtime and system.getTimer
--====================================================================--


module(..., package.seeall)




--====================================================================--
--== Test: DMC WebSockets, WebSocket class
--====================================================================--


-- Semantic Versioning Specification: http://semver.org/

local VERSION = "0.1.0"



--====================================================================--
--== Stand-ins
--====================================================================--


--== Clock and timers: run by hand with fireTimers()

local clock = 0
local timers = {}

local function fireTimers()
	local due = timers
	timers = {}
	for _, t in ipairs( due ) do
		if not t.cancelled then t.f() end
	end
end

local function pendingTimers()
	local n = 0
	for _, t in ipairs( timers ) do
		if not t.cancelled then n = n + 1 end
	end
	return n
end


--== Sockets: records what's sent, feeds what the test gives it

local FakeSockets = {
	ATCP='atcp', OFF=0, LOW=1, MEDIUM=2, HIGH=3,
	throttle=nil,
	last=nil
}

function FakeSockets:create( stype, params )
	local sock = {
		CONNECT='connect_event', READ='read_event',
		CONNECTED='socket_connected', NOT_CONNECTED='socket_not_connected',
		sent={}, pending={}, closed=false
	}
	function sock:connect( host, port, handlers )
		self.host, self.port, self.handlers = host, port, handlers
	end
	function sock:send( data, callback )
		table.insert( self.sent, data )
	end
	function sock:receive( pattern, callback )
		local data = table.concat( self.pending )
		self.pending = {}
		callback{ data=data }
	end
	function sock:close()
		self.closed = true
	end
	FakeSockets.last = sock
	return sock
end


local WebSocket, ws_handshake, bit



--====================================================================--
--== Helpers
--====================================================================--


-- a frame as a server sends it: unmasked
--
local function serverFrame( opcode, data, fin )
	local b1 = opcode + ( fin == false and 0 or 0x80 )
	local len = #data
	local header
	if len <= 125 then
		header = string.char( b1, len )
	elseif len <= 0xffff then
		header = string.char( b1, 126, math.floor( len / 256 ), len % 256 )
	else
		local b = {}
		local n = len
		for i = 8, 1, -1 do
			b[i] = n % 256
			n = math.floor( n / 256 )
		end
		header = string.char( b1, 127, unpack( b ) )
	end
	return header .. data
end

-- a frame as the client sent it (masked, payload up to 125 bytes)
--
local function decodeClientFrame( str )
	local b1, b2 = str:byte( 1, 2 )
	local len = bit.band( b2, 0x7f )
	local mask = { str:byte( 3, 6 ) }
	local out = {}
	for i = 1, len do
		out[i] = string.char( bit.bxor( str:byte( 6 + i ), mask[ ( i - 1 ) % 4 + 1 ] ) )
	end
	return { opcode=bit.band( b1, 0x0f ), data=table.concat( out ) }
end

local function feed( sock, data )
	table.insert( sock.pending, data )
	sock.handlers.onData{ type=sock.READ }
end

local function newSocket( params )
	params = params or {}
	params.uri = params.uri or 'ws://example.com/chat'
	local ws = WebSocket( params )
	local events = {}
	ws:addEventListener( ws.EVENT, function( event )
		table.insert( events, event )
	end )
	return ws, FakeSockets.last, events
end

-- complete the TCP connection and the handshake
--
local function open( sock, split )
	sock.handlers.onConnect{ type=sock.CONNECT, status=sock.CONNECTED }
	local key = sock.sent[1]:match( 'Sec%-WebSocket%-Key: ([^\r]+)' )
	local response = 'HTTP/1.1 101 Switching Protocols\r\n'
		.. 'Upgrade: websocket\r\nConnection: Upgrade\r\n'
		.. 'Sec-WebSocket-Accept: ' .. ws_handshake._buildServerKey( key ) .. '\r\n\r\n'
	if split then
		feed( sock, response:sub( 1, 40 ) )
		feed( sock, response:sub( 41 ) )
	else
		feed( sock, response )
	end
end

-- the handshake request, sent once the TCP connection is made
--
local function request( sock )
	sock.handlers.onConnect{ type=sock.CONNECT, status=sock.CONNECTED }
	return sock.sent[1]
end

local function eventsOf( events, etype )
	local list = {}
	for _, e in ipairs( events ) do
		if e.type == etype then table.insert( list, e ) end
	end
	return list
end



--====================================================================--
--== Testing Setup
--====================================================================--


function suite_setup()
	system.getTimer = function() return clock end
	_G.timer = {
		performWithDelay=function( ms, f )
			local t = { ms=ms, f=f }
			table.insert( timers, t )
			return t
		end,
		cancel=function( t ) t.cancelled = true end
	}
	_G.Runtime = {
		addEventListener=function() end,
		removeEventListener=function() end
	}
	package.loaded[ 'dmc_sockets' ] = FakeSockets

	require 'dmc_corona_boot'
	WebSocket = require 'dmc_websockets'
	ws_handshake = require 'dmc_websockets.handshake'
	bit = require 'lib.dmc_lua.bit'
end

function setup()
	clock = 0
	timers = {}
	FakeSockets.throttle = nil
end



--====================================================================--
--== Tests
--====================================================================--


function test_openAndMessage()
	local ws, sock, events = newSocket()
	open( sock )
	assert_equal( 1, #eventsOf( events, ws.ONOPEN ) )
	feed( sock, serverFrame( 0x1, 'hello' ) )
	local msgs = eventsOf( events, ws.ONMESSAGE )
	assert_equal( 1, #msgs )
	assert_equal( 'hello', msgs[1].message.data )
end

function test_handshakeInTwoReads()
	local ws, sock, events = newSocket()
	open( sock, true )
	assert_equal( 1, #eventsOf( events, ws.ONOPEN ), "should open" )
end

function test_frameAfterHandshakeInSameRead()
	local ws, sock, events = newSocket()
	sock.handlers.onConnect{ type=sock.CONNECT, status=sock.CONNECTED }
	local key = sock.sent[1]:match( 'Sec%-WebSocket%-Key: ([^\r]+)' )
	feed( sock, 'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\n'
		.. 'Connection: Upgrade\r\nSec-WebSocket-Accept: '
		.. ws_handshake._buildServerKey( key ) .. '\r\n\r\n'
		.. serverFrame( 0x1, 'first' ) )
	local msgs = eventsOf( events, ws.ONMESSAGE )
	assert_equal( 1, #msgs )
	assert_equal( 'first', msgs[1].message.data )
end


--== Receive buffer

function test_largeFrameInManyReads()
	local ws, sock, events = newSocket()
	open( sock )
	local payload = string.rep( 'abcdefgh', 40000 ) -- 320000 bytes
	local frame = serverFrame( 0x2, payload )
	for i = 1, #frame, 1000 do
		feed( sock, frame:sub( i, i + 999 ) )
	end
	local msgs = eventsOf( events, ws.ONMESSAGE )
	assert_equal( 1, #msgs )
	assert_equal( #payload, #msgs[1].message.data )
	assert_true( msgs[1].message.data == payload, "payload intact" )
end

function test_framesSplitAcrossReads()
	local ws, sock, events = newSocket()
	open( sock )
	local data = serverFrame( 0x1, 'one' ) .. serverFrame( 0x1, string.rep( 'x', 300 ) )
		.. serverFrame( 0x1, 'three' )
	-- byte by byte: headers split too
	for i = 1, #data do feed( sock, data:sub( i, i ) ) end
	local msgs = eventsOf( events, ws.ONMESSAGE )
	assert_equal( 3, #msgs )
	assert_equal( 'one', msgs[1].message.data )
	assert_equal( 300, #msgs[2].message.data )
	assert_equal( 'three', msgs[3].message.data )
end

function test_maskedFrameFailsWithoutWaitingForPayload()
	local ws, sock, events = newSocket()
	open( sock )
	-- masked, 1000-byte payload announced, only the header sent
	feed( sock, string.char( 0x81, 0x80 + 126, 0x03, 0xe8, 1, 2, 3, 4 ) )
	assert_equal( ws.STATE_CLOSING, ws:getState(), "protocol error closes" )
end


--== Pong

function test_pongEvent()
	local ws, sock, events = newSocket()
	open( sock )
	feed( sock, serverFrame( 0xA, 'abc' ) )
	local pongs = eventsOf( events, ws.ONPONG )
	assert_equal( 1, #pongs )
	assert_equal( 'abc', pongs[1].data )
	assert_nil( pongs[1].latency )
end

function test_pongInsideFragmentedMessage()
	local ws, sock, events = newSocket()
	open( sock )
	feed( sock, serverFrame( 0x1, 'hel', false ) )
	feed( sock, serverFrame( 0xA, 'p' ) )
	feed( sock, serverFrame( 0x0, 'lo' ) )
	assert_equal( 1, #eventsOf( events, ws.ONPONG ) )
	local msgs = eventsOf( events, ws.ONMESSAGE )
	assert_equal( 1, #msgs )
	assert_equal( 'hello', msgs[1].message.data )
end

function test_ping()
	local ws, sock, events = newSocket()
	open( sock )
	local n = #sock.sent
	ws:ping( 'hi' )
	local frame = decodeClientFrame( sock.sent[ n + 1 ] )
	assert_equal( 0x9, frame.opcode )
	assert_equal( 'hi', frame.data )
	assert_error( function() ws:ping( string.rep( 'x', 126 ) ) end )
end

function test_textMustBeUtf8()
	local ws, sock = newSocket()
	open( sock )
	assert_error( function() ws:send( string.char( 255 ) ) end )
	ws:send( 'héllo' )
	ws:send( string.char( 255 ), { type=ws.BINARY } )
end


--== Failed connections

function test_connectTimeoutIsError()
	local ws, sock, events = newSocket()
	sock.handlers.onConnect{ type=sock.CONNECT, status=sock.NOT_CONNECTED, emsg='timeout' }
	local errs = eventsOf( events, ws.ONERROR )
	assert_equal( 1, #errs )
	assert_equal( 3000, errs[1].code )
	assert_equal( 'timeout', errs[1].emsg )
	assert_equal( 0, #eventsOf( events, ws.ONCLOSE ) )
end

function test_tlsFailureIsError()
	local ws, sock, events = newSocket{ uri='wss://example.com/' }
	sock.handlers.onConnect{ type=sock.CONNECT, isError=true,
		status=sock.NOT_CONNECTED, emsg='certificate verify failed' }
	local errs = eventsOf( events, ws.ONERROR )
	assert_equal( 1, #errs )
	assert_equal( 'certificate verify failed', errs[1].emsg )
end


--== Options

function test_throttleOnlyWhenGiven()
	FakeSockets.throttle = 'unchanged'
	newSocket()
	assert_equal( 'unchanged', FakeSockets.throttle )
	newSocket{ throttle=WebSocket.HIGH }
	assert_equal( WebSocket.HIGH, FakeSockets.throttle )
end

function test_queryOption()
	local ws, sock = newSocket{ uri='ws://example.com/chat', query='a=1' }
	assert_match( '^GET /chat%?a=1 HTTP', request( sock ) )

	ws, sock = newSocket{ uri='ws://example.com/chat?x=y', query={ b='two words', a=1 } }
	assert_match( '^GET /chat%?x=y&a=1&b=two%%20words HTTP', request( sock ) )

	ws, sock = newSocket{ uri='ws://example.com/chat?x=y' }
	assert_match( '^GET /chat%?x=y HTTP', request( sock ) )
end

function test_originAndUserAgent()
	local ws, sock = newSocket()
	local req = request( sock )
	assert_match( '\r\nUser%-Agent: dmc_websockets/', req )
	assert_not_match( 'Origin:', req )

	ws, sock = newSocket{ origin='https://example.com' }
	assert_match( '\r\nOrigin: https://example.com\r\n', request( sock ) )
end


--== Keep-alive

function test_noKeepaliveByDefault()
	local ws, sock = newSocket()
	open( sock )
	assert_equal( 0, pendingTimers() )
end

function test_keepalivePingPongLatency()
	local ws, sock, events = newSocket{ keepalive=1000 }
	open( sock )
	assert_equal( 1, pendingTimers() )
	local n = #sock.sent

	clock = 1000
	fireTimers() -- sends a ping, starts its timeout
	local ping = decodeClientFrame( sock.sent[ n + 1 ] )
	assert_equal( 0x9, ping.opcode )
	assert_equal( 1, pendingTimers() )

	clock = 1040
	feed( sock, serverFrame( 0xA, ping.data ) )
	assert_equal( 40, ws.latency )
	local pongs = eventsOf( events, ws.ONPONG )
	assert_equal( 40, pongs[1].latency )
	assert_equal( 1, pendingTimers(), "next ping scheduled, timeout cancelled" )
	assert_equal( 1000, timers[ #timers ].ms )
end

function test_keepaliveTimeout()
	local ws, sock, events = newSocket{ keepalive=1000, keepalive_timeout=500 }
	open( sock )
	fireTimers() -- ping
	assert_equal( 500, timers[ #timers ].ms )
	fireTimers() -- no pong in time
	local errs = eventsOf( events, ws.ONERROR )
	assert_equal( 1, #errs )
	assert_equal( 3003, errs[1].code )
	assert_equal( ws.STATE_CLOSED, ws:getState() )
	assert_true( sock.closed )
	assert_equal( 0, pendingTimers() )
end

function test_keepaliveStopsOnClose()
	local ws, sock = newSocket{ keepalive=1000 }
	open( sock )
	ws:close()
	-- only the timer waiting for the server's close is left
	assert_equal( 1, pendingTimers() )
	assert_equal( 4000, timers[ #timers ].ms )
end


--== Before the connection is open

function test_closeWhileConnecting()
	local ws, sock, events = newSocket()
	ws:close()
	assert_equal( ws.STATE_CLOSED, ws:getState() )
	assert_true( sock.closed, "socket closed" )
	assert_equal( 1, #eventsOf( events, ws.ONCLOSE ) )
	-- the socket's late events are ignored
	sock.handlers.onConnect{ type=sock.CONNECT, status=sock.CONNECTED }
	assert_equal( 0, #sock.sent, "no handshake request" )
	assert_equal( 0, #eventsOf( events, ws.ONERROR ) )
end

function test_sendsBeforeOpenWait()
	local ws, sock = newSocket()
	ws:send( 'early' )
	assert_equal( 0, #sock.sent, "nothing before the handshake" )
	open( sock )
	assert_equal( 2, #sock.sent, "the request, then the message" )
	local frame = decodeClientFrame( sock.sent[2] )
	assert_equal( 0x1, frame.opcode )
	assert_equal( 'early', frame.data )
end

function test_socketDropIsClose()
	local ws, sock, events = newSocket()
	open( sock )
	sock.handlers.onConnect{ type=sock.CONNECT, status=sock.NOT_CONNECTED }
	assert_equal( ws.STATE_CLOSED, ws:getState() )
	assert_equal( 1, #eventsOf( events, ws.ONCLOSE ) )
	assert_equal( 0, #eventsOf( events, ws.ONERROR ) )
end


--== The transports

-- the native and the browser transport have the same members,
-- and so do their connections
--
function test_transportsHaveSameMembers()
	local function members( t )
		local list = {}
		for k, v in pairs( t ) do
			if type( k ) == 'string' and k:sub( 1, 1 ) ~= '_' then
				table.insert( list, k .. ':' .. type( v ) )
			end
		end
		table.sort( list )
		return table.concat( list, ' ' )
	end

	local bridge_name = 'dmc_corona.dmc_websockets.html5_js'
	local saved_bridge = package.loaded[ bridge_name ]
	package.loaded[ bridge_name ] = {
		open=function() return { ok=true, id=1 } end,
		dispose=function() end
	}
	local Native = require 'dmc_websockets.native'
	local Html5 = require 'dmc_websockets.html5'

	assert_equal( members( Native ), members( Html5 ), "modules" )

	local params = { scheme='ws', host='example.com', port=80, path='/', onEvent=function() end }
	local n_conn, h_conn = Native.connect( params ), Html5.connect( params )
	assert_equal( members( getmetatable( n_conn ) ), members( getmetatable( h_conn ) ), "connections" )
	n_conn:close()
	h_conn:close()

	package.loaded[ 'dmc_websockets.html5' ] = nil
	package.loaded[ bridge_name ] = saved_bridge
end
