--====================================================================--
-- tests/dmc_websockets_spec.lua
--
-- Testing for dmc-websockets using Luna Test
--====================================================================--


module(..., package.seeall)




--====================================================================--
--== Test: DMC WebSockets
--====================================================================--


-- Semantic Versioning Specification: http://semver.org/

local VERSION = "0.2.0"



--====================================================================--
--== Testing Setup
--====================================================================--


local ws_handshake


function suite_setup()
	require 'dmc_corona_boot'
	ws_handshake = require "dmc_websockets.handshake"
end


function test_buildServerKey()
	local key = 'dGhlIHNhbXBsZSBub25jZQ=='
	local srvr_key = 's3pPLMBiTxaQ9kYGzzhZRbK+xOo='
	assert_equal( ws_handshake._buildServerKey( key ), srvr_key, "should be equal" )
end

function test_checkResponse_errors()
	assert_error( function() ws_handshake.checkResponse( nil, nil ) end, "should be error" )
	assert_error( function() ws_handshake.checkResponse( {}, nil ) end, "should be error" )
end

function test_checkResponse_badHeaders()
	local key = 'rzcDgS8mDBqtJSCHyPBT3g=='
	local response = {
		'HTTP/1.1 200 OK',
		'Cache-Control: max-age=900',
		'Content-Type: text/html; charset=utf-8',
		'Server: Microsoft-IIS/7.5',
		'X-AspNet-Version: 4.0.30319',
		'X-Powered-By: ASP.NET',
		'Date: Mon, 14 Jul 2014 21:15:27 GMT',
		'Content-Length: 225',
		'Age: 0',
		''
	}
	assert_false( ws_handshake.checkResponse( response, key ), "should be false" )

	response = {
		'HTTP/1.1 101 Switching Protocols',
		'Cache-Control: max-age=900',
		'Content-Type: text/html; charset=utf-8',
		''
	}
	assert_false( ws_handshake.checkResponse( response, key ), "should be false" )

	response = {
		'HTTP/1.1 101 Switching Protocols',
		'Upgrade: websocket',
		'Content-Type: text/html; charset=utf-8',
		'Server: Microsoft-IIS/7.5',
		''
	}
	assert_false( ws_handshake.checkResponse( response, key ), "should be false" )

	response = {
		'HTTP/1.1 101 Switching Protocols',
		'Upgrade: websocket',
		'Content-Type: text/html; charset=utf-8',
		'Server: Microsoft-IIS/7.5',
		'Connection: Upgrade',
		''
	}
	assert_false( ws_handshake.checkResponse( response, key ), "should be false" )

end


function test_checkResponse_goodHeaders()
	local key = 'dGhlIHNhbXBsZSBub25jZQ=='
	local response = {
		'HTTP/1.1 101 Switching Protocols',
		'Upgrade: websocket',
		'Content-Type: text/html; charset=utf-8',
		'Server: Microsoft-IIS/7.5',
		'Connection: Upgrade',
		'Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=',
		'Sec-WebSocket-Protocol: 7',
		''
	}
	assert_true( ws_handshake.checkResponse( response, key, '7' ), "should be true" )

	key = 'MSg0ucuFeYQT7Bb1/FjgDg=='
	response = {
		'HTTP/1.1 101 Switching Protocols',
		'Upgrade: websocket',
		'Connection: Upgrade',
		'Sec-WebSocket-Accept: mqJX00qwTkOd8zz677Gg+vlqaw8=',
		'Sec-WebSocket-Protocol: 7',
		''
	}
	assert_true( ws_handshake.checkResponse( response, key, { 'chat', '7' } ), "should be true" )

end


-- a valid response, with optional extra header lines
local function goodResponse( ... )
	local response = {
		'HTTP/1.1 101 Switching Protocols',
		'Upgrade: websocket',
		'Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=',
	}
	for _, line in ipairs{ ... } do table.insert( response, line ) end
	table.insert( response, '' )
	return response
end

function test_checkResponse_headerFormats()
	local key = 'dGhlIHNhbXBsZSBub25jZQ=='

	-- Connection may list several tokens, in any case
	assert_true( ws_handshake.checkResponse(
		goodResponse( 'Connection: keep-alive, Upgrade' ), key ), "token list" )
	assert_true( ws_handshake.checkResponse(
		goodResponse( 'Connection: UPGRADE' ), key ), "any case" )

	-- whitespace around header values is optional
	assert_true( ws_handshake.checkResponse(
		goodResponse( 'Connection:Upgrade' ), key ), "no space" )
	assert_true( ws_handshake.checkResponse(
		goodResponse( 'Connection:   Upgrade  ' ), key ), "extra space" )
end

function test_checkResponse_protocolsAndExtensions()
	local key = 'dGhlIHNhbXBsZSBub25jZQ=='

	-- server picked a protocol we didn't offer
	assert_false( ws_handshake.checkResponse(
		goodResponse( 'Connection: Upgrade', 'Sec-WebSocket-Protocol: 7' ), key ), "not requested" )
	assert_false( ws_handshake.checkResponse(
		goodResponse( 'Connection: Upgrade', 'Sec-WebSocket-Protocol: 7' ), key, { 'chat' } ), "not in list" )

	-- we don't offer any extensions, so the server can't use one
	assert_false( ws_handshake.checkResponse(
		goodResponse( 'Connection: Upgrade', 'Sec-WebSocket-Extensions: permessage-deflate' ), key ), "extension" )
end


--== SHA-1, dmc_corona/lib/sha1.lua

function test_sha1()
	local SHA1 = require 'lib.sha1'

	-- FIPS 180 examples, and lengths around the 64-byte block
	assert_equal( 'da39a3ee5e6b4b0d3255bfef95601890afd80709', SHA1.sha1( '' ) )
	assert_equal( 'a9993e364706816aba3e25717850c26c9cd0d89d', SHA1.sha1( 'abc' ) )
	assert_equal( '84983e441c3bd26ebaae4aa1f95129e5e54670f1',
		SHA1.sha1( 'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq' ) )
	assert_equal( '2fd4e1c67a2d28fced849ee1bb76e7391b93eb12',
		SHA1.sha1( 'The quick brown fox jumps over the lazy dog' ) )
	assert_equal( 'c1c8bbdc22796e28c0e15163d20899b65621d65a', SHA1.sha1( string.rep( 'a', 55 ) ) )
	assert_equal( 'c2db330f6083854c99d4b5bfb6e8f29f201be699', SHA1.sha1( string.rep( 'a', 56 ) ) )
	assert_equal( '0098ba824b5c16427bd7a1122a5a442a25ec644d', SHA1.sha1( string.rep( 'a', 64 ) ) )
	assert_equal( 'a080cbda64850abb7b7f67ee875ba068074ff6fe', SHA1.sha1( string.rep( 'a', 10000 ) ) )

	-- bytes from 0x80 up
	assert_equal( '78670e88a9c2c711124471d2f24a8dbc8ce5dba9', SHA1.sha1( string.rep( string.char( 255 ), 3 ) ) )

	local binary = SHA1.sha1_binary( 'abc' )
	assert_equal( 20, #binary )
	assert_equal( 0xa9, binary:byte( 1 ) )
	assert_equal( 0x9d, binary:byte( 20 ) )
end
