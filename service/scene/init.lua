local skynet = require "skynet"
local s = require "service"

local balls={}--[playerid]=ball
local playerCount = 0 --玩家数量
local playerIndex = 0 --玩家加入顺序

local randomX = {}
local randomZ = {}

function ball(  )--每个玩家控制一个ball
	local m = {
		playerid=nil,
		node=nil,
		agent=nil,
		x=0,
		z=0,
		health=0,
		rotY=0
	}
	return m
end

local function balllist_msg(  )
	local msg = {"balllist"}
	for i,v in pairs(balls) do
		table.insert(msg,v.playerid)
		table.insert(msg,v.x)
		table.insert(msg,v.z)
		table.insert(msg,v.size)
	end
	return msg
end 

local foods = {}--[id]=food
local food_maxid = 0
local food_count = 0

function food(  )
	local m = {
		id=nil,
		x=math.random(0,100),
		z=math.random(0,100)
	}
	return m
end

local function foodlist_msg(  )
	local msg = {"foodlist"}
	for i,v in pairs(foods) do
		table.insert(msg,v.id)
		table.insert(msg,v.x)
		table.insert(msg,v.z)
	end
	return msg
end 

local walls = {}--[id]=wall
local wall_count = 0

function wall( index )
	if walls[index]~=nil then
		return walls[index]
	end
	local m = {
		id=nil,
		rotateY=math.random(0,1),
		x=randomX[index],
		z=randomZ[index]
	}
	return m
end

local function walllist_msg(  )
	msg = ""
	for i,v in pairs(walls) do
		msg=msg..string.format("%d:%d:%d:%d;",i,v.rotateY,v.x,v.z)
	end
	return {"walllist",0,msg}
end

function broadcast( msg )
	for i,v in pairs(balls) do
		s.send(v.node,v.agent,"send",msg)
	end
end

s.resp.setPlayerCount=function ( source,count )
	skynet.error("The scene player count is "..count)
	playerCount=count
end

s.resp.enter=function ( source,playerid,node,agent )
	if balls[playerid] then
		return false
	end
	playerIndex=playerIndex+1
	local b = ball()
	b.x=randomX[playerIndex]
	b.z=randomZ[playerIndex]
	b.playerid=playerid
	b.node=node
	b.agent=agent
	--
	local entermsg = {"joinGame",0,playerid..";"..b.x..";"..b.z..";"..b.rotY}
	s.send(b.node,b.agent,"send",walllist_msg())
	balls[playerid]=b
	broadcast(entermsg)

	if(playerIndex==playerCount) then
		skynet.sleep(300)
		broadcast({"startGame",0,0})
		skynet.fork(function ()
		--
			local stime = skynet.now()
			local frame = 0
			while true do
				frame = frame + 1
				local isok,err = pcall(update,frame)
				if not isok then
					skynet.error(err)
				end
				local etime = skynet.now()
				local waittime = frame*20 - (etime-stime)
				if waittime<=0 then
					waittime=2
				end
				skynet.sleep(waittime)
			end
		end)
	end
	
--[[
	
	local ret_msg = {"enter",0,"进入成功"}
	s.send(b.node,b.agent,"send",ret_msg)
	s.send(b.node,b.agent,"send",balllist_msg())
	s.send(b.node,b.agent,"send",foodlist_msg())
	return true
]]
end

s.resp.leave=function ( source,playerid )
	if not balls[playerid] then
		return false
	end
	balls[playerid]=nil
	local leavemsg={"leave",playerid}
	broadcast(leavemsg)
end

s.resp.shift=function ( source,playerid,x,z,rotY )
	local b = balls[playerid]
	if not b then
		return false
	end
	b.x=x
	b.z=z
	b.rotY=rotY
end

function update( frame )
	food_update()
	move_update()
	--eat_update()
end

function move_update()
	local msg = ""
	for i,v in pairs(balls) do
		--skynet.error(v.x)
		msg=msg..string.format("%d:%f:%f:%f;",i,v.x,v.z,v.rotY)
	end
	broadcast({"shift",0,msg})
end

function food_update()
	if food_count > 50 then
		return
	end
	if math.random(1,100)<95 then
		return
	end
	food_maxid=food_maxid+1
	food_count=food_count+1
	local f = food()
	f.id=food_maxid
	foods[f.id]=f
	local msg={"addfood",0,string.format("%d;%d;%d",f.id,f.x,f.z)}
	broadcast(msg)
end

function eat_update()
	for pid,b in pairs(balls) do
		for fid,f in pairs(foods) do
			if(b.x-f.x)^2 + (b.z-f.z)^2<b.size^2 then
				b.size=b.size +1
				food_count=food_count-1
				local msg = {"eat",b.playerid,fid,b.size}
				broadcast(msg)
				food[fid]=nil
			end
		end
	end
end

s.init=function ()
	math.randomseed(os.time())
	for i=0,96,4 do
		table.insert(randomX,i)
		table.insert(randomZ,i)
	end
	for i=25,1,-1 do
		local index = math.random(1,i)
		randomX[index],randomX[i]=randomX[i],randomX[index]
		index=math.random(1,i)
		randomZ[index],randomZ[i]=randomZ[i],randomZ[index]
	end
	for i=1,25,1 do
		walls[i]=wall(i)
	end
	

end

s.start(...)