-- ============================================================================
-- CRAFTING MANAGER API (Local Stock & Auto-Craft Microservice)
-- Save as: apis/crafting_manager.lua
-- ============================================================================

local storage = require("apis.storage")
local crafting_manager = {}

local proxyTargetId = nil
local localProtocol = "local_proxy_link"

local me = nil
local chatBox = nil
local craftableExports = {}

function crafting_manager.init(meRef, chatRef)
    me = meRef
    chatBox = chatRef
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
    if chatBox then chatBox.say(message) end
end

function crafting_manager.setCraftableItem(itemKey, targetStock, batchSize)
    craftableExports[itemKey] = {
        targetStock = targetStock,
        batchSize = batchSize
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
    local act = data.action
    if act == "ADD_CRAFT" then
        crafting_manager.setCraftableItem(data.item, data.targetStock, data.batchSize)
    elseif act == "REMOVE_CRAFT" then
        crafting_manager.removeCraftableItem(data.item)
    end
end

function crafting_manager.checkCraftables()
    if not me then return end
    for itemKey, data in pairs(craftableExports) do
        local stock = me.getItem({name = itemKey})
        local amount = stock and stock.amount or 0
        
        if amount < data.targetStock then
            broadcastChat(string.format("§6[Crafting Trigger] %s low (%d/%d). Initiating batch...", itemKey, amount, data.targetStock))
            pcall(function() 
                me.craftItem({name = itemKey, count = data.batchSize}) 
            end)
        end
    end
end

function crafting_manager.getCraftablesList()
    if not me then return {} end
    local success, craftables = pcall(function() return me.listCraftableItems() end)
    
    if not success or not craftables then return {} end
    
    local cleanList = {}
    for _, item in ipairs(craftables) do
        if item and item.name then
            table.insert(cleanList, {
                name = item.name,
                count = item.count or 0,
                displayName = item.displayName or item.name
            })
        end
    end
    return cleanList
end

return crafting_manager