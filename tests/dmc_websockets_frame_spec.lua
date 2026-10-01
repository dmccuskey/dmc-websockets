--====================================================================--
-- tests/dmc_websockets_frame_spec.lua
--
-- Testing for dmc-websockets frame parsing using Luna Test
--====================================================================--


module(..., package.seeall)



--====================================================================--
--== Testing Setup
--====================================================================--


local ByteArray, ws_frame, ws_utf8

function suite_setup()
	require 'dmc_corona_boot'
	ByteArray = require 'lib.dmc_lua.lua_bytearray'
	ws_frame = require 'dmc_websockets.frame'
	ws_utf8 = require 'dmc_websockets.utf8'
end


-- build a byte array holding raw frame bytes
local function frameBytes( ... )
	local ba = ByteArray:new()
	ba:writeBuf( string.char( ... ) )
	return ba
end

-- unmasked close frame from server with code and optional reason
local function closeFrame( code, reason )
	local payload = ws_frame.encodeCloseFrameData( code, reason )
	local ba = ByteArray:new()
	ba:writeBuf( string.char( 0x88, #payload ) .. payload )
	return ba
end

-- receive a frame, returning the error it raised
local function receiveError( ba )
	local ok, err = pcall( ws_frame.receiveFrame, ba )
	assert_false( ok, "expected frame to be rejected" )
	return err
end



--====================================================================--
--== Test: Frames
--====================================================================--


function test_receiveTextFrame()
	local ba = frameBytes( 0x81, 0x02, 0x68, 0x69 ) -- "hi"
	local frame = ws_frame.receiveFrame( ba )
	assert_equal( frame.type, 'text' )
	assert_equal( frame.data, 'hi' )
	assert_true( frame.fin )
end

function test_partialFrameNeedsMoreData()
	-- header says 5 bytes, only 2 have arrived
	local ba = frameBytes( 0x81, 0x05, 0x68, 0x69 )
	local err = receiveError( ba )
	assert_true( err.isa ~= nil, "expected an error object" )
	assert_equal( err.message, "Read surpasses buffer size" )
end

function test_rejectMaskedFrameFromServer()
	local ba = frameBytes( 0x81, 0x82, 1, 2, 3, 4, 0x69, 0x6b )
	local err = receiveError( ba )
	assert_equal( err.code, 1002 )
end

function test_protocolErrorReasonIsText()
	local ba = frameBytes( 0x83, 0x00 ) -- reserved opcode 3
	local err = receiveError( ba )
	assert_equal( err.code, 1002 )
	assert_string( err.reason )
end


--====================================================================--
--== Test: Close Frames


function test_validCloseCodes()
	for _, code in ipairs{ 1000, 1001, 1011, 1012, 1013, 1014, 3000, 4999 } do
		local frame = ws_frame.receiveFrame( closeFrame( code ) )
		assert_equal( frame.type, 'close', "code "..code )
	end
end

function test_invalidCloseCodes()
	for _, code in ipairs{ 0, 999, 1004, 1005, 1006, 1015, 1016, 2999, 5000, 65535 } do
		local err = receiveError( closeFrame( code ) )
		assert_equal( err.code, 1002, "code "..code )
	end
end

function test_closeReasonMustBeUTF8()
	local frame = ws_frame.receiveFrame( closeFrame( 1000, "κόσμε" ) )
	assert_equal( frame.type, 'close' )

	local err = receiveError( closeFrame( 1000, "\206\186\225\189\185\207\131\206\188\206\181\237\160\128" ) )
	assert_equal( err.code, 1007 )
end



--====================================================================--
--== Test: Masking


-- client frames are masked; unmask with a plain byte-by-byte xor
-- at lengths around the 4-byte mask and the 2000-byte chunk size
function test_buildMaskedFrame()
	local bit = require 'lib.dmc_lua.bit'
	for _, len in ipairs{ 1, 2, 3, 4, 5, 125, 126, 1999, 2000, 2001, 2003, 70001 } do
		local data = string.rep( "BAsd7&jh23", math.ceil( len/10 ) ):sub( 1, len )
		local msg = {
			start=1, opcode=0x2, masked=true,
			getAvailable=function() return 0 end,
			read=function() return data end
		}
		local wire = ws_frame.buildFrames{ message=msg }.frame
		local hlen = ( len <= 125 and 2 ) or ( len <= 0xffff and 4 ) or 10
		local mask = { wire:byte( hlen+1, hlen+4 ) }
		local payload = wire:sub( hlen+5 )
		assert_equal( #payload, len )
		local unmasked = {}
		for i=1,len do
			unmasked[i] = string.char( bit.bxor( payload:byte(i), mask[(i-1)%4+1] ) )
		end
		assert_equal( table.concat( unmasked ), data, "length "..len )
	end
end



--====================================================================--
--== Test: frameSize


function test_frameSize()
	local fs = ws_frame.frameSize
	assert_nil( fs( "" ) )
	assert_nil( fs( "\129" ) ) -- header incomplete
	assert_equal( 2 + 5, fs( "\129\5" ) ) -- small, payload not here yet
	assert_equal( 2 + 5, fs( "\129\5hello" ) )
	assert_nil( fs( "\130\126\1" ) ) -- 16-bit length incomplete
	assert_equal( 4 + 1000, fs( "\130\126\3\232" ) )
	assert_nil( fs( "\130\127\0\0\0\0\0" ) ) -- 64-bit length incomplete
	assert_equal( 10 + 0x01000000, fs( "\130\127\0\0\0\0\1\0\0\0" ) )
	-- frames that fail anyway: header size only
	assert_equal( 10, fs( "\130\127\0\0\0\1\0\0\0\0" ) ) -- too long
	assert_equal( 4, fs( "\130\254\3\232" ) ) -- masked
end



--====================================================================--
--== Test: UTF-8


function test_utf8Valid()
	assert_true( ws_utf8.isValid( "" ) )
	assert_true( ws_utf8.isValid( "hello" ) )
	assert_true( ws_utf8.isValid( "κόσμε" ) )
	assert_true( ws_utf8.isValid( "\244\143\191\191" ) ) -- U+10FFFF
end

function test_utf8Invalid()
	assert_false( ws_utf8.isValid( "\192\175" ) ) -- overlong '/'
	assert_false( ws_utf8.isValid( "\237\160\128" ) ) -- surrogate U+D800
	assert_false( ws_utf8.isValid( "\244\144\128\128" ) ) -- above U+10FFFF
	assert_false( ws_utf8.isValid( "\206" ) ) -- truncated
end

function test_utf8Incremental()
	-- "κ" (0xCE 0xBA) split across two pieces
	local v = ws_utf8.newValidator()
	assert_true( v:feed( "\206" ) )
	assert_false( v:isComplete() )
	assert_true( v:feed( "\186" ) )
	assert_true( v:isComplete() )

	-- fails as soon as the bad byte is seen
	v = ws_utf8.newValidator()
	assert_false( v:feed( "ok\237\160" ) )
end
