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
