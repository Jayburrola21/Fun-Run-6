-- Optional source-driven layout export. Values below are labeled preview fixtures,
-- never game defaults: real HUD.Update receives the race bridge's live snapshot.
hud:SetVisible(true)
attrs.DriftCharge=1; attrs.TurboArmed=true; attrs.Boosting=false
attrs.DriftReady=true; attrs.TurboCooldownEnd=0
for _=1,120 do
 hud:Update(kart,Config.MaxSpeed+Config.TurboPower,1/60,100,{X=1920,Y=1080},false,{lap=1,totalLaps=3,coins=56,wins=12})
end
hud.shell.AnchorPoint=Vector2.new(0,0)
hud.shell.Position=UDim2.fromOffset(0,0)
hud.scale.Scale=1
local ids={}
for index,object in ipairs(objects) do ids[object]=index end
local records={}
for index,object in ipairs(objects) do
 local properties={}
 for key,value in pairs(object.values) do
  if key=="Parent" then properties.parent=ids[value]
  else properties[key]=value end
 end
 records[index]=properties
end
local function encode(value)
 local kind=type(value)
 if kind=="string" then
  return '"'..value:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r')..'"'
 elseif kind=="number" then return tostring(value)
 elseif kind=="boolean" then return value and "true" or "false"
 elseif kind=="table" then
  local result={}
  if #value>0 then
   for _,item in ipairs(value) do table.insert(result,encode(item)) end
   return "["..table.concat(result,",").."]"
  end
  for key,item in pairs(value) do table.insert(result,encode(key)..":"..encode(item)) end
  table.sort(result)
  return "{"..table.concat(result,",").."}"
 end
 return "null"
end
print("HUDGRAPH|"..encode(records))
