-- ============================================================================
-- MANAGER API (Lightweight Coordinator Wrapper)
-- Save as: monitor/apis/manager.lua
-- ============================================================================

local import_watcher = require("apis.import_watcher")
local export_shipper = require("apis.export_shipper")

local manager = {}
local me = nil

function manager.init(dimension, meRef, chatRef, routesRef)
    me = meRef
    import_watcher.init(dimension, meRef, chatRef)
    export_shipper.init(dimension, meRef, chatRef, routesRef)

    if fs.exists("data/gateway.dat") then
        local f = fs.open("data/gateway.dat", "r")
        local gwId = tonumber(f.readAll())
        f.close()
        if gwId then
            import_watcher.setProxyTarget(gwId)
            export_shipper.setProxyTarget(gwId)
        end
    end
end

function manager.setProxyTarget(id)
    local f = fs.open("data/gateway.dat", "w")
    f.write(tostring(id))
    f.close()
    import_watcher.setProxyTarget(id)
    export_shipper.setProxyTarget(id)
end

function manager.checkImports()
    import_watcher.tick()
end

function manager.handleInboundResponse(msg)
    import_watcher.handleResponse(msg)
end

function manager.fulfillStockRequest(req)
    export_shipper.fulfill(req)
end

function manager.handleConfigSync(data)
    if not data then return end
    local act = data.action
    if act == "ADD_IMPORT" then
        import_watcher.setRule(data.item, data.targetStock, data.batchSize, data.sourceProxyId)
    elseif act == "REMOVE_IMPORT" then
        import_watcher.removeRule(data.item)
    end
end

function manager.getItemsList()
    if not me then return {} end
    local ok, items = pcall(function() return me.listItems() end)
    return ok and items or {}
end

function manager.getImportsList()
    return import_watcher.getList()
end

return manager
