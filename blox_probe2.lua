-- Blox Strike probe 2: how often do other players' parts actually move? Read-only.
-- Run in a match with a few players alive near you. Result goes to the console, king_hub/hub_log.txt, king_hub/blox_probe2.txt and the clipboard.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera
local out = {}
local function p(s)
    out[#out + 1] = tostring(s); print("[BXP2] " .. tostring(s))
    if shared and shared.MH_Log then pcall(shared.MH_Log, "BXP2 " .. tostring(s)) end
end
local function alive(plr)
    local ch = plr.Character
    return plr ~= lp and ch and ch:FindFirstChild("Head") and plr:GetAttribute("Dead") ~= true and ch:IsDescendantOf(workspace)
end
local list = {}
for _, plr in ipairs(Players:GetPlayers()) do
    if alive(plr) then
        local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
        list[#list + 1] = {plr = plr, d = hrp and (hrp.Position - cam.CFrame.Position).Magnitude or 1e9}
    end
end
table.sort(list, function(a, b) return a.d < b.d end)
local picked = {}
for i = 1, math.min(2, #list) do picked[#picked + 1] = list[i].plr end              -- 2 nearest
for i = #list, math.max(3, #list - 1), -1 do picked[#picked + 1] = list[i].plr end  -- 2 farthest
for _, e in ipairs(list) do p(string.format("%s alive at %.0f studs", e.plr.Name, e.d)) end
if #picked == 0 then p("no living players found - join a match with others alive and run again") end

-- parts of each character
local watch = {}
for _, plr in ipairs(picked) do
    local ch = plr.Character
    local names = {}
    for _, c in ipairs(ch:GetChildren()) do names[#names + 1] = c.Name .. "(" .. c.ClassName .. ")" end
    local h0 = plr.Character:FindFirstChild("HumanoidRootPart")
    p(plr.Name .. " is " .. (h0 and math.floor((h0.Position - cam.CFrame.Position).Magnitude) or "?") .. " studs away")
    p(plr.Name .. " children: " .. table.concat(names, ", "))
    p(plr.Name .. " PrimaryPart=" .. tostring(ch.PrimaryPart and ch.PrimaryPart.Name) .. " Head-HRP offset=" ..
        (function() local h, r = ch:FindFirstChild("Head"), ch:FindFirstChild("HumanoidRootPart")
            return (h and r) and string.format("%.2f studs up", h.Position.Y - r.Position.Y) or "?" end)())
    for _, nm in ipairs({"Head", "HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso", "LeftFoot", "Left Leg"}) do
        local part = ch:FindFirstChild(nm)
        if part and part:IsA("BasePart") then watch[#watch + 1] = {plr = plr.Name, name = nm, part = part, last = part.Position, changes = 0, maxStep = 0, anchored = part.Anchored} end
    end
end

-- count how many frames the position actually changes
local frames, t0 = 0, os.clock()
local c = RunService.RenderStepped:Connect(function()
    frames += 1
    for _, w in ipairs(watch) do
        local pos = w.part.Position
        local step = (pos - w.last).Magnitude
        if step > 0.001 then w.changes += 1; if step > w.maxStep then w.maxStep = step end end
        w.last = pos
    end
end)
task.wait(2)
c:Disconnect()
local secs = os.clock() - t0
p(string.format("sampled %d frames in %.1fs (%.0f fps)", frames, secs, frames / secs))
for _, w in ipairs(watch) do
    p(string.format("%s.%s: position changed on %d/%d frames (%.0f%%), biggest jump %.2f studs, anchored=%s",
        w.plr, w.name, w.changes, frames, w.changes / math.max(frames, 1) * 100, w.maxStep, tostring(w.anchored)))
end
pcall(function() if makefolder and not isfolder("king_hub") then makefolder("king_hub") end end)
pcall(writefile, "king_hub/blox_probe2.txt", table.concat(out, "\n") .. "\n")
p("done")
local copy = setclipboard or toclipboard or (syn and syn.write_clipboard)
if copy then pcall(copy, table.concat(out, "\n")); print("[BXP2] copied to clipboard - just paste it") end
