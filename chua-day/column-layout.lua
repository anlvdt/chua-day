local planner = require("chua-day.column-plan")
local M = {}
local key = "bottomGuard.autoColumns"

local function same(a, b)
    return a and b and math.abs(a.x-b.x)<2 and math.abs(a.y-b.y)<2
        and math.abs(a.w-b.w)<2 and math.abs(a.h-b.h)<2
end

function M.new(guard, filter, isBuiltIn, changed)
    local self = {
        enabled=hs.settings.get(key) == true,
        manual={}, actual={}, desired={}, writes=0, runs=0, applying=false,
    }
    local function candidates()
        local objects, windows = {}, {}
        for _, w in ipairs(filter:getWindows(hs.window.filter.sortByFocusedLast)) do
            if w:isStandard() and w:isVisible() and not w:isMinimized()
                and not w:isFullScreen() and w:application():name() ~= "Hammerspoon" then
                local screen, id = w:screen(), w:id()
                if screen and id then
                    objects[id] = w
                    table.insert(windows, {id=id,screen=screen:getUUID(),frame=w:frame()})
                end
            end
        end
        return objects, windows
    end

    function self:arrange()
        if not self.enabled or self.applying or not hs.accessibilityState() then return end
        if hs.mouse.getButtons().left then self:request(); return end
        local objects, windows = candidates()
        local screens = {}
        for _, screen in ipairs(hs.screen.allScreens()) do
            local f = screen:frame()
            local full = screen:fullFrame()
            if guard.enabled and not isBuiltIn(screen) then
                f.h = math.min(f.y+f.h,full.y+full.h-guard.margin)-f.y
            end
            if f.h >= 100 then
                table.insert(screens,{id=screen:getUUID(),frame={x=f.x,y=f.y,w=f.w,h=f.h}})
            end
        end
        table.sort(screens,function(a,b)
            if a.frame.x == b.frame.x then return a.frame.y < b.frame.y end
            return a.frame.x < b.frame.x
        end)
        local placements, background = planner.plan(windows,screens,self.manual)
        local selected, signature = {}, {}
        self.applying = true
        self.runs = self.runs + 1
        for _, item in ipairs(placements) do
            local w, target = objects[item.id], item.frame
            selected[item.id] = true
            table.insert(signature,item.id)
            local settled = w and same(w:frame(),self.actual[item.id])
                and same(target,self.desired[item.id])
            if w and not same(w:frame(),target) and not settled then
                -- Direct size/position writes avoid the intermediate jumping
                -- performed by setFrameWithWorkarounds.
                local before = w:frame()
                if math.abs(before.w-target.w)>=2 or math.abs(before.h-target.h)>=2 then
                    w:setSize({w=target.w,h=target.h})
                end
                local actual = w:frame()
                if math.abs(actual.x-target.x)>=2 or math.abs(actual.y-target.y)>=2 then
                    w:setTopLeft({x=target.x,y=target.y})
                end
                -- macOS can constrain a resize to the source display. Once
                -- moved, apply the destination size once, without retries.
                actual = w:frame()
                if math.abs(actual.w-target.w)>=2 or math.abs(actual.h-target.h)>=2 then
                    w:setSize({w=target.w,h=target.h})
                end
                self.writes = self.writes + 1
            end
            if w then self.actual[item.id] = w:frame() end
            self.desired[item.id] = target
        end
        table.sort(signature)
        signature = table.concat(signature,",")
        -- Raise the chosen pair over surplus windows without taking focus.
        if signature ~= self.selection then
            for i=#windows,1,-1 do
                local id = windows[i].id
                if selected[id] then objects[id]:raise() end
            end
        end
        self.selection = signature
        self.background = background
        self.placements = placements
        self.applying = false
    end

    function self:request()
        if not self.enabled then return end
        if self.timer then self.timer:stop() end
        self.timer = hs.timer.doAfter(0.35,function()
            self.timer = nil
            local ok, err = xpcall(function() self:arrange() end,debug.traceback)
            self.applying = false
            if not ok then hs.printf("Auto columns: %s",err) end
        end)
    end

    function self:setEnabled(enabled)
        self.enabled = enabled
        hs.settings.set(key,enabled)
        if self.timer then self.timer:stop(); self.timer=nil end
        self.manual, self.actual, self.desired, self.selection = {}, {}, {}, nil
        changed()
        if enabled then self:request() else guard.scan() end
    end

    function self:reset()
        self.manual, self.actual, self.desired, self.selection = {}, {}, {}, nil
        self:request()
    end

    local wf = hs.window.filter
    filter:subscribe({wf.windowsChanged,wf.windowFocused},function()
        if not self.applying then self:request() end
    end)
    filter:subscribe(wf.windowMoved,function(w)
        if not self.enabled or self.applying or not w or not w:isStandard() then return end
        local id = w:id()
        local f = w:frame()
        if self.actual[id] and not same(f,self.actual[id]) then
            self.manual[id] = true
            self.actual[id] = f
            self.desired[id] = nil
            self:request()
        end
    end)
    filter:subscribe(wf.windowDestroyed,function(w)
        local id = w and w:id()
        if id then self.manual[id],self.actual[id],self.desired[id] = nil,nil,nil end
        self:request()
    end)
    self.screenWatcher = hs.screen.watcher.new(function() self:reset() end):start()
    return self
end

return M
