-- Server seat lifecycle. A living driver stays assigned until legitimate cleanup.
-- Dependency injection lets the lifecycle run against deterministic test doubles.
local SeatLock = {}
SeatLock.__index = SeatLock

function SeatLock.new(seat, humanoid, valid, onRelease, scheduler)
	local self=setmetatable({},SeatLock)
	self.seat=seat; self.humanoid=humanoid
	self.valid=valid; self.onRelease=onRelease; self.scheduler=scheduler or task
	self.released=false; self.pending=false
	self.original={power=humanoid.JumpPower,height=humanoid.JumpHeight,
		jumping=humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping),
		gettingUp=humanoid:GetStateEnabled(Enum.HumanoidStateType.GettingUp)}
	humanoid.JumpPower=0; humanoid.JumpHeight=0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp,false)
	local function checkAlive()
		if not self:IsAlive() and not self.released then
			self:Release()
			onRelease()
		end
	end
	self.connections={
		humanoid.Died:Connect(checkAlive),
		humanoid.AncestryChanged:Connect(checkAlive),
		seat.AncestryChanged:Connect(checkAlive),
	}
	return self
end

function SeatLock:IsAlive()
	return not self.released and self.seat.Parent~=nil and self.humanoid.Parent~=nil
		and self.humanoid.Health>0 and self.valid()
end

function SeatLock:Enforce()
	if not self:IsAlive() then return false end
	if self.seat.Occupant==self.humanoid or self.pending then return true end
	self.pending=true
	if self.seat.Occupant then self.seat.Occupant.Sit=false end
	self.scheduler.delay(0.08,function()
		if self:IsAlive() and self.seat.Occupant~=self.humanoid then
			self.humanoid.Jump=false
			self.seat:Sit(self.humanoid)
		end
		self.pending=false
		-- If Sit is temporarily refused by the engine, the next simulation
		-- update retries. No unbounded deferred loop or duplicate driver state.
	end)
	return true
end

function SeatLock:Release()
	if self.released then return end
	self.released=true
	for _,connection in ipairs(self.connections or {}) do connection:Disconnect() end
	local humanoid=self.humanoid
	if humanoid.Parent then
		humanoid.JumpPower=self.original.power; humanoid.JumpHeight=self.original.height
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,self.original.jumping)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp,self.original.gettingUp)
	end
end

return SeatLock
