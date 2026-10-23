-- Minimal geometry/service doubles. No physics solver or networking is simulated.
local Vector={}; Vector.__index=function(self,key)
	if key=="Magnitude" then return math.sqrt(self.X^2+self.Y^2+self.Z^2) end
	return Vector[key]
end
local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z},Vector) end
Vector.__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
Vector.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
Vector.__mul=function(a,b) return vec(a.X*b,a.Y*b,a.Z*b) end
Vector.__div=function(a,b) return vec(a.X/b,a.Y/b,a.Z/b) end
function Vector:Dot(other) return self.X*other.X+self.Y*other.Y+self.Z*other.Z end
local function frame(position)
	return {PointToObjectSpace=function(_,point) return point-position end}
end
local function signal()
	local callbacks={}
	return {Connect=function(_,callback)
		local connection={connected=true}
		function connection:Disconnect() self.connected=false end
		table.insert(callbacks,{connection,callback}); return connection
	end,Fire=function(_,...)
		for _,entry in ipairs(callbacks) do if entry[1].connected then entry[2](...) end end
	end}
end
local Object={}
Object.__index=function(self,key)
	if Object[key] then return Object[key] end
	if self.props[key]~=nil then return self.props[key] end
	for _,child in ipairs(self.children) do if child.Name==key then return child end end
end
Object.__newindex=function(self,key,value)
	if key=="Parent" then
		local previous=self.props.Parent
		if previous then for index,child in ipairs(previous.children) do if child==self then table.remove(previous.children,index); break end end end
		if value then table.insert(value.children,self) end
	end
	self.props[key]=value
end
local function instance(class,name,parent)
	local object=setmetatable({props={ClassName=class,Name=name},attributes={},children={}},Object)
	object.Parent=parent
	return object
end
function Object:Destroy()
	for _,child in ipairs(table.clone(self.children)) do child:Destroy() end
	self.Parent=nil
end
function Object:IsA(class) return self.ClassName==class or (class=="BasePart" and self.ClassName=="Part") end
function Object:FindFirstChild(name)
	for _,child in ipairs(self.children) do if child.Name==name then return child end end
end
function Object:GetChildren() return table.clone(self.children) end
function Object:GetAttribute(name) return self.attributes[name] end
function Object:SetAttribute(name,value) self.attributes[name]=value end
function Object:IsDescendantOf(parent)
	local current=self.Parent
	while current do if current==parent then return true end; current=current.Parent end
	return false
end
local Instance={new=function(class) return instance(class,class) end}
local playerList={}
local Players=instance("Players","Players")
Players.PlayerRemoving=signal()
function Players:GetPlayers() return playerList end
local workspace=instance("Workspace","Workspace")
local guid=0
local HttpService={GenerateGUID=function() guid+=1; return "round-"..guid end}
local script={Parent=instance("Folder","KartSystem")}
local game={GetService=function(_,name) if name=="Players" then return Players end; assert(name=="HttpService"); return HttpService end}
local Career={}
function Career.new(config)
	local self={records={},awards={},loaded=config.TestCareerLoaded~=false}
	function self:Track(player) if self.loaded and self.records[player]==nil then self.records[player]=0 end end
	function self:Get(player) return self.records[player] end
	function self:Award(player,id)
		self:Track(player)
		if not self.awards[id] then self.awards[id]=true; if self.records[player]~=nil then self.records[player]+=1 end end
	end
	function self:Remove(_) end
	function self:Update(_) end
	function self:Destroy() end
	return self
end
local function resetWorld()
	workspace=instance("Workspace","Workspace")
	script.Parent=instance("Folder","KartSystem")
	table.clear(playerList)
end
local function part(name,parent,x,y,z,size)
	local object=instance("Part",name,parent)
	object.Position=vec(x,y,z); object.CFrame=frame(object.Position); object.Size=size or vec(4,6,4)
	return object
end
local function player(id,x)
	local object=instance("Player","Player"..id,Players); object.UserId=id
	local character=instance("Model","Character"..id,workspace); object.Character=character
	local humanoid=instance("Humanoid","Humanoid",character); humanoid.Health=100
	local chassis=part("Chassis",character,x or -10,0,0)
	local seat={Occupant=humanoid}
	table.insert(playerList,object)
	return object,{player=object,chassis=chassis,seat=seat}
end
local function course(total)
	local root=instance("Folder","KartRace",workspace); root:SetAttribute("TotalLaps",total or 2)
	local gates=instance("Folder","Checkpoints",root)
	part("1",gates,0,0,0); part("2",gates,20,0,0); part("3",gates,40,0,0)
	return root,gates
end
local Config={MaxSpeed=82,TurboPower=32,RaceTotalLaps=3,RaceCoinPickupRadius=3.5,RaceMaxRacers=6,RaceTrackWidth=18}

local function square(total,detailed)
	local root=instance("Folder","KartRace",workspace)
	root:SetAttribute("TotalLaps",total or 3)
	local checkpoints=instance("Folder","Checkpoints",root)
	part("1",checkpoints,0,0,0); part("2",checkpoints,100,0,0)
	part("3",checkpoints,100,0,100); part("4",checkpoints,0,0,100)
	if detailed then
		local path=instance("Folder","Path",root)
		for index,point in ipairs({vec(0,0,0),vec(50,0,0),vec(100,0,0),vec(100,0,50),vec(100,0,100),vec(50,0,100),vec(0,0,100),vec(0,0,50)}) do
			part(tostring(index),path,point.X,point.Y,point.Z,vec(1,1,1))
		end
	end
	return root,checkpoints
end
local function removePlayer(value)
	for index,current in ipairs(playerList) do if current==value then table.remove(playerList,index); break end end
	value.Parent=nil
	Players.PlayerRemoving:Fire(value)
end
