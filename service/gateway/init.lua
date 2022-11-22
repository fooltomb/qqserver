local skynet = require "skynet"
local s = require "service"
local socket = require "skynet.socket"
local runconfig = require "runconfig"

--local netpack = require "skynet.netpack"
local pb=require "protobuf"

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
		conn=nil,
		lost_conn_time=nil,
		msgcache={}
	}
	return m
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
	return table.concat(msg,",").."|"
end

local process_msg=function ( fd,cmd,msgpb )

	local umsg = pb.decode("login.Login",msgpb)

	if umsg then
		skynet.error("id:"..umsg.id)
		skynet.error("pw:"..umsg.pw)
	else
		skynet.error("error")
	end
	--[[
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
	--]]
end


local process_buff = function ( fd,readbuff )
	local bufflen = string.len(readbuff)
	if bufflen<5 then
		return readbuff
	local formatStr = string.format("> i2 i2 c%d",bufflen-4)
	local msglen,namelen,other=string.unpack(formatStr,readbuff)
	if bufflen<msglen+2 then
		return readbuff
	formatStr = string.format("> c%d c%d c%d",namelen,msglen-namelen-2,bufflen-msglen-2)
	local cmd,msgpb,rest = string.unpack(formatStr,other)
	process_msg(fd,cmd,msgpb)
	return rest
--[[
	while true do
		skynet.error("readbuff:"..#readbuff.."type:"..type(readbuff))

		local umsg = pb.decode("login.Login",readbuff)

		if umsg then
			skynet.error("id:"..umsg.id)
			skynet.error("pw:"..umsg.pw)
		else
			skynet.error("error")
		end

		local msgstr = string.sub(readbuff,1,2)
		skynet.error(msgstr)
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
	--]]
end

local disconnect = function(fd)
    local c = conns[fd]
    if not c then
        return
    end

    local playerid = c.playerid
    --还没完成登录
    if not playerid then
        return
    --已在游戏中
    else
        local gplayer = players[playerid]
        gplayer.conn = nil --  players[playerid] = nil
        skynet.timeout(30*100, function()
            if gplayer.conn ~= nil then
                return
            end
            local reason = "断线超时"
            skynet.call("agentmgr", "lua", "reqkick", playerid, reason)
        end)
        
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


local process_reconnect = function(fd, msg)
    local playerid = tonumber(msg[2])
    local key = tonumber(msg[3])
    --conn
    local conn = conns[fd]
    if not conn then
        skynet.error("reconnect fail, conn not exist")
        return
    end   
    --gplayer
    local gplayer = players[playerid]
    if not gplayer then
        skynet.error("reconnect fail, player not exist")
        return
    end
    if gplayer.conn then
        skynet.error("reconnect fail, conn not break")
        return
    end
    if gplayer.key ~= key then
        skynet.error("reconnect fail, key error")
        return
    end
    --绑定
    gplayer.conn = conn
    conn.playerid = playerid
    --回应
    s.resp.send_by_fd(nil, fd, {"reconnect", 0})
    --发送缓存消息
    for i, cmsg in ipairs(gplayer.msgcache) do
        s.resp.send_by_fd(nil, fd, cmsg)
    end
    gplayer.msgcache = {}
end

local connect = function(fd, addr)
    if closing then
        return
    end
    skynet.error("connect from " .. addr .. " " .. fd)
	local c = conn()
    conns[fd] = c
    c.fd = fd
    skynet.fork(recv_loop, fd)
end

function s.init( )
	skynet.error("[start]"..s.name.." "..s.id)
	local node = skynet.getenv("node")
	local nodecfg = runconfig[node]
	local port = nodecfg.gateway[s.id].port

	pb.register_file("./proto/login.pb")

    local listenfd = socket.listen("0.0.0.0", port)
    skynet.error("listen socket :","0.0.0.0",port)
    socket.start(listenfd,connect)
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

s.start(...)

