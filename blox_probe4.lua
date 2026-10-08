-- Blox Strike probe 4: decode RemoteSnapshot buffers by matching their bytes against known player positions / ids.
-- Listen-only. Run ALIVE in a live round with enemies both visible and behind walls. Result -> console, hub log, king_hub/blox_probe4.txt, clipboard.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local lp = Players.LocalPlayer
local out = {}
local function p(s)
    out[#out + 1] = tostring(s); print("[BXP4] " .. tostring(s))
    if shared and shared.MH_Log then pcall(shared.MH_Log, "BXP4 " .. tostring(s)) end
end
local rem = RS:WaitForChild("MovementV2Remotes"):WaitForChild("RemoteSnapshot")

local function hex(b, n)
    local t = {}
    for i = 0, math.min(buffer.len(b), n) - 1 do t[#t + 1] = string.format("%02x", buffer.readu8(b, i)) end
    return table.concat(t, " ")
end
-- known players right now
local function known()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        local ch = plr.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if hrp then
            list[#list + 1] = {plr = plr, pos = hrp.Position, culled = ch.Parent and ch.Parent.Name == "_PVS_CulledCharacters", me = plr == lp}
        end
    end
    return list
end

local posHits = {}      -- "enc@offset" -> count
local idHits = {}       -- "enc@offset" -> count
local seenNames = {}    -- player name -> {events, culledAtTheTime}
local sizes = {}
local dumps = 0
local events = 0
local conn = rem.OnClientEvent:Connect(function(b)
    if typeof(b) ~= "buffer" then return end
    events += 1
    local len = buffer.len(b)
    sizes[len] = (sizes[len] or 0) + 1
    if dumps < 6 then dumps += 1; p(string.format("raw %d bytes: %s", len, hex(b, 64))) end
    local ks = known()
    -- positions as float32 / float64 / int16*k
    for off = 0, len - 12 do
        local x, y, z = buffer.readf32(b, off), buffer.readf32(b, off + 4), buffer.readf32(b, off + 8)
        if x == x and y == y and z == z and math.abs(x) < 1e5 and math.abs(y) < 1e5 and math.abs(z) < 1e5 then
            local v = Vector3.new(x, y, z)
            for _, k in ipairs(ks) do
                if not k.culled and (k.pos - v).Magnitude < 3 then
                    posHits["f32@" .. off] = (posHits["f32@" .. off] or 0) + 1
                    seenNames[k.plr.Name] = true
                end
            end
        end
    end
    -- player ids as u32 / f64 / u64-low
    for off = 0, len - 4 do
        local u = buffer.readu32(b, off)
        for _, k in ipairs(ks) do
            if u == k.plr.UserId then idHits["u32@" .. off] = (idHits["u32@" .. off] or 0) + 1 end
        end
    end
    for off = 0, len - 8 do
        local d = buffer.readf64(b, off)
        for _, k in ipairs(ks) do
            if d == k.plr.UserId then idHits["f64@" .. off] = (idHits["f64@" .. off] or 0) + 1 end
        end
    end
end)
task.wait(5)
conn:Disconnect()

local function top(t, n)
    local arr = {}
    for k, v in pairs(t) do arr[#arr + 1] = {k, v} end
    table.sort(arr, function(a, b) return a[2] > b[2] end)
    local s = {}
    for i = 1, math.min(n, #arr) do s[#s + 1] = arr[i][1] .. "x" .. arr[i][2] end
    return #s > 0 and table.concat(s, ", ") or "none"
end
local sz = {}
for k, v in pairs(sizes) do sz[#sz + 1] = k .. "B x" .. v end
p("events in 5s: " .. events .. " | sizes: " .. table.concat(sz, ", "))
p("position matches (float32 offset x count): " .. top(posHits, 10))
p("player id matches: " .. top(idHits, 10))
local names = {}
for n in pairs(seenNames) do names[#names + 1] = n end
p("players whose position appeared in the data: " .. (#names > 0 and table.concat(names, ", ") or "none"))
local st = {}
for _, k in ipairs(known()) do
    if not k.me then st[#st + 1] = k.plr.Name .. (k.culled and "(CULLED)" or "(visible)") .. " id=" .. k.plr.UserId end
end
p("players now: " .. table.concat(st, ", "))
pcall(function() if makefolder and not isfolder("king_hub") then makefolder("king_hub") end end)
pcall(writefile, "king_hub/blox_probe4.txt", table.concat(out, "\n") .. "\n")
p("done")
local copy = setclipboard or toclipboard or (syn and syn.write_clipboard)
if copy then pcall(copy, table.concat(out, "\n")); print("[BXP4] copied to clipboard - just paste it") end
