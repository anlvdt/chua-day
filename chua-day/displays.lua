local M = {}

-- Read the OS display inventory instead of hard-coding a machine's UUID.
function M.internalIDs(profile)
    local ids = {}
    for _, gpu in ipairs(profile.SPDisplaysDataType or {}) do
        for _, display in ipairs(gpu.spdisplays_ndrvs or {}) do
            local kind = display.spdisplays_display_type or ""
            if display.spdisplays_connection_type == "spdisplays_internal"
                or kind:find("built-in", 1, true) then
                local id = tonumber(display._spdisplays_displayID)
                if id then ids[id] = true end
            end
        end
    end
    return ids
end

function M.new(changed)
    local self = {ids={}, generation=0}

    function self:isBuiltIn(screen)
        if self.ids[screen:id()] then return true end
        -- Available immediately while the asynchronous inventory is running.
        local name = (screen:name() or ""):lower()
        return name:find("built-in",1,true) ~= nil or name == "color lcd"
    end

    function self:refresh()
        self.generation = self.generation + 1
        local generation = self.generation
        if self.task then self.task:terminate() end
        self.task = hs.task.new("/usr/sbin/system_profiler",function(code, output)
            if generation ~= self.generation then return end
            self.task = nil
            if code ~= 0 then return end
            local ok, profile = pcall(hs.json.decode,output)
            if ok and type(profile)=="table" and profile.SPDisplaysDataType then
                self.ids = M.internalIDs(profile)
                changed()
            end
        end,nil,{"SPDisplaysDataType","-json"})
        if self.task then self.task:start() end
    end

    self:refresh()
    return self
end

return M
