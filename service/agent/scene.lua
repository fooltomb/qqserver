local skynet = require "skynet"
local s = require "service"
local runconfig = require "runconfig"
local mynode = skynet.getenv("node")

s.snode=nil
s.sname=nil

s.resp.enterScene=function ( source,snode,sname )
	s.snode=snode
	s.sname=sname
	s.send(snode,sname,"enter",s.id,mynode,skynet.self())
	--[[
	if not isok then
		skynet.send(s.gate,"lua","send",s.id,{"joinGame",1,"加入游戏失败"})
	else
		skynet.send(s.gate,"lua","send",s.id,{"joinGame",0,"加入游戏开始倒计时"})
	end
	]]
end
--[[
s.client.enter=function ( msg )
	if s.sname then
		return {"enter",1,"already in scene"}
	end
	local snode,sid = random_scene()
	local sname = "scene"..sid
	local isok = s.call(snode,sname,"enter",s.id,mynode,skynet.self())
	if not isok then
		return {"enter",1,"enter scene failed"}
	end
	s.snode=snode
	s.sname=sname
	return nil
end
]]
s.client.shift=function ( msg )
	if not s.sname then
		return
	end
	local x = msg[2] or 0
	local z = msg[3] or 0
	local roty = msg[4] or 0
	s.call(s.snode,s.sname,"shift",s.id,x,z,roty)
end

s.client.eat=function ( msg )
	if not s.sname then
		return
	end
	local foodid = msg[2]
	s.call(s.snode,s.sname,"eat",s.id,foodid)
end


s.leave_scene=function (  )
	if not s.sname then
		return
	end
	s.call(s.snode,s.sname,"leave",s.id)
	s.snode=nil
	s.sname=nil
end