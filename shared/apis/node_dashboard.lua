-- ============================================================================
-- NODE DASHBOARD API (Grayscale 51x19 Fixed Header + Recursion-Safe Log Pane)
-- Save as: shared/apis/node_dashboard.lua
-- ============================================================================

local PrimeUI = require("apis.primeui")
local node_dashboard = {}

local rawPrint = _G.print
local logWin   = nil
local logLines = {}
local MAX_LOGS = 14
local currentTitle = "NODE ONLINE"
local currentSub   = ""

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

local function redrawLogs()
    if not logWin then return end
    logWin.setVisible(false)
    logWin.setBackgroundColor(colors.black)
    logWin.setTextColor(colors.lightGray)
    logWin.clear()

    local startIdx = math.max(1, #logLines - (MAX_LOGS - 1))
    local row = 1
    for i = startIdx, #logLines do
        logWin.setCursorPos(1, row)
        logWin.write(logLines[i]:sub(1, 49))
        row = row + 1
    end
    logWin.setVisible(true)
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
    logWin = window.create(term.current(), 2, 4, 49, 14)
    redrawLogs()
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
    if logWin then
        redrawLogs()
    else
        rawPrint(text)
    end
end

return node_dashboard
