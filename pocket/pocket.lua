-- ============================================================================
-- POCKET PC REMOTE MANAGER (Imports Viewer Added)
-- Save as: pocket.lua
-- ============================================================================

local net = require("apis.pocket_net")
net.init()

local DIM_LIST = net.getDimensions()

local function selectDimension(promptText)
    term.clear()
    term.setCursorPos(1, 1)
    print("=== " .. promptText .. " ===")
    for i, d in ipairs(DIM_LIST) do
        print(string.format("  %d: %s", i, string.upper(d)))
    end
    write("\nSelect option (1-6): ")
    local choice = tonumber(read())
    return DIM_LIST[choice]
end

local function acquireItemKey()
    term.clear()
    term.setCursorPos(1, 1)
    print("=== SELECT ITEM INPUT METHOD ===")
    print("1. Scan Item via Station (Off-hand/Slot 1)")
    print("2. Type Item ID Manually")
    write("Choice (1-2): ")
    local choice = read()

    if choice == "1" then
        print("\n[Pocket] Pinging scanner station...")
        return net.scanRemoteItem()
    else
        write("Enter Item ID (e.g., minecraft:iron_ingot): ")
        local input = read()
        if input and input ~= "" then
            return input
        end
    end
    return nil
end

local function addImportFlow()
    local targetDim = selectDimension("SELECT TARGET DEPOT")
    if not targetDim then return end
    local targetProxyId = net.resolveProxyId(targetDim)
    if not targetProxyId then
        print("\n§cCould not resolve proxy for: " .. targetDim)
        sleep(2)
        return
    end

    local itemKey = acquireItemKey()
    if not itemKey then 
        print("\n§cNo item key provided. Aborting.")
        sleep(2)
        return 
    end

    write("Target Minimum Stock: ")
    local targetStock = tonumber(read())
    write("Shipment Batch Size: ")
    local batchSize = tonumber(read())

    local sourceDim = selectDimension("SELECT SUPPLIER DEPOT")
    if not sourceDim then return end
    local sourceProxyId = net.resolveProxyId(sourceDim)

    if not targetStock or not batchSize or not sourceProxyId then
        print("\n§cInvalid numeric values or supplier proxy!")
        sleep(2)
        return
    end

    local payload = {
        action = "ADD_IMPORT",
        item = itemKey,
        targetStock = targetStock,
        batchSize = batchSize,
        sourceProxyId = sourceProxyId
    }

    term.clear()
    print("Sending configuration to " .. targetDim:upper() .. "...")
    if net.sendAndAwait(targetProxyId, "CONFIG_SYNC", payload, "ACK", 3) then
        print("\n§aImport rule saved successfully!")
    else
        print("\n§cFailed to reach target proxy.")
    end
    sleep(2)
end

local function addCraftableFlow()
    local targetDim = selectDimension("SELECT MANUFACTURING DEPOT")
    if not targetDim then return end
    local targetProxyId = net.resolveProxyId(targetDim)
    if not targetProxyId then
        print("\n§cCould not resolve proxy for: " .. targetDim)
        sleep(2)
        return
    end

    local itemKey = acquireItemKey()
    if not itemKey then 
        print("\n§cNo item key provided. Aborting.")
        sleep(2)
        return 
    end

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
        action = "ADD_CRAFT",
        item = itemKey,
        targetStock = targetStock,
        batchSize = batchSize
    }

    term.clear()
    print("Sending craftable config to " .. targetDim:upper() .. "...")
    if net.sendAndAwait(targetProxyId, "CONFIG_SYNC", payload, "ACK", 3) then
        print("\n§aCraftable export rule saved successfully!")
    else
        print("\n§cFailed to reach target proxy.")
    end
    sleep(2)
end

local function viewImportsFlow()
    local targetDim = selectDimension("VIEW IMPORTS FOR DIMENSION")
    if not targetDim then return end
    local targetProxyId = net.resolveProxyId(targetDim)
    if not targetProxyId then
        term.clear()
        term.setCursorPos(1, 1)
        print("Could not resolve proxy for: " .. targetDim)
        sleep(2)
        return
    end

    term.clear()
    term.setCursorPos(1, 1)
    print(string.format("Fetching imports from %s...", targetDim:upper()))

    local imports = net.sendAndAwait(targetProxyId, "GET_IMPORTS", nil, "IMPORTS_RESPONSE", 4)
    
    term.clear()
    term.setCursorPos(1, 1)
    print(string.rep("=", 30))
    print(string.format(" IMPORTS: %s", targetDim:upper()))
    print(string.rep("=", 30))

    if not imports or #imports == 0 then
        print("\nNo active import rules found.")
    else
        for i, rule in ipairs(imports) do
            print(string.format("%d. %s", i, tostring(rule.item)))
            print(string.format("   Stock: %d | Batch: %d", tonumber(rule.targetStock) or 0, tonumber(rule.batchSize) or 0))
        end
    end

    print("\nPress Enter to return...")
    read()
end

-- ============================================================================
-- MAIN LOOP
-- ============================================================================
while true do
    term.clear()
    term.setCursorPos(1, 1)
    print("============================")
    print("  CROSS-DIM DEPOT MANAGER   ")
    print("============================")
    print("1. Add Import Rule")
    print("2. Add Craftable Export")
    print("3. View Active Imports")
    print("4. Exit")
    print("----------------------------")
    write("Select option (1-4): ")
    
    local choice = read()
    if choice == "1" then
        addImportFlow()
    elseif choice == "2" then
        addCraftableFlow()
    elseif choice == "3" then
        viewImportsFlow()
    elseif choice == "4" then
        term.clear()
        term.setCursorPos(1, 1)
        print("Exiting Manager.")
        break
    end
end