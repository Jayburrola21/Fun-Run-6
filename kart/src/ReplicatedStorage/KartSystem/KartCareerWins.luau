-- Server career-win storage. Get never yields; unknown/failed loads remain nil.
-- UpdateAsync merges monotonic per-server-session award watermarks. Retrying a
-- write after an ambiguous response cannot increment twice or erase other servers.
local Career={}
Career.__index=Career

local function count(value)
	if type(value)~="number" or value~=value or math.abs(value)==math.huge or value<0 then return nil end
	return math.floor(value)
end

local function record(value)
	if value==nil then return {version=1,wins=0,sessions={}} end
	if type(value)=="number" then
		local wins=count(value)
		if not wins then return nil end
		return {version=1,wins=wins,sessions={}}
	end
	if type(value)~="table" or count(value.wins)==nil then return nil end
	if value.sessions~=nil and type(value.sessions)~="table" then return nil end
	local sessions={}
	for session,sequence in pairs(value.sessions or {}) do
		if type(session)~="string" or count(sequence)==nil then return nil end
		sessions[session]=count(sequence)
	end
	local copy=table.clone(value)
	copy.version=1; copy.wins=count(value.wins); copy.sessions=sessions
	return copy
end

local function identity(player)
	local id=type(player)=="number" and player or (player and player.UserId)
	if type(id)~="number" or id~=id or math.abs(id)==math.huge or id%1~=0 then return nil end
	return tostring(id)
end

function Career.new(config, deps)
	deps=deps or {}
	local self=setmetatable({},Career)
	self.enabled=config.CareerWinsEnabled~=false
	self.records={}
	self.sequences={}; self.awardIds={}
	self.clock=deps.clock or os.clock
	self.spawn=deps.spawn or task.spawn
	self.wait=deps.wait or task.wait
	self.warning=deps.warn or warn
	self.session=deps.sessionId or game:GetService("HttpService"):GenerateGUID(false)
	self.retryBase=1
	self.closeBudget=math.clamp(config.CareerWinsCloseTimeout or 25,0,25)
	self.name=config.CareerWinsDataStore or "FunRunKartCareerWins_v1"
	self.store=deps.store
	self.factory=deps.storeFactory or function()
		return game:GetService("DataStoreService"):GetDataStore(self.name)
	end
	self.storeNext=0
	self.storeFailures=0
	local bind=deps.bindToClose or function(callback) game:BindToClose(callback) end
	if self.enabled then bind(function() self:Close() end) end
	return self
end

function Career:_getStore()
	if self.store then return self.store end
	if self.clock()<self.storeNext then return nil end
	local ok,value=pcall(self.factory)
	if ok and value then self.store=value; self.storeFailures=0; return value end
	self.storeFailures+=1
	self.storeNext=self.clock()+math.min(60,self.retryBase*2^math.min(self.storeFailures-1,6))
	self.warning("Kart career wins storage unavailable; values remain unknown and pending awards are retained.")
	return nil
end

function Career:_record(player)
	local id=identity(player)
	if not id then return nil end
	local current=self.records[id]
	if not current then
		local known=self.sequences[id] or 0
		self.awardIds[id]=self.awardIds[id] or {}
		current={id=id,loaded=false,wins=nil,nextSeq=known,savedSeq=known,awards=self.awardIds[id],
			nextAttempt=0,failures=0,inFlight=false,removed=false}
		self.records[id]=current
	end
	return current
end

function Career:_prune(current)
	if current.removed and not current.inFlight and current.nextSeq<=current.savedSeq then
		if self.records[current.id]==current then self.records[current.id]=nil end
	end
end

function Career:_queue(current, force)
	if not self.enabled or self.destroyed or current.inFlight then return false end
	local dirty=current.nextSeq>current.savedSeq
	if current.loaded and not dirty then self:_prune(current); return false end
	if not force and self.clock()<current.nextAttempt then return false end
	local store=self:_getStore()
	if not store then return false end
	current.inFlight=true
	local target=current.nextSeq
	self.spawn(function()
		local ok,value=pcall(function()
			if target>current.savedSeq then
				return store:UpdateAsync("u_"..current.id,function(previous)
					local data=record(previous)
					if not data then error("Invalid stored career-win record; refusing to overwrite it") end
					local applied=data.sessions[self.session] or 0
					local delta=math.max(target-applied,0)
					data.wins+=delta
					data.sessions[self.session]=math.max(applied,target)
					return data
				end)
			end
			return store:GetAsync("u_"..current.id)
		end)
		local data=ok and record(value) or nil
		local watermark=data and (data.sessions[self.session] or 0) or 0
		if data and target>current.savedSeq and watermark<target then data=nil end
		if data then
			current.loaded=true
			current.wins=data.wins
			current.savedSeq=math.max(current.savedSeq,watermark)
			current.nextSeq=math.max(current.nextSeq,current.savedSeq)
			self.sequences[current.id]=math.max(self.sequences[current.id] or 0,current.nextSeq)
			current.failures=0; current.nextAttempt=0
		else
			-- Never replace an unknown count with 0 after an access failure,
			-- malformed record or an ambiguous write result.
			current.failures+=1
			current.nextAttempt=self.clock()+math.min(60,self.retryBase*2^math.min(current.failures-1,6))
			if current.failures==1 or current.failures%6==0 then
				self.warning("Kart career wins request failed for user "..current.id.."; pending awards retained for retry.")
			end
		end
		current.inFlight=false
		self:_prune(current)
	end)
	return true
end

function Career:Track(player)
	if not self.enabled or self.destroyed or self.closing then return end
	local current=self:_record(player)
	if not current then return end
	current.removed=false
	self:_queue(current,false)
end

function Career:Get(player)
	if not self.enabled then return nil end
	local id=identity(player)
	local current=id and self.records[id]
	if not current or not current.loaded then return nil end
	-- Confirmed storage plus actual locally earned awards still awaiting a save.
	return current.wins+math.max(current.nextSeq-current.savedSeq,0)
end

function Career:Award(player, awardId)
	if not self.enabled or self.destroyed or self.closing or type(awardId)~="string" or #awardId==0 then return false end
	local current=self:_record(player)
	if not current or current.awards[awardId] then return false end
	current.awards[awardId]=true
	current.nextSeq+=1
	self.sequences[current.id]=current.nextSeq
	self:_queue(current,false)
	return true
end

function Career:Flush(player)
	local id=identity(player)
	local current=id and self.records[id]
	return current and self:_queue(current,true) or false
end

function Career:Update(_dt)
	if not self.enabled or self.destroyed then return end
	for _,current in pairs(self.records) do self:_queue(current,false) end
end

function Career:Remove(player)
	local id=identity(player)
	local current=id and self.records[id]
	if not current then return end
	current.removed=true
	self:_queue(current,true)
	self:_prune(current)
	-- Failed dirty records deliberately remain queued after the Player is gone.
end

function Career:Close()
	if not self.enabled or self.destroyed or self.closing then return end
	self.closing=true
	local deadline=self.clock()+self.closeBudget
	for _,current in pairs(self.records) do
		if current.nextSeq>current.savedSeq then self:_queue(current,true) end
	end
	while self.clock()<deadline do
		local pending=false
		for _,current in pairs(self.records) do
			if current.nextSeq>current.savedSeq then
				pending=true
				self:_queue(current,false)
			end
		end
		if not pending then return end
		self.wait(0.1)
	end
	local unsaved=0
	for _,current in pairs(self.records) do unsaved+=math.max(current.nextSeq-current.savedSeq,0) end
	if unsaved>0 then
		self.warning("Kart career wins shutdown deadline reached with "..unsaved.." pending award(s). Storage access must be restored; these writes are not confirmed.")
	end
end

function Career:Destroy()
	if self.destroyed then return end
	self:Close()
	self.destroyed=true
end

return Career
