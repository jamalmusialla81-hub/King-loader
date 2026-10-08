-- Blox Strike probe 8: are the UserId-0 entries in RemoteSnapshot hidden (culled) players sent anonymously?
-- Entry layout (from probe 5): <UserId varint><sequence varint><state u8><x f32><y f32><z f32><~15 more bytes>.
-- Some entries carry UserId 0 and match no visible player. This checks:
--   1. per snapshot: number of id-0 entries vs number of hidden players right now (equal every time = it's them)
--   2. when a player hidden for 1.5 s+ comes back: was an id-0 entry near that spot while they were still hidden?
--      (the last 0.5 s before they reappear is ignored - the server re-sends players just before they show)
--   3. the state byte and the trailing bytes of visible players, next to their real speed, to decode them
-- Listen-only, runs 90 s. Result -> console, hub log, king_hub/blox_probe8.txt, clipboard.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer
local out = {}
local function p(s)
    out[#out + 1] = tostring(s); print("[BXP8] " .. tostring(s))
    if shared and shared.MH_Log then pcall(shared.MH_Log, "BXP8 " .. tostring(s)) end
end
local rem = RS:WaitForChild("MovementV2Remotes"):WaitForChild("RemoteSnapshot")

local function isCulled(plr)
    local ch = plr.Character
    return ch and ch.Parent and ch.Parent.Name == "_PVS_CulledCharacters"
end
local function rootOf(plr)
    local ch = plr.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end
local function hex(b, from, n)
    local t = {}
    for i = from, math.min(buffer.len(b), from + n) - 1 do t[#t + 1] = string.format("%02x", buffer.readu8(b, i)) end
    return table.concat(t, " ")
end
local function plausible(v) return v == v and (v == 0 or (math.abs(v) > 0.01 and math.abs(v) < 5000)) end
local function posAt(b, off)
    if off < 0 or off > buffer.len(b) - 12 then return nil end
    local x, y, z = buffer.readf32(b, off), buffer.readf32(b, off + 4), buffer.readf32(b, off + 8)
    if plausible(x) and plausible(y) and plausible(z) and y > -500 and y < 1500 and (math.abs(x) + math.abs(z)) > 1 then
        return Vector3.new(x, y, z)
    end
end
-- read a varint at off: value, next offset
local function varint(b, off)
    local v, mul, i = 0, 1, off
    while i < buffer.len(b) and i - off < 6 do
        local c = buffer.readu8(b, i)
        v += (c % 128) * mul; mul *= 128; i += 1
        if c < 128 then return v, i end
    end
    return nil
end
-- an entry starting at s: id, seq, state, pos offset
local function entryAt(b, s)
    local id, i = varint(b, s)
    if not id then return nil end
    local seq, j = varint(b, i)
    if not seq or j >= buffer.len(b) then return nil end
    local state = buffer.readu8(b, j)
    local pos = posAt(b, j + 1)
    if not pos then return nil end
    return {start = s, id = id, seq = seq, state = state, posOff = j + 1, pos = pos}
end

local idSet = {}
local function refreshIds() idSet = {}; for _, pl in ipairs(Players:GetPlayers()) do idSet[pl.UserId] = pl end end
refreshIds()
Players.PlayerAdded:Connect(refreshIds)

-- parse one full snapshot into entries: find the first entry, then walk forward
local REST = 15
local function parse(b)
    local len = buffer.len(b)
    local list = {}
    local first
    for off = 4, math.min(len - 12, 80) do
        if posAt(b, off) then
            for s = off - 4, math.max(0, off - 12), -1 do
                local e = entryAt(b, s)
                if e and e.posOff == off and (e.id == 0 or idSet[e.id]) then first = e break end
            end
            if first then break end
        end
    end
    if not first then return list end
    local e = first
    while e do
        list[#list + 1] = e
        local nextStart = e.posOff + 12 + REST
        local n = entryAt(b, nextStart)
        if not n then
            -- trailing size differs: search a little around the expected start
            for d = -6, 10 do
                local c = entryAt(b, nextStart + d)
                if c and (c.id == 0 or idSet[c.id]) then n = c; e.restLen = REST + d break end
            end
        end
        if n then e.rest = hex(b, e.posOff + 12, (e.restLen or REST)) end
        e = n
        if #list > 40 then break end
    end
    return list
end

local recent = {}                -- {t, list}
local countPairs = {}            -- "id0=N hidden=M" -> count
local stateRows = {}             -- state byte -> {n, speedSum}
local restSamples = {}
local full, parsed, idZeroTotal = 0, 0, 0
local lastVisPos = {}
local conn = rem.OnClientEvent:Connect(function(b)
    if typeof(b) ~= "buffer" or buffer.len(b) < 60 then return end
    full += 1
    local list = parse(b)
    if #list == 0 then return end
    parsed += 1
    local now = os.clock()
    table.insert(recent, {t = now, list = list})
    while #recent > 200 do table.remove(recent, 1) end
    local zero = 0
    for _, e in ipairs(list) do
        if e.id == 0 then zero += 1 end
        local plr = idSet[e.id]
        if plr and plr ~= lp and not isCulled(plr) then
            local hrp = rootOf(plr)
            if hrp then
                local spd = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z).Magnitude
                local r = stateRows[e.state] or {n = 0, s = 0, air = 0}
                r.n += 1; r.s += spd
                if math.abs(hrp.AssemblyLinearVelocity.Y) > 2 then r.air += 1 end
                stateRows[e.state] = r
                if #restSamples < 8 and e.rest then
                    restSamples[#restSamples + 1] = string.format("%s state=%02x speed=%.1f velY=%.1f rest=[%s]",
                        plr.Name, e.state, spd, hrp.AssemblyLinearVelocity.Y, e.rest)
                end
            end
        end
    end
    idZeroTotal += zero
    local hidden = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and isCulled(plr) then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health > 0 then hidden += 1 end
        end
    end
    local k = "id0=" .. zero .. " hidden=" .. hidden
    countPairs[k] = (countPairs[k] or 0) + 1
end)

-- the decisive test: culled -> visible
local wasCulled, culledAt = {}, {}
local longHides, near, nearOther = 0, 0, 0
local hb = RunService.Heartbeat:Connect(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and plr.Character then
            local c = isCulled(plr)
            if c and not wasCulled[plr] then culledAt[plr] = os.clock() end
            if wasCulled[plr] and not c then
                local since, back = culledAt[plr] or 0, os.clock()
                if back - since >= 1.5 then
                    task.delay(0.15, function()
                        local hrp = rootOf(plr)
                        if not hrp then return end
                        local real = hrp.Position
                        -- id-0 entries from the window [back-1.5, back-0.5], while they were certainly still hidden
                        local best, bestAge
                        local otherBest
                        for _, snap in ipairs(recent) do
                            if snap.t > since + 0.3 and snap.t < back - 0.5 and back - snap.t < 1.5 then
                                for _, e in ipairs(snap.list) do
                                    local d = (e.pos - real).Magnitude
                                    if e.id == 0 then
                                        if not best or d < best then best, bestAge = d, back - snap.t end
                                    elseif e.id == plr.UserId then
                                        if not otherBest or d < otherBest then otherBest = d end
                                    end
                                end
                            end
                        end
                        longHides += 1
                        if best and best < 12 then near += 1 end
                        if otherBest and otherBest < 12 then nearOther += 1 end
                        p(string.format("%s back after %.1fs hidden at (%.0f,%.0f,%.0f): nearest id-0 entry %s | own-id entry while hidden: %s",
                            plr.Name, back - since, real.X, real.Y, real.Z,
                            best and string.format("%.1f studs, %.1fs before", best, bestAge) or "none",
                            otherBest and string.format("%.1f studs", otherBest) or "none"))
                    end)
                end
            end
            wasCulled[plr] = c
        end
    end
end)

p("listening for 90 s - play a normal round; enemies hiding for a few seconds then showing is what counts")
task.wait(4)
do  -- one decoded snapshot as a sanity check
    local snap = recent[#recent]
    if snap then
        local rows = {}
        for _, e in ipairs(snap.list) do
            local plr = idSet[e.id]
            rows[#rows + 1] = string.format("id=%s seq=%d state=%02x (%.0f,%.0f,%.0f)%s", plr and plr.Name or tostring(e.id), e.seq, e.state,
                e.pos.X, e.pos.Y, e.pos.Z, plr and isCulled(plr) and " CULLED" or "")
        end
        p("decoded snapshot: " .. table.concat(rows, " | "))
    end
end
for i = 1, 8 do
    task.wait(10.75)
    print(string.format("[BXP8] %ds... long hides checked: %d (id-0 entry near them: %d)", 4 + math.floor(i * 10.75), longHides, near))
end
conn:Disconnect(); hb:Disconnect()
task.wait(0.3)

local cp = {}
for k, n in pairs(countPairs) do cp[#cp + 1] = {k, n} end
table.sort(cp, function(a, b) return a[2] > b[2] end)
local cs = {}
for i = 1, math.min(12, #cp) do cs[#cs + 1] = cp[i][1] .. " x" .. cp[i][2] end
p(string.format("snapshots: %d full, %d parsed, %d id-0 entries total", full, parsed, idZeroTotal))
p("id-0 count vs hidden players (same numbers every time = id-0 entries ARE the hidden players): " .. table.concat(cs, ", "))
local st = {}
for s, r in pairs(stateRows) do st[#st + 1] = string.format("%02x: n=%d avgSpeed=%.1f inAir=%d", s, r.n, r.s / r.n, r.air) end
table.sort(st)
p("state byte vs real movement (visible players): " .. table.concat(st, " | "))
for _, r in ipairs(restSamples) do p("sample " .. r) end
p(string.format("RESULT: %d long hides, an id-0 entry was near the comeback spot in %d of them (own-id entry while hidden: %d)", longHides, near, nearOther))
pcall(function() if makefolder and not isfolder("king_hub") then makefolder("king_hub") end end)
pcall(writefile, "king_hub/blox_probe8.txt", table.concat(out, "\n") .. "\n")
p("done")
local copy = setclipboard or toclipboard or (syn and syn.write_clipboard)
if copy then pcall(copy, table.concat(out, "\n")); print("[BXP8] copied to clipboard - just paste it") end
