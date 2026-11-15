-- ============================================================================
-- AE2 POWER & ME BRIDGE HEALTH GUARD
-- Save as: shared/apis/ae2_guard.lua
-- ============================================================================

local ae2_guard = {}

local wasPowered = true
local missingBridgeWarned = false

local function sendChatAlert(chatBox, message)
    print(message)
    if not chatBox then return end
    pcall(function()
        if chatBox.sendMessage then
            chatBox.sendMessage(message)
        elseif chatBox.say then
            chatBox.say(message)
        end
    end)
end

function ae2_guard.isOnline(me, chatBox, dimensionName)
    local dimLabel = string.upper(dimensionName or "UNKNOWN")

    if not me then
        if not missingBridgeWarned then
            sendChatAlert(chatBox, string.format("§4[AE2 ALERT - %s] ME Bridge missing! Logistics paused.", dimLabel))
            missingBridgeWarned = true
        end
        return false
    end
    missingBridgeWarned = false

    local ok, energy = pcall(function()
        return me.getEnergyStored()
    end)

    local hasPower = ok and type(energy) == "number" and energy > 0

    if not hasPower then
        if wasPowered then
            sendChatAlert(chatBox, string.format("§4[POWER OUTAGE - %s] AE2 network has no power! Logistics paused.", dimLabel))
            wasPowered = false
        end
        return false
    end

    if not wasPowered then
        sendChatAlert(chatBox, string.format("§a[POWER RESTORED - %s] AE2 network online. Logistics resumed.", dimLabel))
        wasPowered = true
    end

    return true
end

return ae2_guard
