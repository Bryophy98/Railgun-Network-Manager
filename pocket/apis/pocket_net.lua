-- ============================================================================
-- POCKET PC NETWORK API
-- Save as: apis/pocket_net.lua
-- ============================================================================

local pocket_net = {}

local PROXY_PROTOCOL = "dim_transport"
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

function pocket_net.scanRemoteItem()
    local scannerId = 12 -- Fixed static ID for the Inventory Scanner PC
    local msgId = string.format("scan_%d", os.epoch("local"))
    
    rednet.send(scannerId, { type = "GET_OFFHAND_ITEM", id = msgId }, "scanner_link")

    local timerId = os.startTimer(3)
    while true do
        local event, p1, p2, p3 = os.pullEvent()
        if event == "rednet_message" then
            local senderId, msg, proto = p1, p2, p3
            if senderId == scannerId and proto == "scanner_link" and type(msg) == "table" and msg.id == msgId then
                if msg.success then
                    print(string.format("\n§a[Scanned] %s", msg.item.name))
                    sleep(1)
                    return msg.item.name
                else
                    print("\n§c[Error] " .. tostring(msg.reason))
                    sleep(2)
                    return nil
                end
            end
        elseif event == "timer" and p1 == timerId then
            print("\n§c[Error] Scanner station timed out.")
            sleep(2)
            return nil
        end
    end
end

function pocket_net.sendAndAwait(targetProxyId, reqType, payloadData, expectedRespType, timeoutSec)
    local msgId = string.format("pocket_%d_%d", os.computerID(), os.epoch("local"))
    local packet = {
        id = msgId,
        senderDim = "pocket_pc",
        type = reqType,
        data = payloadData
    }

    print(string.format("[PocketNet] Sending %s (ID: %s) to Proxy ID %d...", reqType, msgId, targetProxyId))
    rednet.send(targetProxyId, packet, PROXY_PROTOCOL)
    local timerId = os.startTimer(timeoutSec or 4)

    while true do
        local event, p1, p2, p3 = os.pullEvent()
        if event == "rednet_message" then
            local senderId, msg, proto = p1, p2, p3
            if proto == PROXY_PROTOCOL and type(msg) == "table" then
                print(string.format("[PocketNet] Received response type '%s' from #%d", tostring(msg.type), senderId))
                if msg.type == expectedRespType and msg.id == msgId then
                    print("[PocketNet] Response matched successfully!")
                    return msg.data
                elseif msg.type == "ACK" and reqType == "CONFIG_SYNC" and msg.ackId == msgId then
                    print("[PocketNet] ACK received for config sync!")
                    return true
                end
            end
        elseif event == "timer" and p1 == timerId then
            print(string.format("[PocketNet Error] Timeout waiting for response to %s!", reqType))
            return nil
        end
    end
end

return pocket_net