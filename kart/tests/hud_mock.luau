-- GUI data/graph stand-in only. This does not render Roblox UI or run its engine.
-- The runner injects 'allowed', a checked-in minimal API property-name fixture.
local Enum=setmetatable({},{__index=function(t,k)
 local v=setmetatable({},{__index=function(_,name) return name end}); rawset(t,k,v); return v
end})
local color={}; color.__index=color
function color:Lerp(other,alpha)
 return setmetatable({R=self.R+(other.R-self.R)*alpha,G=self.G+(other.G-self.G)*alpha,B=self.B+(other.B-self.B)*alpha},color)
end
local Color3={}
function Color3.fromRGB(r,g,b) return setmetatable({R=r/255,G=g/255,B=b/255},color) end
local function constructor(...) return {...} end
local CFrame={new=constructor}
local UDim={new=constructor}
local UDim2={new=constructor,fromOffset=constructor,fromScale=constructor}
local Vector2={new=function(x,y) return {X=x,Y=y} end,zero={X=0,Y=0}}
local ColorSequence={new=constructor}
local ColorSequenceKeypoint={new=constructor}
local Random={new=function() return {NextNumber=function() return 0.4 end} end}
local objects={}
local Object={}
Object.__index=function(object,key) return Object[key] or object.values[key] end
Object.__newindex=function(object,key,value)
 assert(allowed[object.values.ClassName][key],object.values.ClassName.." invalid API property "..key)
 object.values[key]=value
end
local Instance={new=function(class)
 assert(allowed[class],"Unexpected GUI class "..class)
 local object=setmetatable({values={ClassName=class}},Object)
 table.insert(objects,object)
 return object
end}
