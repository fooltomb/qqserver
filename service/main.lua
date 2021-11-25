local skynet = require "skynet"

local runconfig = require "runconfig"

skynet.start(function (  )
	--初始化
	local mynode = skynet.getenv("node")
	local nodecfg = runconfig[mynode]

	skynet.error("[start main]")
	--gateway
	for i,v in pairs(nodecfg.gateway or {}) do
		local srv = skynet.newservice("gateway","gateway",i)
		skynet.name("gateway"..i,srv)
	end
	--skynet.newservice("gateway","gateway",1)

	--login
	for i,v in pairs(nodecfg.login or {}) do
		local srv = skynet.newservice("login","login",i)
		skynet.name("login"..i,srv)
	end
	skynet.exit()
end)