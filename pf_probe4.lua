-- PF probe 4: require the game's own weapon / bullet modules and list their contents. Read-only (require only reads the cached module).
-- Run in a match:  loadstring(game:HttpGet("https://raw.githubusercontent.com/jamalmusialla81-hub/King-loader/claude/compassionate-darwin-n9u6yv/pf_probe4.lua"))()
local out = {}
local function p(s) out[#out + 1] = tostring(s); print("[PF4] " .. tostring(s)) end
local gi = debug.getinfo or getinfo
local WANT = {"bulletcheck", "clientweaponmanager", "weaponmanagementinterface", "weaponmanagementevents", "projectile", "ballistic", "firearm", "shoot", "particle", "physics", "trajectory", "camera"}
local function describe(v)
    local t = typeof(v)
    if t == "function" then local ok, i = pcall(gi, v); return "function(params=" .. tostring(ok and i.numparams) .. ")" end
    if t == "table" then local n = 0 for _ in pairs(v) do n += 1 end return "table(" .. n .. ")" end
    return t
end
local seen = 0
for _, m in ipairs(getloadedmodules()) do
    local l = m.Name:lower()
    local hit = false
    for _, w in ipairs(WANT) do if l == w or (#w > 6 and l:find(w, 1, true)) then hit = true break end end
    if hit and seen < 14 and not m:GetFullName():find("WeaponDatabase") and not m:GetFullName():find("WeaponBlueprints") then
        seen += 1
        local ok, res = pcall(require, m)
        if not ok then p(m:GetFullName() .. " -> require failed: " .. tostring(res):sub(1, 80))
        elseif type(res) == "table" then
            local keys, n = {}, 0
            for k, v in pairs(res) do n += 1 if n <= 45 then keys[#keys + 1] = tostring(k) .. ":" .. describe(v) end end
            p(m:GetFullName() .. " -> table(" .. n .. ") {" .. table.concat(keys, ", ") .. "}")
        else p(m:GetFullName() .. " -> " .. describe(res)) end
    end
end
-- also: any other loaded module whose table has a bullet-ish key
local extra = 0
for _, m in ipairs(getloadedmodules()) do
    local ok, res = pcall(require, m)
    if ok and type(res) == "table" and extra < 15 then
        for k, v in pairs(res) do
            if type(k) == "string" and type(v) == "function" then
                local l = k:lower()
                if l:find("bullet") or l:find("shoot") or l:find("fire") or l:find("projectile") then extra += 1 p("key '" .. k .. "' in " .. m:GetFullName()) break end
            end
        end
    end
end
pcall(function() if makefolder and not isfolder("king_hub") then makefolder("king_hub") end end)
pcall(writefile, "king_hub/pf_probe4.txt", table.concat(out, "\n") .. "\n")
p("done")
