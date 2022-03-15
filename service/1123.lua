local skynet = require "skynet"
local s = require "service"
local socket = require "skynet.socket"
local runconfig = require "runconfig"

local conns = {}
local players = {}

function conn()
    local m = {
        fd = nil,
        playerid = nil,
    }
    return m
end 
function gateplayer()
    local m = {
        playerid = nil,
        agent = nil,
        conn = nil,
    }
    return m
end 

local function str_unpack(msgstr)
    local msg = {}
    while true do 
        local arg,rest = string.match(msgstr,"(.-),(.*)")
        if arg then 
            msgstr = rest
            table.insert( msg,arg)
        else 
            table.insert( msg,msgstr)
            break
        end 
    end 
    return msg[1],msg
end 
local function str_pack  (cmd,msg)
    return table.concat(msg,",").. "\r\n"
end

s.resp.send_by_fd = function (source ,fd,msg ) 
    if not conns[fd] then 
        return 
    end
    local buff = str_pack(msg[1],msg)
    skynet.error("send " .. fd .. " [" .. msg[1] .. "] {" .. table.concat(msg,",") .. "}")
    socket.write(fd,buff) 
end

s.resp.send = function(source , playerid , msg)
    local gplayer = players[playerid]
    if gplayer == nil then
        return
    end
    local c = gplayer.conn
    if c == nil then
       return
    end 
    s.resp.send_by_fd(nil,c.fd,msg)
end
s.resp.sure_agent = function(source,fd,playerid,agent)
    
end 

local function process_msg(fd,msgstr)
    local cmd,msg = str_unpack(msgstr)
    skynet.error("recv "..fd .. "[" .. cmd .. "]{" .. table.concat( msg,",").."}")

    local conn = conns[fd]
    local playerid = conn.playerid
    if not playerid then 
        local node = skynet.getenv("node")
        local nodecfg = runconfig[node]
        local loginid = math.random(1,#nodecfg.login)
        local login = "login" .. loginid
        skynet.send(login,"lua","client",fd,cmd,msg)
    else 
        local gplayer = players[playerid]
        local agent = gplayer.agent;
        skynet.send(agent,"lua","client",cmd,msg)
    end 
end

local function process_buff (fd , readbuff) 
    while true do 
        local msgstr,rest = string.match(readbuff,"(.-)\n\r(.*)")
        if msgstr then 
            readbuff = rest
            process_msg(fd,msgstr)
        else 
            return readbuff
        end 
    end 
end 
local function recv_loop(fd) 
    socket.start(fd)
    skynet.error("socket connected " .. fd )
    local readbuff = ""
    while true do 
        local recvstr = socket.read(fd)
        if recvstr then 
            readbuff = readbuff..recvstr
            readbuff = process_buff(fd,readbuff)
        else 
            skynet.error("skynet close ".. fd)
            disconnect(fd)
            socket.close(fd)
            return
        end 
    end 
end 
local function connect(fd,addr)
    print("connect from " .. addr  .. " " .. fd)
    local c = conn();
    conns[fd] = c;
    c.fd = fd;
    skynet.fork(recv_loop,fd)
end 
function s.init()
    local node = skynet.getenv("node")
    local nodecfg = runconfig[node]
    local port = nodecfg.gateway[s.id].port
    local listnefd = socket.listen("0.0.0.0",port)
    skynet.error("Listen socket :","0.0.0.0",port)
    socket.start(listnefd,connect)
end
s.start(...)