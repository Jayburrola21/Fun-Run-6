-- Paste into Studio's SERVER Command Bar during Play after installing the kart.
-- This checks the running engine graph and real suspension forces, not driving feel.
local folder=assert(workspace:FindFirstChild("RacingKarts"),"KartServer did not start")
local kart=assert(folder:FindFirstChild("RacingKart"),"Kart was not generated")
local root=assert(kart:FindFirstChild("Chassis"),"Missing chassis")
local seat=assert(kart:FindFirstChild("DriverSeat"),"Missing seat")
assert(seat:IsA("VehicleSeat"),"Wrong seat class")
assert(root.CanCollide,"Chassis must collide")
assert(kart.Attachments.TireTraction.ApplyAtCenterOfMass,"Traction must not apply roll/yaw at wheel mounts")
assert(kart.ModelStreamingMode==Enum.ModelStreamingMode.Atomic,"Streaming must keep assemblies together")
assert(#kart.Wheels:GetChildren()==4,"Expected four wheels")
assert(kart.SteeringWheel.Hub:FindFirstChild("LeftGrip"),"Missing left grip")
assert(kart.SteeringWheel.Hub:FindFirstChild("RightGrip"),"Missing right grip")
local forceCount=0
for _,wheel in ipairs(kart.Wheels:GetChildren()) do
	local motor=assert(wheel.Tire:FindFirstChild("WheelMotor"),"Missing wheel motor")
	assert(motor.Part0==root and motor.Part1==wheel.Tire,"Broken wheel assembly")
	for _,part in ipairs(wheel:GetDescendants()) do
		if part:IsA("BasePart") then assert(not part.CanCollide and part.Massless and not part.Anchored,"Visual wheel conflicts with physics") end
	end
end
for _,force in ipairs(kart.Suspension:GetChildren()) do
	if force:IsA("VectorForce") then
		forceCount+=1
		assert(force.Attachment0 and force.Attachment0.Parent==root,"Missing force mount")
		assert(force.RelativeTo==Enum.ActuatorRelativeTo.World,"Wrong force coordinates")
		assert(force.Force.Magnitude==force.Force.Magnitude,"Non-finite force")
	end
end
assert(forceCount==4,"Expected four contact forces")
if not root.Anchored then assert(root:GetNetworkOwner()==nil,"Physics must be server-owned") end
if seat.Occupant and seat.Occupant.RigType==Enum.HumanoidRigType.R15 then
	assert(seat.Occupant:FindFirstChild("KartLeftGrip"),"Missing left IK")
	assert(seat.Occupant:FindFirstChild("KartRightGrip"),"Missing right IK")
end
if seat.Occupant then
	assert(kart:GetAttribute("DriverLocked"),"Driver must be seat-locked")
	assert(not seat.Occupant:GetStateEnabled(Enum.HumanoidStateType.Jumping),"Jump must remain disabled")
	assert(not seat.Occupant:GetStateEnabled(Enum.HumanoidStateType.GettingUp),"Get-up must remain disabled")
end
assert(type(kart:GetAttribute("DriftCharge"))=="number","Missing authoritative charge meter")
assert(type(kart:GetAttribute("TurboCooldownEnd"))=="number","Missing authoritative cooldown deadline")
print("PASS: Studio assembly/constraint smoke check. Driving and multiplayer checklist still required.")
