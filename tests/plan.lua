
local plan = require("chua-day.column-plan").plan
local screens = {
    {id="external",frame={x=-434,y=-1122,w=2048,h=1002}},
    {id="laptop",frame={x=56,y=33,w=1672,h=1084}},
}
local function win(id,screen,x)
    return {id=id,screen=screen,frame={x=x or 0,y=33,w=600,h=400}}
end
local function byID(items)
    local out={}
    for _,item in ipairs(items) do out[item.id]=item end
    return out
end
local p,b = plan({win(1,"external")},screens,{})
assert(#p==1 and #b==0 and p[1].frame.h==1002 and p[1].frame.w==2048)
p = plan({win(1,"external",-400),win(2,"external",600)},screens,{})
local indexed=byID(p)
assert(indexed[1].frame.x==-434 and indexed[2].frame.x==590)
assert(indexed[1].frame.w==1024 and indexed[2].frame.w==1024)
assert(indexed[2].frame.y+indexed[2].frame.h==-120)
p = plan({win(2,"external",600),win(1,"external",-400)},screens,{})
indexed=byID(p)
assert(indexed[1].frame.x==-434 and indexed[2].frame.x==590,"Focus swapped columns")
p,b = plan({win(1,"external"),win(2,"external"),win(3,"external"),
    win(4,"laptop"),win(5,"laptop")},screens,{})
assert(#p==4 and #b==1 and b[1]==3)
local counts={}
for _,item in ipairs(p) do counts[item.screen]=(counts[item.screen] or 0)+1 end
assert(counts.external==2 and counts.laptop==2)
p,b = plan({win(3,"external"),win(1,"external"),win(2,"external"),
    win(4,"laptop"),win(5,"laptop")},screens,{})
assert(byID(p)[3] and #b==1 and b[1]==2,"User selection was not promoted locally")
local manual=win(1,"external",123)
manual.frame.y=-1000
p = plan({manual,win(2,"external",600)},screens,{[1]=true})
assert(byID(p)[1].frame==manual.frame,"Manual geometry was overwritten")
manual.frame.h=1100
p = plan({manual},screens,{[1]=true})
assert(p[1].frame.y==-1000 and p[1].frame.h==880,"Manual maximize lost bottom margin")
-- Opening a third Chrome window on the laptop must never push a window
-- to the external display, even if Codex is the only window there.
p,b = plan({win(7,"laptop"),win(8,"laptop"),win(9,"laptop"),
    win(10,"external")},screens,{})
indexed=byID(p)
assert(#p==3 and #b==1 and b[1]==9)
assert(indexed[7].screen=="laptop" and indexed[8].screen=="laptop")
assert(indexed[10].screen=="external" and indexed[10].frame.w==2048)
p,b = plan({},screens,{})
assert(#p==0 and #b==0)
print("Passed layout checks: local priority, no cross-screen moves, bottom margin and manual placement")
