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
local BLINK_TIMES = { 3.2, 8.6, 12.7, 18.8 }
local BLINK_CYCLE = 22.7
local BLINK_CLOSE = 0.11
local BLINK_REOPEN = 0.165
local BLINK_HOLD = 0.055

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

local function blink(age)
	local phase = age % BLINK_CYCLE
	local since = phase
	for _, start in BLINK_TIMES do
		if phase < start then
			break
		end
		since = phase - start
	end
	-- The initial open period has no blink at time zero.
	if age < BLINK_TIMES[1] then
		return 0
	end
	return ease(since / BLINK_CLOSE)
		* (1 - ease((since - BLINK_CLOSE - BLINK_HOLD) / BLINK_REOPEN))
end

function Timeline.pose(age, elapsed, config)
	local sample = Timeline.sample(elapsed, config)
	local idleWeight = 1
	if sample.active then
		-- Fade the idle motion during wake and bring it back during recovery.
		local edge = math.min(elapsed, Timeline.duration(config) - elapsed)
		idleWeight = 1 - ease(edge / 0.65)
	end
	if idleWeight == 0 then
		return sample
	end

	local scale = idleWeight * math.clamp(number(config and config.IdleBreathScale, 1), 0, 2)
	local period = math.clamp(number(config and config.IdleBreathPeriod, 4.8), 2, 15)
	local phase = (age % period) / period * 2 * math.pi
	local function lift(delay, degrees)
		return math.rad(degrees) * scale * (1 - math.cos(phase - delay)) * 0.5
	end

	local gestureTime = age % 14.3 - 8.2
	local lean = ease(gestureTime / 1.4) * (1 - ease((gestureTime - 1.4) / 2.0))
	local pose = sample.active and sample or table.clone(sample)
	pose.basePitch += lift(0, 1.6) + math.rad(1.05 * lean * scale)
	pose.midPitch += lift(0.18, 1.3) + math.rad(0.7 * lean * scale)
	pose.upperPitch += lift(0.34, 0.7)
	pose.headPitch += lift(0.48, -2)
	pose.headRoll = math.rad(3.1 * lean * scale)
	-- Rise is in authored rig units, converted using the imported rig scale.
	pose.chestRise = scale * (0.07 * (1 - math.cos(phase)) * 0.5 + 0.035 * lean)
	pose.blink = blink(age) * idleWeight
	return pose
end

return Timeline
