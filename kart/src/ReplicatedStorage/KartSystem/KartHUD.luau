-- Client presentation only. All charge, boost and cooldown decisions are server-owned.
local HUD = {}
HUD.__index = HUD

local INK = Color3.fromRGB(9, 14, 25)
local CYAN = Color3.fromRGB(76, 224, 255)
local GOLD = Color3.fromRGB(255, 214, 96)
local MUTED = Color3.fromRGB(133, 153, 178)
local WHITE = Color3.fromRGB(240, 248, 255)

local function create(class, props, parent)
	local instance = Instance.new(class)
	for key, value in pairs(props) do instance[key] = value end
	instance.Parent = parent
	return instance
end

local function corner(parent, radius)
	create("UICorner", {CornerRadius = UDim.new(0, radius)}, parent)
end

local function text(parent, name, position, size, value, fontSize, color, font)
	return create("TextLabel", {
		Name = name, Position = position, Size = size,
		BackgroundTransparency = 1, BorderSizePixel = 0,
		Text = value, TextColor3 = color, TextSize = fontSize,
		Font = font or Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, parent)
end

function HUD.new(playerGui, config)
	local self = setmetatable({}, HUD)
	self.config = config
	self.progress = 0
	self.speed = 0
	self.viewport = Vector2.zero
	self.gui = create("ScreenGui", {
		Name = "KartHUD", ResetOnSpawn = false, Enabled = false,
		IgnoreGuiInset = false, DisplayOrder = 20, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)
	local shell = create("Frame", {
		Name = "DriveCluster", AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -28, 1, -28), Size = UDim2.fromOffset(370, 150),
		BackgroundColor3 = INK, BackgroundTransparency = 0.07,
		BorderSizePixel = 0, ClipsDescendants = true,
	}, self.gui)
	self.shell = shell
	corner(shell, 18)
	self.outline = create("UIStroke", {
		Color = Color3.fromRGB(75, 114, 147), Transparency = 0.45, Thickness = 1.2,
	}, shell)
	create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(29, 46, 68)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 12, 22)),
		}), Rotation = 25,
	}, shell)
	self.scale = create("UIScale", {Scale = 1}, shell)
	self.edge = create("Frame", {
		Name = "AccentEdge", Position = UDim2.fromOffset(0, 18),
		Size = UDim2.fromOffset(3, 114), BorderSizePixel = 0, BackgroundColor3 = CYAN,
	}, shell)
	-- Racing slashes add depth without requiring any uploaded image assets.
	for index = 1, 3 do
		create("Frame", {
			Name = "RacingSlash", Position = UDim2.fromOffset(292 + index * 22, -25),
			Size = UDim2.fromOffset(10, 200), Rotation = 22,
			BorderSizePixel = 0, BackgroundColor3 = CYAN, BackgroundTransparency = 0.95,
		}, shell)
	end
	text(shell, "SpeedCaption", UDim2.fromOffset(20, 13), UDim2.fromOffset(100, 18), "MPH", 10, MUTED)
	self.speedText = text(shell, "Speed", UDim2.fromOffset(17, 27), UDim2.fromOffset(111, 79), "000", 64, WHITE, Enum.Font.GothamBlack)
	self.speedBars = {}
	for index = 1, 9 do
		local bar = create("Frame", {
			Name = "SpeedBar", Position = UDim2.fromOffset(22 + (index - 1) * 10, 127 - index * 1.7),
			Size = UDim2.fromOffset(6, 6 + index * 1.7),
			BorderSizePixel = 0, BackgroundColor3 = CYAN, BackgroundTransparency = 0.82,
		}, shell)
		corner(bar, 2)
		self.speedBars[index] = bar
	end
	create("Frame", {
		Name = "Divider", Position = UDim2.fromOffset(135, 22), Size = UDim2.fromOffset(1, 107),
		BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(84, 119, 150), BackgroundTransparency = 0.6,
	}, shell)
	text(shell, "BoostCaption", UDim2.fromOffset(153, 15), UDim2.fromOffset(166, 18), "T U R B O", 10, MUTED)
	self.status = text(shell, "BoostState", UDim2.fromOffset(153, 37), UDim2.fromOffset(196, 29), "TURBO", 22, CYAN, Enum.Font.GothamBlack)
	self.timer = text(shell, "BoostTimer", UDim2.fromOffset(153, 68), UDim2.fromOffset(192, 24), "", 19, WHITE)
	self.stateDot = create("Frame", {
		Name = "StateDot", Position = UDim2.fromOffset(338, 20), Size = UDim2.fromOffset(7, 7),
		BackgroundColor3 = CYAN, BorderSizePixel = 0,
	}, shell)
	corner(self.stateDot, 5)
	self.segments = {}
	for index = 1, 16 do
		local track = create("Frame", {
			Name = "ChargeSegment", Position = UDim2.fromOffset(154 + (index - 1) * 12, 104),
			Size = UDim2.fromOffset(8, 12), BackgroundColor3 = Color3.fromRGB(43, 59, 81), BorderSizePixel = 0,
			ClipsDescendants = true,
		}, shell)
		corner(track, 2)
		local fill = create("Frame", {
			Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = CYAN, BorderSizePixel = 0,
		}, track)
		corner(fill, 2)
		self.segments[index] = fill
	end
	self.phaseCaption = text(shell, "PhaseCaption", UDim2.fromOffset(153, 121), UDim2.fromOffset(195, 17), "TURBO CHARGE", 9, MUTED)
	-- These values come from the race system. Unknown data stays unknown.
	self.racePanel=create("Frame", {
		Name="RaceCounters", AnchorPoint=Vector2.new(0.5,0),
		Position=UDim2.new(0.5,0,0,18), Size=UDim2.fromOffset(420,74),
		BackgroundColor3=INK, BackgroundTransparency=0.12, BorderSizePixel=0,
	},self.gui)
	corner(self.racePanel,14)
	create("UIStroke",{Color=Color3.fromRGB(75,114,147),Transparency=0.5,Thickness=1},self.racePanel)
	self.raceScale=create("UIScale",{Scale=1},self.racePanel)
	for _,x in ipairs({136,272}) do
		create("Frame",{Name="CounterDivider",Position=UDim2.fromOffset(x,15),Size=UDim2.fromOffset(1,43),BackgroundColor3=Color3.fromRGB(84,119,150),BackgroundTransparency=0.6,BorderSizePixel=0},self.racePanel)
	end
	self.raceLabels={}
	for _,counter in ipairs({{"lap",18,"LAP"},{"coins",154,"COINS"},{"wins",290,"WINS"}}) do
		local key,x,caption=table.unpack(counter)
		text(self.racePanel,key.."Caption",UDim2.fromOffset(x,10),UDim2.fromOffset(110,15),caption,10,key=="lap" and MUTED or GOLD)
		self.raceLabels[key]=text(self.racePanel,key.."Value",UDim2.fromOffset(x,28),UDim2.fromOffset(110,35),"—",25,WHITE,Enum.Font.GothamBlack)
	end

	self.lines = {}
	local random = Random.new(17)
	for index = 1, 18 do
		local line = create("Frame", {
			Name = "BoostStreak", BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(180, 225, 255),
			AnchorPoint = Vector2.new(0.5, 0.5), Visible = false,
		}, self.gui)
		self.lines[index] = {frame = line, angle = index * 2 * math.pi / 18, phase = random:NextNumber()}
	end
	return self
end

function HUD:SetVisible(visible)
	self.gui.Enabled = visible
	if visible then self.progress = 0; self.speed = 0 end
end

function HUD:Update(model, actualSpeed, dt, now, viewport, touch, raceSnapshot)
	if viewport ~= self.viewport or touch ~= self.touch then
		self.viewport = viewport
		self.touch = touch
		local scale=math.clamp(math.min(viewport.X/650,viewport.Y/600),0.62,1)
		self.scale.Scale=scale
		self.raceScale.Scale=scale
		if touch and viewport.X>=700 then
			self.shell.AnchorPoint=Vector2.new(1,0)
			self.shell.Position=UDim2.new(1,-16,0,16)
			self.racePanel.AnchorPoint=Vector2.new(0,0)
			self.racePanel.Position=UDim2.new(0,16,0,16)
		elseif touch then
			self.shell.AnchorPoint=Vector2.new(0.5,0)
			self.shell.Position=UDim2.new(0.5,0,0,26+74*scale)
			self.racePanel.AnchorPoint=Vector2.new(0.5,0)
			self.racePanel.Position=UDim2.new(0.5,0,0,14)
		else
			self.shell.AnchorPoint=Vector2.new(1,1)
			self.shell.Position=UDim2.new(1,-28,1,-28)
			self.racePanel.AnchorPoint=Vector2.new(0.5,0)
			self.racePanel.Position=UDim2.new(0.5,0,0,18)
		end
	end
	local mph=actualSpeed*self.config.StudsToMPH
	self.speed += (mph-self.speed)*(1-math.exp(-dt*10))
	self.speedText.Text = string.format("%03d", math.floor(math.max(self.speed, 0) + 0.5))
	local ratio = math.clamp(self.speed / ((self.config.MaxSpeed + self.config.TurboPower)*self.config.StudsToMPH), 0, 1)
	for index, bar in ipairs(self.speedBars) do bar.BackgroundTransparency = ratio >= index / 9 and 0.05 or 0.82 end

	local charge = math.clamp(model:GetAttribute("DriftCharge") or 0, 0, 1)
	local boosting = model:GetAttribute("Boosting") == true
	local boostEnd = model:GetAttribute("BoostEnd") or 0
	local cooldownEnd = model:GetAttribute("TurboCooldownEnd") or 0
	local remaining = math.max(cooldownEnd - now, 0)
	local armed=model:GetAttribute("TurboArmed")==true
	local color,target,status,timer,caption=CYAN,0,"TURBO","","TURBO CHARGE"
	if boosting then
		target=math.clamp((boostEnd-now)/self.config.TurboDuration,0,1)
		status="TURBO ACTIVE"
		timer,caption=string.format("%.1fs",math.max(boostEnd-now,0)),"BOOST REMAINING"
	elseif remaining>0 or model:GetAttribute("DriftReady")~=true then
		status="RECHARGING"
		timer,caption=remaining>0 and string.format("%.1fs",remaining) or "…","TURBO RECOVERY"
	elseif armed then
		target,status,caption=1,"READY","TURBO CHARGED"
	elseif charge>0 then
		target,status=charge,"CHARGING"
		timer=string.format("%.1fs",math.max(self.config.DriftChargeTime*(1-charge),0))
	end
	-- Follow authoritative progress; never predict charge completion or readiness.
	-- Charge and depletion remain continuous across charge/armed/release states.
	self.progress+=(target-self.progress)*(1-math.exp(-dt*18))
	if armed and not boosting then self.progress=1 end
	self.lastState=status
	self.status.Text, self.status.TextColor3 = status, color
	self.timer.Text, self.phaseCaption.Text = timer, caption
	self.edge.BackgroundColor3, self.stateDot.BackgroundColor3 = color, color
	self.outline.Color = color:Lerp(Color3.fromRGB(75, 114, 147), 0.55)
	local pulse=(boosting or armed) and (0.5+0.5*math.sin(now*10)) or 0
	self.outline.Transparency = 0.5 - pulse * 0.3
	for index, fill in ipairs(self.segments) do
		fill.Size = UDim2.fromScale(math.clamp(self.progress * 16 - (index - 1), 0, 1), 1)
		fill.BackgroundColor3 = color
	end
	local snapshot=raceSnapshot or {}
	local function count(value)
		if type(value)~="number" or value~=value or math.abs(value)==math.huge or value<0 then return "—" end
		return string.format("%d",math.floor(value))
	end
	self.raceLabels.lap.Text=count(snapshot.lap).." / "..count(snapshot.totalLaps)
	self.raceLabels.coins.Text=count(snapshot.coins)
	self.raceLabels.wins.Text=count(snapshot.wins)

	for _, line in ipairs(self.lines) do
		line.frame.Visible = boosting and actualSpeed > self.config.MaxSpeed
		if line.frame.Visible then
			line.phase = (line.phase + dt * 1.5) % 1
			local radius = 0.36 + line.phase * 0.25
			line.frame.Position = UDim2.fromScale(0.5 + math.cos(line.angle) * radius, 0.5 + math.sin(line.angle) * radius)
			line.frame.Size = UDim2.fromOffset(18 + line.phase * 65, 2)
			line.frame.Rotation = math.deg(line.angle)
			line.frame.BackgroundTransparency = 0.65 + line.phase * 0.3
		end
	end
end

return HUD
