-- =============================================================================
--  KING HUB · BLOX STRIKE
--  v15: merged Perf into Effects · removed unnecessary section headers
-- =============================================================================

-- =============================================================================
--  SERVICES
-- =============================================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui          = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Lighting         = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
pcall(function() if makefolder and not (isfolder and isfolder("king_hub")) then makefolder("king_hub") end end)
-- KING unload support: only one KING script runs at a time. Every connection made by this script is tracked
-- through KING_KC (a global, because this file is close to Luau's 200-local limit) and swept on unload.
do
    local g = getgenv and getgenv() or _G
    g.KING_UNLOADERS = g.KING_UNLOADERS or {}
    for k, fn in pairs(g.KING_UNLOADERS) do
        pcall(fn)
        g.KING_UNLOADERS[k] = nil
    end
    local conns = {}
    local gp = game:GetService("CoreGui")
    pcall(function() if gethui then gp = gethui() end end)
    local baseline = {}
    for _, v in ipairs(gp:GetChildren()) do baseline[v] = true end
    local prof = {}
    shared.MH_Prof = prof      -- label -> {total seconds, max seconds, calls}, read and reset by the Debug tab
    local function timed(fn)
        local okL, line = pcall(debug.info, fn, "l")
        local label = "line" .. tostring(okL and line or "?")
        return function(...)
            local t = os.clock()
            fn(...)
            local d = os.clock() - t
            local e = prof[label]
            if not e then e = {0, 0, 0}; prof[label] = e end
            e[1] += d; e[3] += 1
            if d > e[2] then e[2] = d end
        end
    end
    g.KING_KC = function(sig, fn)
        local c = sig:Connect(timed(fn))
        conns[#conns + 1] = c
        return c
    end
    -- runs every frame AFTER the camera has moved (RenderStepped can run before it, which makes overlays trail one frame behind)
    g.KING_ONUNLOAD = function(fn)          -- run fn when this script is unloaded / replaced
        conns[#conns + 1] = {Disconnect = fn}
    end
    g.KING_RENDER = function(fn)
        local name = "KING_" .. game:GetService("HttpService"):GenerateGUID(false)
        game:GetService("RunService"):BindToRenderStep(name, Enum.RenderPriority.Last.Value, timed(fn))
        local h = {Disconnect = function() pcall(function() game:GetService("RunService"):UnbindFromRenderStep(name) end) end}
        conns[#conns + 1] = h
        return h
    end
    local SWEEP = {BloxBangOutline = true, BloxBangNameTag = true, KingBombMarker = true, KingBombBeam = true, KingFullBright = true}
    g.KING_UNLOADERS.blox = function()
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        for _, v in ipairs(gp:GetChildren()) do
            if not baseline[v] and v:IsA("ScreenGui") then
                local n = v.Name
                if n:match("^%x+%-%x+%-%x+%-%x+%-%x+$") or n:match("^King") then pcall(function() v:Destroy() end) end
            end
        end
        for _, v in ipairs(workspace:GetDescendants()) do
            if SWEEP[v.Name] or v.Name:match("^KingGrenadeMarker_") then pcall(function() v:Destroy() end) end
        end
        pcall(function() local f = game:GetService("Lighting"):FindFirstChild("KingFullBright"); if f then f:Destroy() end end)
    end
end
-- hub log: everything the hub does is written to king_hub/hub_log.txt
do
    local LOG = "king_hub/hub_log.txt"
    local t0 = os.clock()
    local buf, count = {}, 0
    local function flush()
        if #buf == 0 then return end
        local chunk = table.concat(buf, "\n") .. "\n"
        buf = {}
        pcall(function()
            if appendfile then appendfile(LOG, chunk)
            else writefile(LOG, (isfile(LOG) and readfile(LOG) or "") .. chunk) end
        end)
    end
    pcall(function() writefile(LOG, "hub log (fresh each run)\n") end)
    shared.MH_Ring = {}
    shared.MH_Log = function(msg)
        count += 1
        local line = string.format("[+%7.1fs] %s", os.clock() - t0, tostring(msg))
        local ring = shared.MH_Ring
        ring[#ring + 1] = line
        if #ring > 600 then table.remove(ring, 1) end      -- last 600 lines, for the copy button
        if count > 4000 then return end
        buf[#buf + 1] = line
    end
    shared.MH_Try = function(name, fn)
        local ok, err = pcall(fn)
        shared.MH_Log((ok and "block ok: " or "BLOCK FAILED: ") .. name .. (ok and "" or (" -> " .. tostring(err))))
        return ok
    end
    task.spawn(function() while true do task.wait(3); flush() end end)
    pcall(function()
        KING_KC(game:GetService("ScriptContext").Error, function(msg, trace)
            shared.MH_Log("ERR " .. tostring(msg) .. " | " .. tostring(trace):sub(1, 220))
        end)
    end)
    shared.MH_Log("hub started; placeId=" .. tostring(game.PlaceId) .. " map=" .. tostring(workspace:GetAttribute("Map")))
end
local playerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Camera      = workspace.CurrentCamera

local GuiParent
pcall(function() GuiParent = gethui() end)
if not GuiParent then pcall(function() GuiParent = CoreGui end) end
if not GuiParent then GuiParent = playerGui end

local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local MOUSE_OK  = UserInputService.MouseEnabled

-- =============================================================================
--  PALETTE
-- =============================================================================
local C = {
    bg        = Color3.fromRGB(8,  16, 16),
    panel     = Color3.fromRGB(10, 22, 22),
    border    = Color3.fromRGB(0,  188, 168),
    teal      = Color3.fromRGB(0,  188, 168),
    tealBright= Color3.fromRGB(0,  230, 210),
    tealDim   = Color3.fromRGB(0,  110, 100),
    gold      = Color3.fromRGB(232,184, 75),
    text      = Color3.fromRGB(180,210,205),
    textDim   = Color3.fromRGB(90, 130,125),
    dark      = Color3.fromRGB(6,  14, 14),
    black     = Color3.fromRGB(0,   0,  0),
    white     = Color3.fromRGB(255,255,255),
    red       = Color3.fromRGB(220, 80,  80),
    visRed    = Color3.fromRGB(255, 40,  40),
    bombOrange= Color3.fromRGB(255, 140, 30),
    green     = Color3.fromRGB(80, 200, 120),
    discord   = Color3.fromRGB(88, 101, 242),
    smokeBlue = Color3.fromRGB(140, 200, 255),
    fireOrange= Color3.fromRGB(255, 120, 40),
    flashYell = Color3.fromRGB(255, 230, 100),
}

local ESP_COLORS = {
    IDF        = Color3.fromRGB(0, 230, 210),
    Anarchist  = Color3.fromRGB(0, 150, 130),
}
local ESP_DEFAULT = Color3.fromRGB(0, 188, 168)

local HP_GOOD = Color3.fromRGB(0,  230, 210)
local HP_MID  = Color3.fromRGB(232,184,  75)
local HP_LOW  = Color3.fromRGB(220, 80,  80)

-- =============================================================================
--  HELPERS
-- =============================================================================
local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 4)
    c.Parent = p
    return c
end

local function stroke(p, col, t, tr)
    local s = Instance.new("UIStroke")
    s.Color = col or C.border
    s.Thickness = t or 1
    s.Transparency = tr or 0.6
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = p
    return s
end

local function tw(obj, t, props)
    pcall(function()
        TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props):Play()
    end)
end
local ease = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local function MakeDragHandle(handle, targetFrame)
    handle.Active = true
    local drag, dragStart, startPos
    KING_KC(handle.InputBegan, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            drag = true
            dragStart = inp.Position
            startPos = targetFrame.Position
        end
    end)
    KING_KC(UserInputService.InputChanged, function(inp)
        if drag and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - dragStart
            targetFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
    KING_KC(UserInputService.InputEnded, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            drag = false
        end
    end)
end

local function Notify(text, duration, color)
    if shared.MH_Log then shared.MH_Log('TOAST ' .. tostring(text)) end
    duration = duration or 3
    if not NotifyHolder then return end
    local toast = Instance.new("Frame", NotifyHolder)
    toast.Size = UDim2.new(1, 0, 0, 42)
    toast.BackgroundColor3 = C.panel
    toast.BackgroundTransparency = 0.05
    toast.BorderSizePixel = 0
    corner(toast, 4)
    stroke(toast, color or C.teal, 1, 0.3)
    local bar = Instance.new("Frame", toast)
    bar.Size = UDim2.new(0, 3, 1, 0)
    bar.BackgroundColor3 = color or C.teal
    bar.BorderSizePixel = 0
    corner(bar, 3)
    local txt = Instance.new("TextLabel", toast)
    txt.BackgroundTransparency = 1
    txt.Size = UDim2.new(1, -20, 1, 0)
    txt.Position = UDim2.new(0, 14, 0, 0)
    txt.Font = Enum.Font.GothamMedium
    txt.TextSize = 13
    txt.TextColor3 = C.text
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.TextWrapped = true
    txt.Text = text
    toast.Position = UDim2.new(0, 320, 0, 0)
    tw(toast, 0.25, { Position = UDim2.new(0, 0, 0, 0) })
    task.delay(duration, function()
        tw(toast, 0.25, { Position = UDim2.new(0, 320, 0, 0) })
        task.wait(0.3)
        toast:Destroy()
    end)
end

-- =============================================================================
--  NOTIFICATIONS
-- =============================================================================
local NotifyGui = Instance.new("ScreenGui", GuiParent)
NotifyGui.Name = "KingNotify"
NotifyGui.ResetOnSpawn = false
NotifyGui.DisplayOrder = 998
pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(NotifyGui)
    elseif protectgui then protectgui(NotifyGui) end
end)

local NotifyHolder = Instance.new("Frame", NotifyGui)
NotifyHolder.Size = UDim2.new(0, 300, 0, 400)
NotifyHolder.Position = UDim2.new(0.5, -150, 0, 12)
NotifyHolder.BackgroundTransparency = 1
local nl = Instance.new("UIListLayout", NotifyHolder)
nl.SortOrder = Enum.SortOrder.LayoutOrder
nl.Padding = UDim.new(0, 6)

-- =============================================================================
--  ROOT GUI
-- =============================================================================
local GUI_NAME = "KingTemplate_" .. tostring(math.random(1000, 9999))
for _, v in pairs(GuiParent:GetChildren()) do
    if v:IsA("ScreenGui") and v.Name:match("^KingTemplate_") then v:Destroy() end
end

local gui = Instance.new("ScreenGui", GuiParent)
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(gui)
    elseif protectgui then protectgui(gui) end
end)

local vp = Camera and Camera.ViewportSize or Vector2.new(1280, 720)
local panelW = math.clamp(vp.X * 0.9, 400, 560)
local panelH = math.clamp(vp.Y * 0.85, 400, 560)
if IS_MOBILE then
    panelW = math.clamp(vp.X * 0.95, 400, 620)
    panelH = math.clamp(vp.Y * 0.9, 400, 620)
end

local FloatBtn = Instance.new("TextButton", gui)
FloatBtn.Name = "KingFloat"
FloatBtn.Size = UDim2.fromOffset(56, 56)
FloatBtn.Position = UDim2.new(0, 20, 0.4, 0)
FloatBtn.BackgroundColor3 = C.teal
FloatBtn.BackgroundTransparency = 0.05
FloatBtn.Text = "👑"
FloatBtn.Font = Enum.Font.GothamBold
FloatBtn.TextSize = 26
FloatBtn.TextColor3 = C.white
FloatBtn.BorderSizePixel = 0
FloatBtn.Active = true
FloatBtn.Draggable = true
FloatBtn.Visible = false
FloatBtn.ZIndex = 100
corner(FloatBtn, 6)
stroke(FloatBtn, C.border, 2, 0.2)

local panel = Instance.new("Frame", gui)
panel.Name = "MainPanel"
panel.Size = UDim2.fromOffset(panelW, panelH)
panel.Position = UDim2.new(0.5, -panelW/2, 0.5, -panelH/2)
panel.BackgroundColor3 = C.panel
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Visible = false
panel.ZIndex = 5
corner(panel, 6)
stroke(panel, C.teal, 1, 0.55)

local scan = Instance.new("Frame", panel)
scan.Size = UDim2.new(1, 0, 1, 0)
scan.BackgroundColor3 = C.black
scan.BackgroundTransparency = 0.97
scan.BorderSizePixel = 0
scan.ZIndex = 10
scan.Active = false

local topBar = Instance.new("Frame", panel)
topBar.Size = UDim2.new(1, 0, 0, 3)
topBar.BackgroundColor3 = C.teal
topBar.BorderSizePixel = 0
topBar.ZIndex = 5
corner(topBar, 2)
tw(topBar, 1.8, { BackgroundColor3 = Color3.fromRGB(0, 230, 210) })

local SidebarW = math.clamp(panelW * 0.32, 170, 200)
local Sidebar = Instance.new("Frame", panel)
Sidebar.Size = UDim2.new(0, SidebarW, 1, 0)
Sidebar.BackgroundColor3 = C.dark
Sidebar.BackgroundTransparency = 0.15
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 6
corner(Sidebar, 6)

local LogoBox = Instance.new("Frame", Sidebar)
LogoBox.Size = UDim2.new(1, 0, 0, 80)
LogoBox.BackgroundTransparency = 1

local LogoIconBg = Instance.new("Frame", LogoBox)
LogoIconBg.Size = UDim2.fromOffset(40, 40)
LogoIconBg.Position = UDim2.fromOffset(20, 20)
LogoIconBg.BackgroundColor3 = C.teal
LogoIconBg.BackgroundTransparency = 0.85
LogoIconBg.BorderSizePixel = 0
corner(LogoIconBg, 4)
stroke(LogoIconBg, C.teal, 1, 0.35)

local LogoIconLbl = Instance.new("TextLabel", LogoIconBg)
LogoIconLbl.Size = UDim2.fromScale(1, 1)
LogoIconLbl.BackgroundTransparency = 1
LogoIconLbl.Text = "👑"
LogoIconLbl.Font = Enum.Font.GothamBold
LogoIconLbl.TextSize = 22

local LogoText = Instance.new("TextLabel", LogoBox)
LogoText.Size = UDim2.new(1, -70, 0, 24)
LogoText.Position = UDim2.fromOffset(70, 20)
LogoText.BackgroundTransparency = 1
LogoText.Text = "KING HUB"
LogoText.Font = Enum.Font.GothamBold
LogoText.TextSize = 16
LogoText.TextColor3 = C.teal
LogoText.TextXAlignment = Enum.TextXAlignment.Left

local LogoSub = Instance.new("TextLabel", LogoBox)
LogoSub.Size = UDim2.new(1, -70, 0, 14)
LogoSub.Position = UDim2.fromOffset(70, 44)
LogoSub.BackgroundTransparency = 1
LogoSub.Text = "BLOX STRIKE // MINIMAL"
LogoSub.Font = Enum.Font.GothamMedium
LogoSub.TextSize = 9
LogoSub.TextColor3 = C.tealDim
LogoSub.TextXAlignment = Enum.TextXAlignment.Left

local LogoDiv = Instance.new("Frame", LogoBox)
LogoDiv.Size = UDim2.new(1, 0, 0, 1)
LogoDiv.Position = UDim2.new(0, 0, 1, 0)
LogoDiv.BackgroundColor3 = C.border
LogoDiv.BackgroundTransparency = 0.82
LogoDiv.BorderSizePixel = 0

local TabHold = Instance.new("Frame", Sidebar)
TabHold.Size = UDim2.new(1, 0, 1, -160)
TabHold.Position = UDim2.fromOffset(0, 81)
TabHold.BackgroundTransparency = 1
local tLayout = Instance.new("UIListLayout", TabHold)
tLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tLayout.Padding = UDim.new(0, 4)
local tPad = Instance.new("UIPadding", TabHold)
tPad.PaddingTop = UDim.new(0, 14)

local ProfileBox = Instance.new("Frame", Sidebar)
ProfileBox.Size = UDim2.new(1, 0, 0, 76)
ProfileBox.Position = UDim2.new(0, 0, 1, -76)
ProfileBox.BackgroundColor3 = C.black
ProfileBox.BackgroundTransparency = 0.35
ProfileBox.BorderSizePixel = 0
corner(ProfileBox, 6)

local Avatar = Instance.new("ImageLabel", ProfileBox)
Avatar.Size = UDim2.fromOffset(36, 36)
Avatar.Position = UDim2.fromOffset(14, 20)
Avatar.BackgroundColor3 = C.dark
Avatar.BorderSizePixel = 0
Avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150"
corner(Avatar, 4)
stroke(Avatar, C.teal, 1, 0.35)

local PName = Instance.new("TextLabel", ProfileBox)
PName.Size = UDim2.new(1, -64, 0, 18)
PName.Position = UDim2.fromOffset(58, 16)
PName.BackgroundTransparency = 1
PName.Text = LocalPlayer.Name
PName.Font = Enum.Font.GothamBold
PName.TextSize = 12
PName.TextColor3 = C.text
PName.TextXAlignment = Enum.TextXAlignment.Left
PName.TextTruncate = Enum.TextTruncate.AtEnd

local PStatus = Instance.new("TextLabel", ProfileBox)
PStatus.Size = UDim2.new(1, -64, 0, 14)
PStatus.Position = UDim2.fromOffset(58, 38)
PStatus.BackgroundTransparency = 1
PStatus.Text = "🟢  Ready"
PStatus.Font = Enum.Font.GothamMedium
PStatus.TextSize = 9
PStatus.TextColor3 = C.teal
PStatus.TextXAlignment = Enum.TextXAlignment.Left

local ContentBg = Instance.new("Frame", panel)
ContentBg.Size = UDim2.new(1, -SidebarW, 1, 0)
ContentBg.Position = UDim2.fromOffset(SidebarW, 0)
ContentBg.BackgroundTransparency = 1

local Topbar = Instance.new("Frame", ContentBg)
Topbar.Size = UDim2.new(1, 0, 0, 76)
Topbar.BackgroundColor3 = C.dark
Topbar.BackgroundTransparency = 0.4
Topbar.BorderSizePixel = 0

MakeDragHandle(Topbar, panel)
MakeDragHandle(LogoBox, panel)

local TopDiv = Instance.new("Frame", Topbar)
TopDiv.Size = UDim2.new(1, 0, 0, 1)
TopDiv.Position = UDim2.new(0, 0, 1, -1)
TopDiv.BackgroundColor3 = C.border
TopDiv.BackgroundTransparency = 0.82
TopDiv.BorderSizePixel = 0

local TopIconBg = Instance.new("Frame", Topbar)
TopIconBg.Size = UDim2.fromOffset(36, 36)
TopIconBg.Position = UDim2.fromOffset(20, 20)
TopIconBg.BackgroundColor3 = C.teal
TopIconBg.BackgroundTransparency = 0.85
TopIconBg.BorderSizePixel = 0
corner(TopIconBg, 4)
stroke(TopIconBg, C.teal, 1, 0.35)

local TopIconLbl = Instance.new("TextLabel", TopIconBg)
TopIconLbl.Size = UDim2.fromScale(1, 1)
TopIconLbl.BackgroundTransparency = 1
TopIconLbl.Text = "👁"
TopIconLbl.Font = Enum.Font.GothamBold
TopIconLbl.TextSize = 18
TopIconLbl.TextColor3 = C.teal

local TopTitle = Instance.new("TextLabel", Topbar)
TopTitle.Size = UDim2.new(1, -220, 1, 0)
TopTitle.Position = UDim2.fromOffset(68, 0)
TopTitle.BackgroundTransparency = 1
TopTitle.Text = "Visuals"
TopTitle.Font = Enum.Font.GothamBold
TopTitle.TextSize = 18
TopTitle.TextColor3 = C.teal
TopTitle.TextXAlignment = Enum.TextXAlignment.Left

local SessionBadge = Instance.new("Frame", Topbar)
SessionBadge.Size = UDim2.fromOffset(120, 28)
SessionBadge.Position = UDim2.new(1, -132, 0.5, -14)
SessionBadge.BackgroundColor3 = C.black
SessionBadge.BackgroundTransparency = 0.4
SessionBadge.BorderSizePixel = 0
corner(SessionBadge, 4)
stroke(SessionBadge, C.border, 1, 0.55)

local SBLabel = Instance.new("TextLabel", SessionBadge)
SBLabel.Size = UDim2.fromScale(1, 1)
SBLabel.BackgroundTransparency = 1
SBLabel.Text = "✅  Active"
SBLabel.Font = Enum.Font.GothamMedium
SBLabel.TextSize = 9
SBLabel.TextColor3 = C.teal

local PageHost = Instance.new("Frame", ContentBg)
PageHost.Size = UDim2.new(1, -40, 1, -100)
PageHost.Position = UDim2.fromOffset(20, 84)
PageHost.BackgroundTransparency = 1

-- =============================================================================
--  TAB SYSTEM
-- =============================================================================
local activeBtn, activePage = nil, nil
local tabPages, tabButtons = {}, {}

local function SelectTab(btn, page, name, icon)
    if activeBtn then
        tw(activeBtn, 0.18, { BackgroundTransparency = 1 })
        local t = activeBtn:FindFirstChild("Title"); if t then tw(t, 0.18, { TextColor3 = C.textDim }) end
        local i = activeBtn:FindFirstChild("Ico");   if i then tw(i, 0.18, { TextColor3 = C.textDim }) end
    end
    if activePage then activePage.Visible = false end
    tw(btn, 0.18, { BackgroundTransparency = 0.75 })
    local t = btn:FindFirstChild("Title"); if t then tw(t, 0.18, { TextColor3 = C.teal }) end
    local i = btn:FindFirstChild("Ico");   if i then tw(i, 0.18, { TextColor3 = C.teal }) end
    page.Visible = true
    page.Position = UDim2.new(0, 0, 0, 10)
    tw(page, 0.3, { Position = UDim2.new(0, 0, 0, 0) })
    TopTitle.Text = name
    TopIconLbl.Text = icon
    activeBtn = btn
    activePage = page
end

local function createTab(icon, name)
    local btn = Instance.new("TextButton", TabHold)
    btn.Size = UDim2.new(1, -20, 0, 42)
    btn.BackgroundColor3 = C.teal
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    corner(btn, 4)
    stroke(btn, C.border, 1, 0.96)

    local icoLbl = Instance.new("TextLabel", btn)
    icoLbl.Name = "Ico"
    icoLbl.Size = UDim2.fromOffset(20, 20)
    icoLbl.Position = UDim2.fromOffset(12, 11)
    icoLbl.BackgroundTransparency = 1
    icoLbl.Font = Enum.Font.GothamBold
    icoLbl.TextSize = 14
    icoLbl.Text = icon
    icoLbl.TextColor3 = C.textDim

    local tLbl = Instance.new("TextLabel", btn)
    tLbl.Name = "Title"
    tLbl.Size = UDim2.new(1, -44, 1, 0)
    tLbl.Position = UDim2.fromOffset(38, 0)
    tLbl.BackgroundTransparency = 1
    tLbl.Text = name
    tLbl.Font = Enum.Font.GothamMedium
    tLbl.TextSize = 12
    tLbl.TextColor3 = C.textDim
    tLbl.TextXAlignment = Enum.TextXAlignment.Left

    local page = Instance.new("ScrollingFrame", PageHost)
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 8
    page.ScrollBarImageColor3 = C.teal
    page.ScrollBarImageTransparency = 0.3
    page.CanvasSize = UDim2.fromOffset(0, 600)
    page.Visible = false
    page.ScrollingEnabled = true
    page.Selectable = true
    page.Active = true
    local lay = Instance.new("UIListLayout", page)
    lay.Padding = UDim.new(0, 6)
    local pad = Instance.new("UIPadding", page)
    pad.PaddingTop = UDim.new(0, 6)
    pad.PaddingBottom = UDim.new(0, 6)
    KING_KC(lay:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        page.CanvasSize = UDim2.new(0, 0, 0, lay.AbsoluteContentSize.Y + 20)
    end)

    KING_KC(btn.MouseButton1Click, function() SelectTab(btn, page, name, icon) end)
    KING_KC(btn.MouseEnter, function()
        if btn ~= activeBtn then
            tw(tLbl, 0.1, { TextColor3 = C.text })
            tw(icoLbl, 0.1, { TextColor3 = C.text })
            tw(btn, 0.1, { BackgroundTransparency = 0.9 })
        end
    end)
    KING_KC(btn.MouseLeave, function()
        if btn ~= activeBtn then
            tw(tLbl, 0.1, { TextColor3 = C.textDim })
            tw(icoLbl, 0.1, { TextColor3 = C.textDim })
            tw(btn, 0.1, { BackgroundTransparency = 1 })
        end
    end)

    tabPages[name] = page
    tabButtons[name] = btn
    return page, btn
end

-- =============================================================================
--  WIDGETS
-- =============================================================================
local orderCounter = 0
local function nextOrder() orderCounter = orderCounter + 1; return orderCounter end

local function toggle(parent, text, default, callback)
    local r = Instance.new("Frame", parent)
    r.BackgroundColor3 = C.dark
    r.BackgroundTransparency = 0.15
    r.BorderSizePixel = 0
    r.Size = UDim2.new(1, 0, 0, 52)
    r.LayoutOrder = nextOrder()
    corner(r, 4)
    stroke(r, C.tealDim, 1, 0.85)

    local l = Instance.new("TextLabel", r)
    l.Size = UDim2.new(1, -100, 1, 0)
    l.Position = UDim2.fromOffset(14, 0)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = C.text
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextWrapped = true

    local tBg = Instance.new("TextButton", r)
    tBg.Size = UDim2.fromOffset(46, 24)
    tBg.Position = UDim2.new(1, -58, 0.5, -12)
    tBg.BackgroundColor3 = Color3.fromRGB(24, 45, 45)
    tBg.Text = ""
    tBg.BorderSizePixel = 0
    tBg.AutoButtonColor = false
    corner(tBg, 4)

    local knob = Instance.new("Frame", tBg)
    knob.Size = UDim2.fromOffset(18, 18)
    knob.Position = UDim2.fromOffset(3, 3)
    knob.BackgroundColor3 = C.white
    knob.BorderSizePixel = 0
    corner(knob, 3)

    local state = default or false
    local function render()
        tw(tBg, 0.18, { BackgroundColor3 = state and C.teal or Color3.fromRGB(24, 45, 45) })
        tw(knob, 0.18, { Position = state and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3) })
    end
    render()

    KING_KC(tBg.MouseButton1Click, function()
        state = not state
        render()
        if callback then pcall(callback, state) end
    end)
    KING_KC(r.MouseEnter, function() tw(r, 0.1, { BackgroundTransparency = 0.05 }) end)
    KING_KC(r.MouseLeave, function() tw(r, 0.1, { BackgroundTransparency = 0.15 }) end)
    return { Value = state, Set = function(v) state = v; render(); if callback then pcall(callback, v) end end }
end

local function button(parent, text, callback, bgColor, txtColor)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(1, 0, 0, 42)
    b.BackgroundColor3 = bgColor or C.dark
    b.BackgroundTransparency = 0.15
    b.Text = text
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 12
    b.TextColor3 = txtColor or C.text
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.LayoutOrder = nextOrder()
    corner(b, 4)
    stroke(b, bgColor or C.tealDim, 1, 0.85)
    KING_KC(b.MouseEnter, function() tw(b, 0.15, { BackgroundTransparency = 0.0 }) end)
    KING_KC(b.MouseLeave, function() tw(b, 0.15, { BackgroundTransparency = 0.15 }) end)
    KING_KC(b.MouseButton1Click, function()
        tw(b, 0.15, { BackgroundTransparency = 0.0 })
        task.delay(0.15, function() tw(b, 0.15, { BackgroundTransparency = 0.15 }) end)
        if callback then pcall(callback) end
    end)
    return b
end

local function slider(parent, text, minV, maxV, default, callback, fmt)
    fmt = fmt or function(v) return string.format("%.2f", v) end
    local r = Instance.new("Frame", parent)
    r.BackgroundColor3 = C.dark
    r.BackgroundTransparency = 0.15
    r.BorderSizePixel = 0
    r.Size = UDim2.new(1, 0, 0, 58)
    r.LayoutOrder = nextOrder()
    corner(r, 4)
    stroke(r, C.tealDim, 1, 0.85)

    local lbl = Instance.new("TextLabel", r)
    lbl.Size = UDim2.new(1, -80, 0, 18)
    lbl.Position = UDim2.fromOffset(14, 6)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 11
    lbl.TextColor3 = C.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local valLbl = Instance.new("TextLabel", r)
    valLbl.Size = UDim2.fromOffset(64, 18)
    valLbl.Position = UDim2.new(1, -76, 0, 6)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = fmt(default)
    valLbl.Font = Enum.Font.Code
    valLbl.TextSize = 11
    valLbl.TextColor3 = C.teal
    valLbl.TextXAlignment = Enum.TextXAlignment.Right

    local track = Instance.new("TextButton", r)
    track.Text = ""
    track.AutoButtonColor = false
    track.BackgroundColor3 = Color3.fromRGB(20, 34, 32)
    track.BorderSizePixel = 0
    track.Size = UDim2.new(1, -28, 0, 8)
    track.Position = UDim2.new(0, 14, 0, 32)
    corner(track, 4)

    local fill = Instance.new("Frame", track)
    fill.Size = UDim2.fromScale((default - minV) / (maxV - minV), 1)
    fill.BackgroundColor3 = C.teal
    fill.BorderSizePixel = 0
    fill.AnchorPoint = Vector2.new(0, 0)
    fill.Position = UDim2.fromScale(0, 0)
    corner(fill, 4)

    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.fromOffset(14, 14)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(fill.Size.X.Scale, 0, 0.5, 0)
    knob.BackgroundColor3 = C.white
    knob.BorderSizePixel = 0
    corner(knob, 7)

    local current = default
    local dragging = false

    local function setFromX(x)
        local abs = track.AbsolutePosition.X
        local sz  = track.AbsoluteSize.X
        if sz <= 0 then return end
        local pct = math.clamp((x - abs) / sz, 0, 1)
        current = minV + (maxV - minV) * pct
        fill.Size = UDim2.fromScale(pct, 1)
        knob.Position = UDim2.new(pct, 0, 0.5, 0)
        valLbl.Text = fmt(current)
        if callback then pcall(callback, current) end
    end

    KING_KC(track.InputBegan, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(inp.Position.X)
        end
    end)
    KING_KC(UserInputService.InputChanged, function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            setFromX(inp.Position.X)
        end
    end)
    KING_KC(UserInputService.InputEnded, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return {
        Value = function() return current end,
        Set = function(v)
            local pct = math.clamp((v - minV) / (maxV - minV), 0, 1)
            current = v
            fill.Size = UDim2.fromScale(pct, 1)
            knob.Position = UDim2.new(pct, 0, 0.5, 0)
            valLbl.Text = fmt(current)
            if callback then pcall(callback, current) end
        end,
    }
end

local function keybind(parent, labelText, defaultKey, callback)
    local r = Instance.new("Frame", parent)
    r.BackgroundColor3 = C.dark
    r.BackgroundTransparency = 0.15
    r.BorderSizePixel = 0
    r.Size = UDim2.new(1, 0, 0, 52)
    r.LayoutOrder = nextOrder()
    corner(r, 4)
    stroke(r, C.tealDim, 1, 0.85)

    local lbl = Instance.new("TextLabel", r)
    lbl.Size = UDim2.new(1, -110, 1, 0)
    lbl.Position = UDim2.fromOffset(14, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 12
    lbl.TextColor3 = C.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local box = Instance.new("TextButton", r)
    box.Size = UDim2.fromOffset(90, 30)
    box.Position = UDim2.new(1, -102, 0.5, -15)
    box.BackgroundColor3 = Color3.fromRGB(20, 34, 32)
    box.Text = defaultKey and defaultKey.Name or "None"
    box.Font = Enum.Font.Code
    box.TextSize = 12
    box.TextColor3 = C.teal
    box.BorderSizePixel = 0
    box.AutoButtonColor = false
    corner(box, 4)
    stroke(box, C.tealDim, 1, 0.5)

    local currentKey = defaultKey
    local listening = false

    local function render()
        box.Text = currentKey and currentKey.Name or "None"
        box.TextColor3 = currentKey and C.teal or C.textDim
    end
    render()

    KING_KC(box.MouseButton1Click, function()
        listening = true
        box.Text = "[press]"
        box.TextColor3 = C.gold
    end)

    KING_KC(UserInputService.InputBegan, function(inp, gpe)
        if not listening then return end
        if gpe then return end
        if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end

        if inp.KeyCode == Enum.KeyCode.Escape then
            listening = false
            render()
            return
        end

        if inp.KeyCode == Enum.KeyCode.LeftShift or inp.KeyCode == Enum.KeyCode.RightShift
        or inp.KeyCode == Enum.KeyCode.LeftControl or inp.KeyCode == Enum.KeyCode.RightControl
        or inp.KeyCode == Enum.KeyCode.LeftAlt or inp.KeyCode == Enum.KeyCode.RightAlt then
            return
        end

        currentKey = inp.KeyCode
        listening = false
        render()
        if callback then pcall(callback, currentKey) end
    end)

    return { Value = function() return currentKey end }
end

-- =============================================================================
--  BUILD TABS
-- =============================================================================
local VIS_TAB    = createTab("👁", "Visuals")
local COMBAT_TAB = createTab("⚔", "Combat")
local BOMB_TAB   = createTab("💣", "Bomb")
local EFFECT_TAB = createTab("✨", "Effects")
local MISC_TAB   = createTab("⚙", "Misc")

-- =============================================================================
--  FEATURES
-- =============================================================================
local Features = {
    BigHeads     = false,
    Outlines     = false,
    TeamCheck    = false,
    NameTags     = false,
    HealthBars   = false,
    SkeletonESP  = false,

    Triggerbot        = false,
    TriggerbotKey     = Enum.KeyCode.C,
    TriggerbotDelay   = 0.08,
    TriggerbotRange   = 300,
    TriggerHeadOnly   = false,
    LastShotAt        = 0,

    RedWhenSighted    = true,

    BombCarrierESP    = false,
    PlantedBombESP    = false,

    NoFlash           = false,
    SeeThroughSmoke   = false,
    SeeThroughFire    = false,

    GrenadeSmokeESP   = false,
    GrenadeFireESP    = false,
    GrenadeFlashESP   = false,
}

-- =============================================================================
--  TEAM CHECK
-- =============================================================================
local teamCache = {}
local TEAM_CACHE_TTL = 1.5

local function readTeamFromPlayer(plr)
    if not plr then return nil end
    local ok, t = pcall(function() return plr:GetAttribute("Team") end)
    if ok and t and t ~= "" then return tostring(t) end

    local char = plr.Character
    if char then
        local ok2, name = pcall(function() return char:GetAttribute("CharacterName") end)
        if ok2 and name and name ~= "" then return tostring(name) end
    end
    return nil
end

local function GetTeam(plr)
    if not plr then return nil end
    local now = tick()
    local cached = teamCache[plr.UserId]
    if cached and (now - cached.t) < TEAM_CACHE_TTL then
        local live = readTeamFromPlayer(plr)
        if live then cached.team = live; cached.lastGood = live; cached.t = now; return live end
        return cached.lastGood
    end
    local live = readTeamFromPlayer(plr)
    if live then
        teamCache[plr.UserId] = { team = live, lastGood = live, t = now }
        return live
    end
    if cached and cached.lastGood then cached.t = now; return cached.lastGood end
    teamCache[plr.UserId] = { team = nil, lastGood = nil, t = now }
    return nil
end

KING_KC(Players.PlayerRemoving, function(plr) teamCache[plr.UserId] = nil end)

local function IsTeammate(plr)
    if not Features.TeamCheck then return false end
    if plr == LocalPlayer then return true end
    local myTeam = GetTeam(LocalPlayer)
    local theirTeam = GetTeam(plr)
    if not myTeam or not theirTeam then return false end
    return myTeam == theirTeam
end

local function IsAlive(plr)
    if not plr then return false end
    local char = plr.Character
    if not char then return false end
    -- characters the game parks in _PVS_CulledCharacters are still alive and still move (dead ones are caught by the Dead attribute below)
    if not char.Parent then return false end
    local okD, dead = pcall(function() return plr:GetAttribute("Dead") end)
    if okD and dead == true then return false end
    local h = char:FindFirstChildOfClass("Humanoid")
    if h and h.Health <= 0 then return false end
    return true
end

-- =============================================================================
--  BOMB CARRIER DETECTION
-- =============================================================================
local function isCarrier(plr)
    if not plr then return false end
    for i = 1, 5 do
        local slot = plr:GetAttribute("Slot" .. i)
        if type(slot) == "string" and slot:find('"Weapon":"C4"', 1, true) then
            return true
        end
    end
    return false
end

-- =============================================================================
--  FORCE-CLEANUP
-- =============================================================================
local forcedCleanups = {}
local function registerCleanup(fn) table.insert(forcedCleanups, fn) end

KING_KC(Players.PlayerRemoving, function(plr)
    for _, fn in ipairs(forcedCleanups) do pcall(fn, plr) end
end)
KING_KC(Players.PlayerAdded, function(plr)
    KING_KC(plr.CharacterRemoving, function()
        for _, fn in ipairs(forcedCleanups) do pcall(fn, plr) end
    end)
end)
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then
        KING_KC(plr.CharacterRemoving, function()
            for _, fn in ipairs(forcedCleanups) do pcall(fn, plr) end
        end)
    end
end

-- =============================================================================
--  CROSSHAIR VISIBILITY
-- =============================================================================
local crosshairParams = RaycastParams.new()
crosshairParams.FilterType = Enum.RaycastFilterType.Exclude
crosshairParams.IgnoreWater = true
crosshairParams.RespectCanCollide = false

local crosshairVisible = {}

local function getCrosshairScreenPos()
    if MOUSE_OK then
        local m = UserInputService:GetMouseLocation()
        return Vector2.new(m.X, m.Y)
    else
        local cam = workspace.CurrentCamera
        if not cam then return nil end
        return Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    end
end

local function getPlayerFromPart(part)
    if not part then return nil end
    local model = part:FindFirstAncestorOfClass("Model")
    while model do
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character == model then return plr end
        end
        model = model:FindFirstAncestorOfClass("Model")
    end
    return nil
end

local function refreshCrosshairVisibility()
    for k in pairs(crosshairVisible) do crosshairVisible[k] = nil end
    if not Features.RedWhenSighted then return end
    local cam = workspace.CurrentCamera
    local myChar = LocalPlayer.Character
    if not cam or not myChar then return end
    local screenPos = getCrosshairScreenPos()
    if not screenPos then return end
    local ray = cam:ViewportPointToRay(screenPos.X, screenPos.Y)
    crosshairParams.FilterDescendantsInstances = { myChar }
    local result = workspace:Raycast(ray.Origin, ray.Direction * Features.TriggerbotRange, crosshairParams)
    if not result or not result.Instance then return end
    local targetPlr = getPlayerFromPart(result.Instance)
    if not targetPlr then return end
    if targetPlr == LocalPlayer then return end
    if IsTeammate(targetPlr) then return end
    if not IsAlive(targetPlr) then return end
    local targetChar = targetPlr.Character
    if not targetChar then return end
    if not result.Instance:IsDescendantOf(targetChar) then return end
    crosshairVisible[targetPlr] = true
end

-- =============================================================================
--  COLOR RESOLVER
-- =============================================================================
local function getESPColorFor(plr)
    if crosshairVisible[plr] then return C.visRed end
    if isCarrier(plr) then return C.bombOrange end
    local team = GetTeam(plr)
    return ESP_COLORS[team] or ESP_DEFAULT
end

-- =============================================================================
--  BIG HEADS
-- =============================================================================
local bigHeadsConnections = {}
local originalHeadSizes = {}
local playerAddedConn

local function restoreHead(plr)
    local char = plr.Character
    if char then
        local head = char:FindFirstChild("Head")
        if head then
            local orig = head:GetAttribute("KingOrigSize") or originalHeadSizes[plr.UserId]
            if orig then head.Size = orig end
        end
    end
    originalHeadSizes[plr.UserId] = nil
end

local function applyBigHead(plr, char)
    if not char then return end
    if not Features.BigHeads then return end
    if IsTeammate(plr) then
        local head = char:FindFirstChild("Head")
        if head and originalHeadSizes[plr.UserId] then
            head.Size = originalHeadSizes[plr.UserId]
            originalHeadSizes[plr.UserId] = nil
        end
        return
    end
    local head = char:FindFirstChild("Head")
    if not head then
        for i = 1, 20 do
            task.wait(0.1)
            if not Features.BigHeads then return end
            if IsTeammate(plr) then return end
            head = char:FindFirstChild("Head")
            if head then break end
        end
    end
    if not head then return end
    if not Features.BigHeads then return end
    if IsTeammate(plr) then return end
    -- remember the REAL size on the part itself, so a reload can't mistake the enlarged size for the original
    local real = head:GetAttribute("KingOrigSize")
    if not real then
        real = head.Size
        if real.X >= 2.9 then real = Vector3.new(1.2, 1.2, 1.2) end   -- already enlarged by an older load: best guess for the native size
        pcall(function() head:SetAttribute("KingOrigSize", real) end)
    end
    originalHeadSizes[plr.UserId] = real
    head.Size = Vector3.new(3, 3, 3)
end

local function enableBigHeads(plr)
    if plr == LocalPlayer then return end
    task.spawn(function() applyBigHead(plr, plr.Character) end)
    if bigHeadsConnections[plr.UserId] then return end
    local conn = KING_KC(plr.CharacterAdded, function(newChar)
        if not Features.BigHeads then return end
        task.spawn(function() applyBigHead(plr, newChar) end)
    end)
    bigHeadsConnections[plr.UserId] = conn
end

local function disableBigHeads(plr)
    if plr == LocalPlayer then return end
    local conn = bigHeadsConnections[plr.UserId]
    if conn then conn:Disconnect(); bigHeadsConnections[plr.UserId] = nil end
    restoreHead(plr)
end

KING_ONUNLOAD(function()
    for _, plr in ipairs(Players:GetPlayers()) do pcall(restoreHead, plr) end
end)

local function setBigHeads(on)
    Features.BigHeads = on
    if on then
        for _, plr in ipairs(Players:GetPlayers()) do enableBigHeads(plr) end
        if not playerAddedConn then
            playerAddedConn = KING_KC(Players.PlayerAdded, function(plr) enableBigHeads(plr) end)
        end
    else
        if playerAddedConn then playerAddedConn:Disconnect(); playerAddedConn = nil end
        for _, plr in ipairs(Players:GetPlayers()) do disableBigHeads(plr) end
    end
end

-- =============================================================================
--  OUTLINES
-- =============================================================================
local outlineHeartbeat
local outlineLastRun = 0
local OUTLINE_COOLDOWN = 0.05
local OUTLINE_NAME = "BloxBangOutline"

local function removeOutlineFromChar(char)
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        if d.Name == OUTLINE_NAME then d:Destroy() end
    end
    local top = char:FindFirstChild(OUTLINE_NAME)
    if top then top:Destroy() end
end

local function addOutlineToChar(plr, char)
    if not char then return end
    if char:FindFirstChild(OUTLINE_NAME) then return end
    local col = getESPColorFor(plr)
    local highlight = Instance.new("Highlight")
    highlight.Name = OUTLINE_NAME
    highlight.FillColor = col
    highlight.OutlineColor = col
    highlight.FillTransparency = 0.75
    highlight.OutlineTransparency = 0.1
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = char
    highlight.Parent = char
end

local function updateOutlineColor(plr, char)
    local h = char:FindFirstChild(OUTLINE_NAME)
    if not h then return end
    local col = getESPColorFor(plr)
    if h.FillColor ~= col then
        h.FillColor = col
        h.OutlineColor = col
    end
end

local function setOutlines(on)
    Features.Outlines = on
    if on then
        if outlineHeartbeat then return end
        outlineHeartbeat = KING_KC(RunService.Heartbeat, function()
            if not Features.Outlines then return end
            local now = tick()
            if now - outlineLastRun < OUTLINE_COOLDOWN then return end
            outlineLastRun = now
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr == LocalPlayer then continue end
                local char = plr.Character
                if not char then continue end
                local shouldHave = IsAlive(plr) and (not IsTeammate(plr) or isCarrier(plr))
                local has = char:FindFirstChild(OUTLINE_NAME) ~= nil
                if shouldHave and not has then
                    addOutlineToChar(plr, char)
                elseif not shouldHave and has then
                    removeOutlineFromChar(char)
                elseif shouldHave and has then
                    updateOutlineColor(plr, char)
                end
            end
        end)
    else
        if outlineHeartbeat then outlineHeartbeat:Disconnect(); outlineHeartbeat = nil end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == OUTLINE_NAME then obj:Destroy() end
        end
    end
end

registerCleanup(function(plr)
    if plr.Character then removeOutlineFromChar(plr.Character) end
end)

-- =============================================================================
--  NAME TAGS
-- =============================================================================
local nameTagHeartbeat
local nameTagLastRun = 0
local NAME_TAG_COOLDOWN = 0.05
local NAME_TAG_NAME = "BloxBangNameTag"

local function removeNameTagFromChar(char)
    if not char then return end
    local existing = char:FindFirstChild(NAME_TAG_NAME)
    if existing then existing:Destroy() end
end

local function addNameTagToChar(plr, char)
    if not char then return end
    if char:FindFirstChild(NAME_TAG_NAME) then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    local col = getESPColorFor(plr)
    local bb = Instance.new("BillboardGui")
    bb.Name = NAME_TAG_NAME
    bb.Size = UDim2.fromOffset(220, 32)
    bb.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.MaxDistance = 600
    bb.Adornee = head
    bb.Parent = char

    local lbl = Instance.new("TextLabel", bb)
    lbl.Name = "Label"
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextColor3 = col
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    lbl.TextStrokeTransparency = 0.35
    lbl.Text = plr.Name
end

local function updateNameTagColor(plr, char)
    local bb = char:FindFirstChild(NAME_TAG_NAME)
    if not bb then return end
    local lbl = bb:FindFirstChild("Label")
    if not lbl then return end
    local col = getESPColorFor(plr)
    local nameText = plr.Name
    if isCarrier(plr) then
        nameText = "💣 " .. nameText .. " [C4]"
    end
    if lbl.TextColor3 ~= col then lbl.TextColor3 = col end
    if lbl.Text ~= nameText then lbl.Text = nameText end
end

local function setNametags(on)
    Features.NameTags = on
    if on then
        if nameTagHeartbeat then return end
        nameTagHeartbeat = KING_KC(RunService.Heartbeat, function()
            if not Features.NameTags then return end
            local now = tick()
            if now - nameTagLastRun < NAME_TAG_COOLDOWN then return end
            nameTagLastRun = now
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr == LocalPlayer then continue end
                local char = plr.Character
                local shouldHave = char ~= nil and IsAlive(plr) and (not IsTeammate(plr) or isCarrier(plr))
                if not shouldHave then
                    if char then removeNameTagFromChar(char) end
                    continue
                end
                if char and not char:FindFirstChild(NAME_TAG_NAME) then
                    addNameTagToChar(plr, char)
                elseif char then
                    updateNameTagColor(plr, char)
                end
            end
        end)
    else
        if nameTagHeartbeat then nameTagHeartbeat:Disconnect(); nameTagHeartbeat = nil end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == NAME_TAG_NAME then obj:Destroy() end
        end
    end
end

registerCleanup(function(plr)
    if plr.Character then removeNameTagFromChar(plr.Character) end
end)

-- =============================================================================
--  SKELETON ESP
-- =============================================================================
local skeletonHeartbeat
local skeletonLastRun = 0
local SKELETON_COOLDOWN = 0
local SKELETON_GUI_NAME = "BloxBangSkeleton"

local BONES = {
    {"Head",         "UpperTorso"},
    {"UpperTorso",   "LowerTorso"},
    {"UpperTorso",   "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso",   "RightUpperArm"},
    {"RightUpperArm","RightLowerArm"},
    {"RightLowerArm","RightHand"},
    {"LowerTorso",   "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso",   "RightUpperLeg"},
    {"RightUpperLeg","RightLowerLeg"},
    {"RightLowerLeg","RightFoot"},
}
local FALLBACK_PARENT = {
    Head         = "Head",
    UpperTorso   = "Torso",
    LowerTorso   = "Torso",
    LeftUpperArm = "Left Arm",
    LeftLowerArm = "Left Arm",
    LeftHand     = "Left Arm",
    RightUpperArm= "Right Arm",
    RightLowerArm= "Right Arm",
    RightHand    = "Right Arm",
    LeftUpperLeg = "Left Leg",
    LeftLowerLeg = "Left Leg",
    LeftFoot     = "Left Leg",
    RightUpperLeg= "Right Leg",
    RightLowerLeg= "Right Leg",
    RightFoot    = "Right Leg",
}

local function ensureSkeletonHolder()
    local existing = gui:FindFirstChild(SKELETON_GUI_NAME)
    if existing then return existing end
    local f = Instance.new("Frame", gui)
    f.Name = SKELETON_GUI_NAME
    f.BackgroundTransparency = 1
    f.Size = UDim2.fromScale(1, 1)
    f.ZIndex = 3
    return f
end

local function getSkeletonHolderFor(player)
    local holder = ensureSkeletonHolder()
    local h = holder:FindFirstChild(tostring(player.UserId))
    if h then return h end
    h = Instance.new("Frame", holder)
    h.Name = tostring(player.UserId)
    h.BackgroundTransparency = 1
    h.BorderSizePixel = 0
    h.Visible = false
    for i = 1, #BONES do
        local line = Instance.new("Frame", h)
        line.Name = "Bone" .. i
        line.BorderSizePixel = 0
        line.AnchorPoint = Vector2.new(0, 0.5)
        line.BackgroundColor3 = ESP_DEFAULT
        line.Visible = false
    end
    return h
end

local function hideAllSkeletons()
    local holder = gui:FindFirstChild(SKELETON_GUI_NAME)
    if holder then
        for _, c in ipairs(holder:GetChildren()) do c.Visible = false end
    end
end

local function resolvePart(char, r15Name)
    local p = char:FindFirstChild(r15Name)
    if p and p:IsA("BasePart") then return p end
    local fb = FALLBACK_PARENT[r15Name]
    if fb and fb ~= r15Name then
        local p2 = char:FindFirstChild(fb)
        if p2 and p2:IsA("BasePart") then return p2 end
    end
    return nil
end

local function drawLine(frame, p1, p2, thickness, col)
    local diff = p2 - p1
    local len = diff.Magnitude
    if len < 1 then frame.Visible = false; return end
    local mid = (p1 + p2) / 2
    local angle = math.deg(math.atan2(diff.Y, diff.X))
    frame.Position = UDim2.fromOffset(math.floor(mid.X), math.floor(mid.Y))
    frame.Size = UDim2.fromOffset(math.max(1, math.floor(len)), math.max(1, math.floor(thickness)))
    frame.Rotation = angle
    frame.BackgroundColor3 = col
    frame.Visible = true
end

local function setSkeletonESP(on)
    Features.SkeletonESP = on
    if on then
        if skeletonHeartbeat then return end
        skeletonHeartbeat = KING_RENDER(function()
            if not Features.SkeletonESP then return end
            local now = tick()
            if now - skeletonLastRun < SKELETON_COOLDOWN then return end
            skeletonLastRun = now
            local cam = workspace.CurrentCamera
            if not cam then hideAllSkeletons(); return end

            for _, plr in ipairs(Players:GetPlayers()) do
                if plr == LocalPlayer then continue end
                Features.SkelHolders = Features.SkelHolders or {}
                local holder = Features.SkelHolders[plr]
                if not holder or not holder.Parent then holder = getSkeletonHolderFor(plr); Features.SkelHolders[plr] = holder end
                local char = plr.Character
                -- cheap checks first: skip the whole 14-bone projection for players that can't be seen
                -- (culled characters are frozen at their last position, so a skeleton there would be wrong)
                local show = false
                if char and char.Parent and char.Parent.Name ~= "_PVS_CulledCharacters" and IsAlive(plr)
                    and (not IsTeammate(plr) or isCarrier(plr)) then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local rp, on = cam:WorldToViewportPoint(hrp.Position)
                        show = on and rp.Z > 0
                    end
                end
                if not show then
                    if holder.Visible then holder.Visible = false end
                    continue
                end

                local col = getESPColorFor(plr)
                local cache = {}
                local function proj(partName)
                    if cache[partName] ~= nil then return cache[partName] end
                    local part = resolvePart(char, partName)
                    if not part then cache[partName] = false; return false end
                    local pos, onScreen = cam:WorldToViewportPoint(part.Position)
                    if not onScreen or pos.Z < 0 then cache[partName] = false; return false end
                    local v2 = Vector2.new(pos.X, pos.Y)
                    cache[partName] = v2
                    return v2
                end

                local headP = proj("Head")
                local footA = proj("LeftFoot")
                local footB = proj("RightFoot")
                local baseThickness = 2
                if headP and (footA or footB) then
                    local foot = footA or footB
                    local h = math.abs(foot.Y - headP.Y)
                    baseThickness = math.clamp(math.floor(h * 0.012), 1, 3)
                end

                local anyVisible = false
                for i, bone in ipairs(BONES) do
                    local line = holder:FindFirstChild("Bone" .. i)
                    if line then
                        local a = proj(bone[1])
                        local b = proj(bone[2])
                        if a and b then
                            drawLine(line, a, b, baseThickness, col)
                            anyVisible = true
                        else
                            line.Visible = false
                        end
                    end
                end
                holder.Visible = anyVisible
            end
        end)
    else
        if skeletonHeartbeat then skeletonHeartbeat:Disconnect(); skeletonHeartbeat = nil end
        hideAllSkeletons()
    end
end

registerCleanup(function(plr)
    local holderParent = gui:FindFirstChild(SKELETON_GUI_NAME)
    if holderParent then
        local h = holderParent:FindFirstChild(tostring(plr.UserId))
        if h then h.Visible = false end
    end
end)

-- =============================================================================
--  HEALTH BARS
-- =============================================================================
local healthHeartbeat
local healthLastRun = 0
local HEALTH_COOLDOWN = 0.05
local HEALTH_GUI_NAME = "BloxBangHealthBars"

local function ensureHealthHolder()
    local existing = gui:FindFirstChild(HEALTH_GUI_NAME)
    if existing then return existing end
    local f = Instance.new("Frame", gui)
    f.Name = HEALTH_GUI_NAME
    f.BackgroundTransparency = 1
    f.Size = UDim2.fromScale(1, 1)
    f.ZIndex = 2
    return f
end

local function getHealthHolderFor(player)
    local holder = ensureHealthHolder()
    local h = holder:FindFirstChild(tostring(player.UserId))
    if h then return h end
    h = Instance.new("Frame", holder)
    h.Name = tostring(player.UserId)
    h.BackgroundTransparency = 1
    h.BorderSizePixel = 0
    h.Visible = false

    local backdrop = Instance.new("Frame", h)
    backdrop.Name = "Backdrop"
    backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    backdrop.BackgroundTransparency = 0.35
    backdrop.BorderSizePixel = 0
    backdrop.Size = UDim2.fromScale(1, 1)
    corner(backdrop, 2)

    local fill = Instance.new("Frame", h)
    fill.Name = "Fill"
    fill.BackgroundColor3 = HP_GOOD
    fill.BorderSizePixel = 0
    fill.AnchorPoint = Vector2.new(0, 1)
    fill.Position = UDim2.fromScale(0, 1)
    fill.Size = UDim2.fromScale(1, 1)
    corner(fill, 2)

    local s = Instance.new("UIStroke", h)
    s.Name = "Outline"
    s.Thickness = 1
    s.Color = Color3.fromRGB(0, 0, 0)
    s.Transparency = 0.4
    return h
end

local function hideAllHealth()
    local holder = gui:FindFirstChild(HEALTH_GUI_NAME)
    if holder then
        for _, c in ipairs(holder:GetChildren()) do c.Visible = false end
    end
end

local function setHealthBars(on)
    Features.HealthBars = on
    if on then
        if healthHeartbeat then return end
        healthHeartbeat = KING_KC(RunService.RenderStepped, function()
            if not Features.HealthBars then return end
            local now = tick()
            if now - healthLastRun < HEALTH_COOLDOWN then return end
            healthLastRun = now
            local cam = workspace.CurrentCamera
            if not cam then hideAllHealth(); return end

            for _, plr in ipairs(Players:GetPlayers()) do
                if plr == LocalPlayer then continue end
                local bar = getHealthHolderFor(plr)
                bar.Visible = false
                local char = plr.Character
                if not char or not IsAlive(plr) then continue end
                if IsTeammate(plr) and not isCarrier(plr) then continue end

                local head = char:FindFirstChild("Head")
                local hrp  = char:FindFirstChild("HumanoidRootPart")
                if not head or not hrp then continue end

                local headPos, onHead = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 0.6, 0))
                local footPos, onFoot = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 2.6, 0))

                if not onHead or not onFoot or headPos.Z < 0 or footPos.Z < 0 then continue end

                local y1 = headPos.Y
                local y2 = footPos.Y
                local height = math.abs(y2 - y1)
                if height < 6 then continue end

                local width = height * 0.55
                local cx = (headPos.X + footPos.X) / 2
                local x0 = cx - width / 2

                local barW = math.max(4, math.floor(width * 0.06))
                local barX = math.floor(x0 + width + 4)
                local barY = math.floor(y1)
                local barH = math.floor(height)

                bar.Position = UDim2.fromOffset(barX, barY)
                bar.Size = UDim2.fromOffset(barW, barH)

                local hp, mx = 0, 100
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    hp, mx = humanoid.Health, humanoid.MaxHealth
                end
                local pct = math.clamp(hp / math.max(mx, 1), 0, 1)

                local fill = bar:FindFirstChild("Fill")
                if fill then
                    fill.Size = UDim2.fromScale(1, pct)
                    local col
                    if pct > 0.6 then col = HP_GOOD
                    elseif pct > 0.3 then col = HP_MID
                    else col = HP_LOW end
                    fill.BackgroundColor3 = col
                end

                local outline = bar:FindFirstChild("Outline")
                if outline then
                    if crosshairVisible[plr] then
                        outline.Color = C.visRed
                        outline.Thickness = 2
                    elseif isCarrier(plr) then
                        outline.Color = C.bombOrange
                        outline.Thickness = 2
                    else
                        outline.Color = Color3.fromRGB(0, 0, 0)
                        outline.Thickness = 1
                    end
                end

                bar.Visible = true
            end
        end)
    else
        if healthHeartbeat then healthHeartbeat:Disconnect(); healthHeartbeat = nil end
        hideAllHealth()
    end
end

registerCleanup(function(plr)
    local holder = gui:FindFirstChild(HEALTH_GUI_NAME)
    if holder then
        local h = holder:FindFirstChild(tostring(plr.UserId))
        if h then h.Visible = false end
    end
end)

-- =============================================================================
--  TRIGGERBOT
-- =============================================================================
local triggerParams = RaycastParams.new()
triggerParams.FilterType = Enum.RaycastFilterType.Exclude
triggerParams.IgnoreWater = true
triggerParams.RespectCanCollide = false

local function getCrosshairPosition()
    if MOUSE_OK then
        local mouse = UserInputService:GetMouseLocation()
        return Vector2.new(mouse.X, mouse.Y)
    else
        local cam = workspace.CurrentCamera
        if not cam then return nil end
        return Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    end
end

local function TryTriggerOnce()
    if not Features.Triggerbot then return end
    local now = tick()
    if now - Features.LastShotAt < Features.TriggerbotDelay then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local crosshair = getCrosshairPosition()
    if not crosshair then return end
    local ray = cam:ViewportPointToRay(crosshair.X, crosshair.Y)
    local myChar = LocalPlayer.Character
    if not myChar then return end
    triggerParams.FilterDescendantsInstances = { myChar }
    local result = workspace:Raycast(ray.Origin, ray.Direction * Features.TriggerbotRange, triggerParams)
    if not result or not result.Instance then return end
    local targetPlr = getPlayerFromPart(result.Instance)
    if not targetPlr then return end
    if targetPlr == LocalPlayer then return end
    if IsTeammate(targetPlr) then return end
    if not IsAlive(targetPlr) then return end
    local targetChar = targetPlr.Character
    if not targetChar then return end
    if not result.Instance:IsDescendantOf(targetChar) then return end
    local hitPart = result.Instance
    if hitPart.Name == "Head" and Features.BigHeads then
        -- Big Heads only enlarges the head on your screen; the real hitbox keeps its original size,
        -- so only count the shot if the crosshair is inside the ORIGINAL head
        local orig = hitPart:GetAttribute("KingOrigSize") or originalHeadSizes[targetPlr.UserId]
        if orig then
            local lp = hitPart.CFrame:PointToObjectSpace(result.Position)
            if math.abs(lp.X) > orig.X / 2 or math.abs(lp.Y) > orig.Y / 2 or math.abs(lp.Z) > orig.Z / 2 then
                if shared.MH_Log and now - (Features.LastBigHeadLog or 0) > 1 then
                    Features.LastBigHeadLog = now
                    shared.MH_Log(string.format("TRIGGER skipped %s: crosshair on the enlarged head but outside the real head (local %.2f,%.2f,%.2f real half-size %.2f,%.2f,%.2f)",
                        targetPlr.Name, lp.X, lp.Y, lp.Z, orig.X / 2, orig.Y / 2, orig.Z / 2))
                end
                return
            end
        elseif shared.MH_Log and now - (Features.LastBigHeadLog or 0) > 1 then
            Features.LastBigHeadLog = now
            shared.MH_Log("TRIGGER head hit on " .. targetPlr.Name .. " but no original head size recorded (Big Heads did not store one)")
        end
    end
    if Features.TriggerHeadOnly and hitPart.Name ~= "Head" then return end
    Features.LastShotAt = now
    if shared.MH_Log then shared.MH_Log(string.format("TRIGGER fire at %s part=%s dist=%.0f bigheads=%s headOnly=%s", targetPlr.Name, hitPart.Name, (result.Position - ray.Origin).Magnitude, tostring(Features.BigHeads), tostring(Features.TriggerHeadOnly))) end
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(crosshair.X, crosshair.Y, 0, true, game, 1)
        task.wait(0.01)
        VirtualInputManager:SendMouseButtonEvent(crosshair.X, crosshair.Y, 0, false, game, 1)
    end)
end

local triggerHeartbeat
local TRIGGER_COOLDOWN = 0.02
local triggerLastRun = 0

local function setTriggerbot(on)
    Features.Triggerbot = on
    if on then
        if triggerHeartbeat then return end
        triggerHeartbeat = KING_KC(RunService.Heartbeat, function()
            if not Features.Triggerbot then return end
            local now = tick()
            if now - triggerLastRun < TRIGGER_COOLDOWN then return end
            triggerLastRun = now
            pcall(TryTriggerOnce)
        end)
    else
        if triggerHeartbeat then triggerHeartbeat:Disconnect(); triggerHeartbeat = nil end
    end
end

-- =============================================================================
--  CROSSHAIR VISIBILITY UPDATER
-- =============================================================================
KING_KC(RunService.Heartbeat, function()
    pcall(refreshCrosshairVisibility)
end)

-- =============================================================================
--  PLANTED BOMB ESP
-- =============================================================================
local plantedBomb = nil
local plantedBillboard = nil
local plantedBeam = nil
local plantedLastScan = 0
local PLANTED_SCAN_INTERVAL = 0.5

local function hasC4Shape(model)
    if not model or not model:IsA("Model") then return false end
    local weapon = model:FindFirstChild("Weapon")
    if not weapon or not weapon:IsA("Model") then return false end
    return weapon:FindFirstChild("Screen") ~= nil
       and weapon:FindFirstChild("FlashingLight") ~= nil
       and weapon:FindFirstChild("Switch") ~= nil
       and weapon:FindFirstChild("Body") ~= nil
end

local function findPlantedBomb()
    local deb = workspace:FindFirstChild("Debris")
    if deb then
        for _, c in ipairs(deb:GetChildren()) do
            if c:IsA("Model") and not c.Name:find("_WeaponAttachments") then
                if hasC4Shape(c) then return c end
            end
        end
    end
    local map = workspace:FindFirstChild("Map")
    if map then
        for _, c in ipairs(map:GetChildren()) do
            if hasC4Shape(c) then return c end
        end
    end
    for _, c in ipairs(workspace:GetChildren()) do
        if hasC4Shape(c) then return c end
    end
    return nil
end

local function makePlantedBillboard(part)
    if plantedBillboard then plantedBillboard:Destroy() end
    local bb = Instance.new("BillboardGui")
    bb.Name = "KingBombMarker"
    bb.Size = UDim2.fromOffset(180, 40)
    bb.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.Adornee = part
    bb.Parent = gui

    local main = Instance.new("TextLabel", bb)
    main.Name = "Main"
    main.BackgroundTransparency = 1
    main.Size = UDim2.new(1, 0, 0.6, 0)
    main.Font = Enum.Font.GothamBlack
    main.TextSize = 18
    main.TextColor3 = C.bombOrange
    main.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    main.TextStrokeTransparency = 0.2
    main.Text = "💣 BOMB"

    local sub = Instance.new("TextLabel", bb)
    sub.Name = "Sub"
    sub.BackgroundTransparency = 1
    sub.Size = UDim2.new(1, 0, 0.4, 0)
    sub.Position = UDim2.new(0, 0, 0.6, 0)
    sub.Font = Enum.Font.Code
    sub.TextSize = 12
    sub.TextColor3 = Color3.fromRGB(255, 200, 100)
    sub.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    sub.TextStrokeTransparency = 0.3
    sub.Text = "--- m"

    plantedBillboard = bb
end

local function makePlantedBeam(part)
    if plantedBeam then plantedBeam:Destroy() end
    local beam = Instance.new("Part")
    beam.Name = "KingBombBeam"
    beam.Anchored = true
    beam.CanCollide = false
    beam.CanQuery = false
    beam.CanTouch = false
    beam.Material = Enum.Material.Neon
    beam.Color = C.bombOrange
    beam.Transparency = 0.3
    beam.Size = Vector3.new(0.4, 100, 0.4)
    beam.Position = part.Position + Vector3.new(0, 50, 0)
    beam.Parent = workspace
    plantedBeam = beam
end

local function clearPlantedBomb()
    if plantedBillboard then plantedBillboard:Destroy(); plantedBillboard = nil end
    if plantedBeam then plantedBeam:Destroy(); plantedBeam = nil end
    plantedBomb = nil
end

local function runPlantedBombESP()
    if not Features.PlantedBombESP then
        if plantedBomb then clearPlantedBomb() end
        return
    end
    local now = tick()
    if now - plantedLastScan < PLANTED_SCAN_INTERVAL then return end
    plantedLastScan = now

    local found = findPlantedBomb()
    if found then
        if found ~= plantedBomb then
            clearPlantedBomb()
            plantedBomb = found
            makePlantedBillboard(found)
            makePlantedBeam(found)
        end
        if plantedBillboard then
            local sub = plantedBillboard:FindFirstChild("Sub")
            if sub then
                local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if myHRP then
                    local d = (myHRP.Position - found.Position).Magnitude
                    sub.Text = string.format("[%dm]", math.floor(d))
                end
            end
        end
    else
        if plantedBomb then clearPlantedBomb() end
    end
end

-- =============================================================================
--  GRENADE ESP
-- =============================================================================
local grenadeMarkers = {}

local function getGrenadePosition(instance)
    if instance:IsA("BasePart") then return instance.Position end
    if instance:IsA("Model") or instance:IsA("Folder") then
        local sum, count = Vector3.new(0,0,0), 0
        for _, d in ipairs(instance:GetChildren()) do
            if d:IsA("BasePart") then
                sum = sum + d.Position
                count = count + 1
                if count >= 6 then break end
            end
        end
        if count > 0 then return sum / count end
    end
    return nil
end

local function makeGrenadeMarker(instance, kind)
    if grenadeMarkers[instance] then return end

    local cfg = {
        smoke = { text = "💨 SMOKE", color = C.smokeBlue },
        fire  = { text = "🔥 FIRE",  color = C.fireOrange },
        flash = { text = "💥 FLASH", color = C.flashYell },
    }
    local c = cfg[kind]
    if not c then return end

    local bb = Instance.new("BillboardGui")
    bb.Name = "KingGrenadeMarker_" .. kind
    bb.Size = UDim2.fromOffset(140, 32)
    bb.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.Adornee = instance
    bb.Parent = gui

    local main = Instance.new("TextLabel", bb)
    main.Name = "Main"
    main.BackgroundTransparency = 1
    main.Size = UDim2.new(1, 0, 0.6, 0)
    main.Font = Enum.Font.GothamBlack
    main.TextSize = 14
    main.TextColor3 = c.color
    main.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    main.TextStrokeTransparency = 0.15
    main.Text = c.text

    local sub = Instance.new("TextLabel", bb)
    sub.Name = "Sub"
    sub.BackgroundTransparency = 1
    sub.Size = UDim2.new(1, 0, 0.4, 0)
    sub.Position = UDim2.new(0, 0, 0.6, 0)
    sub.Font = Enum.Font.Code
    sub.TextSize = 11
    sub.TextColor3 = c.color
    sub.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    sub.TextStrokeTransparency = 0.25
    sub.Text = "--- m"

    grenadeMarkers[instance] = { bb = bb, label = sub, kind = kind }

    KING_KC(instance.AncestryChanged, function()
        if not instance:IsDescendantOf(game) then
            local m = grenadeMarkers[instance]
            if m and m.bb then m.bb:Destroy() end
            grenadeMarkers[instance] = nil
        end
    end)
end

local function destroyGrenadeMarker(instance)
    local m = grenadeMarkers[instance]
    if m and m.bb then m.bb:Destroy() end
    grenadeMarkers[instance] = nil
end

local function refreshGrenadeMarkers()
    if not (Features.GrenadeSmokeESP or Features.GrenadeFireESP or Features.GrenadeFlashESP) then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local myChar = LocalPlayer.Character
    local myPos = myChar and myChar:FindFirstChild("HumanoidRootPart") and myChar.HumanoidRootPart.Position or nil

    for instance, m in pairs(grenadeMarkers) do
        if not instance.Parent then
            destroyGrenadeMarker(instance)
        else
            local enabled = false
            if m.kind == "smoke" then enabled = Features.GrenadeSmokeESP
            elseif m.kind == "fire" then enabled = Features.GrenadeFireESP
            elseif m.kind == "flash" then enabled = Features.GrenadeFlashESP end

            if not enabled then
                if m.bb then m.bb.Enabled = false end
            else
                if m.bb then m.bb.Enabled = true end
                if myPos then
                    local pos = getGrenadePosition(instance)
                    if pos then
                        local d = (pos - myPos).Magnitude
                        if m.label then
                            m.label.Text = string.format("[%dm]", math.floor(d))
                        end
                    end
                end
            end
        end
    end
end

local grenadeDebrisConn
local grenadeHeartbeat

local function handleDebrisChild(c)
    if not c then return end
    local n = c.Name
    if n:find("VoxelSmoke_") then
        makeGrenadeMarker(c, "smoke")
    elseif n:find("VoxelFire_") then
        makeGrenadeMarker(c, "fire")
    elseif n == "Flashbang" then
        makeGrenadeMarker(c, "flash")
    end
end

local function scanDebrisForGrenades()
    local deb = workspace:FindFirstChild("Debris")
    if not deb then return end
    for _, c in ipairs(deb:GetChildren()) do
        handleDebrisChild(c)
    end
end

local function enableGrenadeWatch()
    if grenadeDebrisConn then return end
    local deb = workspace:FindFirstChild("Debris")
    if deb then
        grenadeDebrisConn = KING_KC(deb.ChildAdded, handleDebrisChild)
        scanDebrisForGrenades()
    else
        task.spawn(function()
            local d = workspace:WaitForChild("Debris", 30)
            if d and not grenadeDebrisConn then
                grenadeDebrisConn = KING_KC(d.ChildAdded, handleDebrisChild)
                scanDebrisForGrenades()
            end
        end)
    end
end

local function disableGrenadeWatch()
    if grenadeDebrisConn then grenadeDebrisConn:Disconnect(); grenadeDebrisConn = nil end
    for instance, _ in pairs(grenadeMarkers) do
        destroyGrenadeMarker(instance)
    end
    grenadeMarkers = {}
end

local function isGrenadeESPActive()
    return Features.GrenadeSmokeESP or Features.GrenadeFireESP or Features.GrenadeFlashESP
end

local function ensureGrenadeHeartbeat()
    if grenadeHeartbeat then return end
    grenadeHeartbeat = KING_KC(RunService.Heartbeat, function()
        if not isGrenadeESPActive() then
            if grenadeDebrisConn then
                disableGrenadeWatch()
            end
            return
        end
        enableGrenadeWatch()
        pcall(refreshGrenadeMarkers)
    end)
end

local function setGrenadeESP(kind, on)
    if kind == "smoke" then
        Features.GrenadeSmokeESP = on
    elseif kind == "fire" then
        Features.GrenadeFireESP = on
    elseif kind == "flash" then
        Features.GrenadeFlashESP = on
    end

    if on then
        ensureGrenadeHeartbeat()
        enableGrenadeWatch()
        scanDebrisForGrenades()
        task.spawn(function()
            task.wait(0.05)
            pcall(refreshGrenadeMarkers)
        end)
    else
        for instance, m in pairs(grenadeMarkers) do
            if m.kind == kind and m.bb then
                m.bb:Destroy()
            end
            if m.kind == kind then
                grenadeMarkers[instance] = nil
            end
        end
        if not isGrenadeESPActive() then
            disableGrenadeWatch()
        end
    end
end

-- =============================================================================
--  FLASHBANG NEUTRALIZER
-- =============================================================================
local function killFlashbangGuis()
    if not Features.NoFlash then return end
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end
    for _, name in ipairs({"FlashbangEffect", "FlashScreenshot"}) do
        local g = pg:FindFirstChild(name)
        if g then
            pcall(function() g:Destroy() end)
        end
    end
end

local function killFlashbangLighting()
    if not Features.NoFlash then return end
    local cc = Lighting:FindFirstChild("FlashbangColorCorrection")
    if cc then pcall(function() cc:Destroy() end) end
end

local function killFlashbangOnGuiElement(d)
    if not Features.NoFlash then return end
    if d.Name == "FlashOverlay" and d:IsA("Frame") then
        pcall(function() d.BackgroundTransparency = 1 end)
        pcall(function()
            KING_KC(d:GetPropertyChangedSignal("BackgroundTransparency"), function()
                if Features.NoFlash then d.BackgroundTransparency = 1 end
            end)
        end)
    elseif d.Name == "ScreenshotImage" and d:IsA("ImageLabel") then
        pcall(function() d.ImageTransparency = 1 end)
        pcall(function()
            KING_KC(d:GetPropertyChangedSignal("ImageTransparency"), function()
                if Features.NoFlash then d.ImageTransparency = 1 end
            end)
        end)
    end
end

local flashGuiConn, flashLightingConn, flashDescConn

local function enableNoFlash()
    killFlashbangGuis()
    killFlashbangLighting()

    flashLightingConn = KING_KC(Lighting.ChildAdded, function(c)
        if not Features.NoFlash then return end
        if c.Name == "FlashbangColorCorrection" then
            pcall(function() c:Destroy() end)
        end
    end)

    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        flashGuiConn = KING_KC(pg.ChildAdded, function(c)
            if not Features.NoFlash then return end
            if c.Name == "FlashbangEffect" or c.Name == "FlashScreenshot" then
                pcall(function() c:Destroy() end)
            end
        end)
        for _, d in ipairs(pg:GetDescendants()) do
            killFlashbangOnGuiElement(d)
        end
        flashDescConn = KING_KC(pg.DescendantAdded, killFlashbangOnGuiElement)
    end
end

local function disableNoFlash()
    if flashLightingConn then flashLightingConn:Disconnect(); flashLightingConn = nil end
    if flashGuiConn then flashGuiConn:Disconnect(); flashGuiConn = nil end
    if flashDescConn then flashDescConn:Disconnect(); flashDescConn = nil end
end

local function setNoFlash(on)
    if on == Features.NoFlash then return end
    Features.NoFlash = on
    if on then enableNoFlash() else disableNoFlash() end
end

-- =============================================================================
--  SMOKE / FIRE SEE-THROUGH
-- =============================================================================
local smokeFireConn
local activeSmokeFolders = {}
local activeFireFolders  = {}

local function killParticlesIn(folder)
    if not folder then return end
    for _, d in ipairs(folder:GetDescendants()) do
        if d:IsA("ParticleEmitter") then
            pcall(function() d.Enabled = false end)
        end
    end
end

local function registerEffectFolder(folder)
    if not folder then return end
    local n = folder.Name
    if n:find("VoxelSmoke_") then
        activeSmokeFolders[folder] = true
    elseif n:find("VoxelFire_") then
        activeFireFolders[folder] = true
    else
        return
    end
    KING_KC(folder.AncestryChanged, function()
        if not folder:IsDescendantOf(game) then
            activeSmokeFolders[folder] = nil
            activeFireFolders[folder] = nil
        end
    end)
end

local function scanDebrisForEffects()
    local deb = workspace:FindFirstChild("Debris")
    if not deb then return end
    for _, c in ipairs(deb:GetChildren()) do
        local n = c.Name
        if n:find("VoxelSmoke_") then
            activeSmokeFolders[c] = true
            KING_KC(c.AncestryChanged, function()
                if not c:IsDescendantOf(game) then activeSmokeFolders[c] = nil end
            end)
        elseif n:find("VoxelFire_") then
            activeFireFolders[c] = true
            KING_KC(c.AncestryChanged, function()
                if not c:IsDescendantOf(game) then activeFireFolders[c] = nil end
            end)
        end
    end
end

local function enableSmokeFireWatch()
    if smokeFireConn then return end

    local deb = workspace:FindFirstChild("Debris")
    if deb then
        smokeFireConn = KING_KC(deb.ChildAdded, registerEffectFolder)
    else
        task.spawn(function()
            local d = workspace:WaitForChild("Debris", 30)
            if d and not smokeFireConn then
                smokeFireConn = KING_KC(d.ChildAdded, registerEffectFolder)
                scanDebrisForEffects()
            end
        end)
    end

    scanDebrisForEffects()

    KING_KC(RunService.Heartbeat, function()
        if Features.SeeThroughSmoke then
            for folder in pairs(activeSmokeFolders) do
                if not folder.Parent then
                    activeSmokeFolders[folder] = nil
                else
                    killParticlesIn(folder)
                end
            end
        end
        if Features.SeeThroughFire then
            for folder in pairs(activeFireFolders) do
                if not folder.Parent then
                    activeFireFolders[folder] = nil
                else
                    killParticlesIn(folder)
                end
            end
        end
    end)
end

local function disableSmokeFireWatch()
    if smokeFireConn then smokeFireConn:Disconnect(); smokeFireConn = nil end
    activeSmokeFolders = {}
    activeFireFolders  = {}
    if not Features.SeeThroughSmoke and not Features.SeeThroughFire then
        local deb = workspace:FindFirstChild("Debris")
        if deb then
            for _, c in ipairs(deb:GetChildren()) do
                if c.Name:find("VoxelSmoke_") or c.Name:find("VoxelFire_") then
                    for _, d in ipairs(c:GetDescendants()) do
                        if d:IsA("ParticleEmitter") then
                            pcall(function() d.Enabled = true end)
                        end
                    end
                end
            end
        end
    end
end

local function setSeeThroughSmoke(on)
    if on == Features.SeeThroughSmoke then return end
    Features.SeeThroughSmoke = on
    if on then
        enableSmokeFireWatch()
        local deb = workspace:FindFirstChild("Debris")
        if deb then
            for _, c in ipairs(deb:GetChildren()) do
                if c.Name:find("VoxelSmoke_") then killParticlesIn(c) end
            end
        end
    else
        if not Features.SeeThroughFire then
            disableSmokeFireWatch()
        end
    end
end

local function setSeeThroughFire(on)
    if on == Features.SeeThroughFire then return end
    Features.SeeThroughFire = on
    if on then
        enableSmokeFireWatch()
        local deb = workspace:FindFirstChild("Debris")
        if deb then
            for _, c in ipairs(deb:GetChildren()) do
                if c.Name:find("VoxelFire_") then killParticlesIn(c) end
            end
        end
    else
        if not Features.SeeThroughSmoke then
            disableSmokeFireWatch()
        end
    end
end

-- =============================================================================
--  FULL BRIGHT
-- =============================================================================
local fullBrightState = { On = false, Old = nil, Effect = nil, Conn = nil }

local function captureLighting()
    return {
        Ambient             = Lighting.Ambient,
        OutdoorAmbient      = Lighting.OutdoorAmbient,
        Brightness          = Lighting.Brightness,
        GlobalShadows       = Lighting.GlobalShadows,
        FogEnd              = Lighting.FogEnd,
        FogStart            = Lighting.FogStart,
        FogColor            = Lighting.FogColor,
        ClockTime           = Lighting.ClockTime,
        ExposureCompensation= Lighting.ExposureCompensation,
        EnvironmentDiffuseScale  = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
    }
end

local function applyFullBright()
    Lighting.Ambient        = Color3.fromRGB(180, 180, 180)
    Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
    Lighting.Brightness     = 3
    Lighting.GlobalShadows  = false
    Lighting.FogEnd         = 100000
    Lighting.FogStart       = 100000
    Lighting.FogColor       = Color3.fromRGB(255, 255, 255)
    Lighting.ClockTime      = 14
    Lighting.ExposureCompensation = 0
    Lighting.EnvironmentDiffuseScale  = 1
    Lighting.EnvironmentSpecularScale = 1

    if fullBrightState.Effect then fullBrightState.Effect:Destroy() end
    local cc = Instance.new("ColorCorrectionEffect")
    cc.Name = "KingFullBright"
    cc.Brightness = 0.15
    cc.Contrast = 0.05
    cc.Saturation = 0.05
    cc.TintColor = Color3.fromRGB(255, 255, 255)
    cc.Parent = Lighting
    fullBrightState.Effect = cc

    if fullBrightState.Conn then fullBrightState.Conn:Disconnect() end
    fullBrightState.Conn = KING_KC(Lighting:GetPropertyChangedSignal("Brightness"), function()
        if fullBrightState.On then
            Lighting.Brightness = 3
            Lighting.Ambient = Color3.fromRGB(180, 180, 180)
            Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
            Lighting.GlobalShadows = false
        end
    end)
end

local function restoreFullBright()
    if fullBrightState.Conn then fullBrightState.Conn:Disconnect(); fullBrightState.Conn = nil end
    if fullBrightState.Effect then fullBrightState.Effect:Destroy(); fullBrightState.Effect = nil end
    if fullBrightState.Old then
        for k, v in pairs(fullBrightState.Old) do
            pcall(function() Lighting[k] = v end)
        end
    end
end

local function setFullBright(on)
    if on == fullBrightState.On then return end
    fullBrightState.On = on
    if on then
        fullBrightState.Old = captureLighting()
        applyFullBright()
    else
        restoreFullBright()
    end
end

-- =============================================================================
--  FPS BOOST
-- =============================================================================
local fpsBoostState = { On = false }

local function applyFPSBoost()
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
        Lighting.FogStart = 100000
        Lighting.Brightness = 1
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
        Lighting.OutdoorAmbient = Color3.fromRGB(128,128,128)
        Lighting.ShadowSoftness = 0
    end)
    for _, v in pairs(Lighting:GetChildren()) do
        if v:IsA("BlurEffect") or v:IsA("BloomEffect") or v:IsA("SunRaysEffect")
        or v:IsA("DepthOfFieldEffect") or v:IsA("ColorCorrectionEffect") then
            pcall(function() v.Enabled = false end)
        end
    end
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Smoke")
        or d:IsA("Fire") or d:IsA("Sparkles") then
            pcall(function() d.Enabled = false end)
        elseif d:IsA("Decal") or d:IsA("Texture") then
            pcall(function() d.Transparency = 1 end)
        elseif d:IsA("Explosion") then
            pcall(function() d:Destroy() end)
        end
    end
    pcall(function()
        Workspace.Terrain.WaterWaveSize = 0
        Workspace.Terrain.WaterWaveSpeed = 0
        Workspace.Terrain.WaterReflectance = 0
        Workspace.Terrain.WaterTransparency = 1
    end)
end

local function restoreFPSBoost()
    pcall(function()
        Lighting.GlobalShadows = true
        Lighting.FogEnd = 100000
        Lighting.FogStart = 0
        Lighting.Brightness = 2
        Lighting.EnvironmentDiffuseScale = 1
        Lighting.EnvironmentSpecularScale = 1
    end)
    for _, v in pairs(Lighting:GetChildren()) do
        if v:IsA("BlurEffect") or v:IsA("BloomEffect") or v:IsA("SunRaysEffect")
        or v:IsA("DepthOfFieldEffect") or v:IsA("ColorCorrectionEffect") then
            pcall(function() v.Enabled = true end)
        end
    end
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Smoke")
        or d:IsA("Fire") or d:IsA("Sparkles") then
            pcall(function() d.Enabled = true end)
        elseif d:IsA("Decal") or d:IsA("Texture") then
            pcall(function() d.Transparency = 0 end)
        end
    end
end

-- =============================================================================
--  CLEANUP
-- =============================================================================
local function cleanupAll()
    if shared.MH_BoxChamsOff then pcall(shared.MH_BoxChamsOff) end
    if Features.BigHeads then setBigHeads(false) end
    if Features.Outlines then setOutlines(false) end
    if Features.NameTags then setNametags(false) end
    if Features.HealthBars then setHealthBars(false) end
    if Features.SkeletonESP then setSkeletonESP(false) end
    if Features.Triggerbot then setTriggerbot(false) end
    if Features.PlantedBombESP then Features.PlantedBombESP = false; clearPlantedBomb() end
    if Features.NoFlash then setNoFlash(false) end
    if Features.SeeThroughSmoke then setSeeThroughSmoke(false) end
    if Features.SeeThroughFire then setSeeThroughFire(false) end
    if Features.GrenadeSmokeESP then setGrenadeESP("smoke", false) end
    if Features.GrenadeFireESP then setGrenadeESP("fire", false) end
    if Features.GrenadeFlashESP then setGrenadeESP("flash", false) end
    if fullBrightState.On then setFullBright(false) end
    if fpsBoostState.On then fpsBoostState.On = false; restoreFPSBoost() end
    Notify("All features disabled", 2, C.red)
end

-- =============================================================================
--  VISUALS TAB
-- =============================================================================
toggle(VIS_TAB, "Outlines (Chams)", true, function(v) setOutlines(v) end)
toggle(VIS_TAB, "Name Tags (ESP)",  true, function(v) setNametags(v) end)
toggle(VIS_TAB, "Skeleton ESP",     true, function(v) setSkeletonESP(v) end)
toggle(VIS_TAB, "Health Bars",      true, function(v) setHealthBars(v) end)
toggle(VIS_TAB, "Red When Sighted", true, function(v)
    Features.RedWhenSighted = v
    if not v then for k in pairs(crosshairVisible) do crosshairVisible[k] = nil end end
end)
toggle(VIS_TAB, "Full Bright", true, function(v) setFullBright(v) end)
toggle(VIS_TAB, "Team Check", true, function(v) Features.TeamCheck = v end)

-- =============================================================================
--  COMBAT TAB
-- =============================================================================
toggle(COMBAT_TAB, "Big Heads (visual only - does not change real hits)", false, function(v) setBigHeads(v) end)
toggle(COMBAT_TAB, "Enable Triggerbot", true, function(v) setTriggerbot(v) end)
toggle(COMBAT_TAB, "Triggerbot: head only", false, function(v) Features.TriggerHeadOnly = v end)
setTriggerbot(true) -- always on at startup

Features.TriggerbotDelay = 0
Features.TriggerbotRange = 1000
slider(COMBAT_TAB, "Fire Delay", 0.00, 0.50, 0.00, function(v)
    Features.TriggerbotDelay = v
end, function(v) return string.format("%.2fs", v) end)

slider(COMBAT_TAB, "Max Range", 10, 1000, 1000, function(v)
    Features.TriggerbotRange = v
end, function(v) return string.format("%d st", math.floor(v)) end)

local trigKb = keybind(COMBAT_TAB, "Triggerbot Keybind", Enum.KeyCode.C, function(k)
    Features.TriggerbotKey = k
    Notify("Triggerbot key set to " .. k.Name, 2, C.green)
end)
Features.TriggerbotKey = trigKb.Value() or Enum.KeyCode.C

-- =============================================================================
--  BOMB TAB
-- =============================================================================
toggle(BOMB_TAB, "Show Bomb Carrier", true, function(v)
    Features.BombCarrierESP = v
end)
toggle(BOMB_TAB, "Show Planted Bomb", true, function(v)
    Features.PlantedBombESP = v
end)

-- =============================================================================
--  EFFECTS TAB
-- =============================================================================
toggle(EFFECT_TAB, "No Flash Blind", true, function(v) setNoFlash(v) end)
toggle(EFFECT_TAB, "See Through Smoke", true, function(v) setSeeThroughSmoke(v) end)
toggle(EFFECT_TAB, "See Through Fire",  true, function(v) setSeeThroughFire(v) end)
toggle(EFFECT_TAB, "Smoke Grenade ESP", true, function(v) setGrenadeESP("smoke", v) end)
toggle(EFFECT_TAB, "Fire Grenade ESP",  true, function(v) setGrenadeESP("fire", v) end)
toggle(EFFECT_TAB, "Flashbang ESP",     true, function(v) setGrenadeESP("flash", v) end)
button(EFFECT_TAB, "⚡  Apply FPS Boost", function()
    applyFPSBoost()
    fpsBoostState.On = true
    Notify("FPS Boost applied", 3, C.green)
end)
button(EFFECT_TAB, "🔄  Restore Graphics", function()
    restoreFPSBoost()
    fpsBoostState.On = false
    Notify("Graphics restored", 3, C.gold)
end)

-- =============================================================================
--  STARTUP: everything on by default (each wrapped so one failure can't stop the rest)
-- =============================================================================
Features.TeamCheck       = true
Features.BombCarrierESP  = true
Features.PlantedBombESP  = true
for idx, fn in ipairs({
    function() setOutlines(true) end,
    function() setNametags(true) end,
    function() setSkeletonESP(true) end,
    function() setHealthBars(true) end,
    function() setFullBright(true) end,
    function() setNoFlash(true) end,
    function() setSeeThroughSmoke(true) end,
    function() setSeeThroughFire(true) end,
    function() setGrenadeESP("smoke", true) end,
    function() setGrenadeESP("fire", true) end,
    function() setGrenadeESP("flash", true) end,
    function() applyFPSBoost(); fpsBoostState.On = true end,
}) do
    local okF, errF = pcall(fn)
    if not okF then shared.MH_Log('startup feature #' .. idx .. ' failed: ' .. tostring(errF)) end
end
shared.MH_Log('startup features applied')

-- =============================================================================
--  SKINS TAB  (local / cosmetic only: re-textures your own viewmodel client-side)
--  Uses the game's own assets: ReplicatedStorage.Assets.Skins.<Weapon>.<Skin>.Camera.<Wear>
--  No remotes are fired; other players will not see these skins.
-- =============================================================================
shared.MH_Try('Skins tab', function()
    local SKIN_TAB = createTab("🎨", "Skins")
    local RS = game:GetService("ReplicatedStorage")
    local SkinsRoot = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("Skins")
    local WEARS = {"Factory New", "Minimal Wear", "Field-Tested", "Well-Worn", "Battle-Scarred"}
    local overrides = {}   -- [weapon] = {skin=, wear=}
    local originals = setmetatable({}, {__mode = "k"}) -- [meshPart] = original SurfaceAppearance clone
    local weaponList, selWeapon, selSkin, selWear = {}, nil, nil, 1

    local function skinList(weapon)
        local out = {}
        local w = SkinsRoot and SkinsRoot:FindFirstChild(weapon)
        if w then
            for _, s in ipairs(w:GetChildren()) do
                if s:IsA("Folder") and s:FindFirstChild("Camera") then out[#out + 1] = s.Name end
            end
            table.sort(out)
        end
        return out
    end

    if SkinsRoot then
        for _, w in ipairs(SkinsRoot:GetChildren()) do
            if w:IsA("Folder") and #skinList(w.Name) > 0 then weaponList[#weaponList + 1] = w.Name end
        end
        table.sort(weaponList)
    end

    local function wearFolder(weapon, skin, wearName)
        local cam = SkinsRoot[weapon][skin]:FindFirstChild("Camera")
        if not cam then return nil end
        return cam:FindFirstChild(wearName) or cam:FindFirstChildOfClass("Folder")
    end

    local function applyToModel(model, weapon, ov)
        local key = weapon .. "|" .. ov.skin .. "|" .. ov.wear
        if model:GetAttribute("LocalSkin") == key then return end
        local wf = wearFolder(weapon, ov.skin, ov.wear)
        if not wf then return end
        for _, sa in ipairs(wf:GetChildren()) do
            if sa:IsA("SurfaceAppearance") then
                for _, part in ipairs(model:GetDescendants()) do
                    if part:IsA("MeshPart") and part.Name == sa.Name then
                        local old = part:FindFirstChildOfClass("SurfaceAppearance")
                        if old then
                            if not originals[part] then originals[part] = old:Clone() end
                            old:Destroy()
                        end
                        sa:Clone().Parent = part
                    end
                end
            end
        end
        model:SetAttribute("LocalSkin", key)
    end

    local skinConn
    local function ensureLoop()
        if skinConn then return end
        local acc = 0
        skinConn = KING_KC(RunService.Heartbeat, function(dt)
            acc += dt
            if acc < 0.25 then return end
            acc = 0
            local cam = workspace.CurrentCamera
            if not cam then return end
            for _, m in ipairs(cam:GetChildren()) do
                local ov = m:IsA("Model") and overrides[m.Name]
                if ov then pcall(applyToModel, m, m.Name, ov) end
            end
        end)
    end

    local function resetAll()
        overrides = {}
        local cam = workspace.CurrentCamera
        if cam then
            for _, m in ipairs(cam:GetChildren()) do
                if m:IsA("Model") and m:GetAttribute("LocalSkin") then
                    for _, part in ipairs(m:GetDescendants()) do
                        local orig = part:IsA("MeshPart") and originals[part]
                        if orig then
                            local cur = part:FindFirstChildOfClass("SurfaceAppearance")
                            if cur then cur:Destroy() end
                            orig:Clone().Parent = part
                        end
                    end
                    m:SetAttribute("LocalSkin", nil)
                end
            end
        end
        if skinConn then skinConn:Disconnect(); skinConn = nil end
    end

    -- startup: a random skin for every weapon
    pcall(function()
        math.randomseed(os.clock() * 1000)
        for _, w in ipairs(weaponList) do
            local list = skinList(w)
            if #list > 0 then
                overrides[w] = {skin = list[math.random(#list)], wear = WEARS[1]}
                shared.MH_Log('random skin: ' .. w .. ' -> ' .. overrides[w].skin)
            end
        end
        ensureLoop()
    end)

    if #weaponList == 0 then
        button(SKIN_TAB, "No skin assets found in this game", function() end)
        return
    end

    local function mkFrame(parent, h, order)
        local f = Instance.new("Frame", parent)
        f.Size = UDim2.new(1, 0, 0, h)
        f.BackgroundColor3 = C.dark
        f.BackgroundTransparency = 0.15
        f.BorderSizePixel = 0
        f.LayoutOrder = order or nextOrder()
        corner(f, 4)
        stroke(f, C.tealDim, 1, 0.85)
        return f
    end

    local function mkList(parent, pos, size)
        local sf = Instance.new("ScrollingFrame", parent)
        sf.Position, sf.Size = pos, size
        sf.BackgroundTransparency = 1
        sf.BorderSizePixel = 0
        sf.ScrollBarThickness = 4
        sf.ScrollBarImageColor3 = C.teal
        sf.CanvasSize = UDim2.new()
        sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
        local l = Instance.new("UIListLayout", sf)
        l.Padding = UDim.new(0, 3)
        return sf
    end

    local selWeapon = weaponList[1]
    local selSkin, selWear = nil, 1
    local filter = ""

    -- status row
    local status = mkFrame(SKIN_TAB, 36)
    local statusLbl = Instance.new("TextLabel", status)
    statusLbl.Size = UDim2.new(1, -24, 1, 0)
    statusLbl.Position = UDim2.fromOffset(12, 0)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Font = Enum.Font.GothamMedium
    statusLbl.TextSize = 12
    statusLbl.TextColor3 = C.text
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.RichText = true

    -- search
    local searchRow = mkFrame(SKIN_TAB, 34)
    local search = Instance.new("TextBox", searchRow)
    search.Size = UDim2.new(1, -24, 1, 0)
    search.Position = UDim2.fromOffset(12, 0)
    search.BackgroundTransparency = 1
    search.PlaceholderText = "🔍  Search weapons or skins..."
    search.PlaceholderColor3 = C.textDim
    search.Text = ""
    search.ClearTextOnFocus = false
    search.Font = Enum.Font.Gotham
    search.TextSize = 12
    search.TextColor3 = C.text
    search.TextXAlignment = Enum.TextXAlignment.Left

    -- pick lists
    local pick = mkFrame(SKIN_TAB, 230)
    local wList = mkList(pick, UDim2.fromOffset(6, 6), UDim2.new(0.4, -9, 1, -12))
    local sList = mkList(pick, UDim2.new(0.4, 3, 0, 6), UDim2.new(0.6, -9, 1, -12))

    -- wear row
    local wearRow = mkFrame(SKIN_TAB, 34)
    local wl = Instance.new("UIListLayout", wearRow)
    wl.FillDirection = Enum.FillDirection.Horizontal
    wl.Padding = UDim.new(0, 4)
    wl.VerticalAlignment = Enum.VerticalAlignment.Center
    local wp = Instance.new("UIPadding", wearRow)
    wp.PaddingLeft, wp.PaddingRight = UDim.new(0, 5), UDim.new(0, 5)
    local wearBtns = {}
    local WEAR_SHORT = {"FN", "MW", "FT", "WW", "BS"}

    local rebuildSkins, refresh

    local function doApply()
        if not selSkin then return end
        overrides[selWeapon] = {skin = selSkin, wear = WEARS[selWear]}
        ensureLoop()
    end

    local function styleItem(b, on)
        b.BackgroundColor3 = on and C.teal or C.panel
        b.BackgroundTransparency = on and 0.55 or 0.3
        b.TextColor3 = on and C.white or C.text
    end

    local function mkItem(parent, text, on, onClick)
        local b = Instance.new("TextButton", parent)
        b.Size = UDim2.new(1, -6, 0, 28)
        b.Text = "  " .. text
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.Font = Enum.Font.Gotham
        b.TextSize = 11
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        corner(b, 3)
        styleItem(b, on)
        KING_KC(b.MouseButton1Click, onClick)
        return b
    end

    local function matches(name, owner)
        if filter == "" then return true end
        return name:lower():find(filter, 1, true) or (owner and owner:lower():find(filter, 1, true))
    end

    local function rebuildWeapons()
        for _, c in ipairs(wList:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        for _, w in ipairs(weaponList) do
            local hasSkinMatch = false
            if filter ~= "" then
                for _, s in ipairs(skinList(w)) do if matches(s) then hasSkinMatch = true break end end
            end
            if filter == "" or matches(w) or hasSkinMatch then
                mkItem(wList, w, w == selWeapon, function()
                    selWeapon = w
                    selSkin = (overrides[w] and overrides[w].skin) or nil
                    rebuildWeapons(); rebuildSkins(); refresh()
                end)
            end
        end
    end

    function rebuildSkins()
        for _, c in ipairs(sList:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        for _, s in ipairs(skinList(selWeapon)) do
            if matches(s, selWeapon) then
                mkItem(sList, s, s == selSkin, function()
                    selSkin = s
                    doApply()
                    rebuildSkins(); refresh()
                end)
            end
        end
    end

    for i = 1, #WEARS do
        local b = Instance.new("TextButton", wearRow)
        b.Size = UDim2.new(0.2, -4, 0, 24)
        b.Text = WEAR_SHORT[i]
        b.Font = Enum.Font.GothamMedium
        b.TextSize = 11
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        corner(b, 3)
        KING_KC(b.MouseButton1Click, function()
            selWear = i
            if overrides[selWeapon] then doApply() end
            refresh()
        end)
        wearBtns[i] = b
    end

    function refresh()
        local active = overrides[selWeapon]
        statusLbl.Text = string.format("<b>%s</b>  ›  %s  ›  %s   %s",
            selWeapon, selSkin or "<font color='#5a827d'>pick a skin</font>", WEARS[selWear],
            active and "<font color='#50c878'>● applied</font>" or "")
        for i, b in ipairs(wearBtns) do styleItem(b, i == selWear) end
    end

    KING_KC(search:GetPropertyChangedSignal("Text"), function()
        filter = search.Text:lower()
        rebuildWeapons(); rebuildSkins()
    end)

    button(SKIN_TAB, "Select held weapon", function()
        local cam = workspace.CurrentCamera
        for _, m in ipairs(cam and cam:GetChildren() or {}) do
            if m:IsA("Model") and table.find(weaponList, m.Name) then
                selWeapon = m.Name
                selSkin = (overrides[selWeapon] and overrides[selWeapon].skin) or nil
                rebuildWeapons(); rebuildSkins(); refresh()
                return
            end
        end
        Notify("No held weapon found", 2, C.teal)
    end)
    button(SKIN_TAB, "Reset all skins", function()
        resetAll()
        selSkin = nil
        rebuildSkins(); refresh()
        Notify("Skins reset", 2, C.teal)
    end, C.red, C.white)

    rebuildWeapons(); rebuildSkins(); refresh()
end)

-- =============================================================================
--  LINEUP STORE  (no tab: lineups are found automatically and shown as tiles for the grenade you hold)
-- =============================================================================
shared.MH_Try('Lineup store', function()
    local LP = Players.LocalPlayer
    local HttpService = game:GetService("HttpService")
    local FILE = "king_hub/lineups.json"
    local lineups = {}
    local showing = true
    local function curMap() return workspace:GetAttribute("Map") or "?" end
    local folder
    pcall(function()
        if isfile and isfile(FILE) then lineups = HttpService:JSONDecode(readfile(FILE)) end
    end)
    local function save()
        pcall(function() writefile(FILE, HttpService:JSONEncode(lineups)) end)
    end
    local function v3(t) return Vector3.new(t[1], t[2], t[3]) end
    local function rebuildList() end

    local KIND_COLOR = {
        smoke = Color3.fromRGB(150, 190, 255), flash = Color3.fromRGB(255, 235, 90),
        molotov = Color3.fromRGB(255, 130, 40), he = Color3.fromRGB(255, 80, 80),
    }
    local HELD_KIND = {["Smoke Grenade"] = "smoke", ["Flashbang"] = "flash", ["Molotov"] = "molotov",
                       ["Incendiary Grenade"] = "molotov", ["HE Grenade"] = "he"}
    local entries = {}
    local showRange, onlyHeld = 90, true

    local function mkPart(shape, size, color, trans)
        local p = Instance.new("Part")
        p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
        p.Material = Enum.Material.Neon
        p.Shape = shape
        p.Size = size
        p.Color = color
        p.Transparency = trans
        return p
    end

    local function mkTile(l, color, standPos)
        local anchor = mkPart(Enum.PartType.Block, Vector3.new(0.2, 0.2, 0.2), color, 1)
        anchor.CFrame = CFrame.new(standPos + Vector3.new(0, 5.2, 0))
        local bb = Instance.new("BillboardGui", anchor)
        bb.AlwaysOnTop = true
        bb.Size = UDim2.fromOffset(230, 52)
        bb.MaxDistance = 400
        local fr = Instance.new("Frame", bb)
        fr.Size = UDim2.fromScale(1, 1)
        fr.BackgroundColor3 = Color3.fromRGB(8, 14, 14)
        fr.BackgroundTransparency = 0.2
        fr.BorderSizePixel = 0
        corner(fr, 6)
        stroke(fr, color, 2, 0)
        local kindName = l.kind and l.kind:upper() or "LINEUP"
        local how = l.jump and "JUMP-THROW" or "STAND STILL"
        local t1 = Instance.new("TextLabel", fr)
        t1.Size = UDim2.new(1, -10, 0.5, 0)
        t1.Position = UDim2.fromOffset(6, 2)
        t1.BackgroundTransparency = 1
        t1.Font = Enum.Font.GothamBold
        t1.TextSize = 11
        t1.TextXAlignment = Enum.TextXAlignment.Left
        t1.TextColor3 = C.white
        t1.TextTruncate = Enum.TextTruncate.AtEnd
        t1.Text = l.name
        local t2 = Instance.new("TextLabel", fr)
        t2.Size = UDim2.new(1, -10, 0.5, 0)
        t2.Position = UDim2.new(0, 6, 0.5, 0)
        t2.BackgroundTransparency = 1
        t2.Font = Enum.Font.GothamMedium
        t2.TextSize = 11
        t2.TextXAlignment = Enum.TextXAlignment.Left
        t2.TextColor3 = color
        if l.kind then
            t2.Text = string.format("%s  ·  %s%s", kindName, how, l.pitch and ("  ·  pitch " .. l.pitch .. "°") or "")
        else
            t2.Text = (l.note and l.note ~= "") and l.note or "saved lineup"
        end
        return anchor
    end

    local function render()
        if folder then folder:Destroy(); folder = nil end
        entries = {}
        local cam = workspace.CurrentCamera
        if not showing or not cam then return end
        folder = Instance.new("Folder")
        folder.Name = HttpService:GenerateGUID(false)
        folder.Parent = cam
        for _, l in ipairs(lineups) do
            if (l.map or "?") ~= curMap() or l.plan then continue end
            local color = KIND_COLOR[l.kind] or C.teal
            local sp, ap = v3(l.stand), v3(l.aim)
            local disc = mkPart(Enum.PartType.Cylinder, Vector3.new(0.12, 2.4, 2.4), color, 0.35)
            disc.CFrame = CFrame.new(sp + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
            local ball = mkPart(Enum.PartType.Ball, Vector3.new(0.7, 0.7, 0.7), color, 0.1)
            ball.CFrame = CFrame.new(ap)
            local bb = Instance.new("BillboardGui", ball)
            bb.AlwaysOnTop = true
            bb.Size = UDim2.fromOffset(20, 20)
            bb.MaxDistance = 400
            local dot = Instance.new("Frame", bb)
            dot.Size = UDim2.fromScale(1, 1)
            dot.BackgroundColor3 = color
            dot.BorderSizePixel = 0
            corner(dot, 10)
            stroke(dot, C.white, 1.5, 0)
            entries[#entries + 1] = {stand = sp, kind = l.kind, parts = {disc, mkTile(l, color, sp), ball}}
        end
    end

    local function heldKind()
        local cam = workspace.CurrentCamera
        for _, m in ipairs(cam and cam:GetChildren() or {}) do
            if m:IsA("Model") and HELD_KIND[m.Name] then return HELD_KIND[m.Name] end
        end
    end

    local function updateVisibility()
        if not folder then return end
        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        local hk = onlyHeld and heldKind() or nil
        for _, e in ipairs(entries) do
            local show = true
            if hrp and (hrp.Position - e.stand).Magnitude > showRange then show = false end
            if onlyHeld and (not hk or (e.kind and e.kind ~= hk)) then show = false end
            for _, part in ipairs(e.parts) do part.Parent = show and folder or nil end
        end
    end

    -- lets the Grenades tab add generated lineups
    shared.MH_ClearAuto = function()
        local keep = {}
        for _, l in ipairs(lineups) do
            if not ((l.map or "?") == curMap() and l.name:find(" auto ", 1, true)) then keep[#keep + 1] = l end
        end
        lineups = keep
        save()
    end
    shared.MH_HasPlan = function()
        for _, l in ipairs(lineups) do if (l.map or "?") == curMap() and l.plan and l.ver == 4 then return true end end
        return false
    end
    shared.MH_ClearPlan = function()
        local keep = {}
        for _, l in ipairs(lineups) do
            if not ((l.map or "?") == curMap() and l.plan) then keep[#keep + 1] = l end
        end
        lineups = keep
        save()
    end
    shared.MH_AddLineup = function(l)
        l.map = l.map or curMap()
        lineups[#lineups + 1] = l
        save(); render(); rebuildList(); updateVisibility()
    end

    local lastCam = workspace.CurrentCamera
    local lastMap = curMap()
    local visAcc = 0
    KING_KC(RunService.Heartbeat, function(dt)
        if curMap() ~= lastMap then lastMap = curMap(); render(); updateVisibility() end
        local cam = workspace.CurrentCamera
        if cam ~= lastCam or (showing and folder and folder.Parent ~= cam) then lastCam = cam; render() end
        visAcc += dt
        if visAcc >= 0.25 then visAcc = 0; updateVisibility() end
    end)
    render(); updateVisibility()
end)

-- =============================================================================
--  GRENADE PATHS TAB  (read-only overlay)
--  Runs the game's own GrenadeSimulator locally and draws the predicted path.
--  Nothing is thrown, sent, or moved. Dots only exist on your screen.
-- =============================================================================
shared.MH_Try('Grenades tab', function()
    local RS = game:GetService("ReplicatedStorage")
    local TAB = createTab("☄", "Grenades")

    -- values the simulator needs that aren't in the weapon files; tweak if paths look off
    local GRENADE_RADIUS = 0.5   -- server value unknown; barely affects the physics
    local RANGE_SCALE    = 1     -- matches the game
    local FLASH_FUSE     = 1.5   -- measured: SimulationFinished fires at ~1.5s for flashbangs
    local MAX_SIM_STEPS  = 240          -- ~4 s of flight at 1/60
    local HELD = {["HE Grenade"]=true, ["Smoke Grenade"]=true, ["Flashbang"]=true,
                  ["Molotov"]=true, ["Decoy Grenade"]=true, ["Incendiary Grenade"]=true}

    local okReq, Sim, GetRayIgnore, GetVel, CharRes = pcall(function()
        return require(RS.Shared.GrenadeSimulator),
               require(RS.Components.Common.GetRayIgnore),
               require(RS.Components.Common.GetCharacterVelocity),
               require(RS.Components.Common.CharacterResolver)
    end)
    if not okReq then
        button(TAB, "Could not load game modules", function() end)
        return
    end
    GetRayIgnore = (function(raw)
        -- the game's GetRayIgnore can error when it is a copy loaded outside the game's own scripts (e.g. on Xeno):
        -- fall back to ignoring the camera and our own character
        return function()
            local ok, r = pcall(raw)
            if ok and type(r) == "table" then return r end
            local lpc = game:GetService("Players").LocalPlayer.Character
            return {workspace.CurrentCamera, lpc}
        end
    end)(GetRayIgnore)

    local enabled, jumpThrow = true, false
    local jumpOffset = 3   -- how much higher the camera is at jump-throw release (studs)
    local throwType = "Far"

    local function newPool()
        local f = Instance.new("Folder")
        f.Name = game:GetService("HttpService"):GenerateGUID(false)
        return {folder = f, parts = {}}
    end
    local pathPool, findPool = newPool(), newPool()

    local function dot(pool, i, pos, color, size)
        local p = pool.parts[i]
        if not p then
            p = Instance.new("Part")
            p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
            p.Shape = Enum.PartType.Ball
            p.Material = Enum.Material.Neon
            p.Parent = pool.folder
            pool.parts[i] = p
        end
        p.Color = color
        p.Size = Vector3.new(size, size, size)
        p.Transparency = 0.15
        p.CFrame = CFrame.new(pos)
    end
    local function hideFrom(pool, from)
        for i, part in pairs(pool.parts) do
            if i >= from then part.Transparency = 1 end
        end
    end
    local function attach(pool)
        local cam = workspace.CurrentCamera
        if cam and pool.folder.Parent ~= cam then pool.folder.Parent = cam end
    end

    -- measured against real grenades: they collide with the "RayBarrier" collision group and ignore only
    -- the grenade model, Debris, the camera and your own character (avg miss ~1.5 studs vs ~3.9 with the old filter)
    local simParams, simParamsAt = nil, 0
    local function getSimParams()
        if simParams and os.clock() - simParamsAt < 2 then return simParams end
        local p = RaycastParams.new()
        p.FilterType = Enum.RaycastFilterType.Exclude
        local list = {}
        local debris = workspace:FindFirstChild("Debris")
        if debris then list[#list + 1] = debris end
        if workspace.CurrentCamera then list[#list + 1] = workspace.CurrentCamera end
        local ch = CharRes.getLocalCharacter()
        if ch then list[#list + 1] = ch end
        p.FilterDescendantsInstances = list
        p.RespectCanCollide = false
        p.IgnoreWater = true
        pcall(function() p.CollisionGroup = "RayBarrier" end)
        simParams, simParamsAt = p, os.clock()
        return p
    end

    local function simulate(camPos, dir, vel, kind, pOverride)
        local params = pOverride or getSimParams()
        local start, d = Sim.calculateThrowParameters(camPos, dir, throwType, RANGE_SCALE)
        local state = Sim.createInitialState(start, d, throwType, vel, RANGE_SCALE, tick())
        local cfg = Sim.createConfig(GRENADE_RADIUS, RANGE_SCALE, throwType == "Near",
            (kind == "flash" and FLASH_FUSE) or (kind == "he" and 1.6) or nil, kind == "molotov" and 0.1 or nil, kind == "molotov")
        local pts, bounces, walls = {state.position}, {}, 0
        for _ = 1, MAX_SIM_STEPS do
            local r = Sim.simulate(state, cfg, params, 1 / 60)
            state = r.state
            pts[#pts + 1] = state.position
            for _, e in ipairs(r.events) do
                if e.type == "bounce" then
                    bounces[#bounces + 1] = #pts
                    if e.normal and e.normal.Y < 0.7 then walls += 1 end
                end
            end
            if state.isAtRest then break end
        end
        return pts, bounces, state.position, walls
    end

    local function draw(pool, pts, bounces, color)
        attach(pool)
        local isB = {}
        for _, b in ipairs(bounces) do isB[b] = true end
        local n = 0
        for i, p in ipairs(pts) do
            if i % 3 == 1 or isB[i] or i == #pts then
                n += 1
                if n > 140 then break end
                local last = (i == #pts)
                dot(pool, n, p, isB[i] and C.red or (last and C.white or color), (last or isB[i]) and 0.6 or 0.28)
            end
        end
        hideFrom(pool, n + 1)
    end

    local function heldGrenade()
        local cam = workspace.CurrentCamera
        for _, m in ipairs(cam and cam:GetChildren() or {}) do
            if m:IsA("Model") and HELD[m.Name] then return m.Name end
        end
    end

    local function playerVel()
        local ch = CharRes.getLocalCharacter()
        local v = ch and GetVel(ch) or Vector3.zero
        -- game treats Y > 5 as a jump throw; horizontal speed is added into the throw
        if jumpThrow then return Vector3.new(v.X, 10, v.Z) end
        return v
    end

    -- live preview
    local lastKey, acc = nil, 0
    KING_KC(RunService.Heartbeat, function(dt)
        acc += dt
        if acc < 0.1 then return end
        acc = 0
        if not enabled or not heldGrenade() then
            hideFrom(pathPool, 1); lastKey = nil
            return
        end
        local cam = workspace.CurrentCamera
        local vel = playerVel()
        local key = tostring(cam.CFrame) .. tostring(vel) .. throwType .. tostring(jumpThrow) .. jumpOffset
        if key == lastKey then return end
        lastKey = key
        local ok, pts, bounces = pcall(simulate, cam.CFrame.Position + Vector3.new(0, jumpThrow and jumpOffset or 0, 0), cam.CFrame.LookVector, vel)
        if ok then draw(pathPool, pts, bounces, throwType == "Far" and C.gold or C.teal) end
    end)

    -- lineup finder: from where you stand, which pitch lands on the spot you're looking at?
    local finding = false
    local function findLineup()
        if finding then return end
        local cam = workspace.CurrentCamera
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = GetRayIgnore()
        local hit = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 600, params)
        if not hit then Notify("Look at the spot you want to land on", 3, C.red) return end
        finding = true
        task.spawn(function()
            local origin, target = cam.CFrame.Position + Vector3.new(0, jumpThrow and jumpOffset or 0, 0), hit.Position
            local flat = Vector3.new(target.X - origin.X, 0, target.Z - origin.Z)
            if flat.Magnitude < 1 then finding = false return end
            flat = flat.Unit
            local vel = playerVel()
            local best, bestErr, bestPts, bestB
            local n = 0
            for pitchTenths = -50, 800, 5 do
                local p = math.rad(pitchTenths / 10)
                local dir = flat * math.cos(p) + Vector3.new(0, math.sin(p), 0)
                local ok, pts, bounces, rest = pcall(simulate, origin, dir, vel)
                if ok then
                    local err = (rest - target).Magnitude
                    if not bestErr or err < bestErr then best, bestErr, bestPts, bestB = dir, err, pts, bounces end
                end
                n += 1
                if n % 6 == 0 then task.wait() end
            end
            finding = false
            if not best then Notify("Search failed", 3, C.red) return end
            draw(findPool, bestPts, bestB, C.green)
            local aimPoint = origin + best * 60
            dot(findPool, 150, aimPoint, C.green, 1.2)
            local pitch = math.deg(math.asin(best.Y))
            Notify(string.format("Aim at green ball: pitch %.1f°, lands %.1f studs from target", pitch, bestErr),
                6, bestErr < 4 and C.green or C.red)
        end)
    end

    -- auto lineups: test standing spots around each bombsite, keep throws that land on the site centre
    local autoRunning = false
    -- bombsites are the ZoneParts_A / ZoneParts_B groups; the centre is the average of their parts
    local function siteGroups(sites)
        local groups = {}
        for _, g in ipairs(sites:GetChildren()) do
            local tag = g.Name:match("^ZoneParts_(.+)$")
            if tag then
                local sum, n = Vector3.zero, 0
                for _, part in ipairs(g:GetDescendants()) do
                    if part:IsA("BasePart") then sum += part.Position; n += 1 end
                end
                if n > 0 then groups[#groups + 1] = {Name = "Site " .. tag, Pos = sum / n} end
            end
        end
        return groups
    end
    local function autoFind()
        if autoRunning then return end
        local map = workspace:FindFirstChild("Map")
        local zones = map and map:FindFirstChild("Zones")
        local sites = zones and zones:FindFirstChild("Sites")
        local cam = workspace.CurrentCamera
        local char = CharRes.getLocalCharacter()
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not (sites and cam and hrp and shared.MH_AddLineup) then
            Notify("Need to be spawned in on a map with bombsites", 3, C.red)
            return
        end
        autoRunning = true
        task.spawn(function()
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = GetRayIgnore()
            local eye = cam.CFrame.Position.Y - (hrp.Position.Y - 2.8)
            local added, tested = 0, 0
            local validSpots, totalSpots = 0, 0
            local log = {}
            local groups = siteGroups(sites)
            if shared.MH_ClearAuto then shared.MH_ClearAuto() end
            if #groups == 0 then
                autoRunning = false
                Notify("No ZoneParts_A/B found in this map's Sites", 4, C.red)
                return
            end
            for _, site in ipairs(groups) do
                local center = site.Pos
                if center then
                    local g = workspace:Raycast(center + Vector3.new(0, 2, 0), Vector3.new(0, -25, 0), params)
                    local target = g and g.Position or center
                    Notify("Searching " .. site.Name .. "...", 3, C.teal)
                    local found = {}
                    local bestOverall = math.huge
                    validSpots = 0
                    for _, radius in ipairs({20, 32, 44, 56, 68, 80}) do
                        for k = 0, 19 do
                            local ang = k * (math.pi / 10)
                            local gx, gz = target.X + math.cos(ang) * radius, target.Z + math.sin(ang) * radius
                            local down = workspace:Raycast(Vector3.new(gx, target.Y + 10, gz), Vector3.new(0, -30, 0), params)
                            local ok = down and down.Normal.Y > 0.92 and math.abs(down.Position.Y - target.Y) < 12
                            if ok and workspace:Raycast(down.Position + Vector3.new(0, 0.5, 0), Vector3.new(0, 7, 0), params) then ok = false end
                            if ok then
                                validSpots += 1
                                local feet = down.Position
                                local camPos = feet + Vector3.new(0, eye, 0)
                                local flat = Vector3.new(target.X - camPos.X, 0, target.Z - camPos.Z)
                                if flat.Magnitude > 3 then
                                    flat = flat.Unit
                                    local best, bestErr
                                    for pitchHalf = -10, 160, 3 do
                                        local pitch = pitchHalf / 2
                                        local p = math.rad(pitch)
                                        local dir = flat * math.cos(p) + Vector3.new(0, math.sin(p), 0)
                                        local okS, _, _, rest = pcall(simulate, camPos, dir, Vector3.zero)
                                        if okS then
                                            local err = (rest - target).Magnitude
                                            if not bestErr or err < bestErr then best, bestErr = {dir = dir, pitch = pitch}, err end
                                        end
                                        tested += 1
                                        if tested % 5 == 0 then task.wait() end
                                    end
                                    if bestErr then bestOverall = math.min(bestOverall, bestErr) end
                                    if best and bestErr < 3 then
                                        local hit = workspace:Raycast(camPos, best.dir * 600, params)
                                        if hit then
                                            found[#found + 1] = {err = bestErr, feet = feet, aim = hit.Position, pitch = best.pitch}
                                        end
                                    end
                                end
                            end
                        end
                    end
                    log[#log + 1] = string.format("%s target=(%.0f,%.0f,%.0f) validSpots=%d lineupsUnder3studs=%d bestError=%.1f",
                        site.Name, target.X, target.Y, target.Z, validSpots, #found, bestOverall == math.huge and -1 or bestOverall)
                    table.sort(found, function(a, b) return a.err < b.err end)
                    for i = 1, math.min(#found, 8) do
                        local f = found[i]
                        shared.MH_AddLineup({
                            name = string.format("%s auto %d (%s)", site.Name, i, throwType),
                            note = string.format("stand still, pitch %d°", f.pitch),
                            stand = {f.feet.X, f.feet.Y, f.feet.Z},
                            aim = {f.aim.X, f.aim.Y, f.aim.Z},
                        })
                        added += 1
                    end
                end
            end
            pcall(writefile, "king_hub/autofind_log.txt", table.concat(log, "\n") .. "\nthrowType=" .. throwType .. " sims=" .. tested)
            autoRunning = false
            Notify(string.format("Auto-find done: %d lineups added (see Lineups tab)", added), 5, added > 0 and C.green or C.red)
        end)
    end

    -- ===== automatic planner: walkmesh -> routes -> targets and candidate standing spots =====
    local function computePlan(targetsOnly)
        local map = workspace:FindFirstChild("Map")
        local zones = map and map:FindFirstChild("Zones")
        if not zones then return nil end
        local okC, Codec = pcall(function() return require(RS.MovementV2.Collision.WalkmeshCodec) end)
        if not okC then return nil end

        local tris = {}
        local function scan(inst)
            local data = inst:GetAttribute("WalkMeshData")
            if typeof(data) == "string" then
                local mesh = Codec.Decode(data)
                if mesh then
                    local pivot = inst:IsA("BasePart") and inst.CFrame or inst:GetPivot()
                    local vs = {}
                    for i, v in ipairs(mesh.Vertices) do vs[i] = pivot:PointToWorldSpace(v) end
                    for _, t in ipairs(mesh.Triangles) do tris[#tris + 1] = {vs[t.A], vs[t.B], vs[t.C]} end
                end
            end
        end
        scan(map)
        for _, d in ipairs(map:GetDescendants()) do scan(d) end
        if #tris == 0 then return nil end

        local CELL = 2
        local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
        for _, t in ipairs(tris) do
            for k = 1, 3 do
                local v = t[k]
                minX, maxX = math.min(minX, v.X), math.max(maxX, v.X)
                minZ, maxZ = math.min(minZ, v.Z), math.max(maxZ, v.Z)
            end
        end
        minX, minZ = minX - 4, minZ - 4
        local NX = math.floor((maxX + 4 - minX) / CELL) + 1
        local NZ = math.floor((maxZ + 4 - minZ) / CELL) + 1
        local Y = {}
        local function key(ix, iz) return ix * NZ + iz end
        local function unkey(k) local ix = math.floor(k / NZ); return ix, k - ix * NZ end
        local function world(ix, iz) return minX + (ix + 0.5) * CELL, minZ + (iz + 0.5) * CELL end
        local function walk(ix, iz) return ix >= 0 and ix < NX and iz >= 0 and iz < NZ and Y[key(ix, iz)] ~= nil end

        for n, t in ipairs(tris) do
            local a, b, c = t[1], t[2], t[3]
            local nrm = (b - a):Cross(c - a)
            if nrm.Magnitude > 1e-9 and math.abs(nrm.Y) / nrm.Magnitude >= 0.6 then
                local d = (b.Z - c.Z) * (a.X - c.X) + (c.X - b.X) * (a.Z - c.Z)
                if math.abs(d) > 1e-9 then
                    local x0 = math.floor((math.min(a.X, b.X, c.X) - minX) / CELL)
                    local x1 = math.floor((math.max(a.X, b.X, c.X) - minX) / CELL) + 1
                    local z0 = math.floor((math.min(a.Z, b.Z, c.Z) - minZ) / CELL)
                    local z1 = math.floor((math.max(a.Z, b.Z, c.Z) - minZ) / CELL) + 1
                    for ix = math.max(0, x0), math.min(NX - 1, x1) do
                        for iz = math.max(0, z0), math.min(NZ - 1, z1) do
                            local px, pz = world(ix, iz)
                            local l1 = ((b.Z - c.Z) * (px - c.X) + (c.X - b.X) * (pz - c.Z)) / d
                            local l2 = ((c.Z - a.Z) * (px - c.X) + (a.X - c.X) * (pz - c.Z)) / d
                            local l3 = 1 - l1 - l2
                            if l1 >= -0.02 and l2 >= -0.02 and l3 >= -0.02 then
                                local y = l1 * a.Y + l2 * b.Y + l3 * c.Y
                                local k = key(ix, iz)
                                if not Y[k] or y > Y[k] then Y[k] = y end
                            end
                        end
                    end
                end
            end
            if n % 150 == 0 then task.wait() end
        end

        local eroded = {}
        for k in pairs(Y) do
            local ix, iz = unkey(k)
            if walk(ix + 1, iz) and walk(ix - 1, iz) and walk(ix, iz + 1) and walk(ix, iz - 1) then eroded[k] = true end
        end

        local function nearest(x, z, useEroded)
            local ix, iz = math.floor((x - minX) / CELL), math.floor((z - minZ) / CELL)
            for r = 0, 40 do
                for dx = -r, r do
                    for dz = -r, r do
                        if math.max(math.abs(dx), math.abs(dz)) == r then
                            local jx, jz = ix + dx, iz + dz
                            if walk(jx, jz) and (not useEroded or eroded[key(jx, jz)]) then return key(jx, jz) end
                        end
                    end
                end
            end
        end

        local function dijkstra(src)
            local dist, prev, heap, hn = {[src] = 0}, {}, {{0, src}}, 1
            local function push(d, k)
                hn += 1; heap[hn] = {d, k}
                local i = hn
                while i > 1 do
                    local p = math.floor(i / 2)
                    if heap[p][1] <= heap[i][1] then break end
                    heap[p], heap[i] = heap[i], heap[p]; i = p
                end
            end
            local function pop()
                local top = heap[1]
                heap[1] = heap[hn]; heap[hn] = nil; hn -= 1
                local i = 1
                while true do
                    local l, r, s = i * 2, i * 2 + 1, i
                    if l <= hn and heap[l][1] < heap[s][1] then s = l end
                    if r <= hn and heap[r][1] < heap[s][1] then s = r end
                    if s == i then break end
                    heap[s], heap[i] = heap[i], heap[s]; i = s
                end
                return top
            end
            local pops = 0
            while hn > 0 do
                local d, k = table.unpack(pop())
                if d <= dist[k] then
                    local ix, iz = unkey(k)
                    for dx = -1, 1 do
                        for dz = -1, 1 do
                            if (dx ~= 0 or dz ~= 0) and walk(ix + dx, iz + dz) then
                                if not (dx ~= 0 and dz ~= 0) or (walk(ix + dx, iz) and walk(ix, iz + dz)) then
                                    local nk = key(ix + dx, iz + dz)
                                    local nd = d + CELL * ((dx ~= 0 and dz ~= 0) and 1.4142 or 1)
                                    if not dist[nk] or nd < dist[nk] then dist[nk] = nd; prev[nk] = k; push(nd, nk) end
                                end
                            end
                        end
                    end
                end
                pops += 1
                if pops % 4000 == 0 then task.wait() end
            end
            return dist, prev
        end

        local function route(prev, dst, src)
            local path = {dst}
            while path[#path] ~= src do
                local p = prev[path[#path]]
                if not p then return nil end
                path[#path + 1] = p
            end
            local out = {}
            for i = #path, 1, -1 do out[#out + 1] = path[i] end
            return out
        end
        local function atBack(path, d)
            local acc = 0
            for i = #path, 2, -1 do
                local ax, az = unkey(path[i]); local bx, bz = unkey(path[i - 1])
                acc += CELL * ((ax ~= bx and az ~= bz) and 1.4142 or 1)
                if acc >= d then return path[i - 1] end
            end
            return path[1]
        end

        -- spawns and sites from the map's own zones
        local function avg(list)
            local sum = Vector3.zero
            for _, p in ipairs(list) do sum += p.Position end
            return sum / math.max(1, #list)
        end
        local tSpawns, ctSpawns = {}, {}
        local spawnsF = zones:FindFirstChild("Spawns")
        for _, p in ipairs(spawnsF and spawnsF:GetDescendants() or {}) do
            if p:IsA("BasePart") and not p:FindFirstAncestor("Deathmatch") then
                if p:FindFirstAncestor("Counter-Terrorists") then ctSpawns[#ctSpawns + 1] = p
                elseif p:FindFirstAncestor("Terrorists") then tSpawns[#tSpawns + 1] = p end
            end
        end
        local siteCenters = {}
        local sitesF = zones:FindFirstChild("Sites")
        for _, g in ipairs(sitesF and sitesF:GetChildren() or {}) do
            local tag = g.Name:match("^ZoneParts_(.+)$")
            if tag then
                local parts = {}
                for _, p in ipairs(g:GetDescendants()) do if p:IsA("BasePart") then parts[#parts + 1] = p end end
                if #parts > 0 then siteCenters[tag] = avg(parts) end
            end
        end
        if #tSpawns == 0 or #ctSpawns == 0 or next(siteCenters) == nil then return nil end
        local tc, cc = avg(tSpawns), avg(ctSpawns)
        local Tk, Ck = nearest(tc.X, tc.Z), nearest(cc.X, cc.Z)
        if not (Tk and Ck) then return nil end
        local dT, pT = dijkstra(Tk)
        local dC, pC = dijkstra(Ck)

        local plan = {requests = {}}
        local function stands(teamDist, siteKey, dS, targetKey, lo, hi)
            local tx, tz = world(unkey(targetKey))
            local base = teamDist[siteKey]
            local cand = {}
            for k in pairs(eroded) do
                if teamDist[k] and dS[k] and teamDist[k] + dS[k] <= base + 10 then
                    local ix, iz = unkey(k)
                    local x, z = world(ix, iz)
                    local dd = math.sqrt((x - tx) ^ 2 + (z - tz) ^ 2)
                    if dd >= lo and dd <= hi then cand[#cand + 1] = {k, (ix * 7 + iz * 13) % 101, x, z} end
                end
            end
            table.sort(cand, function(a, b) return a[2] == b[2] and a[1] < b[1] or a[2] < b[2] end)
            local out = {}
            for _, c in ipairs(cand) do
                local okSp = true
                for _, o in ipairs(out) do
                    if math.sqrt((o[3] - c[3]) ^ 2 + (o[4] - c[4]) ^ 2) < 5 then okSp = false break end
                end
                if okSp then out[#out + 1] = c end
                if #out >= 34 then break end
            end
            return out
        end

        for tag, center in pairs(siteCenters) do
            local S = nearest(center.X, center.Z, true)
            if S and dT[S] and dC[S] then
                local dS = dijkstra(S)
                local routeT, routeC = route(pT, S, Tk), route(pC, S, Ck)
                if routeT and routeC then
                    local function add(team, kind, label, targetKey, yoff, lo, hi)
                        local st = targetsOnly and {} or stands(team == "T" and dT or dC, S, dS, targetKey, lo, hi)
                        if #st == 0 and not targetsOnly then return end
                        local tx, tz = world(unkey(targetKey))
                        local req = {
                            site = tag, team = team, kind = kind,
                            label = string.format("Site %s · %s · %s · %s", tag, team, kind:sub(1, 1):upper() .. kind:sub(2), label),
                            target = {tx, Y[targetKey] + yoff, tz}, yoff = yoff, stands = {},
                        }
                        for _, c in ipairs(st) do req.stands[#req.stands + 1] = {c[3], Y[c[1]], c[4]} end
                        plan.requests[#plan.requests + 1] = req
                    end
                    -- T side: utility into the CT approach and onto the site
                    for _, d in ipairs({60, 48, 36, 24}) do add("T", "smoke", "CT approach " .. d, atBack(routeC, d), 0.5, 22, 90) end
                    add("T", "flash", "over the site", S, 4.0, 22, 80)
                    for _, d in ipairs({10, 18, 26}) do add("T", "flash", "CT approach " .. d, atBack(routeC, d), 4.0, 20, 80) end
                    add("T", "molotov", "default plant", S, 0.0, 18, 75)
                    for _, d in ipairs({14, 22, 32}) do add("T", "molotov", "CT approach " .. d, atBack(routeC, d), 0.0, 18, 80) end
                    add("T", "he", "over the site", S, 0.5, 20, 75)
                    for _, d in ipairs({12, 22}) do add("T", "he", "CT approach " .. d, atBack(routeC, d), 0.5, 20, 75) end
                    -- CT side: utility into the T entrance and onto the plant
                    for _, d in ipairs({50, 38, 28, 18}) do add("CT", "smoke", "T entrance " .. d, atBack(routeT, d), 0.5, 22, 90) end
                    for _, d in ipairs({8, 14, 22}) do add("CT", "flash", "T entrance " .. d, atBack(routeT, d), 4.0, 20, 80) end
                    add("CT", "flash", "into the site", S, 4.0, 22, 80)
                    add("CT", "molotov", "plant spot", S, 0.0, 18, 75)
                    for _, d in ipairs({14, 24, 34}) do add("CT", "molotov", "T entrance " .. d, atBack(routeT, d), 0.0, 18, 80) end
                    add("CT", "he", "plant spot", S, 0.5, 20, 75)
                    for _, d in ipairs({12, 22}) do add("CT", "he", "T entrance " .. d, atBack(routeT, d), 0.5, 20, 75) end
                end
            end
        end
        do
            local walkable = 0
            for _ in pairs(Y) do walkable += 1 end
            local names = {}
            for tag in pairs(siteCenters) do names[#names + 1] = tag end
            shared.MH_Log(string.format('plan: %d walkmesh tris, grid %dx%d, %d walkable cells, T spawns=%d CT spawns=%d, sites=%s, requests=%d',
                #tris, NX, NZ, walkable, #tSpawns, #ctSpawns, table.concat(names, ','), #plan.requests))
        end
        return plan
    end

    -- the game's physics decides which planned spots can actually land on each target
    local planRunning = false
    local function buildPlanned(auto)
        if planRunning then return end
        local mapName = tostring(workspace:GetAttribute("Map") or "?")
        local cam = workspace.CurrentCamera
        local char = CharRes.getLocalCharacter()
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not (cam and hrp and shared.MH_AddLineup) then
            if not auto then Notify("Spawn in first", 3, C.red) end
            return
        end
        planRunning = true
        task.spawn(function()
            local okP, plan = pcall(computePlan)
            if not okP or not plan or #plan.requests == 0 then
                planRunning = false
                shared.MH_Log('plan FAILED for ' .. mapName .. ': ' .. tostring(plan))
                Notify("Couldn't plan lineups for " .. mapName .. " (no walkable data)", 4, C.red)
                return
            end
            Notify("Planning lineups for " .. mapName .. "...", 4, C.teal)
            local eye = cam.CFrame.Position.Y - (hrp.Position.Y - 2.8)
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = GetRayIgnore()
            if shared.MH_ClearPlan then shared.MH_ClearPlan() end
            local added, sims = 0, 0
            local sliceT = os.clock()
            local lines = {}
            local ignoreP = RaycastParams.new()
            ignoreP.FilterType = Enum.RaycastFilterType.Exclude
            ignoreP.FilterDescendantsInstances = GetRayIgnore()
            local function ground(x, y, z)
                local r = workspace:Raycast(Vector3.new(x, y + 4, z), Vector3.new(0, -14, 0), ignoreP)
                return r and r.Position.Y or nil
            end

            -- try every stand (standing and jump) against one target with a given raycast setup
            local function searchGroup(req, target, stands, simP, modes)
                local good = {}
                local tol = req.kind == "flash" and 3.5 or 2.5
                local bestAny = math.huge
                for _, feet in ipairs(stands) do
                    for _, jump in ipairs(modes) do
                        local camPos = feet + Vector3.new(0, eye + (jump and jumpOffset or 0), 0)
                        local vel = jump and Vector3.new(0, 10, 0) or Vector3.zero
                        local flat = Vector3.new(target.X - camPos.X, 0, target.Z - camPos.Z)
                        if flat.Magnitude > 3 then
                            flat = flat.Unit
                            local bestErr, bestDir, bestPitch
                            local function tryPitch(pitch)
                                local pr = math.rad(pitch)
                                local dir = flat * math.cos(pr) + Vector3.new(0, math.sin(pr), 0)
                                local okS, _, _, rest = pcall(simulate, camPos, dir, vel, req.kind, simP)
                                sims += 1
                                if os.clock() - sliceT > 0.011 then task.wait(); sliceT = os.clock() end
                                if okS then
                                    local err = (rest - target).Magnitude
                                    if not bestErr or err < bestErr then bestErr, bestDir, bestPitch = err, dir, pitch end
                                end
                            end
                            for pitch = -8, 80, 4 do tryPitch(pitch) end
                            if bestPitch then
                                local c = bestPitch
                                for pitch = c - 3, c + 3 do if pitch ~= c then tryPitch(pitch) end end
                            end
                            if bestErr then bestAny = math.min(bestAny, bestErr) end
                            if bestErr and bestErr <= tol then
                                local hit = workspace:Raycast(camPos, bestDir * 600, ignoreP)
                                if hit then good[#good + 1] = {err = bestErr, feet = feet, aim = hit.Position, pitch = bestPitch, jump = jump} end
                            end
                        end
                    end
                end
                return good, bestAny
            end

            for _, req in ipairs(plan.requests) do
                local okReq, errReq = pcall(function()
                    -- snap the planned spots to the REAL floor (the walkmesh height can differ from it)
                    local tx, ty, tz = req.target[1], req.target[2], req.target[3]
                    local gy = ground(tx, ty, tz)
                    local target = Vector3.new(tx, (gy or (ty - (req.yoff or 0))) + (req.yoff or 0), tz)
                    local stands, lost = {}, 0
                    for _, st in ipairs(req.stands) do
                        local fy = ground(st[1], st[2], st[3])
                        if fy then stands[#stands + 1] = Vector3.new(st[1], fy, st[3]) else lost += 1 end
                    end
                    local good, bestA = searchGroup(req, target, stands, getSimParams(), req.kind == "smoke" and {false, true} or {false})
                    local note = ""
                    local bestB = math.huge
                    if #good == 0 and #stands > 0 then
                        -- nothing landed with the measured collision setup: retry with the older, simpler one
                        local sub = {}
                        for i = 1, math.min(12, #stands) do sub[i] = stands[i] end
                        good, bestB = searchGroup(req, target, sub, ignoreP, {false})
                        note = " (fallback physics)"
                    end
                    table.sort(good, function(a, b) return a.err < b.err end)
                    local picked, nStand, nJump = {}, 0, 0
                    for _, g in ipairs(good) do
                        local far = true
                        for _, q in ipairs(picked) do if (q.feet - g.feet).Magnitude < 8 then far = false break end end
                        local room = (g.jump and nJump < 2) or (not g.jump and nStand < 5)
                        if far and room then
                            picked[#picked + 1] = g
                            if g.jump then nJump += 1 else nStand += 1 end
                        end
                        if #picked >= 7 then break end
                    end
                    for i, g in ipairs(picked) do
                        pcall(shared.MH_AddLineup, {
                            name = string.format("%s #%d", req.label, i),
                            note = string.format("%s, pitch %d°", g.jump and "jump-throw" or "stand still", g.pitch),
                            stand = {g.feet.X, g.feet.Y, g.feet.Z},
                            aim = {g.aim.X, g.aim.Y, g.aim.Z},
                            plan = true, ver = 4, kind = req.kind, jump = g.jump, pitch = g.pitch, team = req.team,
                        })
                        added += 1
                    end
                    lines[#lines + 1] = string.format("%s: %d usable throws, kept %d%s | stands %d (lost %d) | target (%.0f,%.0f,%.0f) groundY=%s | closest miss %.1f%s",
                        req.label, #good, #picked, note, #stands, lost, target.X, target.Y, target.Z, tostring(gy and string.format("%.1f", gy)),
                        math.min(bestA, bestB), (bestA == math.huge and bestB == math.huge) and " (no sims ran)" or "")
                    shared.MH_Log("plan result: " .. lines[#lines])
                end)
                if not okReq then shared.MH_Log("plan group FAILED: " .. tostring(req.label) .. " -> " .. tostring(errReq)) end
            end
            pcall(writefile, "king_hub/plan_result.txt", table.concat(lines, "\n"))
            planRunning = false
            shared.MH_Log(string.format("plan finished: %d lineups added, %d simulations", added, sims))
            Notify(string.format("Planned lineups done: %d added (see Lineups tab)", added), 6, added > 0 and C.green or C.red)
        end)
    end

    -- ===== live throw suggestions =====
    -- Hold a grenade: from exactly where you stand, the hub tries throws at players and the bomb, simulates
    -- each one with the game's physics, scores what it would actually hit, and floats the best few in the sky.
    local HE_FUSE = 1.6
    local suggestOn = true
    local SUG_KIND = {["Flashbang"] = "flash", ["Molotov"] = "molotov", ["Incendiary Grenade"] = "molotov", ["HE Grenade"] = "he"}
    local sugFolder = Instance.new("Folder")
    sugFolder.Name = game:GetService("HttpService"):GenerateGUID(false)
    local sugMarks = {}
    local sugPathPool = newPool()
    local sugOrigin, sugComputing = nil, false
    local mapTargets = {}      -- [kind] = {{pos, label}, ...} for the current map
    local SUG_COLOR = {flash = Color3.fromRGB(255, 235, 90), molotov = Color3.fromRGB(255, 130, 40), he = Color3.fromRGB(255, 80, 80)}

    local function sugMark(i)
        local m = sugMarks[i]
        if m then return m end
        local part = Instance.new("Part")
        part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
        part.Shape = Enum.PartType.Ball
        part.Material = Enum.Material.Neon
        part.Size = Vector3.new(1.4, 1.4, 1.4)
        part.Transparency = 0.1
        local bb = Instance.new("BillboardGui", part)
        bb.AlwaysOnTop = true
        bb.Size = UDim2.fromOffset(230, 56)
        bb.StudsOffset = Vector3.new(0, 2.6, 0)
        bb.MaxDistance = 1200
        local fr = Instance.new("Frame", bb)
        fr.Size = UDim2.fromScale(1, 1)
        fr.BackgroundColor3 = Color3.fromRGB(8, 14, 14)
        fr.BackgroundTransparency = 0.15
        fr.BorderSizePixel = 0
        corner(fr, 8)
        local st = stroke(fr, C.green, 2, 0)
        local t1 = Instance.new("TextLabel", fr)
        t1.Size = UDim2.new(1, -10, 0.5, 0)
        t1.Position = UDim2.fromOffset(6, 2)
        t1.BackgroundTransparency = 1
        t1.Font = Enum.Font.GothamBold
        t1.TextSize = 13
        t1.TextXAlignment = Enum.TextXAlignment.Left
        t1.TextColor3 = C.white
        local t2 = Instance.new("TextLabel", fr)
        t2.Size = UDim2.new(1, -10, 0.5, 0)
        t2.Position = UDim2.new(0, 6, 0.5, 0)
        t2.BackgroundTransparency = 1
        t2.Font = Enum.Font.GothamMedium
        t2.TextSize = 12
        t2.TextXAlignment = Enum.TextXAlignment.Left
        t2.TextColor3 = C.text
        t2.RichText = true
        m = {part = part, st = st, t1 = t1, t2 = t2}
        sugMarks[i] = m
        return m
    end

    local function clearSug()
        for _, m in pairs(sugMarks) do m.part.Parent = nil end
        hideFrom(sugPathPool, 1)
        sugOrigin = nil
    end

    local function gatherPlayers()
        local enemies, mates = {}, {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and IsAlive(plr) then
                local ch = plr.Character
                local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local head = ch:FindFirstChild("Head")
                    local rec = {pos = hrp.Position, head = head and head.Position or (hrp.Position + Vector3.new(0, 1.5, 0)), look = hrp.CFrame.LookVector}
                    if IsTeammate(plr) then mates[#mates + 1] = rec else enemies[#enemies + 1] = rec end
                end
            end
        end
        return enemies, mates
    end

    local function clearLOS(vparams, from, to)
        local r = workspace:Raycast(from, to - from, vparams)
        if not r then return true end
        local mdl = r.Instance:FindFirstAncestorOfClass("Model")
        return mdl ~= nil and mdl:FindFirstChildOfClass("Humanoid") ~= nil
    end

    local function scoreBurst(kind, pos, enemies, mates, bombPos, myHead, vparams)
        local score, ne, nm, onBomb, selfHit = 0, 0, 0, false, false
        if kind == "flash" then
            for _, e in ipairs(enemies) do
                local d = (e.head - pos).Magnitude
                if d <= 55 and clearLOS(vparams, pos, e.head) then
                    local facing = e.look:Dot((pos - e.head).Unit)
                    if facing > -0.2 then ne += 1; score += 10 + (55 - d) / 55 * 2
                    elseif d <= 30 then score += 3 end
                end
            end
            for _, t in ipairs(mates) do
                local d = (t.head - pos).Magnitude
                if d <= 55 and clearLOS(vparams, pos, t.head) and t.look:Dot((pos - t.head).Unit) > 0.1 then
                    nm += 1; score -= 12
                end
            end
            if (myHead - pos).Magnitude <= 55 and clearLOS(vparams, pos, myHead) then selfHit = true; score -= 6 end
        else
            local R = kind == "he" and 14 or 9
            local up = Vector3.new(0, 1, 0)
            for _, e in ipairs(enemies) do
                if (e.pos - pos).Magnitude <= R and (kind == "molotov" or clearLOS(vparams, pos + up, e.pos + up)) then ne += 1; score += 10 end
            end
            for _, t in ipairs(mates) do
                if (t.pos - pos).Magnitude <= R and (kind == "molotov" or clearLOS(vparams, pos + up, t.pos + up)) then nm += 1; score -= 10 end
            end
            if bombPos and (bombPos - pos).Magnitude <= R then onBomb = true; score += kind == "molotov" and 25 or 6 end
        end
        return score, ne, nm, onBomb, selfHit
    end

    local function candidatePoints(kind, enemies, bombPos, origin)
        local pts = {}
        local function add(p)
            local d = (p - origin).Magnitude
            if d >= 12 and d <= 120 then pts[#pts + 1] = {p = p, d = d} end
        end
        if kind == "flash" then
            for _, e in ipairs(enemies) do add(e.head + e.look * 3); add(e.head + Vector3.new(0, 0.5, 0)) end
            for i = 1, #enemies do
                for j = i + 1, #enemies do
                    if (enemies[i].pos - enemies[j].pos).Magnitude < 22 then add((enemies[i].head + enemies[j].head) / 2 + Vector3.new(0, 1, 0)) end
                end
            end
        else
            for _, e in ipairs(enemies) do add(e.pos + Vector3.new(0, 0.3, 0)) end
            for i = 1, #enemies do
                for j = i + 1, #enemies do
                    if (enemies[i].pos - enemies[j].pos).Magnitude < (kind == "he" and 16 or 10) then
                        add((enemies[i].pos + enemies[j].pos) / 2 + Vector3.new(0, 0.3, 0))
                    end
                end
            end
            if bombPos then add(bombPos + Vector3.new(0, 0.3, 0)) end
        end
        table.sort(pts, function(a, b) return a.d < b.d end)
        local out = {}
        for i = 1, math.min(#pts, 24) do out[i] = pts[i].p end
        return out
    end

    local SUG_MAX = 8
    local function showSuggestions(results, origin, kind)
        local cam = workspace.CurrentCamera
        if sugFolder.Parent ~= cam then sugFolder.Parent = cam end
        for i = 1, SUG_MAX do
            local m = sugMark(i)
            local r = results[i]
            if r then
                m.part.Parent = sugFolder
                m.part.CFrame = CFrame.new(origin + r.dir * 70)
                local color = r.bank and Color3.fromRGB(190, 120, 255) or (r.static and (SUG_COLOR[kind] or C.teal) or C.green)
                m.part.Color = color
                m.st.Color = color
                m.t1.Text = r.title
                m.t2.Text = r.detail
            else
                m.part.Parent = nil
            end
        end
        if results[1] then draw(sugPathPool, results[1].pts, results[1].bounces, C.green) else hideFrom(sugPathPool, 1) end
    end

    local function computeSuggestions()
        if sugComputing then return end
        local held = heldGrenade()
        local kind = held and SUG_KIND[held]
        local cam = workspace.CurrentCamera
        if not kind or not cam or not IsAlive(LocalPlayer) then clearSug() return end
        sugComputing = true
        local enemies, mates = gatherPlayers()
        local bombPos
        local bomb = (kind ~= "flash") and findPlantedBomb() or nil
        if bomb and bomb.Parent then bombPos = bomb:GetPivot().Position end
        local origin = cam.CFrame.Position + Vector3.new(0, jumpThrow and jumpOffset or 0, 0)
        local vel = playerVel()
        local myHead = cam.CFrame.Position
        local vparams = RaycastParams.new()
        vparams.FilterType = Enum.RaycastFilterType.Exclude
        vparams.FilterDescendantsInstances = GetRayIgnore()

        -- map targets for this grenade type that are within throwing range
        local tol = (kind == "flash" or kind == "he") and 3.5 or 2.5
        local tlist = {}
        for _, t in ipairs(mapTargets[kind] or {}) do
            local d = (t.pos - origin).Magnitude
            if d >= 10 and d <= 115 then tlist[#tlist + 1] = t end
        end
        -- places worth scoring against players / the bomb
        local near = {}
        for _, e in ipairs(enemies) do near[#near + 1] = e.pos; near[#near + 1] = e.head end
        if bombPos then near[#near + 1] = bombPos end

        local bestStatic, dyn, n = {}, {}, 0
        local sugSlice = os.clock()
        local function run(dir)
            local ok, pts, bnc, rest, walls = pcall(simulate, origin, dir, vel, kind)
            n += 1
            if os.clock() - sugSlice > 0.008 then task.wait(); sugSlice = os.clock() end
            if not ok then return end
            local bank = (walls or 0) > 0
            for ti, t in ipairs(tlist) do
                local err = (rest - t.pos).Magnitude
                if err <= tol then
                    local key = ti .. (bank and "b" or "d")
                    local cur = bestStatic[key]
                    if not cur or err < cur.err then
                        bestStatic[key] = {err = err, dir = dir, pts = pts, bounces = bnc, rest = rest, bank = bank, static = true, label = t.label, ti = ti}
                    end
                end
            end
            local close = false
            for _, p in ipairs(near) do if (p - rest).Magnitude < 16 then close = true break end end
            if close then
                local sc, ne, nm, onBomb, selfHit = scoreBurst(kind, rest, enemies, mates, bombPos, myHead, vparams)
                if sc > 0 then
                    dyn[#dyn + 1] = {score = sc, ne = ne, nm = nm, onBomb = onBomb, selfHit = selfHit, dir = dir, pts = pts, bounces = bnc, rest = rest, bank = bank}
                end
            end
        end
        local function dirOf(yawDeg, pitchDeg)
            local y, p = math.rad(yawDeg), math.rad(pitchDeg)
            return Vector3.new(math.sin(y) * math.cos(p), math.sin(p), -math.cos(y) * math.cos(p))
        end

        -- sweep every direction around you (this is what finds bank shots)
        for yaw = 0, 354, 6 do
            for pitch = -6, 78, 7 do run(dirOf(yaw, pitch)) end
        end
        -- refine the most promising hits
        local cands = {}
        for _, c in pairs(bestStatic) do cands[#cands + 1] = c end
        table.sort(cands, function(a, b) return a.err < b.err end)
        for i = 1, math.min(#cands, 12) do
            local c = cands[i]
            local yaw0 = math.deg(math.atan2(c.dir.X, -c.dir.Z))
            local pit0 = math.deg(math.asin(math.clamp(c.dir.Y, -1, 1)))
            for dy = -3, 3, 1.5 do
                for dp = -3, 3, 1.5 do
                    if dy ~= 0 or dp ~= 0 then run(dirOf(yaw0 + dy, pit0 + dp)) end
                end
            end
        end
        table.sort(dyn, function(a, b) return a.score > b.score end)
        local dynPicked = {}
        for _, r in ipairs(dyn) do
            local distinct = true
            for _, q in ipairs(dynPicked) do if q.dir:Dot(r.dir) > 0.996 then distinct = false break end end
            if distinct then dynPicked[#dynPicked + 1] = r end
            if #dynPicked >= 3 then break end
        end

        -- final list: best throws at players / the bomb first, then map spots (direct and bank shots)
        local list = {}
        for i, r in ipairs(dynPicked) do
            r.title = string.format("%s · TARGET #%d%s", kind:upper(), i, r.bank and " (BANK)" or "")
            local parts = {}
            if r.onBomb then parts[#parts + 1] = "<font color='#ffb040'>ON THE BOMB</font>" end
            parts[#parts + 1] = string.format("%d enem%s", r.ne, r.ne == 1 and "y" or "ies")
            if r.nm > 0 then parts[#parts + 1] = string.format("<font color='#ff5050'>%d TEAM</font>", r.nm) end
            if r.selfHit then parts[#parts + 1] = "<font color='#ff5050'>SELF</font>" end
            r.detail = table.concat(parts, " · ")
            list[#list + 1] = r
        end
        local statics = {}
        for _, c in pairs(bestStatic) do statics[#statics + 1] = c end
        table.sort(statics, function(a, b) return a.err < b.err end)
        for _, c in ipairs(statics) do
            if #list >= SUG_MAX then break end
            local distinct = true
            for _, q in ipairs(list) do if q.dir:Dot(c.dir) > 0.998 then distinct = false break end end
            if distinct then
                c.title = c.label
                c.detail = (c.bank and "<font color='#c080ff'>BANK SHOT</font>" or "direct") .. string.format(" · %s · miss %.1f", kind, c.err)
                list[#list + 1] = c
            end
        end
        sugComputing = false
        if heldGrenade() and SUG_KIND[heldGrenade()] == kind and suggestOn then
            sugOrigin = origin
            showSuggestions(list, origin, kind)
            shared.MH_Log(string.format("suggestions: %s from (%.0f,%.0f,%.0f): %d sims, %d map targets in range, %d map throws (%d bank), %d player throws",
                kind, origin.X, origin.Y, origin.Z, n, #tlist, #statics, (function() local b = 0 for _, c in ipairs(statics) do if c.bank then b += 1 end end return b end)(), #dynPicked))
        end
    end

    local sugAcc = 0
    KING_KC(RunService.Heartbeat, function(dt)
        sugAcc += dt
        if sugAcc < 0.25 then return end
        sugAcc = 0
        local held = heldGrenade()
        local cam = workspace.CurrentCamera
        if not suggestOn or not held or not SUG_KIND[held] or not cam then
            if sugOrigin or next(sugMarks) then clearSug() end
            return
        end
        -- markers are only valid for the spot they were computed at
        if sugOrigin and (cam.CFrame.Position - (sugOrigin - Vector3.new(0, jumpThrow and jumpOffset or 0, 0))).Magnitude > 4 then clearSug() end
        if not sugComputing then task.spawn(computeSuggestions) end
    end)

    -- automatic: log the map when you join; when you spawn, load its target spots (takes a few seconds, no long search)
    task.spawn(function()
        local loggedMap, loadedMap
        while true do
            task.wait(2)
            local m = workspace:GetAttribute("Map")
            if m and m ~= loggedMap then
                loggedMap = m
                shared.MH_Log(string.format("joined map: %s  (gamemode %s, state %s)", tostring(m),
                    tostring(workspace:GetAttribute("Gamemode")), tostring(workspace:GetAttribute("GameState"))))
            end
            local mp = workspace:FindFirstChild("Map")
            if m and mp and m ~= loadedMap and mp:FindFirstChild("Zones") then
                local char = CharRes.getLocalCharacter()
                if char and char:FindFirstChild("HumanoidRootPart") and IsAlive(LocalPlayer) then
                    loadedMap = m
                    mapTargets = {}
                    local okP, plan = pcall(computePlan, true)
                    if okP and plan then
                        local ignoreP = RaycastParams.new()
                        ignoreP.FilterType = Enum.RaycastFilterType.Exclude
                        ignoreP.FilterDescendantsInstances = GetRayIgnore()
                        local count = 0
                        for _, req in ipairs(plan.requests) do
                            local tx, ty, tz = req.target[1], req.target[2], req.target[3]
                            local r = workspace:Raycast(Vector3.new(tx, ty + 4, tz), Vector3.new(0, -14, 0), ignoreP)
                            local y = (r and r.Position.Y or (ty - (req.yoff or 0))) + (req.yoff or 0)
                            mapTargets[req.kind] = mapTargets[req.kind] or {}
                            table.insert(mapTargets[req.kind], {pos = Vector3.new(tx, y, tz), label = req.label})
                            count += 1
                        end
                        shared.MH_Log(string.format("map %s: %d target spots loaded for live lineups", tostring(m), count))
                        Notify(string.format("%s: %d grenade targets ready", tostring(m), count), 3, C.teal)
                    else
                        shared.MH_Log("map " .. tostring(m) .. ": could not load target spots: " .. tostring(plan))
                    end
                end
            end
        end
    end)

    toggle(TAB, "Show path while holding a grenade", true, function(v) enabled = v end)
    toggle(TAB, "Assume jump-throw", false, function(v) jumpThrow = v end)
    toggle(TAB, "Live throw suggestions (flash / molotov / HE)", true, function(v) suggestOn = v; if not v then clearSug() end end)
    slider(TAB, "Jump-throw camera height", 0, 8, 3, function(v) jumpOffset = v end,
        function(v) return string.format("+%.1f studs", v) end)
    local typeBtn
    typeBtn = button(TAB, "Throw type: Far (left click)", function()
        throwType = throwType == "Far" and "Near" or "Far"
        typeBtn.Text = throwType == "Far" and "Throw type: Far (left click)" or "Throw type: Near (right click)"
    end)
    shared.MH_GrenTab = TAB
end)

-- =============================================================================
--  GRENADE RESULTS  (counts enemies flashed / damaged by YOUR grenades; display only)
--  Flash: uses a game flash/blind attribute if one exists, otherwise an estimate
--  (in range + clear line of sight + facing the flash). Damage: health drops of nearby
--  players in the seconds after your HE / molotov goes off.
-- =============================================================================
shared.MH_Try('Results tab', function()
    local RS = game:GetService("ReplicatedStorage")
    local TAB = shared.MH_GrenTab or createTab("📊", "Results")
    local okGRI, rawGRI = pcall(require, RS.Components.Common.GetRayIgnore)
    local GetRayIgnore = (function(raw)
        -- the game's GetRayIgnore can error when it is a copy loaded outside the game's own scripts (e.g. on Xeno):
        -- fall back to ignoring the camera and our own character
        return function()
            local ok, r = pcall(raw)
            if ok and type(r) == "table" then return r end
            local lpc = game:GetService("Players").LocalPlayer.Character
            return {workspace.CurrentCamera, lpc}
        end
    end)(okGRI and rawGRI or function() error("unavailable") end)
    local session = {flashed = 0, teamFlashed = 0, damaged = 0, damage = 0, throws = 0}
    local lastLine = "no grenades thrown yet"
    local hudOn = true
    local KIND = {["Smoke Grenade"] = "smoke", ["Flashbang"] = "flash", ["Molotov"] = "molotov",
                  ["Incendiary Grenade"] = "molotov", ["HE Grenade"] = "he", ["Decoy Grenade"] = "decoy"}

    local gui = Instance.new("ScreenGui")
    gui.Name = game:GetService("HttpService"):GenerateGUID(false)
    gui.ResetOnSpawn = false
    gui.Parent = GuiParent
    local box = Instance.new("Frame", gui)
    box.Size = UDim2.fromOffset(330, 78)
    box.Position = UDim2.new(0, 12, 0.55, 0)
    box.BackgroundColor3 = Color3.fromRGB(8, 14, 14)
    box.BackgroundTransparency = 0.25
    box.BorderSizePixel = 0
    corner(box, 6)
    stroke(box, C.teal, 1.5, 0.3)
    local label = Instance.new("TextLabel", box)
    label.Size = UDim2.new(1, -16, 1, -8)
    label.Position = UDim2.fromOffset(8, 4)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextColor3 = C.text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.RichText = true

    local function refresh()
        box.Visible = hudOn and session.throws > 0   -- only appears after your first grenade
        label.Text = string.format(
            "<b>GRENADE RESULTS</b>\n%s\n<font color='#ffeb5a'>Flashed %d</font>  ·  <font color='#ff5050'>Damaged %d (%d dmg)</font>  ·  team flashed %d",
            lastLine, session.flashed, session.damaged, math.floor(session.damage), session.teamFlashed)
    end
    refresh()

    local loggedKey = false
    local function flashAttr(plr)
        local found, val = false, false
        for _, src in ipairs({plr, plr.Character}) do
            if src then
                for k, v in pairs(src:GetAttributes()) do
                    local lk = k:lower()
                    if lk:find("flash", 1, true) or lk:find("blind", 1, true) then
                        found = true
                        if not loggedKey then
                            loggedKey = true
                            shared.MH_Log(string.format("flash attribute key: %s on %s = %s", k, src == plr and "player" or "character", tostring(v)))
                        end
                        if v == true or (type(v) == "number" and v > 0) then val = true end
                    end
                end
            end
        end
        return found, val
    end

    -- remember whether each player was already flashed, so only NEW flashes from my grenade count
    local flashHist = {}
    task.spawn(function()
        while true do
            task.wait(0.1)
            local now = os.clock()
            for _, plr in ipairs(Players:GetPlayers()) do
                local found, val = flashAttr(plr)
                if found then
                    local h = flashHist[plr] or {}
                    h[#h + 1] = {now, val}
                    while #h > 0 and now - h[1][1] > 4 do table.remove(h, 1) end
                    flashHist[plr] = h
                end
            end
        end
    end)
    local function wasFlashed(plr, atTime)
        local h = flashHist[plr]
        local state = false
        for _, r in ipairs(h or {}) do
            if r[1] <= atTime then state = r[2] else break end
        end
        return state
    end

    local function candidates(pos, range)
        local list = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and IsAlive(plr) then
                local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - pos).Magnitude <= range then list[#list + 1] = plr end
            end
        end
        return list
    end

    local function evalFlash(pos)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = GetRayIgnore()
        local list = candidates(pos, 70)
        local tExp = os.clock()
        task.wait(0.25)
        local nE, nT, mode = 0, 0, "est."
        for _, plr in ipairs(list) do
            if plr.Character then
                local found, val = flashAttr(plr)
                local hit
                if found then
                    mode = "confirmed"
                    local before = wasFlashed(plr, tExp - 0.35)
                    hit = val and not before
                    shared.MH_Log(string.format('flash attr %s flashed=%s alreadyFlashedBefore=%s', plr.Name, tostring(val), tostring(before)))
                else
                    local head = plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("HumanoidRootPart")
                    local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                    if head and hrp then
                        local dir = head.Position - pos
                        local ray = workspace:Raycast(pos, dir, params)
                        local clear = not ray or ray.Instance:IsDescendantOf(plr.Character)
                        local facing = hrp.CFrame.LookVector:Dot((pos - head.Position).Unit) > -0.15
                        hit = clear and facing
                        shared.MH_Log(string.format('flash est %s clear=%s facing=%s', plr.Name, tostring(clear), tostring(facing)))
                    end
                end
                if hit then
                    if IsTeammate(plr) then nT += 1 else nE += 1 end
                end
            end
        end
        session.flashed += nE
        session.teamFlashed += nT
        lastLine = string.format("Flashbang: <font color='#ffeb5a'>%d enemies flashed</font>, %d teammates (%s)", nE, nT, mode)
        refresh()
        Notify(string.format("Flash: %d enemies, %d teammates (%s)", nE, nT, mode), 4, nE > 0 and C.green or C.gold)
    end

    local healthLogged = false
    local function getHealth(plr)
        local ch = plr.Character
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if hum then return hum.Health, "humanoid" end
        for _, src in ipairs({ch, plr}) do
            if src then
                local h = src:GetAttribute("Health")
                if type(h) == "number" then return h, "attribute" end
            end
        end
        return nil
    end

    local function evalDamage(kind, pos)
        local duration = kind == "molotov" and 7.5 or 1.4
        local start, minHp = {}, {}
        local cand = candidates(pos, 45)
        for _, plr in ipairs(cand) do
            local hp, srcName = getHealth(plr)
            if hp then start[plr] = hp; minHp[plr] = hp end
            shared.MH_Log(string.format("%s start: %s dist=%.1f health=%s via %s", kind, plr.Name, (plr.Character.HumanoidRootPart.Position - pos).Magnitude, tostring(hp), tostring(srcName)))
        end
        if #cand == 0 then shared.MH_Log(kind .. ": nobody within 45 studs of the blast") end
        if not healthLogged then
            healthLogged = true
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    local names = {}
                    for _, src in ipairs({plr, plr.Character}) do
                        for k, v in pairs(src:GetAttributes()) do
                            local lk = k:lower()
                            if lk:find("health", 1, true) or lk:find("hp", 1, true) then names[#names + 1] = k .. "=" .. tostring(v) end
                        end
                    end
                    shared.MH_Log("health-related attributes on " .. plr.Name .. ": " .. (#names > 0 and table.concat(names, ", ") or "none"))
                    break
                end
            end
        end
        local t0 = os.clock()
        while os.clock() - t0 < duration do
            for plr in pairs(start) do
                local hp = getHealth(plr)
                if hp then minHp[plr] = math.min(minHp[plr], hp) end
            end
            task.wait(0.1)
        end
        local nE, nT, dmgE = 0, 0, 0
        for plr, hp in pairs(start) do
            local drop = hp - minHp[plr]
            if drop > 0.5 then
                shared.MH_Log(string.format('%s damage %s: %.0f', kind, plr.Name, drop))
                if IsTeammate(plr) then nT += 1 else nE += 1; dmgE += drop end
            end
        end
        session.damaged += nE
        session.damage += dmgE
        lastLine = string.format("%s: <font color='#ff5050'>%d enemies hurt (%d dmg)</font>, %d teammates (est.)",
            kind == "molotov" and "Molotov" or "HE", nE, math.floor(dmgE), nT)
        refresh()
        Notify(string.format("%s: %d enemies hurt, %d dmg", kind == "molotov" and "Molotov" or "HE", nE, math.floor(dmgE)),
            4, nE > 0 and C.green or C.gold)
    end

    local function watch(model)
        task.wait()
        if not model.Parent then return end
        local name = model:GetAttribute("GrenadeName")
        local kind = name and KIND[name]
        if not kind then return end
        local cam = workspace.CurrentCamera
        local pos = model:GetPivot().Position
        -- only grenades that spawn at your own throwing position count as yours
        if not (cam and (pos - cam.CFrame.Position).Magnitude < 10) then return end
        session.throws += 1
        shared.MH_Log('my grenade spawned: ' .. tostring(name))
        lastLine = string.format('%s thrown, waiting for result...', name)
        refresh()
        local last = pos
        local conn
        conn = KING_KC(RunService.Heartbeat, function()
            if model.Parent then
                last = model:GetPivot().Position
            else
                conn:Disconnect()
                if kind == "flash" then task.spawn(evalFlash, last)
                elseif kind == "he" or kind == "molotov" then task.spawn(evalDamage, kind, last)
                else lastLine = string.format("%s thrown", name); refresh() end
            end
        end)
    end

    local debris = workspace:FindFirstChild("Debris") or workspace:WaitForChild("Debris", 10)
    if debris then
        KING_KC(debris.ChildAdded, function(m) if m:IsA("Model") then task.spawn(watch, m) end end)
    end

    toggle(TAB, "Show results panel", true, function(v) hudOn = v; refresh() end)
    button(TAB, "Reset counters", function()
        session = {flashed = 0, teamFlashed = 0, damaged = 0, damage = 0, throws = 0}
        lastLine = "counters reset"
        refresh()
    end)
end)

-- =============================================================================
--  BOMB TIMER + DEFUSE ALERT  (display only)
--  The countdown is read from the bomb itself (attribute or its screen text), falling back to the round timer
--  or an estimate. "Defusing" is read from any defuse attribute on the bomb or players.
--  It logs what it finds, so the exact source can be pinned down from hub_log.txt.
-- =============================================================================
shared.MH_Try('Bomb timer', function()
    local BOMB_TOTAL = 40          -- fallback only, if no countdown can be read
    local DEFUSE_SECONDS, DEFUSE_KIT_SECONDS = 10, 5
    local on = true
    local gui = Instance.new("ScreenGui")
    gui.Name = game:GetService("HttpService"):GenerateGUID(false)
    gui.ResetOnSpawn = false
    gui.Parent = GuiParent
    local box = Instance.new("Frame", gui)
    box.Size = UDim2.fromOffset(280, 66)
    box.Position = UDim2.new(0.5, -140, 0, 78)
    box.BackgroundColor3 = Color3.fromRGB(8, 14, 14)
    box.BackgroundTransparency = 0.2
    box.BorderSizePixel = 0
    box.Visible = false
    corner(box, 8)
    local boxStroke = stroke(box, C.gold, 2, 0.1)
    local label = Instance.new("TextLabel", box)
    label.Size = UDim2.new(1, -16, 1, -8)
    label.Position = UDim2.fromOffset(8, 4)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 15
    label.TextColor3 = C.white
    label.RichText = true
    label.TextXAlignment = Enum.TextXAlignment.Center

    local seen = {}
    local function logOnce(tag, key, value)
        local id = tag .. "|" .. key
        if seen[id] then return end
        seen[id] = true
        shared.MH_Log(string.format("bomb info [%s] %s = %s", tag, key, tostring(value)))
    end

    local function parseClock(text)
        local m, sec = text:match("(%d+):(%d+%.?%d*)")
        if m then return tonumber(m) * 60 + tonumber(sec) end
        local only = text:match("^%s*(%d+%.?%d*)%s*$")
        if only then return tonumber(only) end
    end

    local bombRef, plantedAt, lastDefuser, lastLog = nil, nil, nil, 0
    -- the planted bomb carries BombPlanted = {"Site":..,"TimeUntilExplode":..,"Time":<server time>}
    local function findPlantedModel()
        local function check(c)
            if c:IsA("Model") and c:GetAttribute("BombPlanted") ~= nil and hasC4Shape(c) then return c end
        end
        local deb = workspace:FindFirstChild("Debris")
        if deb then for _, c in ipairs(deb:GetChildren()) do local m = check(c) if m then return m end end end
        local map = workspace:FindFirstChild("Map")
        if map then for _, c in ipairs(map:GetChildren()) do local m = check(c) if m then return m end end end
        for _, c in ipairs(workspace:GetChildren()) do local m = check(c) if m then return m end end
        return nil
    end
    local function plantedInfo(bomb)
        local raw = bomb:GetAttribute("BombPlanted")
        if type(raw) ~= "string" then return nil end
        local ok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end)
        if ok and type(data) == "table" then return data end
    end

    local function readTimer(bomb)
        local info = plantedInfo(bomb)
        if info and type(info.Time) == "number" and type(info.TimeUntilExplode) == "number" then
            local left = info.Time + info.TimeUntilExplode - workspace:GetServerTimeNow()
            return math.clamp(left, 0, info.TimeUntilExplode + 5), "BombPlanted (site " .. tostring(info.Site) .. ")"
        end
        -- fallbacks: attributes on the bomb (and its Weapon model) that look like a countdown
        for _, inst in ipairs({bomb, bomb:FindFirstChild("Weapon")}) do
            if inst then
                for k, v in pairs(inst:GetAttributes()) do
                    logOnce("attr " .. inst.Name, k, v)
                    local lk = k:lower()
                    if type(v) == "number" and (lk:find("time", 1, true) or lk:find("fuse", 1, true) or lk:find("explo", 1, true)
                        or lk:find("detonat", 1, true) or lk:find("remain", 1, true)) and v >= 0 and v <= 120 then
                        return v, "bomb attribute " .. k
                    end
                end
            end
        end
        -- 2) the text shown on the bomb's own screen
        for _, d in ipairs(bomb:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextBox") then
                logOnce("screen", d:GetFullName():sub(-40), d.Text)
                local t = parseClock(d.Text)
                if t and t >= 0 and t <= 120 then return t, "bomb screen" end
            end
        end
        -- 3) the round timer, when the round is in the bomb phase
        local gs = tostring(workspace:GetAttribute("GameState") or "")
        local tm = workspace:GetAttribute("Timer")
        logOnce("workspace", "GameState", gs)
        if type(tm) == "number" and (gs:lower():find("bomb", 1, true) or gs:lower():find("plant", 1, true)) then return tm, "round timer" end
        -- 4) estimate from when the bomb first appeared
        if plantedAt then return math.max(0, BOMB_TOTAL - (os.clock() - plantedAt)), "estimate" end
    end

    local lastVals = {}
    local function watchChange(tag, key, v)
        local id = tag .. "|" .. key
        if lastVals[id] ~= v then
            shared.MH_Log(string.format("bomb signal [%s] %s: %s -> %s", tag, key, tostring(lastVals[id]), tostring(v)))
            lastVals[id] = v
        end
    end
    local function interesting(k)
        local lk = k:lower()
        if lk:find("kit", 1, true) then return false end          -- HasDefuseKit is NOT someone defusing
        return lk:find("defus", 1, true) or lk:find("c4", 1, true) or lk:find("bomb", 1, true) or lk:find("plant", 1, true) or lk:find("interact", 1, true)
    end
    local function truthy(v)
        return v == true or (type(v) == "number" and v > 0) or (type(v) == "string" and v ~= "" and v ~= "false" and v ~= "0")
    end
    local function findDefuser(bomb)
        local who
        for _, inst in ipairs({bomb, bomb:FindFirstChild("Weapon")}) do
            if inst then
                for k, v in pairs(inst:GetAttributes()) do
                    if interesting(k) and k ~= "BombPlanted" then
                        watchChange("bomb " .. inst.Name, k, v)
                        if k:lower():find("defus", 1, true) and truthy(v) then
                            if type(v) == "number" and v > 100 then
                                local plr = Players:GetPlayerByUserId(v)
                                who = who or (plr and plr.Name or "someone")
                            elseif type(v) == "string" then who = who or v
                            else who = who or "someone" end
                        end
                    end
                end
            end
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            for _, src in ipairs({plr, plr.Character}) do
                if src then
                    for k, v in pairs(src:GetAttributes()) do
                        if interesting(k) then
                            watchChange((src == plr and "player " or "character ") .. plr.Name, k, v)
                            if k:lower():find("defus", 1, true) and truthy(v) then who = who or plr.Name end
                        end
                    end
                end
            end
        end
        return who
    end

    task.spawn(function()
        while true do
            task.wait(0.2)
            local bomb = on and findPlantedModel() or nil
            if not bomb or not bomb.Parent then
                box.Visible = false
                bombRef, plantedAt, lastDefuser = nil, nil, nil
            else
                if bomb ~= bombRef then
                    bombRef, plantedAt = bomb, os.clock()
                    local p = bomb:GetPivot().Position
                    shared.MH_Log(string.format("bomb planted/found at (%.0f,%.0f,%.0f)", p.X, p.Y, p.Z))
                end
                local remaining, source = readTimer(bomb)
                local defuser = findDefuser(bomb)
                if defuser ~= lastDefuser then
                    if defuser then Notify("DEFUSING: " .. defuser, 4, C.red) end
                    shared.MH_Log("defuser changed: " .. tostring(lastDefuser) .. " -> " .. tostring(defuser))
                    lastDefuser = defuser
                end
                box.Visible = true
                local lines = {}
                local color = C.gold
                if remaining then
                    local approx = source == "estimate" and "~" or ""
                    local hex = remaining > 20 and "#50c878" or (remaining > 10 and "#ffeb5a" or "#ff5050")
                    color = remaining > 20 and C.green or (remaining > 10 and C.gold or C.red)
                    local siteTag = tostring(source):match("site (%w+)")
                    lines[1] = string.format("💣%s <font color='%s'>%s%.1fs</font>", siteTag and (" SITE " .. siteTag) or "", hex, approx, remaining)
                else
                    lines[1] = "💣 BOMB PLANTED"
                end
                if defuser then
                    local need = DEFUSE_SECONDS
                    local verdict = ""
                    if remaining then
                        verdict = remaining >= need and string.format("  ·  <font color='#ffeb5a'>fits if no kit (%ds)</font>", need)
                            or (remaining >= DEFUSE_KIT_SECONDS and string.format("  ·  <font color='#ffb040'>only with a kit (%ds)</font>", DEFUSE_KIT_SECONDS)
                            or "  ·  <font color='#ff5050'>TOO LATE</font>")
                    end
                    lines[2] = string.format("<font size='13' color='#ff5050'>⚠ %s IS DEFUSING</font>%s", defuser:upper(), verdict)
                    color = C.red
                else
                    lines[2] = "<font size='12' color='#8aa8a4'>nobody defusing</font>"
                end
                label.Text = table.concat(lines, "\n")
                boxStroke.Color = color
                if os.clock() - lastLog > 5 then
                    lastLog = os.clock()
                    shared.MH_Log(string.format("bomb: remaining=%s via %s, defuser=%s", remaining and string.format("%.1f", remaining) or "?", tostring(source), tostring(defuser)))
                end
            end
        end
    end)

    toggle(BOMB_TAB, "Bomb timer + defuse alert", true, function(v) on = v; if not v then box.Visible = false end end)
end)

-- =============================================================================
--  BOX ESP + GUN CHAMS  (display only: boxes drawn on your screen, a highlight on your own weapon)
-- =============================================================================
shared.MH_Try('Box ESP + gun chams', function()
    local RS = game:GetService("ReplicatedStorage")
    local boxOn, chamsOn = true, true
    local chamsPulse, chamsTrans, chamsIdx = false, 0.45, 2
    local CHAMS_COLORS = {
        {"Rainbow", nil}, {"Cyan", Color3.fromRGB(0, 230, 210)}, {"Red", Color3.fromRGB(255, 60, 60)},
        {"Gold", Color3.fromRGB(255, 200, 60)}, {"White", Color3.fromRGB(255, 255, 255)}, {"Pink", Color3.fromRGB(255, 90, 200)},
    }

    -- ---------- box ESP ----------
    local boxGui = Instance.new("ScreenGui")
    boxGui.Name = game:GetService("HttpService"):GenerateGUID(false)
    boxGui.ResetOnSpawn = false
    boxGui.IgnoreGuiInset = true
    boxGui.Parent = GuiParent
    local boxes = {}
    shared.MH_Boxes = boxes
    -- ---------- network positions ----------
    -- The game hides players you can't see: their characters are parked in ReplicatedStorage._PVS_CulledCharacters and
    -- stop moving. But its full movement snapshots (MovementV2Remotes.RemoteSnapshot, ~15 a second) still carry every
    -- player's real root position, keyed by UserId. Layout in front of each position: <UserId varint><sequence varint><1 byte>.
    -- Listen-only: this just reads packets the game already receives.
    local net = {}                      -- userId -> {pos = Vector3, t = os.clock(), vel = Vector3}
    shared.MH_Net = net
    local idSet, idSetAt = {}, 0
    local function refreshIds()
        if os.clock() - idSetAt < 1 then return end
        idSetAt = os.clock()
        idSet = {}
        for _, pl in ipairs(Players:GetPlayers()) do idSet[pl.UserId] = true end
    end
    local function plausible(v) return v == v and (v == 0 or (v > -5000 and v < 5000 and (v > 0.01 or v < -0.01))) end
    local function idBefore(b, off)
        local i = off - 2                                   -- last byte of the sequence varint
        if i < 1 or buffer.readu8(b, i) >= 128 then return nil end
        local st = i
        while st > 0 and buffer.readu8(b, st - 1) >= 128 and i - st < 3 do st -= 1 end
        local e = st - 1                                    -- last byte of the UserId varint
        if e < 2 or buffer.readu8(b, e) >= 128 then return nil end
        for n = 3, 6 do
            local first = e - n + 1
            if first < 0 then break end
            local okC = true
            for k = first, e - 1 do if buffer.readu8(b, k) < 128 then okC = false break end end
            if okC then
                local v, mul = 0, 1
                for k = first, e do v += (buffer.readu8(b, k) % 128) * mul; mul *= 128 end
                if idSet[v] then return v end
            end
        end
        return nil
    end
    task.spawn(function()
        local folder = RS:WaitForChild("MovementV2Remotes", 15)
        local rem = folder and folder:WaitForChild("RemoteSnapshot", 15)
        if not rem then shared.MH_Log("net ESP: RemoteSnapshot not found") return end
        shared.MH_Log("net ESP: listening to RemoteSnapshot")
        local logged = 0
        KING_KC(rem.OnClientEvent, function(b)
            if typeof(b) ~= "buffer" then return end
            local len = buffer.len(b)
            if len < 60 then return end                     -- only full snapshots carry positions
            refreshIds()
            local now = os.clock()
            local off, found = 4, 0
            while off <= len - 12 do
                local x, y, z = buffer.readf32(b, off), buffer.readf32(b, off + 4), buffer.readf32(b, off + 8)
                local uid = nil
                if plausible(x) and plausible(y) and plausible(z) and y > -500 and y < 1500 then uid = idBefore(b, off) end
                if uid then
                    local pos = Vector3.new(x, y, z)
                    local prev = net[uid]
                    local vel = Vector3.zero
                    if prev then
                        local dt = now - prev.t
                        if dt > 0.02 and dt < 0.5 then vel = (pos - prev.pos) / dt end
                    end
                    net[uid] = {pos = pos, t = now, vel = vel}
                    found += 1
                    off += 12
                else
                    off += 1
                end
            end
            if logged < 3 then
                logged += 1
                shared.MH_Log(string.format("net ESP: snapshot %d bytes -> %d player positions decoded", len, found))
            end
        end)
    end)
    local function makeBox(plr)
        local f = Instance.new("Frame", boxGui)
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 0
        f.Visible = false
        local st = Instance.new("UIStroke", f)
        st.Thickness = 1.6
        st.Color = Color3.fromRGB(255, 60, 60)
        st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        boxes[plr] = f
        return f
    end
    KING_KC(Players.PlayerRemoving, function(plr)
        if boxes[plr] then boxes[plr]:Destroy(); boxes[plr] = nil end
    end)

    -- ---------- gun chams ----------
    local hl, hlModel
    local function killChams()
        if hl then hl:Destroy() end
        hl, hlModel = nil, nil
    end
    local function heldModel()
        local cam = workspace.CurrentCamera
        local assets = RS:FindFirstChild("Assets")
        local weapons = assets and assets:FindFirstChild("Weapons")
        if not (cam and weapons) then return nil end
        for _, m in ipairs(cam:GetChildren()) do
            if m:IsA("Model") and weapons:FindFirstChild(m.Name) then return m end
        end
    end

    -- ---------- heard ESP ----------
    -- Hidden players' movement isn't sent, but their SOUNDS are (ReplicateSound: footsteps, scoping, reloads...) and
    -- so are their shots (CreateTracer has the muzzle Origin). Each of those is pinned on the hidden player who could
    -- have made it (nearest one that could have walked there since they were last placed), and that player's box is
    -- drawn there in yellow, fading out over a few seconds. Messages are 01 + zstd frame + serialized table; small
    -- ones are stored uncompressed (raw blocks) and decoded here. Listen-only.
    local heard = {}          -- player -> {pos, t, what}
    local culledAt = {}       -- player -> os.clock() when they went hidden
    shared.MH_Heard = heard
    local function unzstd(b)
        local len = buffer.len(b)
        if len < 10 or buffer.readu8(b, 0) ~= 1 or buffer.readu32(b, 1) ~= 0xFD2FB528 then return nil end
        local desc = buffer.readu8(b, 5)
        local single = bit32.band(bit32.rshift(desc, 5), 1) == 1
        local pos = 6 + (single and 0 or 1) + ({0, 1, 2, 4})[bit32.band(desc, 3) + 1]
        pos += ({single and 1 or 0, 2, 4, 8})[bit32.rshift(desc, 6) + 1]
        local parts, total = {}, 0
        while pos + 3 <= len do
            local h = buffer.readu8(b, pos) + buffer.readu8(b, pos + 1) * 256 + buffer.readu8(b, pos + 2) * 65536
            pos += 3
            local btype, size = math.floor(h / 2) % 4, math.floor(h / 8)
            if btype == 0 then
                if pos + size > len then return nil end
                parts[#parts + 1] = {pos, size}; total += size; pos += size
            else
                return nil                                   -- RLE / really compressed: not needed for these
            end
            if h % 2 == 1 then break end
        end
        local o = buffer.create(total)
        local w = 0
        for _, pt in ipairs(parts) do buffer.copy(o, w, b, pt[1], pt[2]); w += pt[2] end
        return o
    end
    local function readValue(b, i)
        local t = buffer.readu8(b, i); i += 1
        if t == 0x06 or t == 0x05 then
            local n = buffer.readu32(b, i); i += 4
            if n > 200 then error("size") end
            local d = {}
            for k = 1, n do
                if t == 0x06 then
                    local key, v
                    key, i = readValue(b, i)
                    v, i = readValue(b, i)
                    d[tostring(key)] = v
                else
                    d[k], i = readValue(b, i)
                end
            end
            return d, i
        elseif t == 0x04 then
            local n = buffer.readu32(b, i); i += 4
            return buffer.readstring(b, i, n), i + n
        elseif t == 0x03 then return buffer.readf64(b, i), i + 8
        elseif t == 0x07 then return Vector3.new(buffer.readf32(b, i), buffer.readf32(b, i + 4), buffer.readf32(b, i + 8)), i + 12
        elseif t == 0x09 then return Vector3.new(buffer.readf32(b, i), buffer.readf32(b, i + 4), buffer.readf32(b, i + 8)), i + 48   -- CFrame: position only
        elseif t == 0x0c then return nil, i + 4                                                                               -- instance ref
        elseif t == 0x00 then return nil, i
        elseif t == 0x01 then return false, i
        elseif t == 0x02 then return true, i
        end
        error("type")
    end
    local function decode(b)
        local raw = unzstd(b)
        if not raw then return nil end
        local ok, v = pcall(readValue, raw, 0)
        return ok and v or nil
    end
    -- grenades / bomb / world effects make sounds away from any player: never pin those on someone
    local SKIP_CLASS = {Flashbang = true, Smoke = true, Molotov = true, Incendiary = true, HE = true, Decoy = true,
        Grenade = true, Bomb = true, C4 = true, Impact = true, Bullet = true, Explosion = true, Fire = true}
    local classesSeen, classLog = {}, 0
    local function pin(pos, what)
        local now = os.clock()
        -- made by someone you can already see (or you)? then it's not news
        for _, pl in ipairs(Players:GetPlayers()) do
            local ch = pl.Character
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            if hrp and ch.Parent and ch.Parent.Name ~= "_PVS_CulledCharacters" and (hrp.Position - pos).Magnitude < 8 then return end
        end
        local best, bestD
        for _, pl in ipairs(Players:GetPlayers()) do
            local ch = pl.Character
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            if pl ~= LocalPlayer and hrp and ch.Parent and ch.Parent.Name == "_PVS_CulledCharacters" and IsAlive(pl) then
                local h = heard[pl]
                local from, since
                if h and h.t >= (culledAt[pl] or 0) then from, since = h.pos, h.t
                else from, since = hrp.Position, culledAt[pl] or now end
                local d = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(from.X, 0, from.Z)).Magnitude
                local reach = 22 * (now - since) + 12                   -- ~run speed since they were last placed
                if d <= reach and (not bestD or d < bestD) then best, bestD = pl, d end
            end
        end
        if best then heard[best] = {pos = pos, t = now, what = what} end
    end
    task.spawn(function()
        local function hook(name, fn)
            local r = RS:FindFirstChild(name, true)
            if not r then
                local t0 = os.clock()
                repeat task.wait(1); r = RS:FindFirstChild(name, true) until r or os.clock() - t0 > 20
            end
            if not (r and (r:IsA("RemoteEvent") or r:IsA("UnreliableRemoteEvent"))) then shared.MH_Log("heard ESP: " .. name .. " not found") return end
            KING_KC(r.OnClientEvent, function(b) if typeof(b) == "buffer" then local v = decode(b); if type(v) == "table" then fn(v) end end end)
            shared.MH_Log("heard ESP: listening to " .. name)
        end
        hook("ReplicateSound", function(v)
            local pos = v.Position
            if typeof(pos) ~= "Vector3" then return end
            local cls = tostring(v.Class or "?")
            if classLog < 25 and not classesSeen[cls .. "/" .. tostring(v.Name)] then
                classesSeen[cls .. "/" .. tostring(v.Name)] = true
                classLog += 1
                shared.MH_Log("heard ESP: sound class=" .. cls .. " name=" .. tostring(v.Name))
            end
            if SKIP_CLASS[cls] then return end
            pin(pos, cls == "FloorSounds" and "step" or tostring(v.Name or cls))
        end)
        hook("CreateTracer", function(v)
            if typeof(v.Origin) == "Vector3" then pin(v.Origin, "shot") end
        end)
    end)

    KING_RENDER(function()
        local cam = workspace.CurrentCamera
        -- boxes
        local seen = {}
        if boxOn and cam then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and IsAlive(plr) and not IsTeammate(plr) then
                    local ch = plr.Character
                    local stale = ch.Parent and ch.Parent.Name == "_PVS_CulledCharacters"   -- frozen at the last position the game sent
                    local head = ch and ch:FindFirstChild("Head")
                    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                    -- hidden (culled) players: move the frozen body to the real position from the network snapshots
                    local shift = Vector3.zero
                    local heardAge
                    if stale then
                        culledAt[plr] = culledAt[plr] or os.clock()
                    else
                        culledAt[plr], heard[plr] = nil, nil
                    end
                    if stale and hrp then
                        local np = net[plr.UserId]
                        if np and os.clock() - np.t < 1.5 then
                            local ahead = math.min(os.clock() - np.t, 0.15)
                            shift = (np.pos + np.vel * ahead) - hrp.Position
                            stale = false
                        end
                    end
                    -- heard / shot while hidden: draw them where the sound came from
                    if stale and hrp and heard[plr] and os.clock() - heard[plr].t < 4 then
                        heardAge = os.clock() - heard[plr].t
                        shift = heard[plr].pos - hrp.Position
                    end
                    if head and hrp then
                        local hp, onH = cam:WorldToViewportPoint(head.Position + shift + Vector3.new(0, 0.6, 0))
                        local fp, onF = cam:WorldToViewportPoint(hrp.Position + shift - Vector3.new(0, 2.6, 0))
                        if onH and onF and hp.Z > 0 and fp.Z > 0 then
                            local h = math.abs(fp.Y - hp.Y)
                            if h >= 6 then
                                local w = h * 0.55
                                local f = boxes[plr] or makeBox(plr)
                                local st = f:FindFirstChildOfClass("UIStroke")
                                if st then
                                    if heardAge then
                                        st.Color = Color3.fromRGB(255, 230, 60)                 -- heard: yellow, fading
                                        st.Transparency = math.clamp(heardAge / 4, 0, 0.75)
                                    else
                                        st.Color = stale and Color3.fromRGB(255, 160, 40) or Color3.fromRGB(255, 60, 60)
                                        st.Transparency = stale and 0.6 or 0
                                    end
                                end
                                f.Position = UDim2.fromOffset((hp.X + fp.X) / 2 - w / 2, hp.Y)
                                f.Size = UDim2.fromOffset(w, h)
                                f.Visible = true
                                seen[plr] = true
                            end
                        end
                    end
                end
            end
        end
        for plr, f in pairs(boxes) do
            if not seen[plr] then f.Visible = false end
        end
        -- chams
        if not chamsOn or not cam then killChams() return end
        local m = heldModel()
        if not m then killChams() return end
        if hlModel ~= m or not hl or not hl.Parent then
            killChams()
            hl = Instance.new("Highlight")
            hl.Name = "chams"
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Adornee = m
            hl.Parent = cam
            hlModel = m
        end
        local entry = CHAMS_COLORS[chamsIdx]
        local col = entry[2] or Color3.fromHSV((os.clock() * 0.3) % 1, 1, 1)
        hl.FillColor = col
        hl.OutlineColor = col
        hl.FillTransparency = chamsPulse and (0.3 + 0.5 * math.abs(math.sin(os.clock() * 2))) or chamsTrans
        hl.OutlineTransparency = 0
    end)

    toggle(VIS_TAB, "Box ESP", true, function(v) boxOn = v; shared.MH_BoxOn = v end)
    toggle(VIS_TAB, "Gun Chams", true, function(v) chamsOn = v; if not v then killChams() end end)
    local colorBtn
    colorBtn = button(VIS_TAB, "Chams colour: " .. CHAMS_COLORS[chamsIdx][1], function()
        chamsIdx = chamsIdx % #CHAMS_COLORS + 1
        colorBtn.Text = "Chams colour: " .. CHAMS_COLORS[chamsIdx][1]
    end)
    slider(VIS_TAB, "Chams transparency", 0, 1, chamsTrans, function(v) chamsTrans = v end,
        function(v) return string.format("%d%%", math.floor(v * 100)) end)
    toggle(VIS_TAB, "Chams pulse", false, function(v) chamsPulse = v end)

    shared.MH_BoxChamsOff = function() boxOn = false; chamsOn = false; killChams() end
end)

-- =============================================================================
--  MISC TAB
-- =============================================================================
button(MISC_TAB, "Disable All Features", cleanupAll)

-- =============================================================================
--  TOGGLE MENU
-- =============================================================================
KING_KC(FloatBtn.MouseButton1Click, function()
    panel.Visible = not panel.Visible
    FloatBtn.Visible = not panel.Visible
end)

KING_KC(UserInputService.InputBegan, function(i, g)
    if not g and (i.KeyCode == Enum.KeyCode.Insert or i.KeyCode == Enum.KeyCode.K) then
        panel.Visible = not panel.Visible
        FloatBtn.Visible = not panel.Visible
    end
end)

SelectTab(tabButtons["Visuals"], tabPages["Visuals"], "Visuals", "👁")

-- =============================================================================
--  DEBUG LOG: everything the ESP / triggerbot / players are doing, every 2 s, into king_hub/hub_log.txt
--  Debug tab: "Copy log to clipboard" copies the last 600 lines so they can be pasted straight into chat.
-- =============================================================================
shared.MH_Try('Debug log', function()
    local TAB = createTab("🛠", "Debug")
    local on = true
    local prev = {}
    local fpsAcc, fpsN = 0, 0
    local updCount, updLast = {}, {}      -- how many times per second a player's position actually changes
    local frameMax, hitches = 0, 0
    KING_KC(RunService.RenderStepped, function(dt)
        fpsAcc += dt; fpsN += 1
        if dt > frameMax then frameMax = dt end
        if dt > 0.025 then hitches += 1 end
        for _, plr in ipairs(Players:GetPlayers()) do
            local ch = plr ~= LocalPlayer and plr.Character
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            if hrp then
                local pos = hrp.Position
                if updLast[plr] and (pos - updLast[plr]).Magnitude > 0.01 then updCount[plr] = (updCount[plr] or 0) + 1 end
                updLast[plr] = pos
            end
        end
    end)
    local function log(m) shared.MH_Log(m) end
    local function snapshot()
        local cam = workspace.CurrentCamera
        local fps = fpsN > 0 and fpsN / fpsAcc or 0
        fpsAcc, fpsN = 0, 0
        local alive, enemies, mates, drawn = 0, 0, 0, 0
        local rows = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local ch = plr.Character
                local head = ch and ch:FindFirstChild("Head")
                local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                local isAlive = IsAlive(plr)
                local mate = IsTeammate(plr)
                if isAlive then alive += 1; if mate then mates += 1 else enemies += 1 end end
                local box = shared.MH_Boxes and shared.MH_Boxes[plr]
                local boxShown = box and box.Visible or false
                if boxShown then drawn += 1 end
                local dist, onScreen, moved = "-", "-", "-"
                if hrp and cam then
                    dist = string.format("%.0f", (hrp.Position - cam.CFrame.Position).Magnitude)
                    if head then local _, o = cam:WorldToViewportPoint(head.Position) onScreen = tostring(o) end
                    local pv = prev[plr]
                    if pv then moved = string.format("%.1f", (hrp.Position - pv).Magnitude) end
                    prev[plr] = hrp.Position
                end
                if isAlive then
                    local np = shared.MH_Net and shared.MH_Net[plr.UserId]
                    moved = moved .. (np and string.format(" netAge=%.1fs", os.clock() - np.t) or " netAge=none")
                    local upd = (updCount[plr] or 0) / 2
                    updCount[plr] = 0
                    rows[#rows + 1] = string.format("  %s team=%s %s dist=%s onScreen=%s box=%s movedSince2s=%s posUpdates/s=%.0f parent=%s",
                        plr.Name, tostring(GetTeam(plr)), mate and "TEAMMATE" or "ENEMY", dist, onScreen, tostring(boxShown), moved, upd,
                        ch and ch.Parent and ch.Parent.Name or "nil")
                end
            end
        end
        do
            local top = {}
            for label, e in pairs(shared.MH_Prof or {}) do top[#top + 1] = {label, e[1], e[2], e[3]} end
            table.sort(top, function(a, b) return a[2] > b[2] end)
            local parts = {}
            for i = 1, math.min(5, #top) do
                parts[#parts + 1] = string.format("%s=%.2fms/s(max %.1fms, %d calls)", top[i][1], top[i][2] / 2 * 1000, top[i][3] * 1000, top[i][4])
            end
            shared.MH_Prof = shared.MH_Prof or {}
            for k in pairs(shared.MH_Prof) do shared.MH_Prof[k] = nil end
            log(string.format("PERF slowestFrame=%.1fms framesOver25ms=%d | script cost per second, top5: %s", frameMax * 1000, hitches, table.concat(parts, "  ")))
            frameMax, hitches = 0, 0
        end
        log(string.format("SNAP fps=%.0f alive=%d enemies=%d teammates=%d boxesDrawn=%d | me team=%s | Box=%s Skel=%s Names=%s Trig=%s headOnly=%s BigHeads=%s TeamCheck=%s",
            fps, alive, enemies, mates, drawn, tostring(GetTeam(LocalPlayer)), tostring(shared.MH_BoxOn ~= false), tostring(Features.SkeletonESP),
            tostring(Features.NameTags), tostring(Features.Triggerbot), tostring(Features.TriggerHeadOnly), tostring(Features.BigHeads), tostring(Features.TeamCheck)))
        for _, r in ipairs(rows) do log(r) end
    end
    local running = true
    KING_ONUNLOAD(function() running = false end)
    task.spawn(function()
        while running do
            task.wait(2)
            if on and running then pcall(snapshot) end
        end
    end)
    toggle(TAB, "Debug log (every 2s)", true, function(v) on = v end)
    button(TAB, "Copy log to clipboard", function()
        local text = table.concat(shared.MH_Ring or {}, "\n")
        local copy = setclipboard or toclipboard or (syn and syn.write_clipboard)
        if copy then pcall(copy, text); log("log copied to clipboard (" .. #text .. " chars)") else log("no clipboard function; open king_hub/hub_log.txt") end
    end)
    button(TAB, "Clear log", function() shared.MH_Ring = {} end)
end)

-- =============================================================================
--  MAIN HEARTBEAT FOR PLANTED BOMB SCAN
-- =============================================================================
KING_KC(RunService.Heartbeat, function()
    pcall(runPlantedBombESP)
end)

-- =============================================================================
--  LOADER
-- =============================================================================
panel.Visible = false

task.spawn(function()
    local originalPos = UDim2.new(0.5, -panelW/2, 0.5, -panelH/2)
    panel.Position = UDim2.new(0.5, -panelW/2, 0.5, -panelH/2 + 60)

    local LoaderCard = Instance.new("Frame", gui)
    LoaderCard.Name = "KingLoader"
    LoaderCard.Size = UDim2.fromOffset(math.min(480, vp.X * 0.85), 260)
    LoaderCard.Position = UDim2.new(0.5, -math.min(480, vp.X * 0.85)/2, 0.5, -130)
    LoaderCard.BackgroundColor3 = C.panel
    LoaderCard.BorderSizePixel = 0
    LoaderCard.ZIndex = 9992
    corner(LoaderCard, 6)

    task.delay(6, function()
        pcall(function() if LoaderCard and LoaderCard.Parent then LoaderCard:Destroy() end end)
        pcall(function() if panel and not panel.Visible then panel.Visible = true; panel.Position = originalPos end end)
    end)

    local LS = Instance.new("UIStroke", LoaderCard)
    LS.Color = C.teal; LS.Thickness = 1.5

    local LogoBg = Instance.new("Frame", LoaderCard)
    LogoBg.Size = UDim2.fromOffset(60, 60); LogoBg.Position = UDim2.fromOffset(30, 28)
    LogoBg.BackgroundColor3 = C.teal; LogoBg.BorderSizePixel = 0; LogoBg.ZIndex = 9993
    corner(LogoBg, 4)

    local LogoText2 = Instance.new("TextLabel", LogoBg)
    LogoText2.Size = UDim2.fromScale(1, 1); LogoText2.BackgroundTransparency = 1
    LogoText2.Text = "👑"; LogoText2.Font = Enum.Font.GothamBlack
    LogoText2.TextSize = 30; LogoText2.TextColor3 = C.white; LogoText2.ZIndex = 9994

    local MT = Instance.new("TextLabel", LoaderCard)
    MT.Size = UDim2.new(1, -120, 0, 32); MT.Position = UDim2.fromOffset(108, 22)
    MT.BackgroundTransparency = 1; MT.Text = "KING HUB"
    MT.Font = Enum.Font.GothamBlack; MT.TextSize = 26
    MT.TextColor3 = C.teal; MT.TextXAlignment = Enum.TextXAlignment.Left; MT.ZIndex = 9993

    local ST = Instance.new("TextLabel", LoaderCard)
    ST.Size = UDim2.new(1, -120, 0, 18); ST.Position = UDim2.fromOffset(108, 58)
    ST.BackgroundTransparency = 1; ST.Text = "BLOX STRIKE"
    ST.Font = Enum.Font.GothamMedium; ST.TextSize = 11
    ST.TextColor3 = C.tealDim; ST.TextXAlignment = Enum.TextXAlignment.Left; ST.ZIndex = 9993

    local Div = Instance.new("Frame", LoaderCard)
    Div.Size = UDim2.new(1, -60, 0, 1); Div.Position = UDim2.fromOffset(30, 104)
    Div.BackgroundColor3 = C.border; Div.BackgroundTransparency = 0.82
    Div.BorderSizePixel = 0; Div.ZIndex = 9993

    local StepLbl = Instance.new("TextLabel", LoaderCard)
    StepLbl.Size = UDim2.new(1, -80, 0, 22); StepLbl.Position = UDim2.fromOffset(30, 118)
    StepLbl.BackgroundTransparency = 1; StepLbl.Text = "[ INITIALIZING... ]"
    StepLbl.Font = Enum.Font.Code; StepLbl.TextSize = 13
    StepLbl.TextColor3 = C.teal; StepLbl.TextXAlignment = Enum.TextXAlignment.Left; StepLbl.ZIndex = 9993

    local PctLbl = Instance.new("TextLabel", LoaderCard)
    PctLbl.Size = UDim2.fromOffset(60, 22); PctLbl.Position = UDim2.new(1, -90, 0, 118)
    PctLbl.BackgroundTransparency = 1; PctLbl.Text = "0%"
    PctLbl.Font = Enum.Font.GothamBold; PctLbl.TextSize = 13
    PctLbl.TextColor3 = C.textDim; PctLbl.TextXAlignment = Enum.TextXAlignment.Right; PctLbl.ZIndex = 9993

    local BarBg = Instance.new("Frame", LoaderCard)
    BarBg.Size = UDim2.new(1, -60, 0, 8); BarBg.Position = UDim2.fromOffset(30, 154)
    BarBg.BackgroundColor3 = Color3.fromRGB(20, 34, 32); BarBg.BorderSizePixel = 0; BarBg.ZIndex = 9993
    corner(BarBg, 4)

    local BarFill = Instance.new("Frame", BarBg)
    BarFill.Size = UDim2.fromScale(0, 1); BarFill.BackgroundColor3 = C.teal
    BarFill.BorderSizePixel = 0; BarFill.ZIndex = 9994
    corner(BarFill, 4)

    local BottomInfo = Instance.new("TextLabel", LoaderCard)
    BottomInfo.Size = UDim2.new(1, -60, 0, 18); BottomInfo.Position = UDim2.fromOffset(30, 178)
    BottomInfo.BackgroundTransparency = 1
    BottomInfo.Text = "User: " .. LocalPlayer.Name .. "  //  KING HUB"
    BottomInfo.Font = Enum.Font.Gotham; BottomInfo.TextSize = 11
    BottomInfo.TextColor3 = C.textDim; BottomInfo.TextXAlignment = Enum.TextXAlignment.Left; BottomInfo.ZIndex = 9993

    local steps = {
        { text = "[ INITIALIZING... ]",   pct = 0.20 },
        { text = "[ BUILDING GUI... ]",   pct = 0.50 },
        { text = "[ WIRING MODS... ]",    pct = 0.80 },
        { text = "[ READY, " .. string.upper(LocalPlayer.Name) .. " ]", pct = 1.00 },
    }

    for i, step in ipairs(steps) do
        StepLbl.Text = step.text
        PctLbl.Text = math.floor(step.pct * 100) .. "%"
        local dur = (i == #steps) and 0.5 or 0.4
        pcall(function()
            TweenService:Create(BarFill, TweenInfo.new(dur, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.fromScale(step.pct, 1) }):Play()
        end)
        task.wait((i == #steps) and 0.6 or 0.35)
    end

    task.wait(0.4)
    pcall(function()
        TweenService:Create(LoaderCard, ease, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(LS, ease, { Transparency = 1 }):Play()
        TweenService:Create(Div, ease, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(BarBg, ease, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(BarFill, ease, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(StepLbl, ease, { TextTransparency = 1 }):Play()
        TweenService:Create(PctLbl, ease, { TextTransparency = 1 }):Play()
        TweenService:Create(MT, ease, { TextTransparency = 1 }):Play()
        TweenService:Create(ST, ease, { TextTransparency = 1 }):Play()
        TweenService:Create(LogoText2, ease, { TextTransparency = 1 }):Play()
        TweenService:Create(LogoBg, ease, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(BottomInfo, ease, { TextTransparency = 1 }):Play()
    end)
    task.wait(0.7)
    pcall(function() if LoaderCard and LoaderCard.Parent then LoaderCard:Destroy() end end)

    if panel and not panel.Visible then
        panel.Visible = true
        TweenService:Create(panel, ease, { Position = originalPos }):Play()
    end
end)

Notify("KING HUB · Blox Strike loaded", 4, C.green)
print("[KING HUB] Blox Strike loaded.")