local skynet=require "skynet"
local cluster=require "skynet.cluster"

local M = {
	name="",
	id="",

	exit=nil,
	init=nil,

	resp={}
}

function traceback( err )
	skynet.error(tostring(err))
	skynet.error(debug.traceback())
end

local dispatch = function ( session,address,cmd,... )
	local fun = M.resp[cmd]
	if not fun then
		skynet.ret()
		return
	end
	local ret = table.pack(xpcall(fun,traceback,address,...))
	local isok = ret[1]
	if not isok then
		skynet.ret()
		return
	end
	skynet.retpack(table.unpack(ret,2))
end

function init(  )
	skynet.dispatch("lua",dispatch)
	if M.init then
		M.init()
	end
end

function M.call( node,srv,... )
	local mynode = skynet.getenv("node")
	if node==mynode then
		return skynet.call(srv,"lua",...)
	else
		return cluster.call(node,srv,...)
	end	
end

function M.send( node,src,... )
	local mynode = skynet.getenv("node")
	if node==mynode then
		return skynet.send(srv,"lua",...)
	else
		return cluster.send(node,srv,...)
	end
end

function M.start( name,id,... )
	M.name=name
	M.id=id
	skynet.start(init)
end

return M