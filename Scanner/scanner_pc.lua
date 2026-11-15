-- ============================================================================
-- INVENTORY MANAGER SCANNER PC (Ender Top, Local Bottom)
-- Save as: scanner_pc.lua
-- ============================================================================

local SCAN_PROTOCOL = "scanner_link"

-- Open local modem on the bottom side
if peripheral.getType("top") == "modem" then
    rednet.open("top")
    print("[Init] Rednet opened on bottom modem.")
else
    error("No modem found on the bottom side!")
end

local inv = peripheral.find("inventoryManager")
if not inv then error("Inventory Manager peripheral not found!") end

rednet.host(SCAN_PROTOCOL, "item_scanner")

term.clear()
term.setCursorPos(1, 1)
print(string.rep("=", 32))
print("  OFF-HAND SCANNER STATION ONLINE")
print("  Target ID: 12 | Modem: Top")
print(string.rep("=", 32))

while true do
    local event, senderId, message, protocol = os.pullEvent("rednet_message")
    
    if protocol == SCAN_PROTOCOL and type(message) == "table" then
        if message.type == "GET_OFFHAND_ITEM" or message.type == "SCAN_SLOT" then
            print(string.format("[Scanner] Request received from Pocket ID #%d", senderId))
            
            local targetItem = inv.getItemInOffHand()
            
            if targetItem and targetItem.name then
                print(string.format("[Scanner] Found off-hand item: %s (Count: %d)", targetItem.name, targetItem.count))
                rednet.send(senderId, {
                    type = "SCAN_RESPONSE",
                    id = message.id,
                    success = true,
                    item = {
                        name = targetItem.name,
                        count = targetItem.count,
                        displayName = targetItem.displayName or targetItem.name
                    }
                }, SCAN_PROTOCOL)
            else
                print("[Scanner Warning] Off-hand slot returned empty.")
                rednet.send(senderId, {
                    type = "SCAN_RESPONSE",
                    id = message.id,
                    success = false,
                    reason = "Player off-hand slot is empty."
                }, SCAN_PROTOCOL)
            end
        end
    end
end