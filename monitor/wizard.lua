-- ============================================================================
-- WIZARD MODULE (First-Time Dimension & Railgun Peripheral Routing)
-- Save as: wizard.lua
-- ============================================================================

local module = {}

function module.run()
    term.clear()
    term.setCursorPos(1, 1)
    print("=== Interdimensional Depot Setup ===")
    
    local dimList = {"earth", "beneath", "moon", "mars", "venus", "mercury"}
    print("Select this computer's dimension location:")
    for i, d in ipairs(dimList) do
        print(string.format("  %d: %s", i, string.upper(d)))
    end
    
    write("\nSelect option (1-6): ")
    local dimChoice = tonumber(read()) or 1
    local dimName = dimList[dimChoice] or "earth"

    -- Find connected loader/exporter peripherals (e.g., item loaders, railguns, export buses)
    local allPeriphs = peripheral.getNames()
    local busPeriphs = {}
    for _, name in ipairs(allPeriphs) do
        -- Broad search for loader, export, or inventory peripherals
        if string.find(string.lower(name), "loader") or string.find(string.lower(name), "export") or string.find(string.lower(name), "inventory") then
            table.insert(busPeriphs, name)
        end
    end

    print(string.format("\n[%s Selected]", string.upper(dimName)))
    print("--- Railgun / Exporter Peripheral Routing ---")
    print("Assign a dedicated peripheral per destination dimension.")
    
    local routes = {}
    for _, targetDim in ipairs(dimList) do
        if targetDim ~= dimName then
            print(string.format("\nTarget Destination: [%s]", string.upper(targetDim)))
            if #busPeriphs == 0 then
                print("    [!] No suitable peripherals found. Skipping route.")
            else
                for i, bName in ipairs(busPeriphs) do
                    print(string.format("      %d: %s", i, bName))
                end
                print("      0: None")
                write("    Select peripheral number: ")
                local bChoice = tonumber(read())
                if bChoice and bChoice > 0 and busPeriphs[bChoice] then
                    routes[targetDim] = busPeriphs[bChoice]
                end
            end
        end
    end

    local newConfig = { 
        dimension = dimName, 
        routes = routes 
    }
    
    -- Use the storage API convention or direct serialization
    local file = fs.open("data/config.dat", "w")
    if file then
        file.write(textutils.serialize(newConfig))
        file.close()
    end
    
    print("\n[SUCCESS] Configuration saved! Initializing depot...")
    sleep(1.5)
end

function module.load()
    if fs.exists("data/config.dat") then
        local file = fs.open("data/config.dat", "r")
        local content = file.readAll()
        file.close()
        return textutils.unserialize(content)
    end
    return nil
end

return module