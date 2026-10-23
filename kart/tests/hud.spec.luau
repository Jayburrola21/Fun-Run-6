-- Actual KartHUD + Config are injected by the runner. No implementation is copied.
local count=0
local function check(value,message) assert(value,message); count+=1 end
local hud=HUD.new(Instance.new("Folder"),Config)
local attrs={DriftCharge=0,TurboArmed=false,Boosting=false,DriftReady=true,BoostEnd=0,TurboCooldownEnd=0}
local kart={GetAttribute=function(_,key) return attrs[key] end}
local race={lap=2,totalLaps=3,coins=12,wins=5}
local function tick(now,speed) hud:Update(kart,speed or 60,1/60,now,{X=1920,Y=1080},false,race) end
check(not hud.gui.Enabled,"HUD hidden before entering")
hud:SetVisible(true); check(hud.gui.Enabled,"HUD visible while driving")
tick(100)
check(hud.status.Text=="READY" and hud.timer.Text=="","Idle authoritative readiness displayed")
check(hud.progress==0,"Uncharged turbo meter starts empty")
check(#hud.segments==12,"Reference-style blue 12-cartridge turbo meter exists")
for _,fill in ipairs(hud.segments) do
 local track=fill.Parent
 local width,height=track.Size.ox,track.Size.oy
 local angle=math.rad(track.Rotation)
 local boundWidth=width*math.abs(math.cos(angle))+height*math.abs(math.sin(angle))
 local boundHeight=height*math.abs(math.cos(angle))+width*math.abs(math.sin(angle))
 local cx,cy=track.Position.ox+width/2,track.Position.oy+height/2
 check(cx-boundWidth/2>=82 and cx+boundWidth/2<=424 and cy-boundHeight/2>=37 and cy+boundHeight/2<=73,"All slanted turbo cells fit the angular glass housing")
end
check(#hud.speedBars==44,"Circular gauge arc exists")
check(hud.shell.Size.ox==1040 and hud.shell.Size.oy==330,"One connected wide instrument cluster")
check(hud.lapPlate.Parent==hud.shell and hud.racePanel.Parent==hud.shell,"Counters and gauge belong to one cluster")
for _=1,120 do tick(100,60) end
check(hud.speedText.Text==string.format("%03d",math.floor(60*Config.StudsToMPH+0.5)),"Speed converts live studs/second to MPH")
check(math.abs(hud.speed-60*Config.StudsToMPH)<0.00001,"MPH conversion uses actual configured scale")
check(math.abs(Config.StudsToMPH-0.28*2.2369362921)<0.000001,"Default MPH factor follows Roblox 0.28m stud scale")
local expectedNeedle=225+math.clamp(60*Config.StudsToMPH/(Config.GaugeMaxMPH or 100),0,1)*270
check(math.abs(hud.needlePivot.Rotation-expectedNeedle)<0.001,"Red needle follows real MPH")
check(hud.raceLabels.lap.Text=="2 / 3","Lap counter uses actual snapshot")
check(hud.raceLabels.coins.Text=="12" and hud.raceLabels.wins.Text=="5","Coin and win counters use actual snapshot")
race={lap=3,totalLaps=3,coins=13,wins=6}; tick(100)
check(hud.raceLabels.lap.Text=="3 / 3" and hud.raceLabels.coins.Text=="13" and hud.raceLabels.wins.Text=="6","Race counters react to live changes")
race={}; tick(100)
check(hud.raceLabels.lap.Text=="— / —" and hud.raceLabels.coins.Text=="—" and hud.raceLabels.wins.Text=="—","Missing race data stays unknown, not fabricated")
race={lap=0/0,totalLaps=math.huge,coins=-1,wins="9"}; tick(100)
check(hud.raceLabels.lap.Text=="— / —" and hud.raceLabels.coins.Text=="—" and hud.raceLabels.wins.Text=="—","Invalid race data is rejected")
race={lap=0,totalLaps=3,coins=0,wins=0}; tick(100)
check(hud.raceLabels.lap.Text=="0 / 3" and hud.raceLabels.coins.Text=="0" and hud.raceLabels.wins.Text=="0","Real zeros remain visible")
attrs.DriftCharge=0.4; tick(100)
check(hud.status.Text=="CHARGING","Turbo charge state displayed")
check(hud.timer.Text==string.format("%.1fs",Config.DriftChargeTime*0.6),"Charge countdown uses actual tuning")
check(hud.progress>0 and hud.progress<0.4,"Charge follows server without predicting completion")
attrs.DriftCharge=1; tick(100)
check(hud.status.Text=="CHARGING","Client cannot invent armed status at full charge")
attrs.TurboArmed=true
for _=1,60 do tick(100) end
check(hud.status.Text=="READY" and hud.progress>0.99,"Release-mode server armed signal fills READY meter")
check(not hud.lines[1].frame.Visible,"Holding an armed turbo does not display active boost")
check(hud.meterGlow.Transparency<0.65,"Armed state glows blue")
attrs.TurboArmed=false; attrs.Boosting=true; attrs.BoostEnd=100+Config.TurboDuration; tick(100,Config.MaxSpeed+10)
check(hud.status.Text=="BOOST","Immediate-mode boost state displayed directly from server")
check(hud.lines[1].frame.Visible,"High-speed boost streaks visible")
local startProgress=hud.progress
for _=1,60 do tick(100+Config.TurboDuration*0.5,Config.MaxSpeed+10) end
check(hud.progress<startProgress and hud.progress>0.49,"Active boost meter smoothly empties")
attrs.Boosting=false; attrs.DriftCharge=0; attrs.DriftReady=false; attrs.TurboCooldownEnd=100+Config.TurboDuration+Config.TurboCooldown
local recoveryStart=100+Config.TurboDuration
tick(recoveryStart)
check(hud.status.Text=="COOLDOWN","Cooldown state displayed")
check(hud.timer.Text==string.format("%.1fs",Config.TurboCooldown),"Cooldown uses server deadline")
check(not hud.lines[1].frame.Visible,"Boost streaks clear after boost")
for _=1,120 do tick(recoveryStart+1) end
check(hud.timer.Text==string.format("%.1fs",Config.TurboCooldown-1),"Cooldown counts down from server time")
check(hud.progress<0.001,"Turbo charge meter resets empty during cooldown")
tick(attrs.TurboCooldownEnd+1)
check(hud.status.Text=="COOLDOWN","Expired timer cannot invent server readiness")
attrs.DriftReady=true; tick(attrs.TurboCooldownEnd+1)
check(hud.status.Text=="READY" and hud.progress<0.001,"Available turbo remains uncharged after cooldown")
hud:Update(kart,60,1/60,110,{X=844,Y=390},true,race)
check(hud.scale.Scale<=844*0.9/1040 and hud.scale.Scale<=390*0.28/330,"Mobile HUD fits width and height")
check(hud.shell.AnchorPoint.Y==0,"Mobile cluster sits above touch controls")
hud:Update(kart,60,1/60,110,{X=390,Y=844},true,race)
check(hud.scale.Scale*1040<=390*0.9+0.01,"Portrait cluster fits safe screen width")
hud:Update(kart,60,1/60,110,{X=3440,Y=1440},false,race)
check(hud.scale.Scale==1 and hud.shell.AnchorPoint.Y==1,"Large desktop displays anchor one full-size bottom cluster")
for _=1,120 do tick(110,Config.GaugeMaxMPH/Config.StudsToMPH*2) end
check(hud.needlePivot.Rotation<=495,"Needle stays within gauge range at high speed")
for _=1,120 do tick(110,-30) end
check(hud.speedText.Text=="000" and hud.needlePivot.Rotation>=225,"Speed and needle never go negative")
local labels=0
local mphLabels=0
for _,object in ipairs(objects) do
 if object.ClassName=="TextLabel" then
  labels+=1
  local value=object.Text:lower()
  check(not value:find("studs") and not value:find("wasd") and not value:find("space") and not value:find("exit") and not value:find("shift") and not value:find("drift"),"No control instructions, drift bar or studs in HUD")
  if object.Text=="MPH" then mphLabels+=1 end
 end
end
check(labels>=19 and mphLabels==1,"Gauge, race labels and exactly one MPH unit label exist")
hud:SetVisible(false); check(not hud.gui.Enabled,"HUD hides on cleanup")
print(string.format("PASS: %d HUD graph/state assertions; API property-name fixture enforced (no Roblox rendering/engine)",count))
