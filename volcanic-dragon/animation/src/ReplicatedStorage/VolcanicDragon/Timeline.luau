-- All values are relative to the imported rest pose. The head yaw is the
-- desired heading; the three neck yaw components are contributions to it.
local Timeline = {}

local REST = table.freeze({
	basePitch = 0, midPitch = 0, upperPitch = 0, headPitch = 0,
	baseYaw = 0, midYaw = 0, upperYaw = 0, headYaw = 0,
	jawOpen = 0, fire = 0, active = false,
})

local ZERO = { 0, 0, 0, 0, 0 }
local WAKE = { 9, 10, 9, 5, 0 }
local AIM = { 8, 11, 2, -28, 7 }
local BREATH = { 9, 12, 1, -31, 30 }
local RELEASE = { 8, 10, 3, -22, 0 }

local function number(value, fallback)
	if type(value) == "number" and value == value and math.abs(value) < math.huge then
		return value
	end
	return fallback
end

local function ease(value)
	local t = math.clamp(value, 0, 1)
	return t * t * t * (t * (t * 6 - 15) + 10)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

function Timeline.duration(config)
	return math.clamp(number(config and config.Duration, 10), 4, 60)
end

local function heading(time, wakeEnd, fireStart, fireEnd, finish, sweep)
	if time < fireStart then
		return sweep * ease((time - wakeEnd) / ((fireStart - wakeEnd) * 0.83))
	elseif time < fireEnd then
		local progress = (time - fireStart) / (fireEnd - fireStart)
		if progress <= 0.52 then
			return lerp(sweep, -sweep, ease(progress / 0.52))
		end
		return lerp(-sweep, sweep, ease((progress - 0.52) / 0.48))
	end

	return sweep * (1 - ease((time - fireEnd) / ((finish - fireEnd) * 0.72)))
end

function Timeline.sample(elapsed, config)
	local total = Timeline.duration(config)
	if not (elapsed > 0 and elapsed < total) then
		return REST
	end

	local breathTime = math.clamp(number(config and config.FireDuration, 5), 1, total - 2.3)
	local nonFire = total - breathTime
	local wakeEnd = nonFire * 0.30
	local fireStart = nonFire * 0.50
	local fireEnd = fireStart + breathTime
	local recovery = total - fireEnd
	local sweep = math.rad(math.clamp(number(config and config.SweepAngle, 27), 0, 43))
	local yaw = heading(elapsed, wakeEnd, fireStart, fireEnd, total, sweep)
	local followDelay = math.min(1, breathTime / 3, recovery / 1.7)
	local neckBaseYaw = 0.095 * heading(elapsed - 0.39 * followDelay, wakeEnd, fireStart, fireEnd, total, sweep)
	local neckMidYaw = 0.165 * heading(elapsed - 0.28 * followDelay, wakeEnd, fireStart, fireEnd, total, sweep)
	local neckUpperYaw = 0.25 * heading(elapsed - 0.17 * followDelay, wakeEnd, fireStart, fireEnd, total, sweep)

	local from, to, phase, fire = ZERO, WAKE, 0, 0
	local settledBreath = 0
	if elapsed < wakeEnd then
		phase = ease(elapsed / wakeEnd)
	elseif elapsed < fireStart then
		from, to = WAKE, AIM
		phase = ease((elapsed - wakeEnd) / ((fireStart - wakeEnd) * 0.82))
	elseif elapsed < fireEnd then
		from, to = AIM, BREATH
		local entry = math.min(0.40, breathTime * 0.20)
		phase = ease((elapsed - fireStart) / entry)
		fire = ease((elapsed - fireStart) / math.min(0.32, breathTime * 0.18))
			* ease((fireEnd - elapsed) / math.min(0.58, breathTime * 0.28))
	else
		local progress = (elapsed - fireEnd) / recovery
		if progress < 0.31 then
			from, to = BREATH, RELEASE
			phase = ease(progress / 0.31)
		else
			from, to = RELEASE, ZERO
			phase = ease((progress - 0.31) / 0.69)
			local settle = math.clamp((progress - 0.62) / 0.38, 0, 1)
			settledBreath = math.sin(math.pi * settle) ^ 2
		end
	end

	return {
		basePitch = math.rad(lerp(from[1], to[1], phase) + 0.32 * settledBreath),
		midPitch = math.rad(lerp(from[2], to[2], phase) + 0.40 * settledBreath),
		upperPitch = math.rad(lerp(from[3], to[3], phase) + 0.18 * settledBreath),
		headPitch = math.rad(lerp(from[4], to[4], phase) - 0.46 * settledBreath),
		baseYaw = neckBaseYaw,
		midYaw = neckMidYaw,
		upperYaw = neckUpperYaw,
		headYaw = yaw,
		jawOpen = math.rad(lerp(from[5], to[5], phase)),
		fire = fire,
		active = true,
	}
end

return Timeline
