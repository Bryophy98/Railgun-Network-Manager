-- ============================================================================
-- EXPORT SHIPPER API (Supplier Railgun Fulfillment + Per-Request Dedupe)
-- Save as: monitor/apis/export_shipper.lua
-- ============================================================================

local storage   = require("apis.storage")
local ae2_guard = require("apis.ae2_guard")

local export_shipper = {}

local MY_DIMENSION    = "unknown"
local localProtocol   = "local_proxy_link"
local me              = nil
local chatBox         = nil
local dimRoutes       = {}
local proxyTargetId   = nil
local fulfilledOrders = {}

local function chat(msg)
    print(msg)
    if chatBox then
        pcall(function()
            if chatBox.sendMessage then chatBox.sendMessage(msg)
            elseif chatBox.say then chatBox.say(msg) end
        end)
    end
end

function export_shipper.init(dimension, meRef, chatRef, routesRef)
    MY_DIMENSION    = string.lower(dimension)
    me              = meRef
    chatBox         = chatRef
    dimRoutes       = routesRef or {}
    fulfilledOrders = storage.load("fulfilled_orders.dat") or {}
end

function export_shipper.setProxyTarget(id)
    proxyTargetId = id
end

local function sendReply(targetProxyId, replyType, payload)
    if not proxyTargetId then return end
    payload.targetProxyId = targetProxyId
    payload.type          = replyType
    rednet.send(proxyTargetId, payload, localProtocol)
end

function export_shipper.fulfill(req)
    if not req then return end

    local item          = req.item or (req.data and req.data.item)
    local batchSize     = tonumber(req.batchSize or (req.data and req.data.batchSize))
    local requestingDim = req.requestingDim or (req.data and req.data.requestingDim)
    local sourceProxyId = req.sourceProxyId or (req.data and req.data.sourceProxyId)
    local orderId       = req.orderId or (req.data and req.data.orderId)
                          or (requestingDim and item and (string.lower(requestingDim) .. ":" .. tostring(item)))
    local dedupeKey     = req.reqId or (req.data and req.data.reqId) or req.id or orderId

    if not item or not batchSize or not requestingDim then return end
    if not ae2_guard.isOnline(me, chatBox, MY_DIMENSION) then return end

    -- Deduplicate only exact packet retries (by unique reqId), allowing rapid consecutive orders
    local now = os.epoch("local") / 1000
    if dedupeKey and fulfilledOrders[dedupeKey] and (now - fulfilledOrders[dedupeKey]) < 120 then
        print(string.format("[Export Dedupe] Packet %s already shipped. Re-sending ACK.", tostring(dedupeKey)))
        sendReply(sourceProxyId, "STOCK_RESPONSE", {
            orderId = orderId, item = item, batchSize = batchSize,
            data    = { orderId = orderId, item = item, batchSize = batchSize }
        })
        return
    end

    -- Prune old dedupe entries older than 5 minutes so fulfilled_orders.dat stays tiny
    for k, ts in pairs(fulfilledOrders) do
        if (now - ts) > 300 then
            fulfilledOrders[k] = nil
        end
    end

    local targetPeripheral = dimRoutes[requestingDim]
    if not targetPeripheral then
        chat(string.format("§4[Export Error] No peripheral route for: %s", requestingDim))
        return
    end

    local ok, stock = pcall(function() return me.getItem({ name = item }) end)
    local amount    = (ok and stock and stock.amount) or 0

    if amount >= batchSize then
        local success, err = pcall(function()
            return me.exportItemToPeripheral({ name = item, count = batchSize }, targetPeripheral)
        end)

        if success then
            if dedupeKey then
                fulfilledOrders[dedupeKey] = now
                storage.save("fulfilled_orders.dat", fulfilledOrders)
            end
            chat(string.format("§a[Export Success] Dispatched %s to %s", orderId, requestingDim))
            sendReply(sourceProxyId, "STOCK_RESPONSE", {
                orderId = orderId, item = item, batchSize = batchSize,
                data    = { orderId = orderId, item = item, batchSize = batchSize }
            })
        else
            chat(string.format("§4[Export Error] Push failed: %s", tostring(err)))
        end
    else
        chat(string.format("§c[Export Warning] Low stock for %s (%d/%d).", orderId, amount, batchSize))
        sendReply(sourceProxyId, "STOCK_LOW_ACK", {
            orderId = orderId, item = item, available = amount, required = batchSize,
            data    = { orderId = orderId, item = item, available = amount, required = batchSize }
        })
    end
end

return export_shipper
