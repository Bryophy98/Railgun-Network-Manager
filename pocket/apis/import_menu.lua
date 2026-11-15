-- ============================================================================
-- POCKET IMPORT CRUD MENU
-- Save as: pocket/apis/import_menu.lua
-- ============================================================================

local net = require("apis.pocket_net")
local ui  = require("apis.pocket_ui")

local import_menu = {}

local function addOrEdit(targetDim, targetProxyId, prefillItem, prefillSupplierId)
    local itemKey = prefillItem or ui.acquireItemKey()
    if not itemKey then return end

    write("Target Minimum Stock: ")
    local targetStock = tonumber(read())
    write("Shipment Batch Size: ")
    local batchSize = tonumber(read())

    local sourceProxyId = prefillSupplierId
    if not sourceProxyId then
        local sourceDim = ui.selectDimension("SELECT SUPPLIER DEPOT")
        if not sourceDim then return end
        sourceProxyId = net.resolveProxyId(sourceDim)
    end

    if not targetStock or not batchSize or not sourceProxyId then
        print("\n§cInvalid numeric values or supplier proxy!")
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

    ui.header("SAVING IMPORT RULE")
    print("Sending to " .. targetDim:upper() .. "...")
    if net.sendAndAwait(targetProxyId, "CONFIG_SYNC", payload, "ACK", 3) then
        print("\n§aImport rule saved!")
    else
        print("\n§cFailed to reach target proxy.")
    end
    sleep(1.5)
end

function import_menu.run()
    local targetDim = ui.selectDimension("MANAGE IMPORTS FOR DIMENSION")
    if not targetDim then return end

    local targetProxyId = net.resolveProxyId(targetDim)
    if not targetProxyId then
        print("\n§cCould not resolve proxy for: " .. targetDim)
        sleep(2)
        return
    end

    while true do
        ui.header("IMPORTS: " .. targetDim:upper())
        print("Fetching rules...")
        local imports = net.sendAndAwait(targetProxyId, "GET_IMPORTS", nil, "IMPORTS_RESPONSE", 4)

        ui.header("IMPORTS: " .. targetDim:upper())
        if not imports or #imports == 0 then
            print("\nNo active import rules found.")
            print("\n[A] Add Rule | Back")
            write("Choice: ")
            if string.lower(read()) == "a" then
                addOrEdit(targetDim, targetProxyId)
            else
                return
            end
        else
            for i, rule in ipairs(imports) do
                print(string.format("%d. %s [%s]", i, tostring(rule.item), tostring(rule.status or "IDLE")))
                print(string.format("   Stock: %d | Batch: %d", tonumber(rule.targetStock) or 0, tonumber(rule.batchSize) or 0))
            end

            print("\n[A] Add | [E] Edit # | [D] Delete # | Back")
            write("Choice: ")
            local act = string.lower(read())

            if act == "a" then
                addOrEdit(targetDim, targetProxyId)
            elseif act == "e" then
                write("Rule # to edit: ")
                local selected = imports[tonumber(read()) or 0]
                if selected then
                    addOrEdit(targetDim, targetProxyId, selected.item, selected.sourceProxyId)
                end
            elseif act == "d" then
                write("Rule # to delete: ")
                local selected = imports[tonumber(read()) or 0]
                if selected then
                    net.sendAndAwait(targetProxyId, "CONFIG_SYNC", { action = "REMOVE_IMPORT", item = selected.item }, "ACK", 3)
                    print("§cDeleted " .. selected.item)
                    sleep(1.5)
                end
            else
                return
            end
        end
    end
end

return import_menu
