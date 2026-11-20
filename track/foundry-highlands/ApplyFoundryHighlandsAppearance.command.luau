-- In Edit mode, select only the newly imported Foundry Highlands Model.
-- Keep the previous textured track in Workspace as a reference.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play and rerun.")
local selection = game:GetService("Selection"):Get()
local selected = selection[1]
local gray = Color3.fromRGB(136, 147, 158)

local function classify(part)
    local role, tagged, model, priority
    local node = part
    while node ~= workspace do
        local key = node.Name:lower():gsub("[^%w]", "")
        if key:find("collider") or key:find("checkpoint") then return end
        if key:find("pavingbase") then role = "base" end
        if not role then
            if key:find("pavingslate") then role = "slate"
            elseif key:find("pavingdark") then role = "dark"
            elseif key:find("wallneutral") then role = "wall" end
        end
        if key:match("^foundryhighlands") then
            if role then tagged = tagged or node end
            local rootName = key:match("^foundryhighlands%d*$") or key:match("^foundryhighlandstight%d*$")
            if node:IsA("Model") and rootName then model = model or node end
        elseif not priority and role then
            if key:match("^bend") or key:match("^straightpaving") or key:match("^straightwall") then
                priority = 2
            elseif key:match("^straightkit") or key:match("^modularcurve")
                or key:match("^trackcc") or key:match("^driftcircuit") then
                priority = 1
            end
        end
        node = node.Parent
    end
    if tagged and not model then model = tagged:FindFirstAncestorOfClass("Model") end
    return role, model, priority
end

local function usableURI(uri)
    return type(uri) == "string" and uri ~= "" and uri ~= "rbxassetid://0"
end

local function readURI(object, modern, legacy)
    local ok, uri = pcall(function() return object[modern].Uri end)
    if ok and usableURI(uri) then return uri end
    ok, uri = pcall(function() return object[legacy] end)
    if ok and usableURI(uri) then return uri end
end

local records, models = {}, {}
for _, part in workspace:GetDescendants() do
    if not part:IsA("MeshPart") then continue end
    local role, model, priority = classify(part)
    if role then table.insert(records, {part = part, role = role, model = model, priority = priority}) end
    if role and model then models[model] = true end
end

local target = models[selected] and selected
if not target then
    local candidate = next(models)
    if candidate and not next(models, candidate) then target = candidate end
end
if not target or #selection > 1 then
    warn("Select only the new Foundry Highlands Model in Explorer and rerun.")
    return
end

local sources, ranks = {}, {}
for _, record in records do
    local part, role = record.part, record.role
    if role == "base" or part:IsDescendantOf(target) then continue end
    local rank = record.model and 3 or record.priority
    if selected and (part == selected or part:IsDescendantOf(selected)) then rank = (rank or 0) + 8 end
    if not rank then continue end
    local surface = part:FindFirstChildOfClass("SurfaceAppearance")
    local map
    if surface and surface.Archivable ~= false then map = readURI(surface, "ColorMapContent", "ColorMap") end
    local texture = readURI(part, "TextureContent", "TextureID")
    if map or texture then rank += 4
    elseif part.MaterialVariant == "" then continue end
    if not ranks[role] or rank > ranks[role] then
        ranks[role] = rank
        sources[role] = {part = part, surface = map and surface, texture = texture, mapped = map or texture}
    end
end
if not next(sources) then
    warn("No usable texture reference found. Keep the previous textured Highlands or original track in Workspace.")
    return
end

local function apply(part, source, base)
    local clone = source and source.surface and source.surface:Clone()
    if source and source.surface and not clone then return false end
    local visual = source and source.part
    part.TextureID = source and source.texture or ""
    part.Material = visual and visual.Material or Enum.Material.SmoothPlastic
    part.MaterialVariant = visual and visual.MaterialVariant or ""
    part.Color = visual and visual.Color or gray
    part.Reflectance = visual and visual.Reflectance or 0
    part.Transparency = visual and visual.Transparency or 0
    if base then
        part.Transparency = 0
        if clone then clone.AlphaMode, part.Color = Enum.AlphaMode.Overlay, gray end
    end
    for _, child in part:GetChildren() do
        if child:IsA("SurfaceAppearance") then child:Destroy() end
    end
    if clone then clone.Parent = part end
    return true
end

local copied, texturedBase, tintedBase = 0, 0, 0
local missing, bases = {}, {}
for _, record in records do
    local part, role = record.part, record.role
    if not part:IsDescendantOf(target) then continue end
    if role == "base" then table.insert(bases, part)
    elseif sources[role] and apply(part, sources[role]) then copied += 1
    else missing[role] = true end
end
local slate = sources.slate
if copied > 0 and slate then
    for _, part in bases do
        if slate.mapped and apply(part, slate, true) then texturedBase += 1
        else
            apply(part, nil, true)
            tintedBase += 1
        end
    end
end
if copied > 0 then
    pcall(function() game:GetService("ChangeHistoryService"):SetWaypoint("Match track appearance") end)
end
print(("Copied %d paving and wall appearances, textured %d mortar meshes, tinted %d gray."):format(
    copied, texturedBase, tintedBase))
for role in missing do warn("No usable texture reference for " .. role .. ".") end
