-- ============================================================================
-- NODE DASHBOARD API (Grayscale 51x19 Fixed Header + Scrollable Log Pane)
-- Save as: shared/apis/node_dashboard.lua
-- ============================================================================

local PrimeUI = require("apis.primeui")
local node_dashboard = {}

local logLines = {}
local MAX_LOGS = 40
local redrawLogBox = nil
local currentTitle = "NODE ONLINE"
local currentSub = ""

local function cleanText(str)
    return tostring(str or ""):gsub("§.", ""):gsub("[^\32-\126]", "")
end

local function drawHeader()
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.black)
    term.clearLine()
    PrimeUI.centerLabel(term.current(), 1, 1, 51, cleanText(currentTitle):sub(1, 49), colors.black, colors.lightGray)

    term.setCursorPos(1, 2)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.clearLine()
    PrimeUI.centerLabel(term.current(), 1, 2, 51, cleanText(currentSub):sub(1, 49), colors.white, colors.gray)
end

function node_dashboard.init(title, subtitle)
    currentTitle = title or "NODE ONLINE"
    currentSub   = subtitle or ("PC #" .. os.computerID())
    logLines     = {}

    PrimeUI.clear()
    term.setBackgroundColor(colors.black)
    term.clear()

    drawHeader()
    PrimeUI.borderBox(term.current(), 2, 4, 49, 14, colors.white, colors.black)
    redrawLogBox = PrimeUI.textBox(term.current(), 2, 4, 49, 14, "", colors.lightGray, colors.black)
end

function node_dashboard.setStatus(title, subtitle)
    if title then currentTitle = title end
    if subtitle then currentSub = subtitle end
    drawHeader()
end

function node_dashboard.log(msg)
    local text = cleanText(msg)
    table.insert(logLines, text)
    while #logLines > MAX_LOGS do
        table.remove(logLines, 1)
    end
    if redrawLogBox then
        -- Keep newest lines visible at the bottom of the 14-row window
        local startIdx = math.max(1, #logLines - 13)
        local visible = {}
        for i = startIdx, #logLines do
            table.insert(visible, logLines[i])
        end
        redrawLogBox(table.concat(visible, "\n"))
    else
        print(text)
    end
end

return node_dashboard
