local skynet = require "skynet"
local s = require "service"

s.client={}

s.client.login=function ( fd,msg,source )
	skynet.error("login recv "..msg[1].." "..msg[2])
	return {"login",-1,"测试"}
end

s.resp.client=function ( source,fd,cmd,msg )
	if s.client[cmd] then
		local ret_msg = s.client[cmd](fd,msg,source)
		skynet.send(source,"lua","send_by_fd",fd,ret_msg)
	else
		skynet.error("s.resp.client fail",cmd)
	end
end

s.start(...)