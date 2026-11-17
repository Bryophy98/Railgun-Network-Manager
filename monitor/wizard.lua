-- ============================================================================
-- MONITOR WIZARD API (Grayscale PrimeUI Dimension & Railgun Route Setup)
-- Save as: monitor/wizard.lua
-- ============================================================================

local PrimeUI = require("apis.primeui")
local wizard  = {}

local VALID_DIMS = { "earth", "beneath", "moon", "mars", "venus", "mercury" }

local function drawBanner(title)
    PrimeUI.clear()
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.black)
    term.clearLine()
    PrimeUI.centerLabel(term.current(), 1, 1, 51, title:sub(1, 49), colors.black, colors.lightGray)
end

function wizard.load()
    if fs.exists("data/config.dat") then
        local f = fs.open("data/config.dat", "r")
        local data = textutils.unserialize(f.readAll())
        f.close()
        if type(data) == "table" and data.dimension and type(data.routes) == "table" then
            return data
        end
    end
    return nil
end

function wizard.run()
    -- Step 1: Select home dimension for this Monitor PC
    local dimEntries = {}
    for _, dim in ipairs(VALID_DIMS) do
        table.insert(dimEntries, string.upper(dim))
    end

    drawBanner("MONITOR WIZARD: HOME DIMENSION")
    PrimeUI.label(term.current(), 4, 3, "Select this Monitor's home dimension:", colors.lightGray, colors.black)
    PrimeUI.borderBox(term.current(), 4, 5, 45, 9, colors.white, colors.black)
    PrimeUI.selectionBox(term.current(), 4, 5, 45, 9, dimEntries, "SELECT", nil, colors.white, colors.black)
    PrimeUI.label(term.current(), 4, 16, "Click or press Enter to confirm.", colors.gray, colors.black)

    local _, _, chosenHome = PrimeUI.run()
    local homeDim = string.lower(chosenHome or "earth")

    -- Step 2: Gather attached peripherals (excluding computer sides & bridges/modems/chatBoxes)
    local ignoredTypes = {
        modem    = true,
        meBridge = true,
        chatBox  = true
    }

    local periphList = { "< Skip / No Route >" }
    for _, name in ipairs(peripheral.getNames()) do
        local pType = peripheral.getType(name)
        if not ignoredTypes[pType] then
            table.insert(periphList, name .. " (" .. tostring(pType) .. ")")
        end
    end

    -- Step 3: Loop through each destination dimension to assign its output peripheral
    local routes = {}
    for _, destDim in ipairs(VALID_DIMS) do
        if destDim ~= homeDim then
            drawBanner("ROUTE: " .. homeDim:upper() .. " -> " .. destDim:upper())
            PrimeUI.label(term.current(), 4, 3, "Select railgun/chest peripheral for " .. destDim:upper() .. ":", colors.lightGray, colors.black)
            PrimeUI.borderBox(term.current(), 4, 5, 45, 9, colors.white, colors.black)
            PrimeUI.selectionBox(term.current(), 4, 5, 45, 9, periphList, "PICK", nil, colors.white, colors.black)
            PrimeUI.button(term.current(), 4, 16, "Skip Route", "SKIP", colors.white, colors.gray, colors.lightGray)

            local _, act, picked = PrimeUI.run()
            if act ~= "SKIP" and picked and picked ~= "< Skip / No Route >" then
                -- Extract exact peripheral name before " (type)"
                local periphName = picked:match("^(.-) %(") or picked
                routes[destDim] = periphName
            end
        end
    end

    PrimeUI.clear()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)

    if not fs.exists("data") then
        fs.makeDir("data")
    end

    local config = {
        dimension = homeDim,
        routes    = routes
    }

    local f = fs.open("data/config.dat", "w")
    f.write(textutils.serialize(config))
    f.close()

    return config
end

return wizard
