-- Paste the entire file into the Studio Command Bar while stopped.
-- Select the imported modular curve Model. To copy appearance, also select
-- an original track Model or its individual reference MeshParts.
-- For originals with generic names, select the curve and the following MeshParts
-- and fill in their exact Explorer names below.
local sourceNames = {
    -- slate = "Original slate MeshPart",
    -- dark = "Original dark MeshPart",
    -- wall = "Original wall MeshPart",
}

local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before setting up the curve.")

local roles = { "slate", "dark", "wall" }
local displayName = { slate = "slate paving", dark = "dark paving", wall = "neutral wall" }
local modularPrefix = "modularcurve"
local modelName = "modular90degreetrackcurve"
local exactSourceNames = {
    slate = { "bendpavingslate021", "straightpavingslatemeshesfloorssmenvtiles010111" },
    dark = { "bendpavingdark011", "straightpavingdarkmeshesfloorssmenvtiles01111" },
    wall = { "bendwallneutral011", "straightwallneutral031" },
}

local function nameKey(name)
    return (name:lower():gsub("[^%w]", ""))
end

local function contains(name, word)
    return name:find(word, 1, true) ~= nil
end

local function isModularPart(part)
    return part:IsA("MeshPart") and contains(nameKey(part.Name), modularPrefix)
end

local function namedRole(name)
    if contains(name, "pavingslate") or contains(name, "slatepaving") then
        return "slate"
    elseif contains(name, "pavingdark") or contains(name, "darkpaving") then
        return "dark"
    elseif contains(name, "wallneutral") or contains(name, "neutralwall") then
        return "wall"
    end
end

local function targetRole(part)
    local name = nameKey(part.Name)
    if contains(name, "modularcurvecollider") then return nil end
    if contains(name, "pavingbase") then return "slate" end
    return namedRole(name)
end

local function isTargetModel(object)
    if not object:IsA("Model") then return false end
    for _, part in object:GetDescendants() do
        if isModularPart(part) and targetRole(part) then return true end
    end
    return false
end

local function addUnique(list, seen, object)
    if seen[object] then return end
    seen[object] = true
    table.insert(list, object)
end

local selection = Selection:Get()
local targets = {}
local seenTargets = {}
for _, object in selection do
    if isTargetModel(object) then
        addUnique(targets, seenTargets, object)
    end
end

local objects = workspace:GetDescendants()
if #targets == 0 then
    for _, object in objects do
        if object:IsA("Model") and nameKey(object.Name) == modelName and isTargetModel(object) then
            addUnique(targets, seenTargets, object)
        end
    end
end
if #targets == 0 then
    for _, object in objects do
        if isModularPart(object) and targetRole(object) then
            local model = object:FindFirstAncestorOfClass("Model")
            if model then
                addUnique(targets, seenTargets, model)
            end
        end
    end
end
assert(#targets == 1,
    "Select exactly one imported Modular 90 degree track curve Model in Explorer, then paste again.")
local target = targets[1]
assert(target:IsDescendantOf(workspace), "Move the selected curve model into Workspace first.")

local sources = {}
local seenSources = {}
local sourceSelected = false
local function addSource(part)
    if part:IsA("MeshPart") and not isModularPart(part) and not part:IsDescendantOf(target)
        and part:IsDescendantOf(workspace) then
        addUnique(sources, seenSources, part)
    end
end

for _, object in selection do
    if object ~= target and not object:IsDescendantOf(target) then
        sourceSelected = true
        addSource(object)
        for _, descendant in object:GetDescendants() do
            addSource(descendant)
        end
    end
end
if not sourceSelected then
    for _, object in objects do
        addSource(object)
    end
end

local meshProperties = { "Material", "MaterialVariant", "Color", "Reflectance", "Transparency" }
local textureChildren = {
    SurfaceAppearance = {
        "AlphaMode", "Color", "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap",
        "ColorMapContent", "NormalMapContent", "RoughnessMapContent",
        "MetalnessMapContent", "EmissiveMaskContent", "EmissiveStrength", "EmissiveTint",
        "ResampleMode", "SurfaceSlot",
    },
    Decal = {
        "Texture", "TextureContent", "Color3", "Transparency", "Face", "ZIndex",
    },
    Texture = {
        "Texture", "TextureContent", "Color3", "Transparency", "Face", "ZIndex", "StudsPerTileU",
        "StudsPerTileV", "OffsetStudsU", "OffsetStudsV",
    },
}
local function readProperty(object, property)
    local ok, value = pcall(function() return object[property] end)
    if ok then return value end
end
local function hasContent(value)
    if type(value) == "string" then return value ~= "" end
    return value ~= nil and value ~= Content.none
end

local snapshots = {}
local function appearance(part)
    if snapshots[part] then return snapshots[part] end
    local data = { references = {}, signature = {}, children = {} }
    for _, property in meshProperties do
        data.signature[property] = part[property]
    end
    data.textureContent = readProperty(part, "TextureContent")
    data.textureID = part.TextureID
    data.signature.TextureContent = data.textureContent
    data.signature.TextureID = data.textureID
    if hasContent(data.textureContent) or hasContent(data.textureID) then
        data.references.meshTexture = true
    end
    if part.MaterialVariant ~= "" then data.references.variant = true end

    local childCount = 0
    for _, child in part:GetChildren() do
        local properties = textureChildren[child.ClassName]
        if properties then
            table.insert(data.children, child)
            childCount += 1
            data.signature[childCount .. ".class"] = child.ClassName
            for _, property in properties do
                local value = readProperty(child, property)
                data.signature[childCount .. "." .. property] = value
                local isImage = property == "Texture" or property:sub(-3) == "Map"
                    or property:sub(-7) == "Content"
                if isImage and hasContent(value) then
                    data.references[child.ClassName] = true
                end
            end
        end
    end
    snapshots[part] = data
    return data
end

local function sameAppearance(first, second)
    local a = appearance(first).signature
    local b = appearance(second).signature
    for property, value in a do
        if b[property] ~= value then return false end
    end
    for property, value in b do
        if a[property] ~= value then return false end
    end
    return true
end

local function sourceRank(part, role)
    local name = nameKey(part.Name)
    for index, exactName in exactSourceNames[role] do
        if name == exactName or name == exactName:sub(1, -2) then
            return index == 1 and 1 or 3
        end
    end
    if namedRole(name) == role then
        if contains(name, "bend") then return 2 end
        if contains(name, "straight") then return 4 end
        if sourceSelected then return 5 end
    elseif sourceSelected and (name == role or name == nameKey(displayName[role])) then
        return 5
    end
end

local function chooseSource(role)
    local candidates = {}
    local bestRank = math.huge
    local override = sourceNames[role]
    for _, part in sources do
        local rank
        if override then
            if part.Name == override then rank = 1 end
        else
            rank = sourceRank(part, role)
            if rank and next(appearance(part).references) then rank -= 10 end
        end
        if rank and rank <= bestRank then
            if rank < bestRank then
                bestRank = rank
                table.clear(candidates)
            end
            table.insert(candidates, part)
        end
    end

    local label = displayName[role]
    local first = candidates[1]
    if not first then
        warn("No " .. label .. " reference found. Select the original track Model together with "
            .. "the modular curve. If its parts have generic names, set sourceNames." .. role
            .. " to the exact name of its selected reference MeshPart.")
        return nil
    end
    for index = 2, #candidates do
        local other = candidates[index]
        if not sameAppearance(first, other) then
            warn(("Multiple %s references have different appearances (%s and %s). Select one original "
                .. "track Model or set sourceNames.%s and select the matching source part."):format(
                    label, first:GetFullName(), other:GetFullName(), role))
            return nil
        end
    end
    return first
end

local targetsByRole = { slate = {}, dark = {}, wall = {} }
local visuals = {}
local colliders = {}
for _, part in target:GetDescendants() do
    if isModularPart(part) then
        local role = targetRole(part)
        if role then
            table.insert(targetsByRole[role], part)
            table.insert(visuals, part)
        elseif contains(nameKey(part.Name), "modularcurvecollider") then
            table.insert(colliders, part)
        end
    end
end
assert(#visuals > 0, "The selected model has no modular curve visual meshes.")
local expectedColliders = 60
local collisionReady = #colliders == expectedColliders

local references = {}
local changes = {}
for _, role in roles do
    local parts = targetsByRole[role]
    if #parts > 0 then
        local reference = chooseSource(role)
        if reference then
            local source = appearance(reference)
            local replacements = {}
            local prepared = true
            for _, part in parts do
                local copies = {}
                for _, child in source.children do
                    local clone = child:Clone()
                    if clone then
                        table.insert(copies, clone)
                    else
                        prepared = false
                        warn("Could not clone " .. child:GetFullName()
                            .. ". Leaving the curve's " .. displayName[role] .. " appearance as imported.")
                        break
                    end
                end
                if not prepared then break end
                table.insert(replacements, { part = part, source = source, replacements = copies })
            end
            if prepared then
                references[role] = reference
                for _, change in replacements do table.insert(changes, change) end
            end
        end
    end
end

local setupName = "Set up modular track curve"
local started, recording = pcall(function()
    return History:TryBeginRecording("SetupModularTrackCurve", setupName)
end)
if not started then recording = nil end

local function waypoint(name)
    return pcall(function() History:SetWaypoint(name) end)
end

-- Keep a rollback path even when Studio declines an Undo recording.
local journal = {}
local function write(object, property, value)
    local previous = object[property]
    if previous == value then return end
    object[property] = value
    table.insert(journal, { object = object, property = property, previous = previous })
end

local ok, problem = pcall(function()
    for _, part in colliders do
        write(part, "Anchored", true)
        write(part, "CanCollide", collisionReady)
        write(part, "CanQuery", collisionReady)
        write(part, "CanTouch", false)
        write(part, "Transparency", 1)
        write(part, "CastShadow", false)
    end
    for _, part in visuals do
        write(part, "Anchored", true)
        if collisionReady then
            write(part, "CanCollide", false)
            write(part, "CanQuery", false)
            write(part, "CanTouch", false)
        end
    end
    for _, change in changes do
        local part, source = change.part, change.source
        for _, property in meshProperties do
            write(part, property, source.signature[property])
        end
        if hasContent(source.textureContent) then
            local assigned = pcall(write, part, "TextureContent", source.textureContent)
            if not assigned then
                local uri = source.textureID
                if not hasContent(uri) then uri = readProperty(source.textureContent, "Uri") end
                assert(hasContent(uri), "Studio could not assign the embedded texture on " .. part:GetFullName())
                write(part, "TextureID", uri)
            end
        else
            write(part, "TextureID", source.textureID)
        end
        for _, child in part:GetChildren() do
            if textureChildren[child.ClassName] then write(child, "Parent", nil) end
        end
        for _, replacement in change.replacements do
            write(replacement, "Parent", part)
        end
    end
end)

local finalized = false
if recording then
    finalized = pcall(function()
        History:FinishRecording(recording,
            if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
    end)
end
if not ok then
    if not finalized then
        for index = #journal, 1, -1 do
            local edit = journal[index]
            local restored, reason = pcall(function()
                edit.object[edit.property] = edit.previous
            end)
            if not restored then warn("Could not restore " .. edit.property .. ": " .. tostring(reason)) end
        end
    end
    error(problem, 0)
end
if not finalized and not waypoint(setupName) then
    warn("Studio Undo was unavailable. The curve setup was applied.")
end

print(("Set up %s: %d visual MeshParts, %d collision MeshParts, %d appearance copies."):format(
    target:GetFullName(), #visuals, #colliders, #changes))
if not collisionReady then
    warn(("Found %d of %d collision meshes. Reimport the GLB as one Model with separate MeshParts to "
        .. "enable deck and wall collision. Visual collision settings were left as imported.")
        :format(#colliders, expectedColliders))
end
for _, role in roles do
    local source = references[role]
    if source then
        print(("Copied %s from %s to %d MeshParts."):format(
            displayName[role], source:GetFullName(), #targetsByRole[role]))
        if not next(appearance(source).references) then
            warn(("No readable texture asset or material variant was found on %s. Its material and color were copied."):format(
                source:GetFullName()))
        end
    elseif #targetsByRole[role] > 0 then
        print(("Kept the imported appearance for %s."):format(displayName[role]))
    end
end
