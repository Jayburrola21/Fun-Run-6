-- Service/GUI graph doubles only; this is not Roblox rendering or physics.
-- The runner supplies a minimal checked-in API property-name fixture as allowed.
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
local UDim={new=function(scale,offset) return {kind="UDim",scale=scale,offset=offset} end}
local UDim2={}
function UDim2.new(sx,ox,sy,oy) return {kind="UDim2",sx=sx,ox=ox,sy=sy,oy=oy} end
function UDim2.fromOffset(x,y) return UDim2.new(0,x,0,y) end
function UDim2.fromScale(x,y) return UDim2.new(x,0,y,0) end
local Vector2={new=function(x,y) return {X=x,Y=y} end,zero={X=0,Y=0}}
local Vector3={new=function(x,y,z) return {__type="Vector3",X=x,Y=y,Z=z} end}
local function typeof(value) return type(value)=="table" and value.__type or type(value) end
local ColorSequence={new=constructor}
local ColorSequenceKeypoint={new=constructor}
local objects={}
local Object={}
Object.__index=function(object,key) return Object[key] or object.values[key] end
Object.__newindex=function(object,key,value)
 assert(allowed[object.values.ClassName][key],object.values.ClassName.." invalid API property "..key)
 if key=="Parent" then
  local previous=object.values.Parent
  if previous then for index,child in ipairs(previous.children) do if child==object then table.remove(previous.children,index); break end end end
  if value then table.insert(value.children,object) end
 end
 object.values[key]=value
end
function Object:GetChildren()
 local copy={}
 for _,child in ipairs(self.children) do if not child.destroyed then table.insert(copy,child) end end
 return copy
end
function Object:FindFirstChild(name)
 for _,child in ipairs(self.children) do if child.Name==name and not child.destroyed then return child end end
 return nil
end
function Object:IsA(class) return self.ClassName==class end
function Object:GetAttribute(key) return self.attributes[key] end
function Object:SetAttribute(key,value) self.attributes[key]=value end
function Object:Destroy()
 if self.destroyed then return end
 rawset(self,"destroyed",true)
 for _,child in ipairs(self:GetChildren()) do child:Destroy() end
 self.Parent=nil
end
local Instance={new=function(class)
 assert(allowed[class],"Unexpected GUI/data class "..class)
 local object=setmetatable({values={ClassName=class,Name=class},children={},attributes={},destroyed=false},Object)
 table.insert(objects,object)
 return object
end}
local pendingTasks={}
local task={}
function task.spawn(callback) table.insert(pendingTasks,callback) end
function task.delay(_seconds,callback) table.insert(pendingTasks,callback) end
local function flushTasks(limit)
 local ran=0
 while #pendingTasks>0 and ran<(limit or 1000) do local callback=table.remove(pendingTasks,1); callback(); ran+=1 end
 return ran
end
