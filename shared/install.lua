-- ============================================================================
-- NETWORK NODE INTERACTIVE INSTALLER (For Blank CC:Tweaked Computers)
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

    local f = fs.open(destPath, "w")
    if not f then
        return false, "Cannot write: " .. destPath
    end
    f.write(content)
    f.close()
    return true
end

term.clear()
term.setCursorPos(1, 1)
print("====================================")
print("  RAILGUN NETWORK NODE INSTALLER    ")
print("====================================")
print("Fetching network manifest...")

local ok, err = fetch("manifest.lua", "manifest.lua")
if not ok then
    printError("\n[Error] " .. tostring(err))
    return
end

package.loaded["manifest"] = nil
local manifest = require("manifest")

-- Build sorted list of available roles directly from manifest.lua
local roles = {}
for roleName, _ in pairs(manifest) do
    table.insert(roles, roleName)
end
table.sort(roles)

term.clear()
term.setCursorPos(1, 1)
print("====================================")
print("  SELECT ROLE FOR THIS COMPUTER     ")
print("====================================")
print("PC ID: #" .. os.computerID() .. "\n")

for i, roleName in ipairs(roles) do
    print(string.format("  %d. %s", i, string.upper(roleName)))
end
print("  0. Cancel\n")
write("Select role number: ")

local choice = tonumber(read())
if not choice or choice == 0 or not roles[choice] then
    print("\nInstallation cancelled.")
    return
end

local selectedRole = roles[choice]

print("\n[Install] Configuring as: " .. selectedRole:upper())
if not fs.exists("data") then
    fs.makeDir("data")
end

local rf = fs.open("data/role.dat", "w")
rf.write(selectedRole)
rf.close()

print("[Install] Downloading OTA updater...")
local uOk, uErr = fetch("shared/updater.lua", "updater.lua")
if not uOk then
    printError("[Error] " .. tostring(uErr))
    return
end

print("[Install] Launching updater to pull role files...\n")
sleep(1)
shell.run("updater.lua")
