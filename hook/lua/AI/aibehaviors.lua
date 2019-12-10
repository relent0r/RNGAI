
RNGCommanderBehavior = CommanderBehavior
function CommanderBehavior(platoon)
    local aiBrain = platoon:GetBrain()
    per = ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality
    for _, v in platoon:GetPlatoonUnits() do
        if not v.Dead and not v.CommanderThread then
            if per == 'RNGStandard' or per == 'RNGStandardCheat' then
                LOG('Correct ai brain name')
                v.CommanderThread = v:ForkThread(CommanderThreadRNG, platoon)
            else
                LOG('Incorrect ai brain name')
                v.CommanderThread = v:ForkThread(CommanderThread, platoon)
            end
        end
    end
end

function CommanderThreadRNG(cdr, platoon)
    LOG('Starting CommanderThreadRNG')
    local aiBrain = cdr:GetAIBrain()
    aiBrain:BuildScoutLocationsRNG()
    -- Added to ensure we know the start locations (thanks to Sorian).
    SetCDRHome(cdr, platoon)

    while not cdr.Dead do
        -- Overcharge
        if not cdr.Dead then CDROverCharge(aiBrain, cdr) end
        WaitTicks(1)

        -- Go back to base
        if not cdr.Dead then CDRReturnHome(aiBrain, cdr) end
        WaitTicks(1)

        -- Call platoon resume building deal...
        if not cdr.Dead and cdr:IsIdleState() and not cdr.GoingHome and not cdr:IsUnitState("Moving")
        and not cdr:IsUnitState("Building") and not cdr:IsUnitState("Guarding")
        and not cdr:IsUnitState("Attacking") and not cdr:IsUnitState("Repairing")
        and not cdr:IsUnitState("Upgrading") and not cdr:IsUnitState("Enhancing") then
            -- if we have nothing to build...
            if not cdr.EngineerBuildQueue or table.getn(cdr.EngineerBuildQueue) == 0 then
                -- check if the we have still a platton assigned to the CDR
                if cdr.PlatoonHandle then
                    local platoonUnits = cdr.PlatoonHandle:GetPlatoonUnits() or 1
                    -- only disband the platton if we have 1 unit, plan and buildername. (NEVER disband the armypool platoon!!!)
                    if table.getn(platoonUnits) == 1 and cdr.PlatoonHandle.PlanName and cdr.PlatoonHandle.BuilderName then
                        --SPEW('ACU PlatoonHandle found. Plan: '..cdr.PlatoonHandle.PlanName..' - Builder '..cdr.PlatoonHandle.BuilderName..'. Disbanding CDR platoon!')
                        cdr.PlatoonHandle:PlatoonDisband()
                    end
                end
                -- get the global armypool platoon
                local pool = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
                -- assing the CDR to the armypool
                aiBrain:AssignUnitsToPlatoon(pool, {cdr}, 'Unassigned', 'None')
            -- if we have a BuildQueue then continue building
            elseif cdr.EngineerBuildQueue and table.getn(cdr.EngineerBuildQueue) ~= 0 then
                if not cdr.NotBuildingThread then
                    cdr.NotBuildingThread = cdr:ForkThread(platoon.WatchForNotBuilding)
                end
            end
        end
        WaitTicks(1)
    end
end