local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("VolcanicDragon")
local Config = require(shared.Config)
local Timeline = require(shared.Timeline)

local TAG = "VolcanicDragonAnimated"
local LOADED_AT = "VolcanicDragonLoadedAt"
local STARTED_AT = "VolcanicDragonStartedAt"
local DURATION = Timeline.duration(Config)
local ATTACK_INTERVAL = 20
local START_LEAD = 0.22

local registered = {}

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

local function availableAt(model)
	local previous = model:GetAttribute(STARTED_AT)
	return type(previous) == "number" and previous + DURATION or -math.huge
end

local function start(model)
	if not model then
		for candidate in pairs(registered) do
			model = candidate
			break
		end
	end
	if not model or not registered[model] or not model:IsDescendantOf(Workspace) then
		warn("VolcanicDragon: import the rigged GLB in Workspace and name its model " .. Config.ModelName)
		return
	end

	local now = Workspace:GetServerTimeNow()
	if now >= availableAt(model) then
		model:SetAttribute(STARTED_AT, now + START_LEAD)
	end
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
	local loadedAt = Workspace:GetServerTimeNow()
	model:SetAttribute(LOADED_AT, loadedAt)
	model:SetAttribute(STARTED_AT, nil)
	local state = {
		nextAttackAt = loadedAt + ATTACK_INTERVAL,
	}
	registered[model] = state
	CollectionService:AddTag(model, TAG)
	state.connection = model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			state.connection:Disconnect()
			registered[model] = nil
			CollectionService:RemoveTag(model, TAG)
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

RunService.Heartbeat:Connect(function()
	local now = Workspace:GetServerTimeNow()
	for model, state in pairs(registered) do
		if now >= state.nextAttackAt - START_LEAD then
			-- Keep the cadence anchored at load, even if a server frame is late.
			local missed = math.floor((now - (state.nextAttackAt - START_LEAD)) / ATTACK_INTERVAL)
			local startedAt = state.nextAttackAt + missed * ATTACK_INTERVAL
			local readyAt = availableAt(model)
			if readyAt > startedAt or now >= startedAt + DURATION then
				state.nextAttackAt = startedAt + ATTACK_INTERVAL
			elseif now >= readyAt and model:IsDescendantOf(Workspace) then
				-- Keep the previous timestamp until its recovery has finished.
				state.nextAttackAt = startedAt + ATTACK_INTERVAL
				model:SetAttribute(STARTED_AT, startedAt)
			end
		end
	end
end)

-- A server-only manual entry point. Watching the start timestamp also
-- synchronizes clients that stream in or join while a breath is running.
local trigger = Instance.new("BindableEvent")
trigger.Name = "PlayVolcanicDragon"
trigger.Event:Connect(start)
trigger.Parent = ServerStorage
