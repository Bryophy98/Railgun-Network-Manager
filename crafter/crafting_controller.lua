-- ============================================================================
-- DEDICATED CRAFTING CONTROLLER PC (Gateway-Bound Local Microservice)
-- Save as: crafting_controller.lua
-- ============================================================================

local crafting_manager = require("apis.crafting_manager")

local PROXY_LOCAL_PROTOCOL = "local_proxy_link"

local gatewayProxyId = nil
if fs.exists("data/crafting_gateway.dat") then
    local f = fs.open("data/crafting_gateway.dat", "r")
    gatewayProxyId = tonumber(f.readAll())
    f.close()
end

local me = peripheral.find("meBridge")
local chatBox = peripheral.find("chatBox")

if not me then print("[Warning] ME Bridge not found on Crafting PC!") end

rednet.open("bottom")

if gatewayProxyId then
    rednet.send(gatewayProxyId, { type = "REGISTER_CRAFTING_PC" }, PROXY_LOCAL_PROTOCOL)
else
    rednet.broadcast({ type = "REGISTER_CRAFTING_PC" }, PROXY_LOCAL_PROTOCOL)
end
print("[Init] Sent registration ping to local Proxy gateway.")

crafting_manager.init(me, chatBox)

term.clear()
term.setCursorPos(1, 1)
print(string.rep("=", 35))
print("  CRAFTING CONTROLLER ONLINE")
print("  Gateway ID: " .. tostring(gatewayProxyId or "Discovering..."))
print(string.rep("=", 35))

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
                    local f = fs.open("data/crafting_gateway.dat", "w")
                    f.write(tostring(gatewayProxyId))
                    f.close()
                    print(string.format("[Gateway] Confirmed binding to local Proxy Gateway ID: %d", gatewayProxyId))
                else
                    if not gatewayProxyId or gatewayProxyId ~= senderId then
                        gatewayProxyId = senderId
                        local f = fs.open("data/crafting_gateway.dat", "w")
                        f.write(tostring(gatewayProxyId))
                        f.close()
                        print(string.format("[Gateway] Bound to local Proxy Gateway ID: %d", gatewayProxyId))
                    end
                    
                    crafting_manager.setProxyTarget(senderId)
                    
                    if message.type == "CONFIG_SYNC" then
                        crafting_manager.handleConfigSync(message.data)
                    elseif message.type == "GET_CRAFTABLES" then
                        local craftables = crafting_manager.getCraftablesList()
                        rednet.send(senderId, { 
                            type = "CRAFTABLES_RESPONSE", 
                            id = message.id, 
                            targetProxyId = message.sourceProxyId, 
                            data = craftables 
                        }, PROXY_LOCAL_PROTOCOL)
                    end
                end
            end
        end
        
    elseif event == "timer" and p1 == stockCheckTimer then
        crafting_manager.checkCraftables()
        stockCheckTimer = os.startTimer(5)
    end
end