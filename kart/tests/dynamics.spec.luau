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
print(string.format("PASS: %d dynamics assertions (30/60/120 Hz)",count))
