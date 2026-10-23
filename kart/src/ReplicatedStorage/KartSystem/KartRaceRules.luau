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

function Rules.finiteVector(value)
	if value==nil then return false end
	for _,axis in ipairs({"X","Y","Z"}) do
		local n=value[axis]
		if type(n)~="number" or n~=n or math.abs(n)==math.huge then return false end
	end
	return true
end

local function segments(points)
	local result,total={},0
	for index,a in ipairs(points) do
		local b=points[index%#points+1]
		local length=(b-a).Magnitude
		if length>1e-5 then
			table.insert(result,{a=a,b=b,length=length,start=total,finish=total+length})
			total+=length
		end
	end
	return result,total
end

local function project(point,parts,from,to,previous)
	local best
	for _,segment in ipairs(parts) do
		local low=math.max(from,segment.start)
		local high=math.min(to,segment.finish)
		if high>=low then
			local direction=segment.b-segment.a
			local t=math.clamp((point-segment.a):Dot(direction)/(segment.length^2),
				(low-segment.start)/segment.length,(high-segment.start)/segment.length)
			local projected=segment.a+direction*t
			local distance=(point-projected).Magnitude
			local arc=segment.start+segment.length*t
			local tie=previous and math.abs(arc-previous) or arc
			if not best or distance<best.error-1e-6 or (math.abs(distance-best.error)<=1e-6 and tie<best.tie) then
				best={point=projected,arc=arc,error=distance,tie=tie,index=segment.index,t=t}
			end
		end
	end
	return best
end

-- Normalize the real closed polyline so checkpoint one is the minimap start.
-- Checkpoints must follow the path order. Invalid geometry is not ranked.
function Rules.track(points,checkpoints,maxError)
	if #points<2 or #checkpoints<2 then return nil end
	local clean={}
	for _,point in ipairs(points) do
		if not Rules.finiteVector(point) then return nil end
		if #clean==0 or (point-clean[#clean]).Magnitude>1e-5 then table.insert(clean,point) end
	end
	if #clean>1 and (clean[1]-clean[#clean]).Magnitude<1e-5 then table.remove(clean) end
	if #clean<2 then return nil end
	local raw,total=segments(clean)
	if total<1e-4 then return nil end
	for index,segment in ipairs(raw) do segment.index=index end
	local first=project(checkpoints[1],raw,0,total)
	if not first or first.error>maxError then return nil end
	local normalized={first.point}
	for offset=1,#clean do
		local index=(first.index+offset-1)%#clean+1
		local point=clean[index]
		if (point-normalized[#normalized]).Magnitude>1e-5 and (point-normalized[1]).Magnitude>1e-5 then table.insert(normalized,point) end
	end
	local path,length=segments(normalized)
	local gates={0}
	local previous=0
	for index=2,#checkpoints do
		local at=project(checkpoints[index],path,previous+1e-4,length-1e-4)
		if not at or at.error>maxError or at.arc<=previous then return nil end
		gates[index]=at.arc; previous=at.arc
	end
	return {points=normalized,segments=path,length=length,gates=gates}
end

-- Projection is confined to the legal leg between visited/next checkpoints.
-- Being physically near a later part of the circuit cannot skip race progress.
function Rules.trackProgress(track,checkpoint,position,previous,maxError)
	local from=track.gates[checkpoint]
	local to=track.gates[checkpoint+1] or track.length
	if not from or to-from<1e-5 or not Rules.finiteVector(position) then return nil end
	local at=project(position,track.segments,from,to,previous)
	if not at or at.error>maxError then return nil end
	return math.clamp((at.arc-from)/(to-from),0,1),at.arc
end

function Rules.ahead(a,b)
	if a.finishOrder or b.finishOrder then
		if not a.finishOrder then return false end
		if not b.finishOrder then return true end
		if a.finishOrder~=b.finishOrder then return a.finishOrder<b.finishOrder end
	end
	if a.completed~=b.completed then return a.completed>b.completed end
	if a.checkpoint~=b.checkpoint then return a.checkpoint>b.checkpoint end
	if math.abs(a.fraction-b.fraction)>1e-7 then return a.fraction>b.fraction end
	if a.serial~=b.serial then return a.serial<b.serial end
	return a.userId<b.userId
end

return table.freeze(Rules)
