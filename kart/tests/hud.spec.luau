-- Actual KartHUD + Config are injected by the runner. No implementation is copied.
local count=0
local function check(value,message) assert(value,message); count+=1 end
local hud=HUD.new(Instance.new("Folder"),Config)
local attrs={DriftCharge=0,Boosting=false,DriftReady=true,BoostEnd=0,TurboCooldownEnd=0}
local kart={GetAttribute=function(_,key) return attrs[key] end}
local function tick(now,speed) hud:Update(kart,speed or 60,1/60,now,{X=1280,Y=720},false) end
check(not hud.gui.Enabled,"HUD hidden before entering")
hud:SetVisible(true); check(hud.gui.Enabled,"HUD visible while driving")
tick(100)
check(hud.status.Text=="READY" and hud.timer.Text=="","Server ready state displayed")
check(#hud.segments==16,"Segmented charge meter exists")
check(#hud.speedBars==9,"Speed bar graph exists")
attrs.DriftCharge=0.4; tick(100)
check(hud.status.Text=="CHARGING","Charging state displayed")
check(hud.timer.Text=="0.9s","Charge countdown uses real tuning")
check(hud.progress>0 and hud.progress<0.4,"Charge follows server without predicting completion")
attrs.Boosting=true; attrs.BoostEnd=100+Config.TurboDuration; tick(100,Config.MaxSpeed+10)
check(hud.status.Text=="TURBO","Boost state displayed")
check(hud.lines[1].frame.Visible,"High-speed boost streaks visible")
attrs.Boosting=false; attrs.DriftReady=false; attrs.TurboCooldownEnd=100+Config.TurboDuration+Config.TurboCooldown
local recoveryStart=100+Config.TurboDuration
tick(recoveryStart)
check(hud.status.Text=="RECHARGING","Cooldown state displayed")
check(hud.timer.Text==string.format("%.1fs",Config.TurboCooldown),"Cooldown uses server deadline")
check(not hud.lines[1].frame.Visible,"Boost streaks clear after boost")
tick(recoveryStart+1)
check(hud.timer.Text==string.format("%.1fs",Config.TurboCooldown-1),"Cooldown counts down smoothly from server time")
tick(attrs.TurboCooldownEnd+1)
check(hud.status.Text=="RECHARGING","Expired timer cannot invent readiness")
attrs.DriftReady=true; attrs.DriftCharge=0; tick(attrs.TurboCooldownEnd+1)
check(hud.status.Text=="READY","Ready follows server acknowledgement")
hud:Update(kart,60,1/60,110,{X=844,Y=390},true)
check(hud.scale.Scale<1 and hud.scale.Scale>=0.62,"Mobile scales within safe bounds")
hud:Update(kart,60,1/60,110,{X=3440,Y=1440},false)
check(hud.scale.Scale==1,"Large displays do not overscale")
for _=1,120 do tick(110,-30) end
check(hud.speedText.Text=="000","Speed readout never displays negative values")
local labels=0
for _,object in ipairs(objects) do
 if object.ClassName=="TextLabel" then
  labels+=1
  local text=object.Text:lower()
  check(not text:find("studs") and not text:find("wasd") and not text:find("space") and not text:find("exit") and not text:find("shift"),"No control instructions or speed units in HUD")
 end
end
check(labels>=6,"HUD labels were instantiated")
hud:SetVisible(false); check(not hud.gui.Enabled,"HUD hides on cleanup")
print(string.format("PASS: %d HUD graph/state assertions; API property-name fixture enforced (no Roblox rendering/engine)",count))
