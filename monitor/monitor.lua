-- ============================================================================
-- MONITOR PC (Grayscale PrimeUI Dashboard + Gateway Auto-Discovery)
-- Save as: monitor/monitor.lua
-- ============================================================================

local wizard  = require("wizard")
local manager = require("apis.manager")
local dash    = require("apis.node_dashboard")

local config = wizard.load()
if not config then
    wizard.run()
    config = wizard.load()
end

local MY_DIMENSION = config.dimension
local dimRoutes    = config.routes

local PROXY_LOCAL_PROTOCOL = "local_proxy_link"

if not fs.exists("data") then fs.makeDir("data") end

local gatewayProxyId = nil
if fs.exists("data/gateway.dat") then
    local f = fs.open("data/gateway.dat", "r")
    gatewayProxyId = tonumber(f.readAll())
    f.close()
end

local me      = peripheral.find("meBridge")
local chatBox = peripheral.find("chatBox")

dash.init(
    "MONITOR: " .. MY_DIMENSION:upper(),
    string.format("PC #%d | GW: %s | ME: %s", os.computerID(), tostring(gatewayProxyId or "Seeking"), me and "OK" or "Missing")
)
_G.print = dash.log

if not me then dash.log("[Warning] ME Bridge peripheral not found!") end
if not chatBox then dash.log("[Warning] Chat Box peripheral not found!") end

if peripheral.getType("bottom") == "modem" then
    rednet.open("bottom")
else
    peripheral.find("modem", function(name) rednet.open(name) end)
end

if gatewayProxyId then
    rednet.send(gatewayProxyId, { type = "REGISTER_MONITOR" }, PROXY_LOCAL_PROTOCOL)
else
    rednet.broadcast({ type = "REGISTER_MONITOR" }, PROXY_LOCAL_PROTOCOL)
end
dash.log("[Init] Sent registration ping to Proxy gateway.")

manager.init(MY_DIMENSION, me, chatBox, dimRoutes)
if gatewayProxyId then
    manager.setProxyTarget(gatewayProxyId)
end

local stockCheckTimer = os.startTimer(5)

while true do
    local event, p1, p2, p3 = os.pullEvent()

    if event == "rednet_message" then
        local senderId, message, protocol = p1, p2, p3
        if protocol == PROXY_LOCAL_PROTOCOL and type(message) == "table" then
            local isFromGateway = (gatewayProxyId and senderId == gatewayProxyId)
            local isAck = (message.type == "GATEWAY_ACK")

            if isFromGateway or isAck or not gatewayProxyId then
                if message.type == "GATEWAY_ACK" then
                    gatewayProxyId = message.gatewayId or senderId
                    local f = fs.open("data/gateway.dat", "w")
                    f.write(tostring(gatewayProxyId))
                    f.close()
                    dash.setStatus(nil, string.format("PC #%d | GW: #%d | ME: %s", os.computerID(), gatewayProxyId, me and "OK" or "Missing"))
                    dash.log(string.format("[Gateway] Bound to Proxy ID: #%d", gatewayProxyId))
                else
                    if not gatewayProxyId or gatewayProxyId ~= senderId then
                        gatewayProxyId = senderId
                        local f = fs.open("data/gateway.dat", "w")
                        f.write(tostring(gatewayProxyId))
                        f.close()
                        dash.setStatus(nil, string.format("PC #%d | GW: #%d | ME: %s", os.computerID(), gatewayProxyId, me and "OK" or "Missing"))
                    end

                    manager.setProxyTarget(senderId)

                    if message.type == "STOCK_REQUEST" then
                        manager.fulfillStockRequest(message)
                    elseif message.type == "STOCK_RESPONSE" or message.type == "STOCK_LOW_ACK" then
                        manager.handleInboundResponse(message)
                    elseif message.type == "CONFIG_SYNC" then
                        manager.handleConfigSync(message.data)
                    elseif message.type == "GET_ITEMS" then
                        local items = manager.getItemsList()
                        rednet.send(senderId, { type = "ITEMS_RESPONSE", id = message.id, targetProxyId = message.sourceProxyId, data = items }, PROXY_LOCAL_PROTOCOL)
                    elseif message.type == "GET_IMPORTS" then
                        local imports = manager.getImportsList()
                        rednet.send(senderId, { type = "IMPORTS_RESPONSE", id = message.id, targetProxyId = message.sourceProxyId, data = imports }, PROXY_LOCAL_PROTOCOL)
                    end
                end
            end
        end

    elseif event == "timer" and p1 == stockCheckTimer then
        manager.checkImports()
        stockCheckTimer = os.startTimer(5)
    end
end
