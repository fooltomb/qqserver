local skynet = require "skynet"
local s = require "service"
local mynode = skynet.getenv("node")

s.client={}
s.gate=nil
s.aplayer={
	name="",
	id=0,
	kill=0,
	death=0,
	win=0,
	score=0,
	match=0
}

require "scene"

s.resp.client=function ( source,cmd,msg )
	s.gate=source
	if s.client[cmd] then
		local ret_msg = s.client[cmd](msg)
		if ret_msg then
			--skynet.error("agent id in agent:"..s.id)
			skynet.send(source,"lua","send",s.aplayer.id,cmd,ret_msg)
		end
	else
		skynet.error("s.resp.client fail ",cmd)
	end
end

s.resp.send=function ( source,cmd,msg )
	skynet.send(s.gate,"lua","send",s.id,cmd,msg)
end

s.init=function (  )
	--skynet.sleep(200)
	s.data={
		coin=100,
		hp=200
	}
end

s.resp.kick=function ( source )
	skynet.error("im kicked")
	skynet.send("roommgr","lua","Exit",s.aplayer.name)
	s.leave_scene()
	skynet.sleep(100)

end

s.resp.getNode=function ( source )
	return mynode
end

s.resp.exit=function ( source )
	skynet.exit()
end

s.client.work=function ( msg )
	skynet.error("working.."..#msg)
	s.data.coin=s.data.coin+1
	return {"work",s.data.coin}
end
s.client.setPlayer=function ( playerInfo )
	s.aplayer.name=playerInfo.name
	s.aplayer.kill=playerInfo.kill
	s.aplayer.death=playerInfo.death
	s.aplayer.score=playerInfo.score
	s.aplayer.match=playerInfo.match
	s.aplayer.id=playerInfo.id
	--s.aplayer.name,s.aplayer.kill,s.aplayer.death,s.aplayer.win,s.aplayer.score,s.aplayer.match=skynet.call("agentmgr","lua","getPlayerInfo",s.id)
	--return {"playerInfo",0,string.format("%s;%d;%d;%d;%d;%d;%d",s.aplayer.name,s.aplayer.kill,s.aplayer.death,s.aplayer.win,s.aplayer.score,s.aplayer.match,s.id)}
	return
end
s.client.getRooms=function ( msg )
	--skynet.error(msg)
	return skynet.call("roommgr","lua","GetRoomList")
end

s.client.createRoom=function ( msg )
	return skynet.call("roommgr","lua","CreateRoom",msg,s.aplayer.name)
end

s.client.joinRoom=function ( msg )
	--skynet.error("s.id is:"..s.id)
	return skynet.call("roommgr","lua","JoinRoom",s.aplayer.name,msg[2],skynet.self())
end

s.client.prepareGame=function ( msg )
	skynet.send("roommgr","lua","Prepare",s.aplayer.name)
end

s.start(...)