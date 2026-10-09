--====================================================================--
-- DMC WebSockets HTML5 Demo
--
-- Talk to an echo server, on screen. The same code runs in the
-- Solar2D Simulator, on a device and in the browser (an HTML5 build)
--
-- Sample code is MIT licensed, the same license which covers Lua itself
-- http://en.wikipedia.org/wiki/MIT_License
-- Copyright (C) 2026 David McCuskey. All Rights Reserved.
--====================================================================--


print( '\n\n##############################################\n\n' )


--====================================================================--
--== Imports


local WebSockets = require 'dmc_corona.dmc_websockets'



--====================================================================--
--== Setup, Constants


local URI = 'wss://echo.websocket.org'

local IS_HTML5 = ( system.getInfo( 'platform' ) == 'html5' )
local IS_SIMULATOR = ( system.getInfo( 'environment' ) == 'simulator' )

-- the area of the screen we can draw on, whatever the device
local LEFT = display.safeScreenOriginX
local TOP = display.safeScreenOriginY
local WIDTH = display.safeActualContentWidth
local HEIGHT = display.safeActualContentHeight
local MARGIN = 12

local COLOR = {
	background = { 0.96, 0.97, 0.98 },
	panel = { 1, 1, 1 },
	border = { 0.82, 0.85, 0.89 },
	title = { 0.11, 0.15, 0.21 },
	text = { 0.33, 0.38, 0.45 },
	sent = { 0.10, 0.39, 0.82 },
	received = { 0.07, 0.50, 0.29 },
	info = { 0.45, 0.50, 0.57 },
	error = { 0.78, 0.16, 0.16 },
	button = { 0.10, 0.39, 0.82 },
	button_text = { 1, 1, 1 },
	connecting = { 0.92, 0.62, 0.09 },
	open = { 0.13, 0.64, 0.36 },
	closed = { 0.62, 0.65, 0.70 },
}

local ws = nil
local count = 0

local status_dot, status_text
local send_button, connect_button
local log_group, log_top, log_height
local log_lines = {}



--====================================================================--
--== Support Functions


local function platformName()
	if IS_HTML5 then return "the browser" end
	if IS_SIMULATOR then return "the Simulator" end
	return "a device"
end


-- add a line to the bottom of the log, drop lines from the top
-- once the log is full
--
local function log( text, color )
	print( text )

	local line = display.newText{
		parent=log_group,
		text=text,
		x=LEFT + MARGIN*2, y=0,
		width=WIDTH - MARGIN*4,
		font=native.systemFont, fontSize=12,
		align='left',
	}
	line.anchorX, line.anchorY = 0, 0
	line:setFillColor( unpack( color or COLOR.info ) )
	log_lines[ #log_lines+1 ] = line

	local gap = 4
	local total = 0
	for i=1, #log_lines do
		total = total + log_lines[i].height + gap
	end
	while total > log_height and #log_lines > 1 do
		local first = table.remove( log_lines, 1 )
		total = total - first.height - gap
		first:removeSelf()
	end

	local y = log_top
	for i=1, #log_lines do
		log_lines[i].y = y
		y = y + log_lines[i].height + gap
	end
end


local function setButtonEnabled( button, is_enabled )
	button.is_enabled = is_enabled
	button.alpha = is_enabled and 1 or 0.35
end


-- show the state of the connection: 'connecting', 'open',
-- 'closing' or 'closed'
--
local function showStatus( state )
	local labels = {
		connecting = "Connecting to " .. URI,
		open = "Connected to " .. URI,
		closing = "Closing",
		closed = "Not connected",
	}
	local colors = {
		connecting = COLOR.connecting,
		open = COLOR.open,
		closing = COLOR.connecting,
		closed = COLOR.closed,
	}
	status_text.text = labels[ state ]
	status_dot:setFillColor( unpack( colors[ state ] ) )

	setButtonEnabled( send_button, state == 'open' )
	setButtonEnabled( connect_button, state == 'open' or state == 'closed' )
	connect_button.label.text = ( state == 'closed' ) and "Connect" or "Close"
end



--====================================================================--
--== Main Functions


local function webSocketsEvent_handler( event )
	-- an event of a connection we have already replaced
	if event.target ~= ws then return end

	local evt_type = event.type

	if evt_type == ws.ONOPEN then
		log( "Connected" )
		showStatus( 'open' )

	elseif evt_type == ws.ONMESSAGE then
		log( "Received: " .. tostring( event.message.data ), COLOR.received )

	elseif evt_type == ws.ONCLOSE then
		log( "Closed (" .. tostring( event.code ) .. ") " .. tostring( event.reason ) )
		showStatus( 'closed' )

	elseif evt_type == ws.ONERROR then
		local reason = event.emsg or event.reason
		log( "Error (" .. tostring( event.code ) .. ") " .. tostring( reason ), COLOR.error )
		showStatus( 'closed' )

	end
end


local function connect()
	-- a closed WebSocket can't be opened again: make a new one
	if ws then ws:removeSelf() end

	log( "Connecting" )
	showStatus( 'connecting' )

	ws = WebSockets{
		uri=URI
	}
	ws:addEventListener( ws.EVENT, webSocketsEvent_handler )
end


local function close()
	showStatus( 'closing' )
	ws:close()
end


local function sendMessage()
	count = count + 1
	local str = "Hello " .. tostring( count ) .. " from " .. platformName()
	log( "Sent: " .. str, COLOR.sent )
	ws:send( str )
end



--====================================================================--
--== User Interface


local function newButton( params )
	local button = display.newGroup()
	button.x, button.y = params.x, params.y

	local bg = display.newRoundedRect( button, 0, 0, params.width, params.height, 6 )
	bg:setFillColor( unpack( COLOR.button ) )

	button.label = display.newText{
		parent=button,
		text=params.label,
		x=0, y=0,
		font=native.systemFontBold, fontSize=15,
	}
	button.label:setFillColor( unpack( COLOR.button_text ) )

	button.is_enabled = true
	button:addEventListener( 'tap', function( event )
		if button.is_enabled then params.onTap() end
		return true
	end)

	return button
end


local function createUI()
	local bg = display.newRect(
		display.contentCenterX, display.contentCenterY,
		display.actualContentWidth, display.actualContentHeight
	)
	bg:setFillColor( unpack( COLOR.background ) )

	local y = TOP + MARGIN

	local title = display.newText{
		text="dmc-websockets",
		x=LEFT + MARGIN, y=y,
		font=native.systemFontBold, fontSize=20,
	}
	title.anchorX, title.anchorY = 0, 0
	title:setFillColor( unpack( COLOR.title ) )

	local version = display.newText{
		text="version " .. WebSockets.VERSION,
		x=LEFT + WIDTH - MARGIN, y=y + 8,
		font=native.systemFont, fontSize=12,
	}
	version.anchorX, version.anchorY = 1, 0
	version:setFillColor( unpack( COLOR.text ) )

	y = y + 30

	local about = display.newText{
		text="A WebSocket client for Solar2D, running in " .. platformName()
			.. ". Each message you send goes to an echo server, which sends it back.",
		x=LEFT + MARGIN, y=y,
		width=WIDTH - MARGIN*2,
		font=native.systemFont, fontSize=12,
		align='left',
	}
	about.anchorX, about.anchorY = 0, 0
	about:setFillColor( unpack( COLOR.text ) )

	y = y + about.height + MARGIN

	status_dot = display.newCircle( LEFT + MARGIN + 5, y + 8, 5 )

	status_text = display.newText{
		text="",
		x=LEFT + MARGIN + 18, y=y,
		font=native.systemFont, fontSize=12,
	}
	status_text.anchorX, status_text.anchorY = 0, 0
	status_text:setFillColor( unpack( COLOR.title ) )

	y = y + 16 + MARGIN

	local button_w = ( WIDTH - MARGIN*3 ) / 2
	local button_h = 36

	send_button = newButton{
		label="Send a Message",
		x=LEFT + MARGIN + button_w/2, y=y + button_h/2,
		width=button_w, height=button_h,
		onTap=sendMessage,
	}
	connect_button = newButton{
		label="Close",
		x=LEFT + MARGIN*2 + button_w*1.5, y=y + button_h/2,
		width=button_w, height=button_h,
		onTap=function()
			if ws.readyState == ws.ESTABLISHED then
				close()
			else
				connect()
			end
		end,
	}

	y = y + button_h + MARGIN

	local panel_h = TOP + HEIGHT - MARGIN - y
	local panel = display.newRoundedRect(
		LEFT + WIDTH/2, y + panel_h/2, WIDTH - MARGIN*2, panel_h, 6
	)
	panel:setFillColor( unpack( COLOR.panel ) )
	panel:setStrokeColor( unpack( COLOR.border ) )
	panel.strokeWidth = 1

	log_group = display.newGroup()
	log_top = y + MARGIN*0.75
	log_height = panel_h - MARGIN*1.5
end


createUI()
connect()
