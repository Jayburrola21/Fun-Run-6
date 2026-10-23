-- Actual KartHUD + Config are injected by the runner. No implementation is copied.
local count=0
local function check(value,message) assert(value,message); count+=1 end
local hud=HUD.new(Instance.new("Folder"),Config)
local attrs={DriftCharge=0,TurboArmed=false,Boosting=false,DriftReady=true,BoostEnd=0,TurboCooldownEnd=0}
local kart={GetAttribute=function(_,key) return attrs[key] end}
local race={lap=2,totalLaps=3,coins=12,wins=5}
local function tick(now,speed) hud:Update(kart,speed or 60,1/60,now,{X=1280,Y=720},false,race) end
check(not hud.gui.Enabled,"HUD hidden before entering")
hud:SetVisible(true); check(hud.gui.Enabled,"HUD visible while driving")
tick(100)
check(hud.status.Text=="TURBO" and hud.timer.Text=="","Idle meter is named TURBO")
check(hud.progress==0,"Uncharged turbo meter starts empty")
check(#hud.segments==16,"Segmented turbo meter exists")
check(#hud.speedBars==9,"Speed bar graph exists")
for _=1,120 do tick(100,60) end
check(hud.speedText.Text==string.format("%03d",math.floor(60*Config.StudsToMPH+0.5)),"Speed converts live studs/second to MPH")
check(math.abs(hud.speed-60*Config.StudsToMPH)<0.00001,"MPH conversion uses actual configured scale")
check(math.abs(Config.StudsToMPH-0.28*2.2369362921)<0.000001,"Default MPH factor follows Roblox 0.28m stud scale")
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
check(hud.status.Text=="READY" and hud.progress>0.99,"Server armed signal fills blue READY meter")
check(not hud.lines[1].frame.Visible,"Holding an armed turbo does not display active boost")
check(hud.status.TextColor3.B>hud.status.TextColor3.R and hud.outline.Transparency<0.5,"Armed state glows blue")
attrs.TurboArmed=false; attrs.Boosting=true; attrs.BoostEnd=100+Config.TurboDuration; tick(100,Config.MaxSpeed+10)
check(hud.status.Text=="TURBO ACTIVE","Released boost state displayed")
check(hud.lines[1].frame.Visible,"High-speed boost streaks visible")
check(hud.status.TextColor3.B>hud.status.TextColor3.R,"Turbo stays blue")
local startProgress=hud.progress
for _=1,60 do tick(100+Config.TurboDuration*0.5,Config.MaxSpeed+10) end
check(hud.progress<startProgress and hud.progress>0.49,"Active boost meter smoothly empties")
attrs.Boosting=false; attrs.DriftCharge=0; attrs.DriftReady=false; attrs.TurboCooldownEnd=100+Config.TurboDuration+Config.TurboCooldown
local recoveryStart=100+Config.TurboDuration
tick(recoveryStart)
check(hud.status.Text=="RECHARGING","Cooldown state displayed")
check(hud.timer.Text==string.format("%.1fs",Config.TurboCooldown),"Cooldown uses server deadline")
check(not hud.lines[1].frame.Visible,"Boost streaks clear after boost")
for _=1,120 do tick(recoveryStart+1) end
check(hud.timer.Text==string.format("%.1fs",Config.TurboCooldown-1),"Cooldown counts down from server time")
check(hud.progress<0.001,"Turbo charge meter resets empty during cooldown")
tick(attrs.TurboCooldownEnd+1)
check(hud.status.Text=="RECHARGING","Expired timer cannot invent server readiness")
attrs.DriftReady=true; tick(attrs.TurboCooldownEnd+1)
check(hud.status.Text=="TURBO" and hud.progress<0.001,"Available turbo remains uncharged after cooldown")
hud:Update(kart,60,1/60,110,{X=844,Y=390},true,race)
check(hud.scale.Scale<1 and hud.scale.Scale>=0.62,"Mobile scales within safe bounds")
check(hud.raceScale.Scale==hud.scale.Scale,"Race and drive panels scale together")
hud:Update(kart,60,1/60,110,{X=390,Y=844},true,race)
check(hud.racePanel.Position~=hud.shell.Position,"Portrait panels occupy separate positions")
hud:Update(kart,60,1/60,110,{X=3440,Y=1440},false,race)
check(hud.scale.Scale==1,"Large displays do not overscale")
for _=1,120 do tick(110,-30) end
check(hud.speedText.Text=="000","Speed readout never displays negative values")
local labels=0
local mphLabels=0
for _,object in ipairs(objects) do
 if object.ClassName=="TextLabel" then
  labels+=1
  local text=object.Text:lower()
  check(not text:find("studs") and not text:find("wasd") and not text:find("space") and not text:find("exit") and not text:find("shift") and not text:find("drift") and not text:find("roblox"),"No control instructions, drift branding or studs in HUD")
  if object.Text=="MPH" then mphLabels+=1 end
 end
end
check(labels>=12 and mphLabels==1,"Race labels and exactly one MPH unit label exist")
hud:SetVisible(false); check(not hud.gui.Enabled,"HUD hides on cleanup")
print(string.format("PASS: %d HUD graph/state assertions; API property-name fixture enforced (no Roblox rendering/engine)",count))
