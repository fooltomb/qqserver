local skynet = require "skynet"
local s = require "service"
local socket = require "skynet.socket"
local runconfig = require "runconfig"

conns={}--[fd]=conn
players={}--[playerID]=gatePlayer

function conn(  )
	local m={
		fd=nil,
		playerID=nil
	}
	return m
end

function gatePlayer(  )
	local m={
		playerID=nil,
		agent=nil,
		conn=nil
	} 
end


local str_unpack = function ( msgstr )
	local msg = {}
	while true do
		local arg,rest = string.match(msgstr,"(.-),(.*)")
		if arg then
			msgstr = rest
			table.insert(msg,arg)
		else
			table.insert(msg,msgstr)
			break
		end
	end
	return msg[1],msg
end

local str_pack = function ( cmd,msg )
	return table.concat(msg,",").."\r\n"
end

local process_msg=function ( fd,msgstr )
	local cmd,msg = str_unpack(msgstr)
	skynet.error("receive "..fd.."["..cmd.."]|receive msg :{"..table.concat(msg,",").."}")

	local conn=conns[fd]
	local playerID = conn.playerID

	if not playerID then
		local node=skynet.getenv("node")
		local nodecfg = runconfig[node]
		local loginid = math.random(1,#nodecfg.login)
		local login = "login"..loginid
		skynet.send(login,"lua","client",fd,cmd,msg)
	else
		local gplayer = players[playerID]
		local agent = gplayer.agent
		skynet.send(agent,"lua","client",cmd,msg)
	end
end

local process_buff = function ( fd,readbuff )
	while true do
		local msgstr,rest=string.match(readbuff,"(.-)\r\n(.*)")
		if msgstr then
			readbuff=rest
			process_msg(fd,msgstr)
		else
			return readbuff
		end
	end
end

local disconnect=function ( fd )
	local c = conns[fd]
	if not c then
		return
	end

	local playerid=c.playerID

	if not playerid then
		return
	else
		players[playerid]=nil
		local reason = "断线"
		skynet.call("agentmgr","lua","reqkick",playerid,reason)
	end
end

local recv_loop = function ( fd )
	socket.start(fd)
	skynet.error("socket connected "..fd)
	local readbuff = ""
	while true do
		local recvstr = socket.read(fd)
		if recvstr then
			readbuff=readbuff..recvstr
			readbuff=process_buff(fd,readbuff)
		else
			skynet.error("socket close "..fd)
			disconnect(fd)
			socket.close(fd)
			return
		end
	end
end

local connect = function ( fd,addr )
	print("connect form "..addr.." "..fd)
	local c = conn()
	conns[fd]=c
	c.fd=fd
	skynet.fork(recv_loop,fd)
end

function s.init(  )
	skynet.error("[start]"..s.name.." "..s.id)
	local node = skynet.getenv("node")
	local nodecfg = runconfig[node]
	local port = nodecfg.gateway[s.id].port
	print(port)
	local listenfd = socket.listen("0.0.0.0",port)
	skynet.error("listen socket :","0.0.0.0",port)
	socket.start(listenfd,connect)
end

s.start(...)

s.resp.send_by_fd=function ( source,fd,msg )
	if not conns[fd] then
		return
	end

	local buff = str_pack(msg[1],msg)
	skynet.error("send "..fd.." ["..msg[1].."] {"..table.concat(msg,",").."}")
	socket.write(fd,buff)
end

s.resp.send=function ( source,playerid,msg )
	local gplayer = players[playerid]
	if gplayer == nil then
		return
	end
	local c = gplayer.conn
	if c==nil then
		return
	end
	s.resp.send_by_fd(nil,c.fd,msg)
	-- body
end

s.resp.sure_agent=function ( source,fd,playerid,agent )
	local conn = conns[fd]
	if not conn then
		skynet.call("agentmgr","lua","reqkick",playerid,"未完成登陆即下线")
		return false
	end
	conn.playerID=playerid

	local gplayer = gatePlayer()
	gplayer.playerID=playerid
	gplayer.agent=agent
	gplayer.conn=conn
	players[playerid]=gplayer
	return true
end

s.resp.kick=function ( source,playerid )
	local gplayer = players[playerid]
	if not gplayer then
		return
	end
	local c = gplayer.conn
	players[playerid]=nil
	if not c then
		return
	end
	conns[c.fd]=nil
	disconnect(c.fd)
	socket.close(c.fd)
end

