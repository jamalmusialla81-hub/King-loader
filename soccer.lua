-- KING HUB: Soccer helper (place 126987974021910)
-- Auto dodge, auto keeper, top-corner shot aim, experimental stamina. Press K to hide the panel.
-- Everything goes through your own keys (VirtualInputManager); no remotes are fired.
-- Decisions are written to king_hub/soccer_log.txt so they can be tuned.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local lp = Players.LocalPlayer
local genv = getgenv and getgenv() or _G
if genv.KING_SOCCER_CLOSE then pcall(genv.KING_SOCCER_CLOSE) end

-- only one KING script runs at a time: loading this one unloads any other that is active
do
    local g = getgenv and getgenv() or _G
    g.KING_UNLOADERS = g.KING_UNLOADERS or {}
    for k, fn in pairs(g.KING_UNLOADERS) do
        if k ~= "soccer" then pcall(fn) end
        g.KING_UNLOADERS[k] = nil
    end
end

local LOG = "king_hub/soccer_log.txt"
pcall(function() if not isfolder("king_hub") then makefolder("king_hub") end end)
pcall(writefile, LOG, "")
local function log(s) pcall(appendfile, LOG, string.format("%.2f %s\n", os.clock(), s)) end

local CFG = {
    dodge = true, dodgeBallOnly = true, dodgeRange = 18,
    keeper = true, position = true, jumpDive = true,
    aim = true, aimStrength = 1, cornerInset = 3.5, cornerY = 6.5, aimRange = 115,
    stamina = false,
    bike = true, bikeDelay = 0.28, bikeFallback = 0.9,
    tackle = true, tackleKick = true, tackleRange = 9, kickRange = 5,
    curve = true,
    ballGravity = 100, -- measured from the log: the ball falls at roughly half of workspace gravity
}

local function req(path)
    local i = RS:FindFirstChild("Modules")
    for p in path:gmatch("[^%.]+") do i = i and i:FindFirstChild(p) end
    if not i then return nil end
    local ok, r = pcall(require, i)
    return ok and r or nil
end

local KB = req("Gameplay.Keybinds")
local GKPos = req("Gameplay.GoalkeeperPositioning")
local Sprint, HitStamina = req("Actions.Sprint"), req("Actions.BallHitStamina")
local HW = (GKPos and GKPos.Constants and GKPos.Constants.GoalHalfWidth) or 21

local function keyFor(action)
    if not KB then return nil end
    local ok, kc = pcall(KB.GetKeyboardKeyCode, action)
    if ok and typeof(kc) == "EnumItem" then return kc end
    return nil
end
local function key(kc, down)
    if kc then pcall(function() VIM:SendKeyEvent(down, kc, false, game) end) end
end
local function tap(kc, hold)
    key(kc, true)
    task.delay(hold or 0.06, function() key(kc, false) end)
end

-- the game has its own AutoCurve action; use it when it is bound, otherwise the normal Curve key
local function curveKeyCode() return keyFor("AutoCurve") or keyFor("Curve") end

local conns = {}
local function pos(model) return model:GetPivot().Position end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

local function goals()
    local t = {}
    local ok = pcall(function()
        for _, g in ipairs(workspace.Map.Theme.Goals:GetChildren()) do t[#t + 1] = pos(g) end
    end)
    return t
end

local lastWhy, diveAt, diagUntil = 0, 0, 0 -- shared by dodge, dive, tackle and bike diagnostics

-- ===== auto dodge =====
local lastDodge, lastSlideLog = 0, 0
-- The match ball is workspace.Misc.Visuals.ClientBall_MainMatch. Elsewhere (practice range) there can be many balls,
-- so every ball-like part is tracked and the right one is chosen per job (nearest for you, most dangerous for the keeper).
local ballList, lastBallSearch = {}, 0
local function allBalls()
    local ok, b = pcall(function() return workspace.Misc.Visuals:FindFirstChild("ClientBall_MainMatch") end)
    if ok and b then ballList = {b} return ballList end
    if os.clock() - lastBallSearch > 1.5 then
        lastBallSearch = os.clock()
        local list = {}
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("BasePart") and d.Name:lower():find("ball", 1, true) and not d:FindFirstAncestorWhichIsA("Humanoid")
                and not (lp.Character and d:IsDescendantOf(lp.Character)) and not d:IsDescendantOf(workspace.CurrentCamera) then
                list[#list + 1] = d
                if #list >= 40 then break end
            end
        end
        if #list ~= #ballList then log("balls found: " .. #list) end
        ballList = list
    end
    local alive = {}
    for _, d in ipairs(ballList) do if d.Parent then alive[#alive + 1] = d end end
    ballList = alive
    return ballList
end
local nearBall, nearT = nil, 0
local function mainBall()
    local now = os.clock()
    if nearBall and nearBall.Parent and now - nearT < 0.2 then return nearBall end
    nearT = now
    local me = lp.Character
    local mp = me and pos(me)
    local best, bd
    for _, d in ipairs(allBalls()) do
        local dist = mp and (d.Position - mp).Magnitude or 0
        if not bd or dist < bd then best, bd = d, dist end
    end
    nearBall = best
    return best
end
pcall(function()
    local ev = RS.Remotes.Characters.ActionState
    conns[#conns + 1] = ev.OnClientEvent:Connect(function(kind, data)
        if kind ~= "SlidingUntil" or not CFG.dodge or type(data) ~= "table" then return end
        local e = data[1]
        if type(e) ~= "table" or not e.Value or not e.Character then return end
        local me = lp.Character
        if not me or e.Character == me then return end
        local now = os.clock()
        local function why(msg)
            if now - lastSlideLog > 0.5 then
                lastSlideLog = now
                log("slide seen, no dodge: " .. msg)
            end
        end
        if now - lastDodge < 3 then return why("dodge on cooldown") end
        local plr = Players:GetPlayerFromCharacter(e.Character)
        if plr and plr.Team and lp.Team and plr.Team == lp.Team then return why("teammate") end
        local d = pos(e.Character) - pos(me)
        if d.Magnitude > CFG.dodgeRange or d.Magnitude < 0.1 then return why(string.format("distance %.1f", d.Magnitude)) end
        if CFG.dodgeBallOnly then
            local b = mainBall()
            if not b or (b.Position - pos(me)).Magnitude > 7 then return why("you don't have the ball") end
        end
        if e.Character:GetPivot().LookVector:Dot(-d.Unit) < -0.3 then return why("slider facing away") end
        lastDodge = now
        local kc = keyFor("Dribble")
        log(string.format("DODGE from %s dist %.1f key=%s", e.Character.Name, d.Magnitude, tostring(kc)))
        diveAt, diagUntil = now, now + 0.5
        tap(kc)
    end)
end)

-- ===== ball tracking + auto keeper =====
local ballPart, prevPos, prevT, vel, lastDive = nil, nil, 0, Vector3.zero, 0

-- diagnostics: does the game see our key press, and does it start a dive?
conns[#conns + 1] = UIS.InputBegan:Connect(function(input, processed)
    if os.clock() < diagUntil and (input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType == Enum.UserInputType.MouseButton1) then
        log(string.format("input seen: %s %s processed=%s", tostring(input.UserInputType.Name), tostring(input.KeyCode.Name), tostring(processed)))
    end
end)
pcall(function()
    conns[#conns + 1] = RS.Remotes.Characters.ActionState.OnClientEvent:Connect(function(kind, data)
        if os.clock() - diveAt > 1.5 or type(data) ~= "table" then return end
        local e = data[1]
        if type(e) == "table" and e.Character == lp.Character then
            log("my ActionState after dive: " .. tostring(kind) .. " value=" .. tostring(e.Value))
        end
    end)
end)
local function getBall()
    ballPart = mainBall()
    return ballPart
end

-- logs how high the keeper actually gets after a dive, so a manual dive and a scripted one can be compared
local function logFlight(tag)
    task.spawn(function()
        local me = lp.Character
        local root = me and (me.PrimaryPart or me:FindFirstChild("HumanoidRootPart"))
        if not root then return end
        local y0, x0, z0 = root.Position.Y, root.Position.X, root.Position.Z
        local maxRise, t0 = 0, os.clock()
        while os.clock() - t0 < 1.0 and root.Parent do
            maxRise = math.max(maxRise, root.Position.Y - y0)
            task.wait()
        end
        local p = root.Position
        log(string.format("%s flight: max rise=%.1f studs, moved sideways=%.1f studs, ended %.1f up", tag, maxRise,
            Vector3.new(p.X - x0, 0, p.Z - z0).Magnitude, p.Y - y0))
    end)
end
conns[#conns + 1] = UIS.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Keyboard or UIS:GetFocusedTextBox() then return end
    local kd = keyFor("Dive")
    local me = lp.Character
    if kd and input.KeyCode == kd and me and me:GetAttribute("ActiveGoalkeeper") and os.clock() - lastDive > 0.6 then
        diveAt, diagUntil = os.clock(), os.clock() + 1.2
        log("MANUAL dive key pressed")
        logFlight("MANUAL dive")
    end
end)

local tracks = setmetatable({}, {__mode = "k"})   -- [ball part] = {p, t, v}
local function keeperStep()
    local now = os.clock()
    local balls = allBalls()
    if #balls == 0 then return end
    -- keep a velocity estimate for every ball
    for _, b in ipairs(balls) do
        local p, tr = b.Position, tracks[b]
        if not tr then tr = {p = p, t = now, v = Vector3.zero}; tracks[b] = tr
        elseif now > tr.t then
            local v = (p - tr.p) / (now - tr.t)
            if v.Magnitude > 260 then tr.v = Vector3.zero else tr.v = tr.v:Lerp(v, 0.5) end
            tr.p, tr.t = p, now
        end
    end
    vel = (tracks[mainBall() or balls[1]] or {v = Vector3.zero}).v

    local me = lp.Character
    if not CFG.keeper or not me or not me:GetAttribute("ActiveGoalkeeper") or now - lastDive < 1.9 then return end
    local mp, gp, best = pos(me), nil, math.huge
    for _, g in ipairs(goals()) do
        local d = (flat(g) - flat(mp)).Magnitude
        if d < best then best, gp = d, g end
    end
    if not gp then return end
    local s = gp.Z > 0 and 1 or -1
    local lineZ = gp.Z - s * 3
    local cam = workspace.CurrentCamera.CFrame
    local right = flat(cam.RightVector).Unit

    -- pick the most urgent ball that is actually going to cross your goal mouth
    local pick
    local function why(msg, b, v, p)
        if v.Magnitude > 30 and now - lastWhy > 0.4 then
            lastWhy = now
            log(string.format("skip: %s (ball speed %.0f vel=(%.0f,%.0f,%.0f) pos=(%.0f,%.0f,%.0f))", msg, v.Magnitude, v.X, v.Y, v.Z, p.X, p.Y, p.Z))
        end
    end
    for _, b in ipairs(balls) do
        local tr = tracks[b]
        local v, p = tr.v, b.Position
        if v.Z * s >= 10 then
            local t = (lineZ - p.Z) / v.Z
            if t > 0 and t <= 1.2 then
                local cx = p.X + v.X * t
                local cy = math.max(0.5, p.Y + v.Y * t - 0.5 * CFG.ballGravity * t * t)
                if math.abs(cx - gp.X) <= HW + 2 and cy <= 8.5 then
                    local lat = (Vector3.new(cx, 0, lineZ) - flat(mp)):Dot(right)
                    if not (math.abs(lat) < 1.5 and cy < 4) and (not pick or t < pick.t) then
                        pick = {t = t, cx = cx, cy = cy, lat = lat, v = v}
                    end
                else why(string.format("misses goal cross=(%.1f,%.1f)", cx, cy), b, v, p) end
            else why("t=" .. string.format("%.2f", t), b, v, p) end
        else why("not heading to my goal (goalZ " .. gp.Z .. ")", b, v, p) end
    end
    if not pick then return end
    local t, cx, cy, lat, v = pick.t, pick.cx, pick.cy, pick.lat, pick.v
    -- the dive covers ~20 studs in ~0.6s, so start early enough for the distance
    local lead = 0.15 + 0.6 * math.min(math.abs(lat), 20) / 20
    if t > lead then return end
    lastDive = now
    diveAt = now
    diagUntil = now + 0.5
    local kd = keyFor("Dive")
    local dirKey = lat > 1.5 and Enum.KeyCode.D or (lat < -1.5 and Enum.KeyCode.A or nil)
    log(string.format("DIVE t=%.2f cross=(%.1f, %.1f) lat=%.1f speed=%.0f key=%s (of %d balls)", t, cx, cy, lat, v.Magnitude, tostring(kd), #balls))
    if dirKey then key(dirKey, true) end
    local goalPos = gp
    task.delay(t + 0.35, function()
        local bb, mm = getBall(), lp.Character
        if bb and mm then
            local bp2, mp2 = bb.Position, pos(mm)
            log(string.format("DIVE outcome: nearest ball=(%.1f,%.1f,%.1f) vs goal line z=%.1f | me=(%.1f,%.1f) ball-to-me=%.1f",
                bp2.X, bp2.Y, bp2.Z, goalPos.Z, mp2.X, mp2.Z, (bp2 - mp2).Magnitude))
        end
    end)
    task.delay(0.02, function() tap(kd) end)
    if CFG.jumpDive and cy > 3.0 then
        local jk = keyFor("Jump") or Enum.KeyCode.Space
        task.delay(0.1, function() tap(jk, 0.12) end)
        log("jump added (ball height " .. string.format("%.1f", cy) .. ")")
    end
    logFlight("AUTO dive")
    task.delay(0.25, function() if dirKey then key(dirKey, false) end end)
end
conns[#conns + 1] = RunService.Heartbeat:Connect(function() pcall(keeperStep) end)

-- ===== keeper positioning: stand between the ball and the goal centre =====
local WASD = {W = Enum.KeyCode.W, A = Enum.KeyCode.A, S = Enum.KeyCode.S, D = Enum.KeyCode.D}
local ours = {}
local function setKey(name, down)
    if (ours[name] or false) == down then return end
    ours[name] = down or nil
    key(WASD[name], down)
end
local function releaseMoves() for n in pairs(WASD) do setKey(n, false) end end
local lastPosLog = 0
local function positionStep()
    local me, b = lp.Character, getBall()
    local active = CFG.position and me and b and me:GetAttribute("ActiveGoalkeeper")
        and not me:GetAttribute("Ragdolled") and not me:GetAttribute("Stunned") and os.clock() - lastDive > 1.2
    if not active then return releaseMoves() end
    -- if you are pressing a movement key yourself, stay out of the way
    for n, kc in pairs(WASD) do
        if UIS:IsKeyDown(kc) and not ours[n] then return releaseMoves() end
    end
    local mp, bp = pos(me), b.Position
    if (flat(bp) - flat(mp)).Magnitude < 6 then return releaseMoves() end -- you have the ball, play normally

    local gp, best = nil, math.huge
    for _, g in ipairs(goals()) do
        local d = (flat(g) - flat(mp)).Magnitude
        if d < best then best, gp = d, g end
    end
    if not gp then return releaseMoves() end
    local toBall = flat(bp) - flat(gp)
    if toBall.Magnitude < 1 then return releaseMoves() end
    local depth = math.clamp(toBall.Magnitude / 10, 3, 10)
    local t = flat(gp) + toBall.Unit * depth
    local x = gp.X + math.clamp(t.X - gp.X, -(HW - 2), HW - 2)
    local e = Vector3.new(x, 0, t.Z) - flat(mp)

    local cam = workspace.CurrentCamera.CFrame
    local rv, fv = flat(cam.RightVector).Unit, flat(cam.LookVector).Unit
    local r, f = e:Dot(rv), e:Dot(fv)
    -- brake early: the keeper keeps sliding after the key is let go, so aim for where it WILL be
    local root = me.PrimaryPart or me:FindFirstChild("HumanoidRootPart")
    if root then
        local v = flat(root.AssemblyLinearVelocity)
        r, f = r - v:Dot(rv) * 0.22, f - v:Dot(fv) * 0.22
    end
    local function axis(neg, plus, v)
        setKey(plus, v > (ours[plus] and 0.9 or 2.0))
        setKey(neg, v < -(ours[neg] and 0.9 or 2.0))
    end
    axis("A", "D", r)
    axis("S", "W", f)
    if os.clock() - lastPosLog > 3 and (ours.A or ours.D or ours.W or ours.S) then
        lastPosLog = os.clock()
        log(string.format("POSITION target=(%.1f, %.1f) off by right=%.1f fwd=%.1f depth=%.1f", x, t.Z, r, f, depth))
    end
end
conns[#conns + 1] = RunService.Heartbeat:Connect(function() pcall(positionStep) end)

-- ===== auto tackle =====
local lastTackle, suppressAimUntil = 0, 0
local function clickKick(down)
    local kc = keyFor("Kick")
    if kc then return key(kc, down) end
    local c = workspace.CurrentCamera.ViewportSize / 2
    pcall(function() VIM:SendMouseButtonEvent(c.X, c.Y, 0, down, game, 0) end)
end
local function tackleStep()
    if not (CFG.tackle or CFG.tackleKick) then return end
    local now, me, b = os.clock(), lp.Character, getBall()
    if not me or not b or now - lastTackle < 1.5 or me:GetAttribute("ActiveGoalkeeper") then return end
    if me:GetAttribute("Ragdolled") or me:GetAttribute("Stunned") then return end
    local mp, bp = pos(me), b.Position
    -- if ANY ball is at your feet you have the ball: never tackle or click (a click would pass it)
    for _, ball in ipairs(allBalls()) do
        if (ball.Position - mp).Magnitude < 6 then return end
    end
    if (flat(bp) - flat(mp)).Magnitude > CFG.tackleRange + 4 then return end

    -- whoever is closest to the ball has it; you count too, so you never slide while you hold it
    local carrier, cd = nil, 4.5
    local mine = (mp - bp).Magnitude
    if mine < cd then carrier, cd = me, mine end
    for _, folder in ipairs({workspace.Characters.Players, workspace.Characters.NPCs}) do
        for _, m in ipairs(folder:GetChildren()) do
            if m:IsA("Model") and m ~= me then
                local d = (pos(m) - bp).Magnitude
                if d < cd then cd, carrier = d, m end
            end
        end
    end
    if not carrier or carrier == me then return end
    if carrier:GetAttribute("Ragdolled") or carrier:GetAttribute("Stunned") then return end
    local plr = Players:GetPlayerFromCharacter(carrier)
    if plr and plr.Team and lp.Team and plr.Team == lp.Team then return end

    local to = flat(pos(carrier)) - flat(mp)
    if to.Magnitude > CFG.tackleRange or to.Magnitude < 0.1 then return end
    if flat(me:GetPivot().LookVector):Dot(to.Unit) < 0.3 then return end
    local kick = CFG.tackleKick and to.Magnitude <= CFG.kickRange
    if not kick and not CFG.tackle then return end
    lastTackle = now
    diveAt, diagUntil = now, now + 0.5
    if kick then
        -- holding click kicks whoever is in front of you; keep the shot aim out of it
        suppressAimUntil = now + 0.6
        log(string.format("KICK-ATTACK %s dist %.1f", carrier.Name, to.Magnitude))
        clickKick(true)
        task.delay(0.3, function() clickKick(false) end)
    else
        local kc = keyFor("Tackle")
        log(string.format("TACKLE %s dist %.1f key=%s", carrier.Name, to.Magnitude, tostring(kc)))
        tap(kc)
    end
    task.delay(1.2, function()
        log(string.format((kick and "KICK" or "TACKLE") .. " result: carrier Ragdolled=%s Stunned=%s | me Ragdolled=%s Stunned=%s",
            tostring(carrier:GetAttribute("Ragdolled")), tostring(carrier:GetAttribute("Stunned")),
            tostring(me:GetAttribute("Ragdolled")), tostring(me:GetAttribute("Stunned"))))
    end)
end
conns[#conns + 1] = RunService.Heartbeat:Connect(function() pcall(tackleStep) end)

-- ===== top-corner shot aim =====
local lastAimLog = 0
local bikeUntil = 0
local savedCF = nil
local function aimStep()
    if not CFG.aim then return end
    local me, b = lp.Character, getBall()
    if not me or not b or me:GetAttribute("ActiveGoalkeeper") then return end
    local kc = keyFor("Kick")
    local bike = os.clock() < bikeUntil
    if os.clock() < suppressAimUntil and not bike then return end
    local held = bike or (kc and UIS:IsKeyDown(kc)) or (not kc and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1))
    if not held then return end
    local mp = pos(me)
    if not bike and (b.Position - mp).Magnitude > 9 then return end

    local cam = workspace.CurrentCamera
    local look = flat(cam.CFrame.LookVector).Unit
    local gp, bestDot = nil, -math.huge
    for _, g in ipairs(goals()) do
        local d = (flat(g) - flat(mp))
        if d.Magnitude < CFG.aimRange and d.Unit:Dot(look) > bestDot then bestDot, gp = d.Unit:Dot(look), g end
    end
    if not gp or bestDot < 0.3 then return end

    local keeperX, kd = nil, 35
    for _, folder in ipairs({workspace.Characters.Players, workspace.Characters.NPCs}) do
        for _, m in ipairs(folder:GetChildren()) do
            if m:IsA("Model") and m ~= me and m:GetAttribute("ActiveGoalkeeper") then
                local d = (flat(pos(m)) - flat(gp)).Magnitude
                if d < kd then kd, keeperX = d, pos(m).X end
            end
        end
    end
    local reach = HW - CFG.cornerInset
    local farLeft = keeperX and (keeperX > gp.X) or (mp.X > gp.X)
    local target = Vector3.new(gp.X + (farLeft and -reach or reach), CFG.cornerY, gp.Z)
    local cp = cam.CFrame.Position
    local dir = cam.CFrame.LookVector:Lerp((target - cp).Unit, CFG.aimStrength)
    savedCF = cam.CFrame -- put back at the end of the frame so your view never moves
    cam.CFrame = CFrame.lookAt(cp, cp + dir)
    if os.clock() - lastAimLog > 0.5 then
        lastAimLog = os.clock()
        log(string.format("AIM corner x=%.1f y=%.1f keeperX=%s dist=%.0f", target.X, target.Y, tostring(keeperX), (target - cp).Magnitude))
    end
end
-- hold the game's own Curve key while charging a shot, and measure how much the ball actually bends
local curveDown, wasHeld, curveHeld = false, false, nil
local function trackShot()
    local pts, t0 = {}, os.clock()
    while os.clock() - t0 < 1.4 do
        local b = getBall()
        if b and os.clock() - t0 > 0.15 then pts[#pts + 1] = flat(b.Position) end
        task.wait()
    end
    if #pts < 5 then return end
    local a, c = pts[1], pts[#pts]
    local ab = c - a
    if ab.Magnitude < 5 then return log("SHOT too short to measure") end
    local maxDev = 0
    for _, q in ipairs(pts) do
        local dev = math.abs((q - a):Cross(ab).Y) / ab.Magnitude
        if dev > maxDev then maxDev = dev end
    end
    log(string.format("SHOT bend=%.1f studs over %.0f studs (curveKey=%s)", maxDev, ab.Magnitude, tostring(curveKeyCode())))
end
local function curveStep()
    local me, b = lp.Character, getBall()
    local held = false
    if me and b and not me:GetAttribute("ActiveGoalkeeper") then
        local kc = keyFor("Kick")
        local pressed = (kc and UIS:IsKeyDown(kc)) or (not kc and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1))
        held = ((pressed and (b.Position - pos(me)).Magnitude < 9) or os.clock() < bikeUntil) and os.clock() >= suppressAimUntil
    end
    local ck = curveKeyCode()
    if CFG.curve and held and not curveDown and ck then key(ck, true) curveDown = true; curveHeld = ck end
    if (not held or not CFG.curve) and curveDown then key(curveHeld or ck, false) curveDown = false end
    if wasHeld and not held then task.spawn(trackShot) end
    wasHeld = held
end
conns[#conns + 1] = RunService.Heartbeat:Connect(function() pcall(curveStep) end)
pcall(function()
    local CK = req("CurvedKicks")
    if CK then log(string.format("CurvedKicks enabled=%s power=%s", tostring(CK.IsEnabled()), tostring(CK.GetPower()))) end
end)

RunService:BindToRenderStep("KingSoccerAim", Enum.RenderPriority.Camera.Value + 1, function() pcall(aimStep) end)
RunService:BindToRenderStep("KingSoccerAimRestore", Enum.RenderPriority.Last.Value + 1000, function()
    if savedCF then
        pcall(function() workspace.CurrentCamera.CFrame = savedCF end)
        savedCF = nil
    end
end)

-- ===== experimental stamina (client-side only, server may overrule) =====
local orig = {}
local function setStamina(on)
    local function patch(mod, name)
        if not mod or type(mod[name]) ~= "function" then return end
        pcall(function()
            if on then
                if not orig[name] then orig[name] = {mod, mod[name]} end
                mod[name] = function() return 0 end
            elseif orig[name] then
                mod[name] = orig[name][2]
                orig[name] = nil
            end
        end)
    end
    patch(Sprint, "GetDrainAmount")
    patch(Sprint, "GetSpendAmount")
    patch(HitStamina, "GetCost")
    log("stamina patch " .. tostring(on))
end

-- ===== panel =====
local TweenService = game:GetService("TweenService")
local T = {
    bg = Color3.fromRGB(7, 12, 16), row = Color3.fromRGB(13, 24, 30), teal = Color3.fromRGB(0, 200, 175),
    bright = Color3.fromRGB(70, 255, 225), off = Color3.fromRGB(38, 52, 58), text = Color3.fromRGB(205, 232, 227),
    dim = Color3.fromRGB(110, 145, 140), knob = Color3.fromRGB(240, 250, 248),
}
local gui = Instance.new("ScreenGui")
gui.Name = "KingSoccer"
gui.ResetOnSpawn = false
gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

local ROW_H, PAD, HEAD = 44, 8, 46
local ROWS = {
    {"dodge", "Auto dodge", "Dodges slide tackles"},
    {"keeper", "Auto keeper", "Dives at shots on your goal"},
    {"position", "Keeper positioning", "Tracks the ball along your goal line"},
    {"jumpDive", "Jump dive", "Jumps with the dive on high shots"},
    {"aim", "Corner aim", "Silent. Hold kick near the ball"},
    {"curve", "Curve on shots", "Holds your curve key while charging"},
    {"bike", "Flick to bicycle", "Q flick, then jump and bicycle kick"},
    {"tackle", "Auto tackle", "Slides at the ball carrier"},
    {"tackleKick", "Kick attack", "Holds click to kick close opponents"},
    {"stamina", "Stamina (experimental)", "Client only, the server may undo it", setStamina},
}

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(270, HEAD + #ROWS * (ROW_H + 4) + 30)
frame.Position = UDim2.new(0, 24, 0.5, -frame.Size.Y.Offset / 2)
frame.BackgroundColor3 = T.bg
frame.BorderSizePixel = 0
frame.Active, frame.Draggable = true, true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", frame)
stroke.Color = T.teal
stroke.Thickness = 1.2
stroke.Transparency = 0.25

local function label(parent, text, size, color, font, pos, sz, align)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text, l.TextSize, l.TextColor3, l.Font = text, size, color, font
    l.Position, l.Size = pos, sz
    l.TextXAlignment = align or Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

label(frame, "KING HUB", 16, T.bright, Enum.Font.GothamBlack, UDim2.fromOffset(14, 8), UDim2.fromOffset(150, 20))
label(frame, "SOCCER", 11, T.dim, Enum.Font.GothamMedium, UDim2.fromOffset(14, 27), UDim2.fromOffset(150, 14))
local badge = label(frame, "K  hide", 11, T.dim, Enum.Font.GothamMedium, UDim2.new(1, -84, 0, 14), UDim2.fromOffset(70, 16), Enum.TextXAlignment.Right)
local line = Instance.new("Frame")
line.Size, line.Position = UDim2.new(1, -28, 0, 1), UDim2.fromOffset(14, HEAD - 3)
line.BackgroundColor3, line.BackgroundTransparency, line.BorderSizePixel = T.teal, 0.7, 0
line.Parent = frame

local function addRow(i, field, title, sub, onChange)
    local row = Instance.new("TextButton")
    row.AutoButtonColor = false
    row.Text = ""
    row.Size = UDim2.new(1, -PAD * 2, 0, ROW_H)
    row.Position = UDim2.fromOffset(PAD, HEAD + (i - 1) * (ROW_H + 4))
    row.BackgroundColor3 = T.row
    row.BorderSizePixel = 0
    row.Parent = frame
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    label(row, title, 13, T.text, Enum.Font.GothamBold, UDim2.fromOffset(12, 6), UDim2.new(1, -70, 0, 18))
    label(row, sub, 10, T.dim, Enum.Font.Gotham, UDim2.fromOffset(12, 24), UDim2.new(1, -70, 0, 14))

    local pill = Instance.new("Frame")
    pill.Size, pill.Position = UDim2.fromOffset(38, 20), UDim2.new(1, -50, 0.5, -10)
    pill.BorderSizePixel = 0
    pill.Parent = row
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(14, 14)
    knob.BackgroundColor3, knob.BorderSizePixel = T.knob, 0
    knob.Parent = pill
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local function paint(animate)
        local on = CFG[field]
        local goal = {BackgroundColor3 = on and T.teal or T.off}
        local kgoal = {Position = UDim2.fromOffset(on and 21 or 3, 3)}
        if animate then
            TweenService:Create(pill, TweenInfo.new(0.15), goal):Play()
            TweenService:Create(knob, TweenInfo.new(0.15), kgoal):Play()
        else
            pill.BackgroundColor3, knob.Position = goal.BackgroundColor3, kgoal.Position
        end
    end
    row.MouseEnter:Connect(function() TweenService:Create(row, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(18, 33, 40)}):Play() end)
    row.MouseLeave:Connect(function() TweenService:Create(row, TweenInfo.new(0.1), {BackgroundColor3 = T.row}):Play() end)
    row.MouseButton1Click:Connect(function()
        CFG[field] = not CFG[field]
        paint(true)
        if onChange then onChange(CFG[field]) end
    end)
    paint(false)
end
for i, r in ipairs(ROWS) do addRow(i, r[1], r[2], r[3], r[4]) end

label(frame, "log: king_hub/soccer_log.txt", 10, T.dim, Enum.Font.Gotham,
    UDim2.new(0, 14, 1, -22), UDim2.new(1, -28, 0, 14))

-- ===== Q: jump, then bicycle kick into the corner =====
-- The game's own flick-up key (Q) is left alone. After it, we wait for the ball to drop into reach,
-- then jump and kick so the bicycle kick lands on the way down.
local bikeWait, bikeBusy, bikeLog = nil, false, 0
local bikeH0, bikeMax = nil, nil
local function bikeGo(now, why)
    bikeBusy, bikeWait = true, nil
    local d = CFG.bikeDelay
    bikeUntil = now + d + 1.0
    local jumpKey = keyFor("Jump") or Enum.KeyCode.Space
    log("BIKE jump (" .. why .. ")")
    tap(jumpKey, 0.1)
    task.delay(d, function()
        diveAt, diagUntil = os.clock(), os.clock() + 1.0
        local b0, m0 = getBall(), lp.Character
        log(string.format("BIKE kick pressed, ball dist %.1f", (b0 and m0) and (b0.Position - pos(m0)).Magnitude or -1))
        clickKick(true)
        task.delay(0.45, function()          -- the game needs 0.2s of charge at least; 0.4s is full power
            clickKick(false)
            log("BIKE kick released")
            task.delay(0.8, function() bikeBusy = false end)
        end)
    end)
end
local function bikeStep()
    if not bikeWait or bikeBusy then return end
    local now, me, b = os.clock(), lp.Character, getBall()
    if not me or not b or me:GetAttribute("ActiveGoalkeeper") then bikeWait = nil return end
    local since = now - bikeWait
    local mp, bp = pos(me), b.Position
    local dh = (flat(bp) - flat(mp)).Magnitude
    local h = bp.Y - mp.Y
    -- heights are judged against where the ball started, so a weaker flick (practice range) still counts
    bikeH0 = bikeH0 or h
    bikeMax = math.max(bikeMax or h, h)
    local lifted = (bikeMax - bikeH0) > 1.0
    if now - bikeLog > 0.2 then
        bikeLog = now
        log(string.format("BIKE watch t=%.2f dh=%.1f h=%.1f vy=%.1f", since, dh, h, vel.Y))
    end
    if since > 3 then
        bikeWait = nil
        return log("BIKE gave up")
    end
    if since < 0.3 then return end
    local d = CFG.bikeDelay
    local ph = h + vel.Y * d - 0.5 * CFG.ballGravity * d * d
    if lifted and vel.Y < 6 and dh < 14 and ph <= 7 and (ph - bikeH0) >= 1.0 then
        return bikeGo(now, string.format("ball in reach dh=%.1f h=%.1f predicted=%.1f", dh, h, ph))
    end
    -- the one jump that worked before came about 0.95s after the flick with the ball near its peak
    -- never jump at a ball that is still on the floor (the flick failed or got tackled)
    if since > 1.8 and not lifted then
        bikeWait = nil
        return log(string.format("BIKE gave up: ball only rose %.1f studs (dh=%.1f)", bikeMax - bikeH0, dh))
    end
    if since > CFG.bikeFallback and dh < 16 and lifted then
        return bikeGo(now, string.format("timed fallback dh=%.1f h=%.1f", dh, h))
    end
end
conns[#conns + 1] = RunService.Heartbeat:Connect(function() pcall(bikeStep) end)

conns[#conns + 1] = UIS.InputBegan:Connect(function(input, processed)
    if input.UserInputType ~= Enum.UserInputType.Keyboard or UIS:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.K and not processed then frame.Visible = not frame.Visible end
    -- the game's flick-up key may be marked processed, so don't filter on that
    if CFG.bike and input.KeyCode == (keyFor("RainbowFlick") or Enum.KeyCode.Q) then
        bikeWait = os.clock()
        bikeH0, bikeMax = nil, nil
        log("BIKE armed by flick key")
    end
end)

genv.KING_SOCCER_CLOSE = function()
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    releaseMoves()
    if curveDown then key(curveHeld or curveKeyCode(), false) end
    pcall(function() RunService:UnbindFromRenderStep("KingSoccerAim") end)
    pcall(function() RunService:UnbindFromRenderStep("KingSoccerAimRestore") end)
    setStamina(false)
    gui:Destroy()
    genv.KING_SOCCER_CLOSE = nil
end
genv.KING_UNLOADERS.soccer = genv.KING_SOCCER_CLOSE
pcall(function()
    local BK = req("Actions.BicycleKick")
    if BK then
        for k, v in pairs(BK) do
            if type(v) == "table" then
                for k2, v2 in pairs(v) do if type(v2) ~= "table" and type(v2) ~= "function" then log("BicycleKick." .. k .. "." .. k2 .. " = " .. tostring(v2)) end end
            elseif type(v) ~= "function" then log("BicycleKick." .. k .. " = " .. tostring(v)) end
        end
    end
end)
log(string.format("loaded. keys: dodge(Dribble)=%s dive=%s kick=%s HW=%s", tostring(keyFor("Dribble")), tostring(keyFor("Dive")), tostring(keyFor("Kick")), tostring(HW)))
log(string.format("curve keys: AutoCurve=%s Curve=%s -> using %s", tostring(keyFor("AutoCurve")), tostring(keyFor("Curve")), tostring(curveKeyCode())))
print("[KING soccer] loaded - K to hide")
