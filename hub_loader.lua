-- =============================================================================
--  KING HUB  ·  pick a game, the matching script loads.
--  Run:  loadstring(game:HttpGet("https://raw.githubusercontent.com/jamalmusialla81-hub/King-loader/main/hub_loader.lua"))()
--  K hides / shows the menu. The game you are in is detected and marked, but you can load any card.
--  Everything loads over game:HttpGet from GitHub; no workspace files are used.
--  MY SCRIPTS lists the entries in EXTRA_SCRIPTS below (name + raw URL) plus MonkeHub.
-- =============================================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui          = game:GetService("CoreGui")
local HttpService      = game:GetService("HttpService")
local RS               = game:GetService("ReplicatedStorage")

-- set getgenv().KING_BRANCH = "<branch>" before running to load every script from a test branch instead of main
local BRANCH = (getgenv and getgenv().KING_BRANCH) or "main"
local BASE = "https://raw.githubusercontent.com/jamalmusialla81-hub/King-loader/" .. BRANCH .. "/"

local GuiParent = CoreGui
pcall(function() if gethui then GuiParent = gethui() end end)

if getgenv and getgenv().GAMEHUB_CLOSE then pcall(getgenv().GAMEHUB_CLOSE) end

local GAMES = {
    {
        name = "BLOX STRIKE", icon = "🎯", tag = "Counter-Strike style",
        url = BASE .. "blox_strike.lua",
        features = {"ESP, boxes, chams", "Triggerbot, no flash", "Live grenade lineups", "Skins, bomb timer"},
        detect = function()
            return game.PlaceId == 114234929420007
                or (RS:FindFirstChild("Assets") ~= nil and RS.Assets:FindFirstChild("Skins") ~= nil and RS:FindFirstChild("NetworkRemotes") ~= nil)
        end,
    },
    {
        name = "PHANTOM FORCES", icon = "🔫", tag = "Military shooter",
        url = BASE .. "phantom_forces.lua",
        features = {"Box ESP, head dots", "Triggerbot", "Mouse lock-on", "Handles random names"},
        detect = function()
            return game.PlaceId == 292439477
                or (RS:FindFirstChild("ReadyEvent") ~= nil and RS:FindFirstChild("PlayerDataEvent") ~= nil)
        end,
    },
    {
        name = "OPERATION ONE", icon = "🛡", tag = "Tactical shooter",
        url = BASE .. "operation_one.lua",
        features = {"ESP, chams", "Triggerbot, silent aim", "No recoil, grenade aim", "Shoots through cover"},
        detect = function()
            return workspace:FindFirstChild("Viewmodels") ~= nil
                or (RS:FindFirstChild("Modules") ~= nil and RS.Modules:FindFirstChild("Items") ~= nil)
        end,
    },
    {
        name = "SOCCER", icon = "⚽", tag = "Illegal Soccer",
        url = BASE .. "soccer.lua",
        features = {"Auto dodge, auto tackle", "Auto keeper dives", "Silent corner aim", "Flick to bicycle kick"},
        detect = function()
            return game.PlaceId == 126987974021910
                or (RS:FindFirstChild("Modules") ~= nil and RS.Modules:FindFirstChild("Ball") ~= nil and RS.Modules:FindFirstChild("Actions") ~= nil)
        end,
    },
    {
        name = "HUSS VALLEY", icon = "🐔", tag = "Runners vs catchers",
        url = BASE .. "huss_valley.lua",
        features = {"Role ESP through walls", "Catcher tackle timers", "Catcher warning + arrow", "Display only"},
        detect = function()
            return game.PlaceId == 107535308163741 or RS:FindFirstChild("ChickenOrHero") ~= nil
        end,
    },
    {
        name = "MY SCRIPTS", icon = "📁", tag = "Your own scripts", library = true,
        features = {"MonkeHub, one click", "Extra scripts by URL", "Click an entry to run it", "Add your own below"},
        detect = function() return false end,
    },
}

-- other hubs launched as they are (they keep their own name and menu)
local EXTERNAL = {
    {name = "MonkeHub", note = "opens it and captures the scripts it loads", url = BASE .. "capture_monkehub.lua"},
}

-- add your own scripts here as {name = "...", url = "https://raw.githubusercontent.com/..."}
local EXTRA_SCRIPTS = {
}

local C = {
    bg = Color3.fromRGB(7, 12, 16), panel = Color3.fromRGB(11, 20, 26), dark = Color3.fromRGB(5, 10, 13),
    teal = Color3.fromRGB(0, 200, 175), tealBright = Color3.fromRGB(70, 255, 225), tealDim = Color3.fromRGB(0, 110, 100),
    gold = Color3.fromRGB(255, 205, 90), violet = Color3.fromRGB(140, 90, 255), blue = Color3.fromRGB(60, 140, 255),
    text = Color3.fromRGB(190, 220, 215), dim = Color3.fromRGB(95, 135, 130), white = Color3.fromRGB(255, 255, 255),
    green = Color3.fromRGB(90, 220, 130), red = Color3.fromRGB(235, 90, 90),
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
local function gradient(p, a, b, rot)
    local g = Instance.new("UIGradient", p)
    g.Color = ColorSequence.new(a, b)
    g.Rotation = rot or 0
    return g
end

local gui = Instance.new("ScreenGui")
gui.Name = HttpService:GenerateGUID(false)
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.Parent = GuiParent

local conns = {}
local function connect(sig, fn) local c = sig:Connect(fn); conns[#conns + 1] = c; return c end
local alive = true
local function closeHub()
    alive = false
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    pcall(function() gui:Destroy() end)
    if getgenv then getgenv().GAMEHUB_CLOSE = nil end
end
if getgenv then getgenv().GAMEHUB_CLOSE = closeHub end

-- ============================================================ animated backdrop
local backdrop = Instance.new("Frame", gui)
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.new(1, 1, 1)
backdrop.BackgroundTransparency = 1
backdrop.BorderSizePixel = 0
backdrop.ClipsDescendants = true
local bgGrad = Instance.new("UIGradient", backdrop)
bgGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 10, 16)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(16, 8, 34)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(2, 22, 24)),
})
tw(backdrop, 0.7, {BackgroundTransparency = 0.18})

local particles = {}
local rng = Random.new()
for i = 1, 46 do
    local size = rng:NextInteger(2, 7)
    local f = Instance.new("Frame", backdrop)
    f.Size = UDim2.fromOffset(size, size)
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.BackgroundColor3 = ({C.teal, C.violet, C.blue, C.tealBright})[rng:NextInteger(1, 4)]
    f.BackgroundTransparency = 0.35 + rng:NextNumber() * 0.5
    f.BorderSizePixel = 0
    corner(f, 4)
    particles[i] = {
        f = f, x = rng:NextNumber(), y = rng:NextNumber(), speed = 0.015 + rng:NextNumber() * 0.05,
        phase = rng:NextNumber() * 6.28, depth = 0.3 + rng:NextNumber() * 0.9,
    }
end

-- ============================================================ main panel
local panel = Instance.new("CanvasGroup", gui)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, -60)
panel.Size = UDim2.fromOffset(960, 452)
panel.BackgroundColor3 = C.bg
panel.BackgroundTransparency = 0.04
panel.BorderSizePixel = 0
panel.GroupTransparency = 1
corner(panel, 16)
local pStroke = stroke(panel, C.teal, 2.2, 0.1)
local pGrad = Instance.new("UIGradient", pStroke)
pGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, C.teal), ColorSequenceKeypoint.new(0.33, C.violet),
    ColorSequenceKeypoint.new(0.66, C.blue), ColorSequenceKeypoint.new(1, C.teal),
})
local panelFill = Instance.new("UIGradient", panel)
panelFill.Color = ColorSequence.new(Color3.fromRGB(14, 28, 34), Color3.fromRGB(8, 12, 22))
panelFill.Rotation = 90
local pScale = Instance.new("UIScale", panel)
pScale.Scale = 0.7
tw(panel, 0.55, {GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5)}, Enum.EasingStyle.Back)
tw(pScale, 0.65, {Scale = 1}, Enum.EasingStyle.Back)

-- crown with a glow ring behind it
local ring = Instance.new("Frame", panel)
ring.Size = UDim2.fromOffset(58, 58)
ring.Position = UDim2.fromOffset(26, 16)
ring.BackgroundTransparency = 1
corner(ring, 29)
local ringStroke = stroke(ring, C.gold, 2.5, 0.2)
local ringGrad = Instance.new("UIGradient", ringStroke)
ringGrad.Color = ColorSequence.new(C.gold, C.tealBright)
local crown = Instance.new("TextLabel", ring)
crown.Size = UDim2.fromScale(1, 1)
crown.BackgroundTransparency = 1
crown.Text = "👑"
crown.TextSize = 30
crown.Font = Enum.Font.GothamBold

-- title letters reveal, then a shimmer sweeps across
local titleHolder = Instance.new("Frame", panel)
titleHolder.Size = UDim2.fromOffset(300, 40)
titleHolder.Position = UDim2.fromOffset(98, 14)
titleHolder.BackgroundTransparency = 1
local letters = {}
do
    local word = "KING HUB"
    local x = 0
    for i = 1, #word do
        local ch = word:sub(i, i)
        local l = Instance.new("TextLabel", titleHolder)
        l.Size = UDim2.fromOffset(ch == " " and 12 or 26, 40)
        l.Position = UDim2.fromOffset(x, 18)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.GothamBlack
        l.TextSize = 32
        l.Text = ch
        l.TextColor3 = C.white
        l.TextTransparency = 1
        letters[#letters + 1] = {l = l, x = x}
        x += (ch == " " and 12 or 27)
    end
end
task.spawn(function()
    task.wait(0.3)
    for _, e in ipairs(letters) do
        if not alive then return end
        tw(e.l, 0.35, {TextTransparency = 0, Position = UDim2.fromOffset(e.x, 0)}, Enum.EasingStyle.Back)
        task.wait(0.06)
    end
end)
local subtitle = Instance.new("TextLabel", panel)
subtitle.Size = UDim2.fromOffset(400, 16)
subtitle.Position = UDim2.fromOffset(100, 58)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.GothamMedium
subtitle.TextSize = 12
subtitle.TextColor3 = C.dim
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextTransparency = 1
subtitle.Text = "choose your game  ·  K hides the menu"
task.delay(0.9, function() if alive then tw(subtitle, 0.5, {TextTransparency = 0}) end end)

local closeBtn = Instance.new("TextButton", panel)
closeBtn.Size = UDim2.fromOffset(34, 34)
closeBtn.Position = UDim2.new(1, -50, 0, 18)
closeBtn.BackgroundColor3 = C.dark
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = C.text
closeBtn.AutoButtonColor = false
corner(closeBtn, 9)
closeBtn.MouseEnter:Connect(function() tw(closeBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(130, 30, 30)}, Enum.EasingStyle.Back) end)
closeBtn.MouseLeave:Connect(function() tw(closeBtn, 0.12, {BackgroundColor3 = C.dark}) end)

-- terminal strip (status, errors, loading text) and progress bar
local termBg = Instance.new("Frame", panel)
termBg.Size = UDim2.new(1, -52, 0, 46)
termBg.Position = UDim2.new(0, 26, 1, -66)
termBg.BackgroundColor3 = C.dark
termBg.BackgroundTransparency = 0.2
termBg.BorderSizePixel = 0
corner(termBg, 10)
stroke(termBg, C.tealDim, 1, 0.7)
local term = Instance.new("TextLabel", termBg)
term.Size = UDim2.new(1, -20, 0, 20)
term.Position = UDim2.fromOffset(10, 5)
term.BackgroundTransparency = 1
term.Font = Enum.Font.Code
term.TextSize = 12
term.TextColor3 = C.dim
term.TextXAlignment = Enum.TextXAlignment.Left
term.Text = ""
local barBg = Instance.new("Frame", termBg)
barBg.Size = UDim2.new(1, -20, 0, 5)
barBg.Position = UDim2.new(0, 10, 1, -12)
barBg.BackgroundColor3 = Color3.fromRGB(20, 40, 44)
barBg.BorderSizePixel = 0
corner(barBg, 3)
local bar = Instance.new("Frame", barBg)
bar.Size = UDim2.fromScale(0, 1)
bar.BackgroundColor3 = C.teal
bar.BorderSizePixel = 0
corner(bar, 3)
local barGrad = gradient(bar, C.teal, C.violet)

local typing = 0
local function say(text, color)
    typing += 1
    local my = typing
    term.TextColor3 = color or C.text
    task.spawn(function()
        for i = 1, #text do
            if my ~= typing or not alive then return end
            term.Text = "> " .. text:sub(1, i) .. (i < #text and "▌" or "")
            task.wait(0.012)
        end
    end)
end

-- ============================================================ launching
local loading = false
local function flash()
    local f = Instance.new("Frame", gui)
    f.Size = UDim2.fromScale(1, 1)
    f.BackgroundColor3 = C.white
    f.BackgroundTransparency = 0.55
    f.BorderSizePixel = 0
    f.ZIndex = 50
    tw(f, 0.5, {BackgroundTransparency = 1})
    task.delay(0.55, function() pcall(function() f:Destroy() end) end)
end
local function runFile(label, url)
    if loading then return end
    loading = true
    say("downloading " .. url, C.teal)
    tw(bar, 0.8, {Size = UDim2.fromScale(0.55, 1)}, Enum.EasingStyle.Quart)
    local okRead, src
    okRead, src = pcall(function() return game:HttpGet(url) end)
    task.wait(0.45)
    if not okRead or type(src) ~= "string" or #src == 0 then
        say("download failed: " .. url, C.red)
        tw(bar, 0.2, {Size = UDim2.fromScale(0, 1)})
        loading = false
        return
    end
    say("compiling " .. label .. "...", C.teal)
    local fn, err = loadstring(src)
    task.wait(0.3)
    if not fn then
        say("compile error: " .. tostring(err):sub(1, 70), C.red)
        tw(bar, 0.2, {Size = UDim2.fromScale(0, 1)})
        loading = false
        return
    end
    tw(bar, 0.35, {Size = UDim2.fromScale(1, 1)})
    say("launching " .. label .. "  ·  good luck", C.green)
    task.wait(0.55)
    flash()
    tw(panel, 0.4, {GroupTransparency = 1}, Enum.EasingStyle.Quad)
    tw(pScale, 0.4, {Scale = 1.18}, Enum.EasingStyle.Quad)
    tw(backdrop, 0.45, {BackgroundTransparency = 1})
    task.wait(0.5)
    closeHub()
    local okRun, runErr = pcall(fn)
    if not okRun then warn("[king hub] " .. label .. " errored: " .. tostring(runErr)) end
end

-- ============================================================ my scripts page
local cardsHolder = Instance.new("Frame", panel)
cardsHolder.Size = UDim2.new(1, 0, 0, 280)
cardsHolder.Position = UDim2.fromOffset(0, 92)
cardsHolder.BackgroundTransparency = 1

local libPage = Instance.new("CanvasGroup", panel)
libPage.Size = UDim2.new(1, -52, 0, 262)
libPage.Position = UDim2.fromOffset(26, 96)
libPage.BackgroundTransparency = 1
libPage.GroupTransparency = 1
libPage.Visible = false
local libTitle = Instance.new("TextLabel", libPage)
libTitle.Size = UDim2.new(1, -120, 0, 26)
libTitle.BackgroundTransparency = 1
libTitle.Font = Enum.Font.GothamBold
libTitle.TextSize = 18
libTitle.TextColor3 = C.white
libTitle.TextXAlignment = Enum.TextXAlignment.Left
libTitle.Text = "📁  MY SCRIPTS"
local backBtn = Instance.new("TextButton", libPage)
backBtn.Size = UDim2.fromOffset(100, 28)
backBtn.Position = UDim2.new(1, -100, 0, 0)
backBtn.BackgroundColor3 = C.panel
backBtn.Text = "← BACK"
backBtn.Font = Enum.Font.GothamBold
backBtn.TextSize = 12
backBtn.TextColor3 = C.text
backBtn.AutoButtonColor = false
corner(backBtn, 8)
stroke(backBtn, C.tealDim, 1, 0.5)
local libList = Instance.new("ScrollingFrame", libPage)
libList.Size = UDim2.new(1, 0, 1, -40)
libList.Position = UDim2.fromOffset(0, 38)
libList.BackgroundTransparency = 1
libList.BorderSizePixel = 0
libList.ScrollBarThickness = 4
libList.ScrollBarImageColor3 = C.teal
libList.CanvasSize = UDim2.new()
libList.AutomaticCanvasSize = Enum.AutomaticSize.Y
local libLay = Instance.new("UIListLayout", libList)
libLay.Padding = UDim.new(0, 6)

local function showLibrary(show)
    if show then
        for _, c in ipairs(libList:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
        end
        local files = EXTRA_SCRIPTS
        for i, ex in ipairs(EXTERNAL) do
            local b = Instance.new("TextButton", libList)
            b.LayoutOrder = -100 + i
            b.Size = UDim2.new(1, -8, 0, 46)
            b.BackgroundColor3 = Color3.fromRGB(26, 22, 12)
            b.BackgroundTransparency = 1
            b.Text = "   ★  " .. ex.name .. "   ·  " .. ex.note
            b.TextXAlignment = Enum.TextXAlignment.Left
            b.Font = Enum.Font.GothamBold
            b.TextSize = 13
            b.TextColor3 = C.gold
            b.AutoButtonColor = false
            corner(b, 9)
            local bs = stroke(b, C.gold, 1.4, 0.3)
            b.MouseEnter:Connect(function() tw(b, 0.12, {BackgroundColor3 = Color3.fromRGB(44, 36, 14)}); tw(bs, 0.12, {Thickness = 2.2, Transparency = 0}) end)
            b.MouseLeave:Connect(function() tw(b, 0.12, {BackgroundColor3 = Color3.fromRGB(26, 22, 12)}); tw(bs, 0.12, {Thickness = 1.4, Transparency = 0.3}) end)
            b.MouseButton1Click:Connect(function() runFile(ex.name, ex.url) end)
            task.delay(0.05 * i, function() if alive then tw(b, 0.3, {BackgroundTransparency = 0}, Enum.EasingStyle.Back) end end)
        end
        if #files == 0 then
            local l = Instance.new("TextLabel", libList)
            l.Size = UDim2.new(1, 0, 0, 60)
            l.BackgroundTransparency = 1
            l.Font = Enum.Font.GothamMedium
            l.TextSize = 13
            l.TextColor3 = C.dim
            l.TextWrapped = true
            l.Text = "No extra scripts yet.\nAdd {name, url} entries to EXTRA_SCRIPTS at the top of hub_loader.lua."
        end
        for i, f in ipairs(files) do
            local name = f.name
            local b = Instance.new("TextButton", libList)
            b.Size = UDim2.new(1, -8, 0, 40)
            b.BackgroundColor3 = C.panel
            b.BackgroundTransparency = 1
            b.Text = "   ▶  " .. name
            b.TextXAlignment = Enum.TextXAlignment.Left
            b.Font = Enum.Font.GothamMedium
            b.TextSize = 13
            b.TextColor3 = C.text
            b.AutoButtonColor = false
            corner(b, 9)
            local bs = stroke(b, C.tealDim, 1, 0.6)
            b.MouseEnter:Connect(function() tw(b, 0.12, {BackgroundColor3 = Color3.fromRGB(18, 40, 46)}); tw(bs, 0.12, {Color = C.tealBright, Transparency = 0.1}) end)
            b.MouseLeave:Connect(function() tw(b, 0.12, {BackgroundColor3 = C.panel}); tw(bs, 0.12, {Color = C.tealDim, Transparency = 0.6}) end)
            b.MouseButton1Click:Connect(function() runFile(name, f.url) end)
            task.delay(0.05 * i, function() if alive then tw(b, 0.3, {BackgroundTransparency = 0}, Enum.EasingStyle.Back) end end)
        end
        libPage.Visible = true
        libPage.Position = UDim2.fromOffset(60, 96)
        tw(libPage, 0.35, {GroupTransparency = 0, Position = UDim2.fromOffset(26, 96)}, Enum.EasingStyle.Back)
        tw(cardsHolder, 0.25, {Position = UDim2.fromOffset(-60, 92)})
        for _, ch in ipairs(cardsHolder:GetChildren()) do
            if ch:IsA("CanvasGroup") then tw(ch, 0.25, {GroupTransparency = 1}) end
        end
        say("my scripts: " .. #files .. " extra + " .. #EXTERNAL .. " external hub", C.teal)
    else
        tw(libPage, 0.25, {GroupTransparency = 1})
        task.delay(0.26, function() libPage.Visible = false end)
        tw(cardsHolder, 0.35, {Position = UDim2.fromOffset(0, 92)}, Enum.EasingStyle.Back)
        for _, ch in ipairs(cardsHolder:GetChildren()) do
            if ch:IsA("CanvasGroup") then tw(ch, 0.3, {GroupTransparency = 0}) end
        end
        say("choose a game", C.dim)
    end
end
backBtn.MouseButton1Click:Connect(function() showLibrary(false) end)
backBtn.MouseEnter:Connect(function() tw(backBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(18, 40, 46)}) end)
backBtn.MouseLeave:Connect(function() tw(backBtn, 0.12, {BackgroundColor3 = C.panel}) end)

-- ============================================================ game cards
local detectedIndex
for i, g in ipairs(GAMES) do
    local ok, res = pcall(g.detect)
    g.detected = ok and res and true or false
    if g.detected and not detectedIndex then detectedIndex = i end
end

local CARD_W, CARD_H, GAP = 172, 258, 12
local cards = {}
local function makeCard(g, index)
    local baseX = 26 + (index - 1) * (CARD_W + GAP)
    local baseY = 0
    local card = Instance.new("CanvasGroup", cardsHolder)
    card.Size = UDim2.fromOffset(CARD_W, CARD_H)
    card.AnchorPoint = Vector2.new(0.5, 0)
    card.Position = UDim2.fromOffset(baseX + CARD_W / 2, baseY + 50)
    card.BackgroundColor3 = C.panel
    card.BorderSizePixel = 0
    card.GroupTransparency = 1
    card.Rotation = -7
    corner(card, 14)
    gradient(card, Color3.fromRGB(16, 34, 40), Color3.fromRGB(9, 14, 24), 90)
    local cs = stroke(card, g.detected and C.tealBright or C.tealDim, g.detected and 2.2 or 1.2, g.detected and 0.1 or 0.55)
    local csGrad = Instance.new("UIGradient", cs)
    csGrad.Color = ColorSequence.new(g.detected and C.tealBright or C.tealDim, g.detected and C.violet or C.blue)

    local iconBg = Instance.new("Frame", card)
    iconBg.Size = UDim2.fromOffset(46, 46)
    iconBg.Position = UDim2.fromOffset(14, 14)
    iconBg.BackgroundColor3 = g.detected and C.teal or Color3.fromRGB(18, 40, 44)
    iconBg.BackgroundTransparency = g.detected and 0.55 or 0.3
    iconBg.BorderSizePixel = 0
    corner(iconBg, 12)
    local icon = Instance.new("TextLabel", iconBg)
    icon.Size = UDim2.fromScale(1, 1)
    icon.BackgroundTransparency = 1
    icon.Text = g.icon
    icon.TextSize = 24
    icon.Font = Enum.Font.GothamBold

    local name = Instance.new("TextLabel", card)
    name.Size = UDim2.new(1, -20, 0, 20)
    name.Position = UDim2.fromOffset(14, 68)
    name.BackgroundTransparency = 1
    name.Font = Enum.Font.GothamBlack
    name.TextSize = 15
    name.TextColor3 = C.white
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.TextTruncate = Enum.TextTruncate.AtEnd
    name.Text = g.name
    local tag = Instance.new("TextLabel", card)
    tag.Size = UDim2.new(1, -20, 0, 14)
    tag.Position = UDim2.fromOffset(14, 89)
    tag.BackgroundTransparency = 1
    tag.Font = Enum.Font.Gotham
    tag.TextSize = 11
    tag.TextColor3 = C.dim
    tag.TextXAlignment = Enum.TextXAlignment.Left
    tag.Text = g.tag

    local pill
    if not g.library then
        pill = Instance.new("TextLabel", card)
        pill.Size = UDim2.fromOffset(g.detected and 84 or 76, 18)
        pill.Position = UDim2.fromOffset(14, 110)
        pill.BackgroundColor3 = g.detected and C.green or C.dark
        pill.BackgroundTransparency = g.detected and 0.1 or 0.3
        pill.Font = Enum.Font.GothamBold
        pill.TextSize = 9
        pill.TextColor3 = g.detected and C.white or C.dim
        pill.Text = g.detected and "● DETECTED" or "OTHER GAME"
        corner(pill, 9)
    end

    for k, line in ipairs(g.features) do
        local f = Instance.new("TextLabel", card)
        f.Size = UDim2.new(1, -26, 0, 15)
        f.Position = UDim2.fromOffset(14, 136 + (k - 1) * 17)
        f.BackgroundTransparency = 1
        f.Font = Enum.Font.GothamMedium
        f.TextSize = 11
        f.TextColor3 = C.text
        f.TextXAlignment = Enum.TextXAlignment.Left
        f.TextTruncate = Enum.TextTruncate.AtEnd
        f.Text = "›  " .. line
    end

    local btn = Instance.new("TextButton", card)
    btn.Size = UDim2.new(1, -28, 0, 34)
    btn.Position = UDim2.new(0, 14, 1, -48)
    btn.BackgroundColor3 = g.detected and C.teal or Color3.fromRGB(18, 42, 46)
    btn.Font = Enum.Font.GothamBlack
    btn.TextSize = 13
    btn.TextColor3 = C.white
    btn.Text = g.library and "OPEN" or "LOAD"
    btn.AutoButtonColor = false
    corner(btn, 10)

    local entry = {card = card, hover = false, rot = 0, cs = cs, csGrad = csGrad, pill = pill, detected = g.detected, w = CARD_W}
    cards[#cards + 1] = entry

    local function hoverOn()
        if loading then return end
        entry.hover = true
        tw(card, 0.18, {Position = UDim2.fromOffset(baseX + CARD_W / 2, baseY - 8)}, Enum.EasingStyle.Back)
        tw(cs, 0.18, {Thickness = 3, Transparency = 0})
        tw(btn, 0.18, {BackgroundColor3 = C.tealBright})
    end
    local function hoverOff()
        entry.hover = false
        tw(card, 0.2, {Position = UDim2.fromOffset(baseX + CARD_W / 2, baseY)}, Enum.EasingStyle.Back)
        tw(cs, 0.2, {Thickness = g.detected and 2.2 or 1.2, Transparency = g.detected and 0.1 or 0.55})
        tw(btn, 0.2, {BackgroundColor3 = g.detected and C.teal or Color3.fromRGB(18, 42, 46)})
    end
    card.MouseEnter:Connect(hoverOn)
    card.MouseLeave:Connect(hoverOff)

    local function ripple()
        local m = UserInputService:GetMouseLocation()
        local abs = card.AbsolutePosition
        local r = Instance.new("Frame", card)
        r.AnchorPoint = Vector2.new(0.5, 0.5)
        r.Position = UDim2.fromOffset(m.X - abs.X, m.Y - abs.Y)
        r.Size = UDim2.fromOffset(6, 6)
        r.BackgroundColor3 = C.white
        r.BackgroundTransparency = 0.6
        r.BorderSizePixel = 0
        r.ZIndex = 20
        corner(r, 200)
        tw(r, 0.6, {Size = UDim2.fromOffset(400, 400), BackgroundTransparency = 1}, Enum.EasingStyle.Quad)
        task.delay(0.65, function() pcall(function() r:Destroy() end) end)
    end
    local function activate()
        ripple()
        tw(card, 0.08, {Size = UDim2.fromOffset(CARD_W - 8, CARD_H - 10)})
        task.delay(0.1, function() if alive then tw(card, 0.2, {Size = UDim2.fromOffset(CARD_W, CARD_H)}, Enum.EasingStyle.Back) end end)
        if g.library then showLibrary(true) else runFile(g.name, g.url) end
    end
    btn.MouseButton1Click:Connect(activate)

    task.delay(0.55 + (index - 1) * 0.13, function()
        if not alive then return end
        tw(card, 0.55, {GroupTransparency = 0, Position = UDim2.fromOffset(baseX + CARD_W / 2, baseY), Rotation = 0}, Enum.EasingStyle.Back)
    end)
end
for i, g in ipairs(GAMES) do makeCard(g, i) end

-- ============================================================ continuous animation
local t = 0
connect(RunService.RenderStepped, function(dt)
    if not alive then return end
    t += dt
    local mouse = UserInputService:GetMouseLocation()
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
    local mx, my = (mouse.X / vp.X - 0.5), (mouse.Y / vp.Y - 0.5)

    pGrad.Rotation = (t * 55) % 360
    bgGrad.Rotation = (t * 6) % 360
    ringGrad.Rotation = (t * -120) % 360
    ring.Rotation = (t * 30) % 360
    crown.Rotation = -ring.Rotation + math.sin(t * 2) * 6
    ring.Position = UDim2.fromOffset(26, 16 + math.sin(t * 2.2) * 2)
    barGrad.Offset = Vector2.new(math.sin(t * 3) * 0.4, 0)

    for i, e in ipairs(letters) do
        local wave = (math.sin(t * 2.4 - i * 0.55) + 1) / 2
        e.l.TextColor3 = C.white:Lerp(C.tealBright, wave * 0.85)
    end

    for _, p in ipairs(particles) do
        p.y -= p.speed * dt
        if p.y < -0.05 then p.y = 1.05; p.x = rng:NextNumber() end
        local sway = math.sin(t * 0.6 + p.phase) * 0.012
        p.f.Position = UDim2.fromScale(p.x + sway - mx * 0.03 * p.depth, p.y - my * 0.03 * p.depth)
        p.f.BackgroundTransparency = 0.3 + (math.sin(t * 1.3 + p.phase) + 1) * 0.28
    end

    for _, e in ipairs(cards) do
        local target = 0
        if e.hover then
            local center = e.card.AbsolutePosition.X + e.card.AbsoluteSize.X / 2
            target = math.clamp((mouse.X - center) / (e.w / 2), -1, 1) * 3.2
        end
        e.rot += (target - e.rot) * math.min(1, dt * 12)
        if e.hover or math.abs(e.rot) > 0.05 then e.card.Rotation = e.rot end
        e.csGrad.Rotation = (t * 80) % 360
        if e.detected and not e.hover then e.cs.Transparency = 0.08 + (math.sin(t * 3) + 1) * 0.09 end
        if e.pill and e.detected then e.pill.BackgroundTransparency = 0.05 + (math.sin(t * 4) + 1) * 0.12 end
    end
end)

-- first message and shortcuts
task.delay(1.1, function()
    if not alive or loading then return end
    if detectedIndex then say("detected: " .. GAMES[detectedIndex].name .. "  ·  press LOAD", C.green)
    else say("no supported game detected here  ·  you can still pick one", C.dim) end
end)

local shown = true
local function setShown(v)
    shown = v
    if v then
        panel.Visible = true
        tw(panel, 0.3, {GroupTransparency = 0}, Enum.EasingStyle.Quad)
        tw(pScale, 0.35, {Scale = 1}, Enum.EasingStyle.Back)
        tw(backdrop, 0.3, {BackgroundTransparency = 0.18})
    else
        tw(panel, 0.2, {GroupTransparency = 1})
        tw(pScale, 0.2, {Scale = 0.92})
        tw(backdrop, 0.2, {BackgroundTransparency = 1})
        task.delay(0.22, function() if not shown then panel.Visible = false end end)
    end
end
connect(UserInputService.InputBegan, function(i, gp)
    if not gp and i.KeyCode == Enum.KeyCode.K and not loading then setShown(not shown) end
end)
closeBtn.MouseButton1Click:Connect(function()
    tw(panel, 0.25, {GroupTransparency = 1})
    tw(pScale, 0.25, {Scale = 0.85})
    tw(backdrop, 0.3, {BackgroundTransparency = 1})
    task.delay(0.32, closeHub)
end)
