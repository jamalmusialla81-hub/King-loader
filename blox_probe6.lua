-- Blox Strike probe 6: is there ANY live signal for hidden (culled) players? Sounds and other remotes.
-- RemoteSnapshot stops sending a player's position once they're culled, so this looks elsewhere:
--   1. every 3D sound that plays (footsteps, shots, reloads) and where it played
--   2. every RemoteEvent / UnreliableRemoteEvent the game fires at us, and any positions in its arguments
-- When a culled player comes back into view, it checks which of those had already given a position near where they
-- reappeared. Listen-only, runs 90 s. Result -> console, hub log, king_hub/blox_probe6.txt, clipboard.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer
local out = {}
local function p(s)
    out[#out + 1] = tostring(s); print("[BXP6] " .. tostring(s))
    if shared and shared.MH_Log then pcall(shared.MH_Log, "BXP6 " .. tostring(s)) end
end
local function isCulled(plr)
    local ch = plr.Character
    return ch and ch.Parent and ch.Parent.Name == "_PVS_CulledCharacters"
end
local function anyCulled()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and isCulled(plr) then return true end
    end
    return false
end
local function myPos()
    local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position
end

-- recent positional signals: {t, pos, src}
local recent = {}
local function remember(pos, src)
    local me = myPos()
    if me and (pos - me).Magnitude < 6 then return end      -- our own footsteps / shots
    table.insert(recent, {t = os.clock(), pos = pos, src = src})
    if #recent > 400 then table.remove(recent, 1) end
end
local srcCount, srcWhileCulled = {}, {}
local function count(src)
    srcCount[src] = (srcCount[src] or 0) + 1
    if anyCulled() then srcWhileCulled[src] = (srcWhileCulled[src] or 0) + 1 end
end

local conns = {}
-- 1. sounds
local function soundPos(s)
    local par = s.Parent
    if not par then return nil end
    if par:IsA("BasePart") then return par.Position end
    if par:IsA("Attachment") then return par.WorldPosition end
    local m = par:FindFirstAncestorOfClass("Model")
    if m and m.PrimaryPart then return m.PrimaryPart.Position end
    return nil
end
local function watchSound(s)
    conns[#conns + 1] = s.Played:Connect(function()
        local pos = soundPos(s)
        if pos then
            local src = "sound:" .. s.Name
            count(src); remember(pos, src)
        end
    end)
end
for _, d in ipairs(workspace:GetDescendants()) do if d:IsA("Sound") then watchSound(d) end end
conns[#conns + 1] = workspace.DescendantAdded:Connect(function(d)
    if d:IsA("Sound") then
        watchSound(d)
        task.defer(function()
            if d.Parent and d.Playing then
                local pos = soundPos(d)
                if pos then local src = "sound+:" .. d.Name; count(src); remember(pos, src) end
            end
        end)
    end
end)

-- 2. remotes
local function scan(v, src, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "Vector3" then remember(v, src)
    elseif t == "CFrame" then remember(v.Position, src)
    elseif t == "Instance" and v:IsA("BasePart") then remember(v.Position, src .. "(part)")
    elseif t == "table" and depth < 3 then
        local n = 0
        for _, x in pairs(v) do n += 1; if n > 50 then break end; scan(x, src, depth + 1) end
    end
end
local samples = {}
local function describe(...)
    local parts = {}
    for i, a in ipairs({...}) do
        if i > 6 then break end
        local t = typeof(a)
        if t == "buffer" then parts[#parts + 1] = "buffer(" .. buffer.len(a) .. ")"
        elseif t == "Instance" then parts[#parts + 1] = a.ClassName .. ":" .. a.Name
        elseif t == "string" then parts[#parts + 1] = "\"" .. a:sub(1, 24) .. "\""
        else parts[#parts + 1] = t .. ":" .. tostring(a):sub(1, 30) end
    end
    return table.concat(parts, ", ")
end
local function watchRemote(r)
    if r.Name == "RemoteSnapshot" then return end
    conns[#conns + 1] = r.OnClientEvent:Connect(function(...)
        local src = "remote:" .. r.Name
        count(src)
        for _, a in ipairs({...}) do scan(a, src) end
        samples[src] = samples[src] or {}
        if #samples[src] < 2 and anyCulled() then samples[src][#samples[src] + 1] = describe(...) end
    end)
end
for _, d in ipairs(RS:GetDescendants()) do
    if d:IsA("RemoteEvent") or d:IsA("UnreliableRemoteEvent") then watchRemote(d) end
end
conns[#conns + 1] = RS.DescendantAdded:Connect(function(d)
    if d:IsA("RemoteEvent") or d:IsA("UnreliableRemoteEvent") then watchRemote(d) end
end)

-- ground truth: culled -> visible
local wasCulled, culledAt = {}, {}
local events, hits = 0, 0
local hitBySrc = {}
conns[#conns + 1] = RunService.Heartbeat:Connect(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and plr.Character then
            local c = isCulled(plr)
            if c and not wasCulled[plr] then culledAt[plr] = os.clock() end
            if wasCulled[plr] and not c then
                local since = culledAt[plr] or 0
                local hidFor = os.clock() - since
                task.delay(0.15, function()
                    local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end
                    local real, now = hrp.Position, os.clock()
                    -- best signal from the last 2 s while they were hidden
                    local best, bestSrc, bestAge
                    for _, e in ipairs(recent) do
                        if e.t > since and now - e.t < 2.2 then
                            local d = (e.pos - real).Magnitude
                            if not best or d < best then best, bestSrc, bestAge = d, e.src, now - e.t end
                        end
                    end
                    events += 1
                    local ok = best and best < 10
                    if ok then hits += 1; hitBySrc[bestSrc] = (hitBySrc[bestSrc] or 0) + 1 end
                    p(string.format("%s came back after %.1fs hidden: closest signal = %s %s",
                        plr.Name, hidFor, best and string.format("%.1f studs (%s, %.1fs old)", best, bestSrc, bestAge) or "none",
                        ok and "=> LIVE SIGNAL" or "=> nothing near"))
                end)
            end
            wasCulled[plr] = c
        end
    end
end)

p("listening for 90 s - play normally, let enemies go out of view and come back (more shooting/running = better)")
for i = 1, 9 do
    task.wait(10)
    print(string.format("[BXP6] %ds... hidden players seen coming back: %d (signal near them: %d)", i * 10, events, hits))
end
for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
task.wait(0.3)

local rows = {}
for src, n in pairs(srcWhileCulled) do rows[#rows + 1] = {src, n} end
table.sort(rows, function(a, b) return a[2] > b[2] end)
local parts = {}
for i = 1, math.min(25, #rows) do parts[#parts + 1] = rows[i][1] .. " x" .. rows[i][2] end
p("signals while someone was hidden: " .. table.concat(parts, " | "))
for src, list in pairs(samples) do p("sample " .. src .. ": " .. table.concat(list, "  ||  ")) end
local hp = {}
for src, n in pairs(hitBySrc) do hp[#hp + 1] = src .. " x" .. n end
p("matches by source: " .. (#hp > 0 and table.concat(hp, ", ") or "none"))
p(string.format("RESULT: %d hidden players came back, %d had a live signal near where they reappeared", events, hits))
pcall(function() if makefolder and not isfolder("king_hub") then makefolder("king_hub") end end)
pcall(writefile, "king_hub/blox_probe6.txt", table.concat(out, "\n") .. "\n")
p("done")
local copy = setclipboard or toclipboard or (syn and syn.write_clipboard)
if copy then pcall(copy, table.concat(out, "\n")); print("[BXP6] copied to clipboard - just paste it") end
