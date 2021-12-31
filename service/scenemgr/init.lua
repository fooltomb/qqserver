local skynet = require "skynet"
local s = require "service"
local skynet_manager = require "skynet.manager"

local scenes = {}
--local mynode = ""

s.init=function (  )
	--mynode=skynet.getenv("node")
end

s.resp.createScene=function ( source,roomid,count)

	local scenesrv = skynet.newservice("scene","scene",roomid)
	skynet.name("scene"..roomid,scenesrv)
	skynet.error("create a scene")
	skynet.call(scenesrv,"lua","setPlayerCount",count)
end

s.start(...)