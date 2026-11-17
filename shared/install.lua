-- ============================================================================
-- NETWORK NODE INTERACTIVE INSTALLER (Grayscale PrimeUI for Basic PCs)
-- Save as: shared/install.lua
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

local function fetch(repoPath, destPath)
    local url = REPO_BASE .. repoPath .. "?cb=" .. tostring(os.epoch("utc"))
    local res = http.get(url, NO_CACHE_HEADERS)
    if not res then
        return false, "HTTP failed: " .. repoPath
    end
    local content = res.readAll()
    res.close()

    if not content or content == "" then
        return false, "Empty file: " .. repoPath
    end

    local dir = fs.getDir(destPath)
    if dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
    end

    local f = fs.open(destPath, "w")
    if not f then
        return false, "Cannot write: " .. destPath
    end
    f.write(content)
    f.close()
    return true
end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
print("Fetching manifest & UI library...")

local ok1, err1 = fetch("manifest.lua", "manifest.lua")
if not ok1 then printError(err1) return end

local ok2, err2 = fetch("shared/apis/primeui.lua", "apis/primeui.lua")
if not ok2 then printError(err2) return end

package.loaded["manifest"] = nil
local manifest = require("manifest")
local PrimeUI  = require("apis.primeui")

local roles = {}
for roleName, _ in pairs(manifest) do
    table.insert(roles, string.upper(roleName))
end
table.sort(roles)
table.insert(roles, "< Cancel >")

PrimeUI.clear()
term.setBackgroundColor(colors.black)
term.clear()

-- Top grayscale banner (51x1)
term.setCursorPos(1, 1)
term.setBackgroundColor(colors.lightGray)
term.setTextColor(colors.black)
term.clearLine()
PrimeUI.centerLabel(term.current(), 1, 1, 51, "RAILGUN NETWORK NODE INSTALLER (PC #" .. os.computerID() .. ")", colors.black, colors.lightGray)

PrimeUI.label(term.current(), 4, 3, "Select role for this computer (Click or Enter):", colors.lightGray, colors.black)
PrimeUI.borderBox(term.current(), 4, 5, 45, 9, colors.white, colors.black)
PrimeUI.selectionBox(term.current(), 4, 5, 45, 9, roles, "SELECT", nil, colors.white, colors.black)
PrimeUI.button(term.current(), 4, 16, "Cancel", "CANCEL", colors.white, colors.gray, colors.lightGray)

local _, action, chosen = PrimeUI.run()
PrimeUI.clear()
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)

if action == "CANCEL" or not chosen or chosen == "< Cancel >" then
    print("Installation cancelled.")
    return
end

local selectedRole = string.lower(chosen)
print("[Install] Role selected: " .. selectedRole:upper())

if not fs.exists("data") then
    fs.makeDir("data")
end

local rf = fs.open("data/role.dat", "w")
rf.write(selectedRole)
rf.close()

print("[Install] Pulling OTA updater...")
local uOk, uErr = fetch("shared/updater.lua", "updater.lua")
if not uOk then
    printError("[Error] " .. tostring(uErr))
    return
end

print("[Install] Launching updater...")
sleep(1)
shell.run("updater.lua")
