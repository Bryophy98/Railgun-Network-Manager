-- ============================================================================
-- POCKET CRAFTING CRUD MENU
-- Save as: pocket/apis/craft_menu.lua
-- ============================================================================

local net = require("apis.pocket_net")
local ui  = require("apis.pocket_ui")

local craft_menu = {}

local function addOrEdit(targetDim, targetProxyId, prefillItem)
    local itemKey = prefillItem or ui.acquireItemKey()
    if not itemKey then return end

    write("Target Minimum Stock: ")
    local targetStock = tonumber(read())
    write("Crafting Batch Size: ")
    local batchSize = tonumber(read())

    if not targetStock or not batchSize then
        print("\n§cInvalid numeric values!")
        sleep(2)
        return
    end

    local payload = {
        action      = "ADD_CRAFT",
        item        = itemKey,
        targetStock = targetStock,
        batchSize   = batchSize
    }

    ui.header("SAVING CRAFTING RULE")
    print("Sending to " .. targetDim:upper() .. "...")
    if net.sendAndAwait(targetProxyId, "CONFIG_SYNC", payload, "ACK", 3) then
        print("\n§aCrafting rule saved!")
    else
        print("\n§cFailed to reach target proxy.")
    end
    sleep(1.5)
end

function craft_menu.run()
    local targetDim = ui.selectDimension("MANAGE CRAFTING FOR DIMENSION")
    if not targetDim then return end

    local targetProxyId = net.resolveProxyId(targetDim)
    if not targetProxyId then
        print("\n§cCould not resolve proxy for: " .. targetDim)
        sleep(2)
        return
    end

    while true do
        ui.header("CRAFTING: " .. targetDim:upper())
        print("Fetching rules...")
        local rules = net.sendAndAwait(targetProxyId, "GET_CRAFT_RULES", nil, "CRAFT_RULES_RESPONSE", 4)

        ui.header("CRAFTING: " .. targetDim:upper())
        if not rules or #rules == 0 then
            print("\nNo active crafting rules found.")
            print("\n[A] Add Rule | Back")
            write("Choice: ")
            if string.lower(read()) == "a" then
                addOrEdit(targetDim, targetProxyId)
            else
                return
            end
        else
            for i, rule in ipairs(rules) do
                print(string.format("%d. %s", i, tostring(rule.item)))
                print(string.format("   Stock: %d | Batch: %d", tonumber(rule.targetStock) or 0, tonumber(rule.batchSize) or 0))
            end

            print("\n[A] Add | [E] Edit # | [D] Delete # | Back")
            write("Choice: ")
            local act = string.lower(read())

            if act == "a" then
                addOrEdit(targetDim, targetProxyId)
            elseif act == "e" then
                write("Rule # to edit: ")
                local selected = rules[tonumber(read()) or 0]
                if selected then
                    addOrEdit(targetDim, targetProxyId, selected.item)
                end
            elseif act == "d" then
                write("Rule # to delete: ")
                local selected = rules[tonumber(read()) or 0]
                if selected then
                    net.sendAndAwait(targetProxyId, "CONFIG_SYNC", { action = "REMOVE_CRAFT", item = selected.item }, "ACK", 3)
                    print("§cDeleted " .. selected.item)
                    sleep(1.5)
                end
            else
                return
            end
        end
    end
end

return craft_menu
