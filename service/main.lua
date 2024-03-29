local skynet = require "skynet"
local skynet_manager = require "skynet.manager"
local runconfig = require "runconfig"
local cluster = require "skynet.cluster"
local pb=require "protobuf"



function test4(cmd,msg)
	--[[
	pb.register_file("./proto/login.pb")
	local msg={
		id=12,
		pw="dfadf",
	}
	local buff=pb.encode("login.Login",msg)
	skynet.error("len:"..string.len(buff))
	local umsg=pb.decode("login.Login",buff)
	if umsg then
		skynet.error("id:"..umsg.id)
		skynet.error("pw:"..umsg.pw)
	else
		skynet.error("error")
	end
	--]]

	local namelen=string.len(cmd)
	local bodylen=string.len(msg)
	local len=2+namelen+bodylen
	local formatstr=string.format("> i2 i2 c%d c%d",namelen,bodylen)
	skynet.error(formatstr)
	local buff = string.pack(formatstr,len,namelen,cmd,msg)
	return buff

end

function test5( buff )
	local len = string.len(buff)
	local namelen_format = string.format("> i2 i2 c%d",len-4)
	local _,namelen,other = string.unpack(namelen_format,buff)
	
	local bodylen=len-namelen-2
	local bodyformat = string.format("> c%d c%d",namelen,bodylen)
	local cmd,msg = string.unpack(bodyformat,other)
	skynet.error(cmd.." : "..msg)
end


skynet.start(function (  )
	--test5(test4("login","dfdf"))
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

	skynet.call("gateway1","lua","open",{
		address="0.0.0.0",
		prot=32355,
		maxclient=1024,
		nodelay=true,
	})


	skynet.exit()
end)
