local count=0
local function check(value,message) assert(value,message); count+=1 end
local function near(a,b) return (a-b).Magnitude<1e-8 end
local function sameFrame(a,b)
	local x,y={a:GetComponents()},{b:GetComponents()}
	for index,value in ipairs(x) do if math.abs(value-y[index])>1e-8 then return false end end
	return true
end
local names={"MainBody","FrontNose","LeftSidePod","RightSidePod","RearBody","RearBumper","Seat","SteeringWheel","FrontLeftWheel","FrontRightWheel","RearLeftWheel","RearRightWheel","LeftExhaust","RightExhaust","Chassis"}
local pivots={
	SteeringWheel=CFrame.new(0,1.95,-1.05)*CFrame.Angles(math.rad(-24),0,0),
	FrontLeftWheel=CFrame.new(-2.2,0.4,-2.16),FrontRightWheel=CFrame.new(2.2,0.4,-2.16),
	RearLeftWheel=CFrame.new(-2.2,0.4,2.16),RearRightWheel=CFrame.new(2.2,0.4,2.16),
}
local function create(class,name,parent)
	local object=Instance.new(class); object.Name=name; object.Parent=parent; return object
end
local function part(class,name,parent,cf,size)
	local object=create(class,name,parent); object.CFrame=cf; object.Size=size or Vector3.new(0.4,0.3,0.5)
	object.Color="source"; object.CanCollide=true; object.Anchored=true; object.Massless=false; return object
end
local function template()
	local model=create("Model","KartMeshTemplate")
	model:SetAttribute("KartMeshFormat",1)
	for index,name in ipairs(names) do
		local pivot=pivots[name] or CFrame.new()
		local group=create("Folder",name,model); group:SetAttribute("KartGroupPivot",pivot)
		local role=index%3==0 and "Metal" or index%3==1 and "Seat" or "Rubber"
		local object=part("MeshPart",name.."__PaintRed__Mat"..role,group,pivot*CFrame.new(0.12,0.2,-0.1)*CFrame.Angles(0,0.3,0.1))
		object:SetAttribute("KartPrimaryPaint",index%2==0)
		object:SetAttribute("KartBrakeLight",index==5)
		if index==2 then object.Transparency=0.18 end
		create("WeldConstraint","OldConstraint",object)
		create("Script","DoNotCopy",object)
		create("SurfaceAppearance","KeepMaterial",object)
	end
	return model
end
local function rig(scale)
	local model=create("Model","Kart"); model:SetAttribute("ModelScale",scale)
	local spawn=CFrame.new(30,6,-22)*CFrame.Angles(0.12,0.7,0)
	local chassis=part("Part","Chassis",model,spawn); chassis.CanCollide=true
	local seat=part("VehicleSeat","DriverSeat",model,spawn*CFrame.new(0,0.8,0.7))
	local steering=create("Model","SteeringWheel",model)
	local base=pivots.SteeringWheel
	local hub=part("Part","Hub",steering,spawn*(CFrame.new(base.Position*scale)*base.Rotation))
	local motor=create("Motor6D","SteeringMotor",hub); motor.Part0=chassis; motor.Part1=hub
	local wheels=create("Folder","Wheels",model)
	for _,name in ipairs({"FrontLeft","FrontRight","RearLeft","RearRight"}) do
		local group=create("Model",name,wheels)
		local tire=part("Part","Tire",group,spawn*CFrame.new(pivots[name.."Wheel"].Position*scale))
		local wheelMotor=create("Motor6D","WheelMotor",tire); wheelMotor.Part0=chassis; wheelMotor.Part1=tire
	end
	local glow=part("Part","BoostGlow",model,spawn); glow.Transparency=0.74
	local brake=part("Part","BrakeLight",model,spawn); brake.Transparency=0.2
	local fallback=part("Part","FallbackShell",model,spawn); fallback.Transparency=0.15
	return {model=model,chassis=chassis,seat=seat,hub=hub,steering=motor,fallback=fallback,glow=glow,brake=brake}
end

for _,scale in ipairs({0.84,1,1.3}) do
	local vehicle=rig(scale); local source=template()
	local ok=MeshVisuals.apply(vehicle,"blue",source)
	check(ok,"valid imported template applies")
	check(vehicle.model:GetAttribute("VisualSource")=="Blender","mesh visual source advertised accurately")
	check(vehicle.model:GetAttribute("MeshObjectCount")==15,"all imported objects accounted for")
	check(vehicle.chassis.CanCollide and not vehicle.chassis.destroyed,"collision hull remains intact")
	check(vehicle.seat.Parent==vehicle.model and vehicle.seat.Transparency==1,"functional seat retained behind mesh seat")
	check(vehicle.fallback.Transparency==1,"old presentation hidden only after successful preparation")
	check(vehicle.glow.Transparency==0.74 and vehicle.brake.Transparency==0.2,"live glow and brake effects retained")
	check(vehicle.steering.Part1==vehicle.hub,"steering motor target remains unchanged")
	check(#vehicle.meshBrakeLights==1 and vehicle.meshBrakeLights[1]:GetAttribute("KartBrakeLight"),"imported brake lens exposed to existing server effect controller")
	local visuals=vehicle.model.ImportedKartVisuals
	for index,name in ipairs(names) do
		local copy=visuals[name]:GetChildren()[1]
		local original=source[name]:GetChildren()[1]
		check(copy~=original and original.Parent==source[name],"source template is not moved or mutated")
		check(near(copy.Size,original.Size*scale),"mesh size scales exactly once")
		check(copy.Massless and not copy.Anchored and not copy.CanCollide and not copy.CanTouch and not copy.CanQuery,"meshes never compete with physics")
		check(copy.Transparency==original.Transparency,"authored glass/lens transparency retained")
		check(not copy:FindFirstChild("OldConstraint") and not copy:FindFirstChild("DoNotCopy") and copy:FindFirstChild("KeepMaterial"),"only safe visual material children retained")
		check(copy.Color==(index%2==0 and "blue" or "source"),"primary paint recolored without tinting tires and trim")
		local carrier=vehicle.chassis
		if name=="SteeringWheel" then carrier=vehicle.hub
		elseif pivots[name] then carrier=vehicle.model.Wheels[name:sub(1,-6)].Tire end
		check(copy.VisualWeld.Part0==carrier and copy.VisualWeld.Part1==copy,"mesh binds to correct physical or visual carrier")
		local relative=carrier==vehicle.chassis and original.CFrame or pivots[name]:ToObjectSpace(original.CFrame)
		local expected=carrier.CFrame*(CFrame.new(relative.Position*scale)*relative.Rotation)
		check(sameFrame(copy.CFrame,expected),"pivot-relative import transform matches real rotated world rig")
	end
	local before=#visuals:GetDescendants()
	check(MeshVisuals.apply(vehicle,"red",source) and #visuals:GetDescendants()==before,"repeated apply cannot duplicate visuals")
end

for _,failure in ipairs({"format","group","parttype","size","frame","pivot","clone","unexpected","empty"}) do
	local vehicle=rig(0.84); local source=template()
	if failure=="format" then source:SetAttribute("KartMeshFormat",nil)
	elseif failure=="group" then source.RearRightWheel:Destroy()
	elseif failure=="parttype" then source.MainBody:GetChildren()[1].ClassName="Part"
	elseif failure=="size" then source.MainBody:GetChildren()[1].Size=Vector3.new(0,1,1)
	elseif failure=="frame" then source.MainBody:GetChildren()[1].CFrame=CFrame.new(0/0,0,0)
	elseif failure=="pivot" then source.SteeringWheel:SetAttribute("KartGroupPivot",nil)
	elseif failure=="clone" then source.RearRightWheel:GetChildren()[1].Archivable=false
	elseif failure=="unexpected" then create("Folder","Mystery",source)
	elseif failure=="empty" then source.RearBumper:GetChildren()[1]:Destroy() end
	local ok=MeshVisuals.apply(vehicle,"blue",source)
	check(not ok,"malformed template rejected: "..failure)
	check(vehicle.fallback.Transparency==0.15 and vehicle.seat.Transparency==0,"rejected template preserves visible fallback: "..failure)
	check(not vehicle.model:FindFirstChild("ImportedKartVisuals"),"rejected template leaves no partial mesh assembly: "..failure)
end
local native=rig(0.84)
check(not MeshVisuals.apply(native,"blue"),"no uploaded mesh template uses native presentation")
check(native.model:GetAttribute("VisualSource")=="Native" and native.fallback.Transparency==0.15,"native fallback remains visible and labelled")

-- Execute the actual edit-mode importer against translated, rotated and scaled
-- input to catch Blender/FBX/Studio axis and unit differences without fake IDs.
local function importScenario(mode)
	local root=create("Folder","Game")
	local replicated=create("Folder","ReplicatedStorage",root)
	local serverStorage=create("Folder","ServerStorage",root)
	local system=create("Folder","KartSystem",replicated)
	create("ModuleScript","KartMeshVisuals",system)
	local previous=template(); previous.Parent=system
	local original=create("Model","ImportedFBX",root)
	local transform=CFrame.new(42,20,-16)*CFrame.Angles(0.7,-0.4,0.25)
	local units=2.54
	for name,position in pairs({KartOrigin=Vector3.zero,KartForward=Vector3.new(0,0,-4),KartUp=Vector3.new(0,4,0)}) do
		part("MeshPart",name,original,transform*CFrame.new(position*units),Vector3.new(0.02,0.02,0.02)*units)
	end
	local source=template()
	for _,group in ipairs(source:GetChildren()) do
		local mesh=group:GetChildren()[1]:Clone()
		mesh.CFrame=transform*(CFrame.new(mesh.CFrame.Position*units)*mesh.CFrame.Rotation)
		mesh.Size*=units; mesh.Parent=original
		for _,child in ipairs(mesh:GetChildren()) do child:Destroy() end
	end
	if mode=="marker" then original.KartForward:Destroy()
	elseif mode=="scale" then original.KartUp.CFrame=transform*CFrame.new(0,12*units,0)
	elseif mode=="axes" then original.KartUp.CFrame=transform*CFrame.new(0,0,4*units)
	elseif mode=="group" then original.RearRightWheel__PaintRed__MatMetal:Destroy()
	elseif mode=="clone" then original.LeftSidePod__PaintRed__MatMetal.Archivable=false
	elseif mode=="script" then create("Script","UnexpectedScript",original) end
	local services={ReplicatedStorage=replicated,ServerStorage=serverStorage,RunService={IsRunning=function() return mode=="playing" end},Selection={Get=function() return {original} end}}
	local game={GetService=function(_,name) return assert(services[name],name) end}
	local run=assert(loadstring(ImportCommand))
	setfenv(run,setmetatable({game=game,Instance=Instance,CFrame=CFrame,Enum=Enum,print=function() end},{__index=getfenv()}))
	local ok,message=pcall(run)
	if mode~="valid" then
		check(not ok,"invalid FBX import rejected: "..mode)
		check(system.KartMeshTemplate==previous and original.Parent==root,"rejected import preserves previous template and source: "..mode)
		return
	end
	check(ok,tostring(message))
	local installed=system.KartMeshTemplate
	check(installed~=previous and installed:GetAttribute("KartMeshFormat")==1,"new normalized mesh template installed")
	check(previous:IsDescendantOf(serverStorage) and original:IsDescendantOf(serverStorage),"previous template and imported source retained away from track")
	for _,name in ipairs(names) do
		local mesh=installed[name]:GetChildren()[1]
		local authored=source[name]:GetChildren()[1]
		check(sameFrame(mesh.CFrame,authored.CFrame) and near(mesh.Size,authored.Size),"FBX rotation/translation/unit scale normalize correctly: "..name)
		check(mesh:GetAttribute("KartPrimaryPaint")==true,"paint role survives object name import")
		local role=mesh.Name:match("__Mat([%a]+)")
		local material=role=="Metal" and Enum.Material.Metal or role=="Seat" and Enum.Material.Fabric or Enum.Material.SmoothPlastic
		check(mesh.Material==material and mesh:GetAttribute("KartMaterialRole")==role,"native material assignment follows authored FBX role")
	end
	check(not installed:FindFirstChild("KartOrigin"),"alignment markers never become vehicle geometry")
end
for _,mode in ipairs({"valid","marker","scale","axes","group","clone","script","playing"}) do importScenario(mode) end
print(string.format("PASS: %d mesh integration/import assertions (geometry/instance doubles; Studio asset upload unrun)",count))
