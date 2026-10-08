-- PF probe 6: which scripts do the functions that getgc can see belong to? Read-only.
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/jamalmusialla81-hub/King-loader/claude/compassionate-darwin-n9u6yv/pf_probe6.lua"))()
local out = {}
local function p(s) out[#out + 1] = tostring(s); print("[PF6] " .. tostring(s)) end
local gi = debug.getinfo or getinfo
local counts, total, tables = {}, 0, 0
for i, v in ipairs(getgc(true)) do
    if i % 15000 == 0 then task.wait() end
    if type(v) == "function" then
        total += 1
        local ok, info = pcall(gi, v, "S")
        local src = ok and info and tostring(info.short_src) or "?"
        counts[src] = (counts[src] or 0) + 1
    elseif type(v) == "table" then tables += 1 end
end
p("functions=" .. total .. " tables=" .. tables)
local list = {}
for s, n in pairs(counts) do list[#list + 1] = {s, n} end
table.sort(list, function(a, b) return a[2] > b[2] end)
for i = 1, math.min(25, #list) do p(list[i][2] .. "  " .. list[i][1]) end
p("distinct sources: " .. #list)
p("has getactors=" .. tostring(getactors ~= nil) .. " getsenv=" .. tostring(getsenv ~= nil) .. " getscripts=" .. tostring(getscripts ~= nil))
pcall(function() if makefolder and not isfolder("king_hub") then makefolder("king_hub") end end)
pcall(writefile, "king_hub/pf_probe6.txt", table.concat(out, "\n") .. "\n")
p("done")
