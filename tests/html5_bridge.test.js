//====================================================================--
// tests/html5_bridge.test.js
//
// Testing the HTML5 bridge (dmc_corona/dmc_websockets/html5_js.js) with
// Node's test runner, against a stand-in for the browser's WebSocket
//
// usage: node --test tests/html5_bridge.test.js
//====================================================================--

'use strict';

const test = require( 'node:test' );
const assert = require( 'node:assert' );
const fs = require( 'node:fs' );
const path = require( 'node:path' );
const vm = require( 'node:vm' );

const SOURCE = fs.readFileSync(
	path.join( __dirname, '..', 'dmc_corona', 'dmc_websockets', 'html5_js.js' ), 'utf8' );
const NAME = 'dmc_corona_dmc_websockets_html5_js';


// the browser's WebSocket, driven by the test
//
class FakeWebSocket {
	constructor( url, protocols ) {
		if ( !/^wss?:\/\//.test( url ) ) {
			const e = new Error( 'The URL is invalid' );
			e.name = 'SyntaxError';
			throw e;
		}
		this.url = url;
		this.protocols = protocols;
		this.readyState = 0;
		this.sent = [];
		this.closeCalls = [];
		FakeWebSocket.all.push( this );
	}
	send( data ) {
		this.sent.push( data );
	}
	close( code, reason ) {
		if ( code !== undefined && code !== 1000 && ( code < 3000 || code > 4999 ) ) {
			const e = new Error( 'invalid code' );
			e.name = 'InvalidAccessError';
			throw e;
		}
		if ( reason !== undefined && Buffer.byteLength( reason ) > 123 ) {
			const e = new Error( 'reason too long' );
			e.name = 'SyntaxError';
			throw e;
		}
		this.closeCalls.push( [ code, reason ] );
		this.readyState = 2;
	}
	// the server's side
	serverOpen() { this.readyState = 1; this.onopen && this.onopen( {} ); }
	serverMessage( data ) { this.onmessage && this.onmessage( { data: data } ); }
	serverClose( code, reason ) {
		this.readyState = 3;
		this.onclose && this.onclose( { code: code, reason: reason, wasClean: code !== 1006 } );
	}
	serverFail() {
		this.readyState = 3;
		this.onerror && this.onerror( {} );
		this.onclose && this.onclose( { code: 1006, reason: '', wasClean: false } );
	}
}

// a fresh page with the bridge loaded, as Solar2D's loader does it
//
function loadBridge() {
	FakeWebSocket.all = [];
	const window = { WebSocket: FakeWebSocket, btoa: btoa, atob: atob };
	window.window = window;
	vm.createContext( window );
	vm.runInContext( SOURCE, window );
	assert.ok( Object.prototype.hasOwnProperty.call( window, NAME ), 'defines the global the loader looks for' );
	// values cross the bridge as JSON
	const bridge = window[ NAME ];
	const call = ( fn, params ) => JSON.parse( JSON.stringify( bridge[ fn ]( JSON.parse( JSON.stringify( params ) ) ) ) );
	return { window, bridge, call };
}

function open( call, params ) {
	const result = call( 'open', Object.assign( { url: 'wss://example.com/chat', protocols: [] }, params ) );
	assert.strictEqual( result.ok, true );
	return { id: result.id, ws: FakeWebSocket.all[ FakeWebSocket.all.length - 1 ] };
}

function poll( call, id ) {
	const result = call( 'poll', { id: id } );
	assert.strictEqual( result.ok, true );
	return result.events;
}


test( 'opens, queues events in order, and reads them', () => {
	const { call } = loadBridge();
	const { id, ws } = open( call );
	assert.strictEqual( ws.url, 'wss://example.com/chat' );
	assert.strictEqual( ws.binaryType, 'arraybuffer' );

	ws.serverOpen();
	ws.serverMessage( 'hello' );
	ws.serverClose( 4001, 'bye' );
	assert.deepStrictEqual( poll( call, id ), [
		{ kind: 'open' },
		{ kind: 'message', type: 'text', data: 'hello' },
		{ kind: 'close', code: 4001, reason: 'bye', wasClean: true }
	] );
	assert.deepStrictEqual( poll( call, id ), [] );
} );

test( 'passes protocols only when there are some', () => {
	const { call } = loadBridge();
	assert.strictEqual( open( call ).ws.protocols, undefined );
	assert.deepStrictEqual( open( call, { protocols: [ 'v2', 'v1' ] } ).ws.protocols, [ 'v2', 'v1' ] );
} );

test( 'a constructor error is a result, not an exception', () => {
	const { call } = loadBridge();
	const result = call( 'open', { url: 'http://example.com', protocols: [] } );
	assert.strictEqual( result.ok, false );
	assert.strictEqual( result.error.kind, 'constructor' );
	assert.strictEqual( result.error.name, 'SyntaxError' );
} );

test( 'binary both ways, every byte value', () => {
	const { call } = loadBridge();
	const { id, ws } = open( call );
	ws.serverOpen();
	const bytes = Uint8Array.from( { length: 256 * 3 + 1 }, ( _, i ) => i % 256 );
	const str = Buffer.from( bytes ).toString( 'latin1' );

	assert.deepStrictEqual( call( 'send', { id: id, type: 'binary', data: str } ), { ok: true } );
	assert.deepStrictEqual( Buffer.from( ws.sent[ 0 ] ), Buffer.from( bytes ) );

	ws.serverMessage( bytes.buffer );
	ws.serverMessage( new ArrayBuffer( 0 ) );
	const events = poll( call, id ).slice( 1 );
	assert.deepStrictEqual( events, [
		{ kind: 'message', type: 'binary', data: str },
		{ kind: 'message', type: 'binary', data: '' }
	] );
} );

test( 'a large binary message', () => {
	const { call } = loadBridge();
	const { id, ws } = open( call );
	ws.serverOpen();
	const bytes = new Uint8Array( 1024 * 1024 + 7 ).map( ( _, i ) => ( i * 31 ) % 256 );
	ws.serverMessage( bytes.buffer );
	const event = poll( call, id )[ 1 ];
	assert.ok( Buffer.from( event.data, 'latin1' ).equals( Buffer.from( bytes ) ) );
} );

test( 'text keeps Unicode and NUL', () => {
	const { call } = loadBridge();
	const { id, ws } = open( call );
	ws.serverOpen();
	const text = 'héllo 😀 \u0000 end';
	call( 'send', { id: id, type: 'text', data: text } );
	assert.strictEqual( ws.sent[ 0 ], text );
	ws.serverMessage( text );
	assert.strictEqual( poll( call, id )[ 1 ].data, text );
} );

test( 'send before open or after close is refused', () => {
	const { call } = loadBridge();
	const { id, ws } = open( call );
	assert.strictEqual( call( 'send', { id: id, type: 'text', data: 'x' } ).error.kind, 'not_open' );
	ws.serverOpen();
	ws.serverClose( 1000, '' );
	assert.strictEqual( call( 'send', { id: id, type: 'text', data: 'x' } ).error.kind, 'not_open' );
	assert.deepStrictEqual( ws.sent, [] );
} );

test( 'close passes code and reason, once', () => {
	const { call } = loadBridge();
	const { id, ws } = open( call );
	ws.serverOpen();
	assert.deepStrictEqual( call( 'close', { id: id, code: 1000, reason: 'done' } ), { ok: true } );
	assert.deepStrictEqual( call( 'close', { id: id, code: 1000, reason: 'again' } ), { ok: true } );
	assert.deepStrictEqual( ws.closeCalls, [ [ 1000, 'done' ] ] );
} );

test( 'close without a code, or with a reason too long', () => {
	const { call } = loadBridge();
	let { id, ws } = open( call );
	ws.serverOpen();
	call( 'close', { id: id } );
	assert.deepStrictEqual( ws.closeCalls, [ [ undefined, undefined ] ] );

	( { id, ws } = open( call ) );
	ws.serverOpen();
	assert.deepStrictEqual( call( 'close', { id: id, code: 4000, reason: 'x'.repeat( 200 ) } ), { ok: true } );
	assert.deepStrictEqual( ws.closeCalls, [ [ 4000, undefined ] ] );
} );

test( 'error then close are both queued', () => {
	const { call } = loadBridge();
	const { id, ws } = open( call );
	ws.serverFail();
	assert.deepStrictEqual( poll( call, id ), [
		{ kind: 'error' },
		{ kind: 'close', code: 1006, reason: '', wasClean: false }
	] );
} );

test( 'connections are kept apart, ids are never reused', () => {
	const { call } = loadBridge();
	const a = open( call );
	a.ws.serverOpen();
	call( 'dispose', { id: a.id } );
	const b = open( call );
	assert.notStrictEqual( a.id, b.id );
	b.ws.serverOpen();

	// the replaced socket's close arrives late
	a.ws.serverClose( 1000, '' );
	assert.deepStrictEqual( poll( call, b.id ), [ { kind: 'open' } ] );
	assert.strictEqual( call( 'poll', { id: a.id } ).error.kind, 'invalid_id' );
} );

test( 'dispose closes the browser socket and drops its events', () => {
	const { call } = loadBridge();
	const { id, ws } = open( call );
	ws.serverOpen();
	ws.serverMessage( 'unread' );
	assert.deepStrictEqual( call( 'dispose', { id: id } ), { ok: true } );
	assert.strictEqual( ws.onmessage, null );
	assert.deepStrictEqual( ws.closeCalls, [ [ undefined, undefined ] ] );
	assert.deepStrictEqual( call( 'dispose', { id: id } ), { ok: true } );
} );

test( 'loading twice keeps the live connections', () => {
	const { window, call } = loadBridge();
	const { id } = open( call );
	vm.runInContext( SOURCE, window );
	assert.strictEqual( call( 'poll', { id: id } ).ok, true );
} );
