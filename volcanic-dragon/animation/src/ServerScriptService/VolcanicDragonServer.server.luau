local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("VolcanicDragon")
local Config = require(shared.Config)
local Timeline = require(shared.Timeline)

local TAG = "VolcanicDragonAnimated"
local STARTED_AT = "VolcanicDragonStartedAt"
local DURATION = Timeline.duration(Config)
local START_LEAD = 0.22

local registered = {}
local studioPrompts = RunService:IsStudio() and Config.PreviewPrompt

local function findRig(model)
	if model and model:IsA("Model") and model:IsDescendantOf(Workspace) then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("Bone") and (descendant.Name == "MouthOrigin" or descendant.Name:match("^MouthOrigin[%._]%d+$")) then
				return true
			end
		end
	end
	return false
end

local function start(model)
	if not model then
		for candidate in pairs(registered) do
			model = candidate
			break
		end
	end
	local state = model and registered[model]
	if not state or not model:IsDescendantOf(Workspace) then
		warn("VolcanicDragon: import the rigged GLB in Workspace and name its model " .. Config.ModelName)
		return
	end

	local now = Workspace:GetServerTimeNow()
	local previous = model:GetAttribute(STARTED_AT)
	if type(previous) == "number" and now < previous + DURATION then
		return
	end
	local startedAt = now + START_LEAD
	model:SetAttribute(STARTED_AT, startedAt)
	if state.prompt then
		state.prompt.Enabled = false
		task.delay(DURATION + START_LEAD, function()
			if state.prompt.Parent and model:GetAttribute(STARTED_AT) == startedAt then
				state.prompt.Enabled = true
			end
		end)
	end
end

local function mountPrompt(model)
	local base = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not base then
		return nil
	end
	local point = Instance.new("Attachment")
	point.Name = "VolcanicDragonStudioPromptLocation"
	local center, size = model:GetBoundingBox()
	point.Position = base.CFrame:PointToObjectSpace(center.Position + Vector3.yAxis * (size.Y * 0.5 + 2))
	point.Parent = base

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TestFireBreath"
	prompt.ActionText = "Test fire breath"
	prompt.ObjectText = "Volcanic Dragon"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = Config.PreviewPromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = point
	prompt.Triggered:Connect(function()
		start(model)
	end)
	return prompt
end

local function register(model)
	if registered[model] or model.Name ~= Config.ModelName or not findRig(model) then
		return
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute(STARTED_AT, nil)
	local state = { prompt = studioPrompts and mountPrompt(model) or nil }
	registered[model] = state
	CollectionService:AddTag(model, TAG)
	state.connection = model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			state.connection:Disconnect()
			registered[model] = nil
			CollectionService:RemoveTag(model, TAG)
			local point = state.prompt and state.prompt.Parent
			if point then
				point:Destroy()
			end
		end
	end)
end

for _, instance in Workspace:GetDescendants() do
	if instance:IsA("Model") and instance.Name == Config.ModelName then
		register(instance)
	end
end

Workspace.DescendantAdded:Connect(function(instance)
	if instance:IsA("Model") and instance.Name == Config.ModelName then
		task.defer(register, instance)
	end
end)

-- A server-only manual entry point. Watching the start timestamp also
-- synchronizes clients that stream in or join while a breath is running.
local trigger = Instance.new("BindableEvent")
trigger.Name = "PlayVolcanicDragon"
trigger.Event:Connect(start)
trigger.Parent = ServerStorage
