local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local ContextActionService=game:GetService("ContextActionService")
local UserInputService=game:GetService("UserInputService")
local CollectionService=game:GetService("CollectionService")
local player=Players.LocalPlayer
local input=ReplicatedStorage:WaitForChild("KartSystem"):WaitForChild("Remotes"):WaitForChild("Input")
local active,seat,root
local throttle,steer=0,0
local drift=false
local held={}
local analog=Vector2.zero
local clock=0
local Config=require(ReplicatedStorage:WaitForChild("KartSystem"):WaitForChild("KartConfig"))
local Dynamics=require(ReplicatedStorage.KartSystem:WaitForChild("KartDynamics"))
local presentations={}
local cameraFocus,cameraHeading
local cameraCF
local previousCamera
local previousJump
local previousZoom
local HUD=require(ReplicatedStorage.KartSystem:WaitForChild("KartHUD"))
local hud=HUD.new(player:WaitForChild("PlayerGui"),Config)
local previousStates
local seatedHumanoid
local originalStates=setmetatable({},{__mode="k"})
local lockedStates={Enum.HumanoidStateType.Jumping,Enum.HumanoidStateType.GettingUp}

-- Capture local defaults before entering; do not sample a state already locked
-- by another part of the seating lifecycle and later restore that false value.
local function rememberCharacter(character)
	local humanoid=character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid",10)
	if humanoid and not originalStates[humanoid] then
		local states={}
		for _,state in ipairs(lockedStates) do states[state]=humanoid:GetStateEnabled(state) end
		originalStates[humanoid]=states
	end
end
player.CharacterAdded:Connect(rememberCharacter)
if player.Character then rememberCharacter(player.Character) end

local function send()
	if active then input:FireServer(throttle,steer,drift) end
end

local function action(name,state,obj)
	if UserInputService:GetFocusedTextBox() then
		held={}; analog=Vector2.zero; throttle=0; steer=0; drift=false; send()
		return Enum.ContextActionResult.Pass
	end
	if name=="KartBlockExitJump" then return Enum.ContextActionResult.Sink end
	local down=state==Enum.UserInputState.Begin or state==Enum.UserInputState.Change
	if state==Enum.UserInputState.Cancel then down=false end
	if name=="KartThumbstick" then
		analog=down and Vector2.new(obj.Position.X,obj.Position.Y) or Vector2.zero

	else held[name..":"..obj.KeyCode.Name]=down end
	local function pressed(actionName)
		for key,value in pairs(held) do if value and key:sub(1,#actionName+1)==actionName..":" then return true end end
		return false
	end
	throttle=(pressed("KartForward") and 1 or 0)-(pressed("KartReverse") and 1 or 0)
	steer=(pressed("KartRight") and 1 or 0)-(pressed("KartLeft") and 1 or 0)
	if math.abs(analog.Y)>0.15 then throttle=analog.Y end
	if math.abs(analog.X)>0.15 then steer=analog.X end
	drift=pressed("KartDrift")
	return Enum.ContextActionResult.Sink
end

local bindings={
	{"KartForward","Gas",Enum.KeyCode.W,Enum.KeyCode.Up,Enum.KeyCode.ButtonR2},
	{"KartReverse","Brake",Enum.KeyCode.S,Enum.KeyCode.Down,Enum.KeyCode.ButtonL2},
	{"KartLeft","Left",Enum.KeyCode.A,Enum.KeyCode.Left},
	{"KartRight","Right",Enum.KeyCode.D,Enum.KeyCode.Right},
	{"KartDrift","DRIFT",Enum.KeyCode.LeftShift,Enum.KeyCode.RightShift,Enum.KeyCode.ButtonA,Enum.KeyCode.ButtonX},
	{"KartBlockExitJump","",Enum.KeyCode.Space,Enum.KeyCode.E,Enum.KeyCode.F,Enum.KeyCode.ButtonB},
}

local function stop()
	if not active then return end
	throttle=0; steer=0; drift=false; send()
	for _,binding in ipairs(bindings) do ContextActionService:UnbindAction(binding[1]) end
	ContextActionService:UnbindAction("KartThumbstick")
	if seatedHumanoid and seatedHumanoid.Parent and previousStates then
		for state,enabled in pairs(previousStates) do seatedHumanoid:SetStateEnabled(state,enabled) end
	end
	seatedHumanoid=nil; previousStates=nil
	if previousJump~=nil then player.AutoJumpEnabled=previousJump end
	if previousZoom then player.CameraMinZoomDistance=previousZoom[1]; player.CameraMaxZoomDistance=previousZoom[2] end
	local camera=workspace.CurrentCamera
	if camera and previousCamera then
		camera.CameraType=previousCamera.kind
		camera.CameraSubject=previousCamera.subject
		camera.FieldOfView=previousCamera.fov
	end
	active=nil; seat=nil; root=nil; cameraCF=nil; cameraFocus=nil; cameraHeading=nil; hud:SetVisible(false)
	held={}; analog=Vector2.zero
end

local function start(model)
	if active==model then return end
	stop()
	local driverSeat=model:FindFirstChild("DriverSeat")
	local chassis=model:FindFirstChild("Chassis")
	if not driverSeat or not chassis then return end
	active=model; seat=driverSeat; root=chassis
	local camera=workspace.CurrentCamera
	if not camera then stop(); return end
	previousCamera={kind=camera.CameraType,subject=camera.CameraSubject,fov=camera.FieldOfView}
	previousJump=player.AutoJumpEnabled; player.AutoJumpEnabled=false
	previousZoom={player.CameraMinZoomDistance,player.CameraMaxZoomDistance}
	camera.CameraType=Enum.CameraType.Scriptable
	seatedHumanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	previousStates={}
	if seatedHumanoid then
		for _,state in ipairs(lockedStates) do
			local original=originalStates[seatedHumanoid]
			local attribute=state==Enum.HumanoidStateType.Jumping and "DriverJumpingBeforeLock" or "DriverGettingUpBeforeLock"
			local beforeLock=model:GetAttribute(attribute)
			if type(beforeLock)=="boolean" then previousStates[state]=beforeLock
			else previousStates[state]=original and original[state] end
			if previousStates[state]==nil then previousStates[state]=seatedHumanoid:GetStateEnabled(state) end
			seatedHumanoid:SetStateEnabled(state,false)
		end
		seatedHumanoid.Jump=false
	end
	for index,binding in ipairs(bindings) do
		local keys={table.unpack(binding,3)}
		local touch=binding[1]~="KartBlockExitJump"
		ContextActionService:BindActionAtPriority(binding[1],action,touch,5000,table.unpack(keys))
		if touch then
			ContextActionService:SetTitle(binding[1],binding[2])
			local positions={UDim2.new(1,-88,1,-166),UDim2.new(1,-170,1,-100),UDim2.new(0,45,1,-130),UDim2.new(0,133,1,-130),UDim2.new(1,-88,1,-82)}
			ContextActionService:SetPosition(binding[1],positions[index])
			local button=ContextActionService:GetButton(binding[1])
			if button then
				button.ImageColor3=binding[1]=="KartDrift" and Color3.fromRGB(76,224,255) or Color3.fromRGB(38,57,83)
				button.ImageTransparency=0.12
			end
		end
	end
	ContextActionService:BindActionAtPriority("KartThumbstick",action,false,5000,Enum.KeyCode.Thumbstick1)
	hud:SetVisible(true); clock=1
end

local function prepareVisuals(model)
	if presentations[model] then return end
	local chassis=model:FindFirstChild("Chassis")
	local wheels=model:FindFirstChild("Wheels")
	local steering=model:FindFirstChild("SteeringWheel")
	if not chassis or not wheels or not steering then return end
	local hub=steering:FindFirstChild("Hub")
	local motor=hub and hub:FindFirstChild("SteeringMotor")
	if not motor then return end
	local state={root=chassis,wheels={},steering=motor,base=motor.C0,angle=0}
	for _,wheel in ipairs(wheels:GetChildren()) do
		local tire=wheel:FindFirstChild("Tire")
		local wheelMotor=tire and tire:FindFirstChild("WheelMotor")
		if wheelMotor then
			table.insert(state.wheels,{motor=wheelMotor,origin=wheelMotor.C0.Position+Vector3.new(0,Config.SuspensionRest,0),distance=Config.SuspensionRest,spin=0,speed=0,front=wheel.Name:sub(1,5)=="Front"})
		end
	end
	presentations[model]=state
end

-- Every observer animates the same replicated assembly locally at render rate.
-- Motors are visual only; no client writes physics velocity or position.
RunService:BindToRenderStep("KartVisuals",Enum.RenderPriority.Character.Value+1,function(dt)
	for model,state in pairs(presentations) do
		if not model:IsDescendantOf(workspace) or not state.root:IsDescendantOf(workspace) then presentations[model]=nil; continue end
		state.angle=Dynamics.approach(state.angle,model:GetAttribute("SteerAngle") or 0,18,dt)
		for _,wheel in ipairs(state.wheels) do
			local target=wheel.motor:GetAttribute("SuspensionDistance") or Config.SuspensionRest
			local response=target<wheel.distance and Config.VisualSuspensionResponse*2 or Config.VisualSuspensionResponse
			wheel.distance=Dynamics.approach(wheel.distance,target,response,dt)
			local direction=(state.root.CFrame*CFrame.Angles(0,wheel.front and state.angle or 0,0)).LookVector
			local pv=state.root:GetVelocityAtPosition(state.root.CFrame:PointToWorldSpace(wheel.origin))
			wheel.speed=Dynamics.approach(wheel.speed,pv:Dot(direction),16,dt)
			wheel.spin=(wheel.spin-wheel.speed/Config.WheelRadius*dt)%(math.pi*2)
			wheel.motor.C0=CFrame.new(wheel.origin-Vector3.new(0,wheel.distance,0))*CFrame.Angles(0,wheel.front and state.angle or 0,0)*CFrame.Angles(wheel.spin,0,0)
		end
		state.steering.C0=state.base*CFrame.Angles(0,0,state.angle*1.8)
	end
end)

local function watch(model)
	prepareVisuals(model)
	local function changed()
		prepareVisuals(model)
		if model:GetAttribute("DriverUserId")==player.UserId then start(model)
		elseif active==model then stop() end
	end
	model:GetAttributeChangedSignal("DriverUserId"):Connect(changed)
	model.AncestryChanged:Connect(function() if active==model and not model:IsDescendantOf(workspace) then stop() end end)
	changed()
end
for _,model in ipairs(CollectionService:GetTagged("RacingKart")) do watch(model) end
CollectionService:GetInstanceAddedSignal("RacingKart"):Connect(watch)
player.CharacterRemoving:Connect(stop)
UserInputService.WindowFocusReleased:Connect(function()
	held={}; analog=Vector2.zero; throttle=0; steer=0; drift=false; send()
end)
UserInputService.TextBoxFocused:Connect(function()
	held={}; analog=Vector2.zero; throttle=0; steer=0; drift=false; send()
end)

UserInputService.JumpRequest:Connect(function()
	if active and seatedHumanoid then seatedHumanoid.Jump=false end
end)

local rayParams=RaycastParams.new(); rayParams.FilterType=Enum.RaycastFilterType.Exclude; rayParams.RespectCanCollide=true
RunService:BindToRenderStep("KartCamera",Enum.RenderPriority.Camera.Value+1,function(dt)
	if not active or not root then return end
	if not root:IsDescendantOf(workspace) then stop(); return end
	clock+=dt
	if clock>=1/30 then clock=0; send() end
	local camera=workspace.CurrentCamera
	if not camera then return end
	local cf=root.CFrame
	local speed=active:GetAttribute("Speed") or 0
	local boosting=active:GetAttribute("Boosting") or false
	local flat=Vector3.new(cf.LookVector.X,0,cf.LookVector.Z)
	if flat.Magnitude<0.01 then flat=Vector3.new(0,0,-1) else flat=flat.Unit end
	local motion=Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z)
	local blend=active:GetAttribute("DriftBlend") or 0
	if motion.Magnitude>10 and motion.Unit:Dot(flat)>0.3 then flat=flat:Lerp(motion.Unit,blend*0.3).Unit end
	cameraHeading=cameraHeading and cameraHeading:Lerp(flat,1-math.exp(-dt*Config.CameraHeadingResponse)).Unit or flat
	-- Compensate the horizontal filter's steady-speed lag; otherwise stacking
	-- position and CFrame filters makes the kart outrun its camera at high speed.
	local targetFocus=root.Position+Vector3.new(0,1.7,0)+motion/Config.CameraPositionResponse
	if cameraFocus then
		local planar=1-math.exp(-dt*Config.CameraPositionResponse)
		local vertical=1-math.exp(-dt*Config.CameraHeightResponse)
		cameraFocus=Vector3.new(cameraFocus.X+(targetFocus.X-cameraFocus.X)*planar,cameraFocus.Y+(targetFocus.Y-cameraFocus.Y)*vertical,cameraFocus.Z+(targetFocus.Z-cameraFocus.Z)*planar)
	else cameraFocus=targetFocus end
	local scale=Config.ModelScale
	local focus=cameraFocus+cameraHeading*(1.5*scale)
	local desired=focus-cameraHeading*((11+math.min(speed/40,2))*scale)+Vector3.new(0,4.5*scale,0)
	rayParams.FilterDescendantsInstances={active,player.Character}
	local hit=workspace:Raycast(focus,desired-focus,rayParams)
	if hit then desired=hit.Position+hit.Normal*0.6 end
	local desiredCF=CFrame.lookAt(desired,focus)
	cameraCF=desiredCF -- focus and heading have already been independently filtered
	camera.CFrame=cameraCF -- no procedural shake, including drift and turbo
	local targetFov=70+math.clamp(speed/100,0,1)*12+(boosting and 5 or 0)
	camera.FieldOfView+=(targetFov-camera.FieldOfView)*(1-math.exp(-dt*5))
	hud:Update(active,speed,dt,workspace:GetServerTimeNow(),camera.ViewportSize,UserInputService.TouchEnabled,{
		lap=player:GetAttribute("KartLap"),totalLaps=player:GetAttribute("KartTotalLaps"),
		coins=player:GetAttribute("KartCoins"),wins=player:GetAttribute("KartWins"),
	})
end)
