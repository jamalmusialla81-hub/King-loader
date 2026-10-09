-- Blox Strike probe 9: properly decode the game's packed remotes and look for hidden (culled) players in them.
-- Most remotes send:  01 | zstd frame (28 b5 2f fd ...) | serialized table.  Small messages are stored as zstd RAW
-- blocks (no real compression), so they can be unpacked here; truly compressed blocks are skipped and counted.
-- Serialized values seen so far: 06 dict(u32 n, key/value pairs) | 04 string(u32 len) | 03 f64 | 07 Vector3(3 f32)
-- | 0c instance ref (u32 index into the table argument). Unknown types are reported so the decoder can be finished.
-- Checks:
--   * UpdateCameraCFrame: whose UserId is in it, and is that player hidden at the time? (= live camera of hidden enemies)
--   * ReplicateSound (footsteps etc.): position + who made it, and hidden players coming back near a sound
--   * any decoded message naming a hidden player (UserId number, or an instance ref to their character / player)
-- Listen-only, runs 90 s. Result -> console, hub log, king_hub/blox_probe9.txt, clipboard.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer
local out = {}
local function p(s)
    out[#out + 1] = tostring(s); print("[BXP9] " .. tostring(s))
    if shared and shared.MH_Log then pcall(shared.MH_Log, "BXP9 " .. tostring(s)) end
end
local function isCulled(plr)
    local ch = plr.Character
    return ch and ch.Parent and ch.Parent.Name == "_PVS_CulledCharacters"
end
local function rootOf(plr)
    local ch = plr.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end
local function hex(b, from, n)
    local t = {}
    for i = from, math.min(buffer.len(b), from + n) - 1 do t[#t + 1] = string.format("%02x", buffer.readu8(b, i)) end
    return table.concat(t, " ")
end

-- ---------- zstd raw/RLE frame unpacker ----------
local stat = {frames = 0, raw = 0, compressed = 0, notzstd = 0}
local function unzstd(b)
    local len = buffer.len(b)
    if len < 10 or buffer.readu8(b, 0) ~= 1 or buffer.readu32(b, 1) ~= 0xFD2FB528 then stat.notzstd += 1 return nil end
    stat.frames += 1
    local desc = buffer.readu8(b, 5)
    local fcsFlag = bit32.rshift(desc, 6)
    local single = bit32.band(bit32.rshift(desc, 5), 1) == 1
    local dictFlag = bit32.band(desc, 3)
    local pos = 6
    if not single then pos += 1 end
    pos += ({0, 1, 2, 4})[dictFlag + 1]
    local fcsSize = ({single and 1 or 0, 2, 4, 8})[fcsFlag + 1]
    pos += fcsSize
    local parts, total = {}, 0
    while pos + 3 <= len do
        local h = buffer.readu8(b, pos) + buffer.readu8(b, pos + 1) * 256 + buffer.readu8(b, pos + 2) * 65536
        pos += 3
        local last = h % 2 == 1
        local btype = math.floor(h / 2) % 4
        local size = math.floor(h / 8)
        if btype == 0 then
            if pos + size > len then return nil end
            parts[#parts + 1] = {"raw", pos, size}; total += size; pos += size
        elseif btype == 1 then
            parts[#parts + 1] = {"rle", buffer.readu8(b, pos), size}; total += size; pos += 1
        else
            stat.compressed += 1
            return nil
        end
        if last then break end
    end
    local o = buffer.create(total)
    local w = 0
    for _, pt in ipairs(parts) do
        if pt[1] == "raw" then buffer.copy(o, w, b, pt[2], pt[3]) else buffer.fill(o, w, pt[2], pt[3]) end
        w += pt[3]
    end
    stat.raw += 1
    return o
end

-- ---------- serialized table reader ----------
local unknownTypes = {}
local truncated = false          -- hit a value type we can't read yet: keep what was decoded before it
local function readValue(b, i, refs, depth)
    if i >= buffer.len(b) then error("eof") end
    local t = buffer.readu8(b, i); i += 1
    if t == 0x06 then
        local n = buffer.readu32(b, i); i += 4
        if n > 200 then error("bad dict size") end
        local d = {}
        for _ = 1, n do
            local k, v
            k, i = readValue(b, i, refs, depth + 1)
            if truncated then break end
            v, i = readValue(b, i, refs, depth + 1)
            if truncated then d[tostring(k)] = "?"; break end
            d[tostring(k)] = v
        end
        return d, i
    elseif t == 0x04 then
        local n = buffer.readu32(b, i); i += 4
        if n > 4096 then error("bad string size") end
        return buffer.readstring(b, i, n), i + n
    elseif t == 0x03 then
        return buffer.readf64(b, i), i + 8
    elseif t == 0x07 then
        return Vector3.new(buffer.readf32(b, i), buffer.readf32(b, i + 4), buffer.readf32(b, i + 8)), i + 12
    elseif t == 0x0c then
        local idx = buffer.readu32(b, i)
        local inst = type(refs) == "table" and refs[idx] or nil
        return inst or ("ref#" .. idx), i + 4
    else
        local k = string.format("%02x", t)
        if not unknownTypes[k] then unknownTypes[k] = hex(b, i - 1, 60) end
        truncated = true
        return nil, i
    end
end
local function decode(b, refs)
    local raw = unzstd(b)
    if not raw then return nil end
    truncated = false
    local ok, v = pcall(readValue, raw, 0, refs, 0)
    if ok then return v end
    return nil, v
end
local function show(v, depth)
    depth = depth or 0
    local tv = typeof(v)
    if tv == "table" then
        if depth > 2 then return "{...}" end
        local parts = {}
        for k, x in pairs(v) do parts[#parts + 1] = k .. "=" .. show(x, depth + 1) end
        table.sort(parts)
        return "{" .. table.concat(parts, ", ") .. "}"
    elseif tv == "Vector3" then return string.format("V3(%.1f,%.1f,%.1f)", v.X, v.Y, v.Z)
    elseif tv == "Instance" then return v.ClassName .. ":" .. v:GetFullName()
    elseif tv == "number" then return (v == math.floor(v) and string.format("%d", v)) or string.format("%.3f", v)
    else return tostring(v) end
end

-- who does a decoded value point at? (UserId numbers, Player objects, parts of a character)
local function playersIn(v, found, depth)
    found = found or {}
    depth = depth or 0
    local tv = typeof(v)
    if tv == "number" then
        for _, pl in ipairs(Players:GetPlayers()) do if pl.UserId == v then found[pl] = true end end
    elseif tv == "Instance" then
        if v:IsA("Player") then found[v] = true
        else
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl.Character and (v == pl.Character or v:IsDescendantOf(pl.Character)) then found[pl] = true end
            end
        end
    elseif tv == "table" and depth < 4 then
        for _, x in pairs(v) do playersIn(x, found, depth + 1) end
    end
    return found
end
local function vectorsIn(v, list, depth)
    list = list or {}
    depth = depth or 0
    if typeof(v) == "Vector3" then list[#list + 1] = v
    elseif typeof(v) == "CFrame" then list[#list + 1] = v.Position
    elseif typeof(v) == "Instance" and v:IsA("BasePart") then list[#list + 1] = v.Position
    elseif type(v) == "table" and depth < 4 then for _, x in pairs(v) do vectorsIn(x, list, depth + 1) end end
    return list
end

-- ---------- listen ----------
local samples, decodedCount, failCount, failWhy = {}, {}, {}, {}
local namesHidden, namesVisible = {}, {}
local camWho = {}            -- UpdateCameraCFrame: player name -> {hidden, visible}
local recent = {}            -- positional signals: {t, pos, src}
local conns = {}
local function watch(r)
    if r.Name == "RemoteSnapshot" then return end
    conns[#conns + 1] = r.OnClientEvent:Connect(function(b, refs)
        if typeof(b) ~= "buffer" then return end
        local src = r.Name
        local v, err = decode(b, refs)
        if v == nil then
            if err then failCount[src] = (failCount[src] or 0) + 1; failWhy[src] = tostring(err) end
            return
        end
        decodedCount[src] = (decodedCount[src] or 0) + 1
        samples[src] = samples[src] or {}
        if #samples[src] < 2 then samples[src][#samples[src] + 1] = show(v) end
        local who = playersIn(v)
        for pl in pairs(who) do
            if pl ~= lp then
                if isCulled(pl) then namesHidden[src] = (namesHidden[src] or 0) + 1
                else namesVisible[src] = (namesVisible[src] or 0) + 1 end
                if src == "UpdateCameraCFrame" then
                    local c = camWho[pl.Name] or {hidden = 0, visible = 0}
                    if isCulled(pl) then c.hidden += 1 else c.visible += 1 end
                    camWho[pl.Name] = c
                end
            end
        end
        local now = os.clock()
        for _, pos in ipairs(vectorsIn(v)) do
            table.insert(recent, {t = now, pos = pos, src = src})
        end
        while #recent > 3000 do table.remove(recent, 1) end
    end)
end
for _, d in ipairs(RS:GetDescendants()) do
    if d:IsA("RemoteEvent") or d:IsA("UnreliableRemoteEvent") then watch(d) end
end

-- hidden player comes back: decoded positions near them while they were still hidden
local wasCulled, culledAt = {}, {}
local longHides, hits, hitBySrc = 0, 0, {}
conns[#conns + 1] = RunService.Heartbeat:Connect(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and plr.Character then
            local c = isCulled(plr)
            if c and not wasCulled[plr] then culledAt[plr] = os.clock() end
            if wasCulled[plr] and not c then
                local since, back = culledAt[plr] or 0, os.clock()
                if back - since >= 1.5 then
                    task.delay(0.15, function()
                        local hrp = rootOf(plr)
                        if not hrp then return end
                        local real = hrp.Position
                        local best, bestSrc, bestAge
                        for _, e in ipairs(recent) do
                            if e.t > since + 0.3 and e.t < back - 0.5 and back - e.t < 3 then
                                local d = (e.pos - real).Magnitude
                                if not best or d < best then best, bestSrc, bestAge = d, e.src, back - e.t end
                            end
                        end
                        longHides += 1
                        local ok = best and best < 10
                        if ok then hits += 1; hitBySrc[bestSrc] = (hitBySrc[bestSrc] or 0) + 1 end
                        p(string.format("%s back after %.1fs hidden: nearest decoded position while hidden = %s %s", plr.Name, back - since,
                            best and string.format("%.1f studs (%s, %.1fs before)", best, bestSrc, bestAge) or "none", ok and "=> LIVE SIGNAL" or ""))
                    end)
                end
            end
            wasCulled[plr] = c
        end
    end
end)

p("listening for 90 s - play a normal round; running enemies out of sight matter most")
for i = 1, 9 do
    task.wait(10)
    print(string.format("[BXP9] %ds... long hides: %d, decoded signal near them: %d", i * 10, longHides, hits))
end
for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
task.wait(0.3)

p(string.format("frames: %d zstd, %d unpacked, %d truly compressed (skipped), %d other formats", stat.frames, stat.raw, stat.compressed, stat.notzstd))
for src, list in pairs(samples) do p(string.format("decoded %s x%d: %s", src, decodedCount[src] or 0, table.concat(list, "  ||  "))) end
for src, n in pairs(failCount) do p(string.format("decode failed %s x%d: %s", src, n, failWhy[src])) end
for k, h in pairs(unknownTypes) do p("unknown value type " .. k .. ": " .. h) end
local nh = {}
for src, n in pairs(namesHidden) do nh[#nh + 1] = string.format("%s x%d (visible x%d)", src, n, namesVisible[src] or 0) end
p("messages naming a HIDDEN player: " .. (#nh > 0 and table.concat(nh, " | ") or "none"))
local nv = {}
for src, n in pairs(namesVisible) do if not namesHidden[src] then nv[#nv + 1] = src .. " x" .. n end end
p("messages naming only visible players: " .. (#nv > 0 and table.concat(nv, ", ") or "none"))
local cw = {}
for name, c in pairs(camWho) do cw[#cw + 1] = string.format("%s hidden x%d visible x%d", name, c.hidden, c.visible) end
p("UpdateCameraCFrame is about: " .. (#cw > 0 and table.concat(cw, " | ") or "nobody else (only you?)"))
local hb = {}
for src, n in pairs(hitBySrc) do hb[#hb + 1] = src .. " x" .. n end
p("live matches by remote: " .. (#hb > 0 and table.concat(hb, ", ") or "none"))
p(string.format("RESULT: %d long hides, %d had a decoded position near the comeback spot", longHides, hits))
pcall(function() if makefolder and not isfolder("king_hub") then makefolder("king_hub") end end)
pcall(writefile, "king_hub/blox_probe9.txt", table.concat(out, "\n") .. "\n")
p("done")
local copy = setclipboard or toclipboard or (syn and syn.write_clipboard)
if copy then pcall(copy, table.concat(out, "\n")); print("[BXP9] copied to clipboard - just paste it") end
