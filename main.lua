--====================================================================--
-- DMC WebSockets Unit Test
--
-- Run Unit Tests for dmc_websockets
--
-- Sample code is MIT licensed, the same license which covers Lua itself
-- http://en.wikipedia.org/wiki/MIT_License
-- Copyright (C) 2014-2015 David McCuskey. All Rights Reserved.
--====================================================================--


print( '\n\n##############################################\n\n' )


require 'tests.lunatest'

lunatest.suite( 'tests.dmc_websockets_spec' )
lunatest.run()
