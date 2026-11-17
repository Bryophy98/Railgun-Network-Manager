-- ============================================================================
-- IMPORT WATCHER API (Buyer State Machine + High-Consumption Arrival Check)
-- Save as: monitor/apis/import_watcher.lua
-- ============================================================================

local storage   = require("apis.storage")
local ae2_guard = require("apis.ae2_guard")

local import_watcher = {}

local MY_DIMENSION       = "unknown"
local localProtocol      = "local_proxy_link"
local me                 = nil
local chatBox            = nil
local proxyTargetId      = nil
local importsTable       = {}
local TRANSIT_TIMEOUT_SEC = 60

local function makeOrderId(dim, itemKey)
    return string.lower(dim) .. ":" .. tostring(itemKey)
end

local function chat(msg)
    print(msg)
    if chatBox then
        pcall(function()
            if chatBox.sendMessage then chatBox.sendMessage(msg)
            elseif chatBox.say then chatBox.say(msg) end
        end)
    end
end

function import_watcher.persist()
    storage.save("imports.dat", importsTable)
end

function import_watcher.init(dimension, meRef, chatRef)
    MY_DIMENSION = string.lower(dimension)
    me           = meRef
    chatBox      = chatRef

    local raw = storage.load("imports.dat") or {}
    importsTable = {}
    local migrated = false

    for key, entry in pairs(raw) do
        local itemName = entry.item or key
        local orderId  = makeOrderId(MY_DIMENSION, itemName)
        if key ~= orderId then migrated = true end

        importsTable[orderId] = {
            orderId           = orderId,
            dimension         = MY_DIMENSION,
            item              = itemName,
            targetStock       = tonumber(entry.targetStock) or 0,
            batchSize         = tonumber(entry.batchSize) or 1,
            sourceProxyId     = tonumber(entry.sourceProxyId) or 0,
            status            = entry.status or "IDLE",
            baselineStock     = tonumber(entry.baselineStock) or 0,
            lowestStock       = tonumber(entry.lowestStock) or tonumber(entry.baselineStock) or 0,
            targetWhenOrdered = tonumber(entry.targetWhenOrdered) or 0,
            expiry            = tonumber(entry.expiry) or 0,
            updatedAt         = tonumber(entry.updatedAt) or 0
        }
    end
    if migrated then import_watcher.persist() end
end

function import_watcher.setProxyTarget(id)
    proxyTargetId = id
end

function import_watcher.setRule(itemKey, targetStock, batchSize, sourceProxyId)
    local orderId  = makeOrderId(MY_DIMENSION, itemKey)
    local existing = importsTable[orderId]

    importsTable[orderId] = {
        orderId           = orderId,
        dimension         = MY_DIMENSION,
        item              = itemKey,
        targetStock       = targetStock,
        batchSize         = batchSize,
        sourceProxyId     = sourceProxyId,
        status            = existing and existing.status or "IDLE",
        baselineStock     = existing and existing.baselineStock or 0,
        lowestStock       = existing and existing.lowestStock or 0,
        targetWhenOrdered = existing and existing.targetWhenOrdered or 0,
        expiry            = existing and existing.expiry or 0,
        updatedAt         = os.epoch("local") / 1000
    }
    import_watcher.persist()
    chat(string.format("§b[Config] Import saved: %s (Source Proxy: %d)", orderId, sourceProxyId))
end

function import_watcher.removeRule(itemKey)
    local orderId = makeOrderId(MY_DIMENSION, itemKey)
    if importsTable[orderId] then
        importsTable[orderId] = nil
        import_watcher.persist()
        chat(string.format("§c[Config] Import removed: %s", orderId))
    end
end

function import_watcher.tick()
    if not ae2_guard.isOnline(me, chatBox, MY_DIMENSION) then return end
    if not proxyTargetId then return end

    local now   = os.epoch("local") / 1000
    local dirty = false

    for orderId, rule in pairs(importsTable) do
        local ok, stock = pcall(function() return me.getItem({ name = rule.item }) end)
        if not ok then return end
        local amount = stock and stock.amount or 0

        if rule.status == "IDLE" and amount < rule.targetStock then
            chat(string.format("§c[Import Alert] %s low (%d/%d). Requesting...", orderId, amount, rule.targetStock))
            rule.status        = "PENDING"
            rule.baselineStock = amount
            rule.lowestStock   = amount
            rule.updatedAt     = now
            dirty = true

            rednet.send(proxyTargetId, {
                type          = "STOCK_REQUEST",
                orderId       = orderId,
                targetProxyId = rule.sourceProxyId,
                item          = rule.item,
                batchSize     = rule.batchSize,
                requestingDim = MY_DIMENSION
            }, localProtocol)

        elseif rule.status == "PENDING" and (now - (rule.updatedAt or 0)) > 120 then
            rule.status    = "IDLE"
            rule.updatedAt = now
            dirty = true

        elseif rule.status == "IN_TRANSIT" then
            -- Track lowest observed stock so even a small net uptick confirms arrival
            if amount < (rule.lowestStock or amount) then
                rule.lowestStock = amount
                dirty = true
            end

            if amount > (rule.lowestStock or rule.baselineStock) then
                chat(string.format("§a[Import Success] Restock detected for %s! Current: %d", orderId, amount))
                rule.status    = "IDLE"
                rule.updatedAt = now
                dirty = true
            elseif (now - (rule.updatedAt or 0)) >= TRANSIT_TIMEOUT_SEC then
                chat(string.format("§e[Import Timeout] 60s elapsed for %s (consumed in flight). Resuming.", orderId))
                rule.status    = "IDLE"
                rule.updatedAt = now
                dirty = true
            end

        elseif rule.status == "COOLDOWN" and now >= (rule.expiry or 0) then
            rule.status    = "IDLE"
            rule.updatedAt = now
            dirty = true
        end
    end

    if dirty then import_watcher.persist() end
end

function import_watcher.handleResponse(msg)
    local itemKey = msg.item or (msg.data and msg.data.item)
    local orderId = msg.orderId or (msg.data and msg.data.orderId) or (itemKey and makeOrderId(MY_DIMENSION, itemKey))
    local rule    = orderId and importsTable[orderId]
    if not rule then return end

    local now = os.epoch("local") / 1000
    if msg.type == "STOCK_RESPONSE" then
        local qty = tonumber(msg.batchSize or (msg.data and msg.data.batchSize)) or rule.batchSize
        local cur = rule.baselineStock
        if me then
            local ok, stock = pcall(function() return me.getItem({ name = rule.item }) end)
            if ok and stock then cur = stock.amount or cur end
        end
        rule.status            = "IN_TRANSIT"
        rule.lowestStock       = cur
        rule.targetWhenOrdered = cur + qty
        rule.updatedAt         = now
        import_watcher.persist()
        chat(string.format("§a[Supplier Shipped] %s confirmed (%d). In transit...", orderId, qty))

    elseif msg.type == "STOCK_LOW_ACK" then
        local avail = tonumber(msg.available or (msg.data and msg.data.available)) or 0
        local req   = tonumber(msg.required or (msg.data and msg.data.required)) or rule.batchSize
        rule.status    = "COOLDOWN"
        rule.expiry    = now + 300
        rule.updatedAt = now
        import_watcher.persist()
        chat(string.format("§c[Supply Issue] Out of stock for %s (%d/%d). Paused 5m.", orderId, avail, req))
    end
end

function import_watcher.getList()
    local list = {}
    for orderId, data in pairs(importsTable) do
        table.insert(list, {
            orderId       = tostring(orderId),
            item          = tostring(data.item),
            targetStock   = tonumber(data.targetStock) or 0,
            batchSize     = tonumber(data.batchSize) or 0,
            sourceProxyId = tonumber(data.sourceProxyId) or 0,
            status        = tostring(data.status or "IDLE")
        })
    end
    return list
end

return import_watcher
