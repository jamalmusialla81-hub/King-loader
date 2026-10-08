-- Blox Strike ESP probe: for every player, shows why the ESP would or wouldn't draw them. Read-only.
-- Run in a match with the hub loaded, then read the output (also saved to king_hub/blox_probe.txt):
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/jamalmusialla81-hub/King-loader/main/blox_probe.lua"))()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera
local out = {}
local function p(s)
    out[#out + 1] = tostring(s); print("[BXP] " .. tostring(s))
    if shared and shared.MH_Log then pcall(shared.MH_Log, "BXP " .. tostring(s)) end   -- also goes into king_hub/hub_log.txt
end
p("me: " .. lp.Name .. " Team attr=" .. tostring(lp:GetAttribute("Team")) .. " Roblox Team=" .. tostring(lp.Team))
-- frame time
local acc, n = 0, 0
local c = RunService.RenderStepped:Connect(function(dt) acc += dt; n += 1 end)
task.wait(2)
c:Disconnect()
p(string.format("avg fps over 2s: %.0f (frame %.1f ms)", n / acc, acc / n * 1000))
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= lp then
        local ch = plr.Character
        local head = ch and ch:FindFirstChild("Head")
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        local onScreen = "n/a"
        if head then local _, on = cam:WorldToViewportPoint(head.Position) onScreen = tostring(on) end
        local inWs = ch and ch:IsDescendantOf(workspace)
        local parentName = ch and (ch.Parent and ch.Parent:GetFullName() or "nil") or "-"
        local dist = (hrp and cam) and math.floor((hrp.Position - cam.CFrame.Position).Magnitude) or "?"
        p(string.format("%s | Team attr=%s | char=%s inWorkspace=%s parent=%s head=%s hrp=%s hum=%s hp=%s Dead=%s | dist=%s onScreen=%s",
            plr.Name, tostring(plr:GetAttribute("Team")), tostring(ch ~= nil), tostring(inWs), parentName, tostring(head ~= nil), tostring(hrp ~= nil),
            tostring(hum ~= nil), tostring(hum and hum.Health), tostring(plr:GetAttribute("Dead")), tostring(dist), onScreen))
    end
end
-- do culled characters (parked outside workspace) still move?
local culled = {}
for _, plr in ipairs(Players:GetPlayers()) do
    local ch = plr ~= lp and plr.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    if hrp and not ch:IsDescendantOf(workspace) then culled[plr.Name] = {hrp, hrp.Position} end
end
task.wait(1.5)
for name, v in pairs(culled) do
    local moved = (v[1].Position - v[2]).Magnitude
    p(string.format("culled %s moved %.2f studs in 1.5s (%s)", name, moved, moved > 0.05 and "UPDATING" or "FROZEN"))
end
if next(culled) == nil then p("no culled characters this time - run again when the list shows parent=ReplicatedStorage._PVS_CulledCharacters") end
pcall(function() if makefolder and not isfolder("king_hub") then makefolder("king_hub") end end)
pcall(writefile, "king_hub/blox_probe.txt", table.concat(out, "\n") .. "\n")
p("done")
-- copy the whole result to the clipboard so it can be pasted straight into the chat
local text = table.concat(out, "\n")
local copy = setclipboard or toclipboard or (syn and syn.write_clipboard)
if copy then pcall(copy, text); print("[BXP] copied to clipboard - just paste it") else print("[BXP] no clipboard function; see king_hub/blox_probe.txt or hub_log.txt") end
