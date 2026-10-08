-- PF probe 2: finds the bullet code by what it contains, not by name. Read-only.
-- Run in a match, shoot a few times first:  loadstring(game:HttpGet("https://raw.githubusercontent.com/jamalmusialla81-hub/King-loader/claude/compassionate-darwin-n9u6yv/pf_probe2.lua"))()
local out = {}
local function p(s) out[#out + 1] = tostring(s); print("[PF2] " .. tostring(s)) end
p("executor: " .. tostring(identifyexecutor and select(1, identifyexecutor()) or "?"))
p("getgc=" .. tostring(getgc ~= nil) .. " getconstants=" .. tostring((debug and debug.getconstants) ~= nil or getconstants ~= nil)
  .. " getupvalues=" .. tostring((debug and debug.getupvalues) ~= nil or getupvalues ~= nil) .. " getinfo=" .. tostring((debug and debug.getinfo) ~= nil)
  .. " getloadedmodules=" .. tostring(getloadedmodules ~= nil) .. " getsenv=" .. tostring(getsenv ~= nil))
local gk = getconstants or (debug and debug.getconstants)
local gi = (debug and debug.getinfo) or getinfo
local WORDS = {"bulletspeed", "firepos", "penetrationdepth", "velocity", "acceleration", "bulletcheck", "trajectory", "timehit", "newbullet", "camerapos", "firerate", "hitmarker", "bullet"}
local function nameOf(f) local ok, i = pcall(gi, f, "n"); return ok and i and i.name or "?" end

-- 1. functions whose constants mention bullet words
local okgc, gc = pcall(getgc, true)
p("getgc ok=" .. tostring(okgc) .. " count=" .. tostring(okgc and #gc or 0))
local hits, tabs = {}, {}
if okgc then
    for i, v in ipairs(gc) do
        if i % 15000 == 0 then task.wait() end
        if type(v) == "function" and gk and not (is_executor_closure and is_executor_closure(v)) then
            local ok, consts = pcall(gk, v)
            if ok and type(consts) == "table" then
                local score, seen = 0, {}
                for _, c in pairs(consts) do
                    if type(c) == "string" then
                        local l = c:lower()
                        for _, w in ipairs(WORDS) do if l == w and not seen[w] then seen[w] = true; score += 1 end end
                    end
                end
                if score >= 2 then
                    local src = "?"; pcall(function() src = gi(v, "S").short_src end)
                    local ws = {}; for w in pairs(seen) do ws[#ws + 1] = w end
                    hits[#hits + 1] = {score = score, text = string.format("fn name=%s src=%s consts=%s", nameOf(v), tostring(src), table.concat(ws, ","))}
                end
            end
        elseif type(v) == "table" then
            local keys = {}
            for k, val in pairs(v) do
                if type(k) == "string" and type(val) == "function" then
                    local l = k:lower()
                    for _, w in ipairs(WORDS) do if l:find(w, 1, true) then keys[#keys + 1] = k break end end
                end
            end
            if #keys >= 1 then tabs[#tabs + 1] = "table keys: " .. table.concat(keys, ",") end
        end
    end
end
table.sort(hits, function(a, b) return a.score > b.score end)
p("--- functions with bullet-like constants (top 25 of " .. #hits .. ")")
for i = 1, math.min(25, #hits) do p(hits[i].text) end
p("--- tables with bullet-like function names (" .. #tabs .. ")")
local shown = {}
for _, t in ipairs(tabs) do if not shown[t] and #shown < 25 then shown[t] = true; shown[#shown + 1] = t; p(t) end end

-- 2. loaded modules
if getloadedmodules then
    p("--- loaded ModuleScripts with bullet-like names")
    for _, m in ipairs(getloadedmodules()) do
        local l = m.Name:lower()
        if l:find("bullet") or l:find("particle") or l:find("physics") or l:find("gun") or l:find("weapon") or l:find("firearm") then p(m:GetFullName()) end
    end
end
pcall(function() if makefolder and not isfolder("king_hub") then makefolder("king_hub") end end)
pcall(writefile, "king_hub/pf_probe2.txt", table.concat(out, "\n") .. "\n")
p("done (also saved to king_hub/pf_probe2.txt)")
