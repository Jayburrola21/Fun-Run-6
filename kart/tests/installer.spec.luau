local scenarios={"fresh","upgrade","partial","missing","badbackup","wrongtype","playing","incomingserver","incomingclient"}
for _,mode in ipairs(scenarios) do scenario(mode) end
print("PASS: "..#scenarios.." installer scenarios (fresh, custom upgrade, partial repair, rejected input and backup ordering)")
