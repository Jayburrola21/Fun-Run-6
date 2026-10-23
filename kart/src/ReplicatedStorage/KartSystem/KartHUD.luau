-- Reference racing HUD: coins/laps, six real racers, placement and actual-course map.
-- It reads published race data only; driving and boost logic are intentionally absent.
local HUD={}
HUD.__index=HUD
local activeHUDs=setmetatable({},{__mode="k"})
local BLACK=Color3.fromRGB(5,7,10)
local GLASS=Color3.fromRGB(18,21,25)
local WHITE=Color3.fromRGB(247,249,252)
local GOLD=Color3.fromRGB(255,205,65)
local ORANGE=Color3.fromRGB(255,130,27)
local SILVER=Color3.fromRGB(194,205,215)
local BLUE=Color3.fromRGB(86,201,255)
local MARKERS={WHITE,Color3.fromRGB(102,213,255),Color3.fromRGB(244,107,110),Color3.fromRGB(153,236,150),Color3.fromRGB(199,151,255),Color3.fromRGB(255,163,99)}
local function create(class,properties,parent)
 local instance=Instance.new(class)
 for key,value in pairs(properties) do instance[key]=value end
 instance.Parent=parent
 return instance
end
local function frame(parent,name,x,y,w,h,color,z,rotation,transparency)
 return create("Frame",{Name=name,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=color,BackgroundTransparency=transparency or 0,BorderSizePixel=0,ZIndex=z or 1,Rotation=rotation or 0},parent)
end
local function rounded(parent,radius)
 create("UICorner",{CornerRadius=UDim.new(radius=="circle" and 0.5 or 0,radius=="circle" and 0 or radius)},parent)
end
local function circle(parent,name,x,y,diameter,color,z)
 local object=frame(parent,name,x-diameter/2,y-diameter/2,diameter,diameter,color,z)
 rounded(object,"circle"); return object
end
local function stroke(parent,color,width,transparency)
 return create("UIStroke",{Color=color,Thickness=width,Transparency=transparency or 0},parent)
end
local function gradient(parent,top,bottom,rotation)
 if parent:IsA("TextLabel") then parent.TextColor3=WHITE else parent.BackgroundColor3=WHITE end
 return create("UIGradient",{Color=ColorSequence.new(top,bottom),Rotation=rotation or 90},parent)
end
local function text(parent,name,x,y,w,h,value,size,color,z,align)
 return create("TextLabel",{Name=name,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,BorderSizePixel=0,Text=value,TextColor3=color,TextSize=size,Font=Enum.Font.GothamBlack,TextXAlignment=align or Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center,ZIndex=z or 10},parent)
end
local function finite(value) return type(value)=="number" and value==value and math.abs(value)<math.huge end
local function count(value)
 if not finite(value) or value<0 then return "—" end
 return string.format("%d",math.floor(value))
end
local function rank(value)
 return finite(value) and value%1==0 and value>=1 and value<=6 and value or nil
end
local function point(value)
 return typeof(value)=="Vector3" and finite(value.X) and finite(value.Y) and finite(value.Z)
end
local function choose(...)
 for index=1,select("#",...) do local value=select(index,...); if value~=nil then return value end end
 return nil
end
local function trophy(parent,x,y,color,z)
 local left=frame(parent,"TrophyLeftHandle",x,y+2,8,10,color,z,0,1); rounded(left,4); stroke(left,color,2,0)
 local right=frame(parent,"TrophyRightHandle",x+17,y+2,8,10,color,z,0,1); rounded(right,4); stroke(right,color,2,0)
 local cup=frame(parent,"TrophyCup",x+5,y,15,13,color,z+1); rounded(cup,4)
 frame(parent,"TrophyStem",x+11,y+11,3,8,color,z+1)
 local base=frame(parent,"TrophyFoot",x+6,y+18,13,3,color,z+1); rounded(base,1)
end
local function placeholder(parent)
 local root=frame(parent,"PendingHeadshot",0,0,38,38,Color3.fromRGB(44,49,56),7)
 rounded(root,8)
 circle(root,"PendingAvatarHead",19,13,13,Color3.fromRGB(113,123,133),8)
 local shoulders=frame(root,"PendingAvatarShoulders",7,23,24,14,Color3.fromRGB(113,123,133),8); rounded(shoulders,9)
 return root
end
local function panel(parent,name,x,width)
 local shell=frame(parent,name,x,0,width,58,BLACK,2,-3,0.1)
 rounded(shell,5); stroke(shell,BLACK,2,0)
 gradient(shell,Color3.fromRGB(37,39,42),Color3.fromRGB(7,9,12),100)
 frame(shell,"TopHighlight",8,3,width-16,1,SILVER,3,0,0.7)
 return shell
end

function HUD.new(playerGui,config,context)
 local existing=activeHUDs[playerGui]
 if existing then existing:Destroy() end
 local self=setmetatable({},HUD)
 self.playerGui=playerGui; activeHUDs[playerGui]=self
 self.config=config; self.context=context or {}; self.destroyed=false; self.token=1
 self.playerId=self.context.player and self.context.player.UserId or nil
 self.pollTimer=1; self.rows={}; self.markers={}; self.rowsById={}; self.thumbnails={}; self.racers={}
 self.pathObjects={}; self.viewport=Vector2.zero; self.mapValid=false; self.pathVersion=nil
 local previous=playerGui:FindFirstChild("KartHUD")
 if previous then previous:Destroy() end -- remove old dial/turbo and avoid respawn/reload duplicates
 self.gui=create("ScreenGui",{Name="KartHUD",ResetOnSpawn=false,Enabled=false,IgnoreGuiInset=false,DisplayOrder=20,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},playerGui)
 self.shell=frame(self.gui,"RaceHUDCanvas",0,0,1,1,BLACK,1,0,1)
 self.shell.Size=UDim2.fromScale(1,1)
 self.topLeft=frame(self.shell,"CoinsAndLaps",28,24,330,62,BLACK,2,0,1)
 self.topScale=create("UIScale",{Scale=1},self.topLeft)
 local coins=panel(self.topLeft,"CoinPanel",0,154)
 circle(coins,"CoinShadow",29,29,33,Color3.fromRGB(100,59,5),4)
 local coin=circle(coins,"GoldCoin",29,27,28,GOLD,5); stroke(coin,Color3.fromRGB(255,237,146),2,0)
 frame(coins,"CoinStamp",27,18,4,17,Color3.fromRGB(157,91,9),6)
 self.coinText=text(coins,"LiveCoins",54,5,88,46,"—",35,WHITE,6)
 self.coinText.TextStrokeColor3=BLACK; self.coinText.TextStrokeTransparency=0.2
 local lap=panel(self.topLeft,"LapPanel",167,155)
 frame(lap,"FlagPole",15,17,3,29,SILVER,5,-10)
 for row=0,3 do for column=0,4 do
  frame(lap,"CheckeredFlag",18+column*4.8,13+row*4.8,4.8,4.8,(row+column)%2==0 and WHITE or BLACK,6)
 end end
 self.lapText=text(lap,"LiveLap",47,6,100,43,"—/—",31,WHITE,6)
 self.lapText.TextStrokeColor3=BLACK; self.lapText.TextStrokeTransparency=0.2

 self.leaderboard=frame(self.shell,"SixRacerLeaderboard",0,22,238,290,BLACK,3,0,1)
 self.leaderboard.AnchorPoint=Vector2.new(1,0); self.leaderboard.Position=UDim2.new(1,-26,0,22)
 self.boardScale=create("UIScale",{Scale=1},self.leaderboard)
 for index=1,6 do
  local group=frame(self.leaderboard,"RacerSlot"..index,0,(index-1)*48,238,43,GLASS,4,0,0.16)
  rounded(group,11)
  local outline=stroke(group,BLACK,2,0)
  local glass=gradient(group,Color3.fromRGB(37,41,45),Color3.fromRGB(7,10,14),90)
  local position=text(group,"LivePlace",8,1,33,40,"—",25,WHITE,6)
  local head=create("ImageLabel",{Name="RealAvatarHeadshot",Position=UDim2.fromOffset(48,3),Size=UDim2.fromOffset(38,38),BackgroundColor3=Color3.fromRGB(34,38,44),BorderSizePixel=0,Image="",ScaleType=Enum.ScaleType.Crop,ZIndex=7},group)
  rounded(head,8); stroke(head,BLACK,1,0)
  local pending=placeholder(head)
  local localDot=circle(group,"LocalRacerDot",102,21,6,GOLD,7); localDot.Visible=false
  trophy(group,126,11,GOLD,7)
  local wins=text(group,"RealCareerWins",161,3,65,37,"—",27,WHITE,7,Enum.TextXAlignment.Right)
  group.Visible=false
  self.rows[index]={frame=group,rank=position,head=head,pending=pending,wins=wins,outline=outline,glass=glass,dot=localDot,y=(index-1)*48,targetY=(index-1)*48,userId=nil,slot=index}
 end

 self.placement=frame(self.shell,"LargeRacePlacement",32,0,228,155,BLACK,3,-6,1)
 self.placement.AnchorPoint=Vector2.new(0,1); self.placement.Position=UDim2.new(0,32,1,-28)
 self.placeScale=create("UIScale",{Scale=1},self.placement)
 self.placeNumberLayers={}; self.placeSuffixLayers={}
 for _,offset in ipairs({{-4,-3},{4,-3},{-4,3},{4,3},{0,-4},{0,4},{-4,0},{4,0}}) do
  table.insert(self.placeNumberLayers,text(self.placement,"NumberBlackOutline",offset[1],offset[2],128,146,"—",135,BLACK,4))
  table.insert(self.placeSuffixLayers,text(self.placement,"SuffixBlackOutline",116+offset[1]*0.6,73+offset[2]*0.6,98,62,"",47,BLACK,4))
 end
 local extrusion=text(self.placement,"NumberExtrusion",3,7,128,146,"—",135,Color3.fromRGB(137,65,5),5)
 table.insert(self.placeNumberLayers,extrusion)
 self.placeNumber=text(self.placement,"LivePlacementNumber",0,0,128,146,"—",135,WHITE,6)
 self.placeNumber.TextStrokeColor3=BLACK; self.placeNumber.TextStrokeTransparency=0
 self.placeGradient=gradient(self.placeNumber,Color3.fromRGB(255,220,92),ORANGE,90)
 self.placeSuffix=text(self.placement,"LivePlacementSuffix",116,73,98,62,"",47,WHITE,6)
 self.placeSuffix.TextStrokeColor3=BLACK; self.placeSuffix.TextStrokeTransparency=0
 gradient(self.placeSuffix,WHITE,Color3.fromRGB(154,167,180),90)

 self.mapRoot=frame(self.shell,"ActualCourseMinimap",0,0,236,184,BLACK,3,0,1)
 self.mapRoot.AnchorPoint=Vector2.new(1,1); self.mapRoot.Position=UDim2.new(1,-32,1,-32)
 self.mapScale=create("UIScale",{Scale=1},self.mapRoot)
 self.mapPlot=frame(self.mapRoot,"WorldXZCourse",0,0,236,184,BLACK,4,0,1)
 self.finishMarker=frame(self.mapPlot,"RealFinishLine",0,0,20,10,WHITE,8,0,1)
 self.finishMarker.AnchorPoint=Vector2.new(0.5,0.5)
 for row=0,1 do for column=0,3 do
  frame(self.finishMarker,"FinishCheck",column*5,row*5,5,5,(row+column)%2==0 and WHITE or BLACK,8)
 end end
 for index=1,6 do
  local dot=circle(self.mapPlot,"RealRacerMarker"..index,0,0,13,MARKERS[index],10)
  dot.AnchorPoint=Vector2.new(0.5,0.5)
  local outline=stroke(dot,BLACK,2.2,0)
  local label=text(dot,"ActualMarkerPlace",0,0,13,13,"",8,BLACK,12)
  dot.Visible=false
  self.markers[index]={frame=dot,label=label,outline=outline,x=nil,y=nil,targetX=0,targetY=0,valid=false}
 end
 self.mapRoot.Visible=false
 return self
end

function HUD:SetVisible(visible)
 if self.destroyed then return end
 self.gui.Enabled=visible
 if visible then self.pollTimer=1 end
end

function HUD:_thumbnail(userId)
 if self.thumbnails[userId] or not self.context.players then return end
 -- Studio test racers use synthetic non-positive IDs, not public avatar IDs.
 if userId<=0 then self.thumbnails[userId]={url=nil,attempts=0}; return end
 local cache={url=nil,attempts=0}; self.thumbnails[userId]=cache
 local token=self.token
 local function load()
  if self.destroyed or self.token~=token then return end
  cache.attempts+=1
  local ok,url,ready=pcall(function()
   return self.context.players:GetUserThumbnailAsync(userId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size100x100)
  end)
  if self.destroyed or self.token~=token then return end
  if ok and ready==true and type(url)=="string" and url~="" then
   cache.url=url
   local row=self.rowsById[userId]
   if row and row.userId==userId then row.head.Image=url; row.pending.Visible=false end
  elseif cache.attempts<3 then task.delay(2,load) end
 end
 task.spawn(load)
end

function HUD:_map(state)
 local path=state and state:FindFirstChild("Path")
 local expected=state and state:GetAttribute("PathPointCount")
 local revision=state and state:GetAttribute("PathRevision")
 local version=state and tostring(state:GetAttribute("RoundId"))..":"..tostring(revision)..":"..tostring(expected)..":"..tostring(state:GetAttribute("CourseValid")) or "none"
 if self.mapValid and version==self.pathVersion and path==self.pathObject then return end
 -- Replicated attributes can arrive before children (or before an old path is
 -- replaced). A pending/partial revision must stay retryable, never cached.
 self.pathVersion=nil; self.pathObject=nil
 for _,object in ipairs(self.pathObjects) do object:Destroy() end
 self.pathObjects={}; self.mapValid=false; self.mapRoot.Visible=false
 if not state or state:GetAttribute("CourseValid")~=true or not path then return end
 if not finite(expected) or expected%1~=0 or expected<2 or not finite(revision) then return end
 local children=path:GetChildren()
 if #children~=expected then return end
 table.sort(children,function(a,b)
  local ai,bi=tonumber(a.Name),tonumber(b.Name)
  if ai and bi then return ai<bi end
  return a.Name<b.Name
 end)
 local points={}; local minX,maxX,minZ,maxZ=math.huge,-math.huge,math.huge,-math.huge
 for index,value in ipairs(children) do
  if not value:IsA("Vector3Value") or tonumber(value.Name)~=index or not point(value.Value) or value:GetAttribute("PathRevision")~=revision then return end
  local p=value.Value; table.insert(points,p)
  minX=math.min(minX,p.X); maxX=math.max(maxX,p.X); minZ=math.min(minZ,p.Z); maxZ=math.max(maxZ,p.Z)
 end
 if #points<2 or math.max(maxX-minX,maxZ-minZ)<0.001 then return end
 local scale=math.min(204/math.max(maxX-minX,0.001),152/math.max(maxZ-minZ,0.001))
 self.projection={minX=minX,minZ=minZ,scale=scale,offsetX=(236-(maxX-minX)*scale)/2,offsetY=(184-(maxZ-minZ)*scale)/2}
 local projected={}
 for _,p in ipairs(points) do local x,y=self:_project(p); table.insert(projected,{x=x,y=y}) end
 local function keep(object) table.insert(self.pathObjects,object); return object end
 for index,a in ipairs(projected) do
  local b=projected[index%#projected+1]
  local dx,dy=b.x-a.x,b.y-a.y; local length=math.sqrt(dx*dx+dy*dy)
  if length>0.001 then
   local rotation=math.deg(math.atan2(dy,dx))
   local outer=keep(frame(self.mapPlot,"ActualRouteOutline",(a.x+b.x)/2,(a.y+b.y)/2,length+2,16,BLACK,5,rotation))
   outer.AnchorPoint=Vector2.new(0.5,0.5)
   local inner=keep(frame(self.mapPlot,"ActualRoute",(a.x+b.x)/2,(a.y+b.y)/2,length+2,9,Color3.fromRGB(203,207,211),6,rotation))
   inner.AnchorPoint=Vector2.new(0.5,0.5)
  end
  keep(circle(self.mapPlot,"RouteJointBlack",a.x,a.y,16,BLACK,5))
  keep(circle(self.mapPlot,"RouteJointGray",a.x,a.y,9,Color3.fromRGB(203,207,211),6))
 end
 local first,second=projected[1],projected[2]
 self.finishMarker.Position=UDim2.fromOffset(first.x,first.y)
 self.finishMarker.Rotation=math.deg(math.atan2(second.y-first.y,second.x-first.x))+90
 self.pathVersion=version; self.pathObject=path
 self.mapValid=true; self.mapRoot.Visible=true
end

function HUD:_project(position)
 local p=self.projection
 return math.clamp((position.X-p.minX)*p.scale+p.offsetX,8,228),math.clamp((position.Z-p.minZ)*p.scale+p.offsetY,8,176)
end

function HUD:_poll()
 local state=self.context.raceState
 if self.context.getRaceState then state=self.context.getRaceState() end
 self:_map(state)
 self.standingsValid=not state or state:GetAttribute("StandingsValid")~=false
 local folder=state and state:FindFirstChild("Racers")
 local racers={}
 if folder then
  for _,record in ipairs(folder:GetChildren()) do
   local id=record:GetAttribute("UserId")
   if record:IsA("Folder") and record:GetAttribute("Active")==true and finite(id) and id%1==0 then
    table.insert(racers,{id=id,place=self.standingsValid and rank(record:GetAttribute("Place")) or nil,position=record:GetAttribute("Position"),lap=record:GetAttribute("Lap"),totalLaps=record:GetAttribute("TotalLaps"),coins=record:GetAttribute("Coins"),wins=record:GetAttribute("Wins")})
   end
  end
 end
 table.sort(racers,function(a,b) if a.place~=b.place then return (a.place or 99)<(b.place or 99) end; return a.id<b.id end)
 local present={}; self.localRace=nil
 for index,record in ipairs(racers) do
  if index>6 then break end
  present[record.id]=true
  if record.id==self.playerId then self.localRace=record end
 end
 for id,row in pairs(self.rowsById) do
  if not present[id] then row.userId=nil; row.frame.Visible=false; self.rowsById[id]=nil end
 end
 self.racers={}
 for _,marker in ipairs(self.markers) do marker.valid=false end
 for index,record in ipairs(racers) do
  if index>6 then break end
  table.insert(self.racers,record)
  local row=self.rowsById[record.id]
  if not row then
   for _,candidate in ipairs(self.rows) do if not candidate.userId then row=candidate; break end end
   row.userId=record.id; row.y=(index-1)*48; self.rowsById[record.id]=row
  end
  local localPlayer=record.id==self.playerId
  row.targetY=(index-1)*48; row.frame.Visible=true
  row.rank.Text=count(record.place); row.rank.TextColor3=record.place==1 and GOLD or WHITE
  row.wins.Text=count(record.wins); row.dot.Visible=localPlayer
  row.outline.Color=localPlayer and GOLD or BLACK; row.outline.Thickness=localPlayer and 2.5 or 2
  row.glass.Color=localPlayer and ColorSequence.new(Color3.fromRGB(83,65,25),Color3.fromRGB(24,21,17)) or ColorSequence.new(Color3.fromRGB(37,41,45),Color3.fromRGB(7,10,14))
  self:_thumbnail(record.id)
  local cached=self.thumbnails[record.id]
  row.head.Image=cached and cached.url or ""; row.pending.Visible=not (cached and cached.url)
  local marker=self.markers[row.slot]
  marker.frame.Visible=self.mapValid and point(record.position)
  marker.valid=marker.frame.Visible
  marker.frame.BackgroundColor3=localPlayer and GOLD or MARKERS[index]
  marker.frame.ZIndex=localPlayer and 14 or 10
  marker.frame.Size=UDim2.fromOffset(localPlayer and 17 or 13,localPlayer and 17 or 13)
  marker.label.Size=UDim2.fromScale(1,1); marker.label.Text=count(record.place)
  marker.label.ZIndex=localPlayer and 16 or 12
  if marker.valid then
   marker.targetX,marker.targetY=self:_project(record.position)
   if marker.userId~=record.id then marker.x,marker.y=marker.targetX,marker.targetY end
  end
  marker.userId=record.id
 end
 for _,marker in ipairs(self.markers) do if not marker.valid then marker.frame.Visible=false end end
end

function HUD:_placement(place)
 if place==self.lastPlace then return end
 self.lastPlace=place
 local digit=place and tostring(place) or "—"
 local suffix=place and ({"ST","ND","RD","TH","TH","TH"})[place] or ""
 for _,label in ipairs(self.placeNumberLayers) do label.Text=digit end
 for _,label in ipairs(self.placeSuffixLayers) do label.Text=suffix end
 self.placeNumber.Text=digit; self.placeSuffix.Text=suffix
 self.placeGradient.Color=place==2 and ColorSequence.new(WHITE,SILVER) or ColorSequence.new(Color3.fromRGB(255,220,92),ORANGE)
end

function HUD:Update(_model,_actualSpeed,dt,_now,viewport,touch,snapshot)
 if self.destroyed then return end
 if viewport~=self.viewport or touch~=self.touch then
  self.viewport=viewport; self.touch=touch
  local scale=touch and math.clamp(math.min(viewport.X/620,viewport.Y/700),0.45,0.72) or math.clamp(math.min(viewport.X/1280,viewport.Y/720),0.6,1.2)
  for _,object in ipairs({self.topScale,self.boardScale,self.placeScale,self.mapScale}) do object.Scale=scale end
  self.topLeft.Position=UDim2.fromOffset(touch and 14 or 28,touch and 16 or 24)
  self.leaderboard.Position=UDim2.new(1,touch and -14 or -26,0,touch and 16 or 22)
  self.placement.Position=UDim2.new(0,touch and 18 or 32,1,touch and -208 or -28)
  self.mapRoot.Position=UDim2.new(1,touch and -18 or -32,1,touch and -208 or -32)
 end
 self.pollTimer+=dt
 if self.pollTimer>=0.1 then self.pollTimer=0; self:_poll() end
 local data=snapshot or {}; local own=self.localRace or {}; local player=self.context.player
 local function attribute(name) return player and player:GetAttribute(name) or nil end
 self.coinText.Text=count(choose(data.coins,own.coins,attribute("KartCoins")))
 self.lapText.Text=count(choose(data.lap,own.lap,attribute("KartLap"))).."/"..count(choose(data.totalLaps,own.totalLaps,attribute("KartTotalLaps")))
 local place=rank(choose(data.place,own.place,attribute("KartPlace")))
 if not self.standingsValid then place=nil end
 self:_placement(place)
 local blend=1-math.exp(-dt*12)
 for _,row in ipairs(self.rows) do
  if row.userId then row.y+=(row.targetY-row.y)*blend; row.frame.Position=UDim2.fromOffset(0,row.y) end
 end
 for _,marker in ipairs(self.markers) do
  if marker.valid then
   marker.x+=(marker.targetX-marker.x)*blend; marker.y+=(marker.targetY-marker.y)*blend
   marker.frame.Position=UDim2.fromOffset(marker.x,marker.y)
  end
 end
end

function HUD:Destroy()
 if self.destroyed then return end
 self.destroyed=true; self.token+=1
 if activeHUDs[self.playerGui]==self then activeHUDs[self.playerGui]=nil end
 self.rowsById={}; self.thumbnails={}; self.gui:Destroy()
end
return HUD
