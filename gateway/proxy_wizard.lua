-- ============================================================================
-- PROXY WIZARD API (Grayscale PrimeUI First-Time Dimension Setup)
-- Save as: gateway/proxy_wizard.lua
-- ============================================================================

local PrimeUI = require("apis.primeui")
local wizard  = {}

local VALID_DIMS = { "earth", "beneath", "moon", "mars", "venus", "mercury" }

function wizard.load()
    if fs.exists("data/config.dat") then
        local f = fs.open("data/config.dat", "r")
        local data = textutils.unserialize(f.readAll())
        f.close()
        if type(data) == "table" and data.dimension then
            return data
        end
    end
    return nil
end

function wizard.run()
    local entries = {}
    for _, dim in ipairs(VALID_DIMS) do
        table.insert(entries, string.upper(dim))
    end

    PrimeUI.clear()
    term.setBackgroundColor(colors.black)
    term.clear()

    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.black)
    term.clearLine()
    PrimeUI.centerLabel(term.current(), 1, 1, 51, "GATEWAY SETUP WIZARD (PC #" .. os.computerID() .. ")", colors.black, colors.lightGray)

    PrimeUI.label(term.current(), 4, 3, "Select this Gateway's dimension:", colors.lightGray, colors.black)
    PrimeUI.borderBox(term.current(), 4, 5, 45, 9, colors.white, colors.black)
    PrimeUI.selectionBox(term.current(), 4, 5, 45, 9, entries, "SELECT", nil, colors.white, colors.black)
    PrimeUI.label(term.current(), 4, 16, "Use Arrow Keys + Enter or Click to confirm.", colors.gray, colors.black)

    local _, _, chosen = PrimeUI.run()
    PrimeUI.clear()

    local selectedDim = string.lower(chosen or "earth")

    if not fs.exists("data") then
        fs.makeDir("data")
    end

    local config = {
        dimension  = selectedDim,
        monitorId  = nil,
        craftingId = nil
    }

    local f = fs.open("data/config.dat", "w")
    f.write(textutils.serialize(config))
    f.close()

    return config
end

return wizard
