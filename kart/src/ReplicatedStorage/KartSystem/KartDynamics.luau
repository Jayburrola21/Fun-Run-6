-- Pure calculations shared by the server and the standalone Luau tests.
local Dynamics = {}

function Dynamics.approach(value, target, response, dt)
	return value+(target-value)*(1-math.exp(-response*dt))
end

function Dynamics.suspension(compression, normalVelocity, gravity, config)
	local omega=config.SpringFrequency*2*math.pi
	-- Acceleration per quarter mass; critically damped, bounded contact load.
	return math.clamp(gravity+compression*omega*omega-normalVelocity*2*config.SpringDamping*omega,0,gravity*2.5)
end

function Dynamics.steering(speed, steer, blend, config)
	local angle=-steer*config.MaxSteer/(1+(math.abs(speed)/36)^2)
	local limit=config.MaxCornerAcceleration/math.max(math.abs(speed),12)
	local yaw=math.clamp(math.tan(angle)*speed/config.Wheelbase*(1+blend*0.12),-limit,limit)
	return angle,yaw
end

function Dynamics.lateral(speed, sideSpeed, steer, blend, config)
	local target=-steer*math.max(speed,0)*math.tan(config.DriftSlipAngle)*blend
	local grip=config.Grip+(config.DriftGrip-config.Grip)*blend
	return math.clamp((target-sideSpeed)*grip,-config.MaxCornerAcceleration,config.MaxCornerAcceleration)
end

function Dynamics.stage(seconds, thresholds)
	local result = 0
	for index, threshold in ipairs(thresholds) do
		if seconds >= threshold then result = index end
	end
	return result
end

function Dynamics.longitudinal(speed, throttle, boost, config)
	local limit = config.MaxSpeed + boost
	local accel = 0
	if throttle > 0 then
		accel = speed < -1 and config.BrakeAcceleration or config.Acceleration
	elseif throttle < 0 then
		accel = speed > 1 and -config.BrakeAcceleration or -config.Acceleration * 0.65
	end
	accel *= math.abs(throttle)
	if boost > 0 and throttle >= 0 then accel += boost * 1.6 end
	if speed > limit then accel = math.min(accel, -(speed - limit) * 7) end
	if speed < -config.ReverseSpeed then accel = math.max(accel, (-config.ReverseSpeed - speed) * 7) end
	return accel - speed * config.CoastDrag * (throttle == 0 and 1 or 0.15)
end

function Dynamics.finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function Dynamics.updateBoost(state, now, dt, grounded, speed, config)
	local drifting=state.player~=nil and state.drift and math.abs(state.steer)>0.15 and speed>config.DriftMinSpeed and grounded
	if drifting then
		state.charge=math.min(state.charge+dt,config.DriftStages[3]+0.1)
	elseif state.wasDrift and not state.drift and grounded and state.player then
		local tier=Dynamics.stage(state.charge,config.DriftStages)
		if tier>0 then
			state.boostEnd=math.max(state.boostEnd,now+config.DriftBoostDuration[tier])
			state.boostPower=config.DriftBoostPower[tier]
		end
		state.charge=0
	else state.charge=0 end
	state.wasDrift=drifting
	if state.player and state.turbo and now>=state.cooldown and grounded and speed>=0 then
		state.cooldown=now+config.TurboCooldown
		state.boostEnd=math.max(state.boostEnd,now+config.TurboDuration)
		state.boostPower=math.max(state.boostPower,config.TurboPower)
	end
	local power=now<state.boostEnd and state.boostPower or 0
	if power==0 then state.boostPower=0 end
	return drifting,power
end

return table.freeze(Dynamics)
