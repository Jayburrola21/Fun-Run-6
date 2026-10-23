-- Exercises the actual SeatLock module with fake signals/scheduling, not Roblox.
local count=0
local function check(condition,message) assert(condition,message); count+=1 end
local function signal()
	local listeners={}
	return {
		Connect=function(_,callback)
			local connection={Connected=true}
			function connection:Disconnect() self.Connected=false end
			table.insert(listeners,{connection,callback})
			return connection
		end,
		Fire=function(_,...)
			for _,listener in ipairs(listeners) do if listener[1].Connected then listener[2](...) end end
		end,
	}
end
local function fixture(jumping,gettingUp)
	local states={Jumping=jumping,GettingUp=gettingUp}
	local humanoid={Parent={},Health=100,JumpPower=51.5,JumpHeight=8.25,Died=signal(),AncestryChanged=signal(),Sit=true}
	function humanoid:GetStateEnabled(state) return states[state] end
	function humanoid:SetStateEnabled(state,enabled) states[state]=enabled end
	local seat={Parent={},Occupant=humanoid,AncestryChanged=signal(),attempts=0,refuse=false}
	function seat:Sit(driver) self.attempts+=1; if not self.refuse then self.Occupant=driver; driver.Sit=true end end
	local queue={}
	local scheduler={delay=function(seconds,callback) assert(seconds>=0.08); table.insert(queue,callback) end}
	local valid=true
	local released=0
	local lock=SeatLock.new(seat,humanoid,function() return valid end,function() released+=1 end,scheduler)
	return {lock=lock,seat=seat,humanoid=humanoid,states=states,queue=queue,
		setValid=function(value) valid=value end,releases=function() return released end,
		flush=function() local callbacks=table.clone(queue); table.clear(queue); for _,callback in ipairs(callbacks) do callback() end end}
end
local f=fixture(true,false)
check(f.humanoid.JumpPower==0 and f.humanoid.JumpHeight==0,"jump values disabled")
check(not f.states.Jumping and not f.states.GettingUp,"jump and get-up states disabled")
check(f.lock:Enforce() and #f.queue==0,"occupied owner stays assigned without redundant scheduling")
f.seat.Occupant=nil; f.humanoid.Sit=false
for _=1,20 do check(f.lock:Enforce(),"living driver remains retained") end
check(#f.queue==1,"only one reseat is pending")
f.flush()
check(f.seat.Occupant==f.humanoid and f.seat.attempts==1,"voluntary unseat reseats original driver")
check(f.releases()==0,"unseating does not run legitimate cleanup")
local intruder={Sit=true}
f.seat.Occupant=intruder
check(f.lock:Enforce() and not intruder.Sit,"intruder cannot replace locked driver")
f.flush()
check(f.seat.Occupant==f.humanoid,"original driver restored after takeover attempt")
f.seat.Occupant=nil; f.lock:Enforce()
f.humanoid.Health=0; f.humanoid.Died:Fire()
check(f.releases()==1 and f.lock.released,"death releases exactly once")
check(f.humanoid.JumpPower==51.5 and f.humanoid.JumpHeight==8.25,"original jump values restored")
check(f.states.Jumping and not f.states.GettingUp,"original state flags restored, including false")
local attempts=f.seat.attempts; f.flush()
check(f.seat.attempts==attempts,"pending callback cannot reseat a dead driver")
f.humanoid.AncestryChanged:Fire(); f.lock:Release()
check(f.releases()==1,"release is idempotent and listeners disconnect")
check(not f.lock:Enforce(),"released seat lock no longer retains driver")

f=fixture(false,true)
f.setValid(false)
check(not f.lock:Enforce(),"character replacement invalidates seat lock")
f.lock:Release()
check(not f.states.Jumping and f.states.GettingUp,"replacement restores custom state flags")
check(f.humanoid.JumpPower==51.5,"replacement restores jump value")

f=fixture(true,true)
f.seat.Occupant=nil; f.lock:Enforce()
f.seat.Parent=nil; f.seat.AncestryChanged:Fire(); f.flush()
check(f.releases()==1 and f.seat.attempts==0,"destroyed seat releases and cancels pending reseat")
check(f.states.Jumping and f.states.GettingUp,"seat destruction restores states")

f=fixture(true,true)
f.seat.Occupant=nil; f.seat.refuse=true
f.lock:Enforce(); f.flush()
check(f.seat.attempts==1 and #f.queue==0,"engine refusal does not create an unbounded deferred loop")
f.seat.refuse=false; f.lock:Enforce(); f.flush()
check(f.seat.Occupant==f.humanoid and f.seat.attempts==2,"next simulation update retries refused seat")
f.lock:Release()

f=fixture(true,true)
f.humanoid.Parent=nil; f.humanoid.AncestryChanged:Fire()
check(f.releases()==1 and not f.lock:IsAlive(),"removed character releases without dereferencing destroyed avatar")
print(string.format("PASS: %d seat-lock lifecycle assertions (test doubles; Studio unrun)",count))
