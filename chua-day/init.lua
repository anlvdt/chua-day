-- Chừa đáy: external-display bottom clearance and optional two-column layouts.
local bottomGuard
local displays = require("chua-day.displays").new(function()
    if bottomGuard then bottomGuard.scan() end
end)
local marginKey = "bottomGuard.margin"
local enabledKey = "bottomGuard.enabled"
local pending = {}
local states = {}

local function sameFrame(a, b)
    return a and b and math.abs(a.x - b.x) < 1
        and math.abs(a.y - b.y) < 1 and math.abs(a.w - b.w) < 1
        and math.abs(a.h - b.h) < 1
end

bottomGuard = {
    margin = hs.settings.get(marginKey) or 120,
    enabled = hs.settings.get(enabledKey) ~= false,
    corrections = {},
}

function bottomGuard.target(frame, visible, full, margin)
    local bottom = math.min(visible.y + visible.h, full.y + full.h - margin)
    if frame.y + frame.h <= bottom + 1 then
        return nil
    end
    -- Keep the top edge fixed and shorten the bottom edge.
    local top = math.max(visible.y, math.min(frame.y, bottom - 100))
    local height = math.min(frame.h, bottom - top)
    return {x = frame.x, y = top, w = frame.w, h = height}
end

local function adjustWindow(window)
    if bottomGuard.columns and bottomGuard.columns.enabled then return end
    if not bottomGuard.enabled or not hs.accessibilityState()
        or not window:isStandard() or not window:isVisible()
        or window:isFullScreen() then
        return
    end
    local screen = window:screen()
    if not screen or displays:isBuiltIn(screen) then
        return
    end
    local id = window:id()
    local frame = window:frame()
    local now = hs.timer.secondsSinceEpoch()
    local state = states[id]
    if state and (now < state.ignoreUntil or sameFrame(frame, state.settled)) then
        return
    end
    local target = bottomGuard.target(
        frame, screen:frame(), screen:fullFrame(), bottomGuard.margin
    )
    if not target then
        return
    end

    -- Never feed our own accessibility notifications back into another resize.
    -- Also stop applications which keep rejecting the requested geometry.
    state = state or {recent = {}}
    state.recent = hs.fnutils.filter(state.recent, function(t) return now - t < 5 end)
    if #state.recent >= 2 then
        return
    end
    table.insert(state.recent, now)
    state.ignoreUntil = now + 0.8
    states[id] = state
    bottomGuard.corrections[id] = (bottomGuard.corrections[id] or 0) + 1
    window:setSize({w = target.w, h = target.h})
    local actual = window:frame()
    if math.abs(actual.x - target.x) >= 1 or math.abs(actual.y - target.y) >= 1 then
        window:setTopLeft({x = target.x, y = target.y})
    end
    state.settled = window:frame()
    state.timer = hs.timer.doAfter(0.8, function()
        local current = hs.window.get(id)
        if current and states[id] == state then state.settled = current:frame() end
        state.timer = nil
    end)
end

local function queueWindow(window)
    if bottomGuard.columns and bottomGuard.columns.enabled then return end
    local id = window:id()
    if not id then
        return
    end
    local state = states[id]
    if state and hs.timer.secondsSinceEpoch() < state.ignoreUntil then return end
    if pending[id] then
        pending[id]:stop()
    end
    pending[id] = hs.timer.doAfter(0.25, function()
        pending[id] = nil
        local current = hs.window.get(id)
        if not current then
            states[id] = nil
            return
        end
        if hs.mouse.getButtons().left then
            queueWindow(current)
            return
        end
        adjustWindow(current)
    end)
end

function bottomGuard.scan()
    if bottomGuard.columns and bottomGuard.columns.enabled then
        bottomGuard.columns:request()
        return
    end
    for _, window in ipairs(hs.window.visibleWindows()) do
        queueWindow(window)
    end
end

bottomGuard.menu = hs.menubar.new()
local function updateMenu()
    bottomGuard.menu:setTitle(bottomGuard.enabled and "Chừa đáy" or "Chừa đáy · Tắt")
    bottomGuard.menu:setTooltip("Giữ cửa sổ phía trên phần bị che của màn hình ngoài")
    local items = {
        {
            title = "Tự sắp xếp · tối đa 2 cột/màn hình",
            checked = bottomGuard.columns and bottomGuard.columns.enabled or false,
            fn = function()
                bottomGuard.columns:setEnabled(not bottomGuard.columns.enabled)
            end,
        },
        {
            title = "Sắp xếp lại ngay (bỏ vị trí chỉnh tay)",
            disabled = not (bottomGuard.columns and bottomGuard.columns.enabled),
            fn = function() bottomGuard.columns:reset() end,
        },
        {title = "-"},
        {
            title = "Tự chừa đáy màn hình ngoài",
            checked = bottomGuard.enabled,
            fn = function()
                bottomGuard.enabled = not bottomGuard.enabled
                hs.settings.set(enabledKey, bottomGuard.enabled)
                states = {}
                updateMenu()
                bottomGuard.scan()
            end,
        },
        {title = "-"},
    }
    for _, margin in ipairs({80, 120, 160, 200, 240}) do
        table.insert(items, {
            title = margin .. " điểm",
            checked = bottomGuard.margin == margin,
            fn = function()
                bottomGuard.margin = margin
                hs.settings.set(marginKey, margin)
                states = {}
                updateMenu()
                bottomGuard.scan()
            end,
        })
    end
    table.insert(items, {title = "-"})
    table.insert(items, {
        title = "Cấp quyền điều chỉnh cửa sổ…",
        fn = function() hs.accessibilityState(true) end,
    })
    table.insert(items, {
        title = "Thoát",
        fn = function() hs.application.get("Hammerspoon"):kill() end,
    })
    bottomGuard.menu:setMenu(items)
end

updateMenu()

local wf = hs.window.filter
bottomGuard.filter = wf.new():setOverrideFilter({
    visible = true, currentSpace = true, fullscreen = false,
})
bottomGuard.filter:subscribe({
    wf.windowMoved, wf.windowVisible,
}, queueWindow)
bottomGuard.filter:subscribe(wf.windowDestroyed, function(window)
    local id = window:id()
    if not id then
        return
    end
    if pending[id] then
        pending[id]:stop()
        pending[id] = nil
    end
    if states[id] and states[id].timer then states[id].timer:stop() end
    states[id] = nil
end)
bottomGuard.columns = require("chua-day.column-layout").new(
    bottomGuard, bottomGuard.filter, function(screen) return displays:isBuiltIn(screen) end, updateMenu
)
updateMenu()
bottomGuard.screenWatcher = hs.screen.watcher.new(function()
    displays:refresh()
    bottomGuard.scan()
end):start()
bottomGuard.scan()

return bottomGuard
