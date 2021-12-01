local skynet = require "skynet"
local s = require "service"
local mysql = require "skynet.db.mysql"

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
--database
local db = nil

s.resp.reqregister=function ( source,playername,pwd,node,gate)
	-- body
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
	player.agent=agent
	player.status=STATUS.GAME
	return true,agent
end

s.resp.reqkick=function ( source,playerid,reason )
	local mplayer = players[playerid]
	if not mplayer then
		skynet.error("mplayer is nil")
		return false
	end
	skynet.error("player STATUS:"..mplayer.status)
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

s.init=function (  )
	db=mysql.connect({
		host="127.0.0.1",
		port="3306",
		user="root",
		password="123456",
		database="beanfight",
		max_packet_size=1024*1024,
		on_connect=nil
	})
	local res = db:query("select * form player")
	for k,v in pairs(res) do
		print(k,v.id,v.name,v.password)
	end
end

s.start(...)