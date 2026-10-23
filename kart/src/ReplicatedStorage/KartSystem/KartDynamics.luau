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

local function activateTurbo(state, now, config)
	state.charge=0; state.turboArmed=false
	state.boostEnd=now+config.TurboDuration
	state.boostPower=config.TurboPower
	state.cooldown=now+config.TurboCooldown
end

function Dynamics.updateBoost(state, now, dt, grounded, speed, config)
	if state.player==nil then
		state.charge=0; state.turboArmed=false; state.wasDrift=false; state.boostEnd=0; state.boostPower=0
		-- The kart retains its recharge deadline when a driver leaves or respawns.
		return false,0
	end
	local onRoad=grounded and speed>config.DriftMinSpeed
	local validMotion=math.abs(state.steer)>0.15 and onRoad
	local drifting=state.drift and validMotion
	local readyAt=math.max(state.cooldown,state.boostEnd)
	if now<readyAt then
		state.charge=0; state.turboArmed=false
	elseif drifting then
		-- A stalled simulation cannot instantly arm turbo. A frame straddling
		-- recharge completion only credits its eligible tail.
		local elapsed=Dynamics.finite(dt) and math.clamp(dt,0,1/15) or 0
		elapsed=math.min(elapsed,math.max(now-readyAt,0))
		state.charge=math.min(state.charge+elapsed,config.DriftChargeTime)
		-- Epoch deadlines have sub-microsecond double precision. Keep the meter
		-- exactly full when that rounding tolerance completes the charge.
		if state.charge+1e-6>=config.DriftChargeTime then
			state.charge=config.DriftChargeTime; state.turboArmed=true
			if config.TurboActivation=="Immediate" then activateTurbo(state,now,config) end
		end
	elseif config.TurboActivation~="Immediate" and not state.drift and state.wasDrift and state.turboArmed and onRoad then
		-- Shift and the turn key may be released in the same input packet. The
		-- preceding drift must be valid, but current steering need not remain held.
		-- Airborne/slow releases and straightening while still held cancel charge.
		activateTurbo(state,now,config)
	else
		state.charge=0; state.turboArmed=false
	end
	state.wasDrift=drifting
	local power=now<state.boostEnd and state.boostPower or 0
	if power==0 then state.boostPower=0 end
	return drifting,power
end

return table.freeze(Dynamics)
