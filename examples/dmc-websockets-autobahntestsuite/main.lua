--====================================================================--
-- dmc_websockets: Autobahn Test Suite
--
-- Run the Autobahn|Testsuite fuzzing server's cases against dmc-websockets,
-- showing progress and a tally of results on screen
--
-- Sample code is MIT licensed, the same license which covers Lua itself
-- http://en.wikipedia.org/wiki/MIT_License
-- Copyright (C) 2014-2015 David McCuskey. All Rights Reserved.
--====================================================================--



print( '\n\n##############################################\n\n' )


require 'dmc_corona_boot'
require 'dmc_corona.lib.dmc_lua.lua_bytearray'


--====================================================================--
--== Imports


local json = require 'json'
local WebSockets = require 'dmc_corona.dmc_websockets'

local AppConfig = require 'app_config'



--====================================================================--
--== Setup, Constants


local CONF = AppConfig.autobahn
local SERVER = string.format( 'ws://%s:%s', CONF.host, CONF.port )
local CASE_TIMEOUT = ( CONF.case_timeout or 60 ) * 1000

-- result categories, in display order
local BEHAVIORS = { 'OK', 'NON-STRICT', 'INFORMATIONAL', 'UNIMPLEMENTED', 'FAILED' }
local COLORS = {
	['OK']={ 0.2, 0.8, 0.3 },
	['NON-STRICT']={ 0.95, 0.75, 0.1 },
	['INFORMATIONAL']={ 0.3, 0.6, 1 },
	['UNIMPLEMENTED']={ 0.6, 0.6, 0.6 },
	['FAILED']={ 1, 0.25, 0.25 },
}

local W, H = display.contentWidth, display.contentHeight
local FONT = native.systemFont

local ws -- current connection
local case_count, case_idx = 0, 0
local case_timer
local tally = {}
local not_ok = {} -- ids of cases that weren't OK
local start_time

local ui = {}

local runCase, nextCase



--====================================================================--
--== Display


local function newLabel( text, y, size, color )
	local t = display.newText{ text=text, x=W/2, y=y, width=W-24, font=FONT, fontSize=size, align='left' }
	t:setFillColor( unpack( color or { 1, 1, 1 } ) )
	return t
end

local function buildUI()
	display.setStatusBar( display.HiddenStatusBar )
	display.setDefault( 'background', 0.08, 0.09, 0.11 )

	newLabel( 'dmc-websockets '..WebSockets.VERSION, 28, 20 )
	newLabel( 'Autobahn|Testsuite at '..SERVER, 52, 12, { 0.6, 0.6, 0.65 } )

	-- progress bar
	local bar_w = W-24
	local bg = display.newRect( W/2, 80, bar_w, 10 )
	bg:setFillColor( 0.2, 0.2, 0.24 )
	ui.bar = display.newRect( 12, 80, 1, 10 )
	ui.bar.anchorX = 0
	ui.bar:setFillColor( unpack( COLORS['OK'] ) )
	ui.bar.max_w = bar_w
	ui.progress = newLabel( 'Connecting...', 100, 13 )

	ui.case_id = newLabel( '', 136, 16 )
	ui.case_desc = newLabel( '', 184, 11, { 0.75, 0.75, 0.8 } )
	ui.case_desc.anchorY = 0
	ui.case_desc.y = 150 -- up to 3 lines, see showCase()

	ui.counts = {}
	for i, name in ipairs( BEHAVIORS ) do
		local y = 200 + i*26
		local dot = display.newCircle( 22, y, 6 )
		dot:setFillColor( unpack( COLORS[ name ] ) )
		local label = display.newText{ text=name, x=36, y=y, font=FONT, fontSize=14 }
		label.anchorX = 0
		local count = display.newText{ text='0', x=W-12, y=y, font=FONT, fontSize=16 }
		count.anchorX = 1
		ui.counts[ name ] = count
	end

	ui.status = newLabel( '', 380, 12, { 0.75, 0.75, 0.8 } )
	ui.status.anchorY = 0
	ui.status.y = 360
end

local function showCase( id, desc )
	ui.case_id.text = 'Case '..id
	-- the server's descriptions contain HTML
	desc = ( desc or '' ):gsub( '<br>', ' ' ):gsub( '<[^>]+>', '' )
	if #desc > 160 then desc = desc:sub( 1, 157 )..'...' end
	ui.case_desc.text = desc
end

local function showProgress()
	ui.progress.text = string.format( '%d of %d cases', case_idx, case_count )
	if case_count > 0 then
		ui.bar.width = math.max( 1, ui.bar.max_w * case_idx / case_count )
	end
end

local function showTally( behavior )
	tally[ behavior ] = ( tally[ behavior ] or 0 ) + 1
	local label = ui.counts[ behavior ]
	if label then label.text = tostring( tally[ behavior ] ) end
	-- the bar shows the worst result so far
	if behavior == 'FAILED' or ( behavior == 'NON-STRICT' and not tally['FAILED'] ) then
		ui.bar:setFillColor( unpack( COLORS[ behavior ] ) )
	end
end



--====================================================================--
--== Autobahn


local function log( ... )
	print( table.concat( { ... }, ' ' ) )
end

local function cancelCaseTimer()
	if case_timer then
		timer.cancel( case_timer )
		case_timer = nil
	end
end

-- open a new connection to the server, replacing any previous one
-- handler receives only message text, and a final call with nil on close
local function openSocket( path, onMessage, onClose )
	if ws then
		ws:removeEventListener( ws.EVENT, ws._handler )
		ws:removeSelf()
	end
	ws = WebSockets{ uri=SERVER..path }
	ws._handler = function( event )
		if event.type == ws.ONMESSAGE then
			if onMessage then onMessage( event.message ) end
		elseif event.type == ws.ONCLOSE or event.type == ws.ONERROR then
			-- defer, so the socket isn't removed inside its own event
			local code = event.code
			timer.performWithDelay( 1, function() onClose( code ) end )
		end
	end
	ws:addEventListener( ws.EVENT, ws._handler )
end

local function caseParam( idx )
	if CONF.cases then
		return 'casetuple='..CONF.cases[ idx ]
	end
	return 'case='..idx
end

local function getCaseStatus( idx, id )
	local behavior
	openSocket( string.format( '/getCaseStatus?%s&agent=%s', caseParam( idx ), CONF.agent ),
		function( msg )
			local data = json.decode( msg.data )
			behavior = data and data.behavior
		end,
		function()
			behavior = behavior or 'FAILED'
			showTally( behavior )
			if behavior ~= 'OK' then table.insert( not_ok, id..' '..behavior ) end
			log( string.format( 'case %3d/%d %-8s %s', idx, case_count, id, behavior ) )
			nextCase()
		end )
end

-- echo everything the server sends until it closes the connection
local function runEcho( idx, id )
	openSocket( string.format( '/runCase?%s&agent=%s', caseParam( idx ), CONF.agent ),
		function( msg )
			ws:send( msg.data, { type=msg.type } )
		end,
		function()
			cancelCaseTimer()
			getCaseStatus( idx, id )
		end )

	case_timer = timer.performWithDelay( CASE_TIMEOUT, function()
		case_timer = nil
		log( string.format( 'case %3d/%d %-8s TIMEOUT after %ds', idx, case_count, id, CASE_TIMEOUT/1000 ) )
		getCaseStatus( idx, id )
	end )
end

runCase = function( idx )
	local info
	openSocket( string.format( '/getCaseInfo?%s', caseParam( idx ) ),
		function( msg ) info = json.decode( msg.data ) end,
		function()
			local id = info and info.id or tostring( idx )
			showCase( id, info and info.description )
			runEcho( idx, id )
		end )
end

local function finish()
	local secs = ( system.getTimer() - start_time ) / 1000
	ui.case_id.text = 'Complete'
	ui.case_desc.text = string.format( '%d cases in %d:%02d', case_count, secs/60, secs%60 )
	ui.status.text = #not_ok == 0 and 'All cases OK'
		or 'Not OK: '..table.concat( not_ok, ', ' )
	log( 'Complete:', ui.case_desc.text )
	for _, name in ipairs( BEHAVIORS ) do
		if tally[ name ] then log( string.format( '  %-14s %d', name, tally[ name ] ) ) end
	end

	-- write the HTML/JSON reports on the server
	openSocket( '/updateReports?agent='..CONF.agent, nil, function()
		log( 'Reports updated for agent '..CONF.agent )
		ui.status.text = ui.status.text..'\n\nReports written by the server for agent '..CONF.agent
	end )
end

nextCase = function()
	case_idx = case_idx + 1
	if case_idx <= case_count then
		showProgress()
		runCase( case_idx )
	else
		case_idx = case_count
		showProgress()
		finish()
	end
end

local function start()
	start_time = system.getTimer()
	if CONF.cases then
		case_count = #CONF.cases
		log( 'Running', case_count, 'selected cases' )
		nextCase()
		return
	end
	openSocket( '/getCaseCount',
		function( msg ) case_count = tonumber( msg.data ) or 0 end,
		function( code )
			if case_count == 0 then
				ui.progress.text = 'No fuzzing server at '..SERVER
				ui.status.text = 'Start it (see this example\'s README), then relaunch.'
				log( 'ERROR: could not get case count from', SERVER, tostring( code ) )
				return
			end
			log( 'Autobahn case count:', case_count )
			nextCase()
		end )
end



--====================================================================--
--== Main


buildUI()
log( 'dmc_websockets: Start Autobahn Testing against '..SERVER )
start()
