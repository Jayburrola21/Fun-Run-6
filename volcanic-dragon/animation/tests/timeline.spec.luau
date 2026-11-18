-- Run from any directory with the standalone Luau CLI.
local Timeline = require("../src/ReplicatedStorage/VolcanicDragon/Timeline")

local angles = {
    "basePitch", "midPitch", "upperPitch", "headPitch",
    "baseYaw", "midYaw", "upperYaw", "headYaw", "jawOpen",
}
local yawFields = { "headYaw", "upperYaw", "midYaw", "baseYaw" }
local radians = math.rad
local passes = 0

local function check(condition: boolean, message: string)
    assert(condition, message)
    passes += 1
end

local function near(actual: number, expected: number, tolerance: number, message: string)
    check(math.abs(actual - expected) <= tolerance,
        string.format("%s (expected %.5f ± %.5f, got %.5f)", message, expected, tolerance, actual))
end

local function resting(time: number, config)
    local pose = Timeline.sample(time, config)
    for _, field in angles do
        near(pose[field], 0, 1e-6, "Rest pose " .. field)
    end
    near(pose.fire, 0, 1e-6, "Rest pose fire")
    return pose
end

local function neckPitch(pose)
    return pose.basePitch + pose.midPitch + pose.upperPitch
end

local function fireWindow(config, duration: number)
    local startTime, endTime
    local peak = 0
    local step = .005
    for sample = 0, math.floor(duration / step) do
        local time = sample * step
        local fire = Timeline.sample(time, config).fire
        peak = math.max(peak, fire)
        if fire > 1e-4 then
            startTime = startTime or time
            endTime = time
        end
    end
    assert(startTime and endTime, "The animation must have a sustained fire phase")
    return startTime, endTime, peak
end

local function risingZero(field: string, startTime: number, endTime: number, direction: number)
    local step = .005
    local previous = direction * Timeline.sample(startTime, {})[field]
    for time = startTime + step, endTime, step do
        local value = direction * Timeline.sample(time, {})[field]
        if previous < 0 and value >= 0 then
            return time
        end
        previous = value
    end
    error("No crossing during the outward fire sweep for " .. field)
end

local default = {}
near(Timeline.duration(default), 10, 1e-6, "Default duration")
check(not resting(-.01, default).active, "The event must not be active before its scheduled start")
resting(0, default)
check(not resting(10, default).active, "The event must stop at its duration")
check(not resting(100, default).active, "The event must remain at rest after completion")

local previous = Timeline.sample(0, default)
for index = 1, 1000 do
    local time = index / 100
    local pose = Timeline.sample(time, default)
    check(type(pose.active) == "boolean", "Active flag is a boolean")
    check(pose.active == (time < 10), "Active flag matches the event interval")
    check(type(pose.fire) == "number" and pose.fire >= 0 and pose.fire <= 1, "Fire stays normalized")
    check(math.abs(pose.fire - previous.fire) < .2, "Fire ramps instead of switching instantly")
    for _, field in angles do
        local value = pose[field]
        check(type(value) == "number" and value == value and math.abs(value) < math.huge, field .. " stays finite")
        check(math.abs(value - previous[field]) < .055, field .. " moves continuously")
    end
    previous = pose
end

local earlyWake = Timeline.sample(.30, default)
local lateWake = Timeline.sample(1.42, default)
local aiming = Timeline.sample(2.47, default)
local attacking = Timeline.sample(4.10, default)
local cooling = Timeline.sample(8.70, default)
check(math.abs(neckPitch(lateWake)) > math.abs(neckPitch(earlyWake)) + radians(3), "The neck lifts during awakening")
check(math.abs(aiming.headPitch - lateWake.headPitch) > radians(4), "The head changes pitch to aim")
check(aiming.jawOpen > 0 and aiming.jawOpen < attacking.jawOpen, "The jaw opens partially while targeting")
check(attacking.jawOpen >= radians(25) and attacking.jawOpen <= radians(35), "The attacking jaw opens 25–35 degrees")
check(cooling.jawOpen < attacking.jawOpen, "The jaw closes during recovery")
near(Timeline.sample(2.35, default).fire, 0, 1e-6, "No fire while aiming")
near(Timeline.sample(7.70, default).fire, 0, 1e-6, "Fire is off during recovery")

local fireStart, fireEnd, firePeak = fireWindow(default, 10)
near(fireStart, 2.5, .12, "Default fire starts around 2.5 seconds")
near(Timeline.sample(1.25, default).hornHeat, 0, 1e-8, "Horn tips start dark")
local heatUp = Timeline.sample(2, default)
check(heatUp.hornHeat > 0 and heatUp.hornHeat < 1 and heatUp.fire == 0, "Horn tips heat up before ignition")
near(Timeline.sample(2.5, default).hornHeat, 1, 1e-8, "Horn tips reach full heat at ignition")
near(Timeline.sample(4, default).hornHeat, 1, 1e-8, "Horn tips stay hot during the fire")
local coolDown = Timeline.sample(8.1, default)
check(coolDown.hornHeat > 0 and coolDown.hornHeat < 1 and coolDown.fire == 0,
    "Horn tips cool during recovery after the fire stops")
near(Timeline.sample(8.75, default).hornHeat, 0, 1e-8, "Horn tips finish cooling before idle")
near(Timeline.pose(20, math.huge, default).hornHeat, 0, 1e-8, "Horn tips stay dark in idle")
near(fireEnd, 7.5, .12, "Default fire ends around 7.5 seconds")
check(firePeak >= .9, "Breath has a sustained full-strength interval")

local outwardDirection = Timeline.sample(2.65, default).headYaw < 0 and 1 or -1
local headCrossing = risingZero("headYaw", 2.65, 5.65, outwardDirection)
local previousCrossing = headCrossing
for i = 2, #yawFields do
    local time = risingZero(yawFields[i], 2.65, 5.65, outwardDirection)
    check(time >= previousCrossing - .015, yawFields[i] .. " does not turn ahead of the preceding joint")
    previousCrossing = time
end
check(previousCrossing - headCrossing >= .16, "The neck base follows the head with a visible delay")
check(previousCrossing - headCrossing <= .65, "The neck base follows within the same sweep")

local peakOrientedYaw = -math.huge
local peakTime = 0
local initialYaw = outwardDirection * Timeline.sample(2.68, default).headYaw
local finalYaw = outwardDirection * Timeline.sample(7.36, default).headYaw
for i = 270, 728 do
    local time = i / 100
    local value = outwardDirection * Timeline.sample(time, default).headYaw
    if value > peakOrientedYaw then
        peakOrientedYaw = value
        peakTime = time
    end
end
check(initialYaw < radians(-4), "The first sweep starts to one side of the track")
check(peakOrientedYaw > radians(10) and peakTime > 3.0 and peakTime < 7.0, "The sweep reaches the opposite side")
check(finalYaw < peakOrientedYaw - radians(16), "The sweep reverses before the breath ends")
local yawAtTurn = Timeline.sample(peakTime, default).headYaw
local yawBeforeTurn = Timeline.sample(peakTime - .04, default).headYaw
local yawAfterTurn = Timeline.sample(peakTime + .04, default).headYaw
near(yawBeforeTurn, yawAtTurn, radians(1), "Head decelerates into the reversal")
near(yawAfterTurn, yawAtTurn, radians(1), "Head accelerates out of the reversal")

local custom = { Duration = 12, FireDuration = 4, SweepAngle = 13.5, FireRange = 85 }
near(Timeline.duration(custom), 12, 1e-6, "Configurable duration")
local customStart, customEnd, customPeak = fireWindow(custom, 12)
near(customEnd - customStart, 4, .25, "Configurable fire duration")
check(customPeak >= .9, "Custom configuration still produces a full-strength breath")
resting(12, custom)

local sameTiming = { SweepAngle = 13.5 }
local testYaw = Timeline.sample(peakTime, default).headYaw
local smallYaw = Timeline.sample(peakTime, sameTiming).headYaw
near(smallYaw, .5 * testYaw, radians(1), "Halving sweep angle halves horizontal aim")
local first = Timeline.sample(4.18, default)
resting(10, default)
local repeated = Timeline.sample(4.18, default)
for _, field in angles do
    near(repeated[field], first[field], 1e-8, "Repeated trigger does not accumulate " .. field)
end
near(repeated.fire, first.fire, 1e-8, "Repeated trigger produces the same fire envelope")

local idleConfig = { IdleBreathPeriod = 5 }
local exhale = Timeline.pose(0, math.huge, idleConfig)
local inhale = Timeline.pose(2.5, math.huge, idleConfig)
local nextInhale = Timeline.pose(7.5, math.huge, idleConfig)
check(inhale.basePitch - exhale.basePitch > radians(1), "Idle raises the neck on inhale")
check(inhale.headPitch < exhale.headPitch, "Head counters the neck lift")
check(inhale.chestRise > exhale.chestRise + .06, "Chest rises on inhale")
near(inhale.jawOpen, 0, 1e-8, "Idle keeps the jaw closed")
near(inhale.fire, 0, 1e-8, "Idle emits no fire")
for _, field in angles do
    near(nextInhale[field], inhale[field], 1e-8, "Idle loops smoothly for " .. field)
    near(Timeline.pose(2.5, math.huge, { IdleBreathScale = 0 })[field], 0, 1e-8, "Idle can be disabled")
end

local leaning = Timeline.pose(9.6, math.huge, idleConfig)
local settled = Timeline.pose(13, math.huge, idleConfig)
check(leaning.headRoll > radians(2), "Idle occasionally tilts the head")
check(leaning.basePitch > Timeline.pose(4.6, math.huge, idleConfig).basePitch + radians(1),
    "The slight lean lifts the neck on top of continuous breathing")
near(settled.headRoll, 0, 1e-8, "The head eases back to neutral")

local function idleBlink(age)
    return Timeline.pose(age, math.huge, idleConfig).blink
end
near(idleBlink(0.13), 0, 1e-8, "Eyes start open")
near(idleBlink(3.2), 0, 1e-8, "Eyes are open before a blink")
check(idleBlink(3.25) > 0 and idleBlink(3.25) < 1, "Lids close gradually")
near(idleBlink(3.33), 1, 1e-8, "Lids close fully")
check(idleBlink(3.43) > 0 and idleBlink(3.43) < 1, "Lids reopen gradually")
near(idleBlink(3.56), 0, 1e-8, "Eyes return fully open")
near(idleBlink(8.73), 1, 1e-8, "The next blink has a different interval")
near(idleBlink(22.83), 1, 1e-8, "Blink timing continues across cycle boundaries")

for _, edge in { 0, 10 } do
    for _, offset in { -0.001, 0, 0.001 } do
        local pose = Timeline.pose(2.5 + offset, edge + offset, idleConfig)
        for _, field in angles do
            near(pose[field], inhale[field], radians(0.01), "Idle transition is continuous for " .. field)
        end
        near(pose.chestRise, inhale.chestRise, 0.0001, "Chest blends continuously at the attack boundary")
        local blinking = Timeline.pose(3.33 + offset, edge + offset, idleConfig)
        near(blinking.blink, 1, 1e-6, "Blink blends continuously at the attack boundary")
    end
end

local firePose = Timeline.pose(2.5, 4.18, idleConfig)
near(firePose.fire, first.fire, 1e-8, "Idle leaves the fire envelope unchanged")
check(firePose.headRoll == nil and firePose.chestRise == nil and firePose.blink == nil,
    "Idle pose layers are neutral during the fire phase")
for _, field in angles do
    near(firePose[field], first[field], 1e-8, "Idle leaves the fire pose unchanged for " .. field)
end

print(string.format("PASS: %d dragon timeline assertions", passes))
