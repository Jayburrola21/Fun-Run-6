-- In Roblox Studio Edit mode, select the imported R7 Model in Explorer.
-- Paste this whole file into the Command Bar and run it once.
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")

if RunService:IsRunning() then
    warn("Stop Play mode before applying the R7 finishes.")
    return
end

local function finish(red, green, blue, material, reflectance, transparency)
    return {
        color = Color3.fromRGB(red, green, blue),
        material = material,
        reflectance = reflectance or 0,
        transparency = transparency or 0,
    }
end

local M = Enum.Material
local finishes = {
    paint = finish(23, 26, 32, M.SmoothPlastic, .10),
    paintalt = finish(38, 43, 51, M.SmoothPlastic, .07),
    satin = finish(33, 37, 43, M.SmoothPlastic, .03),
    matte = finish(27, 30, 35, M.Plastic),
    frame = finish(61, 68, 77, M.Metal, .08),
    engine = finish(68, 73, 78, M.Metal, .05),
    alloy = finish(38, 43, 49, M.Metal, .12),
    steel = finish(158, 172, 189, M.Metal, .11),
    rotor = finish(185, 191, 201, M.Metal, .09),
    exhaust = finish(125, 119, 109, M.Metal, .09),
    rubber = finish(29, 30, 32, M.Rubber),
    seat = finish(34, 36, 40, M.Leather),
    smoke = finish(45, 58, 77, M.Glass, .05, .6),
    glass = finish(105, 139, 171, M.Glass, .05, .45),
    white = finish(200, 231, 255, M.Neon),
    red = finish(245, 34, 39, M.Neon),
    amber = finish(237, 135, 34, M.SmoothPlastic, .07),
    redlens = finish(151, 31, 39, M.SmoothPlastic, .09),
    clear = finish(188, 210, 226, M.Glass, .04, .34),
    decal = finish(128, 138, 153, M.SmoothPlastic, .05),
    chrome = finish(201, 214, 226, M.Metal, .19),
    gold = finish(166, 130, 72, M.Metal, .11),
    green = finish(54, 190, 94, M.Neon),
    black = finish(16, 18, 21, M.Plastic),
}

local groups = {
    "body", "frontfairing", "fueltank", "seats", "frontwheel", "rearwheel",
    "frontforks", "brakes", "engine", "frame", "swingarm", "chain", "exhaust",
    "handlebars", "cockpit", "lights", "details",
}

local function namedFinish(name)
    -- Studio may change punctuation or append an index to the source node name.
    local key = name:lower():gsub("[^%w]", ""):gsub("%d+$", ""):gsub("mesh$", ""):gsub("%d+$", "")
    for _, group in groups do
        local prefix = "r7" .. group
        if key:sub(1, #prefix) == prefix then
            return finishes[key:sub(#prefix + 1)]
        end
    end
end

local function hasTexture(object, contentProperty, idProperty)
    local ok, value = pcall(function() return object[contentProperty] end)
    if ok and value and value ~= Content.none and value.Uri ~= "rbxassetid://0" then
        return true
    end
    ok, value = pcall(function() return object[idProperty] end)
    return ok and value and value ~= "" and value ~= "rbxassetid://0"
end

local candidates, seen = {}, {}
local function collect(part)
    if not part:IsA("MeshPart") or seen[part] then
        return
    end
    seen[part] = true
    local style = namedFinish(part.Name)
    if style then
        table.insert(candidates, {part = part, style = style})
    end
end

for _, item in Selection:Get() do
    collect(item)
    if item:IsA("Model") or item:IsA("Folder") then
        for _, child in item:GetDescendants() do
            collect(child)
        end
    end
end

if #candidates == 0 then
    warn("Select the imported R7 Model or its R7 MeshParts in Explorer. Keep the original mesh names during import.")
    return
end

local changed, textured = 0, 0
pcall(function() History:SetWaypoint("Before applying Yamaha R7 finishes") end)
for _, entry in candidates do
    local part, style = entry.part, entry.style
    local surface = part:FindFirstChildOfClass("SurfaceAppearance")
    if hasTexture(part, "TextureContent", "TextureID")
        or (surface and hasTexture(surface, "ColorMapContent", "ColorMap")) then
        textured += 1
        continue
    end

    part.Material = style.material
    part.MaterialVariant = ""
    part.Color = style.color
    part.Reflectance = style.reflectance
    part.Transparency = style.transparency
    if surface then
        surface.Color = style.color
    end
    changed += 1
end

if changed > 0 then
    pcall(function() History:SetWaypoint("Apply Yamaha R7 finishes") end)
end
print(("Yamaha R7: applied finishes to %d mesh parts and preserved %d with color textures."):format(changed, textured))
if textured > 0 then
    warn("If a preserved mesh is still white, check that its color texture loaded. You can run this command on the untextured FBX import for built-in Studio finishes.")
end
