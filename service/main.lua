local skynet = require "skynet"
local skynet_manager = require "skynet.manager"
local runconfig = require "runconfig"
local cluster = require "skynet.cluster"

skynet.start(function (  )
	--初始化
	local mynode = skynet.getenv("node")
	local nodecfg = runconfig[mynode]
	--节点管理
	local nodemgr = skynet.newservice("nodemgr","nodemgr",0)
	skynet.name("nodemgr",nodemgr)
	--集群
	cluster.reload(runconfig.cluster)
	cluster.open(mynode)
	--]]

	skynet.error("[start main]")
	--[[gateway
	for i,v in pairs(nodecfg.gateway or {}) do
		local srv = skynet.newservice("gateway","gateway",i)
		skynet.name("gateway"..i,srv)
	end
	--]]


	local srv=skynet.newservice("gateway","gateway",1)
	skynet.name("gateway1",srv)

	--login
	for i,v in pairs(nodecfg.login or {}) do
		local srv = skynet.newservice("login","login",i)
		skynet.name("login"..i,srv)
	end

	local scenesrv = skynet.newservice("scenemgr","scenemgr",0)
	skynet.name("scenemgr",scenesrv)
--[[
	for _,sid in pairs(runconfig.scene[mynode] or {}) do
		local srv = skynet.newservice("scene","scene",sid)
		skynet.name("scene"..sid,srv)
	end
]]
	local anode = runconfig.agentmgr.node
	if mynode==anode then
		local srv = skynet.newservice("agentmgr","agentmgr",0)
		skynet.name("agentmgr",srv)
		local roomsrv = skynet.newservice("roommgr","roommgr",0)
		skynet.name("roommgr",roomsrv)
	else
		local proxy = cluster.proxy(anode,"agentmgr")
		skynet.name("agentmgr",proxy)
		local roomproxy = cluster.proxy(anode,"roommgr")
		skynet.name("roommgr",roomproxy)
	end



	skynet.exit()
end)