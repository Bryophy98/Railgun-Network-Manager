-- ============================================================================
-- DEDICATED CRAFTING CONTROLLER PC (Grayscale PrimeUI Dashboard)
-- Save as: crafter/crafting_controller.lua
-- ============================================================================

local crafting_manager = require("apis.crafting_manager")
local dash             = require("apis.node_dashboard")

local PROXY_LOCAL_PROTOCOL = "local_proxy_link"

if not fs.exists("data") then fs.makeDir("data") end

local gatewayProxyId = nil
if fs.exists("data/crafting_gateway.dat") then
    local f = fs.open("data/crafting_gateway.dat", "r")
    gatewayProxyId = tonumber(f.readAll())
    f.close()
end

local myDimension = "crafter"
if fs.exists("data/dimension.dat") then
    local f = fs.open("data/dimension.dat", "r")
    myDimension = f.readAll()
    f.close()
end

local me      = peripheral.find("meBridge")
local chatBox = peripheral.find("chatBox")

dash.init(
    "CRAFTER: " .. myDimension:upper(),
    string.format("PC #%d | GW: %s | ME: %s", os.computerID(), tostring(gatewayProxyId or "Seeking"), me and "OK" or "Missing")
)
_G.print = dash.log

if not me then dash.log("[Warning] ME Bridge not found on Crafting PC!") end

if peripheral.getType("bottom") == "modem" then
    rednet.open("bottom")
else
    peripheral.find("modem", function(name) rednet.open(name) end)
end

if gatewayProxyId then
    rednet.send(gatewayProxyId, { type = "REGISTER_CRAFTING_PC" }, PROXY_LOCAL_PROTOCOL)
else
    rednet.broadcast({ type = "REGISTER_CRAFTING_PC" }, PROXY_LOCAL_PROTOCOL)
end
dash.log("[Init] Sent registration ping to Proxy gateway.")

crafting_manager.init(me, chatBox, myDimension)

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
                    if message.dimension then
                        myDimension = message.dimension
                        local df = fs.open("data/dimension.dat", "w")
                        df.write(tostring(myDimension))
                        df.close()
                        crafting_manager.init(me, chatBox, myDimension)
                    end
                    local f = fs.open("data/crafting_gateway.dat", "w")
                    f.write(tostring(gatewayProxyId))
                    f.close()
                    dash.setStatus("CRAFTER: " .. myDimension:upper(), string.format("PC #%d | GW: #%d | ME: %s", os.computerID(), gatewayProxyId, me and "OK" or "Missing"))
                    dash.log(string.format("[Gateway] Bound to Proxy ID: #%d", gatewayProxyId))
                else
                    if not gatewayProxyId or gatewayProxyId ~= senderId then
                        gatewayProxyId = senderId
                        local f = fs.open("data/crafting_gateway.dat", "w")
                        f.write(tostring(gatewayProxyId))
                        f.close()
                        dash.setStatus("CRAFTER: " .. myDimension:upper(), string.format("PC #%d | GW: #%d | ME: %s", os.computerID(), gatewayProxyId, me and "OK" or "Missing"))
                    end

                    crafting_manager.setProxyTarget(senderId)

                    if message.type == "CONFIG_SYNC" then
                        crafting_manager.handleConfigSync(message.data)
                    elseif message.type == "GET_CRAFTABLES" then
                        local craftables = crafting_manager.getCraftablesList()
                        rednet.send(senderId, { type = "CRAFTABLES_RESPONSE", id = message.id, targetProxyId = message.sourceProxyId, data = craftables }, PROXY_LOCAL_PROTOCOL)
                    elseif message.type == "GET_CRAFT_RULES" then
                        local rules = crafting_manager.getRulesList()
                        rednet.send(senderId, { type = "CRAFT_RULES_RESPONSE", id = message.id, targetProxyId = message.sourceProxyId, data = rules }, PROXY_LOCAL_PROTOCOL)
                    end
                end
            end
        end

    elseif event == "timer" and p1 == stockCheckTimer then
        crafting_manager.checkCraftables()
        stockCheckTimer = os.startTimer(5)
    end
end
