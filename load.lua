-- KING HUB auto loader: detects the game you are in and runs the matching script.
-- Anything else that is running is unloaded first. If the game isn't recognised, the hub menu opens instead.
-- Run:  loadstring(readfile("king_hub/load.lua"))()
local RS = game:GetService("ReplicatedStorage")

local GAMES = {
    {name = "Blox Strike", path = "king_hub/blox_strike.lua", detect = function()
        return game.PlaceId == 114234929420007
            or (RS:FindFirstChild("Assets") ~= nil and RS.Assets:FindFirstChild("Skins") ~= nil and RS:FindFirstChild("NetworkRemotes") ~= nil)
    end},
    {name = "Phantom Forces", path = "king_hub/phantom_forces.lua", detect = function()
        return game.PlaceId == 292439477
            or (RS:FindFirstChild("ReadyEvent") ~= nil and RS:FindFirstChild("PlayerDataEvent") ~= nil)
    end},
    {name = "Operation One", path = "king_hub/operation_one.lua", detect = function()
        return workspace:FindFirstChild("Viewmodels") ~= nil
            or (RS:FindFirstChild("Modules") ~= nil and RS.Modules:FindFirstChild("Items") ~= nil)
    end},
    {name = "Soccer", path = "king_hub/soccer.lua", detect = function()
        return game.PlaceId == 126987974021910
            or (RS:FindFirstChild("Modules") ~= nil and RS.Modules:FindFirstChild("Ball") ~= nil and RS.Modules:FindFirstChild("Actions") ~= nil)
            or (RS:FindFirstChild("Modules") ~= nil and RS.Modules:FindFirstChild("Gameplay") ~= nil and RS.Modules.Gameplay:FindFirstChild("Keybinds") ~= nil)
    end},
}

local function run(path)
    local ok, src = pcall(readfile, path)
    if not ok or not src then warn("[KING] can't read " .. path) return false end
    local fn, err = loadstring(src)
    if not fn then warn("[KING] " .. path .. " failed to compile: " .. tostring(err)) return false end
    local ok2, err2 = pcall(fn)
    if not ok2 then warn("[KING] " .. path .. " errored: " .. tostring(err2)) end
    return ok2
end

-- close the hub menu and everything else that is running (each script also does this itself)
pcall(function() if getgenv and getgenv().GAMEHUB_CLOSE then getgenv().GAMEHUB_CLOSE() end end)
pcall(function()
    local g = getgenv and getgenv() or _G
    for k, fn in pairs(g.KING_UNLOADERS or {}) do pcall(fn); g.KING_UNLOADERS[k] = nil end
end)

for _, g in ipairs(GAMES) do
    local ok, hit = pcall(g.detect)
    if ok and hit then
        print("[KING] detected " .. g.name)
        run(g.path)
        return
    end
end
print("[KING] game not recognised, opening the hub")
run("king_hub/hub_loader.lua")
