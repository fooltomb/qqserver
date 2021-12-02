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
	local request = string.format("insert into player (name,password) values(\'%s\',\'%s\')",playername,pwd)
	--print(request)
	local res= db:query(request)
	if not res.badresult then
		local playerid = res.insert_id
		local loginok,agent = s.resp.login(source,playerid,node,gate)
		return loginok,agent,playerid
	else
		return false,"改用户名已被注册"
	end
end

s.resp.reqlogin=function ( source,playername,pwd,nod,gate )
	local request = string.format("select * from player where name=%s",playername)
	local res = db:query(request)
	dump(res)
	return false,"测试"
end

s.resp.login=function ( source,playerid,node,gate )
	--todo 防注入
	local mplayer = players[playerid]
	if mplayer and mplayer.status==STATUS.LOGOUT then
		skynet.error("reqlogin fail,at status LOGOUT "..playerid)
		return false,"该用户正在登出，请稍后尝试"
	end
	if mplayer and mplayer.status == STATUS.LOGIN then
		skynet.error("reqlogin fail,at status LOGIN "..playerid)
		return false,"该用户正在其他地点登陆，请稍后尝试"
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