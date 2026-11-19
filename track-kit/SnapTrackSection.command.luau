-- In Studio Edit mode, select the fixed section first, then the section to move.
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

assert(RunService:IsStudio() and not RunService:IsRunning(), "Run the track snap command in Studio Edit mode.")
local selected = Selection:Get()
assert(#selected == 2 and selected[1]:IsA("Model") and selected[2]:IsA("Model"),
	"Select exactly two track section Models. Select the fixed section first, then the section to move.")

local fixed, moving = selected[1], selected[2]
assert(fixed ~= moving and not fixed:IsDescendantOf(moving) and not moving:IsDescendantOf(fixed),
	"Select two separate track sections.")

local function requireNamed(instances, name, className, sectionName)
	local message = string.format("Section %q needs one %s named %q.", sectionName, className, name)
	local found
	for _, instance in ipairs(instances) do
		if instance.Name == name then
			assert(not found and instance:IsA(className), message)
			found = instance
		end
	end
	assert(found, message)
	return found
end

local function connectors(section)
	local marker = requireNamed(section:GetChildren(), "Connectors", "BasePart", section.Name)
	local descendants = marker:GetDescendants()
	return requireNamed(descendants, "TrackIn", "Attachment", section.Name),
		requireNamed(descendants, "TrackOut", "Attachment", section.Name)
end

local _, fixedOut = connectors(fixed)
local movingIn = connectors(moving)
local pivotFromIn = movingIn.WorldCFrame:ToObjectSpace(moving:GetPivot())
local target = fixedOut.WorldCFrame * pivotFromIn

local recording = ChangeHistoryService:TryBeginRecording("TrackKitSnapSection", "Snap track section")
assert(recording, "Could not start an undo recording. Finish any other active Studio edit first.")
local ok, message = pcall(moving.PivotTo, moving, target)
ChangeHistoryService:FinishRecording(recording,
	if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
assert(ok, message)

Selection:Set({ moving })
print(string.format("Snapped %q to %q. The moved section is selected for the next join.", moving.Name, fixed.Name))
