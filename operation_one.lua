-- =============================================================================
--  OPERATION ONE  ·  box ESP, names, health bars, enemy highlight, gun chams
--  Display only: everything is drawn on your own screen. Nothing is sent to the server.
--  Structure (workspace.Viewmodels, LocalViewmodel, parts head/torso/...) follows the layout seen in
--  the N0IR script. K (or RightShift) hides / shows the menu window.
-- =============================================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Workspace        = game:GetService("Workspace")
local CoreGui          = game:GetService("CoreGui")
local HttpService      = game:GetService("HttpService")
local LocalPlayer      = Players.LocalPlayer

if getgenv and getgenv().OP1_RUNNING then
    pcall(getgenv().OP1_RUNNING)          -- unload a previous copy first
end

-- only one KING script runs at a time: loading this one unloads any other that is active
do
    local g = getgenv and getgenv() or _G
    g.KING_UNLOADERS = g.KING_UNLOADERS or {}
    for k, fn in pairs(g.KING_UNLOADERS) do
        if k ~= "op1" then pcall(fn) end
        g.KING_UNLOADERS[k] = nil
    end
end

-- ---------------------------------------------------------------- log
pcall(function() if makefolder and not (isfolder and isfolder("king_hub")) then makefolder("king_hub") end end)
local LOGFILE = "king_hub/op1_log.txt"
local logBuf, t0 = {}, os.clock()
local function log(msg) logBuf[#logBuf + 1] = string.format("[+%6.1fs] %s", os.clock() - t0, tostring(msg)) end
pcall(function() writefile(LOGFILE, "operation one log\n") end)
local logAlive = true
task.spawn(function()
    while logAlive do
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
log("started; placeId=" .. tostring(game.PlaceId))

-- ---------------------------------------------------------------- kill other scripts
-- Other hubs / ESPs you ran before this one: their drawings are cleared, their menus destroyed and their event
-- hooks (render loops, input, player events) disconnected. Only functions created by the executor are touched,
-- never the game's own. Runs before this script hooks anything, so it can't hit itself.
do
    local isExec = isexecutorclosure or checkclosure or isourclosure or is_synapse_function
    local killedConns, killedGuis = 0, 0
    pcall(function() if cleardrawcache then cleardrawcache() end end)
    local function foreign(fn) local ok, r = pcall(isExec, fn) return ok and r end
    if getconnections and isExec then
        local Lighting = game:GetService("Lighting")
        local signals = {
            RunService.RenderStepped, RunService.Heartbeat, RunService.Stepped,
            UserInputService.InputBegan, UserInputService.InputChanged, UserInputService.InputEnded,
            Players.PlayerAdded, Players.PlayerRemoving, Workspace.ChildAdded, Workspace.ChildRemoved,
            Workspace.DescendantAdded, Workspace.DescendantRemoving, Lighting.Changed,
        }
        pcall(function() signals[#signals + 1] = Workspace:GetPropertyChangedSignal("CurrentCamera") end)
        pcall(function() signals[#signals + 1] = LocalPlayer.CharacterAdded end)
        pcall(function() signals[#signals + 1] = Workspace.CurrentCamera:GetPropertyChangedSignal("CFrame") end)
        for _, sig in ipairs(signals) do
            local ok, conns = pcall(getconnections, sig)
            if ok and conns then
                for _, c in ipairs(conns) do
                    local fn = c.Function
                    if fn and foreign(fn) then
                        if pcall(function() c:Disconnect() end) or pcall(function() c:Disable() end) then killedConns += 1 end
                    end
                end
            end
        end
    end
    -- menus: any GUI (hidden GUI folder, CoreGui, PlayerGui) whose buttons run executor code
    local function executorGui(g)
        if not (getconnections and isExec) then return false end
        local checked = 0
        for _, d in ipairs(g:GetDescendants()) do
            if d:IsA("GuiButton") then
                for _, sig in ipairs({d.MouseButton1Click, d.MouseButton1Down, d.Activated}) do
                    local ok, conns = pcall(getconnections, sig)
                    if ok and conns then
                        for _, c in ipairs(conns) do if c.Function and foreign(c.Function) then return true end end
                    end
                end
                checked += 1
                if checked > 60 then return false end
            end
        end
        return false
    end
    local hui
    pcall(function() if gethui then hui = gethui() end end)
    if hui and hui ~= CoreGui then
        for _, g in ipairs(hui:GetChildren()) do
            -- only menus (clickable executor code): Lua-made Drawing libraries keep their canvas here too
            if executorGui(g) and pcall(function() g:Destroy() end) then killedGuis += 1 end
        end
    end
    for _, g in ipairs(CoreGui:GetChildren()) do
        if g ~= hui and g:IsA("ScreenGui") and executorGui(g) then
            if pcall(function() g:Destroy() end) then killedGuis += 1 end
        end
    end
    pcall(function()
        for _, g in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
            if g:IsA("ScreenGui") and executorGui(g) then
                if pcall(function() g:Destroy() end) then killedGuis += 1 end
            end
        end
    end)
    log(string.format("killed other scripts: %d hooks disconnected, %d menus removed (getconnections=%s, closure check=%s, cleardrawcache=%s)",
        killedConns, killedGuis, tostring(getconnections ~= nil), tostring(isExec ~= nil), tostring(cleardrawcache ~= nil)))
end

local GuiParent = CoreGui
pcall(function() if gethui then GuiParent = gethui() end end)

-- ---------------------------------------------------------------- settings
local CHAMS_COLORS = {
    {"Rainbow", nil}, {"Cyan", Color3.fromRGB(0, 230, 210)}, {"Red", Color3.fromRGB(255, 60, 60)},
    {"Gold", Color3.fromRGB(255, 200, 60)}, {"White", Color3.fromRGB(255, 255, 255)}, {"Pink", Color3.fromRGB(255, 90, 200)},
}
local BOX_COLORS = {
    {"Red", Color3.fromRGB(255, 60, 60)}, {"White", Color3.fromRGB(255, 255, 255)}, {"Cyan", Color3.fromRGB(0, 230, 210)},
    {"Gold", Color3.fromRGB(255, 200, 60)}, {"Pink", Color3.fromRGB(255, 90, 200)},
}
local Cfg = {
    Box = true, BoxColor = 1, Names = true, Distance = true, HealthBar = true,
    Highlight = false, TeamCheck = true, ShowDead = false, MaxDist = 900,
    Chams = true, ChamsColor = 2, ChamsTrans = 0.45, ChamsPulse = false,
    Trigger = true, TriggerDelay = 0.0, TriggerRange = 1000, TriggerWallCheck = true,
    NoRecoil = true, RecoilStrength = 100,
    GrenadeAssist = true, GrenadeLock = true, GrenadeMarkers = false,
    Barricades = true, ThinWalls = false, TriggerHeadOnly = false,
    Silent = true, SilentFov = 250, SilentRange = 100, SilentPart = 1, SilentVisible = true, TriggerOnLock = true,
    -- clean extras
    BoxMode = 1, Skeleton = false, VisTint = true,
    Aim = true, AimFov = 180, AimRange = 300, AimSmooth = 0.35, AimMaxStep = 40, AimHuman = 70, AimSticky = true, AimVisible = true, AimPart = 1,
    AimCircle = true, AimLine = true, Tracers = true, Peek = false, PeekTime = 0.3, PeekTap = 0.3, Fullbright = false, NoFog = false, Fov = false, FovValue = 90, Watermark = true,
}
local gaAim = {}                           -- grenade lock-on target, written by the grenade solver, read by the aimbot
local refreshers = {}
local CFG_FILE = "king_hub/op1_config.json"
pcall(function()
    if isfile and isfile(CFG_FILE) then
        local saved = HttpService:JSONDecode(readfile(CFG_FILE))
        for k, v in pairs(saved) do if Cfg[k] ~= nil and type(Cfg[k]) == type(v) then Cfg[k] = v end end
    end
end)
local SILENT_PARTS = {{"Head", "head"}, {"Torso", "torso"}}

local connections, cleanups = {}, {}
local function connect(sig, fn) local c = sig:Connect(fn); connections[#connections + 1] = c; return c end

-- ---------------------------------------------------------------- viewmodel ownership
local function isVM(m) return m ~= nil and m:IsA("Model") and m:GetAttribute("Viewmodels") == true end
local ownerOf = {}                       -- [viewmodel model] = player
local worldClear                          -- defined further down; declared here so the ESP can call it
local ownerSure = {}                     -- [viewmodel] = true when the owner came from the character itself (not a position guess)
local seenVM = {}

local function guessOwner(vm)
    for _, v in pairs(vm:GetAttributes()) do
        for _, plr in ipairs(Players:GetPlayers()) do
            if v == plr.Name or v == plr.UserId or v == plr.DisplayName then return plr end
        end
    end
end

local function positionOwner(vm)
    local torso = vm:FindFirstChild("torso")
    if not torso then return nil end
    local best, bestD
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local ch = plr.Character
            local part = ch:FindFirstChild("HumanoidRootPart") or ch.PrimaryPart
            if not part then
                for _, d in ipairs(ch:GetDescendants()) do
                    if d:IsA("BasePart") then part = d break end
                end
            end
            if part then
                local d = (part.Position - torso.Position).Magnitude
                if d < 6 and (not bestD or d < bestD) then best, bestD = plr, d end
            end
        end
    end
    return best
end

local function watchCharacter(plr, char)
    if plr == LocalPlayer then return end
    task.spawn(function()
        local torso = char:WaitForChild("torso", 8)
        if not torso then return end
        if isVM(torso.Parent) then ownerOf[torso.Parent] = plr; ownerSure[torso.Parent] = true return end
        local conn
        conn = torso.AncestryChanged:Connect(function()
            conn:Disconnect()
            if isVM(torso.Parent) then ownerOf[torso.Parent] = plr; ownerSure[torso.Parent] = true end
        end)
    end)
end
local function hookPlayer(plr)
    if plr == LocalPlayer then return end
    if plr.Character then watchCharacter(plr, plr.Character) end
    connect(plr.CharacterAdded, function(c) watchCharacter(plr, c) end)
end
for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
connect(Players.PlayerAdded, hookPlayer)

-- ---------------------------------------------------------------- box ESP
local espGui = Instance.new("ScreenGui")
espGui.Name = HttpService:GenerateGUID(false)
espGui.ResetOnSpawn = false
espGui.IgnoreGuiInset = true
espGui.Parent = GuiParent

local entries = {}                       -- [vm] = {frame, stroke, name, dist, hpBg, hpFg, hl}
local function hpColor(p)
    if p > 0.6 then return Color3.fromRGB(40, 215, 80) end
    if p > 0.3 then return Color3.fromRGB(235, 195, 30) end
    return Color3.fromRGB(230, 45, 45)
end
local function makeEntry(vm)
    local f = Instance.new("Frame", espGui)
    f.BackgroundTransparency = 1
    f.BorderSizePixel = 0
    f.Visible = false
    local st = Instance.new("UIStroke", f)
    st.Thickness = 1.6
    st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    local name = Instance.new("TextLabel", f)
    name.Size = UDim2.new(1, 40, 0, 14)
    name.Position = UDim2.new(0, -20, 0, -16)
    name.BackgroundTransparency = 1
    name.Font = Enum.Font.GothamBold
    name.TextSize = 13
    name.TextColor3 = Color3.new(1, 1, 1)
    name.TextStrokeTransparency = 0.3
    local dist = Instance.new("TextLabel", f)
    dist.Size = UDim2.new(1, 40, 0, 12)
    dist.Position = UDim2.new(0, -20, 1, 2)
    dist.BackgroundTransparency = 1
    dist.Font = Enum.Font.Gotham
    dist.TextSize = 11
    dist.TextColor3 = Color3.fromRGB(190, 190, 190)
    dist.TextStrokeTransparency = 0.3
    local hpBg = Instance.new("Frame", f)
    hpBg.Size = UDim2.new(0, 3, 1, 0)
    hpBg.Position = UDim2.new(0, -6, 0, 0)
    hpBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    hpBg.BorderSizePixel = 0
    local hpFg = Instance.new("Frame", hpBg)
    hpFg.AnchorPoint = Vector2.new(0, 1)
    hpFg.Position = UDim2.fromScale(0, 1)
    hpFg.Size = UDim2.fromScale(1, 1)
    hpFg.BorderSizePixel = 0
    local hl = Instance.new("Highlight")
    hl.Name = "op1_esp"
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillTransparency = 0.6
    hl.Enabled = false
    hl.Parent = vm
    local corners, bones = {}, {}
    for i = 1, 8 do
        local c = Instance.new("Frame", espGui)
        c.BorderSizePixel = 0
        c.Visible = false
        corners[i] = c
    end
    for i = 1, 5 do
        local b = Instance.new("Frame", espGui)
        b.BorderSizePixel = 0
        b.AnchorPoint = Vector2.new(0.5, 0.5)
        b.Visible = false
        bones[i] = b
    end
    local tracer = Instance.new("Frame", espGui)
    tracer.AnchorPoint = Vector2.new(0.5, 0.5)
    tracer.BackgroundColor3 = Color3.fromRGB(255, 92, 190)
    tracer.BorderSizePixel = 0
    tracer.Visible = false
    local e = {frame = f, stroke = st, name = name, dist = dist, hpBg = hpBg, hpFg = hpFg, hl = hl, corners = corners, bones = bones, tracer = tracer}
    entries[vm] = e
    return e
end
local function dropEntry(vm)
    local e = entries[vm]
    if not e then return end
    pcall(function() e.frame:Destroy() end)
    pcall(function() e.hl:Destroy() end)
    pcall(function() e.tracer:Destroy() end)
    for _, c in ipairs(e.corners) do pcall(function() c:Destroy() end) end
    for _, b in ipairs(e.bones) do pcall(function() b:Destroy() end) end
    entries[vm] = nil
end
local function hideEntry(e)
    e.frame.Visible = false
    e.tracer.Visible = false
    e.hl.Enabled = false
    for _, c in ipairs(e.corners) do c.Visible = false end
    for _, b in ipairs(e.bones) do b.Visible = false end
end
local function drawCorners(e, x0, y0, x1, y1, col)
    local len, t = math.max(6, math.min(x1 - x0, y1 - y0) * 0.25), 2
    local segs = {
        {x0, y0, len, t}, {x0, y0, t, len}, {x1 - len, y0, len, t}, {x1 - t, y0, t, len},
        {x0, y1 - t, len, t}, {x0, y1 - len, t, len}, {x1 - len, y1 - t, len, t}, {x1 - t, y1 - len, t, len},
    }
    for i, s in ipairs(segs) do
        local c = e.corners[i]
        c.Position, c.Size, c.BackgroundColor3, c.Visible = UDim2.fromOffset(s[1], s[2]), UDim2.fromOffset(s[3], s[4]), col, true
    end
end
local BONES = {{"head", "torso"}, {"torso", "arm1"}, {"torso", "arm2"}, {"torso", "leg1"}, {"torso", "leg2"}}
local function drawSkeleton(cam, vm, e, col)
    for i, pair in ipairs(BONES) do
        local b = e.bones[i]
        local pa, pb = vm:FindFirstChild(pair[1]), vm:FindFirstChild(pair[2])
        local ok = false
        if pa and pb and pa:IsA("BasePart") and pb:IsA("BasePart") then
            local a, b2 = cam:WorldToViewportPoint(pa.Position), cam:WorldToViewportPoint(pb.Position)
            if a.Z > 0 and b2.Z > 0 then
                local va, vb = Vector2.new(a.X, a.Y), Vector2.new(b2.X, b2.Y)
                local d = vb - va
                b.Size = UDim2.fromOffset(d.Magnitude, 1.6)
                b.Position = UDim2.fromOffset((va.X + vb.X) / 2, (va.Y + vb.Y) / 2)
                b.Rotation = math.deg(math.atan2(d.Y, d.X))
                b.BackgroundColor3 = col
                ok = true
            end
        end
        b.Visible = ok
    end
end

local function projectBox(cam, cf, size)
    local half = size / 2
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local any = false
    for _, sx in ipairs({-1, 1}) do
        for _, sy in ipairs({-1, 1}) do
            for _, sz in ipairs({-1, 1}) do
                local s = cam:WorldToViewportPoint(cf:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)))
                if s.Z > 0 then
                    any = true
                    minX, maxX = math.min(minX, s.X), math.max(maxX, s.X)
                    minY, maxY = math.min(minY, s.Y), math.max(maxY, s.Y)
                end
            end
        end
    end
    if any and maxX - minX >= 3 and maxY - minY >= 3 then return minX, minY, maxX, maxY end
end

-- ---------------------------------------------------------------- gun chams
local chamsHL, chamsVM
local function killChams()
    if chamsHL then pcall(function() chamsHL:Destroy() end) end
    chamsHL, chamsVM = nil, nil
end

local lastScan, lastOwnerTry, lastDbg = 0, 0, 0
connect(RunService.RenderStepped, function()
    local cam = Workspace.CurrentCamera
    local vms = Workspace:FindFirstChild("Viewmodels")

    -- discover viewmodels and log what they look like (once each)
    if os.clock() - lastScan > 1 and vms then
        lastScan = os.clock()
        for _, vm in ipairs(vms:GetChildren()) do
            if vm:IsA("Model") and not seenVM[vm] then
                seenVM[vm] = true
                if vm.Name ~= "LocalViewmodel" and not ownerOf[vm] then ownerOf[vm] = guessOwner(vm) or positionOwner(vm) end
                local attrs, kids = {}, {}
                for k, v in pairs(vm:GetAttributes()) do attrs[#attrs + 1] = k .. "=" .. tostring(v) end
                for _, c in ipairs(vm:GetChildren()) do kids[#kids + 1] = c.Name end
                log(string.format("viewmodel %s owner=%s attrs=[%s] children=[%s]", vm.Name,
                    ownerOf[vm] and ownerOf[vm].Name or "unknown", table.concat(attrs, ", "), table.concat(kids, ", ")))
            end
        end
    end

    -- Owners guessed by position can be wrong (everyone is bunched together at spawn), which is how a
    -- teammate ends up shown as an enemy. So every guess is re-checked each second until the owner is certain.
    if os.clock() - lastOwnerTry > 1 and vms then
        lastOwnerTry = os.clock()
        for _, vm in ipairs(vms:GetChildren()) do
            if vm:IsA("Model") and vm.Name ~= "LocalViewmodel" and not ownerSure[vm] then
                local g = guessOwner(vm)
                local o = g or positionOwner(vm)
                if g then ownerSure[vm] = true end
                if o ~= ownerOf[vm] then
                    ownerOf[vm] = o
                    if o then log("owner set to " .. o.Name .. (g and " (attribute)" or " (position)")) end
                end
            end
        end
    end

    -- ESP
    local seen = {}
    local dbg = os.clock() - lastDbg > 5
    if dbg then lastDbg = os.clock() end
    if cam and vms and (Cfg.Box or Cfg.Names or Cfg.Distance or Cfg.HealthBar or Cfg.Highlight) then
        for _, vm in ipairs(vms:GetChildren()) do
            if vm:IsA("Model") and vm.Name ~= "LocalViewmodel" then
                local owner = ownerOf[vm]
                local torso = vm:FindFirstChild("torso")
                local alive = torso ~= nil and torso.Transparency < 1
                local hum = owner and owner.Character and owner.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health <= 0 then alive = false end
                -- unknown owner = can't prove it's an enemy, so with team check on it is not drawn
                local friendly = Cfg.TeamCheck and (owner == nil or (owner.Team ~= nil and LocalPlayer.Team ~= nil and owner.Team == LocalPlayer.Team))
                if dbg then
                    log(string.format("esp check: owner=%s team=%s myTeam=%s torsoTransp=%s alive=%s friendly=%s",
                        owner and owner.Name or "unknown", owner and tostring(owner.Team) or "-", tostring(LocalPlayer.Team),
                        torso and string.format("%.2f", torso.Transparency) or "no torso", tostring(alive), tostring(friendly)))
                end
                if (alive or Cfg.ShowDead) and not friendly then
                    local ok, cf, size = pcall(function() return vm:GetBoundingBox() end)
                    if ok and cf then
                        local distance = (cam.CFrame.Position - cf.Position).Magnitude
                        if distance <= Cfg.MaxDist then
                            local x0, y0, x1, y1 = projectBox(cam, cf, size)
                            local e = entries[vm] or makeEntry(vm)
                            local col = BOX_COLORS[Cfg.BoxColor][2]
                            if Cfg.VisTint then
                                if os.clock() - (e.vt or 0) > 0.1 then
                                    e.vt = os.clock()
                                    local hd = vm:FindFirstChild("head")
                                    e.vis = hd ~= nil and worldClear(cam, hd.Position)
                                end
                                if e.vis then col = Color3.fromRGB(80, 255, 110) end
                            end
                            if x0 then
                                e.frame.Position = UDim2.fromOffset(x0, y0)
                                e.frame.Size = UDim2.fromOffset(x1 - x0, y1 - y0)
                                e.frame.Visible = true
                                e.stroke.Enabled = Cfg.Box and Cfg.BoxMode == 1
                                e.stroke.Color = col
                                if Cfg.Box and Cfg.BoxMode == 2 then drawCorners(e, x0, y0, x1, y1, col)
                                else for _, c in ipairs(e.corners) do c.Visible = false end end
                                if Cfg.Skeleton then drawSkeleton(cam, vm, e, col)
                                else for _, b in ipairs(e.bones) do b.Visible = false end end
                                if Cfg.Tracers then
                                    local vp = cam.ViewportSize
                                    local a, b = Vector2.new(vp.X / 2, vp.Y), Vector2.new((x0 + x1) / 2, y1)
                                    local d = b - a
                                    e.tracer.Size = UDim2.fromOffset(d.Magnitude, 1.5)
                                    e.tracer.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
                                    e.tracer.Rotation = math.deg(math.atan2(d.Y, d.X))
                                    e.tracer.Visible = true
                                else e.tracer.Visible = false end
                                e.name.Visible = Cfg.Names
                                e.name.Text = owner and owner.DisplayName or "enemy"
                                e.dist.Visible = Cfg.Distance
                                e.dist.Text = string.format("[ %dm ]", math.floor(distance))
                                local showHp = Cfg.HealthBar and hum ~= nil
                                e.hpBg.Visible = showHp
                                if showHp then
                                    local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                                    e.hpFg.Size = UDim2.fromScale(1, pct)
                                    e.hpFg.BackgroundColor3 = hpColor(pct)
                                end
                            else
                                e.frame.Visible = false
                            end
                            e.hl.Enabled = Cfg.Highlight
                            e.hl.FillColor, e.hl.OutlineColor = col, col
                            seen[vm] = true
                        end
                    end
                end
            end
        end
    end
    for vm, e in pairs(entries) do
        if not vm.Parent then dropEntry(vm)
        elseif not seen[vm] then hideEntry(e) end
    end

    -- gun chams on your own viewmodel
    local lvm = vms and vms:FindFirstChild("LocalViewmodel")
    if not Cfg.Chams or not lvm then killChams() return end
    if chamsVM ~= lvm or not chamsHL or not chamsHL.Parent then
        killChams()
        chamsHL = Instance.new("Highlight")
        chamsHL.Name = "chams"
        chamsHL.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        chamsHL.Adornee = lvm
        if not pcall(function() chamsHL.Parent = CoreGui end) then chamsHL.Parent = Workspace.CurrentCamera end
        chamsVM = lvm
    end
    local entry = CHAMS_COLORS[Cfg.ChamsColor]
    local col = entry[2] or Color3.fromHSV((os.clock() * 0.3) % 1, 1, 1)
    chamsHL.FillColor, chamsHL.OutlineColor = col, col
    chamsHL.FillTransparency = Cfg.ChamsPulse and (0.3 + 0.5 * math.abs(math.sin(os.clock() * 2))) or Cfg.ChamsTrans
    chamsHL.OutlineTransparency = 0
end)

-- ---------------------------------------------------------------- targeting + triggerbot
-- Enemy viewmodel parts may not be hittable by rays, so targets are found from SCREEN positions (like the
-- N0IR script does) and only the world is raycast, to check nothing solid is in the way.
local holding = false
local acquiredAt = nil
-- You holding fire yourself: the triggerbot must never press or release over you, or its release cancels your
-- hold and full-auto guns only fire one shot at a time.
local userHeld = false
connect(UserInputService.InputBegan, function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 and not holding then userHeld = true end
end)
connect(UserInputService.InputEnded, function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 and not holding then userHeld = false end
end)
local function press()
    if holding or userHeld then return end
    holding = true
    if mouse1press then pcall(mouse1press)
    else pcall(function()
        local vim = game:GetService("VirtualInputManager")
        local m = UserInputService:GetMouseLocation()
        vim:SendMouseButtonEvent(m.X, m.Y, 0, true, game, 0)
    end) end
end
local function release()
    if not holding then return end
    holding = false
    if userHeld then return end                 -- you took over: leave the button down for you
    if mouse1release then pcall(mouse1release)
    else pcall(function()
        local vim = game:GetService("VirtualInputManager")
        local m = UserInputService:GetMouseLocation()
        vim:SendMouseButtonEvent(m.X, m.Y, 0, false, game, 0)
    end) end
end
cleanups[#cleanups + 1] = release

local function isFriendly(vm)
    if not Cfg.TeamCheck then return false end
    local owner = ownerOf[vm]
    if owner == nil then return true end
    return owner.Team ~= nil and LocalPlayer.Team ~= nil and owner.Team == LocalPlayer.Team
end
local function isAlive(vm)
    local torso = vm:FindFirstChild("torso")
    if not torso or torso.Transparency >= 1 then return false end
    local owner = ownerOf[vm]
    local hum = owner and owner.Character and owner.Character:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then return false end
    return true
end

-- let the actor-side silent aim know which viewmodels are teammates
task.spawn(function()
    while logAlive do
        task.wait(0.5)
        local vms = Workspace:FindFirstChild("Viewmodels")
        if vms then
            for _, vm in ipairs(vms:GetChildren()) do
                if vm:IsA("Model") and vm.Name ~= "LocalViewmodel" then
                    local f = isFriendly(vm) or nil
                    if vm:GetAttribute("OP1Friendly") ~= f then vm:SetAttribute("OP1Friendly", f) end
                end
            end
        end
    end
end)

-- can a bullet get through this part? (rules follow the N0IR script: Soft/Hard attributes, thin parts; plus barricades)
local function isBarricade(inst)
    local mdl = inst:FindFirstAncestorWhichIsA("Model")
    local nm = (inst.Name .. " " .. (mdl and mdl.Name or "")):lower()
    if nm:find("barricade", 1, true) then return true end
    local ok, tagged = pcall(function() return inst:HasTag("Barricade") or (mdl ~= nil and mdl:HasTag("Barricade")) end)
    return ok and tagged or false
end
local lastBlocker
local function canPenetrate(inst)
    if not inst or not inst:IsA("BasePart") then return true end
    if inst.Transparency >= 1 or not inst.CanCollide then return true end
    if Cfg.Barricades and isBarricade(inst) then return true end
    if not Cfg.ThinWalls then return false end
    local parent = inst.Parent
    local hard = inst:GetAttribute("Hard") or (parent and parent:GetAttribute("Hard"))
    local soft = inst:GetAttribute("Soft") or (parent and parent:GetAttribute("Soft"))
    if soft then return true end
    local dims = {inst.Size.X, inst.Size.Y, inst.Size.Z}
    table.sort(dims)
    if hard then return dims[2] <= 0.5 end
    return dims[2] < 1.45
end

function worldClear(cam, targetPos)
    local vms = Workspace:FindFirstChild("Viewmodels")
    local ignore = {cam}
    if vms then ignore[#ignore + 1] = vms end
    if LocalPlayer.Character then ignore[#ignore + 1] = LocalPlayer.Character end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = ignore
    rp.IgnoreWater = true
    local pos = cam.CFrame.Position
    lastBlocker = nil
    for _ = 1, 10 do
        local r = Workspace:Raycast(pos, targetPos - pos, rp)
        if not r then return true end
        if not canPenetrate(r.Instance) then lastBlocker = r.Instance; return false end
        rp:AddToFilter(r.Instance)
        local rest = targetPos - r.Position
        if rest.Magnitude < 0.1 then return true end
        pos = r.Position + rest.Unit * 0.01
    end
    return true
end

-- grenades, barricade items, shields and the like must never be "fired" by the triggerbot
local NOT_GUNS = {"grenade", "barricade", "reinforce", "shield", "disruptor", "drone", "phone", "camera", "claymore", "mine", "c4", "defus"}
local function holdingGun()
    local vms = Workspace:FindFirstChild("Viewmodels")
    local lvm = vms and vms:FindFirstChild("LocalViewmodel")
    if not lvm then return false end
    for _, c in ipairs(lvm:GetChildren()) do
        if c:IsA("Model") and c:FindFirstChild("Root") then
            local n = c.Name:lower()
            for _, bad in ipairs(NOT_GUNS) do
                if n:find(bad, 1, true) then return false end
            end
        end
    end
    return true
end

-- closest-to-crosshair living enemy inside the lock radius and range (the silent aim's target)
local function lockTarget(cam)
    local vms = Workspace:FindFirstChild("Viewmodels")
    if not (cam and vms) then return nil end
    local center = cam.ViewportSize / 2
    local best, bestD
    for _, vm in ipairs(vms:GetChildren()) do
        if vm:IsA("Model") and vm.Name ~= "LocalViewmodel" and isAlive(vm) and not isFriendly(vm) then
            local part = vm:FindFirstChild(SILENT_PARTS[Cfg.SilentPart][2]) or vm:FindFirstChild("head")
            if part then
                local dist = (part.Position - cam.CFrame.Position).Magnitude
                if dist <= Cfg.SilentRange then
                    local sp, on = cam:WorldToViewportPoint(part.Position)
                    if on and sp.Z > 0 then
                        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        if d <= Cfg.SilentFov and (not bestD or d < bestD) then
                            if not Cfg.SilentVisible or worldClear(cam, part.Position) then best, bestD = vm, d end
                        end
                    end
                end
            end
        end
    end
    return best
end

-- is the crosshair on an enemy right now? (on their head, or inside their upper-body box, with a clear shot)
local function crosshairTarget(cam)
    local vms = Workspace:FindFirstChild("Viewmodels")
    if not (cam and vms) then return nil end
    local c = cam.ViewportSize / 2
    for _, vm in ipairs(vms:GetChildren()) do
        if vm:IsA("Model") and vm.Name ~= "LocalViewmodel" and isAlive(vm) and not isFriendly(vm) then
            local head = vm:FindFirstChild("head")
            local onTarget, aimPos = false, nil
            if head then
                local hp, on = cam:WorldToViewportPoint(head.Position)
                if on and hp.Z > 0 and hp.Z <= Cfg.TriggerRange then
                    local r = math.max(6, (head.Size.Magnitude * 0.55) / hp.Z * cam.ViewportSize.Y / (2 * math.tan(math.rad(cam.FieldOfView / 2))))
                    if (Vector2.new(hp.X, hp.Y) - c).Magnitude <= r then onTarget, aimPos = true, head.Position end
                end
            end
            if not onTarget and not Cfg.TriggerHeadOnly then
                local ok, cf, size = pcall(function() return vm:GetBoundingBox() end)
                if ok and cf and (cf.Position - cam.CFrame.Position).Magnitude <= Cfg.TriggerRange then
                    local x0, y0, x1, y1 = projectBox(cam, cf, size)
                    if x0 then
                        local w, h = x1 - x0, y1 - y0
                        if c.X > x0 + w * 0.2 and c.X < x1 - w * 0.2 and c.Y > y0 and c.Y < y0 + h * 0.75 then
                            onTarget, aimPos = true, (head or vm:FindFirstChild("torso") or {Position = cf.Position}).Position
                        end
                    end
                end
            end
            if onTarget and (not Cfg.TriggerWallCheck or worldClear(cam, aimPos)) then return vm end
        end
    end
end

local lastTrigLog = 0
connect(RunService.Heartbeat, function()
    if not Cfg.Trigger then release(); acquiredAt = nil return end
    if UserInputService:GetFocusedTextBox() then release() return end
    if not holdingGun() then release(); acquiredAt = nil return end
    local cam = Workspace.CurrentCamera
    local target = crosshairTarget(cam)
    local why = target and "crosshair" or nil
    if not target and Cfg.Silent and Cfg.TriggerOnLock then
        target = lockTarget(cam)
        why = target and "silent lock" or nil
    end
    if os.clock() - lastTrigLog > 3 then
        lastTrigLog = os.clock()
        log(string.format("trigger: target=%s via %s, holding=%s, lastBlocker=%s", target and (ownerOf[target] and ownerOf[target].Name or "unknown") or "none", tostring(why), tostring(holding), lastBlocker and (lastBlocker:GetFullName() .. " " .. tostring(lastBlocker.Size)) or "-"))
    end
    if target then
        acquiredAt = acquiredAt or os.clock()
        if os.clock() - acquiredAt >= Cfg.TriggerDelay then press() end
    else
        acquiredAt = nil
        release()
    end
end)

-- ---------------------------------------------------------------- aimbot (mouse lock-on)
-- Moves the real mouse toward the closest enemy while you hold fire or aim. It measures how far the crosshair
-- actually moved for the mouse units it sent, so it works at any sensitivity. Sticky target, head or torso.
do
    local lock = {vm = nil, scale = 1, cmd = nil, last = nil, accX = 0, accY = 0}
    local function candidate(cam, vm, c, mul)
        if not (vm:IsA("Model") and vm.Name ~= "LocalViewmodel" and isAlive(vm) and not isFriendly(vm)) then return end
        local part = vm:FindFirstChild(SILENT_PARTS[Cfg.AimPart][2]) or vm:FindFirstChild("head")
        if not part then return end
        if (part.Position - cam.CFrame.Position).Magnitude > Cfg.AimRange then return end
        local sp, on = cam:WorldToViewportPoint(part.Position)
        if not (on and sp.Z > 0) then return end
        local p = Vector2.new(sp.X, sp.Y)
        local d = (p - c).Magnitude
        if d > Cfg.AimFov * mul then return end
        if Cfg.AimVisible and not worldClear(cam, part.Position) then return end
        return d, p
    end
    connect(RunService.RenderStepped, function()
        if not Cfg.Aim or not mousemoverel then return end
        local cam = Workspace.CurrentCamera
        local vms = Workspace:FindFirstChild("Viewmodels")
        local fire = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        local ads = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        local gren = Cfg.GrenadeLock and gaAim.held and gaAim.pos ~= nil and os.clock() - gaAim.t < 1
        if not (cam and vms) or not (fire or ads) or UserInputService:GetFocusedTextBox() or (not gren and not holdingGun()) then
            lock.vm, lock.cmd, lock.last, lock.accX, lock.accY = nil, nil, nil, 0, 0
            return
        end
        local c = cam.ViewportSize / 2
        local target, tpos
        if gren then
            -- holding a grenade: lock onto the throw direction that lands on the nearest enemy
            local sp, on = cam:WorldToViewportPoint(gaAim.pos)
            if on and sp.Z > 0 then target, tpos = "grenade", Vector2.new(sp.X, sp.Y) end
        elseif Cfg.AimSticky and lock.vm and lock.vm.Parent then
            local d, p = candidate(cam, lock.vm, c, 1.6)
            if d then target, tpos = lock.vm, p end
        end
        if not target and not gren then
            local bestD
            for _, vm in ipairs(vms:GetChildren()) do
                local d, p = candidate(cam, vm, c, 1)
                if d and (not bestD or d < bestD) then bestD, target, tpos = d, vm, p end
            end
        end
        if not target then lock.vm, lock.cmd, lock.last = nil, nil, nil return end
        if lock.vm ~= target then lock.vm, lock.cmd, lock.last, lock.accX, lock.accY = target, nil, nil, 0, 0; lock.t0 = os.clock(); lock.react = (0.04 + math.random() * 0.12) * (Cfg.AimHuman / 100) end
        if lock.cmd and lock.last then
            local m2 = lock.cmd.X * lock.cmd.X + lock.cmd.Y * lock.cmd.Y
            if m2 > 4 then
                local moved = lock.last - tpos
                local est = (moved.X * lock.cmd.X + moved.Y * lock.cmd.Y) / m2
                if est > 0.02 and est < 30 then lock.scale = lock.scale + (est - lock.scale) * 0.2 end
            end
        end
        lock.last = tpos
        local err = tpos - c
        local hum = Cfg.AimHuman / 100
        local t = os.clock()
        -- the aim point drifts slowly around the target instead of sitting dead centre
        err = err + Vector2.new(math.noise(t * 0.9, 11.3, 0) * 7 * hum, math.noise(t * 0.9, 47.7, 0) * 5 * hum)
        if err.Magnitude < 2 + 3 * hum then lock.cmd = nil return end
        -- reaction time after a target is picked up, then an ease-in so it never snaps
        local since = t - (lock.t0 or t)
        local react = lock.react or 0
        if since < react then lock.cmd = nil return end
        local ramp = math.clamp((since - react) / (0.05 + 0.3 * hum), 0, 1)
        ramp = ramp * ramp * (3 - 2 * ramp)
        -- slows down for the fine adjustment as it closes in
        local near = hum > 0 and math.clamp(err.Magnitude / (60 + 60 * (1 - hum)), 0.25, 1) or 1
        local cmd = err * (Cfg.AimSmooth / lock.scale) * ramp * near
        -- slightly curved path plus a little hand tremor
        local ang = math.noise(t * 0.6, 5.5, 0) * 0.35 * hum * math.clamp(err.Magnitude / 150, 0, 1)
        cmd = Vector2.new(cmd.X * math.cos(ang) - cmd.Y * math.sin(ang), cmd.X * math.sin(ang) + cmd.Y * math.cos(ang))
        cmd = cmd + Vector2.new(math.noise(t * 13, 1.5, 0), math.noise(t * 13, 2.5, 0)) * 0.6 * hum
        local m = cmd.Magnitude
        if m > Cfg.AimMaxStep then cmd = cmd * (Cfg.AimMaxStep / m) end
        lock.cmd = cmd
        lock.accX, lock.accY = lock.accX + cmd.X, lock.accY + cmd.Y
        local ix = lock.accX >= 0 and math.floor(lock.accX) or math.ceil(lock.accX)
        local iy = lock.accY >= 0 and math.floor(lock.accY) or math.ceil(lock.accY)
        lock.accX, lock.accY = lock.accX - ix, lock.accY - iy
        if ix ~= 0 or iy ~= 0 then pcall(mousemoverel, ix, iy) end
    end)

    -- pink aimbot ring (matches the lock-on radius) and a line to the locked target
    do
        local PINK = Color3.fromRGB(255, 92, 190)
        local ring = Instance.new("Frame", espGui)
        ring.AnchorPoint = Vector2.new(0.5, 0.5)
        ring.BackgroundTransparency = 1
        ring.BorderSizePixel = 0
        ring.Visible = false
        Instance.new("UICorner", ring).CornerRadius = UDim.new(0.5, 0)
        local rs = Instance.new("UIStroke", ring)
        rs.Color, rs.Thickness, rs.Transparency = PINK, 1.5, 0.35
        local ln = Instance.new("Frame", espGui)
        ln.AnchorPoint = Vector2.new(0.5, 0.5)
        ln.BackgroundColor3 = PINK
        ln.BorderSizePixel = 0
        ln.Visible = false
        connect(RunService.RenderStepped, function()
            local cam = Workspace.CurrentCamera
            if not cam then return end
            local c = cam.ViewportSize / 2
            ring.Visible = Cfg.Aim and Cfg.AimCircle
            if ring.Visible then
                ring.Position = UDim2.fromOffset(c.X, c.Y)
                ring.Size = UDim2.fromOffset(Cfg.AimFov * 2, Cfg.AimFov * 2)
            end
            if Cfg.Aim and Cfg.AimLine and lock.last then
                local d = lock.last - c
                ln.Size = UDim2.fromOffset(d.Magnitude, 1.5)
                ln.Position = UDim2.fromOffset(c.X + d.X / 2, c.Y + d.Y / 2)
                ln.Rotation = math.deg(math.atan2(d.Y, d.X))
                ln.Visible = true
            else
                ln.Visible = false
            end
        end)
    end
end

-- ---------------------------------------------------------------- quick peek
-- Tap Q or E twice quickly: you lean out, the lean is held for a moment, then released.
-- The triggerbot / aimbot do the shooting while you are out.
do
    local vim = game:GetService("VirtualInputManager")
    local lastTap, busy, leaning = {}, false, nil
    local function setLean(code, down) pcall(function() vim:SendKeyEvent(down, code, false, game) end) end
    connect(UserInputService.InputBegan, function(i, gp)
        if gp or busy or not Cfg.Peek or UserInputService:GetFocusedTextBox() then return end
        local k = i.KeyCode
        if k ~= Enum.KeyCode.Q and k ~= Enum.KeyCode.E then return end
        local now = os.clock()
        if lastTap[k] and now - lastTap[k] <= Cfg.PeekTap then
            lastTap[k] = nil
            busy, leaning = true, k
            setLean(k, true)                       -- make sure the lean is on
            task.delay(Cfg.PeekTime, function()
                if leaning then setLean(leaning, false); leaning = nil end
                task.delay(0.15, function() busy = false end)
            end)
        else
            lastTap[k] = now
        end
    end)
    cleanups[#cleanups + 1] = function() if leaning then setLean(leaning, false); leaning = nil end end
end

-- ---------------------------------------------------------------- world / camera + watermark
do
    local Lighting = game:GetService("Lighting")
    local orig = {Brightness = Lighting.Brightness, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
        GlobalShadows = Lighting.GlobalShadows, FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart}
    local atm, was, origFov = {}, {}, nil
    local function restore(...) for _, k in ipairs({...}) do pcall(function() Lighting[k] = orig[k] end) end end
    local function feature(name, on, applyFn, restoreFn)
        if on then applyFn(); was[name] = true elseif was[name] then restoreFn(); was[name] = false end
    end
    connect(RunService.RenderStepped, function()
        pcall(function()
            feature("fb", Cfg.Fullbright, function()
                Lighting.Brightness = 2; Lighting.GlobalShadows = false
                Lighting.Ambient = Color3.fromRGB(190, 190, 190); Lighting.OutdoorAmbient = Color3.fromRGB(190, 190, 190)
            end, function() restore("Brightness", "GlobalShadows", "Ambient", "OutdoorAmbient") end)
            feature("fog", Cfg.NoFog, function()
                Lighting.FogEnd, Lighting.FogStart = 1e6, 1e6
                for _, a in ipairs(Lighting:GetChildren()) do
                    if a:IsA("Atmosphere") then if atm[a] == nil then atm[a] = a.Density end; a.Density = 0 end
                end
            end, function()
                restore("FogEnd", "FogStart")
                for a, d in pairs(atm) do pcall(function() a.Density = d end); atm[a] = nil end
            end)
            feature("fov", Cfg.Fov, function()
                local cam = Workspace.CurrentCamera
                origFov = origFov or cam.FieldOfView
                cam.FieldOfView = Cfg.FovValue
            end, function()
                if origFov then Workspace.CurrentCamera.FieldOfView = origFov end
                origFov = nil
            end)
        end)
    end)
    cleanups[#cleanups + 1] = function()
        restore("Brightness", "Ambient", "OutdoorAmbient", "GlobalShadows", "FogEnd", "FogStart")
        for a, d in pairs(atm) do pcall(function() a.Density = d end) end
        pcall(function() if origFov then Workspace.CurrentCamera.FieldOfView = origFov end end)
    end

    local wm = Instance.new("TextLabel", espGui)
    wm.Position, wm.Size = UDim2.fromOffset(12, 10), UDim2.fromOffset(320, 18)
    wm.BackgroundTransparency = 1
    wm.Font, wm.TextSize = Enum.Font.GothamBold, 13
    wm.TextColor3 = Color3.fromRGB(0, 188, 168)
    wm.TextStrokeTransparency = 0.4
    wm.TextXAlignment = Enum.TextXAlignment.Left
    local fps, lastWm = 60, 0
    connect(RunService.RenderStepped, function(dt)
        fps = fps + (1 / math.max(dt, 1e-3) - fps) * 0.05
        wm.Visible = Cfg.Watermark
        if Cfg.Watermark and os.clock() - lastWm > 0.5 then
            lastWm = os.clock()
            wm.Text = string.format("KING HUB  |  Operation One  |  %d fps  |  %s", math.floor(fps), os.date("%H:%M"))
        end
    end)
end

-- ---------------------------------------------------------------- no recoil
-- Operation One's recoil is a camera kick (Gun.recoil_function). The game's scripts run inside an actor, so the
-- patch is run there. It replaces the kick with nothing on the gun class and on every gun already created.
-- Visual only: nothing is sent to the server and bullet spread is untouched.
local NORECOIL_SRC = [==[
    local rs = game:GetService("ReplicatedStorage")
    local ok, gun = pcall(require, rs.Modules.Items.Item.Gun)
    if not ok or type(gun) ~= "table" then
        pcall(writefile, "king_hub/op1_norecoil.txt", "Gun module not found: " .. tostring(gun))
        return
    end
    gun._op1_nr = __FLAG__
    if not gun._op1_nr_patched and type(gun.recoil_function) == "function" then
        gun._op1_nr_patched = true
        local old = gun.recoil_function
        gun.recoil_function = function(self, ...)
            if gun._op1_nr then return end
            return old(self, ...)
        end
    end
    local wrapped, seen = 0, 0
    if getgc then
        for _, t in ipairs(getgc(true)) do
            if type(t) == "table" and rawget(t, "_op1_wrapped") == nil then
                local r = rawget(t, "recoil")
                if type(r) == "function" and rawget(t, "states") ~= nil then
                    seen += 1
                    rawset(t, "_op1_wrapped", true)
                    rawset(t, "recoil", function(...)
                        if gun._op1_nr then return end
                        return r(...)
                    end)
                    wrapped += 1
                end
            end
        end
    end
    pcall(writefile, "king_hub/op1_norecoil.txt", string.format("enabled=%s classPatched=%s newlyWrappedGuns=%d", tostring(gun._op1_nr), tostring(gun._op1_nr_patched), wrapped))
]==]

local function applyNoRecoil()
    local src = string.gsub(NORECOIL_SRC, "__FLAG__", Cfg.NoRecoil and "true" or "false")
    if getactors and run_on_actor then
        local actors = getactors()
        local actor = actors and actors[1]
        if not actor then log("no-recoil: no actor found") return false end
        local ok, err = pcall(run_on_actor, actor, src)
        if not ok then log("no-recoil: run_on_actor failed: " .. tostring(err)) end
        return ok
    end
    -- No actor support (e.g. Xeno): the game's gun code lives in an actor we can't reach. Requiring the game's
    -- modules from here creates a broken second copy that spams "Cannot require a RobloxScript module" errors,
    -- so no-recoil is simply not available on this executor.
    return false
end
log("no-recoil: actor support = " .. tostring(getactors ~= nil and run_on_actor ~= nil))
task.spawn(function()
    local lastFlag
    if not (getactors and run_on_actor) then
        log("no-recoil: needs getactors/run_on_actor, which this executor does not have - disabled")
        return
    end
    while task.wait(3) and logAlive do
        if lastFlag ~= Cfg.NoRecoil or Cfg.NoRecoil then   -- re-run so guns created later get wrapped too
            lastFlag = Cfg.NoRecoil
            applyNoRecoil()
        end
    end
end)

-- ---------------------------------------------------------------- recoil control (no actor support)
-- Executors without getactors/run_on_actor (e.g. Xeno) can't patch the gun, so this counters the kick with the
-- mouse instead. Every frame it compares how far the camera turned with how far the mouse moved: whatever is left
-- over while you shoot is recoil, and the mouse is pulled back by that much. Mouse units per radian are learned from
-- your own mouse movement (separately for hip fire and aiming down sights), so it works at any sensitivity.
if not (getactors and run_on_actor) then
    if not mousemoverel then
        log("recoil control: executor has no mousemoverel - no recoil not available")
    else
        log("recoil control: no actor support, using mouse recoil control")
        local rcs = {k = {}, debtP = 0, debtY = 0, lastP = nil, lastY = nil, until_ = 0, logged = 0}
        local function angles(cam)
            local lv = cam.CFrame.LookVector
            return math.asin(math.clamp(lv.Y, -1, 1)), math.atan2(-lv.X, -lv.Z)
        end
        local function wrap(a) return (a + math.pi) % (2 * math.pi) - math.pi end
        -- raw mouse movement since the last frame (GetMouseDelta reads 0 unless the mouse is locked Roblox's way)
        local accX, accY = 0, 0
        connect(UserInputService.InputChanged, function(i)
            if i.UserInputType == Enum.UserInputType.MouseMovement then accX += i.Delta.X; accY += i.Delta.Y end
        end)
        local stat = {frames = 0, firing = 0, moved = 0, sent = 0, kick = 0, lastLog = 0}
        RunService:BindToRenderStep("king_op1_rcs", Enum.RenderPriority.Camera.Value + 5, function()
            local cam = Workspace.CurrentCamera
            if not cam then return end
            local p, y = angles(cam)
            local lastP, lastY = rcs.lastP, rcs.lastY
            rcs.lastP, rcs.lastY = p, y
            local md = Vector2.new(accX, accY)
            accX, accY = 0, 0
            if md.Magnitude == 0 then md = UserInputService:GetMouseDelta() end
            stat.frames += 1
            if md.Magnitude > 0 then stat.moved += 1 end
            if os.clock() - stat.lastLog > 4 then
                stat.lastLog = os.clock()
                log(string.format("recoil control: on=%s gun=%s frames=%d mouseMovedFrames=%d firingFrames=%d kick=%.4frad corrections=%d k(hip)=%s k(ads)=%s",
                    tostring(Cfg.NoRecoil), tostring(holdingGun()), stat.frames, stat.moved, stat.firing, stat.kick, stat.sent,
                    rcs.k.hip and string.format("%.6f", rcs.k.hip) or "unlearned", rcs.k.ads and string.format("%.6f", rcs.k.ads) or "unlearned"))
                stat.frames, stat.moved, stat.firing, stat.sent, stat.kick = 0, 0, 0, 0, 0
            end
            if not lastP then return end
            local dP, dY = p - lastP, wrap(y - lastY)
            if math.abs(dP) > 0.35 or math.abs(dY) > 0.6 then rcs.debtP, rcs.debtY = 0, 0 return end   -- respawn / teleport
            local ads = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
            local slot = ads and "ads" or "hip"
            local firing = Cfg.NoRecoil and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                and holdingGun() and not UserInputService:GetFocusedTextBox()
            if firing then rcs.until_ = os.clock() + 0.6; stat.firing += 1 end           -- keep correcting while the kick settles
            local k = rcs.k[slot]                                       -- radians of pitch per mouse unit
            if os.clock() > rcs.until_ then
                rcs.debtP, rcs.debtY = 0, 0
                -- learn the scale from your own vertical mouse movement while not shooting
                if math.abs(md.Y) >= 3 and math.abs(dP) > 1e-4 then
                    local est = -dP / md.Y
                    if est > 1e-5 and est < 0.05 then
                        rcs.k[slot] = k and (k + (est - k) * 0.15) or est
                    end
                end
                return
            end
            if not k then
                if os.clock() - rcs.logged > 5 then
                    rcs.logged = os.clock()
                    log("recoil control: move your mouse up/down a bit (" .. slot .. ") so it can learn your sensitivity")
                end
                return
            end
            -- what the mouse explains vs what the camera did: the rest is recoil
            stat.kick += math.max(0, dP - (-k * md.Y))
            rcs.debtP += dP - (-k * md.Y)
            rcs.debtY += dY - (-k * md.X)
            local s = (Cfg.RecoilStrength or 100) / 100
            local mx = math.clamp(rcs.debtY / k * s, -60, 60)
            local my = math.clamp(rcs.debtP / k * s, -60, 60)
            local ix, iy = math.round(mx), math.round(my)
            if ix ~= 0 or iy ~= 0 then
                pcall(mousemoverel, ix, iy)                 -- kicked up/left -> pull down/right
                stat.sent += 1
                rcs.debtP -= iy * k
                rcs.debtY -= ix * k
            end
        end)
        cleanups[#cleanups + 1] = function() pcall(function() RunService:UnbindFromRenderStep("king_op1_rcs") end) end
    end
end

-- ---------------------------------------------------------------- silent aim
-- Runs in the game's actor like the no-recoil patch: Gun.get_shoot_look is wrapped so that, when an enemy is inside
-- the lock radius and range, bullets are aimed at them instead of where you look. Your camera never moves.
local SILENT_SRC = [==[
    local rs = game:GetService("ReplicatedStorage")
    local ws = game:GetService("Workspace")
    local ok, gun = pcall(require, rs.Modules.Items.Item.Gun)
    if not ok or type(gun) ~= "table" then return end
    gun._op1_sa = { on = __ON__, fov = __FOV__, range = __RANGE__, part = "__PART__", visible = __VIS__, bar = __BAR__, thin = __THIN__ }
    local function isBar(inst)
        local mdl = inst:FindFirstAncestorWhichIsA("Model")
        local nm = (inst.Name .. " " .. (mdl and mdl.Name or "")):lower()
        if nm:find("barricade", 1, true) then return true end
        local ok, t = pcall(function() return inst:HasTag("Barricade") or (mdl ~= nil and mdl:HasTag("Barricade")) end)
        return ok and t or false
    end
    local function passable(inst, cfg)
        if not inst or not inst:IsA("BasePart") then return true end
        if inst.Transparency >= 1 or not inst.CanCollide then return true end
        if cfg.bar and isBar(inst) then return true end
        if not cfg.thin then return false end
        local parent = inst.Parent
        local hard = inst:GetAttribute("Hard") or (parent and parent:GetAttribute("Hard"))
        local soft = inst:GetAttribute("Soft") or (parent and parent:GetAttribute("Soft"))
        if soft then return true end
        local d = {inst.Size.X, inst.Size.Y, inst.Size.Z}
        table.sort(d)
        if hard then return d[2] <= 0.5 end
        return d[2] < 1.45
    end
    local function lineClear(cfg, ws, cam, vms, lp, targetPos)
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        rp.FilterDescendantsInstances = { cam, vms, lp.Character }
        local pos = cam.CFrame.Position
        for _ = 1, 10 do
            local r = ws:Raycast(pos, targetPos - pos, rp)
            if not r then return true end
            if not passable(r.Instance, cfg) then return false end
            rp:AddToFilter(r.Instance)
            local rest = targetPos - r.Position
            if rest.Magnitude < 0.1 then return true end
            pos = r.Position + rest.Unit * 0.01
        end
        return true
    end
    if not gun._op1_sa_patched and type(gun.get_shoot_look) == "function" then
        gun._op1_sa_patched = true
        local old = gun.get_shoot_look
        gun.get_shoot_look = function(self, ...)
            local look = old(self, ...)
            local cfg = gun._op1_sa
            if not cfg or not cfg.on or typeof(look) ~= "CFrame" then return look end
            local cam = ws.CurrentCamera
            local vms = ws:FindFirstChild("Viewmodels")
            if not cam or not vms then return look end
            local lp = game:GetService("Players").LocalPlayer
            local center = cam.ViewportSize / 2
            local best, bestD
            for _, vm in ipairs(vms:GetChildren()) do
                if vm.Name ~= "LocalViewmodel" and vm:IsA("Model") and not vm:GetAttribute("OP1Friendly") then
                    local torso = vm:FindFirstChild("torso")
                    local part = vm:FindFirstChild(cfg.part) or vm:FindFirstChild("head")
                    if part and torso and torso.Transparency < 1 then
                        local dist = (part.Position - cam.CFrame.Position).Magnitude
                        if dist <= cfg.range then
                            local sp, on = cam:WorldToViewportPoint(part.Position)
                            if on and sp.Z > 0 then
                                local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                                if d <= cfg.fov and (not bestD or d < bestD) then
                                    local clear = true
                                    if cfg.visible then clear = lineClear(cfg, ws, cam, vms, lp, part.Position) end
                                    if clear then best, bestD = part, d end
                                end
                            end
                        end
                    end
                end
            end
            if best then return CFrame.lookAt(look.Position, best.Position) end
            return look
        end
    end
]==]
local lastSigSA
local function pushSilent()
    local src = SILENT_SRC
    src = string.gsub(src, "__ON__", Cfg.Silent and "true" or "false")
    src = string.gsub(src, "__FOV__", tostring(math.floor(Cfg.SilentFov)))
    src = string.gsub(src, "__RANGE__", tostring(math.floor(Cfg.SilentRange)))
    src = string.gsub(src, "__PART__", SILENT_PARTS[Cfg.SilentPart][2])
    src = string.gsub(src, "__VIS__", Cfg.SilentVisible and "true" or "false")
    src = string.gsub(src, "__BAR__", Cfg.Barricades and "true" or "false")
    src = string.gsub(src, "__THIN__", Cfg.ThinWalls and "true" or "false")
    if getactors and run_on_actor then
        local actors = getactors()
        local actor = actors and actors[1]
        if actor then
            local ok, err = pcall(run_on_actor, actor, src)
            if not ok then log("silent aim: run_on_actor failed: " .. tostring(err)) end
        end
    end
end
task.spawn(function()
    while logAlive do
        task.wait(0.5)
        local sig = table.concat({tostring(Cfg.Silent), math.floor(Cfg.SilentFov), math.floor(Cfg.SilentRange), Cfg.SilentPart, tostring(Cfg.SilentVisible), tostring(Cfg.Barricades), tostring(Cfg.ThinWalls)}, "|")
        if sig ~= lastSigSA then
            lastSigSA = sig
            pushSilent()
            log("silent aim settings pushed: " .. sig)
        end
    end
end)
cleanups[#cleanups + 1] = function() Cfg.Silent = false; pcall(pushSilent) end

-- ---------------------------------------------------------------- grenade aim marker
-- Display only. Re-implements the game's own Trajectory.cast (flight in 0.1s steps, bounces) and the throw formula
-- velocity = (look + 0.3 up) * throw_speed from the position of the grenade in your hand. It finds the look
-- direction that lands the grenade on the nearest enemy and floats a marker where to aim. Nothing is thrown or sent.
local GA_G = Vector3.new(0, -Workspace.Gravity, 0)
local function gaPos(p0, v, t) return GA_G * 0.5 * t * t + v * t + p0 end
local function gaVel(v, t) return GA_G * t + v end
local function gaPlane(p0, v, hit, n)
    local a = (GA_G * 0.5):Dot(n)
    local b = v:Dot(n)
    local c = (p0 - hit):Dot(n)
    if a == 0 then return -c / b end
    return (-b - math.sqrt(b * b - 4 * a * c)) / (2 * a)
end
local gaWood = PhysicalProperties.new(Enum.Material.Wood)
local gaBase = PhysicalProperties.new(Enum.Material.SmoothPlastic)

local function gaCalcSingle(size, p0, v, ignore, idx)
    local t = 0
    local hit
    while true do
        local a, b = gaPos(p0, v, t), gaPos(p0, v, t + 0.1)
        local rp = RaycastParams.new()
        rp.RespectCanCollide = true
        rp.FilterType = Enum.RaycastFilterType.Exclude
        rp.FilterDescendantsInstances = ignore
        pcall(function() rp.CollisionGroup = "thrown" end)
        local r
        if idx == 0 then r = Workspace:Spherecast(a, size.Magnitude * 0.3, b - a, rp) else r = Workspace:Raycast(a, b - a, rp) end
        t += 0.1
        if r then hit = r break end
        if t >= 5 then break end
    end
    if not hit then return nil end
    local tt = gaPlane(p0, v, hit.Position, hit.Normal)
    if tt ~= tt then tt = t end
    return tt, hit.Normal, gaWood
end

local function gaCast(size, p0, v, ignore, maxBounces)
    local segs = {}
    local p, vv, idx = p0, v, 0
    while vv:Dot(vv) >= 10 and idx <= maxBounces do
        local t, n, props = gaCalcSingle(size, p, vv, ignore, idx)
        if not t then break end
        segs[#segs + 1] = {p, vv, t, n}
        local e = (gaBase.Elasticity * gaBase.ElasticityWeight + props.Elasticity * props.ElasticityWeight) / (gaBase.ElasticityWeight + props.ElasticityWeight)
        local f = (gaBase.Friction * gaBase.FrictionWeight + props.Friction * props.FrictionWeight) / (gaBase.FrictionWeight + props.FrictionWeight)
        local k = 1 - math.abs(vv.Unit:Dot(n))
        local np, nv = gaPos(p, vv, t), gaVel(vv, t)
        vv = (-2 * nv:Dot(n) * n + nv) * e + vv * f * k
        p = np
        idx += 1
    end
    return segs
end
local function gaLanding(segs)
    local last = segs[#segs]
    if not last then return nil end
    return gaPos(last[1], last[2], last[3])
end

local function gaHeld()
    local vms = Workspace:FindFirstChild("Viewmodels")
    local lvm = vms and vms:FindFirstChild("LocalViewmodel")
    if not lvm then return nil end
    for _, c in ipairs(lvm:GetChildren()) do
        if c:IsA("Model") and c.Name:lower():find("grenade", 1, true) and c:FindFirstChild("Root") then return c end
    end
end

local gaFolder = Instance.new("Folder")
gaFolder.Name = HttpService:GenerateGUID(false)
local gaMarks, gaDots = {}, {}
local gaBusy = false
local function gaMark(i)
    local m = gaMarks[i]
    if m then return m end
    local part = Instance.new("Part")
    part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
    part.Shape = Enum.PartType.Ball
    part.Material = Enum.Material.Neon
    part.Size = Vector3.new(1.4, 1.4, 1.4)
    part.Transparency = 0.1
    local bb = Instance.new("BillboardGui", part)
    bb.AlwaysOnTop = true
    bb.Size = UDim2.fromOffset(250, 40)
    bb.StudsOffset = Vector3.new(0, 2.4, 0)
    bb.MaxDistance = 1200
    local fr = Instance.new("Frame", bb)
    fr.Size = UDim2.fromScale(1, 1)
    fr.BackgroundColor3 = Color3.fromRGB(8, 14, 14)
    fr.BackgroundTransparency = 0.15
    fr.BorderSizePixel = 0
    corner(fr, 8)
    local st = stroke(fr, Color3.fromRGB(80, 200, 120), 2, 0)
    local lab = Instance.new("TextLabel", fr)
    lab.Size = UDim2.new(1, -10, 1, 0)
    lab.Position = UDim2.fromOffset(6, 0)
    lab.BackgroundTransparency = 1
    lab.Font = Enum.Font.GothamBold
    lab.TextSize = 12
    lab.TextColor3 = Color3.new(1, 1, 1)
    lab.TextXAlignment = Enum.TextXAlignment.Left
    m = {part = part, st = st, lab = lab}
    gaMarks[i] = m
    return m
end
local function gaClear()
    for _, m in pairs(gaMarks) do m.part.Parent = nil end
    for _, d in pairs(gaDots) do d.Parent = nil end
end

local gaOrigin
local function gaCompute()
    if gaBusy then return end
    local cam = Workspace.CurrentCamera
    local held = gaHeld()
    if not (cam and held) then gaClear() gaOrigin = nil return end
    gaBusy = true
    local root = held.Root
    local nameL = held.Name:lower()
    local speed = nameL:find("impact", 1, true) and 75 or 60
    local bounces = nameL:find("impact", 1, true) and 0 or 1
    local vms = Workspace:FindFirstChild("Viewmodels")
    local ignore = {Workspace.Terrain}
    if LocalPlayer.Character then ignore[#ignore + 1] = LocalPlayer.Character end
    if vms then ignore[#ignore + 1] = vms end
    local origin = root.Position
    local camPos = cam.CFrame.Position

    -- nearest living enemies
    local enemies = {}
    for _, vm in ipairs(vms and vms:GetChildren() or {}) do
        if vm:IsA("Model") and vm.Name ~= "LocalViewmodel" and isAlive(vm) and not isFriendly(vm) then
            local torso = vm:FindFirstChild("torso")
            local d = (torso.Position - origin).Magnitude
            if torso and d >= 8 and d <= 130 then enemies[#enemies + 1] = {vm = vm, pos = torso.Position - Vector3.new(0, 2.4, 0), d = d} end
        end
    end
    table.sort(enemies, function(a, b) return a.d < b.d end)

    local results = {}
    for i = 1, math.min(#enemies, 3) do
        local e = enemies[i]
        local flat = Vector3.new(e.pos.X - origin.X, 0, e.pos.Z - origin.Z)
        if flat.Magnitude > 3 then
            flat = flat.Unit
            local best
            local function try(pitch)
                local p = math.rad(pitch)
                local dir = flat * math.cos(p) + Vector3.new(0, math.sin(p), 0)
                local segs = gaCast(root, origin, (dir + Vector3.new(0, 0.3, 0)) * speed, ignore, bounces)
                local land = gaLanding(segs)
                task.wait()
                if land then
                    local err = (land - e.pos).Magnitude
                    -- prefer flat throws: a steep lob only wins when it is clearly more accurate
                    local score = err + math.max(pitch, 0) * 0.2
                    if not best or score < best.score then best = {err = err, score = score, dir = dir, segs = segs, pitch = pitch} end
                end
            end
            for pitch = -15, 50, 4 do try(pitch) end
            if best then
                local c = best.pitch
                for pitch = c - 3, c + 3 do if pitch ~= c then try(pitch) end end
                best.name = ownerOf[e.vm] and ownerOf[e.vm].DisplayName or "enemy"
                best.dist = e.d
                results[#results + 1] = best
            end
        end
    end
    gaBusy = false
    if not gaHeld() or not Cfg.GrenadeAssist then gaClear() return end
    gaOrigin = camPos
    gaAim.pos = results[1] and (camPos + results[1].dir * 70) or nil
    gaAim.t = os.clock()
    if not Cfg.GrenadeMarkers then return end
    if gaFolder.Parent ~= cam then gaFolder.Parent = cam end
    for i = 1, 3 do
        local m = gaMark(i)
        local r = results[i]
        if r then
            m.part.Parent = gaFolder
            m.part.CFrame = CFrame.new(camPos + r.dir * 70)
            local good = r.err < 8
            local col = good and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(235, 195, 30)
            m.part.Color, m.st.Color = col, col
            m.lab.Text = string.format("%s → %s · %dm · lands %.0f away", held.Name, r.name, math.floor(r.dist), r.err)
        else
            m.part.Parent = nil
        end
    end
    -- path of the best throw
    for _, d in pairs(gaDots) do d.Parent = nil end
    if results[1] then
        local n = 0
        for _, seg in ipairs(results[1].segs) do
            for t = 0, seg[3], 0.1 do
                n += 1
                local d = gaDots[n]
                if not d then
                    d = Instance.new("Part")
                    d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
                    d.Shape = Enum.PartType.Ball
                    d.Material = Enum.Material.Neon
                    d.Size = Vector3.new(0.3, 0.3, 0.3)
                    d.Color = Color3.fromRGB(80, 200, 120)
                    gaDots[n] = d
                end
                d.CFrame = CFrame.new(gaPos(seg[1], seg[2], t))
                d.Parent = gaFolder
            end
        end
    end
end
local gaAcc = 0
connect(RunService.Heartbeat, function(dt)
    gaAim.held = Cfg.GrenadeAssist and gaHeld() ~= nil
    gaAcc += dt
    if gaAcc < 0.4 then return end
    gaAcc = 0
    local cam = Workspace.CurrentCamera
    if not Cfg.GrenadeAssist or not gaHeld() then
        gaAim.pos = nil
        if gaOrigin or next(gaMarks) then gaClear(); gaOrigin = nil end
        return
    end
    if gaOrigin and cam and (cam.CFrame.Position - gaOrigin).Magnitude > 3 then gaClear(); gaOrigin = nil end
    task.spawn(gaCompute)
end)
cleanups[#cleanups + 1] = function() pcall(function() gaClear(); gaFolder:Destroy() end) end

-- ---------------------------------------------------------------- UI
local C = {
    bg = Color3.fromRGB(8, 16, 16), panel = Color3.fromRGB(10, 22, 22), dark = Color3.fromRGB(6, 14, 14),
    teal = Color3.fromRGB(0, 188, 168), tealDim = Color3.fromRGB(0, 110, 100),
    text = Color3.fromRGB(180, 210, 205), dim = Color3.fromRGB(90, 130, 125), white = Color3.fromRGB(255, 255, 255),
}
local function tw(o, t, props, style, dir)
    local tween = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    tween:Play()
    return tween
end
local function corner(p, r) local c = Instance.new("UICorner", p); c.CornerRadius = UDim.new(0, r); return c end
local function stroke(p, col, t, tr)
    local s = Instance.new("UIStroke", p)
    s.Color, s.Thickness, s.Transparency = col, t, tr
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    return s
end

local ui = Instance.new("ScreenGui")
ui.Name = HttpService:GenerateGUID(false)
ui.ResetOnSpawn = false
ui.IgnoreGuiInset = true
ui.DisplayOrder = 50
ui.Parent = GuiParent

local main = Instance.new("CanvasGroup", ui)
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.fromScale(0.5, 0.5)
main.Size = UDim2.fromOffset(420, 580)
main.BackgroundColor3 = C.bg
main.BorderSizePixel = 0
main.GroupTransparency = 1
corner(main, 10)
local mainStroke = stroke(main, C.teal, 2, 0.2)
local grad = Instance.new("UIGradient", mainStroke)
grad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, C.teal), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 255, 235)), ColorSequenceKeypoint.new(1, C.teal)})
local scale = Instance.new("UIScale", main)
scale.Scale = 0.82

local top = Instance.new("Frame", main)
top.Size = UDim2.new(1, 0, 0, 44)
top.BackgroundColor3 = C.panel
top.BorderSizePixel = 0
local title = Instance.new("TextLabel", top)
title.Size = UDim2.new(1, -60, 1, 0)
title.Position = UDim2.fromOffset(16, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = C.white
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "KING HUB  ·  OPERATION ONE"
local sub = Instance.new("TextLabel", top)
sub.Size = UDim2.new(1, -60, 0, 12)
sub.Position = UDim2.fromOffset(16, 28)
sub.BackgroundTransparency = 1
sub.Font = Enum.Font.Gotham
sub.TextSize = 10
sub.TextColor3 = C.dim
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.Text = "press K to hide / show"
title.Size = UDim2.new(1, -60, 0, 24)
title.Position = UDim2.fromOffset(16, 3)

local closeBtn = Instance.new("TextButton", top)
closeBtn.Size = UDim2.fromOffset(30, 30)
closeBtn.Position = UDim2.new(1, -38, 0, 7)
closeBtn.BackgroundColor3 = C.dark
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 13
closeBtn.TextColor3 = C.text
closeBtn.AutoButtonColor = false
corner(closeBtn, 6)

local tabHold = Instance.new("Frame", main)
tabHold.Size = UDim2.new(0, 130, 1, -44)
tabHold.Position = UDim2.fromOffset(0, 44)
tabHold.BackgroundColor3 = C.panel
tabHold.BackgroundTransparency = 0.3
tabHold.BorderSizePixel = 0
local tl = Instance.new("UIListLayout", tabHold)
tl.Padding = UDim.new(0, 6)
local tp = Instance.new("UIPadding", tabHold)
tp.PaddingTop, tp.PaddingLeft, tp.PaddingRight = UDim.new(0, 10), UDim.new(0, 8), UDim.new(0, 8)
local pageHost = Instance.new("Frame", main)
pageHost.Size = UDim2.new(1, -24, 1, -56)
pageHost.Position = UDim2.fromOffset(12, 50)
tabHold.Visible = false
pageHost.BackgroundTransparency = 1

local tabs, activeTab = {}, nil
local order = 0
local function nextOrder() order += 1; return order end

local function selectTab(t)
    if activeTab == t then return end
    if activeTab then
        activeTab.page.Visible = false
        tw(activeTab.btn, 0.18, {BackgroundTransparency = 1})
        tw(activeTab.btn.Label, 0.18, {TextColor3 = C.dim})
    end
    activeTab = t
    t.page.Visible = true
    t.page.Position = UDim2.fromOffset(0, 10)
    tw(t.page, 0.28, {Position = UDim2.fromOffset(0, 0)})
    tw(t.btn, 0.18, {BackgroundTransparency = 0.7})
    tw(t.btn.Label, 0.18, {TextColor3 = C.teal})
end

local sharedPage
local function addTab(name)
    if not sharedPage then
        local page = Instance.new("ScrollingFrame", pageHost)
        page.Size = UDim2.fromScale(1, 1)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 3
        page.ScrollBarImageColor3 = C.teal
        page.CanvasSize = UDim2.new()
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        local lay = Instance.new("UIListLayout", page)
        lay.Padding = UDim.new(0, 4)
        sharedPage = page
    end
    local hd = Instance.new("TextLabel", sharedPage)
    hd.Size = UDim2.new(1, -8, 0, 26)
    hd.BackgroundTransparency = 1
    hd.Font = Enum.Font.GothamBold
    hd.TextSize = 11
    hd.TextColor3 = C.teal
    hd.TextXAlignment = Enum.TextXAlignment.Left
    hd.Text = "  " .. string.upper(name)
    hd.LayoutOrder = nextOrder()
    local line = Instance.new("Frame", hd)
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 1, -2)
    line.BackgroundColor3 = C.tealDim
    line.BackgroundTransparency = 0.5
    line.BorderSizePixel = 0
    do return {page = sharedPage} end
    local btn = Instance.new("TextButton", tabHold)
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = C.teal
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.LayoutOrder = nextOrder()
    corner(btn, 6)
    local lab = Instance.new("TextLabel", btn)
    lab.Name = "Label"
    lab.Size = UDim2.fromScale(1, 1)
    lab.BackgroundTransparency = 1
    lab.Font = Enum.Font.GothamMedium
    lab.TextSize = 13
    lab.TextColor3 = C.dim
    lab.Text = name
    local page = Instance.new("ScrollingFrame", pageHost)
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = C.teal
    page.CanvasSize = UDim2.new()
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    local lay = Instance.new("UIListLayout", page)
    lay.Padding = UDim.new(0, 6)
    local t = {btn = btn, page = page}
    tabs[#tabs + 1] = t
    btn.MouseButton1Click:Connect(function() selectTab(t) end)
    btn.MouseEnter:Connect(function() if activeTab ~= t then tw(btn, 0.1, {BackgroundTransparency = 0.9}) end end)
    btn.MouseLeave:Connect(function() if activeTab ~= t then tw(btn, 0.1, {BackgroundTransparency = 1}) end end)
    return t
end

local function row(t, h)
    local r = Instance.new("Frame", t.page)
    r.Size = UDim2.new(1, -8, 0, h or 40)
    r.BackgroundColor3 = C.dark
    r.BackgroundTransparency = 0.15
    r.BorderSizePixel = 0
    r.LayoutOrder = nextOrder()
    corner(r, 6)
    stroke(r, C.tealDim, 1, 0.85)
    return r
end
local function rowLabel(r, text)
    local l = Instance.new("TextLabel", r)
    l.Size = UDim2.new(1, -90, 1, 0)
    l.Position = UDim2.fromOffset(12, 0)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 12
    l.TextColor3 = C.text
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = text
    return l
end

local function addToggle(t, text, key)
    local r = row(t, 32)
    rowLabel(r, text)
    local bg = Instance.new("TextButton", r)
    bg.Size = UDim2.fromOffset(44, 22)
    bg.Position = UDim2.new(1, -56, 0.5, -11)
    bg.Text = ""
    bg.AutoButtonColor = false
    corner(bg, 11)
    local knob = Instance.new("Frame", bg)
    knob.Size = UDim2.fromOffset(16, 16)
    knob.BackgroundColor3 = C.white
    knob.BorderSizePixel = 0
    corner(knob, 8)
    local function render(animated)
        local on = Cfg[key]
        local p1 = {BackgroundColor3 = on and C.teal or Color3.fromRGB(24, 45, 45)}
        local p2 = {Position = on and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3)}
        if animated then tw(bg, 0.18, p1); tw(knob, 0.18, p2, Enum.EasingStyle.Back)
        else bg.BackgroundColor3 = p1.BackgroundColor3; knob.Position = p2.Position end
    end
    render(false)
    refreshers[#refreshers + 1] = function() render(false) end
    bg.MouseButton1Click:Connect(function() Cfg[key] = not Cfg[key]; render(true) end)
end

local function addSlider(t, text, key, lo, hi, fmt)
    local r = row(t, 44)
    local lab = rowLabel(r, text)
    lab.Size = UDim2.new(1, -90, 0, 24)
    local val = Instance.new("TextLabel", r)
    val.Size = UDim2.fromOffset(80, 24)
    val.Position = UDim2.new(1, -92, 0, 0)
    val.BackgroundTransparency = 1
    val.Font = Enum.Font.GothamBold
    val.TextSize = 12
    val.TextColor3 = C.teal
    val.TextXAlignment = Enum.TextXAlignment.Right
    local track = Instance.new("Frame", r)
    track.Size = UDim2.new(1, -24, 0, 6)
    track.Position = UDim2.new(0, 12, 0, 30)
    track.BackgroundColor3 = Color3.fromRGB(24, 45, 45)
    track.BorderSizePixel = 0
    corner(track, 3)
    local fill = Instance.new("Frame", track)
    fill.BackgroundColor3 = C.teal
    fill.BorderSizePixel = 0
    corner(fill, 3)
    local function setFromAlpha(a)
        a = math.clamp(a, 0, 1)
        Cfg[key] = lo + (hi - lo) * a
        fill.Size = UDim2.fromScale(a, 1)
        val.Text = fmt and fmt(Cfg[key]) or tostring(math.floor(Cfg[key]))
    end
    setFromAlpha((Cfg[key] - lo) / (hi - lo))
    refreshers[#refreshers + 1] = function() setFromAlpha((Cfg[key] - lo) / (hi - lo)) end
    local dragging = false
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromAlpha((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X)
        end
    end)
    connect(UserInputService.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            setFromAlpha((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X)
        end
    end)
    connect(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

local function addCycle(t, text, key, list)
    local r = row(t, 32)
    local btn = Instance.new("TextButton", r)
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    btn.TextColor3 = C.text
    btn.AutoButtonColor = false
    local function render() btn.Text = text .. ": " .. list[Cfg[key]][1] end
    render()
    refreshers[#refreshers + 1] = render
    btn.MouseButton1Click:Connect(function() Cfg[key] = Cfg[key] % #list + 1; render() end)
    btn.MouseEnter:Connect(function() tw(r, 0.1, {BackgroundTransparency = 0.02}) end)
    btn.MouseLeave:Connect(function() tw(r, 0.1, {BackgroundTransparency = 0.15}) end)
end

local function addButton(t, text, cb, col)
    local r = row(t, 32)
    r.BackgroundColor3 = col or C.dark
    local btn = Instance.new("TextButton", r)
    btn.Size = UDim2.fromScale(1, 1)
    btn.BackgroundTransparency = 1
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    btn.TextColor3 = C.text
    btn.Text = text
    btn.AutoButtonColor = false
    btn.MouseButton1Click:Connect(function() pcall(cb) end)
    btn.MouseEnter:Connect(function() tw(r, 0.1, {BackgroundTransparency = 0.02}) end)
    btn.MouseLeave:Connect(function() tw(r, 0.1, {BackgroundTransparency = 0.15}) end)
end

-- tabs
local tEsp = addTab("ESP")
addToggle(tEsp, "Box ESP", "Box")
addToggle(tEsp, "Names", "Names")
addToggle(tEsp, "Distance", "Distance")
addToggle(tEsp, "Health bar", "HealthBar")
addToggle(tEsp, "Enemy highlight (see through walls)", "Highlight")
addToggle(tEsp, "Team check", "TeamCheck")
addToggle(tEsp, "Show dead", "ShowDead")
addCycle(tEsp, "Box colour", "BoxColor", BOX_COLORS)
addCycle(tEsp, "Box style", "BoxMode", {{"Full"}, {"Corner"}})
addToggle(tEsp, "Skeleton", "Skeleton")
addToggle(tEsp, "Tracers (pink)", "Tracers")
addToggle(tEsp, "Box turns green when visible", "VisTint")
addSlider(tEsp, "Max distance", "MaxDist", 100, 2000, function(v) return string.format("%dm", math.floor(v)) end)

local tCmb = addTab("Combat")
addToggle(tCmb, "Aimbot (hold fire or aim)", "Aim")
addSlider(tCmb, "Aimbot radius (screen px)", "AimFov", 20, 600, function(v) return string.format("%dpx", math.floor(v)) end)
addSlider(tCmb, "Aimbot range (studs)", "AimRange", 20, 800, function(v) return string.format("%d studs", math.floor(v)) end)
addSlider(tCmb, "Aimbot strength", "AimSmooth", 0.1, 1, function(v) return string.format("%d%%", math.floor(v * 100)) end)
addSlider(tCmb, "Aimbot max speed", "AimMaxStep", 10, 300, function(v) return string.format("%d", math.floor(v)) end)
addCycle(tCmb, "Aimbot aims at", "AimPart", SILENT_PARTS)
addToggle(tCmb, "Aimbot radius ring (pink)", "AimCircle")
addToggle(tCmb, "Aimbot line to target (pink)", "AimLine")
addSlider(tCmb, "Aimbot humanization", "AimHuman", 0, 100, function(v) return string.format("%d%%", math.floor(v)) end)
addToggle(tCmb, "Aimbot stays on its target", "AimSticky")
addToggle(tCmb, "Aimbot needs line of sight", "AimVisible")
addToggle(tCmb, "Silent aim (locks on when an enemy is close)", "Silent")
addSlider(tCmb, "Lock radius (screen px)", "SilentFov", 20, 700, function(v) return string.format("%dpx", math.floor(v)) end)
addSlider(tCmb, "Lock range (studs)", "SilentRange", 20, 600, function(v) return string.format("%d studs", math.floor(v)) end)
addCycle(tCmb, "Aim at", "SilentPart", SILENT_PARTS)
addToggle(tCmb, "Silent aim needs line of sight", "SilentVisible")
addToggle(tCmb, "Triggerbot fires when silent aim locks on", "TriggerOnLock")
addToggle(tCmb, "Shoot through barricades (triggerbot + silent aim)", "Barricades")
addToggle(tCmb, "Also shoot through thin walls (under 1.45 studs)", "ThinWalls")
addToggle(tCmb, "Triggerbot: head only", "TriggerHeadOnly")
addToggle(tCmb, "Grenade assist (works out the throw angle)", "GrenadeAssist")
addToggle(tCmb, "Grenade lock-on (hold fire or aim with a grenade)", "GrenadeLock")
addToggle(tCmb, "Grenade markers (floating balls, off by default)", "GrenadeMarkers")
addToggle(tCmb, "No recoil", "NoRecoil")
addSlider(tCmb, "Recoil control strength (no-actor executors)", "RecoilStrength", 0, 150, function(v) return string.format("%d%%", math.floor(v)) end)
addToggle(tCmb, "Triggerbot", "Trigger")
addToggle(tCmb, "Wall check (don't shoot through walls)", "TriggerWallCheck")
addSlider(tCmb, "Fire delay", "TriggerDelay", 0, 0.5, function(v) return string.format("%.2fs", v) end)
addSlider(tCmb, "Max range", "TriggerRange", 50, 2000, function(v) return string.format("%dm", math.floor(v)) end)

local tCh = addTab("Chams")
addToggle(tCh, "Gun chams", "Chams")
addCycle(tCh, "Colour", "ChamsColor", CHAMS_COLORS)
addSlider(tCh, "Transparency", "ChamsTrans", 0, 1, function(v) return string.format("%d%%", math.floor(v * 100)) end)
addToggle(tCh, "Pulse", "ChamsPulse")

addToggle(tCmb, "Quick peek (double-tap Q or E)", "Peek")
addSlider(tCmb, "Quick peek: tap speed", "PeekTap", 0.1, 0.6, function(v) return string.format("%.2fs", v) end)
addSlider(tCmb, "Quick peek: time out", "PeekTime", 0.1, 0.8, function(v) return string.format("%.2fs", v) end)

local tWorld = addTab("World")
addToggle(tWorld, "Custom FOV", "Fov")
addSlider(tWorld, "FOV value", "FovValue", 50, 120, function(v) return string.format("%d", math.floor(v)) end)
addToggle(tWorld, "Fullbright", "Fullbright")
addToggle(tWorld, "No fog", "NoFog")

local tMisc = addTab("Misc")
addToggle(tMisc, "Watermark", "Watermark")
addButton(tMisc, "Save config", function() writefile(CFG_FILE, HttpService:JSONEncode(Cfg)); log("config saved") end)
addButton(tMisc, "Load config", function()
    local saved = HttpService:JSONDecode(readfile(CFG_FILE))
    for k, v in pairs(saved) do if Cfg[k] ~= nil and type(Cfg[k]) == type(v) then Cfg[k] = v end end
    for _, fn in ipairs(refreshers) do pcall(fn) end
    log("config loaded")
end)
addButton(tMisc, "Unload script", function() if getgenv then pcall(getgenv().OP1_RUNNING) end end, Color3.fromRGB(60, 16, 16))

-- open animation, drag, hide / show
tw(main, 0.45, {GroupTransparency = 0}, Enum.EasingStyle.Quad)
tw(scale, 0.5, {Scale = 1}, Enum.EasingStyle.Back)
local spin = 0
connect(RunService.RenderStepped, function(dt) spin = (spin + dt * 60) % 360; grad.Rotation = spin end)

local dragging, dragStart, startPos
top.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging, dragStart, startPos = true, i.Position, main.Position
    end
end)
connect(UserInputService.InputChanged, function(i)
    if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
connect(UserInputService.InputEnded, function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

local shown = true
local function setShown(v)
    shown = v
    if v then
        main.Visible = true
        tw(main, 0.25, {GroupTransparency = 0}); tw(scale, 0.3, {Scale = 1}, Enum.EasingStyle.Back)
    else
        tw(main, 0.2, {GroupTransparency = 1}); tw(scale, 0.2, {Scale = 0.9})
        task.delay(0.22, function() if not shown then main.Visible = false end end)
    end
end
connect(UserInputService.InputBegan, function(i, gp)
    if not gp and (i.KeyCode == Enum.KeyCode.K or i.KeyCode == Enum.KeyCode.RightShift) then setShown(not shown) end
end)
closeBtn.MouseButton1Click:Connect(function() setShown(false) end)
closeBtn.MouseEnter:Connect(function() tw(closeBtn, 0.1, {BackgroundColor3 = Color3.fromRGB(120, 30, 30)}) end)
closeBtn.MouseLeave:Connect(function() tw(closeBtn, 0.1, {BackgroundColor3 = C.dark}) end)

-- unload
local function unload()
    Cfg.NoRecoil = false
    pcall(applyNoRecoil)
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    for _, fn in ipairs(cleanups) do pcall(fn) end
    for vm in pairs(entries) do dropEntry(vm) end
    killChams()
    pcall(function() espGui:Destroy() end)
    pcall(function() ui:Destroy() end)
    logAlive = false
    if getgenv then getgenv().OP1_RUNNING = nil end
end
if getgenv then getgenv().OP1_RUNNING = unload; getgenv().KING_UNLOADERS.op1 = unload end
log("ready")
