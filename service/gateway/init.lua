local skynet = require "skynet"
local gateserver = require "snax.gateserver"
local s = require "service"
--local socket = require "skynet.socket"
local runconfig = require "runconfig"

--local socketdriver = require "skynet.socketdriver"
--local netpack = require "skynet.netpack"

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
	return m
end

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
}

local handler = {}

function handler.open(source, conf)
	watchdog = conf.watchdog or source
	return conf.address, conf.port
end

function handler.message(fd, msgstr, sz)

	local cmd,msg = str_unpack(msgstr)
	if(cmd~="shift") then
		skynet.error("receive "..fd.."["..cmd.."]|receive msg :{"..table.concat(msg,",").."}")
	end
	local conn=conns[fd]
	local playerID = conn.playerID
	if not playerID then
		local node=skynet.getenv("node")
		local nodecfg = runconfig[node]
		local loginid = math.random(1,#nodecfg.login)
		local login = "login"..loginid
		skynet.send(login,"lua","client",fd,cmd,msg)
	else		
		if cmd=="exit" then
			local isok=skynet.call("agentmgr","lua","reqkick",playerID,"主动退出")
			skynet.error(isok)
		else
			local gplayer = players[playerID]
			local agent = gplayer.agent
			skynet.send(agent,"lua","client",cmd,msg)
		end
	end

	skynet.trash(msg,sz)
end

function handler.connect(fd, addr)
	skynet.error("new connect form "..addr.." "..fd)
	local c = conn()
	conns[fd]=c
	c.fd=fd
end

local function unforward(c)
	if c then
		local isok=skynet.call("agentmgr","lua","reqkick",c.playerID,"主动退出")
		skynet.error(isok)
		skynet.error("这里释放")
	end
end

local function close_fd(fd)
	local c = conns[fd]
	if c then
		unforward(c)
		conns[fd] = nil
	end
end

function handler.disconnect(fd)

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

function handler.error(fd, msg)
	skynet.error("error fd:"..fd.." error:"..err)
end

function handler.warning(fd, size)
	skynet.error("warning fd:"..fd.." size:"..size)
end

local CMD = {}

function CMD.forward(source, fd, client, address)
	local c = assert(conns[fd])
	unforward(c)
	c.client = client or 0
	c.agent = address or source
	gateserver.openclient(fd)
end

function CMD.accept(source, fd)
	local c = assert(connection[fd])
	unforward(c)
	gateserver.openclient(fd)
end

function CMD.kick(source, fd)
	gateserver.closeclient(fd)
end

function handler.command(cmd, source, ...)
	local f = assert(CMD[cmd])
	return f(source, ...)
end

gateserver.start(handler)

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
	return table.concat(msg,",").."|"
end
--[[
local process_msg=function ( fd,msgstr )
	local cmd,msg = str_unpack(msgstr)
	if(cmd~="shift") then
		skynet.error("receive "..fd.."["..cmd.."]|receive msg :{"..table.concat(msg,",").."}")
	end
	local conn=conns[fd]
	local playerID = conn.playerID
	if not playerID then
		local node=skynet.getenv("node")
		local nodecfg = runconfig[node]
		local loginid = math.random(1,#nodecfg.login)
		local login = "login"..loginid
		skynet.send(login,"lua","client",fd,cmd,msg)
	else		
		if cmd=="exit" then
			local isok=skynet.call("agentmgr","lua","reqkick",playerID,"主动退出")
			skynet.error(isok)
		else
			local gplayer = players[playerID]
			local agent = gplayer.agent
			skynet.send(agent,"lua","client",cmd,msg)
		end
	end
end

local process_buff = function ( fd,readbuff )

	while true do
		skynet.error("readbuff:"..string.upper(readbuff))
		local msgstr,rest=string.match(readbuff,"(.-)|(.*)")
		if msgstr then
			readbuff=rest
			--process_msg(fd,msgstr)
			skynet.error("msgstr:"..msgstr)
			skynet.error("rest:"..rest)
		else
			return readbuff
		end
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



local queue
--有新的链接
local process_connect = function ( fd,addr )
	skynet.error("new connect form "..addr.." "..fd)
	local c = conn()
	conns[fd]=c
	c.fd=fd
	socketdriver.start(fd)
end
--关闭连接
local process_close=function ( fd )
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
--发生错误
local process_error=function (fd, err)
    skynet.error("error fd:"..fd.." error:"..err)
end
--发生警告
local process_warning = function ( fd,size )
	skynet.error("warning fd:"..fd.." size:"..size)
end

--处理消息
function process_msg(fd, msg, sz)
    local str = netpack.tostring(msg,sz)
    skynet.error("recv from fd:"..fd .." str:"..str)
end

--收到多于1条消息时
function process_more()
    for fd, msg, sz in netpack.pop, queue do
         skynet.fork(process_msg, fd, msg, sz)
    end
end

function socket_unpack( msg,size )
	return netpack.filter(queue,msg,size)
end

function socket_dispatch ( _,_,q,type,... )
	skynet.error("socket_dispatch type:"..(type or "nil"))
    queue = q
    if type == "open" then
         process_connect(...)
    elseif type == "data" then
         process_msg(...)
    elseif type == "more" then
         process_more(...)   
    elseif type == "close" then
         process_close(...)
    elseif type == "error" then
         process_error(...)
    elseif type == "warning" then
         process_warning(...)
    end
end

function s.init( )
	skynet.error("[start]"..s.name.." "..s.id)
	local node = skynet.getenv("node")
	local nodecfg = runconfig[node]
	local port = nodecfg.gateway[s.id].port
	skynet.error(skynet.proto)
     --注册SOCKET类型消息
    skynet.register_protocol{
        name = "socket",
        id = skynet.PTYPE_SOCKET,
        unpack = socket_unpack,
        dispatch = socket_dispatch
    }
     --开启监听
    local listenfd = socketdriver.listen("0.0.0.0", port)
    skynet.error("listen socket :","0.0.0.0",port)
    socketdriver.start(listenfd)
end



s.resp.send_by_fd=function ( source,fd,msg )
	if not conns[fd] then
		return
	end

	local buff = str_pack(msg[1],msg)
	if(msg[1]~="shift") then
		skynet.error("send "..fd.." ["..msg[1].."] {"..table.concat(msg,",").."}")
	end
	socket.write(fd,buff)
end

s.resp.send=function ( source,playerid,msg )
	local gplayer = players[playerid]
	if gplayer == nil then
		skynet.error("gplayer is nil")
		return
	end
	local c = gplayer.conn
	if c==nil then
		skynet.error("conn is nil")
		return
	end
	s.resp.send_by_fd(nil,c.fd,msg)
	-- body
end

s.resp.sure_agent=function ( source,fd,playerid,agent )
	--skynet.error(agent)
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
	skynet.error("kick player id:"..playerid)
	players[playerid]=nil
	if not c then
		return
	end
	conns[c.fd]=nil
	disconnect(c.fd)
	socket.close(c.fd)
end
--]]
s.resp.open=function (source, ... )
	skynet.error(...)
end
s.start(...)

