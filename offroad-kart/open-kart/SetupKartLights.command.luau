-- Run in the Roblox Studio Command Bar in Edit mode with the kart Model selected.
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local ScriptEditorService = game:GetService("ScriptEditorService")

assert(not RunService:IsRunning(), "Stop Play before installing the kart lights.")
local selected = Selection:Get()
assert(#selected == 1 and selected[1]:IsA("Model"), "Select one imported kart Model in Explorer.")
local kart = selected[1]

local BANKS = {
    {
        names = {"Left_Headlight_WarmLens", "Right_Headlight_WarmLens"},
        attribute = "HeadlightsEnabled",
        color = Color3.fromRGB(255, 230, 176),
        range = 32,
        angle = 70,
        brightness = 3,
        pitch = .07,
        reverse = false,
    },
    {
        names = {"Left_Taillight_LED", "Right_Taillight_LED"},
        attribute = "TaillightsEnabled",
        color = Color3.fromRGB(255, 32, 40),
        range = 8,
        angle = 105,
        brightness = .55,
        brakeBrightness = 2.5,
        runningColor = Color3.fromRGB(128, 14, 24),
        pitch = .04,
        reverse = true,
    },
}

local ATTACHMENT_NAME = "OffroadKartLightMount"
local LIGHT_NAME = "OffroadKartBeam"
local APPEARANCE_NAME = "OffroadKartImportedAppearance"
local INSTALLER_TAG = "OffroadKartLightSetup"
local CONTROLLER_NAME = "OffroadKartLightController"
local ROLL_AND_ROOF_PARTS = {
    Rear_Roll_Hoop = true,
    Rear_Hoop_Crossbrace = true,
    Roof_LightbarMount = true,
}
for _, side in ipairs({"Left", "Right"}) do
    for _, suffix in ipairs({"Side_Protection", "Lower_Sill", "Cage_Diagonal", "Cage_Rear_Stay"}) do
        ROLL_AND_ROOF_PARTS[side .. "_" .. suffix] = true
    end
end
for pod = 1, 4 do
    for _, suffix in ipairs({"Housing", "Bezel", "WarmLens"}) do
        ROLL_AND_ROOF_PARTS[("Roof_Pod_%d_%s"):format(pod, suffix)] = true
    end
end

local CONTROLLER_SOURCE = [=[
-- Server-side visual controller installed by SetupKartLights.command.luau.
local kart = script.Parent
local headlights, taillights = {}, {}
for _, beam in ipairs(kart:GetDescendants()) do
    if beam:IsA("SpotLight") and beam.Name == "OffroadKartBeam" and beam:GetAttribute("OffroadKartLightSetup") then
        local rear = beam:GetAttribute("OffroadKartRearLamp")
        if typeof(rear) == "boolean" then
            local bank = rear and taillights or headlights
            table.insert(bank, {beam = beam, lens = beam.Parent.Parent})
        end
    end
end
if #headlights ~= 2 or #taillights ~= 2 then
    warn("Open kart lighting requires two installed headlamps and two taillamps.")
    return
end

local seat = kart:FindFirstChildWhichIsA("VehicleSeat", true)
kart.DescendantAdded:Connect(function(object)
    if not seat and object:IsA("VehicleSeat") then
        seat = object
    end
end)

local function braking()
    local override = kart:GetAttribute("Braking")
    if typeof(override) == "boolean" then
        return override
    end
    if seat and not seat:IsDescendantOf(kart) then
        seat = kart:FindFirstChildWhichIsA("VehicleSeat", true)
    end
    if not seat or not seat.Occupant then
        return false
    end

    -- Infer the chassis's forward direction from the moving lamp pairs.
    local front = (headlights[1].lens.Position + headlights[2].lens.Position) / 2
    local rear = (taillights[1].lens.Position + taillights[2].lens.Position) / 2
    local direction = front - rear
    if direction.Magnitude < .001 then
        return false
    end
    local speed = seat.AssemblyLinearVelocity:Dot(direction.Unit)
    return math.abs(speed) > 1 and math.sign(speed) * seat.ThrottleFloat < -.05
end

local previousHeadlights, previousTailState
local function refresh()
    local headOn = kart:GetAttribute("HeadlightsEnabled") ~= false
    if headOn ~= previousHeadlights then
        for _, light in ipairs(headlights) do
            light.beam.Enabled = headOn
            light.lens.Material = headOn and Enum.Material.Neon or Enum.Material.SmoothPlastic
        end
        previousHeadlights = headOn
    end

    local tailOn = kart:GetAttribute("TaillightsEnabled") ~= false
    local tailState = if not tailOn then "Off" elseif braking() then "Brake" else "Running"
    if tailState ~= previousTailState then
        for _, light in ipairs(taillights) do
            local beam = light.beam
            beam.Enabled = tailOn
            beam.Brightness = beam:GetAttribute(tailState == "Brake" and "BrakeBrightness" or "RunningBrightness")
            light.lens.Color = tailState == "Brake" and beam.Color or beam:GetAttribute("RunningColor")
            light.lens.Material = tailOn and Enum.Material.Neon or Enum.Material.SmoothPlastic
        end
        previousTailState = tailState
    end
end

for _, name in ipairs({"Braking", "HeadlightsEnabled", "TaillightsEnabled"}) do
    kart:GetAttributeChangedSignal(name):Connect(refresh)
end
while kart.Parent do
    refresh()
    task.wait(.05)
end
]=]

local TEXTURE_ATTRIBUTE = "OffroadKartOriginalTexture"
local VARIANT_ATTRIBUTE = "OffroadKartOriginalMaterialVariant"

local function findOwnedChild(parent, name, className)
    local owned
    for _, child in ipairs(parent:GetChildren()) do
        if child.Name == name then
            assert(not owned and child:IsA(className) and child:GetAttribute(INSTALLER_TAG) == true,
                ("Conflicting %s on %s."):format(name, parent.Name))
            owned = child
        end
    end
    return owned
end

local function createOwnedChild(parent, name, className)
    local child = Instance.new(className)
    child.Name = name
    child:SetAttribute(INSTALLER_TAG, true)
    child.Parent = parent
    return child
end

local expected = {}
for _, bank in ipairs(BANKS) do
    for _, name in ipairs(bank.names) do
        expected[name] = true
    end
end

local lenses, removal = {}, {}
local headrest
for _, object in ipairs(kart:GetDescendants()) do
    if object:IsA("BasePart") then
        if expected[object.Name] then
            assert(not lenses[object.Name], "Multiple parts named " .. object.Name .. " under the selected Model.")
            lenses[object.Name] = object
        elseif ROLL_AND_ROOF_PARTS[object.Name] then
            table.insert(removal, object)
        elseif object.Name == "Bucket_Headrest" then
            headrest = object
        end
    end
end

-- Validate the four lenses and installer-owned names before editing the model.
local controller = findOwnedChild(kart, CONTROLLER_NAME, "Script")
local braking = kart:GetAttribute("Braking")
assert(braking == nil or typeof(braking) == "boolean", "Braking must be a Boolean attribute.")
local installed = {}
for _, bank in ipairs(BANKS) do
    bank.enabled = kart:GetAttribute(bank.attribute)
    assert(bank.enabled == nil or typeof(bank.enabled) == "boolean", bank.attribute .. " must be a Boolean attribute.")
    for _, name in ipairs(bank.names) do
        local lens = assert(lenses[name], "Missing lens " .. name .. ". Re-import with named meshes kept separate.")
        local mount = findOwnedChild(lens, ATTACHMENT_NAME, "Attachment")
        installed[lens] = {
            mount = mount,
            light = mount and findOwnedChild(mount, LIGHT_NAME, "SpotLight"),
            appearance = findOwnedChild(lens, APPEARANCE_NAME, "Folder"),
        }
    end
end

local function bankCenter(bank)
    local total = Vector3.zero
    for _, name in ipairs(bank.names) do
        total += lenses[name].Position
    end
    return total / #bank.names
end

-- Use the lamp layout so positioning the import at an arbitrary rotation still works.
local nose = bankCenter(BANKS[1])
local tail = bankCenter(BANKS[2])
local crossKart = lenses.Right_Headlight_WarmLens.Position - lenses.Left_Headlight_WarmLens.Position
assert(crossKart.Magnitude > .001, "The two headlight locations coincide.")
local lateral = crossKart.Unit
local forward = nose - tail
forward -= lateral * forward:Dot(lateral)
assert(forward.Magnitude > .001, "Could not determine the front and rear of the kart.")
forward = forward.Unit
local up = lateral:Cross(forward).Unit
local upHint = headrest and (headrest.Position - (nose + tail) / 2) or kart:GetPivot().UpVector
assert(math.abs(up:Dot(upHint)) > .001, "Could not determine which way is up on the kart.")
if up:Dot(upHint) < 0 then
    up = -up
end

local function setLensAppearance(lens, existing)
    -- Imported PBR appearance can obscure the Roblox Neon lens.
    for _, child in ipairs(lens:GetChildren()) do
        if child:IsA("SurfaceAppearance") then
            existing.appearance = existing.appearance or createOwnedChild(lens, APPEARANCE_NAME, "Folder")
            child.Parent = existing.appearance
        end
    end
    if lens:IsA("MeshPart") and lens.TextureID ~= "" then
        if lens:GetAttribute(TEXTURE_ATTRIBUTE) == nil then
            lens:SetAttribute(TEXTURE_ATTRIBUTE, lens.TextureID)
        end
        lens.TextureID = ""
    end
    if lens.MaterialVariant ~= "" then
        if lens:GetAttribute(VARIANT_ATTRIBUTE) == nil then
            lens:SetAttribute(VARIANT_ATTRIBUTE, lens.MaterialVariant)
        end
        lens.MaterialVariant = ""
    end
end

local function applyLighting()
    for _, bank in ipairs(BANKS) do
        local outward = bank.reverse and -forward or forward
        local direction = (outward - up * bank.pitch).Unit
        for _, name in ipairs(bank.names) do
            local lens = lenses[name]
            local existing = installed[lens]
            setLensAppearance(lens, existing)
            local enabled = bank.enabled ~= false
            lens.Material = enabled and Enum.Material.Neon or Enum.Material.SmoothPlastic
            local brakeOn = bank.reverse and enabled and braking == true
            lens.Color = (not brakeOn and bank.runningColor) or bank.color

            -- Offset the attachment past the lens face, even if importer axes differ.
            local frame = lens.CFrame
            local size = lens.Size
            local halfDepth = .5 * (
                math.abs(frame.RightVector:Dot(outward)) * size.X
                + math.abs(frame.UpVector:Dot(outward)) * size.Y
                + math.abs(frame.LookVector:Dot(outward)) * size.Z
            )
            local origin = lens.Position + outward * (halfDepth + math.max(.01, halfDepth * .1))
            local mount = existing.mount or createOwnedChild(lens, ATTACHMENT_NAME, "Attachment")
            mount.CFrame = frame:ToObjectSpace(CFrame.lookAt(origin, origin + direction, up))

            local beam = existing.light or createOwnedChild(mount, LIGHT_NAME, "SpotLight")
            beam.Face = Enum.NormalId.Front
            beam.Color = bank.color
            beam.Brightness = brakeOn and bank.brakeBrightness or bank.brightness
            beam.Range = bank.range
            beam.Angle = bank.angle
            beam.Shadows = false
            beam.Enabled = enabled
            beam:SetAttribute("OffroadKartRearLamp", bank.reverse)
            if bank.reverse then
                beam:SetAttribute("RunningColor", bank.runningColor)
                beam:SetAttribute("RunningBrightness", bank.brightness)
                beam:SetAttribute("BrakeBrightness", bank.brakeBrightness)
            end
        end
    end

    controller = controller or createOwnedChild(kart, CONTROLLER_NAME, "Script")
    controller.RunContext = Enum.RunContext.Server
    ScriptEditorService:UpdateSourceAsync(controller, function()
        return CONTROLLER_SOURCE
    end)
    controller.Enabled = true

    for _, part in ipairs(removal) do
        part:Destroy()
    end
end

local recording = ChangeHistoryService:TryBeginRecording("OffroadKartLighting", "Open the off-road kart and set up its lights")
assert(recording, "Could not start the Studio undo recording for the kart lighting.")
local success, failure = pcall(applyLighting)
ChangeHistoryService:FinishRecording(recording,
    success and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
assert(success, failure)
print(("Updated %s: removed %d roll/roof parts and installed two headlights and two brake lights.")
    :format(kart.Name, #removal))
