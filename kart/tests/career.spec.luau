local assertions=0
local function check(condition,message) assert(condition,message); assertions+=1 end
local p=player()
local f=fixture()
local career=Career.new({},f.deps)
check(#f.callbacks==1,"shutdown hook registered")
career:Track(p)
check(career:Get(p)==nil and #f.queue==1,"unloaded value stays unknown; load asynchronous")
f.drain()
check(career:Get(p)==0 and f.store.gets==1,"confirmed missing datastore record is a real zero")
check(career:Award(p,"round-1") and career:Get(p)==1,"actual earned win is pending over confirmed value")
check(not career:Award(p,"round-1"),"same award cannot repeat in session")
f.drain()
check(f.store.values.u_101.wins==1 and career:Get(p)==1,"award persisted")
check(f.store.values.u_101.sessions["session-A"]==1,"durable session watermark persisted")
career:Update(0.1)
check(#f.queue==0,"clean records do not issue repeated writes")

f=fixture({u_101=5})
career=Career.new({},f.deps); career:Track(p); f.drain()
check(career:Get(p)==5,"legacy numeric wins load")
career:Award(p,"round-new"); f.drain()
check(f.store.values.u_101.wins==6 and career:Get(p)==6,"legacy value migrates without reset")

f=fixture({u_101={wins="invalid",sessions={}}})
career=Career.new({},f.deps); career:Track(p); f.drain()
check(career:Get(p)==nil,"malformed record never becomes fake zero")
career:Award(p,"must-not-destroy")
f.advance(1); career:Update(1); f.drain()
check(f.store.values.u_101.wins=="invalid","invalid stored data is not overwritten")
check(career.records["101"].nextSeq>career.records["101"].savedSeq,"invalid record retains unsaved award")

f=fixture(); f.store.getFailures=1
career=Career.new({},f.deps); career:Track(p); f.drain()
check(career:Get(p)==nil and #f.warnings>0,"load access failure remains unknown and reported")
for _=1,10 do career:Update(0.1) end
check(f.store.gets==1,"retry honors backoff")
f.advance(1); career:Update(1); f.drain()
check(career:Get(p)==0,"successful retry establishes real zero")

f=fixture({u_101=7})
career=Career.new({},f.deps); career:Track(p)
career:Award(p,"queued-before-load")
check(career:Get(p)==nil,"pending award cannot invent missing base total")
f.drain(); career:Update(0.1); f.drain()
check(career:Get(p)==8 and f.store.values.u_101.wins==8,"award before completed load is retained")

f=fixture({u_101=10})
career=Career.new({},f.deps); career:Track(p); f.drain()
f.store.ambiguous=1
career:Award(p,"ambiguous-round"); f.drain()
check(f.store.values.u_101.wins==11 and career:Get(p)==11,"lost response retains actual pending win over known base")
check(career.records["101"].savedSeq==0,"ambiguous response not falsely confirmed")
f.advance(1); career:Update(1); f.drain()
check(f.store.values.u_101.wins==11 and career:Get(p)==11,"retry cannot double a committed award")
check(career.records["101"].savedSeq==1,"successful retry confirms watermark")

f=fixture({u_101={wins=20,sessions={},season="keep"}})
local f2=fixture()
f2.deps.store=f.store
local a=Career.new({},f.deps)
local b=Career.new({},f2.deps)
b.session="session-B"
a:Track(p); b:Track(p); f.drain(); f2.drain()
a:Award(p,"A1"); f.drain()
b:Award(p,"B1"); f2.drain()
a:Award(p,"A2"); f.drain()
check(f.store.values.u_101.wins==23,"concurrent server awards merge without lost update")
check(f.store.values.u_101.sessions["session-A"]==2 and f.store.values.u_101.sessions["session-B"]==1,"independent session watermarks preserved")
check(f.store.values.u_101.season=="keep","unrelated persisted fields preserved")

f=fixture({u_101=3})
career=Career.new({},f.deps); career:Track(p); f.drain()
f.store.saveFailures=1
career:Award(p,"leaving-round"); f.drain()
career:Remove(p); f.drain()
-- Remove forces an immediate retry; if it succeeds the player can be pruned.
check(f.store.values.u_101.wins==4,"departure flush persists pending award")
check(career.records["101"]==nil,"clean removed player record released")
career:Track(p); career:Award(p,"rejoined-round"); f.drain(); career:Update(0.1); f.drain()
check(f.store.values.u_101.wins==5,"same-session reconnect before load does not lose new award")
check(not career:Award(p,"leaving-round"),"reconnect retains round award dedupe")

f=fixture({u_101=3})
career=Career.new({},f.deps); career:Track(p); f.drain()
f.store.saveFailures=3
career:Award(p,"retry-after-disconnect"); f.drain()
career:Remove(p); f.drain()
check(career.records["101"]~=nil,"failed departure retains dirty record")
f.advance(2); career:Update(2); f.drain()
check(career.records["101"]~=nil,"repeated failure retains pending award")
f.advance(4); career:Update(4); f.drain()
check(f.store.values.u_101.wins==4 and career.records["101"]==nil,"detached dirty record retries and prunes after success")

f=fixture()
career=Career.new({},f.deps); career:Track(p)
career:Award(p,"shutdown-round")
f.callbacks[1]()
check(f.store.values.u_101.wins==1,"shutdown waits for load and pending save")
check(career.records["101"].nextSeq==career.records["101"].savedSeq,"shutdown confirms all successful writes")
check(not career:Award(p,"too-late"),"shutdown stops new awards")

f=fixture(); f.store.getFailures=100; f.store.saveFailures=100
career=Career.new({CareerWinsCloseTimeout=0.5},f.deps); career:Track(p); career:Award(p,"blocked-round")
career:Close()
check(career:Get(p)==nil,"shutdown access failure does not fabricate total")
check(career.records["101"].nextSeq>career.records["101"].savedSeq,"deadline retains unconfirmed pending delta")
check(#f.warnings>0 and string.find(f.warnings[#f.warnings],"not confirmed"),"shutdown reports pending durability limit")

f=fixture()
career=Career.new({CareerWinsEnabled=false},f.deps); career:Track(p)
check(career:Get(p)==nil and not career:Award(p,"disabled"),"disabled storage never fabricates wins")
check(#f.queue==0 and #f.callbacks==0,"disabled storage makes no requests or shutdown hook")

f=fixture(); f.deps.store=nil
local attempts=0
f.deps.storeFactory=function() attempts+=1; if attempts<3 then error("store access") end; return f.store end
career=Career.new({},f.deps); career:Track(p)
career:Update(0.1)
check(attempts==1 and career:Get(p)==nil,"store construction failure throttled")
f.advance(1); career:Update(1)
f.advance(2); career:Update(2); f.drain()
check(attempts==3 and career:Get(p)==0,"store construction recovers without false zero")

f=fixture(); f.store.transformTwice=true
career=Career.new({},f.deps); career:Track(p); f.drain()
career:Award(p,"callback-retry"); f.drain()
check(f.store.values.u_101.wins==1,"UpdateAsync callback re-execution remains side-effect-free")

f=fixture()
career=Career.new({},f.deps); career:Track(p); f.drain()
career:Award(p,"inflight-1"); career:Award(p,"inflight-2"); f.drain()
check(career:Get(p)==2 and f.store.values.u_101.wins==1,"new award during in-flight save remains dirty")
career:Update(0.1); f.drain()
check(f.store.values.u_101.wins==2 and career:Get(p)==2,"next write confirms new in-flight award")
print("PASS: "..assertions.." persistent career-win assertions (DataStore/task doubles; Studio access unrun)")
