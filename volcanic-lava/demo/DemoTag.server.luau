local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local scene = Workspace:WaitForChild("VolcanicLavaDemo")

local main = scene:WaitForChild("MainPool")
local side = scene:WaitForChild("SidePool")
side:SetAttribute("FlowAngle", -22)
side:SetAttribute("LavaFlowSpeed", .48)
side:SetAttribute("GlowIntensity", .62)

CollectionService:AddTag(main, "VolcanicLava")
CollectionService:AddTag(side, "VolcanicLava")
