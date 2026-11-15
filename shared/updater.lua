-- ============================================================================
-- SHARED GITHUB OTA UPDATER
-- Save as: shared/updater.lua
-- ============================================================================

local REPO_BASE = "https://githubusercontent.com" .. "Bryophy98/Railgun-Network-Manager/main/"
local cacheBuster = "?t=" .. os.epoch("utc")

local function detectRole()
    if fs.exists("data/role.dat") then
        local f = fs.open("data/role.dat", "r")
        local r = f.readAll():match("^%s*(.-)%s*$")
        f.close()
        return r
    end
    if fs.exists("proxy.lua") then return "gateway" end
    if fs.exists("monitor.lua") then return "monitor" end
    if fs.exists("crafting_controller.lua") then return "crafter" end
    if fs.exists("pocket.lua") then return "pocket" end
    return "scanner"
end

local function downloadFile(repoPath, destPath)
    local response = http.get(REPO_BASE .. repoPath .. cacheBuster)
    if not response then
        return false, "HTTP request failed: " .. repoPath
    end
    local content = response.readAll()
    response.close()

    local tmpPath = destPath .. ".tmp"
    local f = fs.open(tmpPath, "w")
    f.write(content)
    f.close()

    if fs.exists(destPath) then
        fs.delete(destPath)
    end
    fs.move(tmpPath, destPath)
    return true
end

local role = detectRole()
if not fs.exists("data") then fs.makeDir("data") end
local rf = fs.open("data/role.dat", "w")
rf.write(role)
rf.close()

print("[OTA] Updating role: " .. role:upper())
local ok, err = downloadFile("manifest.lua", "manifest.lua")
if not ok then
    printError("[OTA] Manifest error: " .. tostring(err))
    return
end

package.loaded["manifest"] = nil
local manifest = require("manifest")
local files = manifest[role]

if not files then
    printError("[OTA] Unknown role in manifest: " .. tostring(role))
    return
end

for localPath, repoPath in pairs(files) do
    print("[OTA] Pulling " .. localPath .. "...")
    local fOk, fErr = downloadFile(repoPath, localPath)
    if not fOk then
        printError("[OTA] Failed: " .. tostring(fErr))
        return
    end
end

print("[OTA] Update complete! Rebooting...")
sleep(1.5)
os.reboot()
