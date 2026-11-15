-- ============================================================================
-- MANAGER API (Stateful Import Tracking & Lifecycle State Machine)
-- Save as: apis/manager.lua
-- ============================================================================

local storage = require("apis.storage")
local manager = {}

local MY_DIMENSION = "unknown" 
local proxyTargetId = nil
local localProtocol = "local_proxy_link"

local me = nil
local chatBox = nil
local dimRoutes = {}

local importsTable     = {}
local craftableExports = {}
local importStates     = {} -- [itemKey] = { state = "IDLE"|"PENDING"|"WAITING_ARRIVAL"|"COOLDOWN", expectedAmount = 0, expiry = 0 }

local function persistData()
    storage.save("imports.dat", importsTable)
    storage.save("craftable_exports.dat", craftableExports)
end

function manager.init(dimension, meRef, chatRef, routesRef)
    MY_DIMENSION = dimension
    me = meRef
    chatBox = chatRef
    dimRoutes = routesRef or {}
    
    importsTable     = storage.load("imports.dat") or {}
    craftableExports = storage.load("craftable_exports.dat") or {}
    
    if fs.exists("data/gateway.dat") then
        local f = fs.open("data/gateway.dat", "r")
        proxyTargetId = tonumber(f.readAll())
        f.close()
    end
end

function manager.setProxyTarget(id)
    proxyTargetId = id
    local f = fs.open("data/gateway.dat", "w")
    f.write(tostring(id))
    f.close()
end

local function broadcastChat(message)
    print(message)
    if chatBox then
        if chatBox.sendMessage then
            chatBox.sendMessage(message)
        elseif chatBox.say then
            chatBox.say(message)
        end
    end
end

-- ============================================================================
-- CONFIGURATION & STATE HANDLERS
-- ============================================================================

function manager.setImportItem(itemKey, targetStock, batchSize, sourceProxyId)
    importsTable[itemKey] = {
        targetStock = targetStock,
        batchSize = batchSize,
        sourceProxyId = sourceProxyId
    }
    persistData()
    broadcastChat(string.format("§b[Config] Import saved: %s (Source Proxy: %d)", itemKey, sourceProxyId))
end

function manager.removeImportItem(itemKey)
    if importsTable[itemKey] then
        importsTable[itemKey] = nil
        importStates[itemKey] = nil
        persistData()
        broadcastChat(string.format("§c[Config] Import removed: %s", itemKey))
    end
end

function manager.setCraftableItem(itemKey, targetStock, batchSize)
    craftableExports[itemKey] = {
        targetStock = targetStock,
        batchSize = batchSize
    }
    persistData()
    broadcastChat(string.format("§a[Config] Craftable item saved: %s (Target: %d)", itemKey, targetStock))
end

function manager.removeCraftableItem(itemKey)
    if craftableExports[itemKey] then
        craftableExports[itemKey] = nil
        persistData()
        broadcastChat(string.format("§c[Config] Craftable item removed: %s", itemKey))
    end
end

-- ============================================================================
-- BACKGROUND AUTOMATION LOOPS (State Machine)
-- ============================================================================

function manager.checkImports()
    if not me then return end

    if not proxyTargetId and fs.exists("data/gateway.dat") then
        local f = fs.open("data/gateway.dat", "r")
        proxyTargetId = tonumber(f.readAll())
        f.close()
    end

    if not proxyTargetId then
        broadcastChat(string.format("§4[Manager Error] Gateway binding missing! data/gateway.dat not found or invalid."))
        return
    end

    local currentTime = os.epoch("local") / 1000

    for itemKey, data in pairs(importsTable) do
        local stock = me.getItem({name = itemKey})
        local amount = stock and stock.amount or 0
        
        -- Initialize state if not tracked
        if not importStates[itemKey] then
            importStates[itemKey] = { state = "IDLE", baselineAmount = amount }
        end
        
        local currentTrack = importStates[itemKey]

        if currentTrack.state == "IDLE" then
            if amount < data.targetStock then
                broadcastChat(string.format("§c[Import Alert] %s low (%d/%d). Requesting restock...", itemKey, amount, data.targetStock))
                
                currentTrack.state = "PENDING"
                currentTrack.baselineAmount = amount
                
                rednet.send(proxyTargetId, {
                    type = "STOCK_REQUEST",
                    targetProxyId = data.sourceProxyId,
                    item = itemKey,
                    batchSize = data.batchSize,
                    requestingDim = MY_DIMENSION
                }, localProtocol)
            end

        elseif currentTrack.state == "WAITING_ARRIVAL" then
            -- Check if items have arrived (current stock higher than baseline when ordered)
            if amount >= currentTrack.targetWhenOrdered then
                broadcastChat(string.format("§a[Import Success] Restock arrived for %s! Current: %d", itemKey, amount))
                importStates[itemKey] = { state = "IDLE", baselineAmount = amount }
            end

        elseif currentTrack.state == "COOLDOWN" then
            if currentTime >= currentTrack.expiry then
                print(string.format("[Import] Cooldown expired for %s. Resuming check.", itemKey))
                importStates[itemKey] = { state = "IDLE", baselineAmount = amount }
            end
        end
    end
end

-- ============================================================================
-- INCOMING RESPONSES FROM SUPPLIER GATEWAY
-- ============================================================================

function manager.handleInboundResponse(msg)
    local itemKey = msg.item and msg.item.item or (msg.data and msg.data.item)
    if not itemKey then return end

    local track = importStates[itemKey] or { state = "IDLE" }

    if msg.type == "STOCK_RESPONSE" then
        broadcastChat(string.format("§a[Supplier Shipped] Order confirmed for %s. Waiting for delivery...", itemKey))
        local stock = me.getItem({name = itemKey})
        local currentAmount = stock and stock.amount or 0
        
        importStates[itemKey] = {
            state = "WAITING_ARRIVAL",
            targetWhenOrdered = currentAmount + (msg.data and msg.data.batchSize or 1)
        }

    elseif msg.type == "STOCK_LOW_ACK" then
        local available = msg.data and msg.data.available or 0
        local required = msg.data and msg.data.required or 0
        
        broadcastChat(string.format("§c[Supply Issue] Supplier out of stock for %s! Have %d, need %d. Paused for 5 mins.", itemKey, available, required))
        
        importStates[itemKey] = {
            state = "COOLDOWN",
            expiry = (os.epoch("local") / 1000) + 300 -- 5 minutes cooldown
        }
    end
end

-- ============================================================================
-- FULFILLMENT (Local Supplier Side)
-- ============================================================================

function manager.fulfillStockRequest(req)
    -- Fallback safety check in case the packet wrapper was passed directly
    if not req then
        print("[Error] fulfillStockRequest received a nil payload.")
        return
    end
    
    -- If data was nested under req.data, unwrap it gracefully
    local item = req.item or (req.data and req.data.item)
    local batchSize = req.batchSize or (req.data and req.data.batchSize)
    local requestingDim = req.requestingDim or (req.data and req.data.requestingDim)
    local sourceProxyId = req.sourceProxyId or (req.data and req.data.sourceProxyId)

    if not item or not batchSize or not requestingDim then
        print("[Error] fulfillStockRequest missing essential parameters.")
        return
    end

    broadcastChat(string.format("§d[Export Order] %s requested %d of %s", requestingDim, batchSize, item))
    
    if not me then return end

    local targetPeripheral = dimRoutes[requestingDim]
    if not targetPeripheral then
        broadcastChat(string.format("§4[Export Error] No peripheral route configured for: %s", requestingDim))
        return
    end

    local stock = me.getItem({name = item})
    local amount = stock and stock.amount or 0
    
    if amount >= batchSize then
        local success, err = pcall(function()
            return me.exportItemToPeripheral({name = item, count = batchSize}, targetPeripheral)
        end)
        
        if success then
            broadcastChat(string.format("§a[Export Success] Dispatched batch to %s", requestingDim))
            if proxyTargetId then
                rednet.send(proxyTargetId, {
                    targetProxyId = sourceProxyId,
                    type = "STOCK_RESPONSE",
                    data = { item = item, batchSize = batchSize }
                }, localProtocol)
            end
        else
            broadcastChat(string.format("§4[Export Error] Push failed: %s", tostring(err)))
        end
    else
        broadcastChat(string.format("§c[Export Warning] Insufficient stock for %s! Have %d, need %d.", item, amount, batchSize))
        if proxyTargetId then
            rednet.send(proxyTargetId, {
                targetProxyId = sourceProxyId,
                type = "STOCK_LOW_ACK",
                data = { item = item, available = amount, required = batchSize }
            }, localProtocol)
        end
    end
end

function manager.handleConfigSync(data)
    local act = data.action
    if act == "ADD_IMPORT" then
        manager.setImportItem(data.item, data.targetStock, data.batchSize, data.sourceProxyId)
    elseif act == "REMOVE_IMPORT" then
        manager.removeImportItem(data.item)
    elseif act == "ADD_CRAFT" then
        manager.setCraftableItem(data.item, data.targetStock, data.batchSize)
    elseif act == "REMOVE_CRAFT" then
        manager.removeCraftableItem(data.item)
    end
end

function manager.getItemsList()
    if not me then return {} end
    local success, items = pcall(function() return me.listItems() end)
    return success and items or {}
end

function manager.getCraftablesList()
    if not me then return {} end
    local success, craftables = pcall(function() return me.listCraftableItems() end)
    return success and craftables or {}
end

function manager.getImportsList()
    local list = {}
    if not importsTable then return list end
    
    for itemKey, data in pairs(importsTable) do
        table.insert(list, {
            item = tostring(itemKey),
            targetStock = tonumber(data.targetStock) or 0,
            batchSize = tonumber(data.batchSize) or 0,
            sourceProxyId = tonumber(data.sourceProxyId) or 0
        })
    end
    return list
end

return manager