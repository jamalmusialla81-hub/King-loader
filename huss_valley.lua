-- =============================================================================
--  HUSS VALLEY  ·  role ESP + catcher warning
--  Display only: everything is drawn on your own screen, nothing is sent to the server.
--  The game keeps each player's role and state as attributes on the Player:
--    GameRole = Runner / Catcher / Lobby, RunState = Safe / Active, InMatch, TackleReadyAt (server epoch)
--  Movement is custom and server-checked (MovementGuardEvent / ValleyFairPlay), so nothing here touches movement.
--  K (or RightShift) hides / shows the panel.
-- =============================================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui          = game:GetService("CoreGui")
local Workspace        = game:GetService("Workspace")
local LocalPlayer      = Players.LocalPlayer

-- one KING script at a time
do
    local g = getgenv and getgenv() or _G
    g.KING_UNLOADERS = g.KING_UNLOADERS or {}
    for k, fn in pairs(g.KING_UNLOADERS) do pcall(fn); g.KING_UNLOADERS[k] = nil end
end

-- ---------------------------------------------------------------- log
pcall(function() if makefolder and not (isfolder and isfolder("king_hub")) then makefolder("king_hub") end end)
local LOGFILE = "king_hub/huss_log.txt"
local logBuf, t0, alive = {}, os.clock(), true
local function log(msg) logBuf[#logBuf + 1] = string.format("[+%6.1fs] %s", os.clock() - t0, tostring(msg)) end
pcall(writefile, LOGFILE, "huss valley log\n")
task.spawn(function()
    while alive do
        task.wait(3)
        if #logBuf > 0 then
            local chunk = table.concat(logBuf, "\n") .. "\n"
            logBuf = {}
            pcall(function()
                if appendfile then appendfile(LOGFILE, chunk)
                else writefile(LOGFILE, (isfile(LOGFILE) and readfile(LOGFILE) or "") .. chunk) end
            end)
        end
    end
end)
log("started; placeId=" .. game.PlaceId)

local GuiParent = CoreGui
pcall(function() if gethui then GuiParent = gethui() end end)

local Cfg = {
    Esp = true, ShowRunners = true, ShowCatchers = true, Names = true, Distance = true, TackleTimer = true,
    Outline = true, Warning = true, WarnDist = 35, MaxDist = 600,
    AutoDodge = true, DodgeTime = 0.22, DodgeDist = 9, Juke = true, JukeTime = 0.45,
    AutoCatch = true, CatchRange = 7,
    AutoAbility = true, AbilityDist = 12,
}
local connections, cleanups = {}, {}
local function connect(sig, fn) local c = sig:Connect(fn); connections[#connections + 1] = c; return c end

local COLORS = {
    Catcher = Color3.fromRGB(255, 70, 70),
    Runner = Color3.fromRGB(80, 230, 120),
    Other = Color3.fromRGB(180, 180, 180),
}
local function serverNow()
    local ok, t = pcall(function() return Workspace:GetServerTimeNow() end)
    return ok and t or os.time()
end
local function roleOf(plr) return plr:GetAttribute("GameRole") or "?" end
local function inMatch(plr) return plr:GetAttribute("InMatch") == true end
local function rootOf(plr)
    local ch = plr.Character
    return ch and ch:FindFirstChild("HumanoidRootPart"), ch
end
local function myRoot() return (rootOf(LocalPlayer)) end

-- ---------------------------------------------------------------- ESP
local espFolder = Instance.new("Folder")
espFolder.Name = "king_huss_esp"
espFolder.Parent = GuiParent
local esp = {}            -- player -> {bb, label, hl}

local function makeEsp(plr)
    local bb = Instance.new("BillboardGui")
    bb.Name = plr.Name
    bb.AlwaysOnTop = true
    bb.Size = UDim2.fromOffset(160, 40)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.LightInfluence = 0
    bb.Parent = espFolder
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextStrokeTransparency = 0.3
    label.Parent = bb
    local hl = Instance.new("Highlight")
    hl.Name = "king_huss_hl"
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillTransparency = 0.75
    hl.OutlineTransparency = 0
    hl.Parent = espFolder
    local e = {bb = bb, label = label, hl = hl}
    esp[plr] = e
    return e
end
local function dropEsp(plr)
    local e = esp[plr]
    if e then pcall(function() e.bb:Destroy(); e.hl:Destroy() end); esp[plr] = nil end
end
connect(Players.PlayerRemoving, dropEsp)

-- ---------------------------------------------------------------- warning HUD
local hud = Instance.new("ScreenGui")
hud.Name = "king_huss_hud"
hud.ResetOnSpawn = false
hud.IgnoreGuiInset = true
hud.Parent = GuiParent
local warnLabel = Instance.new("TextLabel")
warnLabel.AnchorPoint = Vector2.new(0.5, 0)
warnLabel.Position = UDim2.new(0.5, 0, 0, 70)
warnLabel.Size = UDim2.fromOffset(420, 30)
warnLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
warnLabel.BackgroundTransparency = 0.25
warnLabel.Font = Enum.Font.GothamBold
warnLabel.TextSize = 16
warnLabel.TextColor3 = Color3.new(1, 1, 1)
warnLabel.Visible = false
warnLabel.Parent = hud
Instance.new("UICorner", warnLabel).CornerRadius = UDim.new(0, 8)

-- arrow pointing at the nearest catcher when it is off screen
local arrow = Instance.new("TextLabel")
arrow.AnchorPoint = Vector2.new(0.5, 0.5)
arrow.Size = UDim2.fromOffset(40, 40)
arrow.BackgroundTransparency = 1
arrow.Text = "▲"
arrow.TextSize = 34
arrow.Font = Enum.Font.GothamBold
arrow.TextColor3 = COLORS.Catcher
arrow.TextStrokeTransparency = 0.2
arrow.Visible = false
arrow.Parent = hud

local lastDist = {}
local lastLog = 0
connect(RunService.RenderStepped, function(dt)
    local cam = Workspace.CurrentCamera
    local me = myRoot()
    local now = serverNow()
    local nearest, nearestD, nearestPlr, closing
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local hrp, ch = rootOf(plr)
            local role = roleOf(plr)
            local show = Cfg.Esp and hrp and ch and inMatch(plr)
                and ((role == "Catcher" and Cfg.ShowCatchers) or (role == "Runner" and Cfg.ShowRunners))
            local d = (hrp and me) and (hrp.Position - me.Position).Magnitude or math.huge
            if show and d > Cfg.MaxDist then show = false end
            local e = esp[plr]
            if show then
                e = e or makeEsp(plr)
                local col = COLORS[role] or COLORS.Other
                e.bb.Adornee = ch:FindFirstChild("Head") or hrp
                e.bb.Enabled = true
                local parts = {}
                if Cfg.Names then parts[#parts + 1] = plr.DisplayName end
                parts[#parts + 1] = role:upper()
                local line2 = {}
                if Cfg.Distance and d < math.huge then line2[#line2 + 1] = string.format("%dm", math.floor(d)) end
                if Cfg.TackleTimer and role == "Catcher" then
                    local ready = tonumber(plr:GetAttribute("TackleReadyAt")) or 0
                    line2[#line2 + 1] = ready > now and string.format("tackle %.1fs", ready - now) or "TACKLE READY"
                end
                if plr:GetAttribute("RunState") == "Safe" then line2[#line2 + 1] = "safe" end
                e.label.Text = table.concat(parts, " · ") .. (#line2 > 0 and ("\n" .. table.concat(line2, " · ")) or "")
                e.label.TextColor3 = col
                e.hl.Adornee = Cfg.Outline and ch or nil
                e.hl.Enabled = Cfg.Outline
                e.hl.FillColor = col
                e.hl.OutlineColor = col
            elseif e then
                e.bb.Enabled = false
                e.hl.Enabled = false
            end
            -- nearest catcher (only matters while you're a runner in the match)
            if role == "Catcher" and hrp and me and inMatch(plr) then
                if not nearestD or d < nearestD then
                    nearestD, nearest, nearestPlr = d, hrp, plr
                    local prev = lastDist[plr]
                    closing = prev and (prev - d) / math.max(dt, 1e-3) or 0
                end
                lastDist[plr] = d
            end
        end
    end

    -- warning
    local amRunner = roleOf(LocalPlayer) == "Runner" and inMatch(LocalPlayer)
    if Cfg.Warning and amRunner and nearest and cam then
        local danger = nearestD < Cfg.WarnDist
        local ready = (tonumber(nearestPlr:GetAttribute("TackleReadyAt")) or 0) <= now
        warnLabel.Visible = true
        warnLabel.Text = string.format("%s %s  %dm%s%s", danger and "⚠" or "Catcher", nearestPlr.DisplayName, math.floor(nearestD),
            closing and closing > 2 and string.format("  closing %d/s", math.floor(closing)) or "",
            ready and "  · tackle ready" or "")
        warnLabel.TextColor3 = danger and COLORS.Catcher or Color3.new(1, 1, 1)
        -- off-screen arrow
        local sp, on = cam:WorldToViewportPoint(nearest.Position)
        if (not on or sp.Z <= 0) and nearestD < Cfg.WarnDist * 2.5 then
            local c = cam.ViewportSize / 2
            local rel = cam.CFrame:PointToObjectSpace(nearest.Position)
            local dir = Vector2.new(rel.X, -rel.Y)
            if rel.Z > 0 then dir = Vector2.new(rel.X, rel.Y) end
            if dir.Magnitude < 1e-3 then dir = Vector2.new(0, 1) end
            dir = dir.Unit
            local r = math.min(c.X, c.Y) * 0.7
            arrow.Position = UDim2.fromOffset(c.X + dir.X * r, c.Y + dir.Y * r)
            arrow.Rotation = math.deg(math.atan2(dir.Y, dir.X)) + 90
            arrow.Visible = true
        else
            arrow.Visible = false
        end
    else
        warnLabel.Visible = false
        arrow.Visible = false
    end

    if os.clock() - lastLog > 5 then
        lastLog = os.clock()
        local counts = {Runner = 0, Catcher = 0, Lobby = 0}
        for _, plr in ipairs(Players:GetPlayers()) do
            local r = roleOf(plr)
            counts[r] = (counts[r] or 0) + 1
        end
        log(string.format("me: role=%s run=%s inMatch=%s | runners=%d catchers=%d lobby=%d | nearest catcher=%s %s",
            tostring(roleOf(LocalPlayer)), tostring(LocalPlayer:GetAttribute("RunState")), tostring(inMatch(LocalPlayer)),
            counts.Runner or 0, counts.Catcher or 0, counts.Lobby or 0,
            nearestPlr and nearestPlr.Name or "none", nearestD and string.format("%.0fm", nearestD) or ""))
    end
end)

-- ---------------------------------------------------------------- auto dodge
-- When a catcher whose tackle is ready will reach you within DodgeTime (or is already inside DodgeDist and
-- closing), you dash sideways out of their path using the game's own dash, by pressing the real keys:
-- the movement keys for the dodge direction + the dash key. The dash key is learned: dash once yourself and the
-- key you pressed just before DashCount went up is remembered (saved to king_hub/huss_dashkey.txt).
local VIM = game:GetService("VirtualInputManager")
local DASHKEY_FILE = "king_hub/huss_dashkey.txt"
local dashKey
pcall(function()
    if isfile and isfile(DASHKEY_FILE) then
        local name = readfile(DASHKEY_FILE):gsub("%s", "")
        if name:sub(1, 6) == "Mouse:" then dashKey = Enum.UserInputType[name:sub(7)]
        else dashKey = Enum.KeyCode[name] end
    end
end)
dashKey = dashKey or Enum.KeyCode.Space          -- Space dashes by default; a different key you dash with is learned
log("auto dodge: dash key = " .. dashKey.Name)
local MOVE_KEYS = {[Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true, [Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true}
local recentPress = {}           -- {input enum, t}
local dodging = false
connect(UserInputService.InputBegan, function(i, gp)
    if dodging then return end
    local k = (i.UserInputType == Enum.UserInputType.Keyboard) and i.KeyCode or i.UserInputType
    if k == Enum.UserInputType.MouseMovement or MOVE_KEYS[k] then return end
    table.insert(recentPress, {k = k, t = os.clock()})
    if #recentPress > 8 then table.remove(recentPress, 1) end
end)
local function watchDash(ch)
    if not ch then return end
    connect(ch:GetAttributeChangedSignal("DashCount"), function()
        if dodging then return end
        -- the dash you just did yourself: which key was pressed right before it?
        local now = os.clock()
        for i = #recentPress, 1, -1 do
            local r = recentPress[i]
            if now - r.t < 0.35 then
                if dashKey ~= r.k then
                    dashKey = r.k
                    local save = (r.k.EnumType == Enum.KeyCode) and r.k.Name or ("Mouse:" .. r.k.Name)
                    pcall(writefile, DASHKEY_FILE, save)
                    log("auto dodge: learned dash key = " .. r.k.Name)
                end
                return
            end
        end
    end)
end
watchDash(LocalPlayer.Character)
connect(LocalPlayer.CharacterAdded, watchDash)

local function press(k, down)
    if k.EnumType == Enum.KeyCode then
        VIM:SendKeyEvent(down, k, false, game)
    else
        local m = UserInputService:GetMouseLocation()
        local btn = (k == Enum.UserInputType.MouseButton2) and 1 or 0
        VIM:SendMouseButtonEvent(m.X, m.Y, btn, down, game, 0)
    end
end
local lastDodge, dodges = 0, 0
local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Exclude
local function clearance(from, dir, dist)
    local ignore = {}
    for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then ignore[#ignore + 1] = pl.Character end end
    wallParams.FilterDescendantsInstances = ignore
    local r = Workspace:Raycast(from, dir * dist, wallParams)
    return r and (r.Position - from).Magnitude or dist
end
-- world direction -> camera-relative WASD keys
local function keysFor(cam, dir)
    local f = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z).Unit
    local r = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z).Unit
    local fd, rd = dir:Dot(f), dir:Dot(r)
    local keys = {}
    if fd > 0.35 then keys[#keys + 1] = Enum.KeyCode.W elseif fd < -0.35 then keys[#keys + 1] = Enum.KeyCode.S end
    if rd > 0.35 then keys[#keys + 1] = Enum.KeyCode.D elseif rd < -0.35 then keys[#keys + 1] = Enum.KeyCode.A end
    return keys
end
local ourKeys = {}               -- keys we are holding down (not you)
local function holdKeys(keys)
    local want = {}
    for _, k in ipairs(keys) do want[k] = true end
    for k in pairs(ourKeys) do if not want[k] then pcall(press, k, false); ourKeys[k] = nil end end
    for k in pairs(want) do
        if not ourKeys[k] and not UserInputService:IsKeyDown(k) then pcall(press, k, true); ourKeys[k] = true end
    end
end
cleanups[#cleanups + 1] = function() holdKeys({}) end
local function keyNames(keys) local n = {} for _, k in ipairs(keys) do n[#n + 1] = k.Name end return table.concat(n, "") end

local function dodge(cam, me, cat, catVel, d, tti, why)
    if not dashKey then return end
    dodging = true
    lastDodge = os.clock()
    local toMe = Vector3.new(me.Position.X - cat.Position.X, 0, me.Position.Z - cat.Position.Z)
    local path = Vector3.new(catVel.X, 0, catVel.Z)
    if path.Magnitude < 1 then path = -toMe end
    path = path.Unit
    -- both sideways options; prefer the side you're already on, but never into a wall
    local sideA = Vector3.new(-path.Z, 0, path.X)
    local sideB = -sideA
    if sideA:Dot(toMe) < 0 then sideA, sideB = sideB, sideA end
    local from = me.Position
    local clearA, clearB = clearance(from, sideA, 10), clearance(from, sideB, 10)
    local side = sideA
    if clearA < 5 and clearB > clearA then side = sideB end
    local dashDir = (side * 0.9 + path * 0.15).Unit                -- slightly with their run: they can't turn into it
    local dashKeys = keysFor(cam, dashDir)
    holdKeys(dashKeys)
    task.wait(0.03)
    pcall(press, dashKey, true)
    task.wait(0.05)
    pcall(press, dashKey, false)
    dodges += 1
    local line = string.format("auto dodge #%d (%s): catcher %.1f studs, contact in %.2fs, side clear %.0f/%.0f studs, dash %s+%s",
        dodges, why, d, tti, clearA, clearB, keyNames(dashKeys), dashKey.Name)
    if Cfg.Juke then
        -- cut back behind them: they're still carrying their speed the other way
        task.wait(0.18)
        local back = (-path * 0.8 + side * 0.35).Unit
        if clearance(from, back, 8) < 3 then back = side end
        local jukeKeys = keysFor(cam, back)
        holdKeys(jukeKeys)
        line ..= ", juke " .. keyNames(jukeKeys)
        task.wait(Cfg.JukeTime)
    else
        task.wait(0.25)
    end
    log(line)
    holdKeys({})
    dodging = false
    if Cfg.AutoAbility and shared.KING_HussPop then task.spawn(shared.KING_HussPop, "combo after dodge") end
end

local prevPos = {}
local lastNoKeyLog = 0
local lunge = {}                 -- catcher -> os.clock() of their last dash / tackle start
local function watchCatcher(plr)
    local function hook(ch)
        if not ch then return end
        for _, a in ipairs({"DashCount", "LastDashDistance"}) do
            connect(ch:GetAttributeChangedSignal(a), function() lunge[plr] = os.clock() end)
        end
        connect(ch:GetAttributeChangedSignal("MovementState"), function()
            local st = tostring(ch:GetAttribute("MovementState"))
            if st:find("Dash") or st:find("Tackle") or st:find("Lunge") or st:find("Dive") then lunge[plr] = os.clock() end
        end)
    end
    hook(plr.Character)
    connect(plr.CharacterAdded, hook)
    -- the tackle cooldown starting means they just swung
    connect(plr:GetAttributeChangedSignal("TackleReadyAt"), function() lunge[plr] = os.clock() end)
end
for _, plr in ipairs(Players:GetPlayers()) do if plr ~= LocalPlayer then watchCatcher(plr) end end
connect(Players.PlayerAdded, watchCatcher)
connect(RunService.Heartbeat, function(dt)
    if not Cfg.AutoDodge or dodging or os.clock() - lastDodge < 0.6 then return end
    if roleOf(LocalPlayer) ~= "Runner" or not inMatch(LocalPlayer) then return end
    local ch = LocalPlayer.Character
    local me = ch and ch:FindFirstChild("HumanoidRootPart")
    local cam = Workspace.CurrentCamera
    if not (me and cam) or ch:GetAttribute("DashReady") == false then return end
    local now = serverNow()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and roleOf(plr) == "Catcher" and inMatch(plr) then
            local cat = rootOf(plr)
            if cat then
                local pp = prevPos[plr]
                prevPos[plr] = cat.Position
                local vel = pp and (cat.Position - pp) / math.max(dt, 1e-3) or Vector3.zero
                local rel = Vector3.new(me.Position.X - cat.Position.X, 0, me.Position.Z - cat.Position.Z)
                local d = rel.Magnitude
                local closing = d > 0 and vel:Dot(rel.Unit) or 0
                local tti = closing > 1 and d / closing or math.huge
                local ready = (tonumber(plr:GetAttribute("TackleReadyAt")) or 0) <= now
                local committed = lunge[plr] and os.clock() - lunge[plr] < 0.25 and d < 18 and closing > 2
                local late = ready and (tti < Cfg.DodgeTime or (d < Cfg.DodgeDist and closing > 4))
                if d < 40 and (committed or late) then
                    if dashKey then
                        task.spawn(dodge, cam, me, cat, vel, d, tti, committed and "they lunged" or "last moment")
                        return
                    elseif os.clock() - lastNoKeyLog > 5 then
                        lastNoKeyLog = os.clock()
                        log("auto dodge: catcher close but dash key not learned yet - dash once yourself")
                    end
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------- auto catch
-- You're the catcher, your tackle is ready (TackleReadyAt has passed) and a runner who isn't safe is within
-- CatchRange (or will be in ~0.15 s): the camera turns onto them for a few frames and the tackle input is pressed.
-- The tackle input is learned like the dash key: the input you pressed right before your TackleReadyAt moved.
-- Default left click. Catches (leaderstats) is checked afterwards so the log shows hits and misses.
local TACKLE_FILE = "king_hub/huss_tacklekey.txt"
local tackleKey
pcall(function()
    if isfile and isfile(TACKLE_FILE) then
        local name = readfile(TACKLE_FILE):gsub("%s", "")
        if name:sub(1, 6) == "Mouse:" then tackleKey = Enum.UserInputType[name:sub(7)] else tackleKey = Enum.KeyCode[name] end
    end
end)
tackleKey = tackleKey or Enum.UserInputType.MouseButton1
log("auto catch: tackle input = " .. tackleKey.Name)
local catching = false
connect(LocalPlayer:GetAttributeChangedSignal("TackleReadyAt"), function()
    if catching then return end
    local now = os.clock()
    for i = #recentPress, 1, -1 do
        local r = recentPress[i]
        if now - r.t < 0.4 then
            if r.k ~= tackleKey and r.k ~= dashKey then
                tackleKey = r.k
                pcall(writefile, TACKLE_FILE, (r.k.EnumType == Enum.KeyCode) and r.k.Name or ("Mouse:" .. r.k.Name))
                log("auto catch: learned tackle input = " .. r.k.Name)
            end
            return
        end
    end
end)
local function catchesNow()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    local c = ls and ls:FindFirstChild("Catches")
    return c and tonumber(c.Value) or 0
end
local aimAt                       -- Vector3 the camera is turned to while a catch is in progress
RunService:BindToRenderStep("king_huss_catchaim", Enum.RenderPriority.Camera.Value + 2, function()
    if not aimAt then return end
    local cam = Workspace.CurrentCamera
    if cam then cam.CFrame = CFrame.lookAt(cam.CFrame.Position, aimAt) end
end)
cleanups[#cleanups + 1] = function() pcall(function() RunService:UnbindFromRenderStep("king_huss_catchaim") end) end
local catches, lastCatch = 0, 0
local catchPrev = {}
local function tryCatch(target, hrp, d, how)
    catching = true
    lastCatch = os.clock()
    local before = catchesNow()
    local tStart = os.clock()
    -- turn onto them for a few frames, then tackle while still facing them
    while os.clock() - tStart < 0.08 do
        aimAt = hrp.Position + Vector3.new(0, 0.5, 0)
        RunService.RenderStepped:Wait()
    end
    pcall(press, tackleKey, true)
    task.wait(0.04)
    pcall(press, tackleKey, false)
    local t2 = os.clock()
    while os.clock() - t2 < 0.12 do
        if hrp.Parent then aimAt = hrp.Position + Vector3.new(0, 0.5, 0) end
        RunService.RenderStepped:Wait()
    end
    aimAt = nil
    catches += 1
    task.delay(1.2, function()
        local got = catchesNow() > before
        log(string.format("auto catch #%d (%s): %s at %.1f studs -> %s", catches, how, target.Name, d, got and "CAUGHT" or "missed"))
        catching = false
    end)
end
connect(RunService.Heartbeat, function(dt)
    if not Cfg.AutoCatch or catching or os.clock() - lastCatch < 0.5 then return end
    if roleOf(LocalPlayer) ~= "Catcher" or not inMatch(LocalPlayer) then return end
    if (tonumber(LocalPlayer:GetAttribute("TackleReadyAt")) or 0) > serverNow() then return end
    local me = myRoot()
    if not me then return end
    local best, bestHrp, bestD, how
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and roleOf(plr) == "Runner" and inMatch(plr) and plr:GetAttribute("RunState") ~= "Safe" then
            local hrp = rootOf(plr)
            if hrp then
                local pp = catchPrev[plr]
                catchPrev[plr] = hrp.Position
                local vel = pp and (hrp.Position - pp) / math.max(dt, 1e-3) or Vector3.zero
                local d = (hrp.Position - me.Position).Magnitude
                local soon = (hrp.Position + vel * 0.15 - me.Position).Magnitude
                local eff = math.min(d, soon)
                if eff <= Cfg.CatchRange and (not bestD or eff < bestD) then
                    best, bestHrp, bestD, how = plr, hrp, eff, (soon < d) and "coming in" or "in range"
                end
            end
        end
    end
    if best then task.spawn(tryCatch, best, bestHrp, bestD, how) end
end)

-- ---------------------------------------------------------------- auto ability
-- Your knife's ability (ghost, clone, ...) as an escape: fired when a catcher with a ready tackle is within
-- AbilityDist and your dash can't save you (not ready), or right after an auto dodge as a combo.
-- Ability key: read from the game's own ability button text, else learned from your own use (the input you pressed
-- right before an *AbilityReadyAt went up), else E. Saved to king_hub/huss_abilitykey.txt.
local ABILITY_FILE = "king_hub/huss_abilitykey.txt"
local ABILITY_ATTRS = {"AbilityReadyAt", "GhostAbilityReadyAt", "CloneAbilityReadyAt"}
local abilityKey
pcall(function()
    if isfile and isfile(ABILITY_FILE) then
        local name = readfile(ABILITY_FILE):gsub("%s", "")
        if name:sub(1, 6) == "Mouse:" then abilityKey = Enum.UserInputType[name:sub(7)] else abilityKey = Enum.KeyCode[name] end
    end
end)
if not abilityKey then
    -- the ability button usually shows its key (a single letter)
    pcall(function()
        for _, gname in ipairs({"AbilityControls", "KnifeAbilityHUD", "GhostAbilityHUD"}) do
            local g = LocalPlayer.PlayerGui:FindFirstChild(gname)
            if g then
                for _, d in ipairs(g:GetDescendants()) do
                    if d:IsA("TextLabel") or d:IsA("TextButton") then
                        local t = (d.Text or ""):gsub("%s", ""):upper()
                        if #t == 1 and Enum.KeyCode[t] and not MOVE_KEYS[Enum.KeyCode[t]] then
                            abilityKey = Enum.KeyCode[t]
                            log("auto ability: key read from " .. d:GetFullName())
                            return
                        end
                    end
                end
            end
        end
    end)
end
abilityKey = abilityKey or Enum.KeyCode.E
log("auto ability: key = " .. abilityKey.Name)
local popping = false
for _, a in ipairs(ABILITY_ATTRS) do
    connect(LocalPlayer:GetAttributeChangedSignal(a), function()
        if popping then return end
        local v = tonumber(LocalPlayer:GetAttribute(a)) or 0
        if v <= serverNow() then return end            -- only when a cooldown starts
        local now = os.clock()
        for i = #recentPress, 1, -1 do
            local r = recentPress[i]
            if now - r.t < 0.4 then
                if r.k ~= abilityKey and r.k ~= dashKey and r.k ~= tackleKey then
                    abilityKey = r.k
                    pcall(writefile, ABILITY_FILE, (r.k.EnumType == Enum.KeyCode) and r.k.Name or ("Mouse:" .. r.k.Name))
                    log("auto ability: learned key = " .. r.k.Name .. " (from " .. a .. ")")
                end
                return
            end
        end
    end)
end
local function abilityReady()
    local now = serverNow()
    local any = false
    for _, a in ipairs(ABILITY_ATTRS) do
        local v = LocalPlayer:GetAttribute(a)
        if v ~= nil then
            any = true
            if (tonumber(v) or 0) > now then return false end
        end
    end
    return any
end
local pops, lastPop = 0, 0
local function pop(why)
    if popping or os.clock() - lastPop < 1 or not abilityReady() then return end
    popping = true
    lastPop = os.clock()
    pcall(press, abilityKey, true)
    task.wait(0.05)
    pcall(press, abilityKey, false)
    pops += 1
    task.delay(0.6, function()
        local used = not abilityReady()
        log(string.format("auto ability #%d (%s): pressed %s -> %s", pops, why, abilityKey.Name, used and "ability used" or "nothing happened (wrong key or no ability?)"))
        popping = false
    end)
end
shared.KING_HussPop = pop
connect(RunService.Heartbeat, function()
    if not Cfg.AutoAbility or popping or os.clock() - lastPop < 1 then return end
    if roleOf(LocalPlayer) ~= "Runner" or not inMatch(LocalPlayer) or not abilityReady() then return end
    local ch = LocalPlayer.Character
    local me = ch and ch:FindFirstChild("HumanoidRootPart")
    if not me then return end
    local dashUp = ch:GetAttribute("DashReady") ~= false and Cfg.AutoDodge
    if dashUp then return end                              -- the dodge handles it; the combo is fired from there
    local now = serverNow()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and roleOf(plr) == "Catcher" and inMatch(plr) then
            local cat = rootOf(plr)
            if cat and (cat.Position - me.Position).Magnitude < Cfg.AbilityDist and (tonumber(plr:GetAttribute("TackleReadyAt")) or 0) <= now then
                task.spawn(pop, "catcher close, no dash")
                return
            end
        end
    end
end)

-- ---------------------------------------------------------------- panel
local gui = Instance.new("ScreenGui")
gui.Name = "king_huss_menu"
gui.ResetOnSpawn = false
gui.Parent = GuiParent
local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(250, 0)
main.AutomaticSize = Enum.AutomaticSize.Y
main.Position = UDim2.new(0, 20, 0.3, 0)
main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
main.BackgroundTransparency = 0.05
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
local pad = Instance.new("UIPadding", main)
pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10), UDim.new(0, 10), UDim.new(0, 10)
local list = Instance.new("UIListLayout", main)
list.Padding = UDim.new(0, 6)
list.SortOrder = Enum.SortOrder.LayoutOrder
local order = 0
local function row(text)
    order += 1
    local t = Instance.new("TextLabel")
    t.LayoutOrder = order
    t.Size = UDim2.new(1, 0, 0, 22)
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamBold
    t.TextSize = 15
    t.TextColor3 = Color3.fromRGB(255, 200, 60)
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Text = text
    t.Parent = main
end
local function toggle(label, key)
    order += 1
    local b = Instance.new("TextButton")
    b.LayoutOrder = order
    b.Size = UDim2.new(1, 0, 0, 26)
    b.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
    b.Font = Enum.Font.Gotham
    b.TextSize = 13
    b.TextColor3 = Color3.new(1, 1, 1)
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.AutoButtonColor = true
    b.Parent = main
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    Instance.new("UIPadding", b).PaddingLeft = UDim.new(0, 8)
    local function render() b.Text = (Cfg[key] and "● " or "○ ") .. label; b.TextColor3 = Cfg[key] and Color3.fromRGB(120, 255, 160) or Color3.fromRGB(200, 200, 200) end
    b.MouseButton1Click:Connect(function() Cfg[key] = not Cfg[key]; render() end)
    render()
end
row("KING HUB · Huss Valley")
toggle("ESP", "Esp")
toggle("Show catchers", "ShowCatchers")
toggle("Show runners", "ShowRunners")
toggle("Outline through walls", "Outline")
toggle("Names", "Names")
toggle("Distance", "Distance")
toggle("Catcher tackle timer", "TackleTimer")
toggle("Catcher warning + arrow", "Warning")
toggle("Auto dodge (dash once to teach the key)", "AutoDodge")
toggle("Auto catch (when you're the catcher)", "AutoCatch")
toggle("Auto ability (escape / after dodge)", "AutoAbility")
order += 1
local hint = Instance.new("TextLabel")
hint.LayoutOrder = order
hint.Size = UDim2.new(1, 0, 0, 16)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextSize = 11
hint.TextColor3 = Color3.fromRGB(150, 150, 160)
hint.Text = "K / RightShift: hide · display only"
hint.Parent = main

-- drag
do
    local dragging, startPos, startMouse
    connect(main.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging, startPos, startMouse = true, main.Position, i.Position end
    end)
    connect(UserInputService.InputChanged, function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - startMouse
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    connect(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
end
connect(UserInputService.InputBegan, function(i, gp)
    if not gp and (i.KeyCode == Enum.KeyCode.K or i.KeyCode == Enum.KeyCode.RightShift) then main.Visible = not main.Visible end
end)

-- ---------------------------------------------------------------- unload
local function unload()
    alive = false
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    for _, fn in ipairs(cleanups) do pcall(fn) end
    for plr in pairs(esp) do dropEsp(plr) end
    for _, g in ipairs({espFolder, hud, gui}) do pcall(function() g:Destroy() end) end
end
do
    local g = getgenv and getgenv() or _G
    g.KING_UNLOADERS = g.KING_UNLOADERS or {}
    g.KING_UNLOADERS.huss = unload
end
log("loaded")
print("[KING HUB] Huss Valley loaded.")
