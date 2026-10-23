-- Select the NEW imported KartPackage and run in Studio's EDIT Command Bar.
-- Handles first install, upgrade, and partial installs without duplicate controllers.
assert(not game:GetService("RunService"):IsRunning(),"Stop Play before installing")
local selection=game:GetService("Selection"):Get()
assert(#selection==1 and selection[1].Name=="KartPackage","Select the newly imported KartPackage folder")
local package=selection[1]
local storage=game:GetService("ReplicatedStorage")
local server=game:GetService("ServerScriptService")
local starter=game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local modules={"KartConfig","KartBuilder","KartDynamics","KartSeatLock","KartHUD","KartRace","KartRaceRules"}
local incoming=assert(package:FindFirstChild("KartSystem"),"Incomplete package: missing KartSystem")
for _,name in ipairs(modules) do
 assert(incoming:FindFirstChild(name) and incoming[name]:IsA("ModuleScript"),"Incomplete package: "..name)
end
assert(package:FindFirstChild("KartServer") and package.KartServer:IsA("Script"),"Missing server script")
assert(package:FindFirstChild("KartController") and package.KartController:IsA("LocalScript"),"Missing controller script")
local installed=storage:FindFirstChild("KartSystem")
local installedServer=server:FindFirstChild("KartServer")
local installedController=starter:FindFirstChild("KartController")
assert(not installed or installed:IsA("Folder"),"Existing KartSystem is not a Folder; no changes made")
assert(not installedServer or installedServer:IsA("Script"),"Existing KartServer has unexpected type")
assert(not installedController or installedController:IsA("LocalScript"),"Existing KartController has unexpected type")
for _,name in ipairs(modules) do
 local previous=installed and installed:FindFirstChild(name)
 assert(not previous or previous:IsA("ModuleScript"),"Existing "..name.." has unexpected type")
end
local okNew,newConfig=pcall(require,incoming.KartConfig)
assert(okNew and type(newConfig)=="table","New config cannot load; no changes made")
local oldConfig={}
if installed and installed:FindFirstChild("KartConfig") then
 local ok,result=pcall(require,installed.KartConfig)
 assert(ok and type(result)=="table","Installed config cannot load; no changes made")
 oldConfig=result
end

-- Geometry receives consistent scaled defaults. Preserve compatible custom
-- driving/camera values, palette and spawn; leave retired tier settings behind.
local legacy={MaxSpeed=82,ReverseSpeed=24,Acceleration=39,BrakeAcceleration=75,CoastDrag=0.55,Grip=8.5,DriftGrip=2.1,MaxSteer=math.rad(29),MaxCornerAcceleration=85,SpringFrequency=3.2,SpringDamping=0.82,DriftMinSpeed=27,DriftChargeTime=1.5,TurboDuration=1.15,TurboPower=32,TurboCooldown=6,InputTimeout=0.5,InputRate=30}
local geometry={ModelScale=true,Wheelbase=true,WheelRadius=true,SuspensionRest=true,SuspensionTravel=true,ReleaseVersion=true}
-- This release deliberately changes the charge threshold and activation mode.
-- Old saved defaults must not silently reinstall the reported .9/1.5s behavior.
local oldVersion=tonumber(oldConfig.ReleaseVersion) or 0
local behaviorReset=oldVersion<5 and {DriftChargeTime=true,TurboActivation=true} or {}
local function encode(value)
 local kind=typeof(value)
 if kind=="number" then assert(value==value and math.abs(value)<math.huge,"Non-finite saved tuning"); return string.format("%.17g",value) end
 if kind=="boolean" then return tostring(value) end
 if kind=="string" then return string.format("%q",value) end
 if kind=="CFrame" then local items={value:GetComponents()}; for i,v in ipairs(items) do items[i]=encode(v) end; return "CFrame.new("..table.concat(items,",")..")" end
 if kind=="Color3" then return string.format("Color3.new(%.17g,%.17g,%.17g)",value.R,value.G,value.B) end
 if kind=="table" then
  local items={}
  for key,v in pairs(value) do
   local index=type(key)=="number" and encode(key) or string.format("%q",key)
   table.insert(items,"["..index.."]="..encode(v))
  end
  table.sort(items); return "{"..table.concat(items,",").."}"
 end
 error("Unsupported tuning type: "..kind)
end
local overrides={}
for key,newValue in pairs(newConfig) do
 local previous=oldConfig[key]
 if previous~=nil and not geometry[key] and not behaviorReset[key] then
  local baseline=legacy[key]
  if baseline==nil or oldVersion>=4 then baseline=newValue end
  if key=="Palette" or key=="SpawnCFrame" or encode(previous)~=encode(baseline) then
   table.insert(overrides,"updated["..string.format("%q",key).."]="..encode(previous))
  end
 end
end
local configSource="local config=(function()\n"..incoming.KartConfig.Source.."\nend)()\nlocal updated=table.clone(config)\n"..table.concat(overrides,"\n").."\nreturn table.freeze(updated)"
local prepared={}
for _,name in ipairs(modules) do
 local copy=assert(incoming[name]:Clone(),"Incoming module is not Archivable: "..name)
 if name=="KartConfig" then copy.Source=configSource end
 prepared[name]=copy
end
local preparedServer=assert(package.KartServer:Clone(),"Incoming KartServer is not Archivable")
local preparedController=assert(package.KartController:Clone(),"Incoming KartController is not Archivable")

local oldItems={}
if installed then table.insert(oldItems,installed) end
if installedServer then table.insert(oldItems,installedServer) end
if installedController then table.insert(oldItems,installedController) end
local backup
if #oldItems>0 then
 local backups=game:GetService("ServerStorage"):FindFirstChild("KartBackups")
 if not backups then backups=Instance.new("Folder"); backups.Name="KartBackups"; backups.Parent=game:GetService("ServerStorage") end
 backup=Instance.new("Folder"); backup.Name="BeforeUpgrade_"..os.date("!%Y%m%d_%H%M%S"); backup.Parent=backups
 for _,original in ipairs(oldItems) do
  local copy=assert(original:Clone(),"Cannot back up non-Archivable "..original.Name); copy.Parent=backup
 end
 assert(#backup:GetChildren()==#oldItems,"Incomplete backup; no installed scripts replaced")
 if installed then
  for _,name in ipairs(modules) do
   if installed:FindFirstChild(name) then assert(backup.KartSystem:FindFirstChild(name) and backup.KartSystem[name].Source==installed[name].Source,"Module backup incomplete: "..name) end
  end
 end
 if installedServer then assert(backup.KartServer.Source==installedServer.Source,"Server backup incomplete") end
 if installedController then assert(backup.KartController.Source==installedController.Source,"Controller backup incomplete") end
end
if not installed then installed=Instance.new("Folder"); installed.Name="KartSystem"; installed.Parent=storage end
for _,name in ipairs(modules) do
 local previous=installed:FindFirstChild(name)
 if previous then previous:Destroy() end
 prepared[name].Parent=installed
end
if installedServer then installedServer.Source=preparedServer.Source
else installedServer=preparedServer; installedServer.Parent=server end
if installedController then installedController.Source=preparedController.Source
else installedController=preparedController; installedController.Parent=starter end
installedServer.Disabled=false; installedController.Disabled=false
package:Destroy()
print("Kart installed/upgraded. Spawn markers retained. Restart Play for the reference HUD and 0.50-second turbo.")
if backup then print("Previous installation backed up at "..backup:GetFullName()) end
print("New scaled geometry defaults applied. Compatible custom driving/camera tuning and paint/spawn settings preserved.")
