local Config = {}

Config.Tag = "VolcanicLava"

Config.Defaults = table.freeze({
	LavaFlowSpeed = .72,
	GlowIntensity = .78,
	SparkEmissionRate = 26,
	BubbleFrequency = .48,
	LavaBrightness = .96,
	SmokeDensity = .34,
	AnimationQuality = .85,
	FlowAngle = 16,
	UseEditableTexture = true,
})

Config.Budget = table.freeze({
	NearDistance = 80,
	AtmosphereDistance = 185,
	MaxDistance = 480,
	MaxVisualPools = 6,
	MaxAtmospherePools = 3,
	MobileVisualPools = 4,
	MobileAtmospherePools = 2,
})

local limits = {
	LavaFlowSpeed = {.05, 4},
	GlowIntensity = {0, 2},
	SparkEmissionRate = {0, 75},
	BubbleFrequency = {0, 2.5},
	LavaBrightness = {.26, 1.65},
	SmokeDensity = {0, 1},
	AnimationQuality = {.25, 1},
	FlowAngle = {-360, 360},
}

local function finite(value)
	return type(value) == "number" and math.abs(value) < math.huge
end

function Config.forPart(part, mobile)
	local settings = table.clone(Config.Defaults)
	for field, bounds in pairs(limits) do
		local value = part:GetAttribute(field)
		if finite(value) then
			settings[field] = math.clamp(value, bounds[1], bounds[2])
		end
	end

	local imagePreference = part:GetAttribute("UseEditableTexture")
	if type(imagePreference) == "boolean" then
		settings.UseEditableTexture = imagePreference
	end
	if mobile then
		settings.AnimationQuality = math.min(settings.AnimationQuality, .70)
	end

	local angle = math.rad(settings.FlowAngle)
	settings.FlowDirection = Vector2.new(math.cos(angle), math.sin(angle))
	return settings
end

return Config
