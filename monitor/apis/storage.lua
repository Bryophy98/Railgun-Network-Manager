-- ============================================================================
-- STORAGE API (Disk Persistence Module)
-- Save as: apis/storage.lua
-- ============================================================================

local storage = {}
local STORAGE_DIR = "data"

if not fs.exists(STORAGE_DIR) then
    fs.makeDir(STORAGE_DIR)
end

function storage.save(filename, dataTable)
    local path = STORAGE_DIR .. "/" .. filename
    local file = fs.open(path, "w")
    if file then
        file.write(textutils.serialize(dataTable))
        file.close()
        return true
    end
    return false
end

function storage.load(filename)
    local path = STORAGE_DIR .. "/" .. filename
    if fs.exists(path) then
        local file = fs.open(path, "r")
        if file then
            local content = file.readAll()
            file.close()
            local decoded = textutils.unserialize(content)
            if type(decoded) == "table" then
                return decoded
            end
        end
    end
    return {}
end

return storage