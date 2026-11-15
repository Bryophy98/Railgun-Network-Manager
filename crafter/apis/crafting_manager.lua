-- ============================================================================
-- CRAFTING MANAGER API (Local Stock & Auto-Craft Microservice + AE2 Guard)
-- Save as: crafter/apis/crafting_manager.lua
-- ============================================================================

local storage   = require("apis.storage")
local ae2_guard = require("apis.ae2_guard")

local crafting_manager = {}

local MY_DIMENSION     = "crafter"
local proxyTargetId    = nil
local me               = nil
local chatBox          = nil
local craftableExports = {}

function crafting_manager.init(meRef, chatRef, dimName)
    me               = meRef
    chatBox          = chatRef
    MY_DIMENSION     = dimName or "crafter"
    craftableExports = storage.load("craftable_exports.dat") or {}
end

function crafting_manager.setProxyTarget(id)
    proxyTargetId = id
end

local function persistData()
    storage.save("craftable_exports.dat", craftableExports)
end

local function broadcastChat(message)
    print(message)
    if chatBox then
        pcall(function()
            if chatBox.sendMessage then chatBox.sendMessage(message)
            elseif chatBox.say then chatBox.say(message) end
        end)
    end
end

function crafting_manager.setCraftableItem(itemKey, targetStock, batchSize)
    craftableExports[itemKey] = {
        targetStock = targetStock,
        batchSize   = batchSize
    }
    persistData()
    broadcastChat(string.format("§a[CraftConfig] Rule saved: %s (Target: %d, Batch: %d)", itemKey, targetStock, batchSize))
end

function crafting_manager.removeCraftableItem(itemKey)
    if craftableExports[itemKey] then
        craftableExports[itemKey] = nil
        persistData()
        broadcastChat(string.format("§c[CraftConfig] Rule removed: %s", itemKey))
    end
end

function crafting_manager.handleConfigSync(data)
    if not data then return end
    local act = data.action
    if act == "ADD_CRAFT" then
        crafting_manager.setCraftableItem(data.item, data.targetStock, data.batchSize)
    elseif act == "REMOVE_CRAFT" then
        crafting_manager.removeCraftableItem(data.item)
    end
end

function crafting_manager.checkCraftables()
    if not ae2_guard.isOnline(me, chatBox, MY_DIMENSION) then return end

    for itemKey, data in pairs(craftableExports) do
        local ok, stock = pcall(function() return me.getItem({ name = itemKey }) end)
        if not ok then return end
        local amount = stock and stock.amount or 0

        if amount < data.targetStock then
            broadcastChat(string.format("§6[Crafting Trigger] %s low (%d/%d). Initiating batch...", itemKey, amount, data.targetStock))
            pcall(function()
                me.craftItem({ name = itemKey, count = data.batchSize })
            end)
        end
    end
end

function crafting_manager.getCraftablesList()
    if not ae2_guard.isOnline(me, chatBox, MY_DIMENSION) then return {} end
    local success, craftables = pcall(function() return me.listCraftableItems() end)
    if not success or not craftables then return {} end

    local cleanList = {}
    for _, item in ipairs(craftables) do
        if item and item.name then
            table.insert(cleanList, {
                name        = item.name,
                count       = item.count or 0,
                displayName = item.displayName or item.name
            })
        end
    end
    return cleanList
end

function crafting_manager.getRulesList()
    local list = {}
    for itemKey, data in pairs(craftableExports) do
        table.insert(list, {
            item        = tostring(itemKey),
            targetStock = tonumber(data.targetStock) or 0,
            batchSize   = tonumber(data.batchSize) or 0
        })
    end
    return list
end


return crafting_manager
