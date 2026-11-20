-- Paste in the Studio Command Bar with Play stopped after importing Drift Circuit.
-- Select an original track model to give its appearance priority.
do
    assert(not game:GetService("RunService"):IsRunning(), "Stop Play and rerun.")
    local selection = game:GetService("Selection"):Get()

    local function role(key)
        if key:find("pavingslate") or key:find("pavingbase") then return "slate" end
        if key:find("pavingdark") then return "dark" end
        if key:find("wallneutral") then return "wall" end
    end

    local function classify(part)
        local kind, tag, original
        local node = part
        while node and node ~= workspace do
            local key = node.Name:lower():gsub("[^%w]", "")
            if key:find("collider") or key:find("checkpoint") then return end
            kind = kind or role(key)
            if key:match("^driftcircuit") then
                if node:IsA("Model") and key:match("^driftcircuit%d*$") then
                    if kind then return node, kind end
                    return
                end
                if kind then tag = tag or node end
            elseif kind and not original then
                if key:match("^bend") or key:match("^straightpaving") or key:match("^straightwall") then
                    original = 2
                elseif key:match("^straightkit") or key:match("^modularcurve") or key:match("^trackcc") then
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

    local targets, sources, ranks = {}, {}, {}
    local selectedTarget
    for _, part in workspace:GetDescendants() do
        if not part:IsA("MeshPart") then continue end
        local model, kind, original = classify(part)
        if model then
            local group = targets[model] or {}
            targets[model] = group
            group[part] = kind
            if active(part) then selectedTarget = true end
        elseif original then
            local rank = original
            if active(part) then rank += 8 end
            if part.TextureID ~= "" or part:FindFirstChildOfClass("SurfaceAppearance") or part.MaterialVariant ~= "" then
                rank += 4
            end
            if not ranks[kind] or rank > ranks[kind] then sources[kind], ranks[kind] = part, rank end
        end
    end
    assert(next(targets), "Import Drift Circuit with separate meshes first.")

    local function copyAppearance(part, source)
        local surface = source:FindFirstChildOfClass("SurfaceAppearance")
        local clone = surface and surface:Clone()
        if surface and not clone then return false end
        local textureID = source.TextureID
        local ok = pcall(function()
            local texture = source.TextureContent
            if texture == Content.none and textureID ~= "" then
                part.TextureID = textureID
            else
                part.TextureContent = texture
            end
        end)
        if not ok then part.TextureID = textureID end
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
        if selectedTarget then
            local useGroup = active(model)
            for part in group do
                if active(part) then useGroup = true break end
            end
            if not useGroup then continue end
        end
        for part, kind in group do
            if sources[kind] and copyAppearance(part, sources[kind]) then
                copied += 1
            else
                missing[kind] = true
            end
        end
    end
    if copied > 0 then
        pcall(function() game:GetService("ChangeHistoryService"):SetWaypoint("Match Drift Circuit appearance") end)
    end
    print(("Drift Circuit: copied appearance to %d meshes."):format(copied))
    for kind in missing do
        warn(("Kept the imported %s appearance. No copyable original was found."):format(kind))
    end
end
