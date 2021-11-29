local skynet = require "skynet"
local s = require "service"

STATUS={
	LOGIN=1,
	GAME=2,
	LOGOUT=3
}

--玩家列表
local players = {}
--玩家类
function mgrplayer(  )
	local m ={
		playerid=nil,
		node=nil,
		agent=nil,
		status=nil,
		gate=nil
	}
	return m
end

s.resp.reqlogin=function ( source,playerid,node,gate )
	local mplayer = players[playerid]
	if mplayer and mplayer.status==STATUS.LOGOUT then
		skynet.error("reqlogin fail,at status LOGOUT "..playerid)
		return false
	end
	if mplayer and mplayer.status == STATUS.LOGIN then
		skynet.error("reqlogin fail,at status LOGIN "..playerid)
		return false
	end
	-- 顶替
	if mplayer then
		local pnode = mplayer.node
		local pagent = mplayer.agent
		local pgate = mplayer.gate
		mplayer.status=STATUS.LOGOUT
		s.call(pnode,pagent,"kick")
		s.send(pnode,pagent,"exit")
		s.send(pnode,pgate,"send",playerid,{"kick","顶替下线"})
		s.call(pnode,pgate,"kick",playerid)
	end
	--skynet.error("login here")
	--上线
	local player = mgrplayer()
	player.playerid = playerid
	player.node=node
	player.gate=gate
	player.status=STATUS.LOGIN
	players[playerid]=player
	local agent = s.call(node,"nodemgr","newservice","agent","agent",playerid)
	skynet.error("agent id is :"..s.id)
	player.agent=agent
	player.STATUS=STATUS.GAME
	return true,agent
end

s.resp.reqkick=function ( source,playerid,reason )
	local mplayer = players[playerid]
	if not mplayer then
		return false
	end
	if mplayer.status~=STATUS.GAME then
		return false
	end
	local pnode = mplayer.node
	local pagent = mplayer.agent
	local pgate = mplayer.gate
	mplayer.status=STATUS.LOGOUT
	s.call(pnode,pagent,"kick")
	s.send(pnode,pagent,"exit")
	s.send(pnode,pgate,"kick",playerid)
	players[playerid]=nil
	return true

end

s.start(...)