local skynet = require "skynet"
local s = require "service"

local rooms = {}--[roomid]=room
local playerRoom = {} --[playerId]=room
local playerAgent = {} --[playerId]=agent

local function GetRoom( roomName )
	local m = {
		id=0,
		name=roomName,
		count=0,
		players={},
		status="ready"
	}
	function m:Join( playerId )
		if(self.count>=8) then
			return false,{"joinRoom",1,"房间已满"}
		end
		self.players[playerId]="Join"
		self.count=self.count+1
		return true,{"joinRoom",0,self.id..":"..self.name}
	end
	function m:Prepare( playerId )
		self.players[playerId]="Ready"
		local readyCount = 0
		for k,v in pairs(self.players) do
			if(v=="Ready") then
				readyCount=readyCount+1
			end
		end
		if readyCount==self.count then
			--to do 
		end
	end
	function m:CancelPrepare( playerId )
		self.players[playerId]="Join"
	end
	function m:Exit( playerId )
		self.players[playerId]=nil
		self.count=self.count-1
		if self.count<=0 then
			--kill room
		end
	end
	return m
end 

s.resp.CreateRoom=function ( source,playerid,agent,roomName )
	local room = GetRoom(roomName[2])
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

s.resp.JoinRoom=function ( source,playerId,roomid,agent )
	local room = rooms[tonumber(roomid)]
	local joinok,ret = room:Join(playerid)
	if joinok then
		playerRoom[playerid]=room
		playerAgent[playerid]=agent
	end
	return ret
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