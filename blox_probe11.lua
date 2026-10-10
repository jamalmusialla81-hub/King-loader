-- Blox Strike probe 11: RECORDER. Captures raw samples of every remote message (so they can be decoded offline),
-- each one stamped with the ground truth at that moment: every player's position and whether they're hidden.
-- Priority: zstd-compressed messages (couldn't be unpacked in-game), unknown formats (BotCombat, Control,
-- OwnerSnapshot), and anything that arrives while someone is hidden. At most 4 samples per remote, 320 bytes each.
-- Listen-only, 90 s. Result -> king_hub/blox_probe11.txt and clipboard (paste it; if it's too long, upload the file).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local lp = Players.LocalPlayer
local lines = {}
local function p(s) lines[#lines + 1] = tostring(s); print("[BXP11] " .. tostring(s)) end
local MAX_PER, MAX_BYTES = 4, 320
local function isCulled(plr)
    local ch = plr.Character
    return ch and ch.Parent and ch.Parent.Name == "_PVS_CulledCharacters"
end
local function hex(b)
    local n = math.min(buffer.len(b), MAX_BYTES)
    local t = table.create(n)
    for i = 0, n - 1 do t[i + 1] = string.format("%02x", buffer.readu8(b, i)) end
    return table.concat(t)
end
local function kind(b)
    local len = buffer.len(b)
    if len >= 10 and buffer.readu8(b, 0) == 1 and buffer.readu32(b, 1) == 0xFD2FB528 then
        -- first block type: 0 raw, 1 rle, 2 compressed
        local desc = buffer.readu8(b, 5)
        local single = bit32.band(bit32.rshift(desc, 5), 1) == 1
        local pos = 6 + (single and 0 or 1) + ({0, 1, 2, 4})[bit32.band(desc, 3) + 1] + ({single and 1 or 0, 2, 4, 8})[bit32.rshift(desc, 6) + 1]
        if pos + 3 <= len then
            local h = buffer.readu8(b, pos) + buffer.readu8(b, pos + 1) * 256
            local bt = math.floor(h / 2) % 4
            return bt == 2 and "zstd-compressed" or "zstd-raw"
        end
        return "zstd-?"
    end
    return "other"
end
-- ground truth: compact list of players "Name:H/V:x,y,z"
local function truth()
    local t = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local pos = hrp.Position
            t[#t + 1] = string.format("%s:%s:%d:%.1f,%.1f,%.1f", plr.Name, plr == lp and "ME" or (isCulled(plr) and "H" or "V"), plr.UserId, pos.X, pos.Y, pos.Z)
        end
    end
    return table.concat(t, ";")
end
local function describeArg(a)
    local ta = typeof(a)
    if ta == "buffer" then return "buffer" end
    if ta == "Instance" then return "Instance:" .. a:GetFullName() end
    if ta == "table" then
        local parts = {}
        for k, v in pairs(a) do
            parts[#parts + 1] = tostring(k) .. "=" .. (typeof(v) == "Instance" and v:GetFullName() or typeof(v))
            if #parts > 6 then break end
        end
        return "table{" .. table.concat(parts, ",") .. "}"
    end
    return ta .. ":" .. tostring(a)
end

local samples = {}          -- remote name -> {count, kept = {...}, kinds = {}}
local conns = {}
local function anyHidden()
    for _, plr in ipairs(Players:GetPlayers()) do if plr ~= lp and isCulled(plr) then return true end end
    return false
end
local function watch(r)
    conns[#conns + 1] = r.OnClientEvent:Connect(function(...)
        local args = {...}
        local s = samples[r.Name]
        if not s then s = {count = 0, kept = {}, kinds = {}, path = r:GetFullName()}; samples[r.Name] = s end
        s.count += 1
        for i, a in ipairs(args) do
            if typeof(a) == "buffer" then
                local k = kind(a)
                s.kinds[k] = (s.kinds[k] or 0) + 1
                -- keep: compressed / other formats first, then ones that arrive while someone is hidden
                local want = (#s.kept < MAX_PER) and (k ~= "zstd-raw" or anyHidden() or #s.kept < 2)
                if want then
                    local extra = {}
                    for j, b in ipairs(args) do if j ~= i then extra[#extra + 1] = describeArg(b) end end
                    s.kept[#s.kept + 1] = string.format("SAMPLE %s arg%d %s len=%d t=%.2f\n  extra: %s\n  truth: %s\n  hex: %s",
                        r.Name, i, k, buffer.len(a), os.clock(), table.concat(extra, " | "), truth(), hex(a))
                end
                break
            end
        end
    end)
end
local okR, rrs = pcall(function() return game:GetService("RobloxReplicatedStorage") end)
for _, d in ipairs(game:GetDescendants()) do
    if (d:IsA("RemoteEvent") or d:IsA("UnreliableRemoteEvent")) and not (okR and rrs and d:IsDescendantOf(rrs)) then pcall(watch, d) end
end
if getnilinstances then
    for _, d in ipairs(getnilinstances()) do
        if d:IsA("RemoteEvent") or d:IsA("UnreliableRemoteEvent") then pcall(watch, d) end
    end
end
print("[BXP11] recording 90 s - play a normal round (shooting, enemies out of sight, bots nearby helps)")
for i = 1, 9 do task.wait(10); print("[BXP11] " .. i * 10 .. "s...") end
for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end

p("probe11 placeId=" .. game.PlaceId .. " me=" .. lp.Name .. ":" .. lp.UserId)
local names = {}
for n in pairs(samples) do names[#names + 1] = n end
table.sort(names)
for _, n in ipairs(names) do
    local s = samples[n]
    local ks = {}
    for k, c in pairs(s.kinds) do ks[#ks + 1] = k .. " x" .. c end
    p(string.format("REMOTE %s x%d [%s] %s", n, s.count, table.concat(ks, ", "), s.path))
end
for _, n in ipairs(names) do
    for _, line in ipairs(samples[n].kept) do p(line) end
end
local text = table.concat(lines, "\n")
pcall(function() if makefolder and not isfolder("king_hub") then makefolder("king_hub") end end)
pcall(writefile, "king_hub/blox_probe11.txt", text .. "\n")
local copy = setclipboard or toclipboard
if copy then pcall(copy, text) end
print(string.format("[BXP11] done: %d characters, saved to king_hub/blox_probe11.txt and copied to clipboard", #text))
