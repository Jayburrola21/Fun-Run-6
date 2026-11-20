assert(not game:GetService("RunService"):IsRunning(), "Stop Play first.")
local selection = game:GetService("Selection"):Get()
local curve
for _, item in selection do
    if item:IsA("Model") and item:FindFirstChild("ModularCurveInfillGrout01", true) then
        curve = item
        break
    end
end
curve = curve or assert(workspace:FindFirstChild("Modular 90 degree track curve", true), "Modular curve not found.")
local function role(name)
    name = name:lower():gsub("[^%w]", "")
    if name:find("pavingslate") or name:find("pavingbase") then return "slate" end
    if name:find("pavingdark") then return "dark" end
    if name:find("wallneutral") then return "wall" end
end

local references, scores = {}, {}
for _, part in workspace:GetDescendants() do
    if part:IsA("MeshPart") and not part:IsDescendantOf(curve)
        and not part:FindFirstAncestor("Wide 90 degree track curve") then
        local kind = role(part.Name)
        local parent = part.Parent
        while not kind and parent and parent ~= workspace do
            kind = role(parent.Name)
            parent = parent.Parent
        end
        if kind then
            local score = 0
            if part.TextureID ~= "" or part.MaterialVariant ~= ""
                or part:FindFirstChildOfClass("SurfaceAppearance") then score += 2 end
            for _, source in selection do
                if source ~= curve and (part == source or part:IsDescendantOf(source)) then
                    score += 4
                    break
                end
            end
            if not scores[kind] or score > scores[kind] then
                references[kind], scores[kind] = part, score
            end
        end
    end
end

local helpers = {}
for _, part in curve:GetDescendants() do
    if part:IsA("MeshPart") and part.Name:lower():find("modularcurvecollider", 1, true) then
        table.insert(helpers, part)
    end
end
for _, part in helpers do
    part.Anchored, part.Transparency, part.CastShadow = true, 1, false
    part.CanCollide = #helpers == 60
    part.CanQuery, part.CanTouch = part.CanCollide, false
end

local copied = 0
for _, part in curve:GetDescendants() do
    local kind = part:IsA("MeshPart") and role(part.Name)
    if part:IsA("MeshPart") and part.Name:lower():find("modularcurveinfillgrout", 1, true) then
        for _, child in part:GetChildren() do
            if child:IsA("SurfaceAppearance") then child:Destroy() end
        end
        part.Material, part.MaterialVariant = Enum.Material.SmoothPlastic, ""
        part.Color, part.TextureID = Color3.fromRGB(128, 139, 151), ""
        part.Transparency, part.Reflectance, part.CastShadow = 0, 0, false
        part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
    elseif kind then
        part.Anchored = true
        if #helpers == 60 then part.CanCollide = false end
        local source = references[kind]
        if source then
            local copies = {}
            local function appearance(child)
                return child:IsA("SurfaceAppearance") or child:IsA("Decal")
            end
            for _, child in source:GetChildren() do
                if appearance(child) then table.insert(copies, assert(child:Clone())) end
            end
            part.Material, part.MaterialVariant = source.Material, source.MaterialVariant
            part.Color, part.Reflectance = source.Color, source.Reflectance
            local modern = pcall(function()
                assert(source.TextureContent ~= Content.none)
                part.TextureContent = source.TextureContent
            end)
            if not modern then part.TextureID = source.TextureID end
            for _, child in part:GetChildren() do
                if appearance(child) then child:Destroy() end
            end
            for _, child in copies do child.Parent = part end
            copied += 1
        else
            warn("No original " .. kind .. " reference for " .. part.Name)
        end
    end
end
pcall(function() game:GetService("ChangeHistoryService"):SetWaypoint("Apply curve textures") end)
print("Curve setup finished. Appearance copies:", copied, "Collision helpers:", #helpers)
