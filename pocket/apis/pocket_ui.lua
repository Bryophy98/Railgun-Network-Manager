-- ============================================================================
-- POCKET UI HELPERS (Shared Dimension & Item Input Prompts)
-- Save as: pocket/apis/pocket_ui.lua
-- ============================================================================

local net = require("apis.pocket_net")
local pocket_ui = {}

function pocket_ui.header(title)
    term.clear()
    term.setCursorPos(1, 1)
    print(string.rep("=", 32))
    print("  " .. title)
    print(string.rep("=", 32))
end

function pocket_ui.selectDimension(promptText)
    local dimList = net.getDimensions()
    pocket_ui.header(promptText)
    for i, d in ipairs(dimList) do
        print(string.format("  %d: %s", i, string.upper(d)))
    end
    write("\nSelect (1-6, or 0 to cancel): ")
    local choice = tonumber(read())
    if not choice or choice == 0 then return nil end
    return dimList[choice]
end

function pocket_ui.acquireItemKey()
    pocket_ui.header("SELECT ITEM INPUT METHOD")
    print("1. Scan Item via Station (Off-hand)")
    print("2. Type Item ID Manually")
    write("\nChoice (1-2): ")
    local choice = read()

    if choice == "1" then
        print("\n[Pocket] Pinging scanner station...")
        return net.scanRemoteItem()
    else
        write("Enter Item ID (e.g., minecraft:iron_ingot): ")
        local input = read()
        if input and input ~= "" then return input end
    end
    return nil
end

return pocket_ui
