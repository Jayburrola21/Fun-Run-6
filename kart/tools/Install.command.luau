-- Run in Studio's Command Bar in EDIT mode after selecting the imported KartPackage.
-- Preflight everything before moving anything. Existing installations are preserved.
assert(not game:GetService("RunService"):IsRunning(),"Stop Play mode before installing")
local selected=game:GetService("Selection"):Get()
assert(#selected==1 and selected[1].Name=="KartPackage","Select the imported KartPackage folder")
local package=selected[1]
local storage=game:GetService("ReplicatedStorage")
local server=game:GetService("ServerScriptService")
local starter=game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
assert(not storage:FindFirstChild("KartSystem"),"KartSystem already exists; back it up before replacing")
assert(not server:FindFirstChild("KartServer"),"KartServer already exists")
assert(not starter:FindFirstChild("KartController"),"KartController already exists")
assert(package:FindFirstChild("KartSystem") and package:FindFirstChild("KartServer") and package:FindFirstChild("KartController"),"Incomplete package")
package.KartSystem.Parent=storage
local kartServer=package.KartServer; kartServer.Parent=server; kartServer.Disabled=false
local controller=package.KartController; controller.Parent=starter; controller.Disabled=false
package:Destroy()
print("Kart installed. Configure KartSpawns or KartConfig.SpawnCFrame, select R15 in Avatar Settings, then press Play.")
