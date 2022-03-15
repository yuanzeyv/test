local skynet = require "skynet"
local runconfig = require "runconfig"
local networkDef = require "networkDef"
skynet.start(function() 
    local nodeName = skynet.getenv("node")
    --首先创建配置列表中对应的 分发通道
    local nodeInfo = runconfig[nodeName]
    if nodeInfo == nil then 
        skynet.exit()
        return 
    end 
    skynet.error("GHAHA")
    --创建固定数目的消息通道
    for v,k in pairs(nodeInfo.gateway) do 
        skynet.newservice("gateway","gateway",k.port) --传入待使用的路由
    end 
    networkDef.
end)