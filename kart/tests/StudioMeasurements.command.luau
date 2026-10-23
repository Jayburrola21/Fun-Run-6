-- Paste into the SERVER Command Bar during Play. Drive on a FLAT baseplate.
-- Reports observed motion; it does not automatically certify driving feel.
local kart=assert(workspace:FindFirstChild("RacingKarts") and workspace.RacingKarts:FindFirstChild("RacingKart"),"No kart")
local root=kart.Chassis
assert(kart.DriverSeat.Occupant,"Enter the kart first")
task.spawn(function()
	local elapsed,count,sumVertical,sumRollPitch,maxVertical,maxRollPitch=0,0,0,0,0,0
	print("Kart measurement: drive straight on flat ground for the next 10 seconds.")
	while elapsed<10 and root.Parent do
		local dt=game:GetService("RunService").Heartbeat:Wait()
		local vertical=math.abs(root.AssemblyLinearVelocity.Y)
		local angular=root.AssemblyAngularVelocity
		local rollPitch=math.sqrt(angular:Dot(root.CFrame.RightVector)^2+angular:Dot(root.CFrame.LookVector)^2)
		elapsed+=dt; count+=1; sumVertical+=vertical^2*dt; sumRollPitch+=rollPitch^2*dt
		maxVertical=math.max(maxVertical,vertical); maxRollPitch=math.max(maxRollPitch,rollPitch)
	end
	print(string.format("Kart measured %d samples / %.2fs: vertical velocity RMS %.4f studs/s (peak %.4f); roll/pitch angular velocity RMS %.4f rad/s (peak %.4f)",count,elapsed,math.sqrt(sumVertical/elapsed),maxVertical,math.sqrt(sumRollPitch/elapsed),maxRollPitch))
end)
