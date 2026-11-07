local root = (...) or "."
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

for _, file in ipairs({"init","column-plan","column-layout","displays"}) do
    assert(loadfile(root .. "/chua-day/" .. file .. ".lua"))
end
dofile(root .. "/tests/plan.lua")
local displays = require("chua-day.displays")
local fixture = {SPDisplaysDataType={{spdisplays_ndrvs={
    {_spdisplays_displayID="7",spdisplays_connection_type="spdisplays_internal"},
    {_spdisplays_displayID="0x8",spdisplays_display_type="spdisplays_built-in-retina"},
    {_spdisplays_displayID="9",spdisplays_connection_type="spdisplays_displayport"},
}}}}
local ids = displays.internalIDs(fixture)
assert(ids[7] and ids[8] and not ids[9])
assert(next(displays.internalIDs({}))==nil)

-- Run the packaged entry point against a fake OS, never touching live windows.
local originalHS = hs
local callbacks, tasks = {}, {}
local filter = {}
function filter:setOverrideFilter() return self end
function filter:subscribe(events,callback) table.insert(callbacks,callback); return self end
function filter:getWindows() return {} end
local function timer(callback)
    local t={callback=callback,stopped=false}
    function t:stop() self.stopped=true end
    return t
end
local menu={}
function menu:setTitle(title) self.title=title; return self end
function menu:setTooltip() return self end
function menu:setMenu(items) self.items=items; return self end
local wf={new=function() return filter end,windowMoved="moved",windowVisible="visible",
    windowFocused="focused",windowsChanged="changed",windowDestroyed="destroyed"}
hs={
    settings={get=function() return nil end,set=function() end},
    timer={doAfter=function(_,callback) return timer(callback) end},
    menubar={new=function() return menu end},
    window={filter=wf,visibleWindows=function() return {} end},
    screen={allScreens=function() return {} end,watcher={new=function()
        return {start=function(self) return self end}
    end}},
    task={new=function(_,callback)
        local task={callback=callback,start=function(self) return self end,terminate=function() end}
        table.insert(tasks,task)
        return task
    end},
    json={decode=function() return fixture end},
    accessibilityState=function() return true end,
    mouse={getButtons=function() return {} end},
}
local ok,err=xpcall(function()
    local guard=assert(loadfile(root .. "/chua-day/init.lua"))()
    assert(guard.enabled and guard.margin==120)
    assert(not guard.columns.enabled)
    assert(menu.title=="Chừa đáy" and #menu.items>=9)
    assert(#tasks==1 and #callbacks>=4)
    tasks[1].callback(0,"inventory")
    guard.columns:arrange()
end,debug.traceback)
hs=originalHS
assert(ok,err)
print("Passed display detection and packaged startup checks")
