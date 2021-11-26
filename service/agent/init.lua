local skynet = require "skynet"
local s = require "service"

s.client={}
s.gate=nil

s.resp.client=function ( source,cmd,msg )
	s.gate=source
	if s.client[cmd] then
		local ret_msg = s.client[cmd](msg,source)
		if ret_msg then
			skynet.send(source,"lua","send",s.id,ret_msg)
		end
	else
		skynet.error("s.resp.client fail ",cmd)
	end
end

s.init=function (  )
	skynet.sleep(200)
	s.data={
		coin=100,
		hp=200
	}
end

s.resp.kick=function ( source )
	skynet.sleep(200)
end

s.resp.exit=function ( source )
	skynet.exit()
end

s.client.work=function ( msg )
	skynet.error("working.."..msg)
	s.data.coin=s.data.coin+1
	return {"work",s.data.coin}
end

s.start(...)