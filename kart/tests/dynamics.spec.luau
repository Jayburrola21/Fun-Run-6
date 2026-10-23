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
check(Config.DriftChargeTime==0.5 and Config.TurboDuration==1.5,"turbo uses requested half-second charge and 1.5-second duration")
check(Config.TurboActivation=="Release","default mode waits for Shift release after the half-second charge")
for _,mode in ipairs({"Immediate","Release"}) do
	local tuning=table.clone(Config); tuning.TurboActivation=mode
	for _,hz in ipairs({30,60,120}) do
		for _,epoch in ipairs({0,1800000000}) do
			local label=mode.." / "..hz.."Hz / "..epoch
			local s=state(); s.drift=true
			local frames=math.floor(tuning.DriftChargeTime*hz+0.5)
			for n=1,frames-1 do Dynamics.updateBoost(s,epoch+n/hz,1/hz,true,60,tuning) end
			check(not s.turboArmed and s.boostPower==0,"no early activation: "..label)
			local drifting,power=Dynamics.updateBoost(s,epoch+frames/hz,1/hz,true,60,tuning)
			check(drifting,"charge threshold preserves drift: "..label)
			local activationTime
			if mode=="Immediate" then
				activationTime=epoch+tuning.DriftChargeTime
				check(power==tuning.TurboPower and not s.turboArmed and s.charge==0,"fires in threshold frame while held: "..label)
			else
				check(power==0 and s.turboArmed and s.charge==tuning.DriftChargeTime,"threshold arms without firing: "..label)
			end
			local releaseTime=epoch+0.75
			for n=frames+1,math.floor(0.75*hz) do Dynamics.updateBoost(s,epoch+n/hz,1/hz,true,60,tuning) end
			if mode=="Release" then check(s.turboArmed and s.boostPower==0 and s.cooldown==0,"holding armed drift never fires: "..label) end
			s.drift=false; s.steer=0 -- natural simultaneous Shift + turn-key release
			local _,released=Dynamics.updateBoost(s,releaseTime,1/hz,true,60,tuning)
			if mode=="Release" then activationTime=releaseTime end
			check(released==tuning.TurboPower and not s.turboArmed and s.charge==0,"release is compatible with mode: "..label)
			local deadline,boostEnd=s.cooldown,s.boostEnd
			check(math.abs(boostEnd-activationTime-tuning.TurboDuration)<1e-6,"finite boost deadline: "..label)
			check(math.abs(deadline-activationTime-tuning.TurboCooldown)<1e-6,"cooldown starts at activation: "..label)
			Dynamics.updateBoost(s,releaseTime+1/hz,1/hz,true,60,tuning)
			check(s.cooldown==deadline and s.boostEnd==boostEnd,"repeat release cannot extend turbo: "..label)
			local _,expired=Dynamics.updateBoost(s,boostEnd,1/hz,true,60,tuning)
			check(expired==0,"turbo expires exactly at deadline: "..label)
			s.drift=true; s.steer=1
			Dynamics.updateBoost(s,deadline-0.01,1/hz,true,60,tuning)
			check(s.charge==0 and not s.turboArmed,"no cooldown precharge: "..label)
			Dynamics.updateBoost(s,deadline,1/hz,true,60,tuning)
			check(s.charge==0 and s.boostPower==0,"cooldown boundary gives no free charge: "..label)
			for n=1,frames do Dynamics.updateBoost(s,deadline+n/hz,1/hz,true,60,tuning) end
			if mode=="Immediate" then
				check(s.boostPower==tuning.TurboPower,"held drift retriggers only after fresh charge: "..label)
			else
				check(s.turboArmed and s.boostPower==0,"fresh charge arms after cooldown: "..label)
				s.drift=false; s.steer=0
				local _,second=Dynamics.updateBoost(s,deadline+(frames+1)/hz,1/hz,true,60,tuning)
				check(second==tuning.TurboPower,"consecutive earned releases work: "..label)
			end
			s=state(); s.drift=true
			for n=1,math.floor(0.25*hz) do Dynamics.updateBoost(s,epoch+n/hz,1/hz,true,60,tuning) end
			s.drift=false; s.steer=0
			local _,partial=Dynamics.updateBoost(s,epoch+0.25+1/hz,1/hz,true,60,tuning)
			check(partial==0 and s.charge==0 and not s.turboArmed and s.cooldown==0,"quarter-second release gives no reward: "..label)
		end
	end
	for _,condition in ipairs({{false,60,1},{true,0,1},{true,-40,1},{true,60,0}}) do
		local s=state(); s.drift=true; s.charge=0.2; s.steer=condition[3]
		local drifting,power=Dynamics.updateBoost(s,1,1/60,condition[1],condition[2],tuning)
		check(not drifting and power==0 and s.charge==0,"invalid held drift clears partial charge: "..mode)
	end
	local s=state(); s.player=nil; s.drift=true; s.charge=tuning.DriftChargeTime; s.turboArmed=true; s.boostEnd=5; s.boostPower=32; s.cooldown=9
	local _,empty=Dynamics.updateBoost(s,1,1/60,true,60,tuning)
	check(empty==0 and s.charge==0 and not s.turboArmed and s.boostEnd==0,"no-driver clears charge and boost: "..mode)
	check(s.cooldown==9,"no-driver preserves cooldown: "..mode)
	s=state(); s.drift=true
	Dynamics.updateBoost(s,10,10,true,60,tuning)
	check(s.charge<=1/15+1e-10 and not s.turboArmed and s.boostPower==0,"long stall cannot instantly charge: "..mode)
	for _,invalid in ipairs({-1,math.huge,0/0}) do
		s=state(); s.drift=true
		Dynamics.updateBoost(s,1,invalid,true,60,tuning)
		check(s.charge==0 and not s.turboArmed,"invalid elapsed time cannot charge: "..mode)
	end
	s=state(); s.drift=true; s.cooldown=1800000010.017
	Dynamics.updateBoost(s,1800000010.02,1/30,true,60,tuning)
	check(s.charge>0.002 and s.charge<0.004,"epoch boundary credits only eligible tail: "..mode)
	s=state(); s.drift=true; s.boostEnd=10.01; s.boostPower=tuning.TurboPower; s.cooldown=9
	Dynamics.updateBoost(s,10,1/30,true,60,tuning)
	check(s.charge==0 and not s.turboArmed,"active turbo blocks charge: "..mode)
	s=state(); s.turbo=true
	Dynamics.updateBoost(s,5,1/60,true,60,tuning)
	check(s.boostPower==0 and s.charge==0,"legacy manual input cannot trigger turbo: "..mode)
end
-- Release mode permits simultaneous Shift/turn release after a valid drift,
-- while losing steering on an earlier held frame still cancels the armed charge.
local releaseConfig=table.clone(Config); releaseConfig.TurboActivation="Release"
for _,condition in ipairs({{false,60},{true,0},{true,-40}}) do
	local s=state(); s.drift=false; s.charge=releaseConfig.DriftChargeTime; s.turboArmed=true; s.wasDrift=true
	local _,power=Dynamics.updateBoost(s,1,1/60,condition[1],condition[2],releaseConfig)
	check(power==0 and not s.turboArmed and s.charge==0,"air/slow/reverse release cannot cash in armed turbo")
end
local s=state(); s.drift=true; s.charge=releaseConfig.DriftChargeTime; s.turboArmed=true; s.wasDrift=true; s.steer=0
Dynamics.updateBoost(s,1,1/60,true,60,releaseConfig)
s.drift=false; s.steer=1
local _,lateRelease=Dynamics.updateBoost(s,1.1,1/60,true,60,releaseConfig)
check(lateRelease==0 and not s.turboArmed,"straightening before key release discards armed charge")
s=state(); s.drift=false; s.charge=releaseConfig.DriftChargeTime; s.turboArmed=true; s.wasDrift=false
local _,stale=Dynamics.updateBoost(s,1,1/60,true,60,releaseConfig)
check(stale==0,"stale armed state without preceding drift cannot redeem")

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
