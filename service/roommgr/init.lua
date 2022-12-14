local skynet = require "skynet"
local s = require "service"
local cjson = require "cjson"

local rooms = {}--[roomid]=room
local playerRoom = {} --[playerName]=room
local playerAgent = {} --[playerName]=agent

local function GetRoom( roomName ,pw,creater,roomSize)
	local m = {
		id=0,
		name=roomName,
		size=tonumber(roomSize),
		creater=creater,
		pw=pw,
		readyCount=0,
		joinCount=0,
		players={},
		status="ready"
	}
	function m:Join( playerName )
		if(self.joinCount>=self.size) then
			return false,{"joinRoom",1,"房间已满"}
		end
		--self.players[playerName]="Join"
		table.insert(self.players,{name=playerName,status="Join"})
		self.joinCount=self.joinCount+1
		return true,{"joinRoom",0,self.id..":"..self.name}
	end
	function m:Prepare( playerName )
		for k,v in pairs(self.players) do
			if (v.name==playerName) then
				v.status="Ready"
			end
		end
		--self.players[playerName]="Ready"
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

s.resp.CreateRoom=function ( source,msg,playerName,size)
	local msgjson = cjson.decode(msg)
	local room = GetRoom(msgjson.name,msgjson.pw,playerName,msgjson.size)
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
		room.id=-1
	end
	isok=room:Join(playerName)
	if not isok then
		room.id=-1
	else
		playerRoom[playerName]=room
		playerAgent[playerName]=source
	end
	local roomjson = {
		id=room.id,
		name=room.name,
		size=room.size,
		creater=creater,
		pw=room.pw,
		players=room.players
	}

	return cjson.encode(roomjson)
end

s.resp.JoinRoom=function ( source,playerName,roomid,agent )
	local room = rooms[tonumber(roomid)]
	local joinok,ret = room:Join(playerName)
	if joinok then
		playerRoom[playerName]=room
		playerAgent[playerName]=agent
	end

	local playerState = {name=playerName,status="Exit"}

	for k,v in pairs(room.players) do
		skynet.send(playerAgent[k],"lua","send","roomPlayer",playerState)
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
		--skynet.error(maxNode)
		s.call(maxNode,"scenemgr","createScene",room.id,room.count)
		for k,v in pairs(room.players) do
			skynet.send(playerAgent[k],"lua","enterScene",maxNode,"scene"..room.id)
		end
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
	for k,v in pairs(rooms) do
		local roomInfo = {}
		roomInfo.id=v.id
		roomInfo.name=v.name
		roomInfo.creater=v.creater
		roomInfo.pw=v.pw
		roomInfo.size=v.size
		roomInfo.players=v.players

		local ret_json = cjson.encode(roomInfo)
		--skynet.error("send room list:"..ret_json)
		skynet.send(source,"lua","send","getRooms",ret_json)
	end
	return 
end

function s.init( )
	--pb.register_file("./proto/PMRoom.pb")
	skynet.error("create test room")
	local room = GetRoom("TestRoom","ttt","testPlayer",5)
	rooms[2]=room;
	room.id=2
	room:Join("testPlayer")
end

s.start(...)