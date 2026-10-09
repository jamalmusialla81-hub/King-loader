-- Huss Valley probe: maps the game's structure so a script can be written for it. Read-only, runs once (~5 s).
-- Result -> console, king_hub/huss_probe.txt, clipboard.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local lp = Players.LocalPlayer
local out = {}
local function p(s) out[#out + 1] = tostring(s); print("[HUSS] " .. tostring(s)) end

p(string.format("placeId=%d gameId=%d players=%d", game.PlaceId, game.GameId, #Players:GetPlayers()))
pcall(function() p("game name: " .. game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name) end)

-- tree dump with limits
local function tree(root, depth, maxDepth, budget)
    if depth > maxDepth or budget.n <= 0 then return end
    local kids = root:GetChildren()
    local byClass = {}
    for _, c in ipairs(kids) do byClass[c.ClassName] = (byClass[c.ClassName] or 0) + 1 end
    local shown = 0
    for _, c in ipairs(kids) do
        if budget.n <= 0 then return end
        -- collapse long lists of the same class (map parts etc.)
        if byClass[c.ClassName] > 12 and shown >= 3 and not (c:IsA("Folder") or c:IsA("Model")) then
            -- skip
        else
            budget.n -= 1
            shown += 1
            p(string.rep("  ", depth) .. c.Name .. " [" .. c.ClassName .. "]" .. (#c:GetChildren() > 0 and (" (" .. #c:GetChildren() .. ")") or ""))
            tree(c, depth + 1, maxDepth, budget)
        end
    end
    for cls, n in pairs(byClass) do
        if n > 12 then p(string.rep("  ", depth) .. "... " .. n .. "x " .. cls) end
    end
end

p("=== ReplicatedStorage")
tree(RS, 1, 3, {n = 250})
p("=== Workspace (top levels)")
tree(workspace, 1, 2, {n = 200})

p("=== remotes")
local rem = {}
for _, d in ipairs(game:GetDescendants()) do
    if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
        rem[#rem + 1] = d:GetFullName() .. " [" .. d.ClassName .. "]"
    end
end
table.sort(rem)
for i = 1, math.min(#rem, 150) do p(rem[i]) end
if #rem > 150 then p("... " .. (#rem - 150) .. " more") end

p("=== my character")
local ch = lp.Character
if ch then
    p("parent: " .. (ch.Parent and ch.Parent:GetFullName() or "nil"))
    for _, c in ipairs(ch:GetChildren()) do p("  " .. c.Name .. " [" .. c.ClassName .. "]") end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if hum then p(string.format("humanoid health=%s/%s walkspeed=%s", hum.Health, hum.MaxHealth, hum.WalkSpeed)) end
    for k, v in pairs(ch:GetAttributes()) do p("  attr " .. k .. "=" .. tostring(v)) end
end
p("=== players")
for _, pl in ipairs(Players:GetPlayers()) do
    local attrs = {}
    for k, v in pairs(pl:GetAttributes()) do attrs[#attrs + 1] = k .. "=" .. tostring(v) end
    local ls = pl:FindFirstChild("leaderstats")
    local stats = {}
    if ls then for _, s in ipairs(ls:GetChildren()) do stats[#stats + 1] = s.Name .. "=" .. tostring(s.Value) end end
    p(string.format("%s team=%s char=%s attrs={%s} leaderstats={%s}", pl.Name, tostring(pl.Team), pl.Character and pl.Character:GetFullName() or "none",
        table.concat(attrs, ", "), table.concat(stats, ", ")))
end
p("=== my tools / backpack")
for _, t in ipairs(lp.Backpack:GetChildren()) do p("  backpack: " .. t.Name .. " [" .. t.ClassName .. "]") end
if ch then for _, t in ipairs(ch:GetChildren()) do if t:IsA("Tool") then p("  held: " .. t.Name) end end end
p("=== PlayerGui")
for _, g in ipairs(lp.PlayerGui:GetChildren()) do p("  " .. g.Name .. " [" .. g.ClassName .. "]") end

pcall(function() if makefolder and not isfolder("king_hub") then makefolder("king_hub") end end)
pcall(writefile, "king_hub/huss_probe.txt", table.concat(out, "\n") .. "\n")
local copy = setclipboard or toclipboard or (syn and syn.write_clipboard)
if copy then pcall(copy, table.concat(out, "\n")); print("[HUSS] copied to clipboard - just paste it") end
p("done")
