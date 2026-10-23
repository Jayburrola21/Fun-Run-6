-- Geometry and instance doubles only. No asset upload, mesh rendering or physics.
local V={}
V.__index=function(v,key)
	if key=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
	if key=="Unit" then return v/v.Magnitude end
	return V[key]
end
local function vec(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},V) end
V.__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
V.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
V.__mul=function(a,b) if type(a)=="number" then a,b=b,a end; return vec(a.X*b,a.Y*b,a.Z*b) end
V.__div=function(a,b) return vec(a.X/b,a.Y/b,a.Z/b) end
function V:Dot(b) return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
function V:Cross(b) return vec(self.Y*b.Z-self.Z*b.Y,self.Z*b.X-self.X*b.Z,self.X*b.Y-self.Y*b.X) end
local Vector3={new=vec,zero=vec()}
local F={}
F.__index=function(cf,key)
	if key=="Position" then return cf.p end
	if key=="Rotation" then return setmetatable({p=vec(),m=cf.m},F) end
	return F[key]
end
local function frame(p,m) return setmetatable({p=p or vec(),m=m or {1,0,0,0,1,0,0,0,1}},F) end
local function rotate(m,p) return vec(m[1]*p.X+m[2]*p.Y+m[3]*p.Z,m[4]*p.X+m[5]*p.Y+m[6]*p.Z,m[7]*p.X+m[8]*p.Y+m[9]*p.Z) end
F.__mul=function(a,b)
	local m={}
	for row=0,2 do for column=0,2 do
		local value=0
		for k=0,2 do value+=a.m[row*3+k+1]*b.m[k*3+column+1] end
		m[row*3+column+1]=value
	end end
	return frame(a.p+rotate(a.m,b.p),m)
end
function F:Inverse()
	local m={self.m[1],self.m[4],self.m[7],self.m[2],self.m[5],self.m[8],self.m[3],self.m[6],self.m[9]}
	return frame(rotate(m,self.p*-1),m)
end
function F:ToObjectSpace(other) return self:Inverse()*other end
function F:GetComponents() return self.p.X,self.p.Y,self.p.Z,table.unpack(self.m) end
local CFrame={}
function CFrame.new(x,y,z) return frame(getmetatable(x)==V and x or vec(x,y,z)) end
function CFrame.Angles(x,y,z)
	local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
	return frame(nil,{1,0,0,0,cx,-sx,0,sx,cx})*frame(nil,{cy,0,sy,0,1,0,-sy,0,cy})*frame(nil,{cz,-sz,0,sz,cz,0,0,0,1})
end
function CFrame.lookAt(a,b,up)
	local look=(b-a).Unit; local right=look:Cross(up or vec(0,1,0)).Unit; local vertical=right:Cross(look)
	return frame(a,{right.X,vertical.X,-look.X,right.Y,vertical.Y,-look.Y,right.Z,vertical.Z,-look.Z})
end
local function typeof(value)
	if getmetatable(value)==V then return "Vector3" end
	if getmetatable(value)==F then return "CFrame" end
	return type(value)
end
local Enum={Material={Metal="Metal",Fabric="Fabric",Neon="Neon",Glass="Glass",SmoothPlastic="SmoothPlastic"}}
local Object={}
Object.__index=function(object,key)
	if Object[key] then return Object[key] end
	if key=="Position" and object.props.CFrame then return object.props.CFrame.Position end
	if object.props[key]~=nil then return object.props[key] end
	for _,child in ipairs(object.children) do if child.Name==key then return child end end
	return nil
end
Object.__newindex=function(object,key,value)
	if key=="Parent" then
		local previous=object.props.Parent
		if previous then for index,child in ipairs(previous.children) do if child==object then table.remove(previous.children,index); break end end end
		if value then table.insert(value.children,object) end
	end
	object.props[key]=value
end
local Instance={}
function Instance.new(class)
	return setmetatable({props={ClassName=class,Name=class,Archivable=true,Transparency=0},children={},attributes={}},Object)
end
function Object:IsA(class)
	return self.ClassName==class or class=="BasePart" and (self.ClassName=="MeshPart" or self.ClassName=="Part" or self.ClassName=="VehicleSeat")
		or class=="LuaSourceContainer" and (self.ClassName=="Script" or self.ClassName=="LocalScript" or self.ClassName=="ModuleScript")
end
function Object:GetChildren() return table.clone(self.children) end
function Object:GetDescendants()
	local result={}
	local function visit(parent)
		for _,child in ipairs(parent.children) do table.insert(result,child); visit(child) end
	end
	visit(self); return result
end
function Object:FindFirstChild(name)
	for _,child in ipairs(self.children) do if child.Name==name then return child end end
	return nil
end
function Object:IsDescendantOf(parent)
	local cursor=self.Parent
	while cursor do if cursor==parent then return true end; cursor=cursor.Parent end
	return false
end
function Object:SetAttribute(key,value) self.attributes[key]=value end
function Object:GetAttribute(key) return self.attributes[key] end
function Object:GetAttributes() return table.clone(self.attributes) end
function Object:Clone()
	if not self.Archivable then return nil end
	local copy=Instance.new(self.ClassName)
	for key,value in pairs(self.props) do if key~="Parent" then copy[key]=value end end
	for key,value in pairs(self.attributes) do copy:SetAttribute(key,value) end
	for _,child in ipairs(self.children) do local clone=child:Clone(); if clone then clone.Parent=copy end end
	return copy
end
function Object:Destroy()
	for _,child in ipairs(self:GetChildren()) do child:Destroy() end
	self.Parent=nil; self.destroyed=true
end
function Object:GetFullName()
	return self.Parent and self.Parent:GetFullName().."."..self.Name or self.Name
end
