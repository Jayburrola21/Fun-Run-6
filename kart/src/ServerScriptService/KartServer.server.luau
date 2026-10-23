local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local System = ReplicatedStorage:WaitForChild("KartSystem")
local Config = require(System.KartConfig)
local Dynamics = require(System.KartDynamics)
local Builder = require(System.KartBuilder)

local remotes = Instance.new("Folder"); remotes.Name="Remotes"; remotes.Parent=System
local input = Instance.new("RemoteEvent"); input.Name="Input"; input.Parent=remotes
local states = {}
local playerStates = {}
local rates = {}
local sparkColors = {Color3.fromRGB(60,165,255),Color3.fromRGB(255,141,30),Color3.fromRGB(194,65,255)}
local world = workspace:FindFirstChild("RacingKarts") or Instance.new("Folder")
world.Name="RacingKarts"; world.Parent=workspace

local function restoreDriver(s)
	for part,original in pairs(s.driverMass or {}) do if part.Parent then part.Massless=original end end
	s.driverMass={}
	if s.driverCollision then s.driverCollision:Destroy(); s.driverCollision=nil end
	for _,ik in ipairs(s.iks or {}) do ik:Destroy() end
	s.iks={}
	if s.waist and s.waist.Parent then s.waist.C0=s.waistBase end
	s.waist=nil
	if s.humanoid and s.humanoid.Parent then
		s.humanoid.JumpPower=s.jumpPower
		s.humanoid.JumpHeight=s.jumpHeight
	end
	s.humanoid=nil
	if s.player then playerStates[s.player]=nil end
	s.player=nil; s.throttle=0; s.steer=0; s.drift=false; s.turbo=false
	s.charge=0; s.boostEnd=0; s.boostPower=0; s.cooldown=0; s.wasDrift=false
	s.model:SetAttribute("DriverUserId",0)
	s.prompt.Enabled=true
end

local function attachDriver(s)
	restoreDriver(s)
	local humanoid=s.seat.Occupant
	if not humanoid then return end
	local player=Players:GetPlayerFromCharacter(humanoid.Parent)
	if not player or playerStates[player] then humanoid.Sit=false; return end
	s.player=player; playerStates[player]=s; s.humanoid=humanoid
	s.jumpPower=humanoid.JumpPower; s.jumpHeight=humanoid.JumpHeight
	-- Space is drift while seated. E/F or gamepad B exits explicitly.
	humanoid.JumpPower=0; humanoid.JumpHeight=0
	s.prompt.Enabled=false; s.lastInput=os.clock()
	s.chassis.Anchored=false
	s.chassis:SetNetworkOwner(nil) -- authoritative forces, boosts and speed caps
	-- An animated driver's limbs must not shift the physics assembly's COM or
	-- collide with its hull. Restore every original Massless flag on departure.
	s.driverMass={}
	s.driverCollision=Instance.new("Folder"); s.driverCollision.Name="DriverCollisionOverrides"; s.driverCollision.Parent=s.model
	local hulls={s.chassis}
	for _,part in ipairs(s.model.Suspension:GetChildren()) do
		if part:IsA("BasePart") and part.CanCollide then table.insert(hulls,part) end
	end
	for _,part in ipairs(humanoid.Parent:GetDescendants()) do
		if part:IsA("BasePart") then
			s.driverMass[part]=part.Massless; part.Massless=true
			for _,hull in ipairs(hulls) do
				local constraint=Instance.new("NoCollisionConstraint"); constraint.Part0=part; constraint.Part1=hull; constraint.Parent=s.driverCollision
			end
		end
	end
	s.model:SetAttribute("DriverUserId",player.UserId)
	if humanoid.RigType==Enum.HumanoidRigType.R15 then
		for _,side in ipairs({"Left","Right"}) do
			local upper=humanoid.Parent:FindFirstChild(side.."UpperArm")
			local hand=humanoid.Parent:FindFirstChild(side.."Hand")
			if upper and hand then
				local ik=Instance.new("IKControl"); ik.Name="Kart"..side.."Grip"
				ik.Type=Enum.IKControlType.Position; ik.ChainRoot=upper; ik.EndEffector=hand
				ik.Target=s.hub:FindFirstChild(side.."Grip"); ik.Weight=1; ik.SmoothTime=0.08; ik.Priority=10; ik.Parent=humanoid
				table.insert(s.iks,ik)
			end
		end
		local upperTorso=humanoid.Parent:FindFirstChild("UpperTorso")
		local waist=upperTorso and upperTorso:FindFirstChild("Waist")
		if waist and waist:IsA("Motor6D") then s.waist=waist; s.waistBase=waist.C0 end
	end
end

local function spawnKart(cf, colorName)
	local s=Builder.build("RacingKart",cf,Config.Palette[colorName] or Config.Palette.Red)
	s.model:SetAttribute("ColorName",colorName)
	s.model.Parent=world
	CollectionService:AddTag(s.model,"RacingKart")
	s.spawn=cf; s.throttle=0; s.steer=0; s.visualSteer=0; s.drift=false; s.turbo=false
	s.lastInput=0; s.charge=0; s.boostEnd=0; s.boostPower=0; s.cooldown=0; s.wasDrift=false
	s.visualClock=0; s.iks={}; s.emptyTime=0
	s.filteredSteer=0; s.filteredThrottle=0; s.driftBlend=0; s.normal=Vector3.yAxis; s.driveAccel=0
	s.params=RaycastParams.new(); s.params.FilterType=Enum.RaycastFilterType.Exclude
	s.params.RespectCanCollide=true
	s.chassis:SetNetworkOwner(nil)
	s.prompt.Triggered:Connect(function(player)
		local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not humanoid or humanoid.Health<=0 or not root or playerStates[player] or s.seat.Occupant or s.reserved then return end
		if (root.Position-s.seat.Position).Magnitude>11 then return end
		s.reserved=true; s.prompt.Enabled=false
		s.seat:Sit(humanoid)
		task.delay(1,function()
			s.reserved=false
			if s.model.Parent and not s.seat.Occupant then s.prompt.Enabled=true end
		end)
	end)
	s.seat:GetPropertyChangedSignal("Occupant"):Connect(function() attachDriver(s) end)
	table.insert(states,s)
end

local markers=workspace:FindFirstChild("KartSpawns")
if markers then
	for _,marker in ipairs(markers:GetChildren()) do
		if marker:IsA("BasePart") then
			marker.CanCollide=false; marker.CanTouch=false; marker.CanQuery=false; marker.Transparency=1
			spawnKart(marker.CFrame,marker:GetAttribute("ColorName") or "Red")
		end
	end
end
if #states==0 then spawnKart(Config.SpawnCFrame,"Red") end

input.OnServerEvent:Connect(function(player, throttle, steer, drift, turbo, exit)
	local now=os.clock()
	local rate=rates[player]
	if not rate or now-rate.time>=1 then rate={time=now,count=0}; rates[player]=rate end
	rate.count+=1
	if rate.count>Config.InputRate+15 then return end
	local s=playerStates[player]
	if not s or s.seat.Occupant~=s.humanoid or s.humanoid.Health<=0 then return end
	if not Dynamics.finite(throttle) or not Dynamics.finite(steer) or type(drift)~="boolean" or type(turbo)~="boolean" or type(exit)~="boolean" then return end
	s.lastInput=now
	if exit then s.humanoid.Sit=false; return end
	s.throttle=math.clamp(throttle,-1,1); s.steer=math.clamp(steer,-1,1)
	s.drift=drift; s.turbo=turbo
end)

Players.PlayerRemoving:Connect(function(player)
	local s=playerStates[player]
	if s then
		if s.humanoid then s.humanoid.Sit=false end
		restoreDriver(s)
	end
	rates[player]=nil
end)

RunService.PreSimulation:Connect(function(delta)
	local dt=math.min(delta,1/15)
	local now=os.clock()
	local characters={}
	for _,player in ipairs(Players:GetPlayers()) do
		if player.Character then table.insert(characters,player.Character) end
	end
	for index=#states,1,-1 do
		local s=states[index]
		if not s.model:IsDescendantOf(workspace) then
			restoreDriver(s); table.remove(states,index); continue
		end
		local root=s.chassis
		if root.Position.Y<workspace.FallenPartsDestroyHeight+30 then
			if s.humanoid then s.humanoid.Sit=false end
			restoreDriver(s); root.Anchored=false; s.model:PivotTo(s.spawn)
			root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero
		end
		if s.player and now-s.lastInput>Config.InputTimeout then
			s.throttle=0; s.steer=0; s.drift=false; s.turbo=false; s.charge=0; s.wasDrift=false
		end
		local exclusions={s.model,table.unpack(characters)}
		s.params.FilterDescendantsInstances=exclusions
		local mass=root.AssemblyMass
		if root.Anchored then mass=root:GetMass() end
		local cf=root.CFrame
		local velocity=root.AssemblyLinearVelocity
		local speed=velocity:Dot(cf.LookVector)
		local contacts={}; local groundNormal=Vector3.zero
		for _,wheel in ipairs(s.wheels) do
			local mount=cf:PointToWorldSpace(wheel.origin)
			local ray=workspace:Raycast(mount,-cf.UpVector*(Config.WheelRadius+Config.SuspensionRest+Config.SuspensionTravel),s.params)
			wheel.distance=Config.SuspensionRest+Config.SuspensionTravel
			wheel.force.Force=Vector3.zero
			if ray and ray.Normal.Y>0.15 then
				wheel.distance=math.max(-0.2,ray.Distance-Config.WheelRadius)
				local compression=Config.SuspensionRest-wheel.distance
				-- Include moving ground velocity so platforms do not kick the springs.
				local groundVelocity=Vector3.zero
				if ray.Instance:IsA("BasePart") then groundVelocity=ray.Instance:GetVelocityAtPosition(ray.Position) end
				-- Damp heave here, not angular point velocity: four full-strength
				-- corner dampers massively overdamp the low-inertia chassis roll.
				-- Pitch/roll receive a separate inertia-scaled angular damper below.
				local vertical=(velocity-groundVelocity):Dot(cf.UpVector)
				local support=Dynamics.suspension(compression,vertical,workspace.Gravity,Config)*mass/4
				wheel.force.Force=cf.UpVector*support
				table.insert(contacts,wheel); groundNormal+=ray.Normal
			end
		end
		local grounded=#contacts>=2
		local drifting,boost=Dynamics.updateBoost(s,now,dt,grounded,speed,Config)
		s.filteredSteer=Dynamics.approach(s.filteredSteer,s.player and s.steer or 0,Config.SteerResponse,dt)
		s.filteredThrottle=Dynamics.approach(s.filteredThrottle,s.player and s.throttle or 0,Config.ThrottleResponse,dt)
		if math.abs(s.filteredThrottle)<0.001 then s.filteredThrottle=0 end
		s.driftBlend=Dynamics.approach(s.driftBlend,drifting and 1 or 0,drifting and Config.DriftEnterResponse or Config.DriftExitResponse,dt)
		local steerAngle,desiredYaw=Dynamics.steering(speed,s.filteredSteer,s.driftBlend,Config)
		local targetNormal=grounded and groundNormal.Unit or s.normal
		s.normal=s.normal:Lerp(targetNormal,1-math.exp(-dt*Config.NormalResponse)).Unit
		local normal=s.normal
		local forward=cf.LookVector-normal*cf.LookVector:Dot(normal)
		if forward.Magnitude>0.01 then forward=forward.Unit else forward=cf.LookVector end
		local right=forward:Cross(normal).Unit
		-- Tire traction acts once at the COM. It no longer injects a second yaw
		-- controller at the axles or rolls the chassis by acting above its COM.
		local sideAccel=Dynamics.lateral(speed,velocity:Dot(right),s.filteredSteer,s.driftBlend,Config)
		local drive=Dynamics.longitudinal(speed,s.filteredThrottle,boost,Config)
		if not s.player then drive=math.clamp(-speed*10,-80,80) end
		s.driveAccel=Dynamics.approach(s.driveAccel,drive,10,dt)
		s.driveForce.Force=grounded and (forward*s.driveAccel+right*sideAccel)*mass*(#contacts/4) or Vector3.zero
		if grounded then
			local angular=root.AssemblyAngularVelocity
			local tilt=cf.UpVector:Cross(normal)
			local inertia=mass*(root.Size.X^2+root.Size.Z^2)/12
			local pitchInertia=mass*(root.Size.Y^2+root.Size.Z^2)/12
			local rollInertia=mass*(root.Size.X^2+root.Size.Y^2)/12
			local yawAccel=math.clamp((desiredYaw-angular:Dot(normal))*Config.YawResponse,-Config.MaxYawAcceleration,Config.MaxYawAcceleration)
			-- Springs handle contact roll/pitch; this bounded damper suppresses
			-- excess tilt instead of repeatedly forcing a new orientation.
			local angularDamping=cf.RightVector*angular:Dot(cf.RightVector)*pitchInertia*26
				+cf.LookVector*angular:Dot(cf.LookVector)*rollInertia*26
			s.torque.Torque=tilt*10*inertia-angularDamping+normal*yawAccel*inertia
		else s.torque.Torque=-root.AssemblyAngularVelocity*mass*0.8 end
		-- Empty vehicles settle before anchoring, then remain parked even on slopes.
		if not s.player then
			s.emptyTime+=dt
			if grounded and (velocity.Magnitude<1 or s.emptyTime>2) then
				root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero; root.Anchored=true
			end
		else
			s.emptyTime=0
			local hardLimit=Config.MaxSpeed+Config.DriftBoostPower[3]+15
			local horizontal=Vector3.new(velocity.X,0,velocity.Z)
			if horizontal.Magnitude>hardLimit then
				local capped=horizontal.Unit*hardLimit
				root.AssemblyLinearVelocity=Vector3.new(capped.X,velocity.Y,capped.Z)
			end
		end
		s.visualSteer=steerAngle
		s.visualClock+=delta
		if s.visualClock>=1/20 then
			s.visualClock=0
			local stage=drifting and Dynamics.stage(s.charge,Config.DriftStages) or 0
			for _,wheel in ipairs(s.wheels) do
				wheel.motor:SetAttribute("SuspensionDistance",wheel.distance)
				wheel.emitterAt.Position=wheel.origin-Vector3.new(0,wheel.distance+Config.WheelRadius,0)
				wheel.smoke.Rate=drifting and not wheel.front and 12 or 0
				wheel.sparks.Rate=stage>0 and not wheel.front and 14 or 0
				if stage>0 then wheel.sparks.Color=ColorSequence.new(sparkColors[stage]) end
			end
			s.model:SetAttribute("SteerAngle",s.visualSteer)
			s.model:SetAttribute("DriftBlend",s.driftBlend)
			if s.waist then s.waist.C0=s.waistBase*CFrame.Angles(0,0,-s.visualSteer*0.16) end
			for _,flame in ipairs(s.flames) do flame.emitter.Rate=boost>0 and 35 or 0; flame.light.Brightness=boost>0 and 2 or 0; flame.smoke.Rate=s.player and s.filteredThrottle>0.1 and 3 or 0 end
			for _,light in ipairs(s.model.Effects:GetChildren()) do
				if light.Name=="BrakeLight" and light:IsA("BasePart") then
					local braking=s.throttle<0 and speed>2
					light.Material=braking and Enum.Material.Neon or Enum.Material.SmoothPlastic
					light.Color=braking and Color3.fromRGB(255,30,35) or Color3.fromRGB(110,5,10)
				end
			end
			s.model:SetAttribute("Speed",math.abs(speed)); s.model:SetAttribute("Boosting",boost>0)
			s.model:SetAttribute("DriftStage",stage); s.model:SetAttribute("TurboReady",now>=s.cooldown)
		end
	end
end)
