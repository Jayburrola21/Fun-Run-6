-- Pure server race rules. No client can submit checkpoint, coin or finish events.
local Rules = {}

function Rules.counter(value)
	if type(value)~="number" or value~=value or math.abs(value)==math.huge or value<0 then return nil end
	return math.floor(value)
end

function Rules.new()
	return {started=false,expected=1,lap=0,completed=0,finished=false,coins=0,wins=0,collected={}}
end

function Rules.visit(state, order, checkpointCount, totalLaps)
	if state.finished or order~=state.expected or checkpointCount<2 or totalLaps<1 then return nil end
	if not state.started then
		if order~=1 then return nil end
		state.started=true; state.lap=state.completed+1; state.expected=2
		return "start"
	end
	if order==1 then
		state.completed+=1
		if state.completed>=totalLaps then
			state.finished=true; state.lap=totalLaps
			return "finish"
		end
		state.lap=state.completed+1; state.expected=2
		return "lap"
	end
	state.expected=order==checkpointCount and 1 or order+1
	return "checkpoint"
end

function Rules.resetRoute(state)
	if state.finished then return end
	state.started=false; state.expected=1; state.lap=state.completed
end

function Rules.claimWinner(round, userId)
	if round.winner~=nil then return false end
	round.winner=userId
	return true
end

function Rules.collect(state, coin, value)
	value=Rules.counter(value)
	if not value or value<1 or state.finished or state.collected[coin] then return false end
	state.collected[coin]=true; state.coins+=value
	return true
end

function Rules.inside(point, half)
	return math.abs(point.X)<=half.X and math.abs(point.Y)<=half.Y and math.abs(point.Z)<=half.Z
end

-- Slab intersection returns when a swept server position enters a gate.
-- A driver already inside a gate cannot repeatedly trigger it while parked.
function Rules.entry(previous, current, half)
	if not previous then return Rules.inside(current,half) and 0 or nil end
	if Rules.inside(previous,half) then return nil end
	local enter,leave=0,1
	for _,axis in ipairs({"X","Y","Z"}) do
		local origin=previous[axis]
		local delta=current[axis]-origin
		if math.abs(delta)<1e-9 then
			if math.abs(origin)>half[axis] then return nil end
		else
			local a,b=(-half[axis]-origin)/delta,(half[axis]-origin)/delta
			if a>b then a,b=b,a end
			enter=math.max(enter,a); leave=math.min(leave,b)
			if enter>leave then return nil end
		end
	end
	return enter
end

return table.freeze(Rules)
