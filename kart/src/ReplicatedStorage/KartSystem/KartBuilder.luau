local Config = require(script.Parent.KartConfig)
local Builder = {}
local WHITE = Color3.fromRGB(235, 239, 245)
local BLACK = Color3.fromRGB(20, 23, 30)
local RUBBER = Color3.fromRGB(13, 14, 19)
local METAL = Color3.fromRGB(90, 101, 119)
local BLUE = Color3.fromRGB(20, 85, 220)
local YELLOW = Color3.fromRGB(255, 205, 35)
local SEAT = Color3.fromRGB(12, 14, 18)

function Builder.build(name, spawn, color)
	color = color or Config.Palette.Red
	local scale = Config.ModelScale or 0.84
	-- Build once in canonical units, then scale the entire assembly together.
	local rest = Config.SuspensionRest / scale
	local radius = Config.WheelRadius / scale
	local track = (Config.WheelTrack or 4.40*scale) / scale
	local wheelbase = Config.Wheelbase / scale
	local tireWidth = 0.76
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
		return part(label, Vector3.new((b-a).Magnitude, width, width), CFrame.lookAt((a+b)/2,b)*CFrame.Angles(0,math.pi/2,0), tint, Enum.Material.Metal, parent, Enum.PartType.Cylinder)
	end
	local function ring(parent, base, radius, thickness, tint, material, count, target)
		for i = 1, count do
			local angle = (i-0.5)*math.pi*2/count
			local cf = base * CFrame.Angles(0,0,angle) * CFrame.new(radius,0,0) * CFrame.Angles(0,0,math.pi/2)
			local segment = part("RingSegment", Vector3.new(2*radius*math.tan(math.pi/count), thickness, thickness), cf, tint, material, parent, nil, target ~= nil)
			if material==Enum.Material.Neon then segment.Name="BoostGlow"; segment.Transparency=1 end
			if target then
				local w = Instance.new("WeldConstraint"); w.Part0 = target; w.Part1 = segment; w.Parent = segment
			end
		end
	end
	local function rounded(label,size,cf,tint,radius,parent)
		radius=math.min(radius,size.X/2-0.01,size.Z/2-0.01)
		part(label,Vector3.new(size.X-2*radius,size.Y,size.Z),cf,tint,nil,parent)
		for _,side in ipairs({-1,1}) do
			part(label,Vector3.new(radius,size.Y,size.Z-2*radius),cf*CFrame.new(side*(size.X/2-radius/2),0,0),tint,nil,parent)
		end
		for _,x in ipairs({-1,1}) do for _,z in ipairs({-1,1}) do
			-- Flattened ellipsoids curve away from the top surface; flat cylinder
			-- caps would overlap the panels and create visible z-fighting.
			part(label.."Corner",Vector3.new(2*radius,size.Y,2*radius),cf*CFrame.new(x*(size.X/2-radius),0,z*(size.Z/2-radius)),tint,nil,parent,Enum.PartType.Ball)
		end end
	end

	chassis = part("Chassis", Vector3.new(3.7,0.5,6.5), CFrame.new(), BLACK, Enum.Material.Metal, model, nil, true)
	chassis.Massless = false; chassis.CanCollide = true; chassis.CanQuery = true
	-- Preserve the original mass/inertia collider for unchanged driving feel.
	-- Rendered bodywork has true wheel cutouts and conceals this collision box.
	chassis.Transparency = 1
	chassis.CustomPhysicalProperties = PhysicalProperties.new(3.5,0.12,0,100,100)
	chassis.RootPriority=127
	model.PrimaryPart = chassis
	part("FloorPan",Vector3.new(2.45,0.12,3.60),CFrame.new(0,0.34,0.1),BLACK,Enum.Material.SmoothPlastic)
	part("TaperedSkid",Vector3.new(2.65,0.22,5.80),CFrame.new(0,-0.10,-0.05),BLACK,nil,body,Enum.PartType.Ball)
	part("EnclosedLowerShell",Vector3.new(3.25,0.48,3.95),CFrame.new(0,0.05,0.40),BLUE,nil,body,Enum.PartType.Ball)
	-- A tapered, crowned hood loft follows a gentle longitudinal curve. The
	-- white center stripe is part of that surface instead of a floating decal.
	part("BlueNoseLower",Vector3.new(2.45,0.66,2.5),CFrame.new(0,0.15,-2.12),BLUE,nil,body,Enum.PartType.Ball)
	part("RedNoseCore",Vector3.new(2.18,0.58,2.58),CFrame.new(0,0.62,-2.10)*CFrame.Angles(math.rad(-22),0,0),color,nil,body,Enum.PartType.Ball)
	local function hood(t)
		return -3.22+2.37*t,0.40+1.10*t+0.16*math.sin(math.pi*t),2.25-0.43*t
	end
	for i=0,7 do
		local z0,y0,width0=hood(i/8)
		local z1,y1,width1=hood((i+1)/8)
		local width=(width0+width1)/2
		local length=math.sqrt((z1-z0)^2+(y1-y0)^2)+0.012
		local tilt=-math.atan((y1-y0)/(z1-z0))
		local middle=CFrame.new(0,(y0+y1)/2,(z0+z1)/2)*CFrame.Angles(tilt,0,0)
		part("WhiteCenterStripe",Vector3.new(0.84,0.055,length),middle,WHITE)
		for _,side in ipairs({-1,1}) do
			local panel=(width-0.84)/2
			local x=side*(0.42+panel/2)
			local crown=0.10*(math.abs(x)/(width/2))^2
			local bank=-0.20*x/(width/2)^2
			part("RedHoodPanel",Vector3.new(panel+0.018,0.075,length),middle*CFrame.new(x,-crown,0)*CFrame.Angles(0,0,bank),color)
		end
	end
	for _,side in ipairs({-1,1}) do
		part("RoundedHoodEdge",Vector3.new(0.27,0.27,2.48),CFrame.new(side*0.98,0.88,-2.03)*CFrame.Angles(math.rad(-26),-side*math.rad(6),0),color,nil,body,Enum.PartType.Ball)
	end
	-- Red tilted square with a real white center, centered on the stripe.
	local bz,by=hood(0.53)
	local badge=CFrame.new(0,by+0.07,bz)*CFrame.Angles(math.rad(-26),math.rad(15),0)
	for _,side in ipairs({-1,1}) do
		part("NoseSquareBadge",Vector3.new(0.55,0.012,0.16),badge*CFrame.new(0,0,side*0.195),color)
		part("NoseSquareBadge",Vector3.new(0.16,0.012,0.23),badge*CFrame.new(side*0.195,0,0),color)
	end
	-- Full-length curved pods enclose the lower cockpit and blend into the
	-- rear housing. Their front tips and rear haunches stop inside wheel sweep.
	for _,side in ipairs({-1,1}) do
		part("SidePodBlue",Vector3.new(0.74,0.52,2.80),CFrame.new(side*1.33,0.13,0.30),BLUE,nil,body,Enum.PartType.Ball)
		part("SidePodWhite",Vector3.new(0.70,0.18,2.78),CFrame.new(side*1.34,0.36,0.30),WHITE,nil,body,Enum.PartType.Ball)
		part("SidePodRed",Vector3.new(0.66,1.10,2.70),CFrame.new(side*1.34,0.64,0.30),color,nil,body,Enum.PartType.Ball)
		part("RoundSidePanel",Vector3.new(0.12,1.05,1.05),CFrame.new(side*1.625,0.64,0.35),color,nil,body,Enum.PartType.Cylinder)
		part("WhiteSideRoundel",Vector3.new(0.012,0.78,0.78),CFrame.new(side*1.695,0.64,0.35),WHITE,nil,body,Enum.PartType.Cylinder)
		local sideBadge=CFrame.new(side*1.708,0.64,0.35)*CFrame.Angles(math.rad(15),0,0)
		for _,offset in ipairs({-1,1}) do
			part("SideSquareBadge",Vector3.new(0.010,0.48,0.14),sideBadge*CFrame.new(0,0,offset*0.17),color)
			part("SideSquareBadge",Vector3.new(0.010,0.14,0.20),sideBadge*CFrame.new(0,offset*0.17,0),color)
		end
		bar("CockpitRail",Vector3.new(side*1.06,0.97,-0.50),Vector3.new(side*1.06,1.12,1.30),0.10,BLACK)
		part("RearHaunch",Vector3.new(0.56,0.85,1.40),CFrame.new(side*1.36,0.56,1.53),color,nil,body,Enum.PartType.Ball)
	end

	local bumper=folder("FrontBumper")
	rounded("WhiteFrontBumper",Vector3.new(2.80,0.28,0.62),CFrame.new(0,0.13,-3.22)*CFrame.Angles(math.pi/2,0,0),WHITE,0.23,bumper)
	for _,x in ipairs({-1.02,-0.52,0.52,1.02}) do
		part("BlueBumperVent",Vector3.new(0.22,0.31,0.035),CFrame.new(x*0.88,0.12,-3.375)*CFrame.Angles(0,0,math.rad(-12)),BLUE,nil,bumper)
	end
	bar("BumperLower",Vector3.new(-1.30,-0.25,-3.23),Vector3.new(1.30,-0.25,-3.23),0.15,BLACK,bumper)
	for _,side in ipairs({-1,1}) do
		bar("BumperCorner",Vector3.new(side*1.30,-0.25,-3.23),Vector3.new(side*1.40,0.22,-3.16),0.15,BLACK,bumper)
		local lamp=part("LED",Vector3.new(0.22,0.07,0.035),CFrame.new(side*1.30,0.42,-3.15),WHITE,Enum.Material.Neon,headlights)
		local beam=Instance.new("SpotLight"); beam.Face=Enum.NormalId.Front; beam.Brightness=0.8; beam.Range=22; beam.Angle=70; beam.Parent=lamp
		part("BrakeLight",Vector3.new(0.32,0.13,0.04),CFrame.new(side*1.16,0.48,2.86),Color3.fromRGB(110,5,10),nil,effects)
	end
	local seat=part("DriverSeat",Vector3.new(1.95,0.3,1.65),CFrame.new(0,0.84,0.65),SEAT,Enum.Material.Fabric,model,nil,false,"VehicleSeat")
	seat.HeadsUpDisplay=false; seat.MaxSpeed=0; seat.Torque=0; seat.TurnSpeed=0
	rounded("SeatBack",Vector3.new(1.95,0.28,1.75),CFrame.new(0,1.66,1.42)*CFrame.Angles(math.rad(80),0,0),SEAT,0.27)
	for _,side in ipairs({-1,1}) do
		part("SeatBolster",Vector3.new(0.22,0.9,0.6),CFrame.new(side*0.96,1.29,1.10)*CFrame.Angles(0,0,side*0.12),SEAT,Enum.Material.Fabric)
		bar("RearGuard",Vector3.new(side*1.58,0.10,1.35),Vector3.new(side*1.58,0.10,2.72),0.13,BLACK)
	end
	-- A closed engine cowl joins both haunches and the seat into one rear.
	part("RearLowerHousing",Vector3.new(3.10,0.54,1.65),CFrame.new(0,0.21,2.00),BLUE,nil,body,Enum.PartType.Ball)
	part("RearEngineHousing",Vector3.new(3.00,0.86,1.55),CFrame.new(0,0.68,1.97),color,nil,body,Enum.PartType.Ball)
	part("EngineInset",Vector3.new(1.20,0.10,0.65),CFrame.new(0,1.06,2.00),BLACK,Enum.Material.Metal)
	for i=1,5 do part("EngineCoolingFin",Vector3.new(1.10,0.04,0.055),CFrame.new(0,1.12,1.69+i*0.105),METAL,Enum.Material.Metal) end
	bar("RearAxle",Vector3.new(-2.05,0.40,2.16),Vector3.new(2.05,0.40,2.16),0.18,METAL)
	rounded("RearBumper",Vector3.new(3.10,0.34,0.40),CFrame.new(0,0.12,2.93),BLACK,0.16,body)
	part("RearBumperAccent",Vector3.new(2.65,0.09,0.04),CFrame.new(0,0.21,3.145),WHITE)

	for _,side in ipairs({-1,1}) do
		local lower=Vector3.new(side*1.08,0.34,-1.48)
		local upper=Vector3.new(side*0.94,1.28,-1.20)
		local axis=upper-lower
		local shock=CFrame.lookAt((lower+upper)/2,upper)
		bar("DamperRod",lower,upper,0.075,METAL,suspension)
		bar("DamperBody",lower,lower+axis*0.45,0.17,METAL,suspension)
		for _,point in ipairs({lower,upper}) do
			part("DamperEye",Vector3.new(0.22,0.22,0.22),CFrame.new(point),BLACK,Enum.Material.Metal,suspension,Enum.PartType.Ball)
		end
		local previous
		for n=0,32 do
			local t=n/32
			local phase=t*math.pi*8
			local offset=Vector3.new(math.cos(phase)*0.13,math.sin(phase)*0.13,(t-0.5)*axis.Magnitude*0.83)
			local point=(shock*CFrame.new(offset)).Position
			if previous then bar("BlueCoilSpring",previous,point,0.043,BLUE,suspension) end
			previous=point
		end
	end

	-- Non-colliding visual wheels; each client interpolates these same motors.
	-- Physical contacts are handled only by the spring forces and collision hull.
	local wheelData={}
	for _,desc in ipairs({{"FrontLeft",-1,-wheelbase/2,true},{"FrontRight",1,-wheelbase/2,true},{"RearLeft",-1,wheelbase/2,false},{"RearRight",1,wheelbase/2,false}}) do
		local label,side,z,front=table.unpack(desc)
		local group=Instance.new("Model"); group.Name=label; group.Parent=wheels
		local origin=Vector3.new(side*track/2,rest+0.4,z)
		-- Smaller chassis-mounted collision shells catch walls/curbs without
		-- competing with the raycast tires during normal spring compression.
		local guard=part(label.."Collision",Vector3.new(0.64,1.22,1.22),CFrame.new(origin-Vector3.new(0,0.35,0)),BLACK,Enum.Material.SmoothPlastic,suspension,Enum.PartType.Ball)
		guard.Transparency=1; guard.CanCollide=true; guard.CanQuery=true
		guard.CustomPhysicalProperties=PhysicalProperties.new(0.1,0.1,0,100,100)
		local cf=CFrame.new(origin-Vector3.new(0,rest,0))
		local tire=part("Tire",Vector3.new(tireWidth,2*radius,2*radius),cf,RUBBER,Enum.Material.SmoothPlastic,group,Enum.PartType.Cylinder,true)
		local motor=Instance.new("Motor6D"); motor.Name="WheelMotor"; motor.Part0=chassis; motor.Part1=tire; motor.C0=cf; motor.Parent=tire
		local function detail(label,size,offset,tint,material,shape)
			local p=part(label,size,cf*offset,tint,material,group,shape,true)
			local w=Instance.new("WeldConstraint"); w.Part0=tire; w.Part1=p; w.Parent=p
			return p
		end
		detail("Sidewall",Vector3.new(0.060,1.82,1.82),CFrame.new(side*0.367,0,0),RUBBER,Enum.Material.SmoothPlastic,Enum.PartType.Cylinder)
		detail("Rim",Vector3.new(0.080,1.28,1.28),CFrame.new(side*0.40,0,0),YELLOW,Enum.Material.Metal,Enum.PartType.Cylinder)
		detail("RimLip",Vector3.new(0.025,1.39,1.39),CFrame.new(side*0.395,0,0),YELLOW,Enum.Material.Metal,Enum.PartType.Cylinder)
		for _,offset in ipairs({-1,1}) do
			detail("RimCutout",Vector3.new(0.02,0.24,0.31),CFrame.new(side*0.448,offset*0.20,offset*0.11)*CFrame.Angles(math.rad(25),0,0),BLACK,Enum.Material.SmoothPlastic)
		end
		for n=1,12 do
			for _,offset in ipairs({-0.20,0.20}) do
				detail("Tread",Vector3.new(0.018,0.012,0.18),CFrame.Angles(n*math.pi/6,0,0)*CFrame.new(offset,radius,0),Color3.fromRGB(25,26,30),Enum.Material.SmoothPlastic)
			end
		end
		if not front then
			ring(group,cf*CFrame.new(side*0.455,0,0)*CFrame.Angles(0,math.pi/2,0),0.72,0.040,Color3.fromRGB(50,185,255),Enum.Material.Neon,16,tire)
		end
		local mount=Instance.new("Attachment"); mount.Name=label.."Mount"; mount.Position=origin; mount.Parent=chassis
		local force=Instance.new("VectorForce"); force.Name=label.."Contact"; force.Attachment0=mount; force.RelativeTo=Enum.ActuatorRelativeTo.World; force.ApplyAtCenterOfMass=false; force.Force=Vector3.zero; force.Parent=suspension
		local emitterAt=Instance.new("Attachment"); emitterAt.Name=label.."ContactEffects"; emitterAt.Position=origin-Vector3.new(0,rest+radius,0); emitterAt.Parent=chassis
		local smoke=Instance.new("ParticleEmitter"); smoke.Name="TireSmoke"; smoke.Texture="rbxasset://textures/particles/smoke_main.dds"; smoke.Color=ColorSequence.new(Color3.fromRGB(180,187,200)); smoke.Lifetime=NumberRange.new(0.3,0.6); smoke.Speed=NumberRange.new(1,3); smoke.Rate=0; smoke.SpreadAngle=Vector2.new(30,30); smoke.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.3),NumberSequenceKeypoint.new(1,1.8)}); smoke.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.65),NumberSequenceKeypoint.new(1,1)}); smoke.Parent=emitterAt
		local sparks=Instance.new("ParticleEmitter"); sparks.Name="DriftSparks"; sparks.Texture="rbxasset://textures/particles/sparkles_main.dds"; sparks.Lifetime=NumberRange.new(0.12,0.28); sparks.Speed=NumberRange.new(3,7); sparks.SpreadAngle=Vector2.new(45,45); sparks.LightEmission=1; sparks.Size=NumberSequence.new(0.18); sparks.Rate=0; sparks.Parent=emitterAt
		local glow={}
		for _,p in ipairs(group:GetChildren()) do if p:IsA("BasePart") and p.Material==Enum.Material.Neon then table.insert(glow,p) end end
		table.insert(wheelData,{motor=motor,origin=origin,front=front,force=force,smoke=smoke,sparks=sparks,emitterAt=emitterAt,glow=glow,spin=0})
		bar("Wishbone",Vector3.new(side*1.16,0.05,z),origin-Vector3.new(0,rest,0),0.13,METAL,suspension)
	end
	local steering=Instance.new("Model"); steering.Name="SteeringWheel"; steering.Parent=model
	local steeringBase=CFrame.new(0,1.95,-1.05)*CFrame.Angles(math.rad(-24),0,0)
	local hub=part("Hub",Vector3.new(0.24,0.24,0.18),steeringBase,BLACK,Enum.Material.Metal,steering,nil,true)
	local steeringMotor=Instance.new("Motor6D"); steeringMotor.Name="SteeringMotor"; steeringMotor.Part0=chassis; steeringMotor.Part1=hub; steeringMotor.C0=steeringBase; steeringMotor.Parent=hub
	ring(steering,steeringBase,0.63,0.12,BLACK,Enum.Material.SmoothPlastic,24,hub)
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
		local pipe=CFrame.new(side*0.78,1.06154,2.58005)*CFrame.Angles(-math.atan(0.32/0.948),0,0)
		part("BlackExhaust",Vector3.new(0.76,0.470,0.470),pipe*CFrame.Angles(0,math.pi/2,0),BLACK,Enum.Material.Metal,exhaust,Enum.PartType.Cylinder)
		part("YellowExhaustLip",Vector3.new(0.075,0.492,0.492),pipe*CFrame.new(0,0,0.38)*CFrame.Angles(0,math.pi/2,0),YELLOW,Enum.Material.Metal,exhaust,Enum.PartType.Cylinder)
		part("ExhaustOpening",Vector3.new(0.04,0.36,0.36),pipe*CFrame.new(0,0,0.428)*CFrame.Angles(0,math.pi/2,0),RUBBER,Enum.Material.SmoothPlastic,exhaust,Enum.PartType.Cylinder)
		local at=Instance.new("Attachment"); at.Name="ExhaustOutlet"; at.CFrame=pipe*CFrame.new(0,0,0.46)*CFrame.Angles(0,math.pi,0); at.Parent=chassis
		local flame=Instance.new("ParticleEmitter"); flame.Name="TurboFlame"; flame.Texture="rbxasset://textures/particles/fire_main.dds"; flame.EmissionDirection=Enum.NormalId.Front; flame.Rate=0; flame.Speed=NumberRange.new(12,19); flame.Lifetime=NumberRange.new(0.12,0.22); flame.SpreadAngle=Vector2.new(8,8); flame.LightEmission=1; flame.Color=ColorSequence.new(Color3.fromRGB(255,230,90),Color3.fromRGB(255,70,20)); flame.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.65),NumberSequenceKeypoint.new(1,0)}); flame.Parent=at
		local light=Instance.new("PointLight"); light.Color=Color3.fromRGB(255,143,30); light.Range=9; light.Brightness=0; light.Parent=at
		local smoke=Instance.new("ParticleEmitter"); smoke.Name="EngineExhaust"; smoke.Texture="rbxasset://textures/particles/smoke_main.dds"; smoke.Rate=0; smoke.Lifetime=NumberRange.new(0.25,0.45); smoke.Speed=NumberRange.new(2,4); smoke.EmissionDirection=Enum.NormalId.Front; smoke.Size=NumberSequence.new(0.25); smoke.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.85),NumberSequenceKeypoint.new(1,1)}); smoke.Parent=at
		table.insert(flames,{emitter=flame,light=light,smoke=smoke})
	end
	local rootAt=Instance.new("Attachment"); rootAt.Name="StabilityAttachment"; rootAt.Parent=chassis
	local torque=Instance.new("Torque"); torque.Name="ArcadeStability"; torque.Attachment0=rootAt; torque.RelativeTo=Enum.ActuatorRelativeTo.World; torque.Parent=attachments
	local driveForce=Instance.new("VectorForce"); driveForce.Name="TireTraction"; driveForce.Attachment0=rootAt; driveForce.RelativeTo=Enum.ActuatorRelativeTo.World; driveForce.ApplyAtCenterOfMass=true; driveForce.Force=Vector3.zero; driveForce.Parent=attachments
	local prompt=Instance.new("ProximityPrompt"); prompt.Name="EnterKart"; prompt.ActionText="Drive"; prompt.ObjectText="Racing Kart"; prompt.KeyboardKeyCode=Enum.KeyCode.E; prompt.MaxActivationDistance=9; prompt.RequiresLineOfSight=false; prompt.Parent=seat
	model:SetAttribute("IsRacingKart",true)
	model:SetAttribute("ColorName","Red")
	-- ScaleTo also scales Attachments, Motor6Ds and their welded children about
	-- the chassis pivot. Metadata returned to the physics controller must agree.
	model:ScaleTo(scale)
	for _,wheel in ipairs(wheelData) do wheel.origin=wheel.origin*scale end
	steeringBase=steeringMotor.C0
	model:SetAttribute("ModelScale",scale)
	return {model=model,chassis=chassis,seat=seat,prompt=prompt,wheels=wheelData,driveForce=driveForce,torque=torque,steering=steeringMotor,steeringBase=steeringBase,hub=hub,flames=flames}
end

return Builder
