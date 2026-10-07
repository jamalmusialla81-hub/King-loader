-- Captures every script MonkeHub loads (saved into king_hub/scripts/), then opens MonkeHub itself.
-- Pick each game one at a time in MonkeHub; the scripts it loads are saved as monkehub_NN_*.lua.
-- Files marked _protected are obfuscated: they still run from MY SCRIPTS, they just can't be read.
pcall(function() if not isfolder("king_hub") then makefolder("king_hub") end end)
pcall(function() if not isfolder("king_hub/scripts") then makefolder("king_hub/scripts") end end)

local genv = getgenv and getgenv() or _G
if genv.KING_CAPTURE_ACTIVE then
    print("[capture] already running, just opening MonkeHub")
else
    genv.KING_CAPTURE_ACTIVE = true
    local n, seen = 0, {}
    local function looksProtected(src)
        local head = src:sub(1, 600)
        return head:find("Luraph", 1, true) or head:find("protected using", 1, true)
            or head:find("\\%d%d%d\\%d%d%d") or head:find("return%(function%(")
    end
    local function save(src, tag)
        if type(src) ~= "string" or #src < 1500 or seen[src] then return end
        seen[src] = true
        n += 1
        local name = string.format("king_hub/scripts/monkehub_%02d_%s_%dKB%s.lua", n, tag, math.floor(#src / 1024), looksProtected(src) and "_protected" or "")
        pcall(writefile, name, src)
        print("[capture] saved " .. name)
    end

    local realLoad = loadstring
    genv.loadstring = function(src, ...)
        save(src, "loadstring")
        return realLoad(src, ...)
    end

    local okHook, err = pcall(function()
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if method == "HttpGet" or method == "HttpGetAsync" then
                local res = oldNamecall(self, ...)
                save(res, "httpget")
                return res
            end
            return oldNamecall(self, ...)
        end))
    end)
    if not okHook then warn("[capture] HttpGet hook failed (loadstring capture still works): " .. tostring(err)) end
end

print("[capture] running. Opening MonkeHub...")
loadstring(game:HttpGet("https://pastefy.app/HKWHfFz3/raw"))()
