-- ============================================================================
-- POCKET CRAFTING CRUD MENU (PrimeUI 26x20 Layout)
-- Save as: pocket/apis/craft_menu.lua
-- ============================================================================

local PrimeUI = require("apis.primeui")
local net     = require("apis.pocket_net")
local ui      = require("apis.pocket_ui")

local craft_menu = {}

local function shortItemName(fullId)
    return tostring(fullId):match(":(.+)$") or tostring(fullId)
end

local function addOrEdit(targetDim, targetProxyId, prefillItem)
    local itemKey = prefillItem or ui.acquireItemKey()
    if not itemKey then return end

    local targetStock, batchSize = ui.promptNumbers("CRAFT THRESHOLDS", shortItemName(itemKey))
    if not targetStock or not batchSize then return end

    local payload = {
        action      = "ADD_CRAFT",
        item        = itemKey,
        targetStock = targetStock,
        batchSize   = batchSize
    }

    ui.status("SAVING CRAFT", "Sending to " .. targetDim:upper(), nil, colors.cyan)
    if net.sendAndAwait(targetProxyId, "CONFIG_SYNC", payload, "ACK", 3) then
        ui.status("SUCCESS", "Crafting rule saved!", nil, colors.lime)
    else
        ui.status("TIMEOUT", "No ACK from gateway", nil, colors.red)
    end
    sleep(1.5)
end

function craft_menu.run()
    local targetDim = ui.selectDimension("CRAFTING: SELECT DEPOT")
    if not targetDim then return end

    local targetProxyId = net.resolveProxyId(targetDim)
    if not targetProxyId then
        ui.status("OFFLINE", "Proxy not found:", targetDim:upper(), colors.red)
        sleep(2)
        return
    end

    while true do
        ui.status(targetDim:upper() .. " CRAFTING", "Fetching rules...", nil, colors.cyan)
        local rules = net.sendAndAwait(targetProxyId, "GET_CRAFT_RULES", nil, "CRAFT_RULES_RESPONSE", 4) or {}

        ui.drawFrame(string.format("%s CRAFT (%d)", targetDim:upper(), #rules))

        local selectedIdx = 1
        local entries = {}
        if #rules == 0 then
            entries = { "(No crafting rules)" }
        else
            for _, rule in ipairs(rules) do
                local name = shortItemName(rule.item):sub(1, 17)
                table.insert(entries, string.format("%-17s %4d", name, tonumber(rule.targetStock) or 0))
            end
        end

        PrimeUI.borderBox(term.current(), 2, 3, 24, 9, colors.orange, colors.black)
        PrimeUI.selectionBox(term.current(), 2, 3, 24, 9, entries, "ENTER_ITEM", function(idx)
            selectedIdx = idx
            local r = rules[idx]
            term.setCursorPos(2, 14)
            term.setBackgroundColor(colors.black)
            term.clearLine()
            term.setCursorPos(2, 15)
            term.clearLine()
            if r then
                PrimeUI.label(term.current(), 2, 14, shortItemName(r.item):sub(1, 24), colors.yellow, colors.black)
                PrimeUI.label(term.current(), 2, 15, string.format("Min:%d Batch:%d", r.targetStock or 0, r.batchSize or 0):sub(1, 24), colors.lightGray, colors.black)
            end
        end, colors.white, colors.black)

        if rules[1] then
            local r = rules[1]
            PrimeUI.label(term.current(), 2, 14, shortItemName(r.item):sub(1, 24), colors.yellow, colors.black)
            PrimeUI.label(term.current(), 2, 15, string.format("Min:%d Batch:%d", r.targetStock or 0, r.batchSize or 0):sub(1, 24), colors.lightGray, colors.black)
        end

        PrimeUI.button(term.current(), 1, 18, "Add", "ADD", colors.black, colors.lime, colors.green)
        if #rules > 0 then
            PrimeUI.button(term.current(), 7, 18, "Edit", "EDIT", colors.black, colors.yellow, colors.orange)
            PrimeUI.button(term.current(), 14, 18, "Del", "DEL", colors.white, colors.red, colors.gray)
        end
        PrimeUI.button(term.current(), 20, 18, "Back", "BACK", colors.white, colors.gray, colors.lightGray)
        PrimeUI.keyAction(keys.backspace, "BACK")

        local _, action = PrimeUI.run()
        if action == "ADD" then
            addOrEdit(targetDim, targetProxyId)
        elseif (action == "EDIT" or action == "ENTER_ITEM") and rules[selectedIdx] then
            local sel = rules[selectedIdx]
            addOrEdit(targetDim, targetProxyId, sel.item)
        elseif action == "DEL" and rules[selectedIdx] then
            local sel = rules[selectedIdx]
            ui.status("DELETING", shortItemName(sel.item), nil, colors.red)
            net.sendAndAwait(targetProxyId, "CONFIG_SYNC", { action = "REMOVE_CRAFT", item = sel.item }, "ACK", 3)
            sleep(1)
        elseif action == "BACK" then
            return
        end
    end
end

return craft_menu
