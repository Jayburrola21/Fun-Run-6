-- Minimal instance/service stand-in. Tests command-bar source, not Studio APIs.
local Object={}
local verifyBeforeMutation=function() end
Object.__index=function(o,key)
 if Object[key] then return Object[key] end
 if o.props[key]~=nil then return o.props[key] end
 for _,child in ipairs(o.children) do if child.Name==key then return child end end
end
Object.__newindex=function(o,key,value)
 if o.watched and (key=="Source" or key=="Parent") then verifyBeforeMutation() end
 if key=="Parent" then
  local old=o.props.Parent
  if old then for i,child in ipairs(old.children) do if child==o then table.remove(old.children,i); break end end end
  if value then table.insert(value.children,o) end
 end
 o.props[key]=value
end
function Object:IsA(class) return self.ClassName==class end
function Object:FindFirstChild(name)
 for _,child in ipairs(self.children) do if child.Name==name then return child end end
end
function Object:WaitForChild(name) return assert(self:FindFirstChild(name),name) end
function Object:GetChildren() return table.clone(self.children) end
function Object:GetFullName() return self.Parent and self.Parent:GetFullName().."."..self.Name or self.Name end
function Object:Destroy()
 if self.watched then verifyBeforeMutation() end
 self.Parent=nil
 self.props.destroyed=true
end
local Instance={}
function Instance.new(class)
 return setmetatable({props={Name=class,ClassName=class,Archivable=true,Disabled=true},children={},watched=false},Object)
end
function Object:Clone()
 if not self.Archivable then return nil end
 local copy=Instance.new(self.ClassName)
 for key,value in pairs(self.props) do if key~="Parent" then copy.props[key]=value end end
 for _,child in ipairs(self.children) do local c=child:Clone(); if c then c.Parent=copy end end
 return copy
end
local function create(class,name,parent,source)
 local o=Instance.new(class); o.Name=name; o.Parent=parent
 if source then o.Source=source end
 return o
end
local function tagged(kind,values) values.kind=kind; return values end
local CFrame={new=function(...) return tagged("CFrame",{components={...},GetComponents=function(self) return table.unpack(self.components) end}) end}
local Color3={new=function(r,g,b) return tagged("Color3",{R=r,G=g,B=b}) end}
Color3.fromRGB=function(r,g,b) return Color3.new(r/255,g/255,b/255) end
local function typeof(value) return type(value)=="table" and value.kind or type(value) end
local function evaluate(source)
 local compiled=assert(loadstring(source))
 setfenv(compiled,setmetatable({CFrame=CFrame,Color3=Color3},{__index=getfenv()}))
 return compiled()
end
local function require(module) return evaluate(module.Source) end
local moduleNames={"KartConfig","KartBuilder","KartDynamics","KartSeatLock","KartHUD","KartRace","KartRaceRules","KartCareerWins","KartMeshVisuals","KartPresentation"}
local function snapshot(o)
 local result={source=o.Source,children={}}
 for _,child in ipairs(o.children) do result.children[child.Name]=snapshot(child) end
 return result
end
local function matches(o,saved)
 if not o or o.Source~=saved.source then return false end
 for name,child in pairs(saved.children) do if not matches(o:FindFirstChild(name),child) then return false end end
 return true
end
local function scenario(mode)
 local services={}; local oldItems={}; local watched={}; local mutationCount=0
 local function track(o) table.insert(watched,o); for _,c in ipairs(o.children) do track(c) end end
 for _,name in ipairs({"ReplicatedStorage","ServerScriptService","StarterPlayer","ServerStorage"}) do services[name]=create("Folder",name) end
 local starter=create("Folder","StarterPlayerScripts",services.StarterPlayer)
 local package=create("Folder","KartPackage")
 local incoming=create("Folder","KartSystem",package)
 for _,name in ipairs(moduleNames) do create("ModuleScript",name,incoming,Sources[name]) end
 create("Script","KartServer",package,Sources.KartServer)
 create("LocalScript","KartController",package,Sources.KartController)
 local markers=create("Folder","KartSpawns") -- deliberately outside all installer services
 local marker=create("Part","MySpawn",markers); marker.Position="unchanged"
 if mode~="fresh" then
  if mode~="partial" then
   local installed=create("Folder","KartSystem",services.ReplicatedStorage)
   local prior="local c=table.clone((function()\n"..Sources.KartConfig.."\nend)()); c.ReleaseVersion=2; c.MaxSpeed=97; c.WheelRadius=1.4; c.Wheelbase=8; c.Grip=8.5; c.SpringFrequency=3.2; c.SpawnCFrame=CFrame.new(12,4,9); return c"
   if mode=="version3" then prior=prior:gsub("c.ReleaseVersion=2;","c.ReleaseVersion=3; c.DriftChargeTime=1.5; c.TurboDuration=1.15;") end
   if mode=="version4" then prior=prior:gsub("c.ReleaseVersion=2;","c.ReleaseVersion=4; c.DriftChargeTime=0.9; c.TurboActivation='Release'; c.TurboDuration=1.5;") end
   if mode=="stickyversion4" then prior=prior:gsub("c.ReleaseVersion=2;","c.ReleaseVersion=4; c.DriftChargeTime=1.5; c.TurboActivation='Release'; c.TurboDuration=1.5;") end
   if mode=="version5" then prior=prior:gsub("c.ReleaseVersion=2;","c.ReleaseVersion=5; c.DriftChargeTime=0.5; c.TurboActivation='Immediate'; c.TurboDuration=1.5;") end
   if mode=="customversion5" then prior=prior:gsub("c.ReleaseVersion=2;","c.ReleaseVersion=5; c.DriftChargeTime=0.75; c.TurboActivation='Immediate'; c.TurboDuration=2;") end
   if mode=="customversion6" then prior=prior:gsub("c.ReleaseVersion=2;","c.ReleaseVersion=6; c.DriftChargeTime=0.75; c.TurboActivation='Immediate'; c.TurboDuration=2;") end
   for _,name in ipairs({"KartConfig","KartBuilder","KartDynamics"}) do create("ModuleScript",name,installed,name=="KartConfig" and prior or "return 'old'") end
   create("ModuleScript","MyCustomModule",installed,"return 123")
   create("Model","KartMeshTemplate",installed)
   if mode=="badbackup" then installed.KartBuilder.Archivable=false end
   table.insert(oldItems,installed)
  end
  table.insert(oldItems,create("Script","KartServer",services.ServerScriptService,"-- old server"))
  if mode~="partial" then table.insert(oldItems,create("LocalScript","KartController",starter,"-- old client")) end
 end
 local originals={}
 for _,o in ipairs(oldItems) do originals[o.Name]=snapshot(o); track(o) end
 if mode=="missing" then incoming.KartHUD:Destroy() end
 if mode=="incomingserver" then package.KartServer.Archivable=false end
 if mode=="incomingclient" then package.KartController.Archivable=false end
 if mode=="wrongtype" then services.ReplicatedStorage.KartSystem.props.ClassName="Model" end
 for _,o in ipairs(watched) do o.watched=true end
 verifyBeforeMutation=function()
  mutationCount+=1
  local backups=assert(services.ServerStorage:FindFirstChild("KartBackups"),"Mutation preceded backup")
  local folder=assert(backups:GetChildren()[1],"Missing backup record")
  for name,saved in pairs(originals) do assert(matches(folder:FindFirstChild(name),saved),"Mutation preceded complete backup") end
 end
 local game={GetService=function(_,name) return assert(services[name],name) end}
 services.RunService={IsRunning=function() return mode=="playing" end}
 services.Selection={Get=function() return {package} end}
 local command=assert(loadstring(Command))
 setfenv(command,setmetatable({game=game,Instance=Instance,require=require,typeof=typeof,print=function() end},{__index=getfenv()}))
 local ok,message=pcall(command)
 local shouldFail=mode=="missing" or mode=="badbackup" or mode=="wrongtype" or mode=="playing"
  or mode=="incomingserver" or mode=="incomingclient"
 assert(ok~=shouldFail,mode..": "..tostring(message))
 assert(marker.Parent==markers and marker.Position=="unchanged","Spawn markers changed")
 if shouldFail then
  assert(mutationCount==0,"Rejected command mutated installed source")
  for _,o in ipairs(oldItems) do assert(matches(o,originals[o.Name]),"Rejected command changed installed source") end
 else
  local installed=services.ReplicatedStorage.KartSystem
  for _,name in ipairs(moduleNames) do assert(installed[name],"Missing module "..name) end
  assert(services.ServerScriptService.KartServer.Source==Sources.KartServer and not services.ServerScriptService.KartServer.Disabled)
  assert(starter.KartController.Source==Sources.KartController and not starter.KartController.Disabled)
  assert(package.destroyed,"Imported package not consumed")
  local config=require(installed.KartConfig); local defaults=evaluate(Sources.KartConfig)
  assert(config.ModelScale==defaults.ModelScale and config.WheelRadius==defaults.WheelRadius and config.Wheelbase==defaults.Wheelbase,"Geometry tuning became inconsistent")
  assert(defaults.ReleaseVersion==7 and defaults.TurboActivation=="Release","Incoming remodel config is incorrect")
  if mode=="customversion5" or mode=="customversion6" then
   assert(config.DriftChargeTime==0.75 and config.TurboDuration==2 and config.TurboActivation=="Immediate","Remodel changed custom boost feel")
  elseif mode=="version3" then
   assert(config.DriftChargeTime==1.5 and config.TurboDuration==1.15,"Remodel changed older active boost settings")
  elseif mode=="version4" then
   assert(config.DriftChargeTime==0.9 and config.TurboDuration==1.5 and config.TurboActivation=="Release","Existing .9s boost changed")
  elseif mode=="stickyversion4" then
   assert(config.DriftChargeTime==1.5 and config.TurboActivation=="Release","Existing saved timing changed")
  elseif mode=="version5" then
   assert(config.DriftChargeTime==0.5 and config.TurboDuration==1.5 and config.TurboActivation=="Immediate","Remodel changed active boost mode")
  else
   assert(config.DriftChargeTime==0.5 and config.TurboDuration==1.5 and config.TurboActivation==defaults.TurboActivation,"Fresh/default timing changed")
  end
  if mode=="upgrade" then
   assert(config.MaxSpeed==97,"Custom speed lost")
   assert(config.Grip==defaults.Grip and config.SpringFrequency==defaults.SpringFrequency,"Legacy defaults overrode upgraded stability")
   assert(config.SpawnCFrame.components[1]==12 and config.SpawnCFrame.components[3]==9,"Custom spawn lost")
   assert(installed.MyCustomModule.Source=="return 123","Custom module removed")
   assert(installed.KartMeshTemplate and installed.KartMeshTemplate:IsA("Model"),"Imported mesh template removed")
  end
  assert(#services.ServerScriptService:GetChildren()==1 and #starter:GetChildren()==1,"Duplicate controller scripts")
 end
end
