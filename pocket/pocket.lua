-- ============================================================================
-- POCKET PC REMOTE MANAGER (PrimeUI 26x20 Main Menu)
-- Save as: pocket/pocket.lua
-- ============================================================================

local PrimeUI     = require("apis.primeui")
local net         = require("apis.pocket_net")
local ui          = require("apis.pocket_ui")
local import_menu = require("apis.import_menu")
local craft_menu  = require("apis.craft_menu")

net.init()

local menuItems = {
    "Import Rules (CRUD)",
    "Crafting Jobs (CRUD)",
    "Push OTA Update",
    "Exit"
}

while true do
    ui.drawFrame("CROSS-DIM DEPOT MGR")
    PrimeUI.borderBox(term.current(), 2, 4, 24, 12, colors.blue, colors.black)
    PrimeUI.selectionBox(term.current(), 2, 4, 24, 12, menuItems, "CHOOSE", nil, colors.white, colors.black)
    PrimeUI.label(term.current(), 2, 19, "PC #" .. os.computerID() .. " | Arrows/Touch", colors.gray, colors.black)

    local _, _, choice = PrimeUI.run()

    if choice == "Import Rules (CRUD)" then
        import_menu.run()
    elseif choice == "Crafting Jobs (CRUD)" then
        craft_menu.run()
    elseif choice == "Push OTA Update" then
        ui.status("OTA NETWORK UPDATE", "Broadcasting update...", "Please wait", colors.orange)
        net.broadcastOtaUpdate()
        sleep(2)
        shell.run("updater.lua")
    elseif choice == "Exit" then
        PrimeUI.clear()
        term.setBackgroundColor(colors.black)
        term.clear()
        term.setCursorPos(1, 1)
        print("Exited Depot Manager.")
        break
    end
end
