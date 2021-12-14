local skynet = require "skynet"
local s = require "service"

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
		local ret_msg = s.client[cmd](msg,source)
		if ret_msg then
			skynet.error("agent id in agent:"..s.id)
			skynet.send(source,"lua","send",s.id,ret_msg)
		end
	else
		skynet.error("s.resp.client fail ",cmd)
	end
end

s.resp.send=function ( source,msg )
	skynet.send(s.gate,"lua","send",s.id,msg)
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
	s.leave_scene()
	skynet.sleep(200)

end

s.resp.exit=function ( source )
	skynet.exit()
end

s.client.work=function ( msg )
	skynet.error("working.."..#msg)
	s.data.coin=s.data.coin+1
	return {"work",s.data.coin}
end
s.resp.client.setPlayer=function ( source )
	--s.aplayer.name,s.aplayer.kill,s.aplayer.death,s.aplayer.win,s.aplayer.score,s.aplayer.match=
	skynet.call("agentmgr","lua","getPlayerInfo",s.id)
end

s.client.CreateRoom=function ( msg )
	return skynet.call("roommgr","lua","CreateRoom",s.id,skynet.self(),msg)
end

s.client.GetRoomList=function ( msg )
	return skynet.call("roommgr","lua","GetRoomList",msg)
end

s.start(...)