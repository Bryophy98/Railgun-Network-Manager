-- ============================================================================
-- POCKET IMPORT CRUD MENU (PrimeUI 26x20 Layout)
-- Save as: pocket/apis/import_menu.lua
-- ============================================================================

local PrimeUI = require("apis.primeui")
local net     = require("apis.pocket_net")
local ui      = require("apis.pocket_ui")

local import_menu = {}

local function shortItemName(fullId)
    return tostring(fullId):match(":(.+)$") or tostring(fullId)
end

local function shortStatus(st)
    local map = {
        IDLE       = "IDLE",
        PENDING    = "PEND",
        IN_TRANSIT = "TRAN",
        COOLDOWN   = "COOL"
    }
    return map[st] or tostring(st or "IDLE"):sub(1, 4)
end

local function addOrEdit(targetDim, targetProxyId, prefillItem, prefillSupplierId)
    local itemKey = prefillItem or ui.acquireItemKey()
    if not itemKey then return end

    local targetStock, batchSize = ui.promptNumbers("IMPORT THRESHOLDS", shortItemName(itemKey))
    if not targetStock or not batchSize then return end

    local sourceProxyId = prefillSupplierId
    if not sourceProxyId then
        local sourceDim = ui.selectDimension("SUPPLIER DIMENSION")
        if not sourceDim then return end
        sourceProxyId = net.resolveProxyId(sourceDim)
    end

    if not sourceProxyId then
        ui.status("ERROR", "Supplier proxy offline", nil, colors.red)
        sleep(2)
        return
    end

    local payload = {
        action        = "ADD_IMPORT",
        item          = itemKey,
        targetStock   = targetStock,
        batchSize     = batchSize,
        sourceProxyId = sourceProxyId
    }

    ui.status("SAVING RULE", "Sending to " .. targetDim:upper(), nil, colors.cyan)
    if net.sendAndAwait(targetProxyId, "CONFIG_SYNC", payload, "ACK", 3) then
        ui.status("SUCCESS", "Import rule saved!", nil, colors.lime)
    else
        ui.status("TIMEOUT", "No ACK from gateway", nil, colors.red)
    end
    sleep(1.5)
end

function import_menu.run()
    local targetDim = ui.selectDimension("IMPORTS: SELECT DEPOT")
    if not targetDim then return end

    local targetProxyId = net.resolveProxyId(targetDim)
    if not targetProxyId then
        ui.status("OFFLINE", "Proxy not found:", targetDim:upper(), colors.red)
        sleep(2)
        return
    end

    while true do
        ui.status(targetDim:upper() .. " IMPORTS", "Fetching rules...", nil, colors.cyan)
        local imports = net.sendAndAwait(targetProxyId, "GET_IMPORTS", nil, "IMPORTS_RESPONSE", 4) or {}

        ui.drawFrame(string.format("%s IMPORTS (%d)", targetDim:upper(), #imports))

        local selectedIdx = 1
        local entries = {}
        if #imports == 0 then
            entries = { "(No import rules)" }
        else
            for _, rule in ipairs(imports) do
                local name = shortItemName(rule.item):sub(1, 16)
                local st   = shortStatus(rule.status)
                table.insert(entries, string.format("%-16s [%s]", name, st))
            end
        end

        PrimeUI.borderBox(term.current(), 2, 3, 24, 9, colors.cyan, colors.black)
        PrimeUI.selectionBox(term.current(), 2, 3, 24, 9, entries, "ENTER_ITEM", function(idx)
            selectedIdx = idx
            local r = imports[idx]
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

        if imports[1] then
            local r = imports[1]
            PrimeUI.label(term.current(), 2, 14, shortItemName(r.item):sub(1, 24), colors.yellow, colors.black)
            PrimeUI.label(term.current(), 2, 15, string.format("Min:%d Batch:%d", r.targetStock or 0, r.batchSize or 0):sub(1, 24), colors.lightGray, colors.black)
        end

        PrimeUI.button(term.current(), 1, 18, "Add", "ADD", colors.black, colors.lime, colors.green)
        if #imports > 0 then
            PrimeUI.button(term.current(), 7, 18, "Edit", "EDIT", colors.black, colors.yellow, colors.orange)
            PrimeUI.button(term.current(), 14, 18, "Del", "DEL", colors.white, colors.red, colors.gray)
        end
        PrimeUI.button(term.current(), 20, 18, "Back", "BACK", colors.white, colors.gray, colors.lightGray)
        PrimeUI.keyAction(keys.backspace, "BACK")

        local _, action = PrimeUI.run()
        if action == "ADD" then
            addOrEdit(targetDim, targetProxyId)
        elseif (action == "EDIT" or action == "ENTER_ITEM") and imports[selectedIdx] then
            local sel = imports[selectedIdx]
            addOrEdit(targetDim, targetProxyId, sel.item, sel.sourceProxyId)
        elseif action == "DEL" and imports[selectedIdx] then
            local sel = imports[selectedIdx]
            ui.status("DELETING", shortItemName(sel.item), nil, colors.red)
            net.sendAndAwait(targetProxyId, "CONFIG_SYNC", { action = "REMOVE_IMPORT", item = sel.item }, "ACK", 3)
            sleep(1)
        elseif action == "BACK" then
            return
        end
    end
end

return import_menu
