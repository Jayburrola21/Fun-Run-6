local Config = require(script.Parent.KartConfig)
local Builder = {}
local WHITE = Color3.fromRGB(235, 239, 245)
local BLACK = Color3.fromRGB(20, 23, 30)
local RUBBER = Color3.fromRGB(13, 14, 19)
local METAL = Color3.fromRGB(90, 101, 119)
local BLUE = Color3.fromRGB(70, 177, 255)

function Builder.build(name, spawn, color)
	color = color or Config.Palette.Red
	local model = Instance.new("Model")
	model.Name = name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local function folder(label)
		local f = Instance.new("Folder")
		f.Name = label; f.Parent = model
		return f
	end
	local body = folder("Body")
	local wheels = folder("Wheels")
	local suspension = folder("Suspension")
	local effects = folder("Effects")
	local headlights = folder("Headlights")
	local exhaust = folder("Exhaust")
	local attachments = folder("Attachments")
	local chassis
	local function part(label, size, cf, tint, material, parent, shape, loose, class)
		local p = Instance.new(class or "Part")
		p.Name = label; p.Size = size; p.CFrame = spawn * cf
		p.Color = tint; p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false; p.CanTouch = false; p.CanQuery = false
		p.Massless = true
		if shape then p.Shape = shape end
		p.Parent = parent or body
		if chassis and not loose then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = chassis; weld.Part1 = p; weld.Parent = p
		end
		return p
	end
	local function bar(label, a, b, width, tint, parent)
		return part(label, Vector3.new(width, width, (b-a).Magnitude), CFrame.lookAt((a+b)/2,b), tint, Enum.Material.Metal, parent)
	end
	local function ring(parent, base, radius, thickness, tint, material, count, target)
		for i = 1, count do
			local angle = (i-0.5)*math.pi*2/count
			local cf = base * CFrame.Angles(0,0,angle) * CFrame.new(radius,0,0) * CFrame.Angles(0,0,math.pi/2)
			local segment = part("RingSegment", Vector3.new(2*radius*math.tan(math.pi/count), thickness, thickness), cf, tint, material, parent, nil, target ~= nil)
			if target then
				local w = Instance.new("WeldConstraint"); w.Part0 = target; w.Part1 = segment; w.Parent = segment
			end
		end
	end
	chassis = part("Chassis", Vector3.new(4.25,0.65,7.3), CFrame.new(), BLACK, Enum.Material.Metal, model, nil, true)
	chassis.Massless = false; chassis.CanCollide = true; chassis.CanQuery = true
	chassis.CustomPhysicalProperties = PhysicalProperties.new(2.8,0.2,0,100,100)
	model.PrimaryPart = chassis
	part("FloorPan",Vector3.new(3.9,0.15,4.3),CFrame.new(0,0.48,0.1),METAL,Enum.Material.DiamondPlate)
	-- A layered, tapering nose; wedges slope down towards the front (-Z).
	part("Nose",Vector3.new(2.9,1.05,2.8),CFrame.new(0,0.85,-2.35),color,nil,body,nil,false,"WedgePart")
	part("NoseStripe",Vector3.new(0.52,1.065,2.82),CFrame.new(0.98,0.86,-2.35),WHITE,nil,body,nil,false,"WedgePart")
	local badge=CFrame.new(-0.25,0.88,-2.3)*CFrame.Angles(-math.atan(1.05/2.8),0,0)*CFrame.Angles(0,0.2,0)
	part("NoseBadge",Vector3.new(0.92,0.035,0.92),badge,WHITE)
	part("NoseBadgeInset",Vector3.new(0.32,0.04,0.32),badge*CFrame.new(0,0.025,0),color)
	for _, side in ipairs({-1,1}) do
		part("NoseShoulder",Vector3.new(0.55,0.7,2.3),CFrame.new(side*1.6,0.66,-2.3)*CFrame.Angles(0,0,side*0.12),WHITE,nil,body,nil,false,"WedgePart")
		part("SidePod",Vector3.new(0.65,0.85,2.8),CFrame.new(side*1.82,0.75,0.55),color,nil,body,nil,false,"WedgePart")
		part("SideStripe",Vector3.new(0.68,0.13,2.3),CFrame.new(side*1.83,0.82,0.55),WHITE)
		for n=1,3 do part("CoolingVent",Vector3.new(0.7,0.10,0.38),CFrame.new(side*1.82,0.55,0.45+n*0.46),BLACK) end
		bar("FrameRail",Vector3.new(side*1.45,0.55,1.8),Vector3.new(side*1.32,1.45,-0.8),0.19,color)
		bar("SideGuard",Vector3.new(side*2.08,0.1,-0.4),Vector3.new(side*2.08,0.1,1.9),0.22,METAL)
	end
	local bumper = folder("FrontBumper")
	part("Bumper",Vector3.new(4.9,0.5,0.52),CFrame.new(0,0.05,-3.8),BLACK,Enum.Material.SmoothPlastic,bumper)
	part("Splitter",Vector3.new(4.8,0.09,0.75),CFrame.new(0,-0.22,-3.7),METAL,Enum.Material.Metal,bumper)
	for _, side in ipairs({-1,1}) do
		part("BumperWing",Vector3.new(1.55,0.28,0.85),CFrame.new(side*1.65,0.38,-3.53)*CFrame.Angles(0,side*0.12,0),color,nil,bumper)
		part("LightHousing",Vector3.new(1.3,0.30,0.15),CFrame.new(side*1.65,0.16,-4.08),WHITE,Enum.Material.Metal,headlights)
		local light=part("LED",Vector3.new(1.08,0.13,0.04),CFrame.new(side*1.65,0.17,-4.17),BLUE,Enum.Material.Neon,headlights)
		local beam=Instance.new("SpotLight"); beam.Face=Enum.NormalId.Front; beam.Brightness=1.8; beam.Range=28; beam.Angle=75; beam.Color=BLUE; beam.Parent=light
		part("BrakeLight",Vector3.new(0.6,0.2,0.06),CFrame.new(side*1.6,0.6,3.7),Color3.fromRGB(110,5,10),Enum.Material.SmoothPlastic,effects)
	end
	local seat=part("DriverSeat",Vector3.new(1.9,0.35,1.8),CFrame.new(0,0.95,0.65),BLACK,Enum.Material.Fabric,model,nil,false,"VehicleSeat")
	seat.HeadsUpDisplay=false; seat.MaxSpeed=0; seat.Torque=0; seat.TurnSpeed=0
	part("SeatBack",Vector3.new(1.95,2.15,0.43),CFrame.new(0,2.03,1.5)*CFrame.Angles(-0.14,0,0),BLACK,Enum.Material.Fabric)
	for _,side in ipairs({-1,1}) do
		part("SeatBolster",Vector3.new(0.3,1.2,0.7),CFrame.new(side*0.98,1.65,1.15)*CFrame.Angles(0,0,side*0.12),WHITE,Enum.Material.Fabric)
	end
	part("HeadrestBadge",Vector3.new(0.55,0.55,0.05),CFrame.new(0,2.7,1.21)*CFrame.Angles(0,0,0.2),WHITE)
	part("BadgeInset",Vector3.new(0.23,0.23,0.06),CFrame.new(0,2.7,1.17)*CFrame.Angles(0,0,0.2),BLACK)
	local spoiler=folder("RearSpoiler")
	for _,side in ipairs({-1,1}) do
		bar("SpoilerStrut",Vector3.new(side*1.3,0.65,2.7),Vector3.new(side*1.3,2.6,3.25),0.22,METAL,spoiler)
		part("EndPlate",Vector3.new(0.13,0.85,1.5),CFrame.new(side*2.6,2.7,3.2)*CFrame.Angles(-0.12,0,0),color,nil,spoiler,nil,false,"WedgePart")
		part("WingStripe",Vector3.new(0.5,0.19,1.18),CFrame.new(side*1.7,2.76,3.2)*CFrame.Angles(-0.08,0,0),WHITE,nil,spoiler)
	end
	part("Wing",Vector3.new(5.2,0.18,1.15),CFrame.new(0,2.75,3.2)*CFrame.Angles(-0.08,0,0),color,nil,spoiler)
	-- Wheel and steering assemblies use Motor6D C0 (server replicated), not Transform.
	local wheelData={}
	for _,desc in ipairs({{"FrontLeft",-1,-2.4,true},{"FrontRight",1,-2.4,true},{"RearLeft",-1,2.4,false},{"RearRight",1,2.4,false}}) do
		local label,side,z,front=table.unpack(desc)
		local group=Instance.new("Model"); group.Name=label; group.Parent=wheels
		local origin=Vector3.new(side*2.68,Config.SuspensionRest,z)
		-- Smaller chassis-mounted collision shells catch walls/curbs without
		-- competing with the raycast tires during normal spring compression.
		local guard=part(label.."Collision",Vector3.new(0.85,1.35,1.35),CFrame.new(origin-Vector3.new(0,0.35,0)),BLACK,Enum.Material.SmoothPlastic,suspension,Enum.PartType.Ball)
		guard.Transparency=1; guard.CanCollide=true; guard.CanQuery=true
		guard.CustomPhysicalProperties=PhysicalProperties.new(0.1,0.1,0,100,100)
		local cf=CFrame.new(origin-Vector3.new(0,Config.SuspensionRest,0))
		local tire=part("Tire",Vector3.new(0.95,2.1,2.1),cf,RUBBER,Enum.Material.SmoothPlastic,group,Enum.PartType.Cylinder,true)
		local motor=Instance.new("Motor6D"); motor.Name="WheelMotor"; motor.Part0=chassis; motor.Part1=tire; motor.C0=cf; motor.Parent=tire
		local function detail(label,size,offset,tint,material,shape)
			local p=part(label,size,cf*offset,tint,material,group,shape,true)
			local w=Instance.new("WeldConstraint"); w.Part0=tire; w.Part1=p; w.Parent=p
			return p
		end
		detail("Rim",Vector3.new(0.1,1.4,1.4),CFrame.new(side*0.49,0,0),METAL,Enum.Material.Metal,Enum.PartType.Cylinder)
		detail("Hub",Vector3.new(0.13,0.45,0.45),CFrame.new(side*0.57,0,0),BLACK,Enum.Material.Metal,Enum.PartType.Cylinder)
		for n=1,6 do
			detail("Spoke",Vector3.new(0.12,0.65,0.12),CFrame.new(side*0.55,0,0)*CFrame.Angles(n*math.pi/3,0,0)*CFrame.new(0,0.37,0),WHITE,Enum.Material.Metal)
		end
		ring(group,cf*CFrame.new(side*0.56,0,0)*CFrame.Angles(0,math.pi/2,0),0.79,0.065,BLUE,Enum.Material.Neon,20,tire)
		for n=1,20 do
			for _,offset in ipairs({-0.26,0.26}) do
				detail("Tread",Vector3.new(0.025,0.025,0.20),CFrame.Angles(n*math.pi/10,0,0)*CFrame.new(offset,1.049,0),Color3.fromRGB(28,29,33),Enum.Material.SmoothPlastic)
			end
		end
		local mount=Instance.new("Attachment"); mount.Name=label.."Mount"; mount.Position=origin; mount.Parent=chassis
		local force=Instance.new("VectorForce"); force.Name=label.."Contact"; force.Attachment0=mount; force.RelativeTo=Enum.ActuatorRelativeTo.World; force.ApplyAtCenterOfMass=false; force.Force=Vector3.zero; force.Parent=suspension
		local emitterAt=Instance.new("Attachment"); emitterAt.Name=label.."ContactEffects"; emitterAt.Position=origin-Vector3.new(0,Config.SuspensionRest+Config.WheelRadius,0); emitterAt.Parent=chassis
		local smoke=Instance.new("ParticleEmitter"); smoke.Name="TireSmoke"; smoke.Texture="rbxasset://textures/particles/smoke_main.dds"; smoke.Color=ColorSequence.new(Color3.fromRGB(180,187,200)); smoke.Lifetime=NumberRange.new(0.3,0.6); smoke.Speed=NumberRange.new(1,3); smoke.Rate=0; smoke.SpreadAngle=Vector2.new(30,30); smoke.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.3),NumberSequenceKeypoint.new(1,1.8)}); smoke.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.65),NumberSequenceKeypoint.new(1,1)}); smoke.Parent=emitterAt
		local sparks=Instance.new("ParticleEmitter"); sparks.Name="DriftSparks"; sparks.Texture="rbxasset://textures/particles/sparkles_main.dds"; sparks.Lifetime=NumberRange.new(0.12,0.28); sparks.Speed=NumberRange.new(3,7); sparks.SpreadAngle=Vector2.new(45,45); sparks.LightEmission=1; sparks.Size=NumberSequence.new(0.18); sparks.Rate=0; sparks.Parent=emitterAt
		local glow={}
		for _,p in ipairs(group:GetChildren()) do if p:IsA("BasePart") and p.Material==Enum.Material.Neon then table.insert(glow,p) end end
		table.insert(wheelData,{motor=motor,origin=origin,front=front,force=force,smoke=smoke,sparks=sparks,emitterAt=emitterAt,glow=glow,spin=0})
		bar("Wishbone",Vector3.new(side*1.4,0.05,z),origin,0.13,METAL,suspension)
	end
	local steering=Instance.new("Model"); steering.Name="SteeringWheel"; steering.Parent=model
	local steeringBase=CFrame.new(0,1.95,-1.05)*CFrame.Angles(math.rad(-24),0,0)
	local hub=part("Hub",Vector3.new(0.24,0.24,0.18),steeringBase,BLACK,Enum.Material.Metal,steering,nil,true)
	local steeringMotor=Instance.new("Motor6D"); steeringMotor.Name="SteeringMotor"; steeringMotor.Part0=chassis; steeringMotor.Part1=hub; steeringMotor.C0=steeringBase; steeringMotor.Parent=hub
	ring(steering,steeringBase,0.63,0.12,color,Enum.Material.Fabric,20,hub)
	for n=1,3 do
		local cf=steeringBase*CFrame.Angles(0,0,n*2*math.pi/3)*CFrame.new(0,-0.3,0)
		local p=part("Spoke",Vector3.new(0.12,0.6,0.10),cf,METAL,Enum.Material.Metal,steering,nil,true)
		local w=Instance.new("WeldConstraint"); w.Part0=hub; w.Part1=p; w.Parent=p
	end
	for _,side in ipairs({-1,1}) do
		local a=Instance.new("Attachment"); a.Name=side<0 and "LeftGrip" or "RightGrip"; a.Position=Vector3.new(side*0.59,0.13,0); a.Parent=hub
	end
	bar("SteeringColumn",Vector3.new(0,0.65,-0.65),Vector3.new(0,1.95,-1.05),0.16,METAL)
	local flames={}
	for _,side in ipairs({-1,1}) do
		local cf=CFrame.new(side*0.98,1.25,2.6)*CFrame.Angles(0,math.pi/2,0)
		part("TurboCanister",Vector3.new(1.65,0.86,0.86),cf,METAL,Enum.Material.Metal,exhaust,Enum.PartType.Cylinder)
		part("ExhaustTip",Vector3.new(0.2,0.72,0.72),CFrame.new(side*0.98,1.25,3.48)*CFrame.Angles(0,math.pi/2,0),BLACK,Enum.Material.Metal,exhaust,Enum.PartType.Cylinder)
		local at=Instance.new("Attachment"); at.Name="ExhaustOutlet"; at.Position=Vector3.new(side*0.98,1.25,3.65); at.Orientation=Vector3.new(0,180,0); at.Parent=chassis
		local flame=Instance.new("ParticleEmitter"); flame.Name="TurboFlame"; flame.Texture="rbxasset://textures/particles/fire_main.dds"; flame.EmissionDirection=Enum.NormalId.Front; flame.Rate=0; flame.Speed=NumberRange.new(12,19); flame.Lifetime=NumberRange.new(0.12,0.22); flame.SpreadAngle=Vector2.new(8,8); flame.LightEmission=1; flame.Color=ColorSequence.new(Color3.fromRGB(255,230,90),Color3.fromRGB(255,70,20)); flame.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.65),NumberSequenceKeypoint.new(1,0)}); flame.Parent=at
		local light=Instance.new("PointLight"); light.Color=Color3.fromRGB(255,143,30); light.Range=9; light.Brightness=0; light.Parent=at
		table.insert(flames,{emitter=flame,light=light})
	end
	local rootAt=Instance.new("Attachment"); rootAt.Name="StabilityAttachment"; rootAt.Parent=chassis
	local torque=Instance.new("Torque"); torque.Name="ArcadeStability"; torque.Attachment0=rootAt; torque.RelativeTo=Enum.ActuatorRelativeTo.World; torque.Parent=attachments
	local prompt=Instance.new("ProximityPrompt"); prompt.Name="EnterKart"; prompt.ActionText="Drive"; prompt.ObjectText="Racing Kart"; prompt.KeyboardKeyCode=Enum.KeyCode.E; prompt.MaxActivationDistance=9; prompt.RequiresLineOfSight=false; prompt.Parent=seat
	model:SetAttribute("IsRacingKart",true)
	model:SetAttribute("ColorName","Red")
	return {model=model,chassis=chassis,seat=seat,prompt=prompt,wheels=wheelData,torque=torque,steering=steeringMotor,steeringBase=steeringBase,hub=hub,flames=flames}
end

return Builder
