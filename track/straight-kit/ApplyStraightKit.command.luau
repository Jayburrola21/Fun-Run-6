-- Edit mode. Select kit models and optionally the original straight.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play and rerun.")
local selected = game:GetService("Selection"):Get()

local function role(key)
    if key:find("pavingslate") or key:find("pavingbase") then return "slate" end
    if key:find("pavingdark") then return "dark" end
    if key:find("wallneutral") then return "wall" end
    return key:match("straightkitcollider(%a+)")
end

local function identify(part)
    local kind, tagged
    local node = part
    while node and node ~= workspace do
        local key = node.Name:lower():gsub("[^%w]", "")
        kind = kind or role(key)
        if key:find("straightkit") then
            tagged = tagged or node
            if kind and node:IsA("Model") and key:match("^straightkitstraight0[1-6]") then
                return kind, node
            end
        end
        node = node.Parent
    end
    if kind and tagged then return kind, tagged:FindFirstAncestorOfClass("Model") or tagged end
    return kind
end

local pieces, sources = {}, {}
local anySelected
local colliderRoles = { deck = true, innerwall = true, outerwall = true }
local function selectedPart(part)
    for _, item in selected do
        if item == part or part:IsDescendantOf(item) then return true end
    end
    return false
end

for _, part in workspace:GetDescendants() do
    if not part:IsA("MeshPart") then continue end
    local kind, model = identify(part)
    if not kind then continue end
    local active = selectedPart(part)
    if model then
        local piece = pieces[model] or { visuals = {}, colliders = {} }
        pieces[model] = piece
        piece.selected = piece.selected or active
        anySelected = anySelected or active
        if colliderRoles[kind] then
            piece.colliders[part] = kind
        else
            piece.visuals[part] = kind
        end
    elseif active and not sources[kind] then
        sources[kind] = part
    end
end
assert(next(pieces), "Import a StraightKit GLB first.")

local function copyAppearance(part, source)
    local surface = source:FindFirstChildOfClass("SurfaceAppearance")
    local clone = surface and surface:Clone()
    if surface and not clone then return false end
    local ok = pcall(function()
        local content = source.TextureContent
        assert(content ~= Content.none or source.TextureID == "")
        part.TextureContent = content
    end)
    if not ok then part.TextureID = source.TextureID end
    part.Color = source.Color
    part.Material = source.Material
    part.MaterialVariant = source.MaterialVariant
    part.Reflectance = source.Reflectance
    part.Transparency = source.Transparency
    for _, child in part:GetChildren() do
        if child:IsA("SurfaceAppearance") then child:Destroy() end
    end
    if clone then clone.Parent = part end
    return true
end

local pieceCount, copied, incomplete = 0, 0, 0
for _, piece in pieces do
    if anySelected and not piece.selected then continue end
    pieceCount += 1
    local seen, count = {}, 0
    for _, kind in piece.colliders do
        seen[kind] = true
        count += 1
    end
    local complete = count == 3 and seen.deck and seen.innerwall and seen.outerwall or false
    if not complete then incomplete += 1 end
    for part in piece.colliders do
        part.Anchored = true
        part.CanCollide = complete
        part.CanQuery = complete
        part.CanTouch = false
        part.Transparency = 1
        part.CastShadow = false
    end
    for part, kind in piece.visuals do
        part.Anchored = true
        if complete then
            part.CanCollide = false
            part.CanQuery = false
            part.CanTouch = false
        end
        local source = sources[kind]
        if source and copyAppearance(part, source) then copied += 1 end
    end
end
pcall(function() game:GetService("ChangeHistoryService"):SetWaypoint("Set up track kit") end)
print(("Prepared %d kits and copied %d appearances."):format(pieceCount, copied))
if incomplete > 0 then
    warn(("%d kits kept visual collision because helpers were incomplete."):format(incomplete))
end
