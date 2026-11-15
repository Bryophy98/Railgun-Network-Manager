-- ============================================================================
-- PROXY WIZARD MODULE (First-Time Dimension Configuration)
-- Save as: proxy_wizard.lua
-- ============================================================================

local module = {}

function module.run()
    term.clear()
    term.setCursorPos(1, 1)
    print("=== Interdimensional Proxy Setup ===")
    
    local dimList = {"earth", "beneath", "moon", "mars", "venus", "mercury"}
    print("Select this Proxy PC's dimension location:")
    for i, d in ipairs(dimList) do
        print(string.format("  %d: %s", i, string.upper(d)))
    end
    
    write("\nSelect option (1-6): ")
    local dimChoice = tonumber(read()) or 1
    local dimName = dimList[dimChoice] or "earth"

    local newConfig = { 
        dimension = dimName,
        monitorId = nil -- Will be populated automatically upon first contact
    }
    
    if not fs.exists("data") then
        fs.makeDir("data")
    end
    
    local file = fs.open("data/config.dat", "w")
    if file then
        file.write(textutils.serialize(newConfig))
        file.close()
    end
    
    print(string.format("\n[SUCCESS] Proxy configured for [%s]!", string.upper(dimName)))
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