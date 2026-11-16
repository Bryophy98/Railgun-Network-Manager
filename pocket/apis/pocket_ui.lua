-- ============================================================================
-- POCKET PRIMEUI HELPERS (26x20 Screen Layout)
-- Save as: pocket/apis/pocket_ui.lua
-- ============================================================================

local PrimeUI = require("apis.primeui")
local net     = require("apis.pocket_net")

local pocket_ui = {}

function pocket_ui.drawFrame(title)
    PrimeUI.clear()
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.white)
    term.clearLine()
    local label = tostring(title):sub(1, 24)
    PrimeUI.centerLabel(term.current(), 1, 1, 26, label, colors.white, colors.blue)
end

function pocket_ui.status(title, line1, line2, color)
    pocket_ui.drawFrame(title)
    PrimeUI.borderBox(term.current(), 2, 4, 24, 12, color or colors.cyan, colors.black)
    if line1 then PrimeUI.centerLabel(term.current(), 2, 8, 24, tostring(line1):sub(1, 24), colors.white, colors.black) end
    if line2 then PrimeUI.centerLabel(term.current(), 2, 10, 24, tostring(line2):sub(1, 24), colors.lightGray, colors.black) end
end

function pocket_ui.selectDimension(promptTitle)
    local dims = net.getDimensions()
    local entries = {}
    for _, d in ipairs(dims) do
        table.insert(entries, string.upper(d))
    end
    table.insert(entries, "< Cancel >")

    pocket_ui.drawFrame(promptTitle)
    PrimeUI.borderBox(term.current(), 2, 4, 24, 13, colors.lightBlue, colors.black)
    PrimeUI.selectionBox(term.current(), 2, 4, 24, 13, entries, "SELECT", nil, colors.white, colors.black)
    PrimeUI.keyAction(keys.backspace, "CANCEL")

    local _, action, val = PrimeUI.run()
    if action == "CANCEL" or not val or val == "< Cancel >" then
        return nil
    end
    return string.lower(val)
end

function pocket_ui.acquireItemKey()
    pocket_ui.drawFrame("ITEM INPUT")
    PrimeUI.borderBox(term.current(), 2, 4, 24, 13, colors.cyan, colors.black)
    PrimeUI.label(term.current(), 3, 5, "Choose item source:", colors.lightGray, colors.black)

    PrimeUI.button(term.current(), 3, 7, "Scan Off-Hand (ID 12)", "SCAN", colors.black, colors.lime, colors.green)
    PrimeUI.button(term.current(), 3, 10, "Type Item ID Manual", "MANUAL", colors.white, colors.gray, colors.lightGray)
    PrimeUI.button(term.current(), 3, 14, "Cancel", "CANCEL", colors.white, colors.red, colors.gray)

    local _, action = PrimeUI.run()
    if action == "SCAN" then
        pocket_ui.status("SCANNER", "Pinging ID 12...", "Hold item in off-hand", colors.yellow)
        return net.scanRemoteItem()
    elseif action == "MANUAL" then
        pocket_ui.drawFrame("ENTER ITEM ID")
        PrimeUI.borderBox(term.current(), 2, 6, 24, 1, colors.cyan, colors.black)
        PrimeUI.label(term.current(), 2, 4, "Item ID (Enter to save):", colors.lightGray, colors.black)
        PrimeUI.inputBox(term.current(), 2, 6, 24, "SUBMIT", colors.white, colors.gray)
        PrimeUI.button(term.current(), 2, 11, "Cancel", "CANCEL", colors.white, colors.red, colors.gray)
        local _, inpAct, text = PrimeUI.run()
        if inpAct == "SUBMIT" and text and text ~= "" then
            return text
        end
    end
    return nil
end

function pocket_ui.promptNumbers(title, itemLabel)
    pocket_ui.drawFrame(title)
    PrimeUI.label(term.current(), 2, 3, tostring(itemLabel):sub(1, 24), colors.yellow, colors.black)
    PrimeUI.label(term.current(), 2, 5, "Target Minimum Stock:", colors.white, colors.black)
    PrimeUI.borderBox(term.current(), 2, 7, 24, 1, colors.cyan, colors.black)
    PrimeUI.inputBox(term.current(), 2, 7, 24, "NEXT", colors.white, colors.gray)
    PrimeUI.button(term.current(), 2, 11, "Cancel", "CANCEL", colors.white, colors.red, colors.gray)

    local _, act1, val1 = PrimeUI.run()
    local targetStock = tonumber(val1)
    if act1 ~= "NEXT" or not targetStock then return nil, nil end

    pocket_ui.drawFrame(title)
    PrimeUI.label(term.current(), 2, 3, tostring(itemLabel):sub(1, 24), colors.yellow, colors.black)
    PrimeUI.label(term.current(), 2, 5, "Batch Size:", colors.white, colors.black)
    PrimeUI.borderBox(term.current(), 2, 7, 24, 1, colors.cyan, colors.black)
    PrimeUI.inputBox(term.current(), 2, 7, 24, "DONE", colors.white, colors.gray)
    PrimeUI.button(term.current(), 2, 11, "Cancel", "CANCEL", colors.white, colors.red, colors.gray)

    local _, act2, val2 = PrimeUI.run()
    local batchSize = tonumber(val2)
    if act2 ~= "DONE" or not batchSize then return nil, nil end

    return targetStock, batchSize
end

return pocket_ui
