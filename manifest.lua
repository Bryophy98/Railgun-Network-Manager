return {
    gateway = {
        ["startup.lua"]        = "shared/startup.lua",
        ["updater.lua"]        = "shared/updater.lua",
        ["proxy.lua"]          = "gateway/proxy.lua",
        ["proxy_wizard.lua"]   = "gateway/proxy_wizard.lua",
        ["apis/proxy_net.lua"] = "gateway/apis/proxy_net.lua",
        ["apis/primeui.lua"] = "shared/apis/primeui.lua"
    },
        monitor = {
        ["startup.lua"]             = "shared/startup.lua",
        ["updater.lua"]             = "shared/updater.lua",
        ["monitor.lua"]             = "monitor/monitor.lua",
        ["wizard.lua"]              = "monitor/wizard.lua",
        ["apis/manager.lua"]        = "monitor/apis/manager.lua",
        ["apis/import_watcher.lua"] = "monitor/apis/import_watcher.lua",
        ["apis/export_shipper.lua"] = "monitor/apis/export_shipper.lua",
        ["apis/storage.lua"]        = "monitor/apis/storage.lua",
        ["apis/ae2_guard.lua"]      = "shared/apis/ae2_guard.lua",
        ["apis/primeui.lua"]        = "shared/apis/primeui.lua"
    },
    crafter = {
        ["startup.lua"]               = "shared/startup.lua",
        ["updater.lua"]               = "shared/updater.lua",
        ["crafting_controller.lua"]   = "crafter/crafting_controller.lua",
        ["apis/crafting_manager.lua"] = "crafter/apis/crafting_manager.lua",
        ["apis/storage.lua"]          = "crafter/apis/storage.lua",
        ["apis/ae2_guard.lua"]        = "shared/apis/ae2_guard.lua",
        ["apis/primeui.lua"] = "shared/apis/primeui.lua"
    },
        pocket = {
        ["startup.lua"]          = "shared/startup.lua",
        ["updater.lua"]          = "shared/updater.lua",
        ["pocket.lua"]           = "pocket/pocket.lua",
        ["apis/pocket_net.lua"]  = "pocket/apis/pocket_net.lua",
        ["apis/pocket_ui.lua"]   = "pocket/apis/pocket_ui.lua",
        ["apis/import_menu.lua"] = "pocket/apis/import_menu.lua",
        ["apis/craft_menu.lua"]  = "pocket/apis/craft_menu.lua",
        ["apis/primeui.lua"] = "shared/apis/primeui.lua"
    },
    scanner = {
        ["startup.lua"]    = "shared/startup.lua",
        ["updater.lua"]    = "shared/updater.lua",
        ["scanner_pc.lua"] = "Scanner/scanner_pc.lua",
        ["apis/primeui.lua"] = "shared/apis/primeui.lua"
    }
}
