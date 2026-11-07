local M = {}

-- Inputs are plain tables; windows arrive in most-recently-used order.
function M.plan(windows, screens, manual)
    local groups, background = {}, {}
    for _, screen in ipairs(screens) do
        groups[screen.id] = {}
    end
    for _, window in ipairs(windows) do
        local group = groups[window.screen]
        if group and #group < 2 then
            table.insert(group, window)
        else
            table.insert(background, window.id)
        end
    end
    local placements = {}
    for _, screen in ipairs(screens) do
        local group, area = groups[screen.id], screen.frame
        -- Focus changes must not swap the left and right columns.
        table.sort(group, function(a, b)
            if a.frame.x == b.frame.x then return a.id < b.id end
            return a.frame.x < b.frame.x
        end)
        local leftWidth = math.floor(area.w / 2)
        for index, window in ipairs(group) do
            local target
            if manual[window.id] and window.screen == screen.id then
                target = window.frame
                local bottom = area.y + area.h
                if target.y + target.h > bottom then
                    local top = math.max(area.y,math.min(target.y,bottom-100))
                    target = {x=target.x,y=top,w=target.w,h=math.min(target.h,bottom-top)}
                end
            elseif #group == 1 then
                target = {x=area.x,y=area.y,w=area.w,h=area.h}
            else
                target = {
                    x=area.x + (index == 2 and leftWidth or 0), y=area.y,
                    w=index == 1 and leftWidth or area.w-leftWidth, h=area.h,
                }
            end
            table.insert(placements, {id=window.id,screen=screen.id,frame=target})
        end
    end
    return placements, background
end

return M
