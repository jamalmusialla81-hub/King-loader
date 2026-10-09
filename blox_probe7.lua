-- Blox Strike probe 7: do the game's buffer remotes (UpdateCameraCFrame, ReplicateSound, tracers, muzzle flashes...)
-- carry positions of hidden (culled) players? Probe 6 only looked at plain Vector3 arguments, so it never read inside buffers.
-- This reads every plausible Vector3 inside each buffer, and:
--   * for VISIBLE enemies: checks which remotes keep giving a position on top of them (= the remote tracks players)
--   * when a hidden enemy comes back: checks which remotes gave a position near them WHILE hidden
--     (ignores the last 0.4 s before they reappear, that's just the game re-showing their character)
-- Listen-only, runs 90 s. Result -> console, hub log, king_hub/blox_probe7.txt, clipboard.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer
local out = {}
local function p(s)
    out[#out + 1] = tostring(s); print("[BXP7] " .. tostring(s))
    if shared and shared.MH_Log then pcall(shared.MH_Log, "BXP7 " .. tostring(s)) end
end
local WATCH = {
    UpdateCameraCFrame = true, ReplicateSound = true, CreateTracer = true, CreateCharacterMuzzleFlash = true,
    Action = true, CreateImpact = true, OwnerSnapshot = true, Bounce = true, CreateMarker = true,
    WeaponEquipResolved = true, StopSoundAtPosition = true, CharacterDamaged = true,
}
local function isCulled(plr)
    local ch = plr.Character
    return ch and ch.Parent and ch.Parent.Name == "_PVS_CulledCharacters"
end
local function rootOf(plr)
    local ch = plr.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end
local function plausible(v) return v == v and (v == 0 or (math.abs(v) > 0.01 and math.abs(v) < 5000)) end
local function positions(b)
    local list, len, off = {}, buffer.len(b), 0
    while off <= len - 12 do
        local x, y, z = buffer.readf32(b, off), buffer.readf32(b, off + 4), buffer.readf32(b, off + 8)
        if plausible(x) and plausible(y) and plausible(z) and (math.abs(x) + math.abs(y) + math.abs(z)) > 5 and y > -500 and y < 1500 then
            list[#list + 1] = {off = off, pos = Vector3.new(x, y, z)}
            off += 12
        else
            off += 1
        end
    end
    return list
end
local function hex(b, n)
    local t = {}
    for i = 0, math.min(buffer.len(b), n) - 1 do t[#t + 1] = string.format("%02x", buffer.readu8(b, i)) end
    return table.concat(t, " ")
end

-- UserId as the varint bytes the game uses (seen in RemoteSnapshot), to spot a remote naming a hidden player
local function varintBytes(n)
    local t = {}
    repeat
        local b = n % 128
        n = math.floor(n / 128)
        if n > 0 then b += 128 end
        t[#t + 1] = b
    until n == 0
    return t
end
local function hasBytes(b, seq)
    local len, n = buffer.len(b), #seq
    for i = 0, len - n do
        if buffer.readu8(b, i) == seq[1] then
            local ok = true
            for k = 2, n do if buffer.readu8(b, i + k - 1) ~= seq[k] then ok = false break end end
            if ok then return true end
        end
    end
    return false
end
local idBytes = {}
local function idOf(plr)
    local v = idBytes[plr]
    if not v then v = varintBytes(plr.UserId); idBytes[plr] = v end
    return v
end
local mentionHidden, mentionVisible = {}, {}   -- remote -> times it named a hidden / visible player

local recent = {}                 -- {t, pos, src, off}
local onVisible, fired = {}, {}   -- src -> times a position landed on a visible enemy / times fired
local hexSample = {}
local conns = {}
local function watch(r)
    if r.Name == "RemoteSnapshot" then return end
    local deep = WATCH[r.Name]
    conns[#conns + 1] = r.OnClientEvent:Connect(function(...)
        local src = r.Name
        local now = os.clock()
        for _, a in ipairs({...}) do
            if typeof(a) == "buffer" and buffer.len(a) >= 5 then
                -- does this message name another player by UserId, and are they hidden right now?
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= lp and hasBytes(a, idOf(plr)) then
                        if isCulled(plr) then mentionHidden[src] = (mentionHidden[src] or 0) + 1
                        else mentionVisible[src] = (mentionVisible[src] or 0) + 1 end
                    end
                end
            end
            if deep and typeof(a) == "buffer" then
                fired[src] = (fired[src] or 0) + 1
                if not hexSample[src] then hexSample[src] = string.format("len=%d %s", buffer.len(a), hex(a, 48)) end
                local list = positions(a)
                for _, e in ipairs(list) do
                    table.insert(recent, {t = now, pos = e.pos, src = src, off = e.off})
                end
                -- does it sit on a visible player right now?
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= lp and not isCulled(plr) then
                        local hrp = rootOf(plr)
                        if hrp then
                            for _, e in ipairs(list) do
                                if (e.pos - hrp.Position).Magnitude < 4 then
                                    local k = src .. "@" .. e.off
                                    onVisible[k] = (onVisible[k] or 0) + 1
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
        while #recent > 3000 do table.remove(recent, 1) end
    end)
end
for _, d in ipairs(RS:GetDescendants()) do
    if d:IsA("RemoteEvent") or d:IsA("UnreliableRemoteEvent") then watch(d) end
end

local wasCulled, culledAt = {}, {}
local events, longEvents, hits = 0, 0, 0
local hitBySrc = {}
conns[#conns + 1] = RunService.Heartbeat:Connect(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and plr.Character then
            local c = isCulled(plr)
            if c and not wasCulled[plr] then culledAt[plr] = os.clock() end
            if wasCulled[plr] and not c then
                local since, back = culledAt[plr] or 0, os.clock()
                local hidFor = back - since
                task.delay(0.15, function()
                    local hrp = rootOf(plr)
                    if not hrp or hidFor < 1.5 then return end     -- short flickers say nothing
                    local real = hrp.Position
                    local best, bestSrc, bestAge
                    for _, e in ipairs(recent) do
                        if e.t > since + 0.3 and e.t < back - 0.4 and back - e.t < 3 then
                            local d = (e.pos - real).Magnitude
                            if not best or d < best then best, bestSrc, bestAge = d, e.src .. "@" .. e.off, back - e.t end
                        end
                    end
                    longEvents += 1
                    local ok = best and best < 12
                    if ok then hits += 1; hitBySrc[bestSrc] = (hitBySrc[bestSrc] or 0) + 1 end
                    p(string.format("%s back after %.1fs hidden: closest buffer position while hidden = %s %s",
                        plr.Name, hidFor, best and string.format("%.1f studs (%s, %.1fs before)", best, bestSrc, bestAge) or "none",
                        ok and "=> LIVE SIGNAL" or "=> nothing near"))
                end)
                events += 1
            end
            wasCulled[plr] = c
        end
    end
end)

p("listening for 90 s - play normally; enemies hidden for a few seconds then coming back is what counts")
for i = 1, 9 do
    task.wait(10)
    print(string.format("[BXP7] %ds... long hides checked: %d (live signal: %d)", i * 10, longEvents, hits))
end
for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
task.wait(0.3)

for src, s in pairs(hexSample) do p("hex " .. src .. " x" .. (fired[src] or 0) .. ": " .. s) end
local rows = {}
for k, n in pairs(onVisible) do rows[#rows + 1] = {k, n} end
table.sort(rows, function(a, b) return a[2] > b[2] end)
local parts = {}
for i = 1, math.min(12, #rows) do parts[#parts + 1] = rows[i][1] .. " x" .. rows[i][2] end
p("positions landing on VISIBLE players (remote@byteOffset): " .. (#parts > 0 and table.concat(parts, " | ") or "none"))
local mh = {}
for src, n in pairs(mentionHidden) do mh[#mh + 1] = {src, n} end
table.sort(mh, function(a, b) return a[2] > b[2] end)
local mp = {}
for i = 1, math.min(15, #mh) do mp[#mp + 1] = string.format("%s x%d (visible x%d)", mh[i][1], mh[i][2], mentionVisible[mh[i][1]] or 0) end
p("remotes naming a HIDDEN player by UserId: " .. (#mp > 0 and table.concat(mp, " | ") or "none"))
local hp = {}
for k, n in pairs(hitBySrc) do hp[#hp + 1] = k .. " x" .. n end
p("matches while hidden: " .. (#hp > 0 and table.concat(hp, ", ") or "none"))
p(string.format("RESULT: %d long hides checked, %d had a buffer position near where they came back", longEvents, hits))
pcall(function() if makefolder and not isfolder("king_hub") then makefolder("king_hub") end end)
pcall(writefile, "king_hub/blox_probe7.txt", table.concat(out, "\n") .. "\n")
p("done")
local copy = setclipboard or toclipboard or (syn and syn.write_clipboard)
if copy then pcall(copy, table.concat(out, "\n")); print("[BXP7] copied to clipboard - just paste it") end
