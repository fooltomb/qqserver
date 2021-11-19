local skynet = require "skynet"
skynet.start(function (  )
	skynet.error("[start main]")
	skynet.newservice("gateway","gateway",1)
	skynet.exit()
end)