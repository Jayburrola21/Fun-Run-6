-- Angles in degrees, timing in seconds, and distances in studs.
return table.freeze({
	ModelName = "VolcanicDragon",
	IdleBreathPeriod = 4.8,
	IdleBreathScale = 1,
	Duration = 10,
	FireDuration = 5,
	SweepAngle = 27,
	FireRange = 105,
	FireDepression = 13,
	-- Optional: put the track's Workspace child name in TrackName to keep
	-- impact effects exclusive to that model and its descendants.
	TrackName = "",
	Effects = table.freeze({
		Quality = 1,
		WidthScale = 1,
	}),
})
