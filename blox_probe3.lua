-- Blox Strike probe 3: what does MovementV2Remotes.RemoteSnapshot carry? Listen-only: connects a read-only handler, sends nothing, hooks nothing.
-- Run while ALIVE in a live round (not spectating). Result goes to the console, king_hub/hub_log.txt, king_hub/blox_probe3.txt and the clipboard.
local RS = game:GetService("ReplicatedStorage")
local out = {}
local function p(s)
    out[#out + 1] = tostring(s); print("[BXP3] " .. tostring(s))
    if shared and shared.MH_Log then pcall(shared.MH_Log, "BXP3 " .. tostring(s)) end
end
local function fmt(v, d)
    d = d or 0
    local t = typeof(v)
    if t == "Vector3" then return string.format("V3(%.1f,%.1f,%.1f)", v.X, v.Y, v.Z) end
    if t == "CFrame" then local x, y, z = v.X, v.Y, v.Z return string.format("CF(%.1f,%.1f,%.1f)", x, y, z) end
    if t == "number" then return string.format("%.3f", v) end
    if t == "string" then return '"' .. v:sub(1, 40) .. '"' end
    if t == "Instance" then return "Inst(" .. v.ClassName .. ":" .. v.Name .. ")" end
    if t == "buffer" then return "buffer(" .. buffer.len(v) .. " bytes)" end
    if t == "table" then
        if d >= 2 then return "{...}" end
        local parts, n = {}, 0
        for k, x in pairs(v) do n += 1 if n <= 8 then parts[#parts + 1] = tostring(k) .. "=" .. fmt(x, d + 1) end end
        return "{" .. table.concat(parts, ", ") .. (n > 8 and (", ... (" .. n .. " entries)") or "") .. "}"
    end
    return t .. ":" .. tostring(v):sub(1, 30)
end
local folder = RS:FindFirstChild("MovementV2Remotes")
if not folder then p("no ReplicatedStorage.MovementV2Remotes found") else
    local names = {}
    for _, c in ipairs(folder:GetChildren()) do names[#names + 1] = c.Name .. "(" .. c.ClassName .. ")" end
    p("MovementV2Remotes contains: " .. table.concat(names, ", "))
    local function listen(remName)
        local rem = folder:FindFirstChild(remName)
        if not (rem and (rem:IsA("RemoteEvent") or rem:IsA("UnreliableRemoteEvent"))) then p(remName .. " missing or not a remote: " .. tostring(rem and rem.ClassName)) return nil end
        local st = {shown = 0, total = 0, t0 = os.clock(), name = remName}
        st.conn = rem.OnClientEvent:Connect(function(...)
            st.total += 1
            if st.shown < 6 then
                st.shown += 1
                local a = {}
                for i = 1, select("#", ...) do a[i] = fmt((select(i, ...))) end
                p(string.format("%s event %d args(%d): %s", remName, st.shown, select("#", ...), table.concat(a, " | ")))
            end
        end)
        return st
    end
    local watchers = {}
    for _, n in ipairs({"RemoteSnapshot", "OwnerSnapshot"}) do local w = listen(n) if w then watchers[#watchers + 1] = w end end
    task.wait(4)
    for _, st in ipairs(watchers) do
        st.conn:Disconnect()
        p(string.format("%s: received %d events in %.1fs (%.1f/s)", st.name, st.total, os.clock() - st.t0, st.total / (os.clock() - st.t0)))
    end
end
pcall(function() if makefolder and not isfolder("king_hub") then makefolder("king_hub") end end)
pcall(writefile, "king_hub/blox_probe3.txt", table.concat(out, "\n") .. "\n")
p("done")
local copy = setclipboard or toclipboard or (syn and syn.write_clipboard)
if copy then pcall(copy, table.concat(out, "\n")); print("[BXP3] copied to clipboard - just paste it") end
