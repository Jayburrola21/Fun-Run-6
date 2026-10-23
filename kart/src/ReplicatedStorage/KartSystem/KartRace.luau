-- Server-authoritative six-racer match, standings and actual course snapshot.
local Players=game:GetService("Players")
local HttpService=game:GetService("HttpService")
local Rules=require(script.Parent.KartRaceRules)
local Career=require(script.Parent.KartCareerWins)
local Race={}
Race.__index=Race
local fields={Lap="KartLap",TotalLaps="KartTotalLaps",Coins="KartCoins",Wins="KartWins"}
local defaults={Lap={"Lap","CurrentLap"},TotalLaps={"TotalLaps","MaxLaps"},Coins={"Coins"},Wins={"Wins","Trophies"}}
local progressDefaults={Checkpoint={"RaceCheckpoint","Checkpoint"},CompletedLaps={"RaceCompletedLaps","CompletedLaps"},Progress={"RaceSegmentProgress","SegmentProgress"},Finished={"RaceFinished"},FinishOrder={"RaceFinishOrder"}}
local reserved={KartLap=true,KartTotalLaps=true,KartCoins=true,KartWins=true,KartPlace=true}

local function binding(player,field,config,progress)
	local definitions=progress and progressDefaults or defaults
	local configured=progress and config.RaceProgressBinding or config.RaceStatNames
	local names=(configured and configured[field]) or definitions[field]
	if type(names)=="string" then names={names} end
	if type(names)~="table" then names=definitions[field] end
	local stats=player:FindFirstChild("leaderstats")
	local function valid(raw)
		if field=="Finished" then if type(raw)=="boolean" then return raw end; return nil end
		if field=="Progress" then
			return type(raw)=="number" and raw==raw and raw>=0 and raw<=1 and raw or nil
		end
		local value=Rules.counter(raw)
		if value~=nil and (field~="TotalLaps" and field~="FinishOrder" or value>=1) and (not progress or value==raw) then return value end
		return nil
	end
	for _,name in ipairs(names or {}) do
		if type(name)=="string" and not reserved[name] then
			local value=valid(player:GetAttribute(name))
			if value~=nil then return value end
			local stat=stats and stats:FindFirstChild(name)
			if stat and (stat:IsA("IntValue") or stat:IsA("NumberValue") or stat:IsA("BoolValue")) then
				value=valid(stat.Value)
				if value~=nil then return value end
			end
		end
	end
	return nil
end

local function folder(parent,name)
	local value=Instance.new("Folder"); value.Name=name; value.Parent=parent
	return value
end
local function attribute(object,name,value)
	if object:GetAttribute(name)~=value then object:SetAttribute(name,value) end
end
local function ordered(parent)
	local result,count={},0
	if not parent then return nil end
	for _,part in ipairs(parent:GetChildren()) do
		if part:IsA("BasePart") then
			local raw=part:GetAttribute("Order")
			if raw==nil then raw=tonumber(part.Name) end
			local order=Rules.counter(raw)
			if not order or order<1 or order~=raw or result[order] then return nil end
			result[order]=part; count+=1
		end
	end
	if count<2 or count>500 then return nil end
	for index=1,count do if not result[index] then return nil end end
	return result
end

function Race.new(config,dependencies)
	dependencies=dependencies or {}
	local self=setmetatable({config=config,elapsed=0,refresh=0,states={},positions={},round={},
		checkpoints={},coins={},admitted={},serial=0,activeDrivers={},rows={},pathRevision=0},Race)
	self.maxRacers=math.clamp(Rules.counter(config.RaceMaxRacers) or 6,1,6)
	self.career=dependencies.career or Career.new(config)
	local existing=script.Parent:FindFirstChild("RaceState")
	if existing then existing:Destroy() end
	self.snapshot=folder(script.Parent,"RaceState")
	self.pathFolder=folder(self.snapshot,"Path"); self.racerFolder=folder(self.snapshot,"Racers")
	self.removing=Players.PlayerRemoving:Connect(function(player)
		self:ReleaseAdmission(player)
		self.career:Remove(player)
		self.states[player]=nil; self.positions[player]=nil
	end)
	self:_refresh()
	return self
end

function Race:_state(player)
	if not self.states[player] then self.states[player]=Rules.new() end
	return self.states[player]
end

function Race:CanJoin(player)
	if self.destroyed or not player or player.Parent~=Players then return false end
	if self.admitted[player] then return true end
	local count=self.round.finishCount or 0
	for racer in pairs(self.admitted) do if not self:_state(racer).finishOrder then count+=1 end end
	return count<self.maxRacers
end

function Race:TryJoin(player)
	if not self:CanJoin(player) then return false end
	if self.admitted[player] then return true end
	self.serial+=1; self.admitted[player]=self.serial
	self:_state(player)
	local row=folder(self.racerFolder,tostring(player.UserId))
	row:SetAttribute("UserId",player.UserId); row:SetAttribute("Active",true)
	self.rows[player]=row
	attribute(player,"KartRaceAdmitted",true)
	return true
end

function Race:ReleaseAdmission(player)
	self.admitted[player]=nil; self.positions[player]=nil; self.activeDrivers[player]=nil
	if self.rows[player] then self.rows[player]:Destroy(); self.rows[player]=nil end
	attribute(player,"KartRaceAdmitted",false); attribute(player,"KartPlace",nil)
end

function Race:ResetRound()
	self.round={finishCount=0,finishOwners={}}
	self.roundId=HttpService:GenerateGUID(false)
	self.positions={}
	for player,state in pairs(self.states) do
		local fresh=Rules.new(); fresh.coins=state.coins
		-- A provider must actually reset its progress before its previous finish
		-- can be consumed in a new round. Never write to another race's stats.
		local external=self:_externalProgress(player,binding(player,"TotalLaps",self.config) or self.total)
		fresh.externalFinishBlocked=state.externalFinishBlocked or state.externalFinished==true or (external and external.finished) or false
		self.states[player]=fresh
	end
	local inactive={}
	for player in pairs(self.admitted) do if not self.activeDrivers[player] then table.insert(inactive,player) end end
	for _,player in ipairs(inactive) do self:ReleaseAdmission(player) end
	attribute(self.snapshot,"RoundId",self.roundId)
	attribute(self.snapshot,"WinnerUserId",nil)
end

function Race:_refresh()
	local course=workspace:FindFirstChild("KartRace")
	local checkpoints=ordered(course and course:FindFirstChild("Checkpoints"))
	local pathParts=ordered(course and course:FindFirstChild("Path"))
	local source=pathParts and "Path" or "Checkpoints"
	local points,gates={},{}
	if checkpoints then
		for _,part in ipairs(checkpoints) do table.insert(gates,part.Position) end
		for _,part in ipairs(pathParts or checkpoints) do table.insert(points,part.Position) end
	end
	local width=self.config.RaceTrackWidth or 18
	local track=checkpoints and Rules.track(points,gates,width) or nil
	local valid=track~=nil
	local total=Rules.counter(course and course:GetAttribute("TotalLaps"))
	if not total or total<1 then total=Rules.counter(self.config.RaceTotalLaps) or 3 end
	total=math.max(total,1)
	local changed=self.course~=course or self.total~=total or self.hasCourse~=valid
	if not changed and valid then
		if #self.checkpoints~=#checkpoints or not self.track or #self.track.points~=#track.points then changed=true
		else
			for index,part in ipairs(checkpoints) do if self.checkpoints[index]~=part then changed=true; break end end
			if not changed then for index,point in ipairs(track.points) do
				if (point-self.track.points[index]).Magnitude>0.01 then changed=true; break end
			end end
		end
	end
	local coins={}
	local coinFolder=course and course:FindFirstChild("Coins")
	if coinFolder then for _,part in ipairs(coinFolder:GetChildren()) do if part:IsA("BasePart") then table.insert(coins,part) end end end
	self.course=course; self.hasCourse=valid; self.hasCoins=coinFolder~=nil
	self.checkpoints=valid and checkpoints or {}; self.track=track; self.coins=coins; self.total=total
	attribute(self.snapshot,"CourseValid",valid); attribute(self.snapshot,"TotalLaps",total)
	attribute(self.snapshot,"PathSource",valid and source or nil)
	if changed then
		for _,child in ipairs(self.pathFolder:GetChildren()) do child:Destroy() end
		if valid then for index,point in ipairs(track.points) do
			local item=Instance.new("Vector3Value"); item.Name=string.format("%03d",index); item.Value=point
			item:SetAttribute("PathRevision",self.pathRevision+1); item.Parent=self.pathFolder
		end end
		attribute(self.snapshot,"PathPointCount",valid and #track.points or 0)
		self.pathRevision+=1; attribute(self.snapshot,"PathRevision",self.pathRevision)
		self:ResetRound()
	end
end

function Race:_externalProgress(player,total)
	if not self.hasCourse then return nil end
	local checkpoint=binding(player,"Checkpoint",self.config,true)
	local completed=binding(player,"CompletedLaps",self.config,true)
	local fraction=binding(player,"Progress",self.config,true)
	if not checkpoint or checkpoint<1 or checkpoint>#self.checkpoints or not completed or completed>total or fraction==nil then return nil end
	return {completed=completed,checkpoint=checkpoint,fraction=fraction,
		finished=binding(player,"Finished",self.config,true)==true or completed>=total,
		finishOrder=binding(player,"FinishOrder",self.config,true)}
end

function Race:_rank(player,position)
	local state=self:_state(player)
	local total=binding(player,"TotalLaps",self.config) or self.total
	local external=self:_externalProgress(player,total)
	if external and external.finished and state.externalFinishBlocked then external=nil end
	local checkpoint=state.started and (state.expected==1 and #self.checkpoints or state.expected-1) or 0
	local completed=state.completed
	local fraction=0
	if external then
		checkpoint=external.checkpoint; completed=external.completed; fraction=external.fraction
	elseif checkpoint>0 then
		local sameLeg=state.rankCheckpoint==checkpoint and state.rankCompleted==completed
		local projected,distance=Rules.trackProgress(self.track,checkpoint,position,
			sameLeg and state.rankDistance or nil,self.config.RaceTrackWidth or 18)
		if projected~=nil then fraction=projected; state.rankDistance=distance
		elseif sameLeg then fraction=state.rankFraction or 0 end
	end
	state.rankCheckpoint=checkpoint; state.rankCompleted=completed; state.rankFraction=fraction
	return {player=player,serial=self.admitted[player],userId=player.UserId,completed=completed,
		checkpoint=checkpoint,fraction=fraction,finishOrder=state.finishOrder,external=external,total=total}
end

function Race:_values(player)
	local state=self:_state(player)
	local rank=state.rank
	local lap=binding(player,"Lap",self.config)
	local total=binding(player,"TotalLaps",self.config)
	if rank and self.hasCourse then
		total=total or rank.total
		if lap==nil then lap=rank.finishOrder and total or math.min(rank.completed+(rank.checkpoint>0 and 1 or 0),total) end
	else
		if self.hasCourse and self.admitted[player] then lap=lap or state.lap; total=total or self.total end
	end
	local coins=binding(player,"Coins",self.config)
	if coins==nil and self.hasCoins then coins=state.coins end
	local wins=binding(player,"Wins",self.config)
	if wins==nil then self.career:Track(player); wins=self.career:Get(player) end
	return {Lap=lap,TotalLaps=total,Coins=coins,Wins=wins}
end

function Race:_publish(player)
	local values=self:_values(player)
	for field,name in pairs(fields) do attribute(player,name,values[field]) end
	local state=self:_state(player)
	attribute(player,"KartPlace",self.admitted[player] and self.hasCourse and state.place or nil)
	local row=self.rows[player]
	if row then
		attribute(row,"Active",true); attribute(row,"Place",self.hasCourse and state.place or nil)
		attribute(row,"Position",state.position)
		for field,value in pairs(values) do attribute(row,field,value) end
		-- pairs omits nil fields; remove stale unknown data explicitly.
		for field in pairs(fields) do attribute(row,field,values[field]) end
	end
end

function Race:Update(karts,dt)
	if self.destroyed then return end
	self.career:Update(dt)
	self.elapsed+=math.max(0,dt); self.refresh+=math.max(0,dt)
	if self.elapsed<0.1 then return end
	local sample=self.elapsed; self.elapsed=0
	if self.refresh>=1 then self.refresh=0; self:_refresh() end
	local active,candidates,finishers={},{},{}
	for _,kart in ipairs(karts) do
		local player=kart.player
		local occupant=kart.seat and kart.seat.Occupant
		if player and player.Parent==Players and occupant and occupant.Health>0 and player.Character==occupant.Parent
			and kart.chassis and kart.chassis:IsDescendantOf(workspace) and Rules.finiteVector(kart.chassis.Position) then
			table.insert(candidates,kart)
		end
	end
	table.sort(candidates,function(a,b) return a.player.UserId<b.player.UserId end)
	-- A Lap-only provider owns a different race whose ordering is unknown.
	-- Latch this round unavailable; resetting after the provider supplies its
	-- complete progress schema gives every participant a coherent fresh race.
	for _,kart in ipairs(candidates) do self:TryJoin(kart.player) end
	for player in pairs(self.admitted) do
		if binding(player,"Lap",self.config)~=nil and not self:_externalProgress(player,binding(player,"TotalLaps",self.config) or self.total) then
			self.round.progressBlocked=true
		end
	end
	local standingsValid=self.hasCourse and not self.round.progressBlocked
	attribute(self.snapshot,"StandingsValid",standingsValid)
	for _,kart in ipairs(candidates) do
		local player=kart.player
		if self:TryJoin(player) then
			active[player]=true
			local state=self:_state(player)
			local position=kart.chassis.Position; state.position=position
			local previous=self.positions[player]
			local limit=((self.config.MaxSpeed or 82)+(self.config.TurboPower or 32)+20)*sample+12
			local teleported=previous and (position-previous).Magnitude>limit*2
			if teleported then previous=nil; Rules.resetRoute(state); state.rankCheckpoint=nil; state.rankDistance=nil end
			if not teleported and self.hasCourse then
				local external=self:_externalProgress(player,binding(player,"TotalLaps",self.config) or self.total)
				local ownsIncomplete=binding(player,"Lap",self.config)~=nil and not external
				if external then
					if not external.finished then state.externalFinishBlocked=false end
					state.externalFinished=external.finished
				end
				if state.externalActive and not external then Rules.resetRoute(state); state.rankDistance=nil end
				state.externalActive=external~=nil
				local events={}
				for order,gate in ipairs(self.checkpoints) do
					if gate:IsDescendantOf(workspace) then
						local entered=Rules.entry(previous and gate.CFrame:PointToObjectSpace(previous) or nil,
							gate.CFrame:PointToObjectSpace(position),gate.Size/2)
						if entered then table.insert(events,{order=order,time=entered}) end
					end
				end
				table.sort(events,function(a,b) return a.time==b.time and a.order<b.order or a.time<b.time end)
				for _,event in ipairs(events) do
					if not external and not ownsIncomplete and Rules.visit(state,event.order,#self.checkpoints,binding(player,"TotalLaps",self.config) or self.total)=="finish" and not state.finishOrder then
						table.insert(finishers,{player=player,state=state,time=event.time})
					end
				end
				if external and external.finished and not state.externalFinishBlocked and not state.finishOrder then
					state.finished=true
					table.insert(finishers,{player=player,state=state,time=external.finishOrder or math.huge,provided=external.finishOrder})
				end
			end
			if self.hasCoins and binding(player,"Coins",self.config)==nil then
				for _,coin in ipairs(self.coins) do
					if coin:IsDescendantOf(workspace) then
						local nearest=position
						if previous then
							local direction=position-previous; local squared=direction:Dot(direction)
							if squared>1e-9 then nearest=previous+direction*math.clamp((coin.Position-previous):Dot(direction)/squared,0,1) end
						end
						if (nearest-coin.Position).Magnitude<=(self.config.RaceCoinPickupRadius or 3.5) then Rules.collect(state,coin,coin:GetAttribute("Value") or 1) end
					end
				end
			end
			self.positions[player]=position
		end
	end
	self.activeDrivers=active
	table.sort(finishers,function(a,b) return a.time==b.time and a.player.UserId<b.player.UserId or a.time<b.time end)
	for _,finisher in ipairs(finishers) do
		if standingsValid and not finisher.state.finishOrder then
			local order=finisher.provided or 1
			if not finisher.provided then while self.round.finishOwners[order] do order+=1 end end
			if order<=self.maxRacers and not self.round.finishOwners[order] then
				self.round.finishCount=(self.round.finishCount or 0)+1
				self.round.finishOwners[order]=finisher.player.UserId
				finisher.state.finishOrder=order
				if order==1 and Rules.claimWinner(self.round,finisher.player.UserId) then
					attribute(self.snapshot,"WinnerUserId",finisher.player.UserId)
					if binding(finisher.player,"Wins",self.config)==nil then self.career:Award(finisher.player,self.roundId..":"..tostring(finisher.player.UserId)) end
				end
			end
		end
	end

	for player in pairs(self.positions) do
		if not active[player] then self.positions[player]=nil; Rules.resetRoute(self:_state(player)) end
	end
	local standings={}
	for player in pairs(self.admitted) do
		local state=self:_state(player)
		if standingsValid and state.position then
			local rank=self:_rank(player,state.position); state.rank=rank
			table.insert(standings,rank)
		else state.place=nil; state.rank=nil end
	end
	table.sort(standings,Rules.ahead)
	local unfinished=0
	for _,rank in ipairs(standings) do
		if rank.finishOrder then self:_state(rank.player).place=rank.finishOrder
		else
			unfinished+=1
			while self.round.finishOwners[unfinished] do unfinished+=1 end
			self:_state(rank.player).place=unfinished
		end
	end
	for _,player in ipairs(Players:GetPlayers()) do self:_publish(player) end
end

function Race:Destroy()
	if self.destroyed then return end
	self.destroyed=true; self.removing:Disconnect()
	self.career:Destroy()
	for _,player in ipairs(Players:GetPlayers()) do
		for _,name in pairs(fields) do player:SetAttribute(name,nil) end
		player:SetAttribute("KartPlace",nil); player:SetAttribute("KartRaceAdmitted",false)
	end
	self.snapshot:Destroy()
	table.clear(self.states); table.clear(self.positions); table.clear(self.admitted)
end

return Race
