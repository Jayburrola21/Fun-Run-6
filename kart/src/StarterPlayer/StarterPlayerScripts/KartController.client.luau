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
local drift,turbo=false,false
local held={}
local analog=Vector2.zero
local clock=0
local Config=require(ReplicatedStorage:WaitForChild("KartSystem"):WaitForChild("KartConfig"))
local Dynamics=require(ReplicatedStorage.KartSystem.KartDynamics)
local presentations={}
local cameraFocus,cameraHeading
local cameraCF
local previousCamera
local previousJump
local previousZoom
local gui=Instance.new("ScreenGui"); gui.Name="KartHUD"; gui.ResetOnSpawn=false; gui.Enabled=false; gui.Parent=player:WaitForChild("PlayerGui")
local label=Instance.new("TextLabel"); label.Name="Telemetry"; label.AnchorPoint=Vector2.new(0.5,1); label.Position=UDim2.fromScale(0.5,0.96); label.Size=UDim2.fromOffset(490,76); label.BackgroundColor3=Color3.fromRGB(15,19,28); label.BackgroundTransparency=0.2; label.TextColor3=Color3.new(1,1,1); label.TextSize=19; label.Font=Enum.Font.GothamBold; label.TextWrapped=true; label.Parent=gui
local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,14); corner.Parent=label
local lines={}
local random=Random.new(17)
for n=1,18 do
	local line=Instance.new("Frame"); line.Name="SpeedLine"; line.BorderSizePixel=0; line.BackgroundColor3=Color3.fromRGB(180,225,255); line.AnchorPoint=Vector2.new(0.5,0.5); line.Visible=false; line.Parent=gui
	lines[n]={frame=line,angle=n*2*math.pi/18,phase=random:NextNumber()}
end

local function send(exit)
	if active then input:FireServer(throttle,steer,drift,turbo,exit or false) end
end

local function action(name,state,obj)
	if UserInputService:GetFocusedTextBox() then
		held={}; analog=Vector2.zero; throttle=0; steer=0; drift=false; turbo=false; send(false)
		return Enum.ContextActionResult.Pass
	end
	local down=state==Enum.UserInputState.Begin or state==Enum.UserInputState.Change
	if state==Enum.UserInputState.Cancel then down=false end
	if name=="KartThumbstick" then
		analog=down and Vector2.new(obj.Position.X,obj.Position.Y) or Vector2.zero
	elseif name=="KartExit" then
		if state==Enum.UserInputState.Begin then send(true) end
	else held[name..":"..obj.KeyCode.Name]=down end
	local function pressed(actionName)
		for key,value in pairs(held) do if value and key:sub(1,#actionName+1)==actionName..":" then return true end end
		return false
	end
	throttle=(pressed("KartForward") and 1 or 0)-(pressed("KartReverse") and 1 or 0)
	steer=(pressed("KartRight") and 1 or 0)-(pressed("KartLeft") and 1 or 0)
	if math.abs(analog.Y)>0.15 then throttle=analog.Y end
	if math.abs(analog.X)>0.15 then steer=analog.X end
	drift=pressed("KartDrift"); turbo=pressed("KartTurbo")
	return Enum.ContextActionResult.Sink
end

local bindings={
	{"KartForward","Gas",Enum.KeyCode.W,Enum.KeyCode.Up,Enum.KeyCode.ButtonR2},
	{"KartReverse","Brake",Enum.KeyCode.S,Enum.KeyCode.Down,Enum.KeyCode.ButtonL2},
	{"KartLeft","Left",Enum.KeyCode.A,Enum.KeyCode.Left},
	{"KartRight","Right",Enum.KeyCode.D,Enum.KeyCode.Right},
	{"KartDrift","Drift",Enum.KeyCode.Space,Enum.KeyCode.ButtonA},
	{"KartTurbo","Turbo",Enum.KeyCode.LeftShift,Enum.KeyCode.RightShift,Enum.KeyCode.ButtonX},
	{"KartExit","Exit",Enum.KeyCode.E,Enum.KeyCode.F,Enum.KeyCode.ButtonB},
}

local function stop()
	if not active then return end
	throttle=0; steer=0; drift=false; turbo=false; send(false)
	for _,binding in ipairs(bindings) do ContextActionService:UnbindAction(binding[1]) end
	ContextActionService:UnbindAction("KartThumbstick")
	if previousJump~=nil then player.AutoJumpEnabled=previousJump end
	if previousZoom then player.CameraMinZoomDistance=previousZoom[1]; player.CameraMaxZoomDistance=previousZoom[2] end
	local camera=workspace.CurrentCamera
	if camera and previousCamera then
		camera.CameraType=previousCamera.kind
		camera.CameraSubject=previousCamera.subject
		camera.FieldOfView=previousCamera.fov
	end
	active=nil; seat=nil; root=nil; cameraCF=nil; cameraFocus=nil; cameraHeading=nil; gui.Enabled=false
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
	for index,binding in ipairs(bindings) do
		local keys={table.unpack(binding,3)}
		ContextActionService:BindActionAtPriority(binding[1],action,true,3000,table.unpack(keys))
		ContextActionService:SetTitle(binding[1],binding[2])
		ContextActionService:SetPosition(binding[1],UDim2.new(1,-80-((index-1)%3)*82,1,-150-math.floor((index-1)/3)*78))
	end
	ContextActionService:BindActionAtPriority("KartThumbstick",action,false,3000,Enum.KeyCode.Thumbstick1)
	gui.Enabled=true; clock=1
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
	held={}; analog=Vector2.zero; throttle=0; steer=0; drift=false; turbo=false; send(false)
end)
UserInputService.TextBoxFocused:Connect(function()
	held={}; analog=Vector2.zero; throttle=0; steer=0; drift=false; turbo=false; send(false)
end)

local rayParams=RaycastParams.new(); rayParams.FilterType=Enum.RaycastFilterType.Exclude; rayParams.RespectCanCollide=true
RunService:BindToRenderStep("KartCamera",Enum.RenderPriority.Camera.Value+1,function(dt)
	if not active or not root then return end
	if not root:IsDescendantOf(workspace) then stop(); return end
	clock+=dt
	if clock>=1/30 then clock=0; send(false) end
	local camera=workspace.CurrentCamera
	if not camera then return end
	local cf=root.CFrame
	local speed=active:GetAttribute("Speed") or 0
	local boosting=active:GetAttribute("Boosting") or false
	local stage=active:GetAttribute("DriftStage") or 0
	local ready=active:GetAttribute("TurboReady")
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
	local focus=cameraFocus+cameraHeading*1.5
	local desired=focus-cameraHeading*(11+math.min(speed/40,2))+Vector3.new(0,4.5,0)
	rayParams.FilterDescendantsInstances={active,player.Character}
	local hit=workspace:Raycast(focus,desired-focus,rayParams)
	if hit then desired=hit.Position+hit.Normal*0.6 end
	local desiredCF=CFrame.lookAt(desired,focus)
	cameraCF=desiredCF -- focus and heading have already been independently filtered
	camera.CFrame=cameraCF -- no procedural shake, including drift and turbo
	local targetFov=70+math.clamp(speed/100,0,1)*12+(boosting and 5 or 0)
	camera.FieldOfView+=(targetFov-camera.FieldOfView)*(1-math.exp(-dt*5))
	label.Text=string.format("%03d studs/s   •   %s   •   Drift %d/3\nWASD / arrows   Space: drift   Shift: turbo   E/F: exit",math.floor(speed),boosting and "BOOST" or (ready and "TURBO READY" or "RECHARGING"),stage)
	for _,line in ipairs(lines) do
		local frame=line.frame
		frame.Visible=boosting and speed>85
		if frame.Visible then
			line.phase=(line.phase+dt*1.5)%1
			local radius=0.36+line.phase*0.25
			frame.Position=UDim2.fromScale(0.5+math.cos(line.angle)*radius,0.5+math.sin(line.angle)*radius)
			frame.Size=UDim2.fromOffset(18+line.phase*65,2)
			frame.Rotation=math.deg(line.angle); frame.BackgroundTransparency=0.65+line.phase*0.3
		end
	end
end)
