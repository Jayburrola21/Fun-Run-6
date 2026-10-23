-- Pure visual motion calculations. Never changes vehicle forces or turbo rules.
local Presentation={}

function Presentation.delta(dt)
	return type(dt)=="number" and dt==dt and math.clamp(dt,0,0.1) or 0
end

function Presentation.wheel(phase,filteredSpeed,actualSpeed,radius,dt)
	dt=Presentation.delta(dt)
	if radius<=0 then return phase,0 end
	-- Ignore sub-pixel replication noise at rest; parked tires stop immediately.
	if math.abs(actualSpeed)<0.05 then return phase,0 end
	local decay=math.exp(-16*dt)
	local speed=actualSpeed+(filteredSpeed-actualSpeed)*decay
	-- Analytic distance under the smoothing curve, so spin agrees across FPS.
	local distance=actualSpeed*dt+(filteredSpeed-actualSpeed)*(1-decay)/16
	return (phase-distance/radius)%(2*math.pi),speed
end

return table.freeze(Presentation)
