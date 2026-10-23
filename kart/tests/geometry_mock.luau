-- Minimal geometry-only Roblox stand-in. It does NOT simulate engine physics/IK.
local V={}; V.__index=function(v,k)
 if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
 if k=="Unit" then return v/v.Magnitude end
 return V[k]
end
local function vec(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},V) end
V.__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
V.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
V.__unm=function(a) return vec(-a.X,-a.Y,-a.Z) end
V.__mul=function(a,b) if type(a)=="number" then a,b=b,a end; return vec(a.X*b,a.Y*b,a.Z*b) end
V.__div=function(a,b) return vec(a.X/b,a.Y/b,a.Z/b) end
function V:Cross(b) return vec(self.Y*b.Z-self.Z*b.Y,self.Z*b.X-self.X*b.Z,self.X*b.Y-self.Y*b.X) end
local Vector3={new=vec,zero=vec()}
local Vector2={new=function(...) return {...} end}
local F={}; F.__index=function(f,k) if k=="Position" then return f.p end; return F[k] end
local function frame(p,m) return setmetatable({p=p or vec(),m=m or {1,0,0,0,1,0,0,0,1}},F) end
local function rotate(m,p) return vec(m[1]*p.X+m[2]*p.Y+m[3]*p.Z,m[4]*p.X+m[5]*p.Y+m[6]*p.Z,m[7]*p.X+m[8]*p.Y+m[9]*p.Z) end
F.__mul=function(a,b)
 local r={}
 for i=0,2 do for j=0,2 do
  r[i*3+j+1]=0
  for k=0,2 do r[i*3+j+1]+=a.m[i*3+k+1]*b.m[k*3+j+1] end
 end end
 return frame(a.p+rotate(a.m,b.p),r)
end
local CFrame={}
function CFrame.new(x,y,z) return frame(type(x)=="table" and x or vec(x,y,z)) end
function CFrame.Angles(x,y,z)
 local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
 return frame(nil,{1,0,0,0,cx,-sx,0,sx,cx})*frame(nil,{cy,0,sy,0,1,0,-sy,0,cy})*frame(nil,{cz,-sz,0,sz,cz,0,0,0,1})
end
function CFrame.lookAt(a,b)
 local look=(b-a).Unit; local right=look:Cross(vec(0,1,0)).Unit; local up=right:Cross(look)
 return frame(a,{right.X,up.X,-look.X,right.Y,up.Y,-look.Y,right.Z,up.Z,-look.Z})
end
local Color3={}
function Color3.new(r,g,b) return {R=r,G=g,B=b} end
function Color3.fromRGB(r,g,b) return Color3.new(r/255,g/255,b/255) end
local Enum=setmetatable({},{__index=function(t,k) local e=setmetatable({},{__index=function(_,v) return v end}); rawset(t,k,e); return e end})
local function construct(...) return {...} end
local PhysicalProperties={new=construct}
local NumberRange={new=construct}
local NumberSequence={new=construct}
local NumberSequenceKeypoint={new=construct}
local ColorSequence={new=construct}
local instances={}
local Object={}
Object.__index=function(o,k)
 if Object[k] then return Object[k] end
 if o.props[k]~=nil then return o.props[k] end
 for _,child in ipairs(o.children) do if child.Name==k then return child end end
 return nil
end
Object.__newindex=function(o,k,v)
 if k=="Parent" then
  assert(o.props.Parent==nil,"Mock supports initial parenting only")
  if v then table.insert(v.children,o) end
 end
 o.props[k]=v
end
function Object:GetChildren() return self.children end
function Object:IsA(class) return self.ClassName==class or (class=="BasePart" and (self.ClassName=="Part" or self.ClassName=="WedgePart" or self.ClassName=="VehicleSeat")) end
function Object:SetAttribute(k,v) self.attributes[k]=v end
local Instance={}
function Instance.new(class)
 local o=setmetatable({props={ClassName=class,Name=class,Transparency=0},children={},attributes={}},Object)
 table.insert(instances,o); return o
end
