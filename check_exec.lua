-- Executor check: which functions do the KING HUB scripts need, and which does YOUR executor have?
-- Run:  loadstring(game:HttpGet("https://raw.githubusercontent.com/jamalmusialla81-hub/King-loader/main/check_exec.lua"))()      (or paste this whole file into the executor)
-- Prints the result (and saves king_hub/exec_check.txt if the executor has writefile). Read-only: nothing is hooked or changed.
local g = (getgenv and getgenv()) or _G
local function has(name) local v = g[name]; if v == nil then v = rawget(_G, name) end; return v ~= nil end

local NEED = {
    {"writefile", "optional: logs and saved configs"},
    {"appendfile", "optional: logs (falls back to writefile)"},
    {"isfile", "optional: configs"}, {"isfolder", "optional: configs"}, {"makefolder", "optional: configs"},
    {"loadstring", "loader"},
    {"getgenv", "unload / one-script-at-a-time"},
    {"gethui", "menus (falls back to CoreGui)"},
    {"Drawing", "ESP / FOV circles"},
    {"mousemoverel", "aimbot / lock-on"},
    {"mouse1press", "triggerbot (falls back to VirtualInputManager)"},
    {"mouse1release", "triggerbot (falls back to VirtualInputManager)"},
    {"getgc", "no-recoil on Operation One"},
    {"getactors", "Operation One silent aim + no-recoil (not needed elsewhere)"},
    {"run_on_actor", "Operation One silent aim + no-recoil (not needed elsewhere)"},
    {"hookfunction", "optional"},
    {"getrenv", "optional"},
    {"cloneref", "optional"},
    {"setclipboard", "optional"},
}

local lines, missing = {}, {}
lines[#lines + 1] = "executor: " .. tostring((identifyexecutor and select(1, identifyexecutor())) or "unknown")
for _, n in ipairs(NEED) do
    local ok = has(n[1])
    lines[#lines + 1] = string.format("%-14s %s   %s", n[1], ok and "OK     " or "MISSING", n[2])
    if not ok then missing[#missing + 1] = n[1] end
end

-- quick behaviour tests
local function try(label, fn)
    local ok, err = pcall(fn)
    lines[#lines + 1] = string.format("test %-26s %s", label, ok and "ok" or ("FAILED: " .. tostring(err)))
end
try("Drawing.new Square", function() local d = Drawing.new("Square"); d:Remove() end)
try("VirtualInputManager", function() game:GetService("VirtualInputManager") end)
try("Highlight instance", function() Instance.new("Highlight"):Destroy() end)
try("game:HttpGet (GitHub raw)", function()
    local src = game:HttpGet("https://raw.githubusercontent.com/jamalmusialla81-hub/King-loader/main/load.lua")
    assert(type(src) == "string" and #src > 0, "empty response")
end)
try("write + read file (optional)", function()
    writefile("king_hub_test.txt", "x"); assert(readfile("king_hub_test.txt") == "x")
    if delfile then delfile("king_hub_test.txt") end
end)

lines[#lines + 1] = ""
if #missing == 0 then
    lines[#lines + 1] = "verdict: everything the scripts use is present."
else
    lines[#lines + 1] = "verdict: missing " .. table.concat(missing, ", ")
    lines[#lines + 1] = "Soccer, Phantom Forces and Blox Strike mostly need only Drawing and gethui (file functions are optional, used for logs and saved configs)."
    lines[#lines + 1] = "Operation One's silent aim and no-recoil need getactors + run_on_actor."
end

local text = table.concat(lines, "\n") .. "\n"
pcall(function() if makefolder and isfolder and not isfolder("king_hub") then makefolder("king_hub") end end)
pcall(writefile, "king_hub/exec_check.txt", text)
print(text)
