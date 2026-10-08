-- PF probe 5: logs the arguments of PhysicsLib.ballisticsTrajectory / timehit and CharmPhysics.new while you shoot. Changes nothing.
-- Run in a match, then SHOOT (at a wall, at a player, ADS and hip) for 30 seconds:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/jamalmusialla81-hub/King-loader/claude/compassionate-darwin-n9u6yv/pf_probe5.lua"))()
local out = {}
local function p(s) out[#out + 1] = tostring(s); print("[PF5] " .. tostring(s)) end
local function fmt(v, d)
    d = d or 0
    local t = typeof(v)
    if t == "Vector3" then return string.format("V3(%.2f,%.2f,%.2f)", v.X, v.Y, v.Z) end
    if t == "number" then return string.format("%.3f", v) end
    if t == "table" and d < 1 then
        local parts, n = {}, 0
        for k, x in pairs(v) do n += 1 if n <= 12 then parts[#parts + 1] = tostring(k) .. "=" .. fmt(x, d + 1) end end
        return "{" .. table.concat(parts, ", ") .. (n > 12 and ", ..." or "") .. "}"
    end
    if t == "Instance" then return "Inst(" .. v.ClassName .. ":" .. v.Name .. ")" end
    return t .. ":" .. tostring(v):sub(1, 30)
end
local function find(name)
    for _, m in ipairs(getloadedmodules()) do
        if m.Name == name then local ok, r = pcall(require, m) if ok and type(r) == "table" then return r end end
    end
end
local restore, counts = {}, {}
local function watch(mod, modName, fnName)
    local orig = mod and rawget(mod, fnName)
    if type(orig) ~= "function" then p("cannot watch " .. modName .. "." .. fnName) return end
    counts[fnName] = 0
    mod[fnName] = function(...)
        local n = select("#", ...)
        local res = table.pack(orig(...))
        counts[fnName] += 1
        if counts[fnName] <= 12 then
            local a = {}
            for i = 1, n do a[i] = fmt((select(i, ...))) end
            local r = {}
            for i = 1, res.n do r[i] = fmt(res[i]) end
            p(string.format("%s.%s(%s) -> %s", modName, fnName, table.concat(a, ", "), table.concat(r, ", ")))
        end
        return table.unpack(res, 1, res.n)
    end
    restore[#restore + 1] = function() mod[fnName] = orig end
    p("watching " .. modName .. "." .. fnName)
end
local phys, charm = find("PhysicsLib"), find("CharmPhysics")
watch(phys, "PhysicsLib", "ballisticsTrajectory")
watch(phys, "PhysicsLib", "timehit")
watch(charm, "CharmPhysics", "new")
p("shoot now - 30 seconds")
task.delay(30, function()
    for _, f in ipairs(restore) do pcall(f) end
    for k, v in pairs(counts) do p("calls " .. k .. " = " .. v) end
    pcall(function() if makefolder and not isfolder("king_hub") then makefolder("king_hub") end end)
    pcall(writefile, "king_hub/pf_probe5.txt", table.concat(out, "\n") .. "\n")
    p("done, restored")
end)
