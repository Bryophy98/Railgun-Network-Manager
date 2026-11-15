-- ============================================================================
-- POCKET PC REMOTE MANAGER (Main Menu Dispatcher)
-- Save as: pocket/pocket.lua
-- ============================================================================

local net         = require("apis.pocket_net")
local ui          = require("apis.pocket_ui")
local import_menu = require("apis.import_menu")
local craft_menu  = require("apis.craft_menu")

net.init()

while true do
    ui.header("CROSS-DIM DEPOT MANAGER")
    print("1. Manage Import Rules (CRUD)")
    print("2. Manage Crafting Jobs (CRUD)")
    print("3. Push Network Update (OTA)")
    print("4. Exit")
    print(string.rep("-", 32))
    write("Select option (1-4): ")

    local choice = read()
    if choice == "1" then
        import_menu.run()
    elseif choice == "2" then
        craft_menu.run()
    elseif choice == "3" then
        ui.header("NETWORK OTA UPDATE")
        print("Broadcasting update signal...")
        net.broadcastOtaUpdate()
        sleep(2)
        shell.run("updater.lua")
    elseif choice == "4" then
        term.clear()
        term.setCursorPos(1, 1)
        print("Exiting Manager.")
        break
    end
end
