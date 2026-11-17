-- ============================================================================
-- INVENTORY SCANNER STATION (Grayscale PrimeUI Dashboard)
-- Save as: Scanner/scanner_pc.lua
-- ============================================================================

local dash = require("apis.node_dashboard")

local SCAN_PROTOCOL = "scanner_link"
local invManager    = peripheral.find("inventoryManager")

if not invManager then
    error("No Inventory Manager attached to Scanner PC!")
end

for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "modem" then
        rednet.open(name)
    end
end

dash.init(
    "OFF-HAND SCANNER STATION",
    string.format("PC #%d | Protocol: %s | Ready", os.computerID(), SCAN_PROTOCOL)
)
_G.print = dash.log
dash.log("[Scanner] Listening for Pocket PC scan requests...")

while true do
    local senderId, msg, protocol = rednet.receive(SCAN_PROTOCOL)
    if type(msg) == "table" and msg.type == "GET_OFFHAND_ITEM" then
        dash.log(string.format("[Scan] Request from Pocket PC #%d", senderId))

        local ok, item = pcall(function() return invManager.getItemInOffHand() end)
        if ok and item and item.name then
            dash.log(string.format("[Scan] Found: %s (x%d)", item.name, item.count or 1))
            rednet.send(senderId, {
                type    = "OFFHAND_ITEM_RESPONSE",
                id      = msg.id,
                success = true,
                item    = {
                    name        = item.name,
                    displayName = item.displayName or item.name,
                    count       = item.count or 1
                }
            }, SCAN_PROTOCOL)
        else
            dash.log("[Scan] Failed: Off-hand empty or player out of range.")
            rednet.send(senderId, {
                type    = "OFFHAND_ITEM_RESPONSE",
                id      = msg.id,
                success = false,
                reason  = "Off-hand empty or player out of range."
            }, SCAN_PROTOCOL)
        end
    end
end
