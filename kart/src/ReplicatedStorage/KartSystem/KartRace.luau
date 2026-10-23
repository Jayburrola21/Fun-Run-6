-- Server bridge to real attributes/leaderstats plus optional checkpoint/coin markers.
-- Unknown data stays nil. This module never writes another race system's stats.
local Players=game:GetService("Players")
local Rules=require(script.Parent.KartRaceRules)
local Race={}
Race.__index=Race
local fields={Lap="KartLap",TotalLaps="KartTotalLaps",Coins="KartCoins",Wins="KartWins"}
local defaults={Lap={"Lap","CurrentLap"},TotalLaps={"TotalLaps","MaxLaps"},Coins={"Coins"},Wins={"Wins","Trophies"}}
local reserved={KartLap=true,KartTotalLaps=true,KartCoins=true,KartWins=true}

local function binding(player, field, config)
	local names=(config.RaceStatNames and config.RaceStatNames[field]) or defaults[field]
	if type(names)=="string" then names={names} end
	if type(names)~="table" then names=defaults[field] end
	local leaderstats=player:FindFirstChild("leaderstats")
	for _,name in ipairs(names) do
		if type(name)=="string" and not reserved[name] then
			local value=Rules.counter(player:GetAttribute(name))
			if value~=nil and (field~="TotalLaps" or value>=1) then return value end
			local stat=leaderstats and leaderstats:FindFirstChild(name)
			if stat and (stat:IsA("IntValue") or stat:IsA("NumberValue")) then
				value=Rules.counter(stat.Value)
				if value~=nil and (field~="TotalLaps" or value>=1) then return value end
			end
		end
	end
	return nil
end

function Race.new(config)
	local self=setmetatable({config=config,elapsed=0,refresh=0,states={},positions={},round={},checkpoints={},coins={}},Race)
	self.removing=Players.PlayerRemoving:Connect(function(player)
		self.states[player]=nil; self.positions[player]=nil
	end)
	self:_refresh()
	return self
end

function Race:_state(player)
	if not self.states[player] then self.states[player]=Rules.new() end
	return self.states[player]
end

function Race:ResetRound()
	self.round={}
	self.positions={}
	for player,state in pairs(self.states) do
		local fresh=Rules.new()
		fresh.coins=state.coins; fresh.wins=state.wins
		self.states[player]=fresh
	end
end

function Race:_refresh()
	local course=workspace:FindFirstChild("KartRace")
	local gates=course and course:FindFirstChild("Checkpoints")
	local coinFolder=course and course:FindFirstChild("Coins")
	local checkpoints,coins={},{}
	local valid=gates~=nil
	if gates then
		for _,part in ipairs(gates:GetChildren()) do
			if part:IsA("BasePart") then
				local raw=part:GetAttribute("Order")
				if raw==nil then raw=tonumber(part.Name) end
				local order=Rules.counter(raw)
				if not order or order<1 or order~=raw or checkpoints[order] then valid=false
				else checkpoints[order]=part end
			end
		end
	end
	local count=0
	for _ in pairs(checkpoints) do count+=1 end
	if count<2 or count>200 then valid=false end
	for order=1,count do if not checkpoints[order] then valid=false end end
	local total=Rules.counter(course and course:GetAttribute("TotalLaps"))
	if not total or total<1 then total=Rules.counter(self.config.RaceTotalLaps) or 3 end
	if total<1 then total=3 end
	local changed=self.course~=course or self.total~=total or self.hasCourse~=valid or #self.checkpoints~=(valid and count or 0)
	if valid and not changed then for index,part in ipairs(checkpoints) do if self.checkpoints[index]~=part then changed=true; break end end end
	if coinFolder then
		for _,part in ipairs(coinFolder:GetChildren()) do if part:IsA("BasePart") then table.insert(coins,part) end end
	end
	self.course=course; self.hasCourse=valid; self.hasCoins=coinFolder~=nil
	self.checkpoints=valid and checkpoints or {}; self.coins=coins; self.total=total
	if changed then self:ResetRound() end
end

function Race:_publish(player)
	local state=self:_state(player)
	local externalLap=binding(player,"Lap",self.config)
	for field,attribute in pairs(fields) do
		local value=binding(player,field,self.config)
		if value==nil then
			if field=="Lap" and self.hasCourse then value=state.lap end
			if field=="TotalLaps" and self.hasCourse and externalLap==nil then value=self.total end
			if field=="Coins" and self.hasCoins then value=state.coins end
			if field=="Wins" and self.hasCourse and externalLap==nil then value=state.wins end
		end
		if player:GetAttribute(attribute)~=value then player:SetAttribute(attribute,value) end
	end
end

function Race:Update(karts, dt)
	if self.destroyed then return end
	self.elapsed+=math.max(0,dt)
	self.refresh+=math.max(0,dt)
	if self.elapsed<0.1 then return end
	local sample=self.elapsed; self.elapsed=0
	if self.refresh>=1 then self.refresh=0; self:_refresh() end
	local active={}
	local finishers={}
	for _,kart in ipairs(karts) do
		local player=kart.player
		local occupant=kart.seat and kart.seat.Occupant
		if player and player.Parent==Players and occupant and occupant.Health>0 and player.Character==occupant.Parent
			and kart.chassis and kart.chassis:IsDescendantOf(workspace) then
			active[player]=true
			local state=self:_state(player)
			local position=kart.chassis.Position
			local previous=self.positions[player]
			-- Ignore void recovery/other teleports as checkpoint sweeps.
			local limit=((self.config.MaxSpeed or 82)+(self.config.TurboPower or 32)+20)*sample+12
			local teleported=previous and (position-previous).Magnitude>limit*2
			if teleported then previous=nil; Rules.resetRoute(state) end
			if not teleported and self.hasCourse and binding(player,"Lap",self.config)==nil then
				local events={}
				for order,gate in ipairs(self.checkpoints) do
					if gate:IsDescendantOf(workspace) then
						local half=gate.Size/2
						local before=previous and gate.CFrame:PointToObjectSpace(previous) or nil
						local after=gate.CFrame:PointToObjectSpace(position)
						local entered=Rules.entry(before,after,half)
						if entered then table.insert(events,{order=order,time=entered}) end
					end
				end
				table.sort(events,function(a,b) return a.time==b.time and a.order<b.order or a.time<b.time end)
				for _,event in ipairs(events) do
					if Rules.visit(state,event.order,#self.checkpoints,binding(player,"TotalLaps",self.config) or self.total)=="finish" then
						table.insert(finishers,{player=player,state=state,time=event.time})
					end
				end
			end
			if self.hasCoins and binding(player,"Coins",self.config)==nil then
				local reach=self.config.RaceCoinPickupRadius or 3.5
				for _,coin in ipairs(self.coins) do
					if coin:IsDescendantOf(workspace) then
						local nearest=position
						if previous then
							local direction=position-previous
							local lengthSquared=direction:Dot(direction)
							if lengthSquared>1e-9 then
								local along=math.clamp((coin.Position-previous):Dot(direction)/lengthSquared,0,1)
								nearest=previous+direction*along
							end
						end
						if (nearest-coin.Position).Magnitude<=reach then Rules.collect(state,coin,coin:GetAttribute("Value") or 1) end
					end
				end
			end
			self.positions[player]=position
		end
	end
	-- Compare swept crossing times across karts, not their iteration/spawn order.
	table.sort(finishers,function(a,b)
		return a.time==b.time and a.player.UserId<b.player.UserId or a.time<b.time
	end)
	if finishers[1] and Rules.claimWinner(self.round,finishers[1].player.UserId) then
		finishers[1].state.wins+=1
	end

	for player in pairs(self.positions) do
		if not active[player] then self.positions[player]=nil; Rules.resetRoute(self:_state(player)) end
	end
	for _,player in ipairs(Players:GetPlayers()) do self:_publish(player) end
end

function Race:Destroy()
	if self.destroyed then return end
	self.destroyed=true
	self.removing:Disconnect()
	for _,player in ipairs(Players:GetPlayers()) do
		for _,attribute in pairs(fields) do player:SetAttribute(attribute,nil) end
	end
	table.clear(self.states); table.clear(self.positions)
end

return Race
