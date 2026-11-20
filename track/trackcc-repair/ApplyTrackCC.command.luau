-- Paste in the Studio Command Bar in Edit mode after importing TrackCC Repaired.
-- Select the restored model to scope changes and optionally select an original reference.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play and rerun.")
local selection = game:GetService("Selection"):Get()

local function role(key)
    if key:find("pavingslate") or key:find("pavingbase") then return "slate" end
    if key:find("pavingdark") then return "dark" end
    if key:find("wallneutral") then return "wall" end
end

local function classify(part)
    local kind, original, tag
    local node = part
    while node and node ~= workspace do
        local key = node.Name:lower():gsub("[^%w]", "")
        local found = role(key)
        kind = kind or found
        if node:IsA("Model") and key:match("^trackccrepaired") then
            return node, kind
        end
        if key:match("^trackcc") and found then
            tag = tag or node
        end
        if found and (key:match("^bend") or key:match("^straight")) then
            original = original or key
        end
        node = node.Parent
    end
    if tag then
        return tag:FindFirstAncestorOfClass("Model") or tag, kind
    end
    return nil, kind, original
end

local function isSelected(part)
    for _, selected in selection do
        if selected == part or part:IsDescendantOf(selected) then return true end
    end
    return false
end

local canonical = {
    bendpavingslate02 = true, bendpavingdark01 = true, bendwallneutral01 = true,
    straightpavingslatemeshesfloorssmenvtiles01011 = true,
    straightpavingdarkmeshesfloorssmenvtiles0111 = true, straightwallneutral03 = true,
}
local targets, sources, ranks = {}, {}, {}
local selectedTarget = false
for _, part in workspace:GetDescendants() do
    if not part:IsA("MeshPart") then continue end
    local model, kind, original = classify(part)
    if model then
        local group = targets[model] or {}
        targets[model] = group
        table.insert(group, {part = part, kind = kind})
        group.selected = group.selected or isSelected(part)
        selectedTarget = selectedTarget or group.selected
    elseif original then
        local rank = if isSelected(part) then 4 else 0
        if part.TextureID ~= "" or part:FindFirstChildOfClass("SurfaceAppearance") or part.MaterialVariant ~= "" then
            rank += 2
        end
        if canonical[original] or canonical[original:gsub("1$", "")] then rank += 1 end
        if not ranks[kind] or rank > ranks[kind] then
            ranks[kind], sources[kind] = rank, part
        end
    end
end
assert(next(targets), "Import TrackCC Repaired as a Model with separate MeshParts first.")

local function copyAppearance(part, source)
    local surface = source:FindFirstChildOfClass("SurfaceAppearance")
    local clone = surface and surface:Clone()
    if surface and not clone then return false end
    local ok = pcall(function() part.TextureContent = source.TextureContent end)
    if not ok then part.TextureID = source.TextureID end
    part.Material = source.Material
    part.MaterialVariant = source.MaterialVariant
    part.Color = source.Color
    part.Reflectance = source.Reflectance
    part.Transparency = source.Transparency
    for _, child in part:GetChildren() do
        if child:IsA("SurfaceAppearance") then child:Destroy() end
    end
    if clone then clone.Parent = part end
    return true
end

local anchored, copied = 0, 0
local skipped = {}
for _, group in targets do
    if selectedTarget and not group.selected then continue end
    for _, target in ipairs(group) do
        local part, kind = target.part, target.kind
        part.Anchored = true
        anchored += 1
        if kind then
            local source = sources[kind]
            if source and copyAppearance(part, source) then
                copied += 1
            else
                skipped[kind] = true
            end
        end
    end
end
pcall(function() game:GetService("ChangeHistoryService"):SetWaypoint("Set up TrackCC") end)
print(("Anchored %d TrackCC meshes and copied appearance to %d."):format(anchored, copied))
for _, kind in {"slate", "dark", "wall"} do
    if skipped[kind] then
        warn(("Kept imported %s appearance. No copyable original reference was found."):format(kind))
    end
end
