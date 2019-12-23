--local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetMOARadii()


RNGCommanderBehavior = CommanderBehavior
function CommanderBehavior(platoon)
    local aiBrain = platoon:GetBrain()
    per = ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality
    for _, v in platoon:GetPlatoonUnits() do
        if not v.Dead and not v.CommanderThread then
            if per == 'RNGStandard' or per == 'RNGStandardcheat' then
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
        if not cdr.Dead then CDROverChargeRNG(aiBrain, cdr) end
        WaitTicks(1)

        -- Go back to base
        if not cdr.Dead then CDRReturnHomeRNG(aiBrain, cdr) end
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

function CDROverChargeRNG(aiBrain, cdr)
    local weapBPs = cdr:GetBlueprint().Weapon
    local weapon

    for k, v in weapBPs do
        if v.Label == 'OverCharge' then
            weapon = v
            break
        end
    end

    cdr.UnitBeingBuiltBehavior = false

    -- Added for ACUs starting near each other
    if GetGameTimeSeconds() < 60 then
        return
    end

    -- Increase distress on non-water maps
    local distressRange = 60
    if cdr:GetHealthPercent() > 0.8 and aiBrain:GetMapWaterRatio() < 0.4 then
        distressRange = 100
    end

    -- Increase attack range for a few mins on small maps
    local maxRadius = weapon.MaxRadius + 10
    local mapSizeX, mapSizeZ = GetMapSize()
    if cdr:GetHealthPercent() > 0.8
        and GetGameTimeSeconds() < 660
        and GetGameTimeSeconds() > 243
        and mapSizeX <= 512 and mapSizeZ <= 512
        and ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality ~= 'turtle'
        and ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality ~= 'defense'
        and ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality ~= 'rushnaval'
        then
        maxRadius = 160
    end

    -- Take away engineers too
    local cdrPos = cdr.CDRHome
    local numUnits = aiBrain:GetNumUnitsAroundPoint(categories.LAND - categories.SCOUT, cdrPos, (maxRadius), 'Enemy')
    local distressLoc = aiBrain:BaseMonitorDistressLocation(cdrPos)
    local overCharging = false

    -- Don't move if upgrading
    if cdr:IsUnitState("Upgrading") or cdr:IsUnitState("Enhancing") then
        return
    end

    if Utilities.XZDistanceTwoVectors(cdrPos, cdr:GetPosition()) > maxRadius then
        return
    end

    if numUnits > 0 or (not cdr.DistressCall and distressLoc and Utilities.XZDistanceTwoVectors(distressLoc, cdrPos) < distressRange) then
        if cdr.UnitBeingBuilt then
            cdr.UnitBeingBuiltBehavior = cdr.UnitBeingBuilt
        end
        local plat = aiBrain:MakePlatoon('', '')
        aiBrain:AssignUnitsToPlatoon(plat, {cdr}, 'support', 'None')
        plat:Stop()
        local priList = {
            categories.EXPERIMENTAL,
            categories.TECH3 * categories.INDIRECTFIRE,
            categories.TECH3 * categories.MOBILE,
            categories.TECH2 * categories.INDIRECTFIRE,
            categories.MOBILE * categories.TECH2,
            categories.TECH1 * categories.INDIRECTFIRE,
            categories.TECH1 * categories.MOBILE,
            categories.ALLUNITS
        }

        local target
        local continueFighting = true
        local counter = 0
        local cdrThreat = cdr:GetBlueprint().Defense.SurfaceThreatLevel or 75
        local enemyThreat
        repeat
            overCharging = false
            if counter >= 5 or not target or target.Dead or Utilities.XZDistanceTwoVectors(cdrPos, target:GetPosition()) > maxRadius then
                counter = 0
                searchRadius = 30
                repeat
                    searchRadius = searchRadius + 30
                    for k, v in priList do
                        target = plat:FindClosestUnit('Support', 'Enemy', true, v)
                        if target and Utilities.XZDistanceTwoVectors(cdrPos, target:GetPosition()) <= searchRadius then
                            local cdrLayer = cdr:GetCurrentLayer()
                            local targetLayer = target:GetCurrentLayer()
                            if not (cdrLayer == 'Land' and (targetLayer == 'Air' or targetLayer == 'Sub' or targetLayer == 'Seabed')) and
                               not (cdrLayer == 'Seabed' and (targetLayer == 'Air' or targetLayer == 'Water')) then
                                break
                            end
                        end
                        target = false
                    end
                until target or searchRadius >= maxRadius

                if target then
                    local targetPos = target:GetPosition()

                    -- If inside base dont check threat, just shoot!
                    if Utilities.XZDistanceTwoVectors(cdr.CDRHome, cdr:GetPosition()) > 45 then
                        enemyThreat = aiBrain:GetThreatAtPosition(targetPos, 1, true, 'AntiSurface')
                        enemyCdrThreat = aiBrain:GetThreatAtPosition(targetPos, 1, true, 'Commander')
                        friendlyThreat = aiBrain:GetThreatAtPosition(targetPos, 1, true, 'AntiSurface', aiBrain:GetArmyIndex())
                        if enemyThreat - enemyCdrThreat >= friendlyThreat + (cdrThreat / 1.5) then
                            break
                        end
                    end

                    if aiBrain:GetEconomyStored('ENERGY') >= weapon.EnergyRequired and target and not target.Dead then
                        overCharging = true
                        IssueClearCommands({cdr})
                        IssueOverCharge({cdr}, target)
                    elseif target and not target.Dead then -- Commander attacks even if not enough energy for overcharge
                        IssueClearCommands({cdr})
                        IssueMove({cdr}, targetPos)
                        IssueMove({cdr}, cdr.CDRHome)
                    end
                elseif distressLoc then
                    enemyThreat = aiBrain:GetThreatAtPosition(distressLoc, 1, true, 'AntiSurface')
                    enemyCdrThreat = aiBrain:GetThreatAtPosition(distressLoc, 1, true, 'Commander')
                    friendlyThreat = aiBrain:GetThreatAtPosition(distressLoc, 1, true, 'AntiSurface', aiBrain:GetArmyIndex())
                    if enemyThreat - enemyCdrThreat >= friendlyThreat + (cdrThreat / 3) then
                        break
                    end
                    if distressLoc and (Utilities.XZDistanceTwoVectors(distressLoc, cdrPos) < distressRange) then
                        IssueClearCommands({cdr})
                        IssueMove({cdr}, distressLoc)
                        IssueMove({cdr}, cdr.CDRHome)
                    end
                end
            end

            if overCharging then
                while target and not target.Dead and not cdr.Dead and counter <= 5 do
                    WaitTicks(5)
                    counter = counter + 0.5
                end
            else
                WaitTicks(50)
                counter = counter + 5
            end

            distressLoc = aiBrain:BaseMonitorDistressLocation(cdrPos)
            if cdr.Dead then
                return
            end

            if aiBrain:GetNumUnitsAroundPoint(categories.LAND - categories.SCOUT, cdrPos, maxRadius, 'Enemy') <= 0
                and (not distressLoc or Utilities.XZDistanceTwoVectors(distressLoc, cdrPos) > distressRange) then
                continueFighting = false
            end
            -- If com is down to yellow then dont keep fighting
            if (cdr:GetHealthPercent() < 0.75) and Utilities.XZDistanceTwoVectors(cdr.CDRHome, cdr:GetPosition()) > 30 then
                continueFighting = false
            end
        until not continueFighting or not aiBrain:PlatoonExists(plat)

        IssueClearCommands({cdr})

        -- Finish the unit
        if cdr.UnitBeingBuiltBehavior and not cdr.UnitBeingBuiltBehavior:BeenDestroyed() and cdr.UnitBeingBuiltBehavior:GetFractionComplete() < 1 then
            IssueRepair({cdr}, cdr.UnitBeingBuiltBehavior)
        end
        cdr.UnitBeingBuiltBehavior = false
    end
end

function CDRReturnHomeRNG(aiBrain, cdr)
    -- This is a reference... so it will autoupdate
    local cdrPos = cdr:GetPosition()
    local distSqAway = 1600
    local loc = cdr.CDRHome
    if not cdr.Dead and VDist2Sq(cdrPos[1], cdrPos[3], loc[1], loc[3]) > distSqAway then
        local plat = aiBrain:MakePlatoon('', '')
        aiBrain:AssignUnitsToPlatoon(plat, {cdr}, 'support', 'None')
        repeat
            CDRRevertPriorityChange(aiBrain, cdr)
            if not aiBrain:PlatoonExists(plat) then
                return
            end
            IssueStop({cdr})
            IssueMove({cdr}, loc)
            cdr.GoingHome = true
            WaitTicks(70)
        until cdr.Dead or VDist2Sq(cdrPos[1], cdrPos[3], loc[1], loc[3]) <= distSqAway

        cdr.GoingHome = false
        IssueClearCommands({cdr})
    end
end