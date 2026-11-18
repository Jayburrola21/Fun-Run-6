local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local camera = Workspace.CurrentCamera
while not camera do
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Wait()
	camera = Workspace.CurrentCamera
end

camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = 48
local target = Vector3.new(4, .15, -.6)
local elapsed = 0
RunService:BindToRenderStep("VolcanicLavaDemoCamera", Enum.RenderPriority.Camera.Value, function(dt)
	elapsed += dt
	local angle = -.48 + math.sin(elapsed * .13) * .21
	local eye = target + Vector3.new(math.sin(angle) * 65, 32, math.cos(angle) * 65)
	camera.CFrame = CFrame.lookAt(eye, target)
	camera.Focus = CFrame.new(target)
end)
script.Destroying:Connect(function()
	RunService:UnbindFromRenderStep("VolcanicLavaDemoCamera")
end)
