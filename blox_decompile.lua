-- Blox Strike: decompile the game's own client code that could carry enemy positions (MacSploit: decompile).
-- Looks at every client script / loaded module, keeps the ones whose name or path mentions movement, snapshots,
-- culling, radar / minimap / spotting, replication or sound, decompiles them and saves:
--   king_hub/decompiled/<path>.lua   one file per script
--   king_hub/decompiled/_index.txt    every client script name (matched or not), so more can be picked later
--   king_hub/decompiled/_all.txt      all matched sources in one file (upload this one)
-- Read-only. Can take a minute; the game may stutter while it decompiles.
local OUT = "king_hub/decompiled"
pcall(function() if not isfolder("king_hub") then makefolder("king_hub") end end)
pcall(function() if not isfolder(OUT) then makefolder(OUT) end end)
if not decompile then warn("[DECOMP] this executor has no decompile()") return end

local KEYWORDS = {"movement", "snapshot", "pvs", "cull", "radar", "minimap", "map", "spot", "replicat", "network",
    "visib", "interp", "sound", "footstep", "character", "spectat", "client", "remote", "net"}
local SKIP_PATH = {"CoreGui", "CorePackages", "RobloxGui", "PlayerModule", "ChatScript", "BubbleChat", "ExperienceChat"}

local seen, list = {}, {}
local function add(s)
    if typeof(s) ~= "Instance" or seen[s] then return end
    if not (s:IsA("LocalScript") or s:IsA("ModuleScript") or (s:IsA("Script") and s.RunContext == Enum.RunContext.Client)) then return end
    seen[s] = true
    list[#list + 1] = s
end
pcall(function() for _, s in ipairs(getscripts()) do add(s) end end)
pcall(function() for _, s in ipairs(getloadedmodules()) do add(s) end end)
pcall(function() for _, s in ipairs(getrunningscripts()) do add(s) end end)
pcall(function() for _, s in ipairs(getnilinstances()) do add(s) end end)

local function pathOf(s)
    local ok, p = pcall(function() return s:GetFullName() end)
    return ok and p or ("nil." .. s.Name)
end
local function wanted(path)
    for _, k in ipairs(SKIP_PATH) do if path:find(k, 1, true) then return false end end
    local low = path:lower()
    for _, k in ipairs(KEYWORDS) do if low:find(k, 1, true) then return true end end
    return false
end

table.sort(list, function(a, b) return pathOf(a) < pathOf(b) end)
local index, all, saved, failed = {}, {}, 0, 0
local totalChars = 0
for i, s in ipairs(list) do
    local path = pathOf(s)
    local match = wanted(path)
    index[#index + 1] = (match and "* " or "  ") .. s.ClassName .. " " .. path
    if match then
        local ok, src = pcall(decompile, s)
        if ok and type(src) == "string" and #src > 0 then
            local fname = path:gsub("[^%w%._%-]", "_"):sub(1, 120)
            pcall(writefile, OUT .. "/" .. fname .. ".lua", src)
            if totalChars < 1500000 then
                all[#all + 1] = "\n\n==================== " .. s.ClassName .. " " .. path .. " ====================\n" .. src
                totalChars += #src
            end
            saved += 1
        else
            failed += 1
            index[#index] ..= "   (decompile failed: " .. tostring(src):sub(1, 80) .. ")"
        end
        if i % 5 == 0 then task.wait() end
    end
end
pcall(writefile, OUT .. "/_index.txt", table.concat(index, "\n") .. "\n")
pcall(writefile, OUT .. "/_all.txt", table.concat(all))
local summary = string.format("[DECOMP] %d client scripts found, %d matched and saved, %d failed. Files in %s (_all.txt has the matched sources, %d chars; _index.txt lists everything)",
    #list, saved, failed, OUT, totalChars)
print(summary)
local copy = setclipboard or toclipboard
if copy then pcall(copy, table.concat(index, "\n")) print("[DECOMP] the script index is on your clipboard") end
