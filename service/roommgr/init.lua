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
			--to do 
		end
		return false
	end
	function m:CancelPrepare( playerName )
		self.players[playerName]="Join"
	end
	function m:Exit( playerName )
		if(self.players[playerName]=="Ready") then
			self.readyCount=self.readyCount-1
		end
		self.players[playerName]=nil
		self.count=self.count-1
		if self.count<=0 then
			--kill room
		end
		return false
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
	end
end

s.resp.Exit=function ( source,playerName )
	local room = playerRoom[playerName]
	if(room==nil) then
		return
	end
	local isok = room:Exit(playerName)
	if not isok then
		local playerState = ""
		for k,v in pairs(room.players) do
			playerState=playerState..k..":"..v..";"
		end
		for k,v in pairs(room.players) do
			skynet.send(playerAgent[k],"lua","send",{"roomPlayer",0,playerState})
		end
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