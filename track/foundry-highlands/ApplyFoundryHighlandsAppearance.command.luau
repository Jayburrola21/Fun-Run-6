-- Paste in the Studio Command Bar with Play stopped after importing Foundry Highlands.
-- Select an original track model to give its appearance priority.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play and rerun.")
local selection = game:GetService("Selection"):Get()

local function role(key)
    if key:find("pavingslate") then return "slate" end
    if key:find("pavingdark") then return "dark" end
    if key:find("wallneutral") then return "wall" end
end
local canonical = {
    bendpavingslate02 = true, bendpavingdark01 = true, bendwallneutral01 = true,
    straightpavingslatemeshesfloorssmenvtiles01011 = true,
    straightpavingdarkmeshesfloorssmenvtiles0111 = true,
    straightwallneutral03 = true,
}
local function classify(part)
    local kind, tag, original
    local node = part
    while node and node ~= workspace do
        local key = node.Name:lower():gsub("[^%w]", "")
        if key:find("collider") or key:find("checkpoint") or key:find("mortar")
            or key:find("deckbase") or key:find("pavingbase") then return end
        kind = kind or role(key)
        if key:match("^foundryhighlands") then
            if node:IsA("Model") and key:match("^foundryhighlands%d*$") then return node, kind end
            if kind then tag = tag or node end
        elseif kind and not original then
            if key:match("^bend") or key:match("^straightpaving") or key:match("^straightwall") then
                original = if canonical[key] or canonical[key:gsub("1$", "")] then 3 else 2
            elseif key:match("^straightkit") or key:match("^modularcurve")
                or key:match("^trackcc") or key:match("^driftcircuit") then
                original = 1
            end
        end
        node = node.Parent
    end
    if tag then return tag:FindFirstAncestorOfClass("Model") or tag, kind end
    return nil, kind, original
end

local function active(part)
    for _, item in selection do
        if item == part or part:IsDescendantOf(item) then return true end
    end
    return false
end

local targets, sources, ranks, selectedModels = {}, {}, {}, {}
for _, part in workspace:GetDescendants() do
    if not part:IsA("MeshPart") then continue end
    local model, kind, original = classify(part)
    if not kind then continue end
    if model then
        targets[model] = targets[model] or {}
        targets[model][part] = kind
        if active(part) then selectedModels[model] = true end
    elseif original then
        local rank = original
        if active(part) then rank += 8 end
        if part.TextureID ~= "" or part:FindFirstChildOfClass("SurfaceAppearance") or part.MaterialVariant ~= "" then
            rank += 4
        end
        if not ranks[kind] or rank > ranks[kind] then sources[kind], ranks[kind] = part, rank end
    end
end
assert(next(targets), "Import Foundry Highlands with separate meshes first.")

local function copyAppearance(part, source)
    local surface = source:FindFirstChildOfClass("SurfaceAppearance")
    local clone = surface and surface:Clone()
    if surface and not clone then return false end
    if source.TextureID ~= "" then
        part.TextureID = source.TextureID
    elseif not pcall(function() part.TextureContent = source.TextureContent end) then
        part.TextureID = ""
    end
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

local copied = 0
local missing = {}
for model, group in targets do
    if next(selectedModels) and not selectedModels[model] then continue end
    for part, kind in group do
        if sources[kind] and copyAppearance(part, sources[kind]) then
            copied += 1
        else
            missing[kind] = true
        end
    end
end
if copied > 0 then
    pcall(function() game:GetService("ChangeHistoryService"):SetWaypoint("Match track appearance") end)
end
print(("Copied appearance to %d Foundry Highlands meshes."):format(copied))
for kind in missing do warn("No original reference for " .. kind .. ".") end
