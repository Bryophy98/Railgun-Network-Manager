-- ============================================================================
-- SHARED GITHUB OTA UPDATER (Strict Role Detection + CDN Cache Bypass)
-- Save as: shared/updater.lua
-- ============================================================================

local REPO_BASE = table.concat({
    "https://",
    "raw.",
    "githubusercontent.com",
    "/Bryophy98/Railgun-Network-Manager/main/"
})

local NO_CACHE_HEADERS = {
    ["Cache-Control"] = "no-cache, no-store, must-revalidate",
    ["Pragma"]        = "no-cache"
}

local function detectRole()
    if fs.exists("data/role.dat") then
        local f = fs.open("data/role.dat", "r")
        local r = f.readAll():match("^%s*(.-)%s*$")
        f.close()
        if r and r ~= "" then return r end
    end
    if fs.exists("proxy.lua") then return "gateway" end
    if fs.exists("monitor.lua") then return "monitor" end
    if fs.exists("crafting_controller.lua") then return "crafter" end
    if fs.exists("pocket.lua") then return "pocket" end
    if fs.exists("scanner_pc.lua") then return "scanner" end
    return nil
end

local function downloadFile(repoPath, destPath)
    local url = REPO_BASE .. repoPath .. "?cb=" .. tostring(os.epoch("utc"))
    local response = http.get(url, NO_CACHE_HEADERS)
    if not response then
        return false, "HTTP request failed: " .. repoPath
    end

    local content = response.readAll()
    response.close()

    if not content or content == "" then
        return false, "Empty response for: " .. repoPath
    end

    local tmpPath = destPath .. ".tmp"
    if fs.exists(tmpPath) then fs.delete(tmpPath) end

    local f = fs.open(tmpPath, "w")
    if not f then
        return false, "Could not open temp file: " .. tmpPath
    end
    f.write(content)
    f.close()

    if fs.exists(destPath) then
        fs.delete(destPath)
    end
    fs.move(tmpPath, destPath)
    return true
end

local role = detectRole()

if not role then
    print("[OTA] No role assigned to this PC.")
    write("Enter role name (gateway/monitor/crafter/pocket/scanner): ")
    role = read():match("^%s*(.-)%s*$"):lower()
    if not role or role == "" then
        printError("[OTA] Aborted: Role cannot be empty.")
        return
    end
end

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
