-- PF probe 3: opens up the one function that holds the bullet constants. Read-only.
-- Run in a match:  loadstring(game:HttpGet("https://raw.githubusercontent.com/jamalmusialla81-hub/King-loader/claude/compassionate-darwin-n9u6yv/pf_probe3.lua"))()
local out = {}
local function p(s) out[#out + 1] = tostring(s); print("[PF3] " .. tostring(s)) end
local gk = debug.getconstants or getconstants
local guv = debug.getupvalues or getupvalues
local gi = debug.getinfo or getinfo
local need = {firepos = 1, bulletspeed = 1, newbullet = 1, penetrationdepth = 1}
local target
for i, v in ipairs(getgc(true)) do
    if i % 15000 == 0 then task.wait() end
    if type(v) == "function" then
        local ok, c = pcall(gk, v)
        if ok and type(c) == "table" then
            local n = 0
            for _, k in pairs(c) do if type(k) == "string" and need[k:lower()] then n += 1 end end
            if n >= 3 then target = v break end
        end
    end
end
if not target then p("target function not found") else
    local info = gi(target)
    p(string.format("fn: name=%s src=%s line=%s nups=%s nparams=%s vararg=%s", tostring(info.name), tostring(info.short_src), tostring(info.currentline), tostring(info.nups), tostring(info.numparams), tostring(info.is_vararg)))
    local cs = {}
    for _, c in pairs(gk(target)) do if type(c) == "string" then cs[#cs + 1] = c end end
    p("constants: " .. table.concat(cs, " | "))
    local function describe(v, depth)
        local t = typeof(v)
        if t == "table" then
            local keys, n = {}, 0
            for k, val in pairs(v) do
                n += 1
                if n <= 40 then keys[#keys + 1] = tostring(k) .. ":" .. typeof(val) end
            end
            return "table(" .. n .. ") {" .. table.concat(keys, ", ") .. "}"
        elseif t == "function" then
            local ok, i = pcall(gi, v)
            return "function name=" .. tostring(ok and i.name) .. " nups=" .. tostring(ok and i.nups)
        end
        return t .. " " .. tostring(v):sub(1, 60)
    end
    for i, v in pairs(guv(target)) do p("upvalue " .. tostring(i) .. ": " .. describe(v)) end
end
pcall(function() if makefolder and not isfolder("king_hub") then makefolder("king_hub") end end)
pcall(writefile, "king_hub/pf_probe3.txt", table.concat(out, "\n") .. "\n")
p("done")
