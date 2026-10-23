local count=0
local function check(value,message) assert(value,message); count+=1 end
local radius=0.96*0.84
for _,hz in ipairs({30,60,120}) do
	for _,speed in ipairs({60,-30,100}) do
		local phase,filtered=0,0
		for _=1,hz do phase,filtered=Presentation.wheel(phase,filtered,speed,radius,1/hz) end
		local distance=speed-speed*(1-math.exp(-16))/16
		local expected=(-distance/radius)%(2*math.pi)
		check(math.abs(phase-expected)<1e-9,"velocity/radius spin matches elapsed motion at "..hz)
		check(math.abs(filtered-speed)<0.0001,"visual speed settles at "..hz)
		local stopped,newSpeed=Presentation.wheel(phase,filtered,0,radius,1/hz)
		check(stopped==phase and newSpeed==0,"stationary wheels stop without lingering spin")
		local noisy,noiseSpeed=Presentation.wheel(phase,filtered,0.02,radius,1/hz)
		check(noisy==phase and noiseSpeed==0,"replication noise cannot rumble parked wheels")
	end
end
local forward=Presentation.wheel(0,0,10,radius,1/60)
local reverse=Presentation.wheel(0,0,-10,radius,1/60)
check(forward>math.pi and reverse<math.pi,"forward and reverse spin in opposite directions")
local large=Presentation.wheel(0,20,20,radius,1/60)
local small=Presentation.wheel(0,20,20,radius/2,1/60)
check(math.abs((2*math.pi-small)-2*(2*math.pi-large))<1e-9,"actual tire radius controls spin")
for _,dt in ipairs({-1,0/0,math.huge,1}) do
	local phase,speed=Presentation.wheel(0,0,40,radius,dt)
	check(phase==phase and speed==speed and phase>=0 and phase<2*math.pi,"stalled/invalid render deltas stay finite")
end
check(Presentation.delta(1/30)==1/30,"normal frame time remains unchanged")
check(Presentation.delta(2)==0.1,"resume after stall cannot jump many wheel revolutions")
print(string.format("PASS: %d visual wheel-motion assertions (30/60/120Hz; engine unrun)",count))
