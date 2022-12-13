local skynet = require "skynet"
local s = require "service"
local cjson= require "cjson"

s.client={}

s.client.login=function ( fd,msg,source )

	local msgjson = cjson.decode(msg)
	--skynet.error("login recv "..msgpb.name.." "..msgpb.pw)
	local playername=msgjson.name
	local pwd = msgjson.pw
	local gate = source
	node = skynet.getenv("node")
	local isok,agent,playerInfo = skynet.call("agentmgr","lua","reqlogin",playername,pwd,node,gate)
	if not isok then
		return playerInfo
	end
	local isok = skynet.call(gate,"lua","sure_agent",fd,playerInfo.id,agent)
	if not isok then
		playerInfo.error="agent注册失败"
		playerInfo.rusult=0
		return playerInfo
	end
	skynet.error("login succeed "..playerInfo.id.."|name:"..playerInfo.name)
	skynet.send(agent,"lua","client","setPlayer",playerInfo)
	return playerInfo
end

s.client.register=function ( fd,msg,source )
	local msgjson = cjson.decode(msg)
	local playername = msgjson.name
	local pwd = msgjson.pw
	local gate = source
	node=skynet.getenv("node")
	local isok,agent,playerInfo = skynet.call("agentmgr","lua","reqregister",playername,pwd,node,gate)
	if not isok then
		--return {"register",1,agent}
		return playerInfo
	end
	isok=skynet.call(gate,"lua","sure_agent",fd,playerInfo.id,agent)
	if not isok then
		--return {"register",1,"gate注册失败"}
		playerInfo.result=0
		playerInfo.error="gate注册失败"
		return playerInfo
	end
	skynet.error("register succeed "..playerInfo.id)
	skynet.send(agent,"lua","client","setPlayer",playerInfo)
	return playerInfo
end

s.resp.client=function ( source,fd,cmd,msg )
	if s.client[cmd] then
		local ret_msg = s.client[cmd](fd,msg,source)
		--skynet.error("login return")
		local ret_json = cjson.encode(ret_msg)
		skynet.send(source,"lua","send_by_fd",fd,cmd,ret_pb)
	else
		skynet.error("s.resp.client fail",cmd)
	end
end

function s.init( )
	--pb.register_file("./proto/PMPlayer.pb")
end

s.start(...)
