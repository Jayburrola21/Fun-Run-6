local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("VolcanicDragon")
local Config = require(shared.Config)
local Timeline = require(shared.Timeline)
local DragonRig = require(shared.DragonRig)
local FireEffects = require(shared.FireEffects)

local TAG = "VolcanicDragonAnimated"
local STARTED_AT = "VolcanicDragonStartedAt"
local duration = Timeline.duration(Config)
local depression = math.rad(math.clamp(Config.FireDepression, 0, 40))
local models = {}

local function track(model)
	if model:IsA("Model") and not models[model] then
		models[model] = { retryAt = 0 }
	end
end

local function untrack(model)
	local state = models[model]
	if not state then
		return
	end
	if state.effects then
		state.effects:Destroy()
	end
	if state.rig and state.rig.mouth:IsDescendantOf(model) then
		state.rig:Reset()
	end
	models[model] = nil
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(untrack)
for _, model in CollectionService:GetTagged(TAG) do
	track(model)
end

RunService.RenderStepped:Connect(function(dt)
	local now = Workspace:GetServerTimeNow()
	for model, state in pairs(models) do
		local started = model:GetAttribute(STARTED_AT)
		local elapsed = type(started) == "number" and now - started or math.huge
		if elapsed >= 0 and elapsed < duration then
			-- Atomic streaming keeps copies of the bind skeleton together.
			-- A missed replication frame can retry without shifting the clock.
			if not state.rig and now >= state.retryAt then
				local rig, reason = DragonRig.new(model)
				state.rig = rig
				state.retryAt = now + .25
				if not rig and elapsed > 1 and not state.warned then
					warn("VolcanicDragon: " .. reason)
					state.warned = true
				end
			end
			if state.rig then
				local sample = Timeline.sample(elapsed, Config)
				state.rig:Apply(sample)
				state.moving = true
				if sample.fire > 0 then
					state.effects = state.effects or FireEffects.new(model, Config)
					local origin, direction = state.rig:GetMouth(depression)
					state.effects:Update(origin, direction, sample.fire, dt)
					state.breathing = true
				elseif state.breathing then
					state.effects:Stop()
					state.breathing = nil
				end
			end
		elseif state.moving then
			state.rig:Reset()
			if state.breathing then
				state.effects:Stop()
				state.breathing = nil
			end
			state.moving = nil
		end
	end
end)
