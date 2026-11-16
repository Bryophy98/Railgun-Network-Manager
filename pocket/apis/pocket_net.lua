-- ============================================================================
-- POCKET PC NETWORK API (Clean Silent Returns for PrimeUI)
-- Save as: pocket/apis/pocket_net.lua
-- ============================================================================

local pocket_net = {}

local PROXY_PROTOCOL = "dim_transport"
local OTA_PROTOCOL   = "OTA_UPDATE"
local DIM_LIST = {"earth", "beneath", "moon", "mars", "venus", "mercury"}

function pocket_net.init()
    local modem = peripheral.find("modem")
    if not modem then error("No modem attached to Pocket PC!") end
    rednet.open(peripheral.getName(modem))
end

function pocket_net.getDimensions()
    return DIM_LIST
end

function pocket_net.resolveProxyId(dimName)
    local hostname = "proxy_" .. dimName:lower()
    return rednet.lookup(PROXY_PROTOCOL, hostname)
end

function pocket_net.getRemoteImports(targetProxyId)
    return pocket_net.sendAndAwait(targetProxyId, "GET_IMPORTS", nil, "IMPORTS_RESPONSE", 4)
end

function pocket_net.broadcastOtaUpdate()
    local updateId = os.epoch("utc")
    rednet.broadcast({ cmd = "RUN_UPDATE", id = updateId }, OTA_PROTOCOL)
    return updateId
end

function pocket_net.scanRemoteItem()
    local scannerId = 12
    local msgId = string.format("scan_%d", os.epoch("local"))

    rednet.send(scannerId, { type = "GET_OFFHAND_ITEM", id = msgId }, "scanner_link")

    local timerId = os.startTimer(3)
    while true do
        local event, p1, p2, p3 = os.pullEvent()
        if event == "rednet_message" then
            local senderId, msg, proto = p1, p2, p3
            if senderId == scannerId and proto == "scanner_link" and type(msg) == "table" and msg.id == msgId then
                if msg.success and msg.item and msg.item.name then
                    return tostring(msg.item.name), nil
                else
                    return nil, tostring(msg.reason or "Scan failed")
                end
            end
        elseif event == "timer" and p1 == timerId then
            return nil, "Scanner timed out"
        end
    end
end

function pocket_net.sendAndAwait(targetProxyId, reqType, payloadData, expectedRespType, timeoutSec)
    local msgId = string.format("pocket_%d_%d", os.computerID(), os.epoch("local"))
    local packet = {
        id        = msgId,
        senderDim = "pocket_pc",
        type      = reqType,
        data      = payloadData
    }

    rednet.send(targetProxyId, packet, PROXY_PROTOCOL)
    local timerId = os.startTimer(timeoutSec or 4)

    while true do
        local event, p1, p2, p3 = os.pullEvent()
        if event == "rednet_message" then
            local senderId, msg, proto = p1, p2, p3
            if proto == PROXY_PROTOCOL and type(msg) == "table" then
                local matchesQuery = (msg.id == msgId) or (msg.sourceQueryId == msgId)
                if msg.type == expectedRespType and matchesQuery then
                    rednet.send(senderId, { type = "RESPONSE_ACK", ackId = msg.id }, PROXY_PROTOCOL)
                    return msg.data
                elseif msg.type == "ACK" and reqType == "CONFIG_SYNC" and msg.ackId == msgId then
                    return true
                end
            end
        elseif event == "timer" and p1 == timerId then
            return nil
        end
    end
end

return pocket_net
