-- Blox Strike probe 10 (deep, MacSploit): is there ANY live data about hidden (culled) players on this client?
-- Probes 4-9 only covered remotes in ReplicatedStorage. This searches everything else:
--   A. game memory (getgc): tables the game uses to track players. First it finds table fields that hold a position on
--      top of a visible player, then watches whether those fields keep moving while that player is hidden.
--   B. every remote anywhere (Workspace, Players, nil-parented via getnilinstances), counted while players are hidden
--   C. hidden characters: any property / attribute / animation that still changes while they're culled
--   D. Vector3 / CFrame values and attributes anywhere that change while their owner is hidden
-- Listen-only, ~120 s. Expect one short freeze at the start (the memory scan). Result -> console, hub log,
-- king_hub/blox_probe10.txt, clipboard.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer
local out = {}
local function p(s)
    out[#out + 1] = tostring(s); print("[BXP10] " .. tostring(s))
    if shared and shared.MH_Log then pcall(shared.MH_Log, "BXP10 " .. tostring(s)) end
end
local function isCulled(plr)
    local ch = plr.Character
    return ch and ch.Parent and ch.Parent.Name == "_PVS_CulledCharacters"
end
local function rootOf(plr)
    local ch = plr.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end
local function hiddenNow()
    local t = {}
    for _, plr in ipairs(Players:GetPlayers()) do if plr ~= lp and isCulled(plr) then t[plr] = true end end
    return t
end
p(string.format("executor=%s getgc=%s getnilinstances=%s getconnections=%s",
    tostring(identifyexecutor and identifyexecutor() or "?"), tostring(getgc ~= nil), tostring(getnilinstances ~= nil), tostring(getconnections ~= nil)))

local conns = {}
local results = {}

-- ---------------------------------------------------------------- A. game memory
local cands = {}             -- {tbl, key, plr, kind, last, movedHidden, movedVisible, hiddenSamples}
local scanned, tablesSeen = false, 0
local function posOf(v)
    local t = typeof(v)
    if t == "Vector3" then return v end
    if t == "CFrame" then return v.Position end
    return nil
end
local function scanMemory()
    if not getgc then p("A: getgc not available") return end
    -- needs visible enemies to anchor on
    local anchors = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and not isCulled(plr) then
            local hrp = rootOf(plr)
            if hrp then anchors[#anchors + 1] = {plr = plr, pos = hrp.Position} end
        end
    end
    if #anchors < 2 then return false end
    local t0 = os.clock()
    local ok, gc = pcall(getgc, true)
    if not ok then p("A: getgc failed: " .. tostring(gc)) return true end
    local seenKey = {}
    for _, tbl in ipairs(gc) do
        if type(tbl) == "table" then
            tablesSeen += 1
            local n = 0
            local okIter = pcall(function()
                for k, v in next, tbl do
                    n += 1
                    if n > 60 then break end
                    local pos = posOf(v)
                    if pos then
                        for _, a in ipairs(anchors) do
                            if (pos - a.pos).Magnitude < 3.5 then
                                local id = tostring(tbl) .. "|" .. tostring(k)
                                if not seenKey[id] and #cands < 400 then
                                    seenKey[id] = true
                                    cands[#cands + 1] = {tbl = tbl, key = k, plr = a.plr, kind = typeof(v), last = pos,
                                        movedHidden = 0, movedVisible = 0, hiddenTicks = 0, keyName = tostring(k)}
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
    p(string.format("A: memory scan took %.2fs, %d tables, %d candidate fields sitting on %d visible players", os.clock() - t0, tablesSeen, #cands, #anchors))
    return true
end
local function trackMemory()
    local hidden = hiddenNow()
    for _, c in ipairs(cands) do
        local okR, v = pcall(rawget, c.tbl, c.key)
        local pos = okR and posOf(v)
        if pos then
            local moved = (pos - c.last).Magnitude > 0.3
            c.last = pos
            if hidden[c.plr] then
                c.hiddenTicks += 1
                if moved then c.movedHidden += 1 end
            elseif moved then
                c.movedVisible += 1
            end
        end
    end
end
-- when a hidden player comes back: did a candidate field already sit near their comeback spot?
local cmpBack, cmpHits = 0, {}

-- ---------------------------------------------------------------- B. every remote anywhere
local remoteStats = {}       -- name -> {path, n, nHidden, bytesHidden}
local function watchRemote(r)
    if remoteStats[r] then return end
    local st = {path = r:GetFullName(), n = 0, nHidden = 0}
    remoteStats[r] = st
    conns[#conns + 1] = r.OnClientEvent:Connect(function(...)
        st.n += 1
        if next(hiddenNow()) then st.nHidden += 1 end
    end)
end
local function sweepRemotes()
    local roots = {game:GetService("Workspace"), Players, game:GetService("Lighting"), game:GetService("SoundService"), lp:FindFirstChild("PlayerGui"), lp:FindFirstChild("PlayerScripts")}
    for _, root in ipairs(roots) do
        if root then
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("RemoteEvent") or d:IsA("UnreliableRemoteEvent") then watchRemote(d) end
            end
        end
    end
    if getnilinstances then
        for _, d in ipairs(getnilinstances()) do
            if d:IsA("RemoteEvent") or d:IsA("UnreliableRemoteEvent") then watchRemote(d) end
            pcall(function()
                for _, x in ipairs(d:GetDescendants()) do
                    if x:IsA("RemoteEvent") or x:IsA("UnreliableRemoteEvent") then watchRemote(x) end
                end
            end)
        end
    end
end

-- ---------------------------------------------------------------- C. hidden characters still changing?
local charChanges = {}       -- "Class.Property" -> count while hidden
local hookedChars = {}
local function hookChar(plr)
    local ch = plr.Character
    if not ch or hookedChars[ch] then return end
    hookedChars[ch] = true
    local function onChange(inst, prop)
        if isCulled(plr) then
            local k = inst.ClassName .. "." .. prop
            charChanges[k] = (charChanges[k] or 0) + 1
        end
    end
    local function hookInst(inst)
        if inst:IsA("Humanoid") or inst:IsA("BasePart") or inst:IsA("Motor6D") or inst:IsA("Animator") or inst:IsA("ValueBase") then
            conns[#conns + 1] = inst.Changed:Connect(function(prop) onChange(inst, prop) end)
        end
        conns[#conns + 1] = inst.AttributeChanged:Connect(function(a) onChange(inst, "@" .. a) end)
        if inst:IsA("Animator") then
            conns[#conns + 1] = inst.AnimationPlayed:Connect(function() if isCulled(plr) then charChanges["Animator.AnimationPlayed"] = (charChanges["Animator.AnimationPlayed"] or 0) + 1 end end)
        end
    end
    hookInst(ch)
    for _, d in ipairs(ch:GetDescendants()) do hookInst(d) end
    conns[#conns + 1] = ch.DescendantAdded:Connect(function(d)
        hookInst(d)
        if isCulled(plr) then charChanges["(child added) " .. d.ClassName] = (charChanges["(child added) " .. d.ClassName] or 0) + 1 end
    end)
    -- player object attributes too
end
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= lp then
        conns[#conns + 1] = plr.AttributeChanged:Connect(function(a)
            if isCulled(plr) then local k = "Player.@" .. a; charChanges[k] = (charChanges[k] or 0) + 1 end
        end)
    end
end

-- ---------------------------------------------------------------- D. position-type values / attributes anywhere
local valueHits = {}         -- path -> count while someone hidden (Vector3/CFrame values that change)
local function watchValues(root)
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("Vector3Value") or d:IsA("CFrameValue") then
            conns[#conns + 1] = d.Changed:Connect(function()
                if next(hiddenNow()) then valueHits[d:GetFullName()] = (valueHits[d:GetFullName()] or 0) + 1 end
            end)
        end
    end
end
pcall(watchValues, RS); pcall(watchValues, game:GetService("Workspace")); pcall(watchValues, Players)

-- ---------------------------------------------------------------- run
p("running ~120 s - play normally; the memory scan starts once 2+ other players are visible (short freeze)")
sweepRemotes()
local remoteCount = 0
for _ in pairs(remoteStats) do remoteCount += 1 end
p("B: watching " .. remoteCount .. " remotes outside ReplicatedStorage (incl. nil-parented)")

local wasCulled, culledAt = {}, {}
local hb = RunService.Heartbeat:Connect(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and plr.Character then
            hookChar(plr)
            local c = isCulled(plr)
            if c and not wasCulled[plr] then culledAt[plr] = os.clock() end
            if wasCulled[plr] and not c and scanned then
                local since, back = culledAt[plr] or 0, os.clock()
                if back - since > 1.5 then
                    task.delay(0.15, function()
                        local hrp = rootOf(plr)
                        if not hrp then return end
                        cmpBack += 1
                        for _, cd in ipairs(cands) do
                            if cd.plr == plr and cd.movedHidden > 0 and (cd.last - hrp.Position).Magnitude < 8 then
                                local k = cd.kind .. " ." .. cd.keyName
                                cmpHits[k] = (cmpHits[k] or 0) + 1
                            end
                        end
                    end)
                end
            end
            wasCulled[plr] = c
        end
    end
end)
conns[#conns + 1] = hb

local tStart = os.clock()
local lastTrack = 0
while os.clock() - tStart < 120 do
    task.wait(0.25)
    if not scanned then scanned = scanMemory() ~= false end
    if scanned and os.clock() - lastTrack > 0.25 then lastTrack = os.clock(); trackMemory() end
    if math.floor(os.clock() - tStart) % 20 == 0 then
        print(string.format("[BXP10] %ds... memory candidates %d, comebacks checked %d", math.floor(os.clock() - tStart), #cands, cmpBack))
        task.wait(1)
    end
end
for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end

-- ---------------------------------------------------------------- report
local live = {}
for _, c in ipairs(cands) do
    if c.movedHidden > 0 then live[#live + 1] = c end
end
table.sort(live, function(a, b) return a.movedHidden > b.movedHidden end)
p(string.format("A: %d memory fields tracked; %d of them KEPT MOVING while their player was hidden", #cands, #live))
for i = 1, math.min(15, #live) do
    local c = live[i]
    p(string.format("  A live: %s key=%s player=%s moved hidden x%d (of %d hidden ticks), visible x%d", c.kind, c.keyName, c.plr.Name,
        c.movedHidden, c.hiddenTicks, c.movedVisible))
end
local still = {}
for _, c in ipairs(cands) do if c.movedVisible > 3 and c.movedHidden == 0 and c.hiddenTicks > 4 then still[#still + 1] = c.kind .. "." .. c.keyName end end
p("A: fields that move while visible but FREEZE while hidden: " .. #still .. (#still > 0 and (" e.g. " .. table.concat(still, ", ", 1, math.min(6, #still))) or ""))
local ch = {}
for k, n in pairs(cmpHits) do ch[#ch + 1] = k .. " x" .. n end
p(string.format("A: hidden players came back %d times; live memory field already near the comeback spot: %s", cmpBack, #ch > 0 and table.concat(ch, ", ") or "never"))

local rs = {}
for _, st in pairs(remoteStats) do if st.n > 0 then rs[#rs + 1] = string.format("%s x%d (while someone hidden x%d)", st.path, st.n, st.nHidden) end end
table.sort(rs)
p("B: remotes outside ReplicatedStorage that fired: " .. (#rs > 0 and table.concat(rs, " | ") or "none"))

local cc = {}
for k, n in pairs(charChanges) do cc[#cc + 1] = {k, n} end
table.sort(cc, function(a, b) return a[2] > b[2] end)
local ccs = {}
for i = 1, math.min(25, #cc) do ccs[#ccs + 1] = cc[i][1] .. " x" .. cc[i][2] end
p("C: changes on HIDDEN characters / players: " .. (#ccs > 0 and table.concat(ccs, " | ") or "none"))

local vh = {}
for k, n in pairs(valueHits) do vh[#vh + 1] = k .. " x" .. n end
p("D: Vector3/CFrame values changing while someone hidden: " .. (#vh > 0 and table.concat(vh, " | ", 1, math.min(15, #vh)) or "none"))

pcall(function() if makefolder and not isfolder("king_hub") then makefolder("king_hub") end end)
pcall(writefile, "king_hub/blox_probe10.txt", table.concat(out, "\n") .. "\n")
p("done")
local copy = setclipboard or toclipboard or (syn and syn.write_clipboard)
if copy then pcall(copy, table.concat(out, "\n")); print("[BXP10] copied to clipboard - just paste it") end
