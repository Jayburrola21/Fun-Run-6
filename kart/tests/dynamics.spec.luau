-- The runner supplies the actual Config and Dynamics modules; no Roblox engine needed.
local count=0
local function check(value,message)
	assert(value,message); count+=1
end
check(Dynamics.stage(0,Config.DriftStages)==0,"no free drift boost")
check(Dynamics.stage(0.64,Config.DriftStages)==0,"blue threshold lower bound")
check(Dynamics.stage(0.65,Config.DriftStages)==1,"blue threshold")
check(Dynamics.stage(1.5,Config.DriftStages)==2,"orange threshold")
check(Dynamics.stage(2.7,Config.DriftStages)==3,"purple threshold")
check(Dynamics.stage(10000,Config.DriftStages)==3,"drift tier capped")
check(not Dynamics.finite(0/0),"reject NaN remote inputs")
check(not Dynamics.finite(math.huge),"reject positive infinity")
check(not Dynamics.finite(-math.huge),"reject negative infinity")
check(not Dynamics.finite("1"),"reject numeric strings")
check(Dynamics.finite(-1) and Dynamics.finite(0) and Dynamics.finite(1),"valid controls")
local function integrate(speed,throttle,boost,seconds,hz)
	for _=1,seconds*hz do speed+=Dynamics.longitudinal(speed,throttle,boost,Config)/hz end
	return speed
end
for _,hz in ipairs({30,60,120}) do
	local speed=integrate(0,1,0,8,hz)
	check(speed>Config.MaxSpeed-3 and speed<Config.MaxSpeed+2,"forward speed limit at "..hz)
	local reverse=integrate(0,-1,0,5,hz)
	check(reverse<0 and reverse>-Config.ReverseSpeed-2,"reverse capped at "..hz)
	local brake=integrate(60,-1,0,1,hz)
	check(brake<5,"brakes stop before reverse at "..hz)
	check(integrate(50,0,0,2,hz)<20,"coast drag at "..hz)
	local boosted=integrate(70,1,Config.DriftBoostPower[3],6,hz)
	check(boosted<Config.MaxSpeed+Config.DriftBoostPower[3]+4,"boost speed bounded at "..hz)
	check(boosted>speed+25,"boost accelerates at "..hz)
	check(integrate(boosted,1,0,3,hz)<Config.MaxSpeed+2,"boost expiry decelerates at "..hz)
end
check(Dynamics.longitudinal(-10,1,0,Config)>0,"forward brakes reverse motion")
check(Dynamics.longitudinal(10,-1,0,Config)<0,"reverse brakes forward motion")
check(Dynamics.longitudinal(0,0,0,Config)==0,"idle does not propel")
local function state()
	return {player=true,drift=false,steer=1,turbo=false,charge=0,wasDrift=false,boostEnd=0,boostPower=0,cooldown=0}
end
for tier,seconds in ipairs({0.8,1.7,2.9}) do
	local s=state(); s.drift=true
	for n=1,math.floor(seconds*60) do Dynamics.updateBoost(s,n/60,1/60,true,40,Config) end
	check(s.boostPower==0,"charging does not boost")
	s.drift=false
	local _,power=Dynamics.updateBoost(s,seconds+0.02,1/60,true,40,Config)
	check(power==Config.DriftBoostPower[tier],"release earns tier "..tier)
	local deadline=s.boostEnd
	Dynamics.updateBoost(s,seconds+0.1,1/60,true,40,Config)
	check(s.boostEnd==deadline,"release cannot redeem charge twice")
	local _,expired=Dynamics.updateBoost(s,deadline+0.01,1/60,true,40,Config)
	check(expired==0,"tier "..tier.." expires")
end
local s=state(); s.drift=true
for n=1,300 do Dynamics.updateBoost(s,n/60,1/60,false,60,Config) end
check(s.charge==0,"airborne drifting cannot charge")
for n=1,300 do Dynamics.updateBoost(s,n/60,1/60,true,0,Config) end
check(s.charge==0,"stationary drifting cannot charge")
s.steer=0
for n=1,300 do Dynamics.updateBoost(s,n/60,1/60,true,60,Config) end
check(s.charge==0,"straight driving cannot charge")
s.steer=1
for n=1,600 do Dynamics.updateBoost(s,n/60,1/60,true,60,Config) end
check(s.charge<=Config.DriftStages[3]+0.1,"charge accumulation is bounded")
Dynamics.updateBoost(s,11,1/60,false,60,Config)
check(s.charge==0,"leaving ground clears charge")
s=state(); s.turbo=true
local _,power=Dynamics.updateBoost(s,0,1/60,true,0,Config)
check(power==Config.TurboPower,"turbo available initially")
local deadline=s.boostEnd
for n=1,300 do Dynamics.updateBoost(s,n/60,1/60,true,60,Config) end
check(s.boostEnd==deadline and s.boostPower==0,"held/spammed turbo cannot extend boost during cooldown")
local _,nextPower=Dynamics.updateBoost(s,Config.TurboCooldown,1/60,true,60,Config)
check(nextPower==Config.TurboPower,"turbo recharges at cooldown")
s=state(); s.turbo=true
Dynamics.updateBoost(s,0,1/60,false,60,Config)
check(s.boostPower==0 and s.cooldown==0,"airborne turbo is rejected without consuming recharge")
s=state(); s.player=nil; s.drift=true; s.turbo=true
Dynamics.updateBoost(s,0,1/60,true,60,Config)
check(s.charge==0 and s.boostPower==0,"empty kart cannot charge or activate boost")

-- Interpolation must have the same elapsed-time result at different frame rates.
local reference
for _,hz in ipairs({30,60,120}) do
	local blend,steer=0,0
	for _=1,hz do
		blend=Dynamics.approach(blend,1,Config.DriftEnterResponse,1/hz)
		steer=Dynamics.approach(steer,1,Config.SteerResponse,1/hz)
	end
	check(math.abs(blend-(1-math.exp(-Config.DriftEnterResponse)))<1e-10,"frame-independent drift entry "..hz)
	check(steer>0.99,"responsive steering "..hz)
	local oldBlend=blend
	blend=Dynamics.approach(blend,0,Config.DriftExitResponse,1/hz)
	check(blend>0 and blend<oldBlend,"gradual grip recovery "..hz)
	for _=1,hz do blend=Dynamics.approach(blend,0,Config.DriftExitResponse,1/hz) end
	check(blend<0.005,"drift exit settles "..hz)
	local height,vertical=0.25,0
	for _=1,hz*3 do
		local acceleration=Dynamics.suspension(-height,vertical,196.2,Config)-196.2
		vertical+=acceleration/hz; height+=vertical/hz
	end
	check(math.abs(height)<0.001 and math.abs(vertical)<0.001,"heave settles "..hz)
	-- Small-angle four-corner spring model with the same inertia-scaled damping
	-- used by the server. This is a numeric regression, not an engine physics test.
	local yawInertia=(3.7^2+6.5^2)/12
	for _,axis in ipairs({{2.68,(3.7^2+0.5^2)/12},{2.4,(6.5^2+0.5^2)/12}}) do
		local angle,angular=0.08,0
		local stiffness=(Config.SpringFrequency*2*math.pi)^2*axis[1]^2+10*yawInertia
		for _=1,hz*3 do
			local acceleration=(-stiffness*angle-26*axis[2]*angular)/axis[2]
			angular+=acceleration/hz; angle+=angular/hz
			assert(math.abs(angle)<0.15,"roll/pitch response diverged")
		end
		check(math.abs(angle)<0.001 and math.abs(angular)<0.001,"angular damping settles "..hz)
	end
end
check(Dynamics.approach(0,1,Config.DriftEnterResponse,1/60)<0.1,"drift onset cannot snap")
check(Dynamics.suspension(0,0,196.2,Config)==196.2,"static spring supports gravity")
check(Dynamics.suspension(-10,0,196.2,Config)==0,"spring never pulls kart down")
check(Dynamics.suspension(10,-100,196.2,Config)<=196.2*2.5,"contact impulse bounded")
for _,speed in ipairs({0,20,60,100}) do
	local leftAngle,leftYaw=Dynamics.steering(speed,-1,1,Config)
	local rightAngle,rightYaw=Dynamics.steering(speed,1,1,Config)
	check(leftAngle==-rightAngle and leftYaw==-rightYaw,"symmetric turning "..speed)
	check(math.abs(rightYaw)*math.abs(speed)<=Config.MaxCornerAcceleration+1e-8,"cornering limit "..speed)
end
local slip=Dynamics.lateral(60,0,1,1,Config)
check(slip<0,"right drift slides outward to the left")
check(Dynamics.lateral(60,0,-1,1,Config)==-slip,"drift direction follows steering")
check(Dynamics.lateral(60,0,1,0,Config)==0,"normal driving has no artificial slide")
check(Dynamics.lateral(60,10,0,0,Config)<0,"normal grip removes sideways motion")
print(string.format("PASS: %d dynamics assertions (30/60/120 Hz)",count))
