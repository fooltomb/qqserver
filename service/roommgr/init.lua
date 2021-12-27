local skynet = require "skynet"
local s = require "service"

local rooms = {}--[roomid]=room
local playerRoom = {} --[playerName]=room
local playerAgent = {} --[playerName]=agent

local function GetRoom( roomName )
	local m = {
		id=0,
		name=roomName,
		count=0,
		readyCount=0,
		players={},
		status="ready"
	}
	function m:Join( playerName )
		if(self.count>=8) then
			return false,{"joinRoom",1,"房间已满"}
		end
		self.players[playerName]="Join"
		self.count=self.count+1
		return true,{"joinRoom",0,self.id..":"..self.name}
	end
	function m:Prepare( playerName )
		self.players[playerName]="Ready"
		self.readyCount=self.readyCount+1
		if self.readyCount==self.count then
			return true --玩家全部就绪可以开始游戏
		else
			return false
		end
	end

	function m:Exit( playerName )
		if(self.players[playerName]=="Ready") then
			self.readyCount=self.readyCount-1
		end
		self.players[playerName]=nil
		self.count=self.count-1
		if self.count<=0 then
			return true,self.id --玩家全部离开可以销毁房间
		else
			return false,self.id
		end
	end
	return m
end 

s.resp.CreateRoom=function ( source,roomName )
	local room = GetRoom(roomName)
	local isok=false
	for i=1,100 do
		if rooms[i]==nil then
			room.id=i
			rooms[i]=room
			isok = true
			break
		end
	end
	if not isok then 
		return {"room",1,"房间数量已达上限"}
	else
		return {"room",0,room.id}
	end
	--[[

	--]]
end

s.resp.JoinRoom=function ( source,playerName,roomid,agent )
	local room = rooms[tonumber(roomid)]
	local joinok,ret = room:Join(playerName)
	if joinok then
		playerRoom[playerName]=room
		playerAgent[playerName]=agent
	end
	local playerState = ""
	for k,v in pairs(room.players) do
		playerState=playerState..k..":"..v..";"
	end
	for k,v in pairs(room.players) do
		skynet.send(playerAgent[k],"lua","send",{"roomPlayer",0,playerState})
	end
	return ret
end

s.resp.Prepare=function ( source,playerName )
	local room = playerRoom[playerName]
	local isok=room:Prepare(playerName)
	if not isok then
		local playerState = ""
		for k,v in pairs(room.players) do
			playerState=playerState..k..":"..v..";"
		end
		for k,v in pairs(room.players) do
			skynet.send(playerAgent[k],"lua","send",{"roomPlayer",0,playerState})
		end
	else
		local nodes = {}
		local maxNode = ""
		for k,v in pairs(room.players) do
			local node = skynet.call(playerAgent[k],"lua","getNode")
			if(nodes[node]==nil) then
				nodes[node]=1
			else
				nodes[node]=nodes[node]+1
			end
			if maxNode=="" then
				maxNode=node
			else
				if nodes[node]>nodes[maxNode] then
					maxNode=node
				end
			end
		end
		skynet.error(maxNode)
		s.call(maxNode,"scenemgr","lua","createScene")
		--通过scenemgr新建一个scene.返回sceneNode和sceneName
		--给agent广播让他们加入scene
	end
end

s.resp.Exit=function ( source,playerName )
	local room = playerRoom[playerName]
	if(room==nil) then
		return
	end
	local isok,roomid = room:Exit(playerName)
	if not isok then
		local playerState = ""
		for k,v in pairs(room.players) do
			playerState=playerState..k..":"..v..";"
		end
		for k,v in pairs(room.players) do
			skynet.send(playerAgent[k],"lua","send",{"roomPlayer",0,playerState})
		end
	else
		rooms[roomid]=nil
	end
	playerRoom[playerName]=nil
	playerAgent[playerName]=nil
end

s.resp.GetRoomList=function ( source )
	--skynet.error("roomMgr Get RoomList")
	local msg = ""
	for k,v in pairs(rooms) do
		msg=msg..v.id..":"..v.name..";"
	end
	return {"roomList",0,msg}
end

s.start(...)