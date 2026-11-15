-- ============================================================================
-- DEPOT MONITOR PC (Persistent Gateway Binding & Transactional ACKs)
-- ============================================================================

local manager = require("apis.manager")
local wizard = require("wizard")

local config = wizard.load()
if not config then
    wizard.run()
    config = wizard.load()
end

local MY_DIMENSION = config.dimension
local DIM_ROUTES = config.routes
local PROXY_LOCAL_PROTOCOL = "local_proxy_link"

local gatewayProxyId = nil
if fs.exists("data/gateway.dat") then
    local f = fs.open("data/gateway.dat", "r")
    gatewayProxyId = tonumber(f.readAll())
    f.close()
end

local me = peripheral.find("meBridge")
local chatBox = peripheral.find("chatBox")

rednet.open("bottom")

manager.init(MY_DIMENSION, me, chatBox, DIM_ROUTES)

term.clear()
term.setCursorPos(1, 1)
print(string.rep("=", 35))
print("  MONITOR PC ONLINE: " .. MY_DIMENSION:upper())
print("  Gateway ID: " .. tostring(gatewayProxyId or "Discovering..."))
print(string.rep("=", 35))

if gatewayProxyId then
    rednet.send(gatewayProxyId, { type = "REGISTER_MONITOR" }, PROXY_LOCAL_PROTOCOL)
else
    rednet.broadcast({ type = "REGISTER_MONITOR" }, PROXY_LOCAL_PROTOCOL)
end
print("[Init] Sent registration ping to local Proxy gateway.")

local stockCheckTimer = os.startTimer(5)

while true do
    local event, p1, p2, p3 = os.pullEvent()
    
    if event == "rednet_message" then
        local senderId, message, protocol = p1, p2, p3
        if protocol == PROXY_LOCAL_PROTOCOL and type(message) == "table" then
            
            -- CLEAN FILTER: Only process if it's from our gateway OR an explicit ACK
            local isFromGateway = (gatewayProxyId and senderId == gatewayProxyId)
            local isAck = (message.type == "GATEWAY_ACK")
            
            if isFromGateway or isAck or not gatewayProxyId then
                if message.type == "GATEWAY_ACK" then
                    gatewayProxyId = message.gatewayId or senderId
                    local f = fs.open("data/gateway.dat", "w")
                    f.write(tostring(gatewayProxyId))
                    f.close()
                    print(string.format("[Gateway] Confirmed binding to Proxy Gateway ID: %d", gatewayProxyId))
                else
                    if not gatewayProxyId or gatewayProxyId ~= senderId then
                        gatewayProxyId = senderId
                        local f = fs.open("data/gateway.dat", "w")
                        f.write(tostring(gatewayProxyId))
                        f.close()
                        print(string.format("[Gateway] Bound to Proxy Gateway ID: %d", gatewayProxyId))
                    end
                    
                    manager.setProxyTarget(senderId)
                    
                    if message.type == "CONFIG_SYNC" then
                        manager.handleConfigSync(message.data)
                    elseif message.type == "STOCK_REQUEST" then
                        -- Pass the full message table to handle flat field structures
                        manager.fulfillStockRequest(message)
                    elseif message.type == "STOCK_RESPONSE" or message.type == "STOCK_LOW_ACK" then
                        -- Acknowledge receipt back to gateway so it clears its response queue
                        rednet.send(senderId, { type = "REQUEST_ACK", ackId = message.id }, PROXY_LOCAL_PROTOCOL)
                        
                        -- Pass response into the manager state machine
                        manager.handleInboundResponse(message)
                        
                    elseif message.type == "GET_ITEMS" then
                        local items = manager.getItemsList()
                        rednet.send(senderId, { 
                            type = "ITEMS_RESPONSE", 
                            id = message.id, 
                            targetProxyId = message.sourceProxyId, 
                            data = items 
                        }, PROXY_LOCAL_PROTOCOL)
                    elseif message.type == "GET_IMPORTS" then
                        local imports = manager.getImportsList()
                        rednet.send(senderId, { 
                            type = "IMPORTS_RESPONSE", 
                            id = message.id, 
                            targetProxyId = message.sourceProxyId, 
                            data = imports 
                        }, PROXY_LOCAL_PROTOCOL)
                    end
                end
            end
        end
        
    elseif event == "timer" and p1 == stockCheckTimer then
        manager.checkImports()
        stockCheckTimer = os.startTimer(5)
    end
end