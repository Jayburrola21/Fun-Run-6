-- Deterministic task/DataStore doubles. No requests reach Roblox services.
local function deep(value)
	if type(value)~="table" then return value end
	local result={}
	for key,v in pairs(value) do result[key]=deep(v) end
	return result
end
local function fixture(initial, session)
	local store={values=deep(initial or {}),gets=0,updates=0,getFailures=0,saveFailures=0,ambiguous=0,transformTwice=false}
	function store:GetAsync(key)
		self.gets+=1
		if self.getFailures>0 then self.getFailures-=1; error("simulated read access failure") end
		return deep(self.values[key])
	end
	function store:UpdateAsync(key,transform)
		self.updates+=1
		if self.saveFailures>0 then self.saveFailures-=1; error("simulated write access failure") end
		local result=transform(deep(self.values[key]))
		if self.transformTwice then result=transform(deep(self.values[key])) end
		self.values[key]=deep(result)
		if self.ambiguous>0 then self.ambiguous-=1; error("simulated committed write with lost response") end
		return deep(result)
	end
	local queue={}
	local now=0
	local warnings={}
	local callbacks={}
	local function drain()
		local pending=table.clone(queue)
		table.clear(queue)
		for _,callback in ipairs(pending) do callback() end
	end
	local deps={
		store=store,sessionId=session or "session-A",
		spawn=function(callback) table.insert(queue,callback) end,
		clock=function() return now end,
		wait=function(delta) now+=delta; drain() end,
		warn=function(message) table.insert(warnings,message) end,
		bindToClose=function(callback) table.insert(callbacks,callback) end,
	}
	return {store=store,deps=deps,queue=queue,warnings=warnings,callbacks=callbacks,drain=drain,
		advance=function(delta) now+=delta end}
end
local function player(id) return {UserId=id or 101} end
