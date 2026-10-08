-- Blox Strike ESP probe: for every player, shows why the ESP would or wouldn't draw them. Read-only.
-- Run in a match with the hub loaded, then read the output (also saved to king_hub/blox_probe.txt):
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/jamalmusialla81-hub/King-loader/main/blox_probe.lua"))()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera
local out = {}
local function p(s) out[#out + 1] = tostring(s); print("[BXP] " .. tostring(s)) end
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
pcall(function() if makefolder and not isfolder("king_hub") then makefolder("king_hub") end end)
pcall(writefile, "king_hub/blox_probe.txt", table.concat(out, "\n") .. "\n")
p("done")
