-- PF probe: can the game's bullet code be reached from the normal script environment?
-- No actor APIs (those crash MacSploit). Read-only: nothing is hooked or changed.
-- Run in a match:  loadstring(game:HttpGet("https://raw.githubusercontent.com/jamalmusialla81-hub/King-loader/main/pf_probe.lua"))()   then read king_hub/pf_probe.txt
local out = {}
local function p(s) out[#out + 1] = tostring(s) end

p("executor: " .. tostring((identifyexecutor and select(1, identifyexecutor())) or "?"))
p("has getgc=" .. tostring(getgc ~= nil) .. " getrenv=" .. tostring(getrenv ~= nil) .. " hookfunction=" .. tostring(hookfunction ~= nil)
    .. " getupvalue=" .. tostring(getupvalue ~= nil or (debug and debug.getupvalue) ~= nil))

-- 1. does the game's shared.require table exist here?
local ok, req = pcall(function() return getrenv().shared.require end)
p("getrenv().shared.require: " .. tostring(ok and req ~= nil))
local ok2, shared = pcall(function() return shared end)
p("shared table here: " .. tostring(ok2 and type(shared)))

-- 2. look for the bullet module in the garbage collector
local found = {}
local okgc, gc = pcall(getgc, true)
p("getgc(true) ok=" .. tostring(okgc) .. " count=" .. tostring(okgc and #gc or "-"))
if okgc then
    local seen = 0
    for _, v in ipairs(gc) do
        seen += 1
        if seen % 20000 == 0 then task.wait() end
        if type(v) == "table" then
            local nb = rawget(v, "newBullet")
            if type(nb) == "function" then found[#found + 1] = "table with newBullet" end
            if rawget(v, "NetworkClient") ~= nil or (type(rawget(v, "send")) == "function" and type(rawget(v, "fetch")) == "function") then
                found[#found + 1] = "network-like table"
            end
            if rawget(v, "getActiveCamera") ~= nil then found[#found + 1] = "camera interface" end
        end
    end
end
p("matches: " .. (#found > 0 and table.concat(found, ", ") or "none"))
p("verdict: " .. (#found > 0 and "the bullet code IS reachable on the main thread" or "not reachable from here (it lives inside an actor)"))

pcall(function() if makefolder and not isfolder("king_hub") then makefolder("king_hub") end end)
pcall(writefile, "king_hub/pf_probe.txt", table.concat(out, "\n") .. "\n")
print("[PF probe] done, see king_hub/pf_probe.txt")
