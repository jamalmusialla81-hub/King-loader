-- Blox Strike probe 5: does RemoteSnapshot carry the REAL positions of culled (hidden) players?
-- Listen-only, runs 90 s. Every time a culled player comes back into view, it checks whether the last snapshots
-- already contained a position where that player reappeared. Result -> console, hub log, king_hub/blox_probe5.txt, clipboard.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer
local out = {}
local function p(s)
    out[#out + 1] = tostring(s); print("[BXP5] " .. tostring(s))
    if shared and shared.MH_Log then pcall(shared.MH_Log, "BXP5 " .. tostring(s)) end
end
local rem = RS:WaitForChild("MovementV2Remotes"):WaitForChild("RemoteSnapshot")

local function plausible(v) return v == v and (v == 0 or (math.abs(v) > 0.01 and math.abs(v) < 3000)) end
-- every plausible Vector3 in a buffer, with the 8 bytes in front of it (probably the entity id / flags)
local function positions(b)
    local list, len = {}, buffer.len(b)
    local off = 0
    while off <= len - 12 do
        local x, y, z = buffer.readf32(b, off), buffer.readf32(b, off + 4), buffer.readf32(b, off + 8)
        if plausible(x) and plausible(y) and plausible(z) and (math.abs(x) + math.abs(y) + math.abs(z)) > 1 and y > -500 and y < 1500 then
            local pre = {}
            for i = math.max(0, off - 8), off - 1 do pre[#pre + 1] = string.format("%02x", buffer.readu8(b, i)) end
            list[#list + 1] = {off = off, pos = Vector3.new(x, y, z), pre = table.concat(pre, " ")}
            off += 12
        else
            off += 1
        end
    end
    return list
end
local function isCulled(plr)
    local ch = plr.Character
    return ch and ch.Parent and ch.Parent.Name == "_PVS_CulledCharacters"
end

local recent = {}          -- last few full snapshots: {t, list}
local counts = {}
local fullCount = 0
local conn = rem.OnClientEvent:Connect(function(b)
    if typeof(b) ~= "buffer" then return end
    local len = buffer.len(b)
    if len < 150 then return end           -- only full snapshots
    fullCount += 1
    local list = positions(b)
    counts[#list] = (counts[#list] or 0) + 1
    table.insert(recent, 1, {t = os.clock(), list = list, n = len > 26 and buffer.readu8(b, 26) or -1})
    if #recent > 6 then table.remove(recent) end
end)

-- watch for culled -> visible transitions
local wasCulled = {}
local events, hits = 0, 0
local idSeen = {}
local hb = RunService.Heartbeat:Connect(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and plr.Character then
            local c = isCulled(plr)
            if wasCulled[plr] and not c then
                -- just came back: snapshot what the server sent BEFORE we could see them
                local before = {}
                for _, snap in ipairs(recent) do before[#before + 1] = snap end
                task.delay(0.25, function()
                    local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end
                    local real = hrp.Position
                    local best, bestPre
                    for _, snap in ipairs(before) do
                        for _, e in ipairs(snap.list) do
                            local d = (e.pos - real).Magnitude
                            if not best or d < best then best, bestPre = d, e.pre end
                        end
                    end
                    events += 1
                    if best and best < 8 then hits += 1 end
                    p(string.format("%s came back at (%.0f,%.0f,%.0f): closest position in the snapshots sent BEFORE = %s studs away %s  id-bytes[%s]",
                        plr.Name, real.X, real.Y, real.Z, best and string.format("%.1f", best) or "none",
                        (best and best < 8) and "=> SERVER WAS SENDING IT" or "=> not sent", tostring(bestPre)))
                end)
            end
            wasCulled[plr] = c
        end
    end
end)

-- also learn the id bytes for visible players (so the ESP can tell who is who)
task.spawn(function()
    for _ = 1, 3 do
        task.wait(3)
        local snap = recent[1]
        if snap then
            local rows = {}
            for _, e in ipairs(snap.list) do
                local who = "?"
                for _, plr in ipairs(Players:GetPlayers()) do
                    local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and not isCulled(plr) and (hrp.Position - e.pos).Magnitude < 4 then who = plr.Name end
                end
                rows[#rows + 1] = string.format("@%d [%s] (%.0f,%.0f,%.0f)=%s", e.off, e.pre, e.pos.X, e.pos.Y, e.pos.Z, who)
            end
            p("snapshot count-byte=" .. snap.n .. " entries: " .. table.concat(rows, " | "))
        end
    end
end)

p("listening for 90 s - play normally, let enemies go out of view and come back")
for i = 1, 9 do
    task.wait(10)
    print(string.format("[BXP5] %ds... culled players seen coming back: %d", i * 10, events))
end
conn:Disconnect(); hb:Disconnect()
task.wait(0.5)
local cs = {}
for k, v in pairs(counts) do cs[#cs + 1] = k .. " positions x" .. v end
p("full snapshots: " .. fullCount .. " | positions per snapshot: " .. table.concat(cs, ", "))
p(string.format("RESULT: %d culled players came back, %d of them were already in the server data", events, hits))
pcall(function() if makefolder and not isfolder("king_hub") then makefolder("king_hub") end end)
pcall(writefile, "king_hub/blox_probe5.txt", table.concat(out, "\n") .. "\n")
p("done")
local copy = setclipboard or toclipboard or (syn and syn.write_clipboard)
if copy then pcall(copy, table.concat(out, "\n")); print("[BXP5] copied to clipboard - just paste it") end
