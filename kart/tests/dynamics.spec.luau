-- The runner supplies the actual Config and Dynamics modules; no Roblox engine needed.
local count=0
local function check(value,message)
	assert(value,message); count+=1
end
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
	local boosted=integrate(70,1,Config.TurboPower,6,hz)
	check(boosted<Config.MaxSpeed+Config.TurboPower+4,"boost speed bounded at "..hz)
	check(boosted>speed+25,"boost accelerates at "..hz)
	check(integrate(boosted,1,0,3,hz)<Config.MaxSpeed+2,"boost expiry decelerates at "..hz)
end
check(Dynamics.longitudinal(-10,1,0,Config)>0,"forward brakes reverse motion")
check(Dynamics.longitudinal(10,-1,0,Config)<0,"reverse brakes forward motion")
check(Dynamics.longitudinal(0,0,0,Config)==0,"idle does not propel")
local function state()
	return {player=true,drift=false,steer=1,charge=0,turboArmed=false,wasDrift=false,boostEnd=0,boostPower=0,cooldown=0}
end
check(Config.DriftChargeTime==0.9 and Config.TurboDuration==1.5,"release turbo uses the requested timings")
for _,hz in ipairs({30,60,120}) do
	local s=state(); s.drift=true
	local frames=math.floor(Config.DriftChargeTime*hz+0.5)
	for n=1,math.floor(0.5*hz) do Dynamics.updateBoost(s,n/hz,1/hz,true,60,Config) end
	check(not s.turboArmed and s.boostPower==0,"half-second drift has no turbo "..hz)
	for n=math.floor(0.5*hz)+1,frames-1 do Dynamics.updateBoost(s,n/hz,1/hz,true,60,Config) end
	check(not s.turboArmed and s.boostPower==0,"does not arm early "..hz)
	local drifting,power=Dynamics.updateBoost(s,frames/hz,1/hz,true,60,Config)
	check(drifting and power==0 and s.turboArmed and s.charge==Config.DriftChargeTime,"0.9 seconds arms without auto firing "..hz)
	local releaseTime=1.2
	for n=frames+1,math.floor(releaseTime*hz)-1 do Dynamics.updateBoost(s,n/hz,1/hz,true,60,Config) end
	check(s.turboArmed and s.boostPower==0 and s.cooldown==0,"holding an armed drift never spends turbo "..hz)
	s.drift=false
	local _,released=Dynamics.updateBoost(s,releaseTime,1/hz,true,60,Config)
	check(released==Config.TurboPower and not s.turboArmed and s.charge==0,"release after 1.2 seconds redeems turbo "..hz)
	local deadline,boostEnd=s.cooldown,s.boostEnd
	check(math.abs(boostEnd-releaseTime-1.5)<1e-9,"release boost lasts exactly 1.5 seconds "..hz)
	check(math.abs(deadline-releaseTime-Config.TurboCooldown)<1e-9,"cooldown starts when turbo is redeemed "..hz)
	Dynamics.updateBoost(s,releaseTime+1/hz,1/hz,true,60,Config)
	check(s.cooldown==deadline and s.boostEnd==boostEnd,"repeated release cannot redeem twice "..hz)
	local _,expired=Dynamics.updateBoost(s,boostEnd,1/hz,true,60,Config)
	check(expired==0,"turbo expires at its deadline "..hz)
	for n=math.ceil((boostEnd+1/hz)*hz),math.floor(deadline*hz)-1 do
		s.drift=n%2==0
		Dynamics.updateBoost(s,n/hz,1/hz,true,60,Config)
	end
	check(s.cooldown==deadline and s.boostEnd==boostEnd and s.charge==0 and not s.turboArmed,"cooldown cannot precharge or rearm "..hz)
	s.drift=true
	Dynamics.updateBoost(s,deadline,1/hz,true,60,Config)
	check(s.charge==0 and not s.turboArmed,"cooldown completion gives no free charge "..hz)
	for n=1,frames do Dynamics.updateBoost(s,deadline+n/hz,1/hz,true,60,Config) end
	check(s.turboArmed and s.boostPower==0,"a fresh continuous drift can arm after cooldown "..hz)
	s.drift=false
	local _,second=Dynamics.updateBoost(s,deadline+(frames+1)/hz,1/hz,true,60,Config)
	check(second==Config.TurboPower and s.cooldown>deadline,"consecutive earned drift boosts work "..hz)

	s=state(); s.drift=true
	for n=1,math.floor(0.5*hz) do Dynamics.updateBoost(s,n/hz,1/hz,true,60,Config) end
	s.drift=false
	local _,partial=Dynamics.updateBoost(s,0.5+1/hz,1/hz,true,60,Config)
	check(partial==0 and s.charge==0 and not s.turboArmed and s.cooldown==0,"partial release awards nothing "..hz)
end
for _,condition in ipairs({{false,60,1},{true,0,1},{true,-40,1},{true,60,0}}) do
	local s=state(); s.drift=true; s.charge=0.5; s.steer=condition[3]
	local drifting,power=Dynamics.updateBoost(s,1,1/60,condition[1],condition[2],Config)
	check(not drifting and power==0 and s.charge==0,"air/slow/reverse/straight cancels partial charge")
	s=state(); s.drift=false; s.charge=Config.DriftChargeTime; s.turboArmed=true; s.wasDrift=true; s.steer=condition[3]
	local _,invalidRelease=Dynamics.updateBoost(s,1,1/60,condition[1],condition[2],Config)
	check(invalidRelease==0 and not s.turboArmed and s.charge==0,"invalid release cannot redeem armed turbo")
	s=state(); s.drift=true; s.charge=Config.DriftChargeTime; s.turboArmed=true; s.wasDrift=true; s.steer=condition[3]
	Dynamics.updateBoost(s,1,1/60,condition[1],condition[2],Config)
	s.drift=false; s.steer=1
	local _,laterRelease=Dynamics.updateBoost(s,1.1,1/60,true,60,Config)
	check(laterRelease==0 and not s.turboArmed,"lost drift eligibility discards armed charge permanently")
end
local s=state(); s.player=nil; s.drift=true; s.charge=Config.DriftChargeTime; s.turboArmed=true; s.boostEnd=5; s.boostPower=32; s.cooldown=9
local _,emptyPower=Dynamics.updateBoost(s,1,1/60,true,60,Config)
check(emptyPower==0 and s.charge==0 and not s.turboArmed and s.boostEnd==0 and s.boostPower==0,"no driver clears active boost and armed charge")
check(s.cooldown==9,"driver departure preserves cooldown")
s=state(); s.drift=true
Dynamics.updateBoost(s,10,10,true,60,Config)
check(s.charge<=1/15+1e-10 and not s.turboArmed,"long stall cannot instantly arm")
for _,invalid in ipairs({-1,math.huge,0/0}) do
	s=state(); s.drift=true
	Dynamics.updateBoost(s,1,invalid,true,60,Config)
	check(s.charge==0 and not s.turboArmed,"negative or non-finite elapsed time cannot charge")
end
s=state(); s.drift=true; s.cooldown=10.01
Dynamics.updateBoost(s,10.02,1/30,true,60,Config)
check(math.abs(s.charge-0.01)<1e-9,"boundary frame only counts time after cooldown")
s=state(); s.drift=true; s.boostEnd=10.01; s.boostPower=Config.TurboPower; s.cooldown=9
Dynamics.updateBoost(s,10,1/30,true,60,Config)
check(s.charge==0 and not s.turboArmed,"active turbo blocks charge with a shorter custom cooldown")
s=state(); s.turbo=true
Dynamics.updateBoost(s,5,1/60,true,60,Config)
check(s.boostPower==0 and s.charge==0,"legacy manual turbo input cannot activate")
local custom=table.clone(Config); custom.DriftChargeTime=0.2
s=state(); s.drift=true
for n=1,12 do Dynamics.updateBoost(s,n/60,1/60,true,60,custom) end
check(s.turboArmed and s.boostPower==0,"configured charge time arms without firing")
s.drift=false
local _,customRelease=Dynamics.updateBoost(s,0.22,1/60,true,60,custom)
check(customRelease==Config.TurboPower,"configured charge can redeem on release")

-- Epoch clocks retain exact frame-level charging/release behavior despite their
-- sub-microsecond double precision; no extra frame is added after cooldown.
for _,hz in ipairs({30,60,120}) do
	local epoch=1800000000
	local s=state(); s.drift=true
	local frames=math.floor(Config.DriftChargeTime*hz+0.5)
	for n=1,frames-1 do Dynamics.updateBoost(s,epoch+n/hz,1/hz,true,60,Config) end
	check(not s.turboArmed,"epoch clock does not arm early "..hz)
	Dynamics.updateBoost(s,epoch+frames/hz,1/hz,true,60,Config)
	check(s.turboArmed and s.boostPower==0,"epoch clock arms while held "..hz)
	s.drift=false
	local _,power=Dynamics.updateBoost(s,epoch+1.2,1/hz,true,60,Config)
	check(power==Config.TurboPower,"epoch release redeems turbo "..hz)
	check(math.abs(s.boostEnd-(epoch+1.2+Config.TurboDuration))<1e-6,"epoch boost deadline "..hz)
	check(math.abs(s.cooldown-(epoch+1.2+Config.TurboCooldown))<1e-6,"epoch cooldown deadline "..hz)
	local cooldown=s.cooldown
	s.drift=true
	Dynamics.updateBoost(s,cooldown,1/hz,true,60,Config)
	check(s.charge==0 and not s.turboArmed,"epoch cooldown has no free charge "..hz)
	for n=1,frames do Dynamics.updateBoost(s,cooldown+n/hz,1/hz,true,60,Config) end
	check(s.turboArmed and s.boostPower==0,"epoch fresh charge arms correctly "..hz)
	s.drift=false
	local _,second=Dynamics.updateBoost(s,cooldown+(frames+1)/hz,1/hz,true,60,Config)
	check(second==Config.TurboPower,"epoch consecutive release turbo "..hz)
end
s=state(); s.drift=true; s.cooldown=1800000010.017
Dynamics.updateBoost(s,1800000010.02,1/30,true,60,Config)
check(s.charge>0.002 and s.charge<0.004,"epoch fractional boundary credits only eligible tail")

-- Interpolation must have the same elapsed-time result at different frame rates.
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
	local scale=Config.ModelScale
	local width,length,height=3.7*scale,6.5*scale,0.5*scale
	local yawInertia=(width^2+length^2)/12
	for _,axis in ipairs({{2.68*scale,(width^2+height^2)/12},{Config.Wheelbase/2,(length^2+height^2)/12}}) do
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
