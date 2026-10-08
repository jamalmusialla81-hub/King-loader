-- =============================================================================
--  PHANTOM FORCES  ·  box ESP, triggerbot, mouse lock-on
--  Display + mouse input only. Nothing is sent to the server and no game code is hooked.
--  Phantom Forces renames everything and has no Roblox characters, so players are read from
--  workspace.Players.<team folder>.<model>: the NameTagGui / PlayerTag label gives the name and the
--  part it hangs on is the head. Models are rebuilt constantly, so nothing is cached by reference.
--  K (or RightShift) hides / shows the menu.
-- =============================================================================
local Players          = game:GetService("Players")      -- never game.Players here: the service is renamed
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")
local HttpService      = game:GetService("HttpService")
local LocalPlayer      = Players.LocalPlayer
local camera           = workspace.CurrentCamera
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() if workspace.CurrentCamera then camera = workspace.CurrentCamera end end)

if getgenv and getgenv().PF_RUNNING then pcall(getgenv().PF_RUNNING) end

-- only one KING script runs at a time: loading this one unloads any other that is active
do
    local g = getgenv and getgenv() or _G
    g.KING_UNLOADERS = g.KING_UNLOADERS or {}
    for k, fn in pairs(g.KING_UNLOADERS) do
        if k ~= "pf" then pcall(fn) end
        g.KING_UNLOADERS[k] = nil
    end
end

-- ---------------------------------------------------------------- log
pcall(function() if makefolder and not (isfolder and isfolder("king_hub")) then makefolder("king_hub") end end)
local LOGFILE = "king_hub/pf_log.txt"
local logBuf, t0, logAlive = {}, os.clock(), true
local function log(msg) logBuf[#logBuf + 1] = string.format("[+%6.1fs] %s", os.clock() - t0, tostring(msg)) end
pcall(function() writefile(LOGFILE, "phantom forces log\n") end)
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

local GuiParent = CoreGui
pcall(function() if gethui then GuiParent = gethui() end end)

local Cfg = {
    Box = true, Names = true, Distance = true, HeadDot = true, MaxDist = 1000,
    Trigger = true, TriggerGlass = true, TriggerWallbang = false, TriggerDelay = 0.0, TriggerRange = 1000, TriggerWallCheck = true, TriggerHeadOnly = false,
    Aim = true, AimFov = 180, AimRange = 250, AimSmooth = 0.35, AimVisible = true, AimHuman = 70,
    AimPart = 1, AimSticky = true, AimMaxStep = 40,
    -- esp extras
    BoxMode = 1, BoxColor = 1, NameColor = 3, DistColor = 3, EspVisOnly = false, VisTint = true,
    Chams = false, ChamsColor = 1, ChamsFill = 0.6,
    -- viewmodel / weapon chams
    VM = false, VMColor = 2, VMMat = 1, VMTrans = 0.3,
    WP = false, WPColor = 1, WPMat = 1, WPTrans = 0.3,
    -- world
    Fov = false, FovValue = 90, Fullbright = false, NoFog = false, NoGrass = false,
    CustomTime = false, TimeValue = 12, CustomAmbient = false, AmbientColor = 7,
    Watermark = true, AimCircle = true, AimLine = true, Tracers = true,
}
local PALETTE = {
    {"Red", Color3.fromRGB(255, 60, 60)}, {"Teal", Color3.fromRGB(0, 188, 168)}, {"White", Color3.fromRGB(255, 255, 255)},
    {"Yellow", Color3.fromRGB(255, 230, 80)}, {"Green", Color3.fromRGB(80, 255, 110)}, {"Blue", Color3.fromRGB(70, 130, 255)},
    {"Purple", Color3.fromRGB(170, 90, 255)}, {"Pink", Color3.fromRGB(255, 110, 200)},
}
local MATERIALS = {
    {"ForceField", Enum.Material.ForceField}, {"Neon", Enum.Material.Neon}, {"Glass", Enum.Material.Glass},
    {"SmoothPlastic", Enum.Material.SmoothPlastic}, {"Metal", Enum.Material.Metal}, {"Ice", Enum.Material.Ice}, {"Foil", Enum.Material.Foil},
}
local refreshers = {}
local CFG_FILE = "king_hub/pf_config.json"
pcall(function()
    if isfile and isfile(CFG_FILE) then
        local saved = HttpService:JSONDecode(readfile(CFG_FILE))
        for k, v in pairs(saved) do if Cfg[k] ~= nil and type(Cfg[k]) == type(v) then Cfg[k] = v end end
    end
end)
local connections, cleanups = {}, {}
local function connect(sig, fn) local c = sig:Connect(fn); connections[#connections + 1] = c; return c end

-- ---------------------------------------------------------------- reading players
local function playersFolder() return workspace:FindFirstChild("Players") end

-- returns list of enemies {model, name, head(BasePart)} and whether my own team folder was found
local lastSnapLog = 0
local function snapshot()
    local folder = playersFolder()
    if not folder then return {}, false end
    local found, mine = {}, nil
    -- Your own character is not in this list in first person, so the name tag never finds you.
    -- The team folders are named after the teams, so match them to your Team / TeamColor instead.
    local myNames = {}
    pcall(function() if LocalPlayer.Team then myNames[LocalPlayer.Team.Name] = true end end)
    pcall(function() myNames[LocalPlayer.TeamColor.Name] = true end)
    local counts = {}
    for _, teamFolder in ipairs(folder:GetChildren()) do
        if myNames[teamFolder.Name] then mine = teamFolder end
        counts[#counts + 1] = teamFolder.Name .. "=" .. #teamFolder:GetChildren()
        for _, model in ipairs(teamFolder:GetChildren()) do
            if model:IsA("Model") then
                local gui = model:FindFirstChild("NameTagGui", true)
                local label = gui and gui:FindFirstChild("PlayerTag", true)
                local holder = gui and (gui.Adornee or gui.Parent)
                if label and holder and holder:IsA("BasePart") then
                    local name = label.Text
                    if name == LocalPlayer.Name or name == LocalPlayer.DisplayName then
                        mine = teamFolder
                    else
                        found[#found + 1] = {model = model, folder = teamFolder, name = name, head = holder}
                    end
                end
            end
        end
    end
    -- The team folders have random names, so they can't be matched to your team. Instead each model is matched to
    -- its player by name tag, and that player's Team / TeamColor is compared with yours.
    local byName = {}
    for _, p in ipairs(Players:GetPlayers()) do byName[p.Name] = p; byName[p.DisplayName] = p end
    local hits, friendlies = 0, 0
    for _, e in ipairs(found) do
        local p = byName[e.name]
        if p and p ~= LocalPlayer then
            hits += 1
            local same = false
            pcall(function()
                same = (LocalPlayer.Team ~= nil and p.Team == LocalPlayer.Team) or p.TeamColor == LocalPlayer.TeamColor
            end)
            e.friendly = same
            if same then friendlies += 1; mine = mine or e.folder end
        end
    end
    local enemies = {}
    for _, e in ipairs(found) do
        if e.friendly == false or (e.friendly == nil and (not mine or e.folder ~= mine)) then enemies[#enemies + 1] = e end
    end
    if os.clock() - lastSnapLog > 5 then
        lastSnapLog = os.clock()
        local names = {}
        for n in pairs(myNames) do names[#names + 1] = n end
        log(string.format("snapshot: %d models seen (%d matched to players, %d teammates), %d enemies, own team %s | folders: %s | my team names: %s",
            #found, hits, friendlies, #enemies, mine and mine.Name or "NOT found (everyone treated as enemy)", table.concat(counts, ", "), table.concat(names, "/")))
    end
    return enemies, mine ~= nil
end

local function projectBox(cf, size)
    local half = size / 2
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local any = false
    for _, sx in ipairs({-1, 1}) do
        for _, sy in ipairs({-1, 1}) do
            for _, sz in ipairs({-1, 1}) do
                local s = camera:WorldToViewportPoint(cf:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)))
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

-- nothing solid between the camera and a point (player models are ignored).
-- passMats: set of Enum.Material that count as "see-through" for this check (glass, or thin wallbang materials).
local function worldClear(targetPos, passMats)
    local ignore = {camera}
    local pf = playersFolder()
    if pf then ignore[#ignore + 1] = pf end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.IgnoreWater = true
    local origin = camera.CFrame.Position
    for _ = 1, 10 do
        rp.FilterDescendantsInstances = ignore
        local hit = workspace:Raycast(origin, targetPos - origin, rp)
        if not hit then return true end
        local part = hit.Instance
        if passMats and (passMats[part.Material] or (passMats[Enum.Material.Glass] and part.Transparency >= 0.5)) then
            ignore[#ignore + 1] = part       -- pass through this part and keep looking
        else
            return false
        end
    end
    return false
end
local GLASS_MATS = {[Enum.Material.Glass] = true}
local WALLBANG_MATS = {
    [Enum.Material.Glass] = true, [Enum.Material.Wood] = true, [Enum.Material.WoodPlanks] = true,
    [Enum.Material.Plastic] = true, [Enum.Material.SmoothPlastic] = true, [Enum.Material.Fabric] = true, [Enum.Material.Ice] = true,
}

-- ---------------------------------------------------------------- box ESP
local espGui = Instance.new("ScreenGui")
espGui.Name = HttpService:GenerateGUID(false)
espGui.ResetOnSpawn = false
espGui.IgnoreGuiInset = true
espGui.Parent = GuiParent
local entries = {}                          -- keyed by player NAME (models are rebuilt too often to key by model)
local function makeEntry(name)
    local f = Instance.new("Frame", espGui)
    f.BackgroundTransparency = 1
    f.BorderSizePixel = 0
    f.Visible = false
    local st = Instance.new("UIStroke", f)
    st.Thickness = 1.6
    st.Color = Color3.fromRGB(255, 60, 60)
    st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    local lab = Instance.new("TextLabel", f)
    lab.Size = UDim2.new(1, 60, 0, 14)
    lab.Position = UDim2.new(0, -30, 0, -16)
    lab.BackgroundTransparency = 1
    lab.Font = Enum.Font.GothamBold
    lab.TextSize = 13
    lab.TextColor3 = Color3.new(1, 1, 1)
    lab.TextStrokeTransparency = 0.3
    local dist = Instance.new("TextLabel", f)
    dist.Size = UDim2.new(1, 60, 0, 12)
    dist.Position = UDim2.new(0, -30, 1, 2)
    dist.BackgroundTransparency = 1
    dist.Font = Enum.Font.Gotham
    dist.TextSize = 11
    dist.TextColor3 = Color3.fromRGB(190, 190, 190)
    dist.TextStrokeTransparency = 0.3
    local dot = Instance.new("Frame", espGui)
    dot.Size = UDim2.fromOffset(6, 6)
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.BackgroundColor3 = Color3.fromRGB(255, 230, 80)
    dot.BorderSizePixel = 0
    dot.Visible = false
    local corners = {}
    for i = 1, 8 do
        local c = Instance.new("Frame", espGui)
        c.BorderSizePixel = 0
        c.Visible = false
        corners[i] = c
    end
    local hl = Instance.new("Highlight")
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Enabled = false
    hl.Parent = espGui
    local tracer = Instance.new("Frame", espGui)
    tracer.AnchorPoint = Vector2.new(0.5, 0.5)
    tracer.BackgroundColor3 = Color3.fromRGB(255, 92, 190)
    tracer.BorderSizePixel = 0
    tracer.Visible = false
    local e = {frame = f, stroke = st, name = lab, dist = dist, dot = dot, corners = corners, hl = hl, tracer = tracer}
    entries[name] = e
    return e
end
local function hideEntry(en)
    en.frame.Visible = false
    en.tracer.Visible = false
    en.dot.Visible = false
    en.hl.Enabled = false
    for _, c in ipairs(en.corners) do c.Visible = false end
end
local function drawCorners(en, x0, y0, x1, y1, col)
    local len = math.max(6, math.min(x1 - x0, y1 - y0) * 0.25)
    local t = 2
    local segs = {
        {x0, y0, len, t}, {x0, y0, t, len}, {x1 - len, y0, len, t}, {x1 - t, y0, t, len},
        {x0, y1 - t, len, t}, {x0, y1 - len, t, len}, {x1 - len, y1 - t, len, t}, {x1 - t, y1 - len, t, len},
    }
    for i, s in ipairs(segs) do
        local c = en.corners[i]
        c.Position = UDim2.fromOffset(s[1], s[2])
        c.Size = UDim2.fromOffset(s[3], s[4])
        c.BackgroundColor3 = col
        c.Visible = true
    end
end

local cachedEnemies = {}
connect(RunService.RenderStepped, function()
    local enemies = snapshot()
    cachedEnemies = enemies
    local seen = {}
    if camera then
        for _, e in ipairs(enemies) do
            local ok, cf, size = pcall(function() return e.model:GetBoundingBox() end)
            if ok and cf then
                local distance = (camera.CFrame.Position - cf.Position).Magnitude
                if distance <= Cfg.MaxDist then
                    local x0, y0, x1, y1 = projectBox(cf, size)
                    local en = entries[e.name] or makeEntry(e.name)
                    local visible = true
                    if Cfg.EspVisOnly or Cfg.VisTint then visible = worldClear(e.head.Position) end
                    if x0 and (visible or not Cfg.EspVisOnly) then
                        local boxCol = PALETTE[Cfg.BoxColor][2]
                        if Cfg.VisTint and visible then boxCol = Color3.fromRGB(80, 255, 110) end
                        en.frame.Position = UDim2.fromOffset(x0, y0)
                        en.frame.Size = UDim2.fromOffset(x1 - x0, y1 - y0)
                        en.frame.Visible = true
                        en.stroke.Color = boxCol
                        if Cfg.Tracers then
                            local vp = camera.ViewportSize
                            local a, b = Vector2.new(vp.X / 2, vp.Y), Vector2.new((x0 + x1) / 2, y1)
                            local d = b - a
                            en.tracer.Size = UDim2.fromOffset(d.Magnitude, 1.5)
                            en.tracer.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
                            en.tracer.Rotation = math.deg(math.atan2(d.Y, d.X))
                            en.tracer.Visible = true
                        else en.tracer.Visible = false end
                        en.stroke.Enabled = Cfg.Box and Cfg.BoxMode == 1
                        if Cfg.Box and Cfg.BoxMode == 2 then
                            drawCorners(en, x0, y0, x1, y1, boxCol)
                        else
                            for _, c in ipairs(en.corners) do c.Visible = false end
                        end
                        en.name.Visible = Cfg.Names
                        en.name.TextColor3 = PALETTE[Cfg.NameColor][2]
                        en.name.Text = e.name
                        en.dist.Visible = Cfg.Distance
                        en.dist.TextColor3 = PALETTE[Cfg.DistColor][2]
                        en.dist.Text = string.format("[ %dm ]", math.floor(distance))
                        local hs, on = camera:WorldToViewportPoint(e.head.Position)
                        en.dot.Visible = Cfg.HeadDot and on and hs.Z > 0
                        en.dot.Position = UDim2.fromOffset(hs.X, hs.Y)
                        if Cfg.Chams then
                            en.hl.Adornee = e.model
                            en.hl.FillColor = PALETTE[Cfg.ChamsColor][2]
                            en.hl.OutlineColor = PALETTE[Cfg.ChamsColor][2]
                            en.hl.FillTransparency = Cfg.ChamsFill
                            en.hl.Enabled = true
                        else
                            en.hl.Enabled = false
                        end
                    else
                        hideEntry(en)
                    end
                    seen[e.name] = true
                end
            end
        end
    end
    for name, en in pairs(entries) do
        if not seen[name] then hideEntry(en) end
    end
end)

-- ---------------------------------------------------------------- viewmodel / weapon chams
-- The viewmodel (arms + gun) lives under the camera. The arms model has a child called "Sleeves".
-- Original colors / materials are remembered so turning it off puts everything back.
local savedArm, savedWp = {}, {}
local function restoreSaved(saved)
    for p, v in pairs(saved) do
        pcall(function() p.Color, p.Material, p.Transparency = v[1], v[2], v[3] end)
        saved[p] = nil
    end
end
local function paintModel(model, saved, colIdx, matIdx, trans)
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            if not saved[p] then saved[p] = {p.Color, p.Material, p.Transparency} end
            if saved[p][3] < 0.99 then
                p.Color, p.Material, p.Transparency = PALETTE[colIdx][2], MATERIALS[matIdx][2], trans
            end
        end
    end
end
local lastVm, armWas, wpWas = 0, false, false
connect(RunService.Heartbeat, function()
    if os.clock() - lastVm < 0.15 or not camera then return end
    lastVm = os.clock()
    pcall(function()
        for _, m in ipairs(camera:GetChildren()) do
            if m:IsA("Model") or m:IsA("Folder") then
                local isArm = m:FindFirstChild("Sleeves") ~= nil
                if isArm and Cfg.VM then paintModel(m, savedArm, Cfg.VMColor, Cfg.VMMat, Cfg.VMTrans)
                elseif not isArm and Cfg.WP then paintModel(m, savedWp, Cfg.WPColor, Cfg.WPMat, Cfg.WPTrans) end
            end
        end
        if armWas and not Cfg.VM then restoreSaved(savedArm) end
        if wpWas and not Cfg.WP then restoreSaved(savedWp) end
        armWas, wpWas = Cfg.VM, Cfg.WP
    end)
end)
cleanups[#cleanups + 1] = function() restoreSaved(savedArm); restoreSaved(savedWp) end

-- ---------------------------------------------------------------- world / camera
local Lighting = game:GetService("Lighting")
local origLight = {
    Brightness = Lighting.Brightness, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
    ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, GlobalShadows = Lighting.GlobalShadows,
}
local atmos = {}
local function restoreLight(...)
    for _, k in ipairs({...}) do pcall(function() Lighting[k] = origLight[k] end) end
end
local wasOn = {}
local function feature(name, on, applyFn, restoreFn)
    if on then applyFn(); wasOn[name] = true
    elseif wasOn[name] then restoreFn(); wasOn[name] = false end
end
local origFov
connect(RunService.RenderStepped, function()
    pcall(function()
        feature("fb", Cfg.Fullbright, function()
            Lighting.Brightness = 2; Lighting.GlobalShadows = false
            if not Cfg.CustomAmbient then Lighting.Ambient = Color3.fromRGB(190, 190, 190); Lighting.OutdoorAmbient = Color3.fromRGB(190, 190, 190) end
        end, function() restoreLight("Brightness", "GlobalShadows", "Ambient", "OutdoorAmbient") end)
        feature("fog", Cfg.NoFog, function()
            Lighting.FogEnd, Lighting.FogStart = 1e6, 1e6
            for _, a in ipairs(Lighting:GetChildren()) do
                if a:IsA("Atmosphere") then if atmos[a] == nil then atmos[a] = a.Density end; a.Density = 0 end
            end
        end, function()
            restoreLight("FogEnd", "FogStart")
            for a, d in pairs(atmos) do pcall(function() a.Density = d end); atmos[a] = nil end
        end)
        feature("time", Cfg.CustomTime, function() Lighting.ClockTime = Cfg.TimeValue end, function() restoreLight("ClockTime") end)
        feature("amb", Cfg.CustomAmbient, function()
            Lighting.Ambient = PALETTE[Cfg.AmbientColor][2]; Lighting.OutdoorAmbient = PALETTE[Cfg.AmbientColor][2]
        end, function() restoreLight("Ambient", "OutdoorAmbient") end)
        feature("grass", Cfg.NoGrass, function() workspace.Terrain.Decoration = false end, function() workspace.Terrain.Decoration = true end)
        feature("fov", Cfg.Fov, function()
            origFov = origFov or camera.FieldOfView
            camera.FieldOfView = Cfg.FovValue
        end, function() if origFov then camera.FieldOfView = origFov end; origFov = nil end)
    end)
end)
cleanups[#cleanups + 1] = function()
    restoreLight("Brightness", "Ambient", "OutdoorAmbient", "ClockTime", "FogEnd", "FogStart", "GlobalShadows")
    for a, d in pairs(atmos) do pcall(function() a.Density = d end) end
    pcall(function() workspace.Terrain.Decoration = true end)
    pcall(function() if origFov then camera.FieldOfView = origFov end end)
end

-- ---------------------------------------------------------------- watermark
local wm = Instance.new("TextLabel", espGui)
wm.Position = UDim2.fromOffset(12, 10)
wm.Size = UDim2.fromOffset(320, 18)
wm.BackgroundTransparency = 1
wm.Font = Enum.Font.GothamBold
wm.TextSize = 13
wm.TextColor3 = Color3.fromRGB(0, 188, 168)
wm.TextStrokeTransparency = 0.4
wm.TextXAlignment = Enum.TextXAlignment.Left
local fpsAvg, lastWm = 60, 0
connect(RunService.RenderStepped, function(dt)
    fpsAvg = fpsAvg + (1 / math.max(dt, 1e-3) - fpsAvg) * 0.05
    wm.Visible = Cfg.Watermark
    if Cfg.Watermark and os.clock() - lastWm > 0.5 then
        lastWm = os.clock()
        wm.Text = string.format("KING HUB  |  Phantom Forces  |  %d fps  |  %d enemies  |  %s", math.floor(fpsAvg), #cachedEnemies, os.date("%H:%M"))
    end
end)

-- ---------------------------------------------------------------- triggerbot + mouse lock-on
local holding, acquiredAt = false, nil
local clickMode
local function press()
    if holding then return end
    holding = true
    if mouse1press then pcall(mouse1press); clickMode = clickMode or "mouse1press"
    else pcall(function()
        local vim = game:GetService("VirtualInputManager")
        local m = UserInputService:GetMouseLocation()
        vim:SendMouseButtonEvent(m.X, m.Y, 0, true, game, 0)
    end); clickMode = clickMode or "VirtualInputManager" end
end
local function release()
    if not holding then return end
    holding = false
    if mouse1release then pcall(mouse1release)
    else pcall(function()
        local vim = game:GetService("VirtualInputManager")
        local m = UserInputService:GetMouseLocation()
        vim:SendMouseButtonEvent(m.X, m.Y, 0, false, game, 0)
    end) end
end
cleanups[#cleanups + 1] = release

local function onCrosshair(e)
    local c = camera.ViewportSize / 2
    local hp, on = camera:WorldToViewportPoint(e.head.Position)
    if on and hp.Z > 0 and hp.Z <= Cfg.TriggerRange then
        local r = math.max(6, (e.head.Size.Magnitude * 0.6) / hp.Z * camera.ViewportSize.Y / (2 * math.tan(math.rad(camera.FieldOfView / 2))))
        if (Vector2.new(hp.X, hp.Y) - c).Magnitude <= r then return true, e.head.Position end
    end
    if not Cfg.TriggerHeadOnly then
        local ok, cf, size = pcall(function() return e.model:GetBoundingBox() end)
        if ok and cf and (cf.Position - camera.CFrame.Position).Magnitude <= Cfg.TriggerRange then
            local x0, y0, x1, y1 = projectBox(cf, size)
            if x0 then
                local w, h = x1 - x0, y1 - y0
                if c.X > x0 + w * 0.2 and c.X < x1 - w * 0.2 and c.Y > y0 and c.Y < y0 + h * 0.75 then return true, e.head.Position end
            end
        end
    end
    return false
end

local lastTrigLog = 0
connect(RunService.Heartbeat, function()
    if not Cfg.Trigger then release(); acquiredAt = nil return end
    if UserInputService:GetFocusedTextBox() then release() return end
    local target
    for _, e in ipairs(cachedEnemies) do
        local hit, aimPos = onCrosshair(e)
        if hit then
            -- glass is always see-through; wallbang materials only count while the fire button is held
            local mats = (Cfg.TriggerWallbang and not holding and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)) and WALLBANG_MATS
                or (Cfg.TriggerGlass and GLASS_MATS) or nil
            if not Cfg.TriggerWallCheck or worldClear(aimPos, mats) then target = e break end
        end
    end
    if os.clock() - lastTrigLog > 3 then
        lastTrigLog = os.clock()
        log(string.format("trigger: enemies=%d target=%s holding=%s click=%s", #cachedEnemies, target and target.name or "none", tostring(holding), tostring(clickMode)))
    end
    if target then
        acquiredAt = acquiredAt or os.clock()
        if os.clock() - acquiredAt >= Cfg.TriggerDelay then press() end
    else
        acquiredAt = nil
        release()
    end
end)

-- mouse lock-on. Camera writes are discarded by the game within a frame, so the real mouse is moved.
-- Closed loop: each frame it measures how far the crosshair actually moved for the mouse units it sent,
-- so it works at any sensitivity and in ADS without being tuned. The target is sticky (it stays on the
-- same player until that player is lost) and the aim point is the head or the chest.
local AIM_PARTS = {{"Head", 0}, {"Chest", 1.3}}
local lock = {name = nil, scale = 1, cmd = nil, last = nil, accX = 0, accY = 0}
local function aimPointOf(e)
    return e.head.Position - Vector3.new(0, AIM_PARTS[Cfg.AimPart][2], 0)
end
local function aimCandidate(e, c, fovMul)
    local pt = aimPointOf(e)
    if (pt - camera.CFrame.Position).Magnitude > Cfg.AimRange then return end
    local sp, on = camera:WorldToViewportPoint(pt)
    if not (on and sp.Z > 0) then return end
    local d = (Vector2.new(sp.X, sp.Y) - c).Magnitude
    if d > Cfg.AimFov * fovMul then return end
    if Cfg.AimVisible and not worldClear(pt) then return end
    return d, Vector2.new(sp.X, sp.Y)
end
connect(RunService.RenderStepped, function()
    if not Cfg.Aim or not mousemoverel then return end
    local fire = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    local ads = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    if not (fire or ads) or UserInputService:GetFocusedTextBox() then
        lock.name, lock.cmd, lock.last, lock.accX, lock.accY = nil, nil, nil, 0, 0
        return
    end
    local c = camera.ViewportSize / 2
    local target, tpos

    -- keep the current target while it is still a valid candidate
    if Cfg.AimSticky and lock.name then
        for _, e in ipairs(cachedEnemies) do
            if e.name == lock.name then
                local d, sp = aimCandidate(e, c, 1.6)
                if d then target, tpos = e, sp end
                break
            end
        end
    end
    if not target then
        local bestD
        for _, e in ipairs(cachedEnemies) do
            local d, sp = aimCandidate(e, c, 1)
            if d and (not bestD or d < bestD) then bestD, target, tpos = d, e, sp end
        end
    end
    if not target then lock.name, lock.cmd, lock.last = nil, nil, nil return end
    if lock.name ~= target.name then lock.name, lock.cmd, lock.last, lock.accX, lock.accY = target.name, nil, nil, 0, 0; lock.t0 = os.clock(); lock.react = (0.04 + math.random() * 0.12) * (Cfg.AimHuman / 100) end

    -- learn how many screen pixels one mouse unit moves the crosshair
    if lock.cmd and lock.last then
        local cmag2 = lock.cmd.X * lock.cmd.X + lock.cmd.Y * lock.cmd.Y
        if cmag2 > 4 then
            local moved = lock.last - tpos            -- the target slides the opposite way to the crosshair
            local est = (moved.X * lock.cmd.X + moved.Y * lock.cmd.Y) / cmag2
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

    -- the mouse only takes whole units, so carry the remainder to the next frame
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
        local cam = camera
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
main.Size = UDim2.fromOffset(420, 560)
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
title.Text = "KING HUB  ·  PHANTOM FORCES"
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
    bg.Position = UDim2.new(1, -54, 0.5, -11)
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
addToggle(tEsp, "Head dot", "HeadDot")
addSlider(tEsp, "Max distance", "MaxDist", 100, 2000, function(v) return string.format("%dm", math.floor(v)) end)
addCycle(tEsp, "Box style", "BoxMode", {{"Full"}, {"Corner"}})
addCycle(tEsp, "Box color", "BoxColor", PALETTE)
addCycle(tEsp, "Name color", "NameColor", PALETTE)
addCycle(tEsp, "Distance color", "DistColor", PALETTE)
addToggle(tEsp, "Visible check: only show visible enemies", "EspVisOnly")
addToggle(tEsp, "Visible check: box turns green when visible", "VisTint")
addToggle(tEsp, "Tracers (pink)", "Tracers")
addToggle(tEsp, "Chams (see through walls)", "Chams")
addCycle(tEsp, "Chams color", "ChamsColor", PALETTE)
addSlider(tEsp, "Chams fill", "ChamsFill", 0, 1, function(v) return string.format("%d%%", math.floor(v * 100)) end)

local tVis = addTab("Viewmodel")
addToggle(tVis, "Custom arms", "VM")
addCycle(tVis, "Arms color", "VMColor", PALETTE)
addCycle(tVis, "Arms material", "VMMat", MATERIALS)
addSlider(tVis, "Arms transparency", "VMTrans", 0, 0.95, function(v) return string.format("%d%%", math.floor(v * 100)) end)
addToggle(tVis, "Custom weapon", "WP")
addCycle(tVis, "Weapon color", "WPColor", PALETTE)
addCycle(tVis, "Weapon material", "WPMat", MATERIALS)
addSlider(tVis, "Weapon transparency", "WPTrans", 0, 0.95, function(v) return string.format("%d%%", math.floor(v * 100)) end)

local tWorld = addTab("World")
addToggle(tWorld, "Custom FOV", "Fov")
addSlider(tWorld, "FOV value", "FovValue", 50, 120, function(v) return string.format("%d", math.floor(v)) end)
addToggle(tWorld, "Fullbright", "Fullbright")
addToggle(tWorld, "No fog", "NoFog")
addToggle(tWorld, "No grass", "NoGrass")
addToggle(tWorld, "Custom time of day", "CustomTime")
addSlider(tWorld, "Time of day", "TimeValue", 0, 24, function(v) return string.format("%.1fh", v) end)
addToggle(tWorld, "Custom ambient", "CustomAmbient")
addCycle(tWorld, "Ambient color", "AmbientColor", PALETTE)

local tCmb = addTab("Combat")
addToggle(tCmb, "Triggerbot", "Trigger")
addToggle(tCmb, "Triggerbot: wall check", "TriggerWallCheck")
addToggle(tCmb, "Triggerbot: shoot through glass", "TriggerGlass")
addToggle(tCmb, "Triggerbot: wallbang thin walls (only while you hold click)", "TriggerWallbang")
addToggle(tCmb, "Triggerbot: head only", "TriggerHeadOnly")
addSlider(tCmb, "Fire delay", "TriggerDelay", 0, 0.5, function(v) return string.format("%.2fs", v) end)
addSlider(tCmb, "Max range", "TriggerRange", 50, 2000, function(v) return string.format("%dm", math.floor(v)) end)
addToggle(tCmb, "Mouse lock-on (hold fire or aim)", "Aim")
addSlider(tCmb, "Lock-on radius (screen px)", "AimFov", 20, 600, function(v) return string.format("%dpx", math.floor(v)) end)
addSlider(tCmb, "Lock-on range (studs)", "AimRange", 20, 800, function(v) return string.format("%d studs", math.floor(v)) end)
addSlider(tCmb, "Lock-on strength", "AimSmooth", 0.1, 1, function(v) return string.format("%d%%", math.floor(v * 100)) end)
addSlider(tCmb, "Lock-on max speed", "AimMaxStep", 10, 300, function(v) return string.format("%d", math.floor(v)) end)
addCycle(tCmb, "Lock-on aims at", "AimPart", {{"Head"}, {"Chest"}})
addToggle(tCmb, "Lock-on radius ring (pink)", "AimCircle")
addToggle(tCmb, "Lock-on line to target (pink)", "AimLine")
addSlider(tCmb, "Lock-on humanization", "AimHuman", 0, 100, function(v) return string.format("%d%%", math.floor(v)) end)
addToggle(tCmb, "Lock-on stays on its target", "AimSticky")
addToggle(tCmb, "Lock-on needs line of sight", "AimVisible")

local tMisc = addTab("Misc")
addToggle(tMisc, "Watermark", "Watermark")
addButton(tMisc, "Save config", function()
    writefile(CFG_FILE, HttpService:JSONEncode(Cfg)); log("config saved")
end)
addButton(tMisc, "Load config", function()
    local saved = HttpService:JSONDecode(readfile(CFG_FILE))
    for k, v in pairs(saved) do if Cfg[k] ~= nil and type(Cfg[k]) == type(v) then Cfg[k] = v end end
    for _, fn in ipairs(refreshers) do pcall(fn) end
    log("config loaded")
end)
addButton(tMisc, "Unload script", function() if getgenv then pcall(getgenv().PF_RUNNING) end end, Color3.fromRGB(60, 16, 16))

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
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    for _, fn in ipairs(cleanups) do pcall(fn) end
    for _, e in pairs(entries) do pcall(function() e.frame:Destroy(); e.dot:Destroy(); e.hl:Destroy(); e.tracer:Destroy(); for _, c in ipairs(e.corners) do c:Destroy() end end) end
    pcall(function() espGui:Destroy() end)
    pcall(function() ui:Destroy() end)
    logAlive = false
    if getgenv then getgenv().PF_RUNNING = nil end
end
if getgenv then getgenv().PF_RUNNING = unload; getgenv().KING_UNLOADERS.pf = unload end
log("ready")
