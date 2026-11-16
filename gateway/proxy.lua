-- ============================================================================
-- PROXY PC (Refactored Main Logic with Crafting CRUD & Dimension Handshake)
-- Save as: gateway/proxy.lua
-- ============================================================================

local wizard = require("proxy_wizard")
local pnet = require("apis.proxy_net")

local config = wizard.load()
if not config then
    wizard.run()
    config = wizard.load()
end

local MY_DIMENSION = config.dimension
local monitorComputerId = config.monitorId
local craftingComputerId = config.craftingId or nil

local PROXY_PROTOCOL = "dim_transport"
local LOCAL_PROTOCOL = "local_proxy_link"

term.clear()
term.setCursorPos(1, 1)
print(string.rep("=", 31))
print("  DIMENSIONAL PROXY GATEWAY")
print("  Dimension: " .. MY_DIMENSION:upper())
print("  Linked Monitor:   " .. tostring(monitorComputerId or "None"))
print("  Linked Crafting:  " .. tostring(craftingComputerId or "None"))
print(string.rep("=", 31))

-- Open all attached modems (top Ender Modem + bottom Local link)
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "modem" then
        rednet.open(name)
    end
end

rednet.host(PROXY_PROTOCOL, "proxy_" .. MY_DIMENSION)

pnet.loadQueues()

local processedCache = {}
local pendingQueries = {}

-- Main Event Loop
while true do
    local event, p1, p2, p3 = os.pullEvent()

    if event == "rednet_message" then
        local senderId, message, protocol = p1, p2, p3

        if protocol == PROXY_PROTOCOL and type(message) == "table" then
            if message.type == "ACK" then
                local msgId = message.ackId
                local q = pnet.getOutboundQueue()
                if q[msgId] then
                    os.cancelTimer(q[msgId].timerId)
                    q[msgId] = nil
                    pnet.saveQueues()
                    print(string.format("[ACK] Request packet %s delivered & cleared.", msgId))
                end
            elseif message.type == "RESPONSE_ACK" then
                local msgId = message.ackId
                local resQ = pnet.getResponseQueue()
                if resQ[msgId] then
                    os.cancelTimer(resQ[msgId].timerId)
                    resQ[msgId] = nil
                    pnet.saveQueues()
                    print(string.format("[Response ACK] Result packet %s acknowledged & cleared.", msgId))
                end
            else
                rednet.send(senderId, { type = "ACK", ackId = message.id }, PROXY_PROTOCOL)

                if message.type == "GET_ITEMS"
                    or message.type == "GET_CRAFTABLES"
                    or message.type == "GET_CRAFT_RULES"
                    or message.type == "GET_IMPORTS"
                    or message.type == "STOCK_REQUEST" then
                    pendingQueries[message.id] = senderId
                end

                if not processedCache[message.id] then
                    processedCache[message.id] = true
                    message.sourceProxyId = senderId

                    local targetClient = monitorComputerId
                    if message.type == "GET_CRAFTABLES"
                        or message.type == "GET_CRAFT_RULES"
                        or (message.type == "CONFIG_SYNC" and message.data and string.find(tostring(message.data.action), "CRAFT")) then
                        targetClient = craftingComputerId or monitorComputerId
                    end

                    if targetClient then
                        print(string.format("[Gateway] Forwarding packet '%s' to local client ID %d", tostring(message.type), targetClient))
                        rednet.send(targetClient, message, LOCAL_PROTOCOL)
                    else
                        print("[Gateway Error] Packet dropped: No local client registered!")
                    end
                end
            end

        elseif protocol == LOCAL_PROTOCOL and type(message) == "table" then
            if message.type == "REGISTER_MONITOR" then
                if monitorComputerId ~= senderId then
                    monitorComputerId = senderId
                    pnet.saveConfig(MY_DIMENSION, monitorComputerId, craftingComputerId)
                end
                rednet.send(senderId, {
                    type      = "GATEWAY_ACK",
                    gatewayId = os.computerID(),
                    dimension = MY_DIMENSION
                }, LOCAL_PROTOCOL)

            elseif message.type == "REGISTER_CRAFTING_PC" then
                if craftingComputerId ~= senderId then
                    craftingComputerId = senderId
                    pnet.saveConfig(MY_DIMENSION, monitorComputerId, craftingComputerId)
                end
                rednet.send(senderId, {
                    type      = "GATEWAY_ACK",
                    gatewayId = os.computerID(),
                    dimension = MY_DIMENSION
                }, LOCAL_PROTOCOL)

            elseif message.type == "REQUEST_ACK" then
                local msgId = message.ackId
                local resQ = pnet.getResponseQueue()
                if resQ[msgId] then
                    os.cancelTimer(resQ[msgId].timerId)
                    resQ[msgId] = nil
                    pnet.saveQueues()
                end

            elseif message.type == "ITEMS_RESPONSE"
                or message.type == "CRAFTABLES_RESPONSE"
                or message.type == "CRAFT_RULES_RESPONSE"
                or message.type == "IMPORTS_RESPONSE" then
                local destinationProxyId = pendingQueries[message.id] or message.targetProxyId
                if destinationProxyId then
                    pnet.sendResponsePacket(destinationProxyId, message, message.id, false, MY_DIMENSION, PROXY_PROTOCOL, LOCAL_PROTOCOL)
                    pendingQueries[message.id] = nil
                end

            elseif message.type == "STOCK_RESPONSE" or message.type == "STOCK_LOW_ACK" then
                local destinationProxyId = message.targetProxyId or pendingQueries[message.sourceQueryId]
                if destinationProxyId then
                    pnet.sendResponsePacket(destinationProxyId, message, message.id, false, MY_DIMENSION, PROXY_PROTOCOL, LOCAL_PROTOCOL)
                end

            elseif message.sourceProxyId and (message.type == "STOCK_RESPONSE" or message.type == "STOCK_LOW_ACK") then
                pnet.sendResponsePacket(monitorComputerId, message, message.id, true, MY_DIMENSION, PROXY_PROTOCOL, LOCAL_PROTOCOL)

            elseif message.targetProxyId and message.type == "STOCK_REQUEST" then
                pnet.sendCrossDimPacket(message.targetProxyId, message, message.id, MY_DIMENSION, PROXY_PROTOCOL)
            end
        end

    elseif event == "timer" then
        -- Retry Request Queue
        for msgId, qItem in pairs(pnet.getOutboundQueue()) do
            if qItem.timerId == p1 then
                if qItem.attempts < 5 then
                    qItem.attempts = qItem.attempts + 1
                    rednet.send(qItem.recipient, qItem.packet, PROXY_PROTOCOL)
                    qItem.timerId = os.startTimer(3)
                    pnet.saveQueues()
                else
                    pnet.getOutboundQueue()[msgId] = nil
                    pnet.saveQueues()
                end
            end
        end
        -- Retry Response Queue
        for msgId, qItem in pairs(pnet.getResponseQueue()) do
            if qItem.timerId == p1 then
                if qItem.attempts < 5 then
                    qItem.attempts = qItem.attempts + 1
                    local proto = qItem.isLocal and LOCAL_PROTOCOL or PROXY_PROTOCOL
                    rednet.send(qItem.recipient, qItem.packet, proto)
                    qItem.timerId = os.startTimer(3)
                    pnet.saveQueues()
                else
                    pnet.getResponseQueue()[msgId] = nil
                    pnet.saveQueues()
                end
            end
        end
    end
end
