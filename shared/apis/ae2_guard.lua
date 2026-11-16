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

local function checkNetworkLive(me)
    local methods = { "getEnergyStorage", "getEnergyStored", "getStoredEnergy", "getEnergyUsage" }
    for _, method in ipairs(methods) do
        if type(me[method]) == "function" then
            local ok, r1, r2 = pcall(me[method])
            if ok then
                -- Case 1: returns (boolean, number) e.g. true, 125000
                if type(r1) == "boolean" then
                    if r1 and type(r2) == "number" and r2 > 0 then
                        return true
                    end
                -- Case 2: returns (number) directly e.g. 125000
                elseif type(r1) == "number" and r1 > 0 then
                    return true
                end
            end
        end
    end
    return false
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

    local hasPower = checkNetworkLive(me)

    if not hasPower then
        if wasPowered then
            sendChatAlert(chatBox, string.format("§4[POWER OUTAGE - %s] AE2 network has no power! Logistics paused.", dimLabel))
            wasPowered = false
        end
        return false
    end

    if not wasPowered then
        sendChatAlert(chatBox, string.format("§a[POWER RESTORED - %s] AE2 network back online. Logistics resumed.", dimLabel))
        wasPowered = true
    end

    return true
end

return ae2_guard
