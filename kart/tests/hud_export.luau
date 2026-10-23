-- Optional graph preview. All participants/counters below are explicitly labeled
-- test fixtures; the product HUD has no sample racers or invented stat defaults.
extra:Destroy(); overflow:Destroy()
path:FindFirstChild("002").Value=Vector3.new(65,0,-35)
state:SetAttribute("StandingsValid",true); state:SetAttribute("CourseValid",true); state:SetAttribute("PathPointCount",4); state:SetAttribute("PathRevision",100);
for _,value in ipairs(path:GetChildren()) do value:SetAttribute("PathRevision",100) end
 state:SetAttribute("RoundId","preview-fixture")
local fixturePositions={{55,0,-35},{65,0,-20},{65,0,15},{30,0,45},{0,0,12},{0,0,-20}}
for index,record in ipairs(records) do
 record:SetAttribute("Active",true); record:SetAttribute("Place",index)
 record:SetAttribute("Position",Vector3.new(table.unpack(fixturePositions[index])))
 record:SetAttribute("Lap",1); record:SetAttribute("TotalLaps",3)
 record:SetAttribute("Coins",index==3 and 12 or index)
 record:SetAttribute("Wins",({32,21,14,9,8,4})[index])
end
local previewPlayers={GetUserThumbnailAsync=function() return "",false end}
hud=HUD.new(playerGui,Config,{player=player,players=previewPlayers,raceState=state})
hud:SetVisible(true)
for _=1,120 do hud:Update({},0,1/60,100,{X=1280,Y=720},false) end
local ids={}; local active={}
for _,object in ipairs(objects) do
 if not object.destroyed then table.insert(active,object); ids[object]=#active end
end
local data={}
for index,object in ipairs(active) do
 local properties={}
 for key,value in pairs(object.values) do
  if key=="Parent" then properties.parent=ids[value]
  else properties[key]=value end
 end
 data[index]=properties
end
local function encode(value)
 local kind=type(value)
 if kind=="string" then return '"'..value:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r')..'"'
 elseif kind=="number" then return tostring(value)
 elseif kind=="boolean" then return value and "true" or "false"
 elseif kind=="table" then
  local result={}
  if #value>0 then for _,item in ipairs(value) do table.insert(result,encode(item)) end; return "["..table.concat(result,",").."]" end
  for key,item in pairs(value) do table.insert(result,encode(key)..":"..encode(item)) end
  table.sort(result); return "{"..table.concat(result,",").."}"
 end
 return "null"
end
print("HUDGRAPH|"..encode({width=1280,height=720,records=data}))
