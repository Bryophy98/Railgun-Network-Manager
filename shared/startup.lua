-- ============================================================================
-- SHARED STARTUP WRAPPER (Crash-Protected + Network-Wide OTA Listener)
-- Save as: shared/startup.lua
-- ============================================================================

local OTA_PROTOCOL = "OTA_UPDATE"
local seenUpdates = {}

-- Open all attached modems (Ender top, Wired/Wireless bottom, Pocket back)
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "modem" then
        rednet.open(name)
    end
end

local function detectRole()
    if fs.exists("data/role.dat") then
        local f = fs.open("data/role.dat", "r")
        local r = f.readAll()
        f.close()
        return r
    end
    if fs.exists("proxy.lua") then return "gateway" end
    if fs.exists("monitor.lua") then return "monitor" end
    if fs.exists("crafting_controller.lua") then return "crafter" end
    if fs.exists("pocket.lua") then return "pocket" end
    return "scanner"
end

local ROLE_ENTRY = {
    gateway = "proxy.lua",
    monitor = "monitor.lua",
    crafter = "crafting_controller.lua",
    pocket  = "pocket.lua",
    scanner = "scanner_pc.lua"
}

local myRole = detectRole()

local function otaListener()
    while true do
        local senderId, msg, protocol = rednet.receive(OTA_PROTOCOL)
        if type(msg) == "table" and msg.cmd == "RUN_UPDATE" and msg.id and not seenUpdates[msg.id] then
            seenUpdates[msg.id] = true
            print("\n[OTA] Network update triggered (ID: " .. tostring(msg.id) .. ")")

            -- Gateways relay the update to both Ender and Local modem networks first
            if myRole == "gateway" then
                print("[OTA] Relaying update signal to local & dimensional nodes...")
                rednet.broadcast(msg, OTA_PROTOCOL)
                sleep(1.5)
            else
                sleep(0.5)
            end

            shell.run("updater.lua")
        end
    end
end

local function runRoleProgram()
    local script = ROLE_ENTRY[myRole]
    if not script or not fs.exists(script) then
        printError("[BOOT] Entry script missing for role: " .. tostring(myRole))
        print("[OTA] Waiting for network update...")
        while true do sleep(60) end
    end

    local ok, err = pcall(function()
        shell.run(script)
    end)

    if not ok then
        printError("\n[CRASH] " .. script .. " crashed:")
        printError(tostring(err))
        print("\n[OTA] Update listener still active! Fix on GitHub and broadcast update.")
        while true do sleep(60) end
    end
end

parallel.waitForAny(otaListener, runRoleProgram)
