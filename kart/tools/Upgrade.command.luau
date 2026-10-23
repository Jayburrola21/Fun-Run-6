-- Select the newly imported KartPackage, then paste into Studio's EDIT Command Bar.
assert(not game:GetService("RunService"):IsRunning(),"Stop Play before upgrading")
local selected=game:GetService("Selection"):Get()
assert(#selected==1 and selected[1].Name=="KartPackage","Select the NEW imported KartPackage folder")
local package=selected[1]
local storage=game:GetService("ReplicatedStorage")
local server=game:GetService("ServerScriptService")
local starter=game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local oldSystem=assert(storage:FindFirstChild("KartSystem"),"Use Install.command.luau for a first installation")
local oldServer=assert(server:FindFirstChild("KartServer"),"Existing KartServer not found")
local oldController=assert(starter:FindFirstChild("KartController"),"Existing KartController not found")
assert(oldServer:IsA("Script") and oldController:IsA("LocalScript"),"Unexpected installed script types")
local incoming=assert(package:FindFirstChild("KartSystem"),"Incomplete package")
for _,name in ipairs({"KartConfig","KartBuilder","KartDynamics"}) do
	assert(incoming:FindFirstChild(name) and incoming[name]:IsA("ModuleScript"),"Missing incoming "..name)
end
assert(package:FindFirstChild("KartServer") and package.KartServer:IsA("Script"),"Missing server script")
assert(package:FindFirstChild("KartController") and package.KartController:IsA("LocalScript"),"Missing controller script")

-- Preserve customized values; unchanged first-release tuning receives new defaults.
local defaults={MaxSpeed=82,ReverseSpeed=24,Acceleration=39,BrakeAcceleration=75,CoastDrag=0.55,Grip=8.5,DriftGrip=2.1,MaxSteer=math.rad(29),MaxCornerAcceleration=85,Wheelbase=4.8,WheelRadius=1.05,SuspensionRest=0.65,SuspensionTravel=0.65,SpringFrequency=3.2,SpringDamping=0.82,DriftMinSpeed=27,TurboDuration=1.15,TurboPower=32,TurboCooldown=6,InputTimeout=0.5,InputRate=30,DriftStages={0.65,1.5,2.7},DriftBoostDuration={0.55,1.0,1.6},DriftBoostPower={20,29,38}}
local function encode(value)
	local kind=typeof(value)
	if kind=="number" then assert(value==value and math.abs(value)<math.huge); return string.format("%.17g",value) end
	if kind=="CFrame" then local values={value:GetComponents()}; for i,v in ipairs(values) do values[i]=encode(v) end; return "CFrame.new("..table.concat(values,",")..")" end
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
local ok,oldConfig=pcall(require,assert(oldSystem:FindFirstChild("KartConfig"),"Existing Config missing"))
assert(ok and type(oldConfig)=="table","Existing Config failed to load; no files changed")
local overrides={}
for key,baseline in pairs(defaults) do
	if oldConfig[key]~=nil and encode(oldConfig[key])~=encode(baseline) then
		table.insert(overrides,"updated["..string.format("%q",key).."]="..encode(oldConfig[key]))
	end
end
for _,key in ipairs({"SpawnCFrame","Palette"}) do
	if oldConfig[key]~=nil then table.insert(overrides,"updated["..string.format("%q",key).."]="..encode(oldConfig[key])) end
end
local newConfigSource="local config=(function()\n"..incoming.KartConfig.Source.."\nend)()\nlocal updated=table.clone(config)\n"..table.concat(overrides,"\n").."\nreturn table.freeze(updated)"

local backups=game:GetService("ServerStorage"):FindFirstChild("KartBackups")
if not backups then backups=Instance.new("Folder"); backups.Name="KartBackups"; backups.Parent=game:GetService("ServerStorage") end
local backup=Instance.new("Folder"); backup.Name="BeforeUpgrade_"..os.date("!%Y%m%d_%H%M%S"); backup.Parent=backups
-- Verify recoverable clones before replacing any installed script.
for _,original in ipairs({oldSystem,oldServer,oldController}) do
	local copy=assert(original:Clone(),"Cannot back up a non-Archivable instance")
	copy.Parent=backup
end
assert(#backup:GetChildren()==3,"Backup incomplete; upgrade aborted")
for _,name in ipairs({"KartConfig","KartBuilder","KartDynamics"}) do
	assert(backup.KartSystem:FindFirstChild(name) and backup.KartSystem[name].Source==oldSystem[name].Source,"Module backup incomplete; no installed scripts replaced")
end
assert(backup.KartServer.Source==oldServer.Source and backup.KartController.Source==oldController.Source,"Script backup incomplete")
for _,name in ipairs({"KartConfig","KartBuilder","KartDynamics"}) do
	local copy=incoming[name]:Clone()
	if name=="KartConfig" then copy.Source=newConfigSource end
	local previous=oldSystem:FindFirstChild(name)
	if previous then previous:Destroy() end
	copy.Parent=oldSystem
end
oldServer.Source=package.KartServer.Source; oldServer.Disabled=false
oldController.Source=package.KartController.Source; oldController.Disabled=false
package:Destroy()
print("Kart upgraded. Backup: "..backup:GetFullName()..". Spawn markers and custom tuning preserved. Restart Play to rebuild the kart.")
warn("Custom tuning overrides new defaults. If you previously customized suspension/grip, compare KartConfig with the new release before testing.")
