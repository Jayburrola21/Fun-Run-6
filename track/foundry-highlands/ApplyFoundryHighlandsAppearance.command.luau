-- Paste in the Studio Command Bar with Play stopped after importing Foundry Highlands.
-- Select an original track model to give its appearance priority.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play and rerun.")
local selection = game:GetService("Selection"):Get()
local function role(key)
    if key:find("pavingbase") then return "base" end
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
    while node ~= workspace do
        local key = node.Name:lower():gsub("[^%w]", "")
        if key:find("collider") or key:find("checkpoint") then return end
        if (key:find("mortar") or key:find("deckbase")) and not key:find("pavingbase") then return end
        local found = role(key)
        kind = if found == "base" then found else kind or found
        if key:match("^foundryhighlands") then
            local namedRoot = key:match("^foundryhighlands%d*$") or key:match("^foundryhighlandstight%d*$")
            if node:IsA("Model") and namedRoot then return node, kind end
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
    elseif original and kind ~= "base" then
        local rank = original
        if active(part) then rank += 8 end
        if part.TextureID ~= "" or part:FindFirstChildOfClass("SurfaceAppearance") then rank += 4 end
        if not ranks[kind] or rank > ranks[kind] then sources[kind], ranks[kind] = part, rank end
    end
end
assert(next(targets), "Import Foundry Highlands with separate meshes first.")
local function hasGroutTexture(source)
    if not source then return false end
    local surface = source:FindFirstChildOfClass("SurfaceAppearance")
    if surface and surface.Archivable == false then return false end
    local ok, uri = pcall(function()
        local content = if surface then surface.ColorMapContent else source.TextureContent
        return content.Uri
    end)
    if ok and uri and uri ~= "" and uri ~= "rbxassetid://0" then return true end
    ok, uri = pcall(function() return if surface then surface.ColorMap else source.TextureID end)
    return ok and uri and uri ~= "" and uri ~= "rbxassetid://0"
end
local function applyAppearance(part, source, base)
    local clone
    if source then
        local surface = source:FindFirstChildOfClass("SurfaceAppearance")
        clone = surface and surface:Clone()
        if surface and not clone then return false end
        if source.TextureID ~= "" or not pcall(function() part.TextureContent = source.TextureContent end) then
            part.TextureID = source.TextureID
        end
        part.Material, part.MaterialVariant = source.Material, source.MaterialVariant
        part.Color, part.Reflectance, part.Transparency = source.Color, source.Reflectance, source.Transparency
        if base then part.Transparency = 0 end
        if clone and base then
            clone.AlphaMode = Enum.AlphaMode.Overlay
            part.Color = Color3.fromRGB(136, 147, 158)
        end
    else
        part.TextureID = ""
        pcall(function() part.TextureContent = Content.none end)
        part.Material, part.MaterialVariant = Enum.Material.SmoothPlastic, ""
        part.Color = Color3.fromRGB(136, 147, 158)
        part.Reflectance, part.Transparency = 0, 0
    end
    for _, child in part:GetChildren() do
        if child:IsA("SurfaceAppearance") then child:Destroy() end
    end
    if clone then clone.Parent = part end
    return true
end
local copied, texturedBase, tintedBase = 0, 0, 0
local missing = {}
local groutSource = if hasGroutTexture(sources.slate) then sources.slate else nil
for model, group in targets do
    if next(selectedModels) and not selectedModels[model] then continue end
    for part, kind in group do
        local source = if kind == "base" then groutSource else sources[kind]
        if source and applyAppearance(part, source, kind == "base") then
            if kind == "base" then texturedBase += 1 else copied += 1 end
        elseif kind == "base" then
            applyAppearance(part, nil)
            tintedBase += 1
        else
            missing[kind] = true
        end
    end
end
pcall(function() game:GetService("ChangeHistoryService"):SetWaypoint("Match track appearance") end)
print(("Copied %d paving and wall appearances, textured %d mortar meshes, tinted %d gray."):format(
    copied, texturedBase, tintedBase))
for kind in missing do warn("No original reference for " .. kind .. ".") end
