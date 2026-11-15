-- ============================================================================
-- PROXY NET API (Queue Management & Packet Helpers)
-- Save as: apis/proxy_net.lua
-- ============================================================================

local proxy_net = {}

local outboundQueue = {}   -- [msgId] = { recipient, packet, attempts, timerId }
local responseQueue = {}   -- [msgId] = { recipient, packet, attempts, timerId, isLocal }

function proxy_net.loadQueues()
    if fs.exists("data/queue.dat") then
        local f = fs.open("data/queue.dat", "r")
        local saved = textutils.unserialize(f.readAll())
        f.close()
        if type(saved) == "table" then
            for id, item in pairs(saved) do
                item.timerId = os.startTimer(3)
                outboundQueue[id] = item
            end
            print("[Persistent] Restored request queue.")
        end
    end

    if fs.exists("data/response_queue.dat") then
        local f = fs.open("data/response_queue.dat", "r")
        local saved = textutils.unserialize(f.readAll())
        f.close()
        if type(saved) == "table" then
            for id, item in pairs(saved) do
                item.timerId = os.startTimer(3)
                responseQueue[id] = item
            end
            print("[Persistent] Restored response queue.")
        end
    end
end

function proxy_net.saveQueues()
    local cReq = {}
    for id, item in pairs(outboundQueue) do
        cReq[id] = { recipient = item.recipient, packet = item.packet, attempts = item.attempts }
    end
    local f = fs.open("data/queue.dat", "w")
    f.write(textutils.serialize(cReq))
    f.close()

    local cRes = {}
    for id, item in pairs(responseQueue) do
        cRes[id] = { recipient = item.recipient, packet = item.packet, attempts = item.attempts, isLocal = item.isLocal }
    end
    local f2 = fs.open("data/response_queue.dat", "w")
    f2.write(textutils.serialize(cRes))
    f2.close()
end

function proxy_net.saveConfig(MY_DIMENSION, monitorComputerId, craftingComputerId)
    local cfg = { dimension = MY_DIMENSION, monitorId = monitorComputerId, craftingId = craftingComputerId }
    local f = fs.open("data/config.dat", "w")
    f.write(textutils.serialize(cfg))
    f.close()
end

function proxy_net.sendCrossDimPacket(recipientProxyId, flatPayload, originalQueryId, MY_DIMENSION, PROXY_PROTOCOL)
    local msgId = string.format("%s_req_%d_%d", MY_DIMENSION, os.epoch("local"), math.random(100, 999))
    local packet = {
        id = msgId,
        sourceQueryId = originalQueryId,
        senderDim = MY_DIMENSION,
        type = flatPayload.type,
        targetProxyId = flatPayload.targetProxyId,
        sourceProxyId = flatPayload.sourceProxyId or os.computerID(),
        item = flatPayload.item,
        batchSize = flatPayload.batchSize,
        requestingDim = flatPayload.requestingDim,
        available = flatPayload.available,
        required = flatPayload.required
    }
    
    print(string.format("[Gateway Out] Dispatching flat request %s to proxy ID %d", msgId, recipientProxyId))
    rednet.send(recipientProxyId, packet, PROXY_PROTOCOL)
    
    outboundQueue[msgId] = {
        recipient = recipientProxyId,
        packet = packet,
        attempts = 1,
        timerId = os.startTimer(3)
    }
    proxy_net.saveQueues()
end

function proxy_net.sendResponsePacket(recipientId, flatPayload, originalQueryId, isLocal, MY_DIMENSION, PROXY_PROTOCOL, LOCAL_PROTOCOL)
    local msgId = string.format("%s_res_%d_%d", MY_DIMENSION, os.epoch("local"), math.random(100, 999))
    local packet = {
        id = msgId,
        sourceQueryId = originalQueryId,
        senderDim = MY_DIMENSION,
        type = flatPayload.type,
        targetProxyId = flatPayload.targetProxyId,
        sourceProxyId = flatPayload.sourceProxyId or os.computerID(),
        item = flatPayload.item,
        batchSize = flatPayload.batchSize,
        requestingDim = flatPayload.requestingDim,
        available = flatPayload.available,
        required = flatPayload.required,
        data = flatPayload.data
    }
    
    local protocol = isLocal and LOCAL_PROTOCOL or PROXY_PROTOCOL
    print(string.format("[Gateway Response] Sending flat result %s to %s ID %d", msgId, isLocal and "local client" or "proxy", recipientId))
    rednet.send(recipientId, packet, protocol)
    
    responseQueue[msgId] = {
        recipient = recipientId,
        packet = packet,
        attempts = 1,
        isLocal = isLocal,
        timerId = os.startTimer(3)
    }
    proxy_net.saveQueues()
end

function proxy_net.getOutboundQueue() return outboundQueue end
function proxy_net.getResponseQueue() return responseQueue end

return proxy_net
