local vector, cf = {}, {}
local function vec(x, y, z)
    return setmetatable({X=x, Y=y, Z=z}, vector)
end
function vector.__index(v, name)
    if name=="Magnitude" then
        return math.sqrt(v:Dot(v))
    elseif name=="Unit" then
        return v/v.Magnitude
    end
    return vector[name]
end
function vector.__add(a,b) return vec(a.X+b.X,a.Y+b.Y, a.Z and a.Z+b.Z) end
function vector.__sub(a,b) return vec(a.X-b.X,a.Y-b.Y, a.Z and a.Z-b.Z) end
function vector.__unm(a) return vec(-a.X,-a.Y,a.Z and -a.Z) end
function vector.__mul(a,b)
    if type(a)=="number" then a,b=b,a end
    return vec(a.X*b,a.Y*b,a.Z and a.Z*b)
end
function vector.__div(a,b) return a*(1/b) end
function vector:Dot(b) return self.X*b.X+self.Y*b.Y+(self.Z and self.Z*b.Z or 0) end
function vector:Cross(b) return vec(self.Y*b.Z-self.Z*b.Y,self.Z*b.X-self.X*b.Z,self.X*b.Y-self.Y*b.X) end
function vector:Lerp(b,t) return self+(b-self)*t end
local Vector2 = {new=vec, zero=vec(0,0)}
local Vector3 = {new=vec, yAxis=vec(0,1,0)}
local function frame(p,x,y,z) return setmetatable({p=p,x=x,y=y,z=z},cf) end
cf.__index=cf
function cf.new(x,y,z) return frame(vec(x,y,z),vec(1,0,0),vec(0,1,0),vec(0,0,1)) end
cf.identity=cf.new(0,0,0)
cf.fromMatrix=frame
function cf.vector(a,v) return a.x*v.X+a.y*v.Y+a.z*v.Z end
function cf.__mul(a,b)
    return frame(a.p+a:vector(b.p),a:vector(b.x),a:vector(b.y),a:vector(b.z))
end
function cf.__add(a,b) return frame(a.p+b,a.x,a.y,a.z) end
function cf.relative(a,p)
    local v=p-a.p
    return vec(v:Dot(a.x),v:Dot(a.y),v:Dot(a.z))
end
local CFrame=cf
local Color3={fromRGB=vec}
local Enum={Material={Neon="neon",Basalt="basalt"},PartType={Cylinder="cylinder"},BulkMoveMode={FireCFrameChanged=1}}
local Workspace={}
function Workspace:BulkMoveTo(parts,frames,mode)
    assert(#parts==#frames and mode==1)
    for i,p in ipairs(parts) do p.CFrame=frames[i] end
end
local game={GetService=function(_self,name) assert(name=="Workspace"); return Workspace end}
local objects={}
local Instance={}
function Instance.new(kind)
    local obj={ClassName=kind, Destroy=function(self) self.destroyed=true end}
    table.insert(objects,obj)
    return obj
end
local Random={}
function Random.new(seed)
    return {NextNumber=function(_self,a,b)
        seed=(seed*16807)%2147483647
        return (a or 0)+((b or 1)-(a or 0))*seed/2147483647
    end}
end
local Surface = (function()
-- MODULE_SURFACE
end)()
local tilted = frame(vec(-10,7,12),vec(0,0,1),vec(.6,.8,0),vec(-.8,.6,0))
local sizes = {
    vec(48, 3, 32), vec(11, 1, 11), vec(330, 1, 35), vec(3.5,1,153.5),
    vec(17,1,127),vec(79,1,87),vec(4,1,4), vec(.1,1,.1),
}
local maxCount=0
local maxOutside=0
for _,size in sizes do
    for _,quality in {.25,.85,1} do
        for _,angle in {0,16,73,90,157,210} do
            table.clear(objects)
            local source={Size=size,CFrame=tilted,Position=tilted.p}
            local direction=vec(math.cos(math.rad(angle)),math.sin(math.rad(angle)))
            local root={}
            local surface=Surface.new(source,root,{
                LavaFlowSpeed=2.35, GlowIntensity=.9, LavaBrightness=.97,
                AnimationQuality=quality, FlowDirection=direction,
            })
            local count=#objects-1
            assert(surface.TextureCarrier.Name=="Molten bed")
            assert(count <= 124, count)
            maxCount=math.max(maxCount,count)
            local top=tilted*cf.new(0,size.Y*.5,0)
            for step=1,18 do
                local time=step*.58
                surface:Update(time,step%2)
                assert(#objects-1==count)
                assert(source.CFrame==tilted and source.Size==size)
                for _,p in objects do
                    if p.ClassName=="Folder" then continue end
                    assert(p.CFrame and p.Size and p.Material)
                    assert(p.Anchored and p.CanTouch==false and p.CanCollide==false and p.CanQuery==false)
                    local frame,size = p.CFrame,p.Size
                    for x=-1,1,2 do
                        for y=-1,1,2 do
                            for z=-1,1,2 do
                                if p.ClassName=="WedgePart" and y==1 and z==-1 then continue end
                                local corner=frame.p+frame:vector(vec(x*size.X*.5,y*size.Y*.5,z*size.Z*.5))
                                local q=top:relative(corner)
                                local outside=math.max(math.abs(q.X)-source.Size.X*.5,math.abs(q.Z)-source.Size.Z*.5)
                                maxOutside=math.max(maxOutside,outside)
                                assert(outside < .012, string.format("%s escaped source by %f (%f,%f,%f)",p.Name,outside,angle,source.Size.X,source.Size.Z))
                            end
                        end
                    end
                end
            end
            surface:Destroy()
            assert(surface.folder.destroyed)
        end
    end
end
print(string.format("Validated %d configurations, no update allocations, maximum %d visual parts, max edge overshoot %.6f.",#sizes*3*6,maxCount,maxOutside))
