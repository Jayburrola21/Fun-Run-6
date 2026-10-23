-- Actual KartHUD + Config source is injected; these are service/graph tests only.
local count=0
local function check(value,message) assert(value,message); count+=1 end
local function folder(name,parent)
 local instance=Instance.new("Folder"); instance.Name=name; instance.Parent=parent; return instance
end
local playerGui=folder("PlayerGui")
local state=folder("RaceState")
state:SetAttribute("StandingsValid",true); state:SetAttribute("CourseValid",true); state:SetAttribute("PathPointCount",4); state:SetAttribute("PathRevision",1); state:SetAttribute("RoundId","round-a"); state:SetAttribute("TotalLaps",3)
local path=folder("Path",state)
-- Included demo checkpoint coordinates: this is actual course data, not a decorative circuit.
for index,p in ipairs({{0,0,-35},{65,0,-35},{65,0,45},{0,0,45}}) do
 local value=Instance.new("Vector3Value"); value.Name=string.format("%03d",index); value.Value=Vector3.new(table.unpack(p)); value:SetAttribute("PathRevision",1); value.Parent=path
end
local raceFolders=folder("Racers",state)
local records={}
for index=1,6 do
 local record=folder(tostring(100+index),raceFolders); records[index]=record
 for key,value in pairs({UserId=100+index,Place=index,Position=Vector3.new(4+index*8,0,-35),Lap=index==3 and 1 or 2,TotalLaps=3,Coins=index*2,Wins=20-index*2,Active=true}) do record:SetAttribute(key,value) end
end
local player={UserId=103,GetAttribute=function() return nil end}
local thumbnailCalls={}
local players={GetUserThumbnailAsync=function(_,userId,kind,size)
 table.insert(thumbnailCalls,{userId=userId,kind=kind,size=size})
 return "rbxthumb://type=AvatarHeadShot&id="..userId.."&w=100&h=100",true
end}
local context={player=player,players=players,raceState=state}
local hud=HUD.new(playerGui,Config,context)
local function tick(dt,snapshot,touch,viewport)
 hud:Update({},0,dt or 0.11,100,viewport or {X=1280,Y=720},touch or false,snapshot)
end
check(not hud.gui.Enabled,"HUD hidden before entry")
hud:SetVisible(true); tick()
check(hud.gui.Enabled,"HUD visible while driving")
check(#hud.rows==6 and #hud.markers==6,"Six prebuilt race rows and six map markers")
check(hud.coinText.Text=="6" and hud.lapText.Text=="1/3","Top-left counts use actual local race record")
check(hud.placeNumber.Text=="3" and hud.placeSuffix.Text=="RD","Prominent orange placement uses actual third place")
check(#hud.racers==6,"All six actual admitted racers displayed")
check(hud.rowsById[103].outline.Color.R>0.9 and hud.rowsById[103].dot.Visible,"Local row is highlighted gold")
check(hud.rowsById[101].rank.Text=="1","First place comes from published race rank")
check(hud.rowsById[103].wins.Text=="14","Career wins come from published career stat")
check(hud.mapValid and hud.mapRoot.Visible,"Actual valid course map displayed")
check(#hud.pathObjects==16,"Four actual path edges and joints built once")
local aX,aY=hud:_project(Vector3.new(0,0,-35)); local bX,bY=hud:_project(Vector3.new(65,0,45))
check(aX<bX and aY<bY,"World X/Z path bounds determine projection")
check(math.abs((bX-aX)/(bY-aY)-65/80)<0.0001,"Map preserves actual track aspect ratio")
local marker=hud.markers[hud.rowsById[103].slot]
check(marker.valid and marker.frame.BackgroundColor3.R>0.9 and marker.frame.Size.ox==17,"Actual local marker is larger gold")
local created=#objects
for _=1,120 do tick(1/60) end
check(#objects==created,"No per-frame row, icon or map rebuild")
flushTasks()
check(#thumbnailCalls==6,"Each real user headshot requested once")
for _,call in ipairs(thumbnailCalls) do check(call.userId>=101 and call.userId<=106 and call.kind=="HeadShot","Headshots requested for actual racer IDs") end
check(hud.rowsById[103].head.Image:find("id=103")~=nil and not hud.rowsById[103].pending.Visible,"Actual thumbnail applied to matching local racer")
for _=1,60 do tick(1/60) end
flushTasks(); check(#thumbnailCalls==6,"Cached headshots do not repeat every poll")
records[3]:SetAttribute("Wins",nil); tick()
check(hud.rowsById[103].wins.Text=="—","Unknown persistent career wins are not fabricated")
records[3]:SetAttribute("Place",1); records[1]:SetAttribute("Place",3)
tick(1/60); tick(0.1)
check(hud.placeNumber.Text=="1" and hud.placeSuffix.Text=="ST","Placement updates from changed actual rank")
local moving=hud.rowsById[103]
check(moving.targetY==0 and moving.y>0 and moving.y<96,"Leaderboard row movement is interpolated")
for _=1,120 do tick(1/60) end
check(moving.y<0.001,"Reordered leaderboard row reaches correct slot")
local oldX=marker.x
records[3]:SetAttribute("Position",Vector3.new(55,0,40)); tick(0.1)
check(marker.x>oldX and marker.x<marker.targetX,"Minimap marker interpolates actual racer movement")
check(hud.markers[hud.rowsById[103].slot]==marker,"Marker identity survives leaderboard reorder")
records[6]:SetAttribute("Active",false); tick()
check(#hud.racers==5 and hud.rowsById[106]==nil,"Departed/inactive racer row is removed, not replaced with fake player")
local visible=0; for _,row in ipairs(hud.rows) do if row.frame.Visible then visible+=1 end end
check(visible==5,"Only real active race rows visible")
local extra=folder("999",raceFolders); extra:SetAttribute("UserId",999); extra:SetAttribute("Active",true); extra:SetAttribute("Place",6)
local overflow=folder("1000",raceFolders); overflow:SetAttribute("UserId",1000); overflow:SetAttribute("Active",true); overflow:SetAttribute("Place",6)
tick(); check(#hud.racers==6,"Overflow does not create more than six rows")
state:SetAttribute("CourseValid",false); tick()
check(not hud.mapRoot.Visible and not hud.mapValid,"Unknown/invalid course hides minimap instead of unrelated circuit")
check(#hud.pathObjects==0,"Old route is cleared on invalidation")
state:SetAttribute("CourseValid",true); state:SetAttribute("PathRevision",2)
for _,value in ipairs(path:GetChildren()) do value:SetAttribute("PathRevision",2) end
path:FindFirstChild("002").Value=Vector3.new(130,0,-35); tick()
check(hud.mapValid and hud.projection.minX==0 and math.abs(hud.projection.scale-204/130)<0.0001,"Map rebuilds from revised actual path bounds")
local stable=#objects; tick(); check(#objects==stable,"Unchanged map revision reuses route geometry")
state:SetAttribute("RoundId","round-b"); tick(); check(#objects>stable,"New round refreshes route cache")
-- Replication can deliver revision/count attributes before points. The same
-- revision must recover after zero -> partial -> complete children arrive.
for _,value in ipairs(path:GetChildren()) do value:Destroy() end
state:SetAttribute("PathRevision",3); state:SetAttribute("PathPointCount",nil)
tick(); check(not hud.mapValid and hud.pathVersion==nil,"Missing replicated point count cannot commit a map cache")
state:SetAttribute("PathPointCount",4)
tick(); check(not hud.mapValid and hud.pathVersion==nil,"Revision before zero children stays retryable")
local incoming={}
local pointData={{0,0,-35},{65,0,-35},{65,0,45},{0,0,45}}
for index=1,2 do
 local value=Instance.new("Vector3Value"); value.Name=string.format("%03d",index); value.Value=Vector3.new(table.unpack(pointData[index])); value:SetAttribute("PathRevision",3); value.Parent=path; incoming[index]=value
end
tick(); check(not hud.mapValid and #hud.pathObjects==0 and hud.pathVersion==nil,"Partial children cannot become a cached unrelated closed circuit")
for index=3,4 do
 local value=Instance.new("Vector3Value"); value.Name=string.format("%03d",index); value.Value=Vector3.new(table.unpack(pointData[index])); value:SetAttribute("PathRevision",3); value.Parent=path; incoming[index]=value
end
incoming[4].Value=Vector3.new(0/0,0,45)
tick(); check(not hud.mapValid and hud.pathVersion==nil,"Full count with invalid point data is not committed")
incoming[4].Value=Vector3.new(table.unpack(pointData[4]))
tick(); check(hud.mapValid and hud.pathVersion~=nil and #hud.pathObjects==16,"Complete valid data recovers under the same published revision")
local built=#objects; tick(); check(#objects==built,"Complete point set is cached after successful build")
state:SetAttribute("PathRevision",4)
tick(); check(not hud.mapValid and hud.pathVersion==nil,"Stale same-count old points cannot masquerade as a new revision")
for _,value in ipairs(incoming) do value:SetAttribute("PathRevision",4) end
tick(); check(hud.mapValid and hud.pathVersion~=nil,"Matching child revisions restore map without another folder version bump")
incoming[4].Name="003"; state:SetAttribute("PathRevision",5)
for _,value in ipairs(incoming) do value:SetAttribute("PathRevision",5) end
tick(); check(not hud.mapValid,"Duplicate or incomplete ordered point names are rejected")
incoming[4].Name="004"
tick(); check(hud.mapValid,"Corrected ordered point names recover at the same revision")
tick(0.1,{lap=2,totalLaps=4,coins=99,place=2})
check(hud.coinText.Text=="99" and hud.lapText.Text=="2/4" and hud.placeSuffix.Text=="ND","Canonical live snapshot overrides cached rows")
tick(0.1,{lap=0/0,totalLaps=math.huge,coins=-1,place=9})
check(hud.coinText.Text=="—" and hud.lapText.Text=="—/—" and hud.placeNumber.Text=="—","Invalid values do not invent stats or places")
tick(0.1,nil,true,{X=844,Y=390})
check(hud.mapRoot.Position.oy==-208 and hud.placement.Position.oy==-208,"Mobile lower elements lift above touch controls")
check(hud.mapScale.Scale<1 and hud.boardScale.Scale<1,"Mobile elements scale down")
tick(0.1,nil,false,{X=1920,Y=1080})
check(hud.mapRoot.AnchorPoint.X==1 and hud.mapRoot.AnchorPoint.Y==1,"Desktop minimap stays fixed bottom-right")
check(hud.placement.AnchorPoint.X==0 and hud.placement.AnchorPoint.Y==1,"Desktop placement stays bottom-left")
for _,object in ipairs(objects) do
 if not object.destroyed and (object.ClassName=="TextLabel" or object.ClassName=="Frame") then
  local name=(object.Name or ""):lower(); local value=(object.Text or ""):lower()
  check(not name:find("speedometer") and not name:find("turbo") and value~="mph","Old speedometer/MPH/turbo GUI is absent")
 end
end
state:SetAttribute("StandingsValid",false); tick(0.1,{place=2})
check(hud.placeNumber.Text=="—","Explicit invalid standings override stale snapshot placement")
check(hud.rowsById[103].rank.Text=="—" and hud.mapValid,"Unranked racers retain the real course/map without invented places")
state:SetAttribute("StandingsValid",true); tick()
check(hud.placeNumber.Text=="1","Standings recovery returns actual placement")
local studioState=folder("StudioRaceState"); studioState:SetAttribute("CourseValid",false)
local studioRacers=folder("Racers",studioState); local studioRecord=folder("-1",studioRacers)
for key,value in pairs({UserId=-1,Place=1,Active=true}) do studioRecord:SetAttribute(key,value) end
local studioCalls=0
local studioPlayers={GetUserThumbnailAsync=function() studioCalls+=1; error("Synthetic Studio ID must not call public avatar service") end}
local studioGui=folder("StudioPlayerGui")
local studioHUD=HUD.new(studioGui,Config,{player={UserId=-1,GetAttribute=function() return nil end},players=studioPlayers,raceState=studioState})
studioHUD:SetVisible(true); studioHUD:Update({},0,0.1,100,{X=1280,Y=720},false)
check(#studioHUD.racers==1 and studioHUD.rowsById[-1]~=nil,"Negative Studio test ID is a real admitted participant")
check(studioHUD.rowsById[-1].dot.Visible and studioHUD.placeNumber.Text=="1","Synthetic Studio local player receives real place and local highlight")
flushTasks(); check(studioCalls==0,"Non-positive Studio IDs never hit public thumbnail service")
studioHUD:Destroy()
hud:SetVisible(false); check(not hud.gui.Enabled,"HUD hides on lifecycle cleanup")
local priorGui=hud.gui
hud=HUD.new(playerGui,Config,context)
check(priorGui.destroyed and #playerGui:GetChildren()==1,"Recreation destroys old ScreenGui and prevents respawn duplicates")
hud:SetVisible(true); tick(); hud:Destroy(); local callsBefore=#thumbnailCalls; flushTasks()
check(hud.destroyed and hud.gui.destroyed,"Destroy removes entire HUD")
check(#thumbnailCalls==callsBefore,"Delayed headshot work is cancelled after destroy")
-- Failure retries are bounded; no repeated service calls from per-frame polling.
local failures=0
local badPlayers={GetUserThumbnailAsync=function() failures+=1; error("temporary thumbnail outage") end}
hud=HUD.new(playerGui,Config,{player=player,players=badPlayers,raceState=state})
hud:SetVisible(true); tick(); flushTasks()
check(failures==#hud.racers*3,"Thumbnail service failures retry at most three times per real user")
local failureCount=failures
for _=1,60 do tick(1/60) end
flushTasks(); check(failures==failureCount,"Failed thumbnail cache does not spam service forever")
hud:Destroy()
print(string.format("PASS: %d racing HUD graph/state assertions; actual race data, map and async lifecycle (not Roblox rendering)",count))
