-- One native-GUI instrument cluster. This module never makes boost/gameplay decisions.
local HUD={}
HUD.__index=HUD
local BLACK=Color3.fromRGB(5,7,10)
local FACE=Color3.fromRGB(14,18,23)
local CHROME=Color3.fromRGB(149,163,171)
local BLUE=Color3.fromRGB(58,206,255)
local RED=Color3.fromRGB(232,39,48)
local GOLD=Color3.fromRGB(245,185,43)
local WHITE=Color3.fromRGB(246,250,255)
local MUTED=Color3.fromRGB(128,146,159)

local function create(class,props,parent)
 local instance=Instance.new(class)
 for key,value in pairs(props) do instance[key]=value end
 instance.Parent=parent
 return instance
end
local function rounded(parent,radius)
 create("UICorner",{CornerRadius=UDim.new(radius=="circle" and 0.5 or 0,radius=="circle" and 0 or radius)},parent)
end
local function frame(parent,name,x,y,w,h,color,z,rotation,transparency)
 return create("Frame",{Name=name,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=color,BackgroundTransparency=transparency or 0,BorderSizePixel=0,ZIndex=z or 1,Rotation=rotation or 0},parent)
end
local function circle(parent,name,x,y,diameter,color,z)
 local object=frame(parent,name,x-diameter/2,y-diameter/2,diameter,diameter,color,z)
 rounded(object,"circle")
 return object
end
local function text(parent,name,x,y,w,h,value,size,color,z,align)
 return create("TextLabel",{Name=name,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,BorderSizePixel=0,Text=value,TextColor3=color,TextSize=size,Font=Enum.Font.GothamBlack,TextXAlignment=align or Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center,ZIndex=z or 10},parent)
end
local function gradient(parent,top,bottom,rotation)
 parent.BackgroundColor3=WHITE -- UIGradient tints multiply the base color.
 create("UIGradient",{Color=ColorSequence.new(top,bottom),Rotation=rotation or 90},parent)
end
local function stroke(parent,color,width,transparency)
 return create("UIStroke",{Color=color,Thickness=width,Transparency=transparency or 0},parent)
end
local function diamond(parent,name,cx,cy,size,color,z)
 local object=frame(parent,name,cx-size/2,cy-size/2,size,size,color,z,45)
 return object
end
local function plate(parent,name,x,y,width,height,color,z,rotation)
 local group=frame(parent,name,x,y,width,height,BLACK,z,rotation,1)
 local function shape(label,inset,tint,layer)
  local h=height-2*inset
  local half=h/2
  local size=h/math.sqrt(2)
  local left=diamond(group,label.."Left",inset+half,inset+half,size,tint,layer)
  local right=diamond(group,label.."Right",width-inset-half,inset+half,size,tint,layer)
  local middle=frame(group,label.."Middle",inset+half,inset,width-2*inset-h,h,tint,layer)
  return {left,middle,right}
 end
 shape("Bezel",0,BLACK,z)
 local faces=shape("Face",5,color,z+1)
 for _,face in ipairs(faces) do gradient(face,color:Lerp(WHITE,0.32),color:Lerp(BLACK,0.28),90) end
 local glass=shape("DarkGlass",11,Color3.fromRGB(13,19,25),z+2)
 for _,face in ipairs(glass) do gradient(face,Color3.fromRGB(34,43,51),Color3.fromRGB(6,10,15),90) end
 return group,faces
end
local function number(value)
 if type(value)~="number" or value~=value or math.abs(value)==math.huge or value<0 then return "—" end
 return string.format("%d",math.floor(value))
end

function HUD.new(playerGui,config)
 local self=setmetatable({},HUD)
 self.config=config; self.progress=0; self.speed=0; self.viewport=Vector2.zero
 self.gui=create("ScreenGui",{Name="KartHUD",ResetOnSpawn=false,Enabled=false,IgnoreGuiInset=false,DisplayOrder=20,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},playerGui)
 self.shell=frame(self.gui,"RacingInstrumentCluster",0,0,1040,330,BLACK,1,0,1)
 self.shell.AnchorPoint=Vector2.new(0.5,1)
 self.shell.Position=UDim2.new(0.5,0,1,-20)
 self.scale=create("UIScale",{Scale=1},self.shell)
 self.raceScale=self.scale
 -- A single connected black/chrome framework joins gauge, turbo and counters.
 local bridge=frame(self.shell,"ConnectedChassis",270,134,730,172,BLACK,1)
 rounded(bridge,15)
 gradient(bridge,Color3.fromRGB(31,37,43),BLACK,90)
 frame(self.shell,"ChromeRail",290,206,706,6,CHROME,2)
 frame(self.shell,"CarbonRail",289,213,710,15,FACE,2)
 self.racePanel=frame(self.shell,"CounterStrip",327,238,700,88,BLACK,2,0,0.08)
 rounded(self.racePanel,8)

 -- Large circular gauge: black rim, chrome lip, red bezel segments, carbon face.
 local gauge=frame(self.shell,"Speedometer",0,0,330,330,BLACK,3,0,1)
 local outer=circle(gauge,"OuterBlackBezel",165,165,330,BLACK,3)
 stroke(outer,Color3.fromRGB(45,49,55),2,0)
 local chrome=circle(gauge,"ChromeBezel",165,165,317,CHROME,4)
 gradient(chrome,Color3.fromRGB(236,243,247),Color3.fromRGB(37,46,54),105)
 local redRim=circle(gauge,"RedBezel",165,165,308,RED,5)
 gradient(redRim,Color3.fromRGB(255,69,78),Color3.fromRGB(103,10,18),90)
 for index=0,23 do
  local angle=index*math.pi*2/24
  local segment=frame(gauge,"BezelSegment",165+154*math.cos(angle)-7,165+154*math.sin(angle)-3,14,6,index%3==0 and RED or BLACK,6,math.deg(angle)+90)
  rounded(segment,2)
 end
 circle(gauge,"InnerBlackBezel",165,165,291,BLACK,7)
 local face=circle(gauge,"CarbonFace",165,165,276,FACE,8)
 gradient(face,Color3.fromRGB(29,34,40),Color3.fromRGB(6,9,13),100)
 stroke(face,Color3.fromRGB(68,83,95),1,0.25)
 -- Native tile marks stay within the circular face; no external carbon image.
 for x=-112,112,14 do for y=-112,112,14 do
  if x*x+y*y<116*116 then
   frame(gauge,"CarbonWeave",162+x,162+y,6,6,Color3.fromRGB(40,48,54),9,45,0.9)
  end
 end end
 self.speedBars={}
 for index=0,43 do
  local angle=math.rad(135+index/43*270)
  local arc=frame(gauge,"GaugeArc",165+134*math.cos(angle)-8,165+134*math.sin(angle)-7,16,14,index/43>=0.8 and RED or BLUE,10,math.deg(angle)+90,0.7)
  rounded(arc,2)
  table.insert(self.speedBars,arc)
 end
 self.gaugeMax=config.GaugeMaxMPH or 100
 for index=0,40 do
  local angle=math.rad(135+index/40*270)
  local major=index%4==0
  local length=major and 15 or 7
  local radius=major and 119 or 123
  local tick=frame(gauge,"GaugeTick",165+radius*math.cos(angle)-1.5,165+radius*math.sin(angle)-length/2,major and 3 or 2,length,index>=32 and RED or BLUE,11,math.deg(angle)-90)
  rounded(tick,1)
  if major then
   text(gauge,"GaugeNumber",165+100*math.cos(angle)-20,165+100*math.sin(angle)-11,40,22,string.format("%d",math.floor(index/40*self.gaugeMax+0.5)),14,index>=32 and Color3.fromRGB(255,131,133) or Color3.fromRGB(188,213,225),12)
  end
 end
 self.needlePivot=frame(gauge,"RedNeedlePivot",162,162,6,6,RED,13,225,1)
 local needle=frame(self.needlePivot,"RedNeedle",1,-92,4,95,RED,13)
 rounded(needle,2)
 frame(self.needlePivot,"NeedleHighlight",1,-88,1,82,Color3.fromRGB(255,145,148),14)
 frame(self.needlePivot,"NeedleCounterweight",1,3,4,20,Color3.fromRGB(124,16,21),13)
 circle(gauge,"NeedleChromeHub",165,165,25,CHROME,15)
 circle(gauge,"NeedleBlackHub",165,165,19,BLACK,16)
 circle(gauge,"NeedleRedHub",165,165,8,RED,17)
 self.speedText=text(gauge,"LiveMPHDigits",102,199,126,68,"000",59,WHITE,18)
 self.speedText.TextStrokeColor3=BLACK; self.speedText.TextStrokeTransparency=0.35
 self.mphLabel=text(gauge,"MPHCaption",125,261,80,24,"MPH",18,Color3.fromRGB(203,220,232),18)

 -- Horizontal electric-blue turbo cartridges and vector lightning badge.
 local turbo=frame(self.shell,"TurboAssembly",335,113,446,117,BLACK,4,0,1)
 text(turbo,"TurboCaption",64,-12,155,30,"TURBO",27,WHITE,8,Enum.TextXAlignment.Left)
 self.status=text(turbo,"TurboState",228,-7,174,24,"TURBO",16,BLUE,8,Enum.TextXAlignment.Right)
 local chromeHousing=plate(turbo,"TurboChromeHousing",50,23,406,64,CHROME,5)
 local meter,bezelFaces=plate(turbo,"TurboElectricHousing",53,26,400,58,BLUE,6)
 self.meterGlow=stroke(bezelFaces[2],BLUE,1.5,0.6)
 self.segments={}
 for index=1,12 do
  local track=frame(turbo,"TurboCartridge",88+(index-1)*28,39,20,31,Color3.fromRGB(8,29,46),9,12)
  rounded(track,2)
  local fill=frame(track,"TurboBlueFill",0,0,20,31,BLUE,10)
  fill.AnchorPoint=Vector2.new(0,1); fill.Position=UDim2.fromScale(0,1)
  gradient(fill,Color3.fromRGB(177,253,255),Color3.fromRGB(0,119,250),90)
  stroke(fill,Color3.fromRGB(167,242,255),0.9,0.25)
  rounded(fill,2)
  table.insert(self.segments,fill)
 end
 local badge=plate(turbo,"LightningChromeHex",-19,16,88,76,CHROME,11)
 plate(turbo,"LightningElectricHex",-15,20,80,68,BLUE,12)
 frame(turbo,"LightningUpper",17,30,11,25,BLUE,15,22)
 frame(turbo,"LightningBridge",13,49,26,10,BLUE,15,-12)
 frame(turbo,"LightningLower",25,55,11,25,BLUE,15,22)
 self.timer=text(turbo,"TurboTimer",296,104,112,22,"",18,WHITE,8,Enum.TextXAlignment.Right)
 self.phaseCaption=text(turbo,"TurboPhase",66,104,218,20,"TURBO CHARGE",10,MUTED,8,Enum.TextXAlignment.Left)
 self.outline=self.meterGlow
 self.edge=badge

 -- Right red lap plate with a native checkered-flag icon.
 local lap=plate(self.shell,"RedLapPlate",798,113,236,106,RED,5,-4)
 self.lapPlate=lap
 frame(lap,"FlagPole",42,22,4,61,CHROME,8,-10)
 for row=0,3 do for column=0,4 do
  frame(lap,"FlagSquare",45+column*9,21+row*9,9,9,(row+column)%2==0 and WHITE or BLACK,9)
 end end
 text(lap,"LapCaption",108,12,91,23,"LAP",15,WHITE,9)
 self.raceLabels={}
 self.raceLabels.lap=text(lap,"LiveLapCount",91,38,124,46,"— / —",32,WHITE,9)
 self.raceLabels.lap.TextStrokeColor3=BLACK; self.raceLabels.lap.TextStrokeTransparency=0.35

 -- Lower gold coin/trophy plates belong to the same connected cluster.
 local coins=plate(self.shell,"GoldCoinPlate",332,245,320,80,GOLD,5,-2)
 circle(coins,"CoinBlackRim",50,40,48,Color3.fromRGB(62,39,8),8)
 circle(coins,"CoinBrightRim",50,40,41,Color3.fromRGB(255,232,130),9)
 circle(coins,"CoinFace",50,40,33,GOLD,10)
 frame(coins,"CoinStamp",47,28,6,24,Color3.fromRGB(127,74,8),11)
 text(coins,"CoinCaption",91,8,166,18,"COINS",11,GOLD,9,Enum.TextXAlignment.Left)
 self.raceLabels.coins=text(coins,"LiveCoinCount",91,25,166,43,"—",35,WHITE,10,Enum.TextXAlignment.Left)
 self.raceLabels.coins.TextStrokeColor3=Color3.fromRGB(77,45,7); self.raceLabels.coins.TextStrokeTransparency=0.2
 local wins=plate(self.shell,"GoldTrophyPlate",672,245,355,80,GOLD,5,2)
 local trophyColor=GOLD
 local leftHandle=frame(wins,"TrophyLeftHandle",26,20,17,19,trophyColor,9,0,1); rounded(leftHandle,7); stroke(leftHandle,trophyColor,4,0)
 local rightHandle=frame(wins,"TrophyRightHandle",61,20,17,19,trophyColor,9,0,1); rounded(rightHandle,7); stroke(rightHandle,trophyColor,4,0)
 local cup=frame(wins,"TrophyCup",36,17,32,28,trophyColor,10); rounded(cup,8); stroke(cup,Color3.fromRGB(77,45,7),1.5,0); gradient(cup,Color3.fromRGB(255,231,128),GOLD,90)
 frame(wins,"TrophyStem",49,42,6,13,trophyColor,10)
 local base=frame(wins,"TrophyBase",37,54,30,5,trophyColor,10); rounded(base,2)
 text(wins,"WinCaption",96,8,174,18,"WINS",11,GOLD,9,Enum.TextXAlignment.Left)
 self.raceLabels.wins=text(wins,"LiveWinCount",96,25,174,43,"—",35,WHITE,10,Enum.TextXAlignment.Left)
 self.raceLabels.wins.TextStrokeColor3=Color3.fromRGB(77,45,7); self.raceLabels.wins.TextStrokeTransparency=0.2
 -- The reference mark sits inside the bottom of the speedometer bezel.
 local pedestal=frame(gauge,"EmblemChromePedestal",135,285,60,36,BLACK,18)
 rounded(pedestal,8); stroke(pedestal,CHROME,1,0.55)
 local emblem=frame(gauge,"RedSquareEmblem",151,289,28,28,RED,19,15,1)
 for _,side in ipairs({0,1}) do
  frame(emblem,"SquareMark",0,side*20,28,8,RED,19)
  frame(emblem,"SquareMark",side*20,8,8,12,RED,19)
 end
 self.lines={}
 local random=Random.new(17)
 for index=1,18 do
  local line=frame(self.gui,"BlueBoostStreak",0,0,1,2,Color3.fromRGB(170,231,255),0)
  line.AnchorPoint=Vector2.new(0.5,0.5); line.Visible=false
  self.lines[index]={frame=line,angle=index*2*math.pi/18,phase=random:NextNumber()}
 end
 return self
end

function HUD:SetVisible(visible)
 self.gui.Enabled=visible
 if visible then self.progress=0; self.speed=0 end
end

function HUD:Update(model,actualSpeed,dt,now,viewport,touch,raceSnapshot)
 if viewport~=self.viewport or touch~=self.touch then
  self.viewport=viewport; self.touch=touch
  self.scale.Scale=math.max(0.16,math.min(viewport.X*0.9/1040,viewport.Y*0.28/330,1))
  self.shell.AnchorPoint=Vector2.new(0.5,touch and 0 or 1)
  self.shell.Position=touch and UDim2.new(0.5,0,0,12) or UDim2.new(0.5,0,1,-18)
 end
 local mph=math.max(actualSpeed*self.config.StudsToMPH,0)
 self.speed+=(mph-self.speed)*(1-math.exp(-dt*12))
 self.speedText.Text=string.format("%03d",math.floor(self.speed+0.5))
 local ratio=math.clamp(self.speed/self.gaugeMax,0,1)
 self.needlePivot.Rotation=225+ratio*270
 for index,arc in ipairs(self.speedBars) do
  local active=ratio>=(index-1)/(#self.speedBars-1)
  arc.BackgroundTransparency=active and 0.05 or 0.78
 end
 local charge=math.clamp(model:GetAttribute("DriftCharge") or 0,0,1)
 local armed=model:GetAttribute("TurboArmed")==true
 local boosting=model:GetAttribute("Boosting")==true
 local boostEnd=model:GetAttribute("BoostEnd") or 0
 local cooldownEnd=model:GetAttribute("TurboCooldownEnd") or 0
 local remaining=math.max(cooldownEnd-now,0)
 local target,status,timer,caption=0,"READY","","TURBO CHARGE"
 if boosting then
  target=math.clamp((boostEnd-now)/self.config.TurboDuration,0,1)
  status="BOOST"
  timer,caption=string.format("%.1fs",math.max(boostEnd-now,0)),"TURBO ACTIVE"
 elseif remaining>0 or model:GetAttribute("DriftReady")~=true then
  status="COOLDOWN"
  timer,caption=remaining>0 and string.format("%.1fs",remaining) or "…","TURBO RECOVERY"
 elseif armed then
  target,status,caption=1,"READY","TURBO CHARGED"
 elseif charge>0 then
  target,status=charge,"CHARGING"
  timer=string.format("%.1fs",math.max(self.config.DriftChargeTime*(1-charge),0))
 end
 self.progress+=(target-self.progress)*(1-math.exp(-dt*20))
 self.status.Text=status; self.timer.Text=timer; self.phaseCaption.Text=caption
 local pulse=(armed or boosting) and (0.5+0.5*math.sin(now*12)) or 0
 self.meterGlow.Transparency=0.65-pulse*0.5
 self.meterGlow.Thickness=1.5+pulse*1.5
 self.status.TextColor3=(armed or boosting) and WHITE or BLUE
 for index,fill in ipairs(self.segments) do
  local fraction=math.clamp(self.progress*#self.segments-(index-1),0,1)
  fill.Size=UDim2.new(1,0,fraction,0)
  fill.Visible=fraction>0.001
  fill.BackgroundTransparency=(armed or boosting) and 0.05+0.15*(1-pulse) or 0
 end
 local snapshot=raceSnapshot or {}
 self.raceLabels.lap.Text=number(snapshot.lap).." / "..number(snapshot.totalLaps)
 self.raceLabels.coins.Text=number(snapshot.coins)
 self.raceLabels.wins.Text=number(snapshot.wins)
 for _,line in ipairs(self.lines) do
  line.frame.Visible=boosting and actualSpeed>self.config.MaxSpeed
  if line.frame.Visible then
   line.phase=(line.phase+dt*1.5)%1
   local radius=0.36+line.phase*0.25
   line.frame.Position=UDim2.fromScale(0.5+math.cos(line.angle)*radius,0.5+math.sin(line.angle)*radius)
   line.frame.Size=UDim2.fromOffset(18+line.phase*65,2)
   line.frame.Rotation=math.deg(line.angle)
   line.frame.BackgroundTransparency=0.65+line.phase*0.3
  end
 end
end
return HUD
