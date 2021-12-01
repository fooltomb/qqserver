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

local function dump( res,tab )
	tab=tab or 0
	if(tab==0)then
		skynet.error("........dump..........")
	end
	if type(res)=="table" then
		skynet.error(string.rep("\t",tab).."{")
		for k,v in pairs(res) do
			if type(v)=="table" then
				dump(v,tab+1)
			else
				skynet.error(string.rep("\t",tab),k,"=",v,",")
			end
		end
		skynet.error(string.rep("\t",tab).."}")
	else
		skynet.error(string.rep("\t",tab),res)
	end
end 

s.resp.reqregister=function ( source,playername,pwd,node,gate)
	--todo 防注入
	local res,err = db:query(string.format("insert into 'player' ('name','password') values(%s,%s)",playername,pwd))
	dump(res)
end

s.resp.reqlogin=function ( source,playerid,node,gate )
	--todo 防注入
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
end

s.start(...)