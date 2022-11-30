local skynet = require "skynet"
local s = require "service"
local pb = require "protobuf"

s.client={}

s.client.login=function ( fd,msg,source )

	local msgpb = pb.decode("PMPlayer.PBLogin",msg)
	skynet.error("login recv "..msgpb.name.." "..msgpb.pw)
	local playername=msgpb.name
	local pwd = msgpb.pw
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

	return playerInfo
end

s.client.register=function ( fd,msg,source )
	local playername = msg[2]
	local pwd = msg[3]
	local gate = source
	node=skynet.getenv("node")
	local isok,agent,playerid = skynet.call("agentmgr","lua","reqregister",playername,pwd,node,gate)
	if not isok then
		return {"register",1,agent}
	end
	isok=skynet.call(gate,"lua","sure_agent",fd,playerid,agent)
	if not isok then
		return {"register",1,"gate注册失败"}
	end
	skynet.error("register succeed "..playerid)
	return {"register",0,"注册成功"}
end

s.resp.client=function ( source,fd,cmd,msg )
	if s.client[cmd] then
		local ret_msg = s.client[cmd](fd,msg,source)
		skynet.error("login return")
		local ret_pb = pb.encode("PMPlayer.PBPlayerInfo",ret_msg)
		skynet.send(source,"lua","send_by_fd",fd,cmd,ret_pb)
	else
		skynet.error("s.resp.client fail",cmd)
	end
end

function s.init( )
	pb.register_file("./proto/PMPlayer.pb")
end

s.start(...)
