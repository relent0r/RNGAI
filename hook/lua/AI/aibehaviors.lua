WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] * RNGAI: offset aibehaviors.lua' )

--local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetMOARadii()
local UnitRatioCheckRNG = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').UnitRatioCheckRNG
local lerpy = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').lerpy
local SetArcPoints = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').SetArcPoints
local GeneratePointsAroundPosition = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GeneratePointsAroundPosition
local GetEconomyStored = moho.aibrain_methods.GetEconomyStored
local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local GetEconomyTrend = moho.aibrain_methods.GetEconomyTrend
local GetEconomyIncome = moho.aibrain_methods.GetEconomyIncome
local GetEconomyRequested = moho.aibrain_methods.GetEconomyRequested
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local MakePlatoon = moho.aibrain_methods.MakePlatoon
local AssignUnitsToPlatoon = moho.aibrain_methods.AssignUnitsToPlatoon
local PlatoonExists = moho.aibrain_methods.PlatoonExists
local GetListOfUnits = moho.aibrain_methods.GetListOfUnits
local GetPlatoonPosition = moho.platoon_methods.GetPlatoonPosition
local PlatoonExists = moho.aibrain_methods.PlatoonExists
local GetMostRestrictiveLayer = import('/lua/ai/aiattackutilities.lua').GetMostRestrictiveLayer

function CommanderBehaviorRNG(platoon)
    for _, v in platoon:GetPlatoonUnits() do
        if not v.Dead and not v.CommanderThread then
            v.CommanderThread = v:ForkThread(CommanderThreadRNG, platoon)
        end
    end
end

function SetCDRDefaults(aiBrain, cdr, plat)
    cdr.CDRHome = table.copy(cdr:GetPosition())
    aiBrain.ACUSupport.ACUMaxSearchRadius = 80
    cdr.GunUpgradeRequired = false
    cdr.GunUpgradePresent = false
end

function CDRGunCheck(aiBrain, cdr)
    local factionIndex = aiBrain:GetFactionIndex()
    if factionIndex == 1 then
        if not cdr:HasEnhancement('HeavyAntiMatterCannon') then
            return true
        end
    elseif factionIndex == 2 then
        if not cdr:HasEnhancement('CrysalisBeam') then
            return true
        end
    elseif factionIndex == 3 then
        if not cdr:HasEnhancement('CoolingUpgrade') then
            return true
        end
    elseif factionIndex == 4 then
        if not cdr:HasEnhancement('RateOfFire') then
            return true
        end
    end
    return false
end

function CommanderThreadRNG(cdr, platoon)
    --LOG('* AI-RNG: Starting CommanderThreadRNG')
    local aiBrain = cdr:GetAIBrain()
    
    aiBrain:BuildScoutLocationsRNG()
    cdr.UnitBeingBuiltBehavior = false
    -- Added to ensure we know the start locations (thanks to Sorian).
    SetCDRDefaults(aiBrain, cdr, platoon)

    while not cdr.Dead do
        -- Overcharge
        if (aiBrain.EnemyIntel.EnemyThreatCurrent.ACUGunUpgrades > 0) and (not cdr.GunUpgradePresent) and (GetGameTimeSeconds() < 1500) then
            if CDRGunCheck(aiBrain, cdr) then
                --LOG('ACU Requires Gun set upgrade flag to true')
                cdr.GunUpgradeRequired = true
            else
                cdr.GunUpgradeRequired = false
            end
        end

        if not cdr.Dead then
            CDREnhancementsRNG(aiBrain, cdr)
        end
        WaitTicks(2)

        if not cdr.Dead then 
            CDROverChargeRNG(aiBrain, cdr) 
        end
        WaitTicks(1)

        -- Go back to base
        if not cdr.Dead and aiBrain.ACUSupport.ReturnHome then 
            CDRReturnHomeRNG(aiBrain, cdr) 
        end
        WaitTicks(2)
        
        if not cdr.Dead then 
            CDRUnitCompletion(aiBrain, cdr) 
        end
        WaitTicks(2)

        if not cdr.Dead then
            CDRHideBehaviorRNG(aiBrain, cdr)
        end
        WaitTicks(2)

        -- Call platoon resume building deal...
        if not cdr.Dead and cdr:IsIdleState() and not cdr.GoingHome and not cdr:IsUnitState("Moving")
        and not cdr:IsUnitState("Building") and not cdr:IsUnitState("Guarding")
        and not cdr:IsUnitState("Attacking") and not cdr:IsUnitState("Repairing")
        and not cdr:IsUnitState("Upgrading") and not cdr:IsUnitState("Enhancing") 
        and not cdr:IsUnitState('BlockCommandQueue') and not cdr.UnitBeingBuiltBehavior and not cdr.Upgrading and not cdr.Combat then
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
                --LOG('CDR Getting assigned back to unassigned pool')
                AssignUnitsToPlatoon(aiBrain, pool, {cdr}, 'Unassigned', 'None')
            -- if we have a BuildQueue then continue building
            elseif cdr.EngineerBuildQueue and table.getn(cdr.EngineerBuildQueue) ~= 0 then
                if not cdr.NotBuildingThread then
                    --LOG('ACU Watch for not building triggered')
                    cdr.NotBuildingThread = cdr:ForkThread(platoon.WatchForNotBuildingRNG)
                end
            end
        end
        WaitTicks(5)
    end
end

function CDROverChargeRNG(aiBrain, cdr)
    local weapBPs = cdr:GetBlueprint().Weapon
    local overCharge = {}
    local weapon = {}
    local factionIndex = aiBrain:GetFactionIndex()
    local acuThreatLimit = 22
    
    for k, v in weapBPs do
        if v.Label == 'RightDisruptor' or v.Label == 'RightZephyr' or v.Label == 'RightRipper' or v.Label == 'ChronotronCannon' then
            weapon = v
            weapon.Range = v.MaxRadius - 3
            --LOG('* AI-RNG: ACU Weapon Range is :'..weaponRange)
            continue
        end
        if v.Label == 'OverCharge' then
            overCharge = v
            break
        end

    end
    -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
    if factionIndex == 1 then
        if cdr:HasEnhancement('HeavyAntiMatterCannon') then
            cdr.GunUpgradePresent = true
            weapon.Range = 30 - 3
            acuThreatLimit = 37
        end
    elseif factionIndex == 2 then
        if cdr:HasEnhancement('CrysalisBeam') then
            cdr.GunUpgradePresent = true
            weapon.Range = 35 - 3
            acuThreatLimit = 37
        end
    elseif factionIndex == 3 then
        if cdr:HasEnhancement('CoolingUpgrade') then
            cdr.GunUpgradePresent = true
            weapon.Range = 30 - 3
            acuThreatLimit = 37
        end
    elseif factionIndex == 4 then
        if cdr:HasEnhancement('RateOfFire') then
            cdr.GunUpgradePresent = true
            weapon.Range = 30 - 3
            acuThreatLimit = 37
        end
    end

    --cdr.UnitBeingBuiltBehavior = false

    -- Added for ACUs starting near each other
    if GetGameTimeSeconds() < 120 then
        return
    end

    -- Increase distress on non-water maps
    local distressRange = 60
    if cdr:GetHealthPercent() > 0.8 and aiBrain:GetMapWaterRatio() < 0.4 then
        distressRange = 100
    end

    -- Increase attack range for a few mins on small maps
    local maxRadius = weapon.MaxRadius + 20
    local mapSizeX, mapSizeZ = GetMapSize()
    if cdr:GetHealthPercent() > 0.8
        and GetGameTimeSeconds() > 260
        and mapSizeX <= 512 and mapSizeZ <= 512
        then
        maxRadius = 260 - GetGameTimeSeconds()/60*6 -- reduce the radius by 6 map units per minute. After 30 minutes it's (240-180) = 60
        if maxRadius < 60 then 
            maxRadius = 60 -- IF maxTimeRadius < 60 THEN maxTimeRadius = 60
        end
        aiBrain.ACUSupport.ACUMaxSearchRadius = maxRadius
    end
    
    -- Take away engineers too
    local cdrPos = cdr.CDRHome
    local numUnits = GetNumUnitsAroundPoint(aiBrain, categories.LAND - categories.SCOUT, cdrPos, (maxRadius), 'Enemy')
    local acuUnits = GetNumUnitsAroundPoint(aiBrain, categories.LAND * categories.COMMAND - categories.SCOUT, cdrPos, (maxRadius), 'Enemy')
    local distressLoc = aiBrain:BaseMonitorDistressLocationRNG(cdrPos)
    local overCharging = false

    -- Don't move if upgrading
    if cdr:IsUnitState("Upgrading") or cdr:IsUnitState("Enhancing") then
        return
    end

    if Utilities.XZDistanceTwoVectors(cdrPos, cdr:GetPosition()) > maxRadius then
        return
    end

    if numUnits > 1 or (not cdr.DistressCall and distressLoc and Utilities.XZDistanceTwoVectors(distressLoc, cdrPos) < distressRange) then
        --LOG('Num of units greater than zero or base distress')
        if cdr.UnitBeingBuilt then
            --LOG('Unit being built is true, assign to cdr.UnitBeingBuiltBehavior')
            cdr.UnitBeingBuiltBehavior = cdr.UnitBeingBuilt
        end
        if cdr.PlatoonHandle and cdr.PlatoonHandle != aiBrain.ArmyPool then
            if PlatoonExists(aiBrain, cdr.PlatoonHandle) then
                --LOG("*AI DEBUG "..aiBrain.Nickname.." CDR disbands ")
                cdr.PlatoonHandle:PlatoonDisband(aiBrain)
                
            end
        end
        cdr.Combat = true
        --LOG('Create Attack platoon')
        local plat = aiBrain:MakePlatoon('CDRAttack', 'none')
        --LOG('Set Platoon BuilderName')
        plat.BuilderName = 'CDR Combat'
        --LOG('Assign ACU to attack platoon')
        aiBrain:AssignUnitsToPlatoon(plat, {cdr}, 'Attack', 'None')
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
                        target = plat:FindClosestUnit('Attack', 'Enemy', true, v)
                        if target and Utilities.XZDistanceTwoVectors(cdrPos, target:GetPosition()) <= searchRadius then
                            if not aiBrain.ACUSupport.Supported then
                                aiBrain.ACUSupport.Position = cdr:GetPosition()
                                aiBrain.ACUSupport.Supported = true
                                --LOG('* AI-RNG: ACUSupport.Supported set to true')
                                aiBrain.ACUSupport.TargetPosition = target:GetPosition()
                            end
                            local cdrLayer = cdr:GetCurrentLayer()
                            local targetLayer = target:GetCurrentLayer()
                            if not (cdrLayer == 'Land' and (targetLayer == 'Air' or targetLayer == 'Sub' or targetLayer == 'Seabed')) and
                               not (cdrLayer == 'Seabed' and (targetLayer == 'Air' or targetLayer == 'Water')) then
                                --LOG('Layer not correct')
                                break
                            end
                        end
                        target = false
                    end
                    WaitTicks(1)
                    --LOG('No target found in sweep increasing search radius')
                until target or searchRadius >= maxRadius or not aiBrain:PlatoonExists(plat)

                if target then
                    --LOG('Target Found')
                    local targetPos = target:GetPosition()
                    local cdrPos = cdr:GetPosition()
                    aiBrain.BaseMonitor.CDRDistress = targetPos
                    aiBrain.BaseMonitor.CDRThreatLevel = aiBrain:GetThreatAtPosition(targetPos, 1, true, 'AntiSurface')
                    --LOG('CDR Position in Brain :'..repr(aiBrain.ACUSupport.Position))
                    local targetDistance = VDist2(cdrPos[1], cdrPos[3], targetPos[1], targetPos[3])
                    

                    -- If inside base dont check threat, just shoot!
                    if Utilities.XZDistanceTwoVectors(cdr.CDRHome, cdr:GetPosition()) > 45 then
                        enemyThreat = aiBrain:GetThreatAtPosition(targetPos, 1, true, 'AntiSurface')
                        --LOG('enemyThreat is '..enemyThreat)
                        enemyCdrThreat = aiBrain:GetThreatAtPosition(targetPos, 1, true, 'Commander')
                        --LOG('enemyCDR is '..enemyCdrThreat)
                        friendlyThreat = aiBrain:GetThreatAtPosition(targetPos, 1, true, 'AntiSurface', aiBrain:GetArmyIndex())
                        --LOG('friendlyThreat is'..friendlyThreat)
                        if enemyThreat - enemyCdrThreat >= friendlyThreat + (cdrThreat / 1.5) then
                            --LOG('Enemy Threat too high')
                            break
                        end
                    end

                    if aiBrain:GetEconomyStored('ENERGY') >= overCharge.EnergyRequired and target and not target.Dead then
                        --LOG('* AI-RNG: Stored Energy is :'..aiBrain:GetEconomyStored('ENERGY')..' OverCharge enerygy required is :'..overCharge.EnergyRequired)
                        overCharging = true
                        IssueClearCommands({cdr})
                        --LOG('* AI-RNG: Target Distance is '..targetDistance..' Weapong Range is '..weapon.Range)
                        local result, newTarget = CDRGetUnitClump(aiBrain, cdrPos, weapon.Range)
                        if result then
                            --LOG('New Unit Found for OC')
                            target = newTarget
                            targetPos = target:GetPosition()
                            targetDistance = VDist2(cdrPos[1], cdrPos[3], targetPos[1], targetPos[3])
                        end
                        local movePos = lerpy(cdrPos, targetPos, {targetDistance, targetDistance - weapon.Range})
                        if aiBrain:CheckBlockingTerrain(movePos, targetPos, 'none') then
                            if not PlatoonExists(aiBrain, plat) then
                                local plat = aiBrain:MakePlatoon('CDRAttack', 'none')
                                plat.BuilderName = 'CDR Combat'
                                aiBrain:AssignUnitsToPlatoon(plat, {cdr}, 'Attack', 'None')
                            end
                            cdr.PlatoonHandle:MoveToLocation(cdr.CDRHome, false)
                            WaitTicks(30)
                            IssueClearCommands({cdr})
                            continue
                        end
                        cdr.PlatoonHandle:MoveToLocation(movePos, false)
                        if target and not target.Dead and not target:BeenDestroyed() then
                            IssueOverCharge({cdr}, target)
                        end
                    elseif target and not target.Dead and not target:BeenDestroyed() then -- Commander attacks even if not enough energy for overcharge
                        IssueClearCommands({cdr})
                        local movePos = lerpy(cdrPos, targetPos, {targetDistance, targetDistance - weapon.Range})
                        if aiBrain:CheckBlockingTerrain(movePos, targetPos, 'none') then
                            cdr.PlatoonHandle:MoveToLocation(cdr.CDRHome, false)
                            WaitTicks(30)
                            IssueClearCommands({cdr})
                            continue
                        end
                        local cdrNewPos = {}
                        --LOG('* AI-RNG: Move Position is'..repr(movePos))
                        --LOG('* AI-RNG: Moving to movePos to attack')
                        if not PlatoonExists(aiBrain, plat) then
                            local plat = aiBrain:MakePlatoon('CDRAttack', 'none')
                            plat.BuilderName = 'CDR Combat'
                            aiBrain:AssignUnitsToPlatoon(plat, {cdr}, 'Attack', 'None')
                        end
                        cdr.PlatoonHandle:MoveToLocation(movePos, false)
                        cdrNewPos[1] = movePos[1] + Random(-8, 8)
                        cdrNewPos[2] = movePos[2]
                        cdrNewPos[3] = movePos[3] + Random(-8, 8)
                        cdr.PlatoonHandle:MoveToLocation(cdrNewPos, false)
                    end
                elseif distressLoc then
                    --LOG('* AI-RNG: ACU Detected Distress Location')
                    enemyThreat = aiBrain:GetThreatAtPosition(distressLoc, 1, true, 'AntiSurface')
                    enemyCdrThreat = aiBrain:GetThreatAtPosition(distressLoc, 1, true, 'Commander')
                    friendlyThreat = aiBrain:GetThreatAtPosition(distressLoc, 1, true, 'AntiSurface', aiBrain:GetArmyIndex())
                    if enemyThreat - enemyCdrThreat >= friendlyThreat + (cdrThreat / 3) then
                        break
                    end
                    if distressLoc and (Utilities.XZDistanceTwoVectors(distressLoc, cdrPos) < distressRange) then
                        IssueClearCommands({cdr})
                        --LOG('* AI-RNG: ACU Moving to distress location')
                        cdr.PlatoonHandle:MoveToLocation(distressLoc, false)
                        cdr.PlatoonHandle:MoveToLocation(cdr.CDRHome, false)
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

            distressLoc = aiBrain:BaseMonitorDistressLocationRNG(cdrPos)
            if cdr.Dead then
                --LOG('CDR Considered dead, returning')
                return
            end

            if GetNumUnitsAroundPoint(aiBrain, categories.LAND - categories.SCOUT, cdrPos, maxRadius, 'Enemy') <= 0
                and (not distressLoc or Utilities.XZDistanceTwoVectors(distressLoc, cdrPos) > distressRange) then
                continueFighting = false
            end
            -- If com is down to yellow then dont keep fighting
            if (cdr:GetHealthPercent() < 0.70) and Utilities.XZDistanceTwoVectors(cdr.CDRHome, cdr:GetPosition()) > 30 then
                continueFighting = false
                if not cdr.GunUpgradePresent then
                    --LOG('ACU Low health and no gun upgrade, set required')
                    cdr.GunUpgradeRequired = true
                end
            end
            if continueFighting == true then
                local enemyUnits = GetUnitsAroundPoint(aiBrain, (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * (categories.LAND + categories.AIR) - categories.SCOUT - categories.ENGINEER ), cdr:GetPosition(), 70, 'Enemy')
                local enemyUnitThreat = 0
                local bp
                for k,v in enemyUnits do
                    if not v.Dead then
                        if EntityCategoryContains(categories.COMMAND, v) then
                            if v:HasEnhancement('HeavyAntiMatterCannon') or v:HasEnhancement('CrysalisBeam') or v:HasEnhancement('CoolingUpgrade') or v:HasEnhancement('RateOfFire') then
                                enemyUnitThreat = enemyUnitThreat + 25
                            else
                                enemyUnitThreat = enemyUnitThreat + 15
                            end
                        else
                            --LOG('Unit ID is '..v.UnitId)
                            bp = __blueprints[v.UnitId].Defense
                            --LOG(repr(__blueprints[v.UnitId].Defense))
                            if bp.SurfaceThreatLevel ~= nil then
                                enemyUnitThreat = enemyUnitThreat + bp.SurfaceThreatLevel
                                if enemyUnitThreat > acuThreatLimit then
                                    break
                                end
                            end
                        end
                    end
                end
                --LOG('Total Enemy Threat '..enemyUnitThreat)
                --LOG('ACU Cutoff Threat '..acuThreatLimit)
                --LOG('Distance from home '..Utilities.XZDistanceTwoVectors(cdr.CDRHome, cdr:GetPosition()))
                if (enemyUnitThreat > acuThreatLimit) and (Utilities.XZDistanceTwoVectors(cdr.CDRHome, cdr:GetPosition()) > 40) then
                    --LOG('* AI-RNG: Enemy unit threat too high cease fighting, unitThreat :'..enemyUnitThreat)
                    continueFighting = false
                end
            end
            if (aiBrain.EnemyIntel.EnemyThreatCurrent.ACUGunUpgrades > 0) and (not cdr.GunUpgradePresent) and (GetGameTimeSeconds() < 1500) then
                if CDRGunCheck(aiBrain, cdr) then
                    --LOG('ACU Requires Gun set upgrade flag to true, continue fighting set to false')
                    cdr.GunUpgradeRequired = true
                    continueFighting = false
                else
                    cdr.GunUpgradeRequired = false
                end
            end
            --[[
            if not continueFighting then
                --LOG('Continue Fighting was set to false')
            else
                --LOG('Continue Fighting is still true')
            end]]
            if not aiBrain:PlatoonExists(plat) then
                --LOG('* AI-RNG: CDRAttack platoon no longer exist, something disbanded it')
            end
            WaitTicks(1)
        until not continueFighting or not aiBrain:PlatoonExists(plat)
        cdr.Combat = false
        cdr.GoingHome = true -- had to add this as the EM was assigning jobs between this and the returnhome function
        aiBrain.ACUSupport.ReturnHome = true
        aiBrain.ACUSupport.TargetPosition = false
        aiBrain.ACUSupport.Supported = false
        aiBrain.BaseMonitor.CDRDistress = false
        aiBrain.BaseMonitor.CDRThreatLevel = 0
        --LOG('* AI-RNG: ACUSupport.Supported set to false')
    end
end

function CDRReturnHomeRNG(aiBrain, cdr)
    -- This is a reference... so it will autoupdate
    local cdrPos = cdr:GetPosition()
    local distSqAway = 2025
    local loc = cdr.CDRHome
    local maxRadius = aiBrain.ACUSupport.ACUMaxSearchRadius
    local acuThreatLimit = 15
    if not cdr.Dead and VDist2Sq(cdrPos[1], cdrPos[3], loc[1], loc[3]) > distSqAway then
        --LOG('CDR further than distSqAway')
        cdr.GoingHome = true
        local plat = aiBrain:MakePlatoon('CDRReturnHome', 'none')
        aiBrain:AssignUnitsToPlatoon(plat, {cdr}, 'support', 'None')
        repeat
            CDRRevertPriorityChange(aiBrain, cdr)
            IssueClearCommands({cdr})
            IssueStop({cdr})
            local acuPos1 = table.copy(cdrPos)
            --LOG('ACU Pos 1 :'..repr(acuPos1))
            --LOG('Home location is :'..repr(loc))
            if not PlatoonExists(aiBrain, plat) then
                local plat = aiBrain:MakePlatoon('CDRReturnHome', 'none')
                aiBrain:AssignUnitsToPlatoon(plat, {cdr}, 'support', 'None')
            end
            cdr.PlatoonHandle:MoveToLocation(loc, false)
            WaitTicks(40)
            local acuPos2 = table.copy(cdrPos)
            local headingVec = {(2 * (10 * acuPos2[1] - acuPos1[1]*9) + loc[1])/3, 0, (2 * (10 * acuPos2[3] - acuPos1[3]*9) + loc[3])/3}
            local movePosTable = SetArcPoints(headingVec,acuPos2, 15, 3, 8)
            local indexVar = math.random(1,3)
            IssueClearCommands({cdr})
            IssueStop({cdr})
            --LOG('movePos Table '..repr(movePosTable[indexVar]))
            if movePosTable[indexVar] ~= nil then
                if not PlatoonExists(aiBrain, plat) then
                    local plat = aiBrain:MakePlatoon('CDRReturnHome', 'none')
                    aiBrain:AssignUnitsToPlatoon(plat, {cdr}, 'support', 'None')
                end
                cdr.PlatoonHandle:MoveToLocation(movePosTable[indexVar], false)
            else
                if not PlatoonExists(aiBrain, plat) then
                    local plat = aiBrain:MakePlatoon('CDRReturnHome', 'none')
                    aiBrain:AssignUnitsToPlatoon(plat, {cdr}, 'support', 'None')
                end
                cdr.PlatoonHandle:MoveToLocation(loc, false)
            end
            WaitTicks(20)
            if (cdr:GetHealthPercent() > 0.75) and not cdr.GunUpgradeRequired then
                if (GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND, loc, maxRadius, 'ENEMY') > 0 ) then
                    local enemyUnits = aiBrain:GetUnitsAroundPoint((categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * (categories.LAND + categories.AIR) - categories.SCOUT - categories.ENGINEER - categories.COMMAND), cdr:GetPosition(), 70, 'Enemy')
                    local enemyUnitThreat = 0
                    local bp
                    for k,v in enemyUnits do
                        if not v.Dead then
                            --LOG('Unit Defense is'..repr(v:GetBlueprint().Defense))
                            --LOG('Unit ID is '..v.UnitId)
                            --bp = v:GetBlueprint().Defense
                            bp = __blueprints[v.UnitId].Defense
                            --LOG(repr(__blueprints[v.UnitId].Defense))
                            if bp.SurfaceThreatLevel ~= nil then
                                enemyUnitThreat = enemyUnitThreat + bp.SurfaceThreatLevel
                                if enemyUnitThreat > acuThreatLimit then
                                    break
                                end
                            end
                        end
                    end
                    --LOG('Total Enemy Threat '..enemyUnitThreat)
                    --LOG('ACU Cutoff Threat '..acuThreatLimit)
                    --LOG('Distance from home '..Utilities.XZDistanceTwoVectors(cdr.CDRHome, cdr:GetPosition()))
                    if (enemyUnitThreat < acuThreatLimit) then
                        --LOG('* AI-RNG: Enemy unit threat low enough to return to fighting :'..enemyUnitThreat)
                        cdr.GoingHome = false
                        IssueStop({cdr})
                        return CDROverChargeRNG(aiBrain, cdr)
                    end
                end
            end
        until cdr.Dead or VDist2Sq(cdrPos[1], cdrPos[3], loc[1], loc[3]) <= distSqAway or not aiBrain:PlatoonExists(plat)

        cdr.GoingHome = false
        IssueClearCommands({cdr})
    end
    --LOG('Sometimes the combat platoon gets disbanded, hard to find the reason')
    if aiBrain.ACUSupport.Supported then
        aiBrain.ACUSupport.Supported = false
    end
    cdr.GoingHome = false
    if aiBrain.BaseMonitor.CDRDistress then
        aiBrain.BaseMonitor.CDRDistress = false
        aiBrain.BaseMonitor.CDRThreatLevel = 0
    end
end

function CDRUnitCompletion(aiBrain, cdr)
    if cdr.UnitBeingBuiltBehavior and not cdr.Combat and not cdr.Upgrading and not cdr.GoingHome then
        if not cdr.UnitBeingBuiltBehavior:BeenDestroyed() and cdr.UnitBeingBuiltBehavior:GetFractionComplete() < 1 then
            --LOG('* AI-RNG: Attempt unit Completion')
            IssueClearCommands( {cdr} )
            IssueRepair( {cdr}, cdr.UnitBeingBuiltBehavior )
            WaitTicks(60)
        end
        if not cdr.UnitBeingBuiltBehavior:BeenDestroyed() then
            --LOG('* AI-RNG: Unit Completion is :'..cdr.UnitBeingBuiltBehavior:GetFractionComplete())
            if cdr.UnitBeingBuiltBehavior:GetFractionComplete() == 1 then
                --LOG('* AI-RNG: Unit is completed set UnitBeingBuiltBehavior to false')
                cdr.UnitBeingBuiltBehavior = false
            end
        elseif cdr.UnitBeingBuiltBehavior:BeenDestroyed() then
            --LOG('* AI-RNG: Unit was destroyed set UnitBeingBuiltBehavior to false')
            cdr.UnitBeingBuiltBehavior = false
        end
    end
end

function CDRHideBehaviorRNG(aiBrain, cdr)
    if cdr:IsIdleState() then
        cdr.GoingHome = false
        cdr.Combat = false
        cdr.Upgrading = false

        local category = false
        local runShield = false
        local runPos = false
        local nmaShield = GetNumUnitsAroundPoint(aiBrain, categories.SHIELD * categories.STRUCTURE, cdr:GetPosition(), 100, 'Ally')
        local nmaPD = GetNumUnitsAroundPoint(aiBrain, categories.DIRECTFIRE * categories.DEFENSE, cdr:GetPosition(), 100, 'Ally')
        local nmaAA = GetNumUnitsAroundPoint(aiBrain, categories.ANTIAIR * categories.DEFENSE, cdr:GetPosition(), 100, 'Ally')

        if nmaShield > 0 then
            category = categories.SHIELD * categories.STRUCTURE
            runShield = true
        elseif nmaAA > 0 then
            category = categories.DEFENSE * categories.ANTIAIR
        elseif nmaPD > 0 then
            category = categories.DEFENSE * categories.DIRECTFIRE
        end

        if category then
            runPos = AIUtils.AIFindDefensiveAreaSorian(aiBrain, cdr, category, 100, runShield)
            IssueClearCommands({cdr})
            IssueMove({cdr}, runPos)
            WaitTicks(30)
        end

        if not category or not runPos then
            local cdrNewPos = {}
            cdrNewPos[1] = cdr.CDRHome[1] + Random(-6, 6)
            cdrNewPos[2] = cdr.CDRHome[2]
            cdrNewPos[3] = cdr.CDRHome[3] + Random(-6, 6)
            WaitTicks(1)
            IssueStop({cdr})
            IssueMove({cdr}, cdrNewPos)
            WaitTicks(30)
        end
    end
    WaitTicks(5)
end

function CDRGetUnitClump(aiBrain, cdrPos, radius)
    -- Will attempt to get a unit clump rather than single unit targets for OC
    local unitList = GetUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, cdrPos, radius, 'Enemy')
    --LOG('Check for unit clump')
    for k, v in unitList do
        local unitPos = v:GetPosition()
        local unitCount = GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, unitPos, 2.5, 'Enemy')
        if unitCount > 1 then
            --LOG('Multiple Units found')
            return true, v
        end
    end
    return false
end

function ACUDetection(platoon)
    
    local aiBrain = platoon:GetBrain()
    local ACUTable = aiBrain.EnemyIntel.ACU
    local scanWait = platoon.PlatoonData.ScanWait
    local unit = platoon:GetPlatoonUnits()[1]

    --LOG('* AI-RNG: ACU Detection Behavior Running')
    if ACUTable then 
        while not unit.Dead do
            local currentGameTime = GetGameTimeSeconds()
            local acuUnits = GetUnitsAroundPoint(aiBrain, categories.COMMAND, unit:GetPosition(), 40, 'Enemy')
            if acuUnits[1] then
                --LOG('* AI-RNG: ACU Detected')
                for _, v in acuUnits do
                    --unitDesc = GetBlueprint(v).Description
                    --LOG('* AI-RNG: Units is'..unitDesc)
                    enemyIndex = v:GetAIBrain():GetArmyIndex()
                    --LOG('* AI-RNG: EnemyIndex :'..enemyIndex)
                    --LOG('* AI-RNG: Curent Game Time : '..currentGameTime)
                    --LOG('* AI-RNG: Iterating ACUTable')
                    for k, c in ACUTable do
                        --LOG('* AI-RNG: Table Index is : '..k)
                        --LOG('* AI-RNG:'..c.LastSpotted)
                        --LOG('* AI-RNG:'..repr(c.Position))
                        if currentGameTime - 60 > c.LastSpotted and k == enemyIndex then
                            --LOG('* AI-RNG: CurrentGameTime IF is true updating tables')
                            c.Position = v:GetPosition()
                            acuThreat = aiBrain:GetThreatAtPosition(c.Position, 0, true, 'Overall')
                            --LOG('* AI-RNG: Threat at ACU location is :'..acuThreat)
                            c.Threat = acuThreat
                            c.LastSpotted = currentGameTime
                        end
                    end
                end
            end
            WaitTicks(scanWait)
        end
    else
            WARN('No EnemyIntel ACU Table found, is the game still initializing?')
    end
end

-- 99% of the below was Sprouto's work
function StructureUpgradeThread(unit, aiBrain, upgradeSpec, bypasseco) 
    --LOG('* AI-RNG: Starting structure thread upgrade for'..aiBrain.Nickname)

    local unitBp = unit:GetBlueprint()
    local upgradeID = unitBp.General.UpgradesTo or false
    local upgradebp = false
    local unitType, unitTech = StructureTypeCheck(aiBrain, unitBp)

    if upgradeID then
        upgradebp = aiBrain:GetUnitBlueprint(upgradeID) or false
    end

    if not (upgradeID and upgradebp) then
        unit.UpgradeThread = nil
        unit.UpgradesComplete = true
        --LOG('* AI-RNG: upgradeID or upgradebp is false, returning')
        return
    end

    local upgradeable = true
    local upgradeIssued = false

    if not bypasseco then
        local bypasseco = false
    end
    -- Eco requirements
    local massNeeded = upgradebp.Economy.BuildCostMass
	local energyNeeded = upgradebp.Economy.BuildCostEnergy
    local buildtime = upgradebp.Economy.BuildTime
    --LOG('Mass Needed '..massNeeded)
    --LOG('Energy Needed '..energyNeeded)
    -- build rate
    local buildrate = unitBp.Economy.BuildRate

    -- production while upgrading
    local massProduction = unitBp.Economy.ProductionPerSecondMass or 0
    local energyProduction = unitBp.Economy.ProductionPerSecondEnergy or 0
    
    local massTrendNeeded = ( math.min( 0,(massNeeded / buildtime) * buildrate) - massProduction) * .1
    --LOG('Mass Trend Needed for '..unitTech..' Extractor :'..massTrendNeeded)
    local energyTrendNeeded = ( math.min( 0,(energyNeeded / buildtime) * buildrate) - energyProduction) * .1
    --LOG('Energy Trend Needed for '..unitTech..' Extractor :'..energyTrendNeeded)
    local energyMaintenance = (upgradebp.Economy.MaintenanceConsumptionPerSecondEnergy or 10) * .1

    -- Define Economic Data
    local eco = aiBrain.EcoData.OverTime -- mother of god I'm stupid this is another bit of Sprouto genius.
    local massStorage
    local energyStorage
    local massStorageRatio
    local energyStorageRatio
    local massIncome
    local massRequested
    local energyIncome
    local energyRequested
    local massTrend
    local energyTrend
    local massEfficiency
    local energyEfficiency
    local ecoTimeOut
    local upgradeNumLimit
    local extractorUpgradeLimit = 0
    local extractorClosest = false
    local multiplier
    local initial_delay = 0
    local ecoStartTime = GetGameTimeSeconds()

    if aiBrain.CheatEnabled then
        multiplier = tonumber(ScenarioInfo.Options.BuildMult)
    else
        multiplier = 1
    end

    if unitTech == 'TECH1' and aiBrain.UpgradeMode == 'Aggressive' then
        ecoTimeOut = (320 / multiplier)
    elseif unitTech == 'TECH2' and aiBrain.UpgradeMode == 'Aggressive' then
        ecoTimeOut = (520 / multiplier)
    elseif unitTech == 'TECH1' and aiBrain.UpgradeMode == 'Normal' then
        ecoTimeOut = (420 / multiplier)
    elseif unitTech == 'TECH2' and aiBrain.UpgradeMode == 'Normal' then
        ecoTimeOut = (720 / multiplier)
    elseif unitTech == 'TECH1' and aiBrain.UpgradeMode == 'Caution' then
        ecoTimeOut = (420 / multiplier)
    elseif unitTech == 'TECH2' and aiBrain.UpgradeMode == 'Caution' then
        ecoTimeOut = (720 / multiplier)
    end
    if aiBrain.CheatEnabled then
        multiplier = tonumber(ScenarioInfo.Options.BuildMult)
    else
        multiplier = 1
    end
    --LOG('Multiplier is '..multiplier)
    --LOG('Initial Delay is before any multiplier is '..upgradeSpec.InitialDelay)
    --LOG('Initial Delay is '..(upgradeSpec.InitialDelay / multiplier))
    --LOG('Eco timeout for Tech '..unitTech..' Extractor is '..ecoTimeOut)
    --LOG('* AI-RNG: Initial Variables set')
    while initial_delay < (upgradeSpec.InitialDelay / multiplier) do
		if GetEconomyStored( aiBrain, 'MASS') >= 50 and GetEconomyStored( aiBrain, 'ENERGY') >= 100 and unit:GetFractionComplete() == 1 then
            initial_delay = initial_delay + 10
            unit.InitialDelay = true
            if (GetGameTimeSeconds() - ecoStartTime) > ecoTimeOut then
                initial_delay = upgradeSpec.InitialDelay
            end
        end
        --LOG('* AI-RNG: Initial Delay loop trigger for '..aiBrain.Nickname..' is : '..initial_delay..' out of 90')
		WaitTicks(100)
    end
    unit.InitialDelay = false

    -- Main Upgrade Loop
    while ((not unit.Dead) or unit.Sync.id) and upgradeable and not upgradeIssued do
        --LOG('* AI-RNG: Upgrade main loop starting for'..aiBrain.Nickname)
        WaitTicks(upgradeSpec.UpgradeCheckWait * 10)
        upgradeSpec = aiBrain:GetUpgradeSpec(unit)
        --LOG('Upgrade Spec '..repr(upgradeSpec))
        --LOG('Current low mass trigger '..upgradeSpec.MassLowTrigger)
        if (GetGameTimeSeconds() - ecoStartTime) > ecoTimeOut then
            --LOG('Eco Bypass is True')
            bypasseco = true
        end
        if bypasseco then
            upgradeNumLimit = StructureUpgradeNumDelay(aiBrain, unitType, unitTech)
            if unitTech == 'TECH1' then
                extractorUpgradeLimit = aiBrain.EcoManager.ExtractorUpgradeLimit.TECH1
            elseif unitTech == 'TECH2' then
                extractorUpgradeLimit = aiBrain.EcoManager.ExtractorUpgradeLimit.TECH2
            end
            --LOG('UpgradeNumLimit is '..upgradeNumLimit)
            --LOG('extractorUpgradeLimit is '..extractorUpgradeLimit)
            if upgradeNumLimit >= extractorUpgradeLimit then
                WaitTicks(10)
                continue
            end
        end



        extractorClosest = ExtractorClosest(aiBrain, unit, unitBp)
        if not extractorClosest then
            --LOG('ExtractorClosest is false')
            WaitTicks(10)
            continue
        end
        if not unit.MAINBASE then
            if UnitRatioCheckRNG( aiBrain, 1.7, categories.MASSEXTRACTION * categories.TECH1, '>=', categories.MASSEXTRACTION * categories.TECH2 ) and unitTech == 'TECH2' then
                --LOG('Too few tech2 extractors to go tech3')
                ecoStartTime = ecoStartTime + upgradeSpec.UpgradeCheckWait
                WaitTicks(10)
                continue
            end
        end
        if unit.MAINBASE then
            --LOG('MAINBASE Extractor')
        end
        --LOG('Current Upgrade Limit is :'..upgradeNumLimit)
        
        --LOG('Upgrade Issued '..aiBrain.UpgradeIssued..' Upgrade Issued Limit '..aiBrain.UpgradeIssuedLimit)
        if aiBrain.UpgradeIssued < aiBrain.UpgradeIssuedLimit then
            --LOG('* AI-RNG:'..aiBrain.Nickname)
            --LOG('* AI-RNG: UpgradeIssues and UpgradeIssuedLimit are set')
            massStorage = GetEconomyStored( aiBrain, 'MASS')
            --LOG('* AI-RNG: massStorage'..massStorage)
            energyStorage = GetEconomyStored( aiBrain, 'ENERGY')
            --LOG('* AI-RNG: energyStorage'..energyStorage)
            massStorageRatio = GetEconomyStoredRatio(aiBrain, 'MASS')
            --LOG('* AI-RNG: massStorageRatio'..massStorageRatio)
            energyStorageRatio = GetEconomyStoredRatio(aiBrain, 'ENERGY')
            --LOG('* AI-RNG: energyStorageRatio'..energyStorageRatio)
            massIncome = GetEconomyIncome(aiBrain, 'MASS')
            --LOG('* AI-RNG: massIncome'..massIncome)
            massRequested = GetEconomyRequested(aiBrain, 'MASS')
            --LOG('* AI-RNG: massRequested'..massRequested)
            energyIncome = GetEconomyIncome(aiBrain, 'ENERGY')
            --LOG('* AI-RNG: energyIncome'..energyIncome)
            energyRequested = GetEconomyRequested(aiBrain, 'ENERGY')
            --LOG('* AI-RNG: energyRequested'..energyRequested)
            massTrend = GetEconomyTrend(aiBrain, 'MASS')
            --LOG('* AI-RNG: massTrend'..massTrend)
            energyTrend = GetEconomyTrend(aiBrain, 'ENERGY')
            --LOG('* AI-RNG: energyTrend'..energyTrend)
            massEfficiency = math.min(massIncome / massRequested, 2)
            --LOG('* AI-RNG: massEfficiency'..massEfficiency)
            energyEfficiency = math.min(energyIncome / energyRequested, 2)
            --LOG('* AI-RNG: energyEfficiency'..energyEfficiency)
            
            if (massEfficiency >= upgradeSpec.MassLowTrigger and energyEfficiency >= upgradeSpec.EnergyLowTrigger)
                or ((massStorageRatio > .60 and energyStorageRatio > .40))
                or (massStorage > (massNeeded * .7) and energyStorage > (energyNeeded * .7 ) ) or bypasseco then
                    if bypasseco then
                        --LOG('Low Triggered bypasseco')
                    else
                        --LOG('* AI-RNG: low_trigger_good = true')
                    end
                --LOG('* AI-RNG: low_trigger_good = true')
            else
                WaitTicks(10)
                continue
            end
            --[[
            if (massEfficiency <= upgradeSpec.MassHighTrigger and energyEfficiency <= upgradeSpec.EnergyHighTrigger) then
                --LOG('* AI-RNG: hi_trigger_good = true')
            else
                continue
            end]]

            if ( massTrend >= massTrendNeeded and energyTrend >= energyTrendNeeded and energyTrend >= energyMaintenance )
				or ( massStorage >= (massNeeded * .7) and energyStorage > (energyNeeded * .7) ) or bypasseco then
				-- we need to have 15% of the resources stored -- some things like MEX can bypass this last check
				if (massStorage > ( massNeeded * .15 * upgradeSpec.MassLowTrigger) and energyStorage > ( energyNeeded * .15 * upgradeSpec.EnergyLowTrigger)) or bypasseco then
                    if aiBrain.UpgradeIssued < aiBrain.UpgradeIssuedLimit then
						if not unit.Dead then

                            upgradeIssued = true
                            IssueUpgrade({unit}, upgradeID)
                            if bypasseco then
                                --LOG('Upgrade Issued with bypass')
                            else
                                --LOG('Upgrade Issued without bypass')
                            end
                            -- if upgrade issued and not completely full --
                            if massStorageRatio < 1 or energyStorageRatio < 1 then
                                ForkThread(StructureUpgradeDelay, aiBrain, aiBrain.UpgradeIssuedPeriod)  -- delay the next upgrade by the full amount
                            else
                                ForkThread(StructureUpgradeDelay, aiBrain, aiBrain.UpgradeIssuedPeriod * .5)     -- otherwise halve the delay period
                            end

                            if ScenarioInfo.StructureUpgradeDialog then
                                --LOG("*AI DEBUG "..aiBrain.Nickname.." STRUCTUREUpgrade "..unit.Sync.id.." "..unit:GetBlueprint().Description.." upgrading to "..repr(upgradeID).." "..repr(__blueprints[upgradeID].Description).." at "..GetGameTimeSeconds() )
                            end

                            repeat
                               WaitTicks(50)
                            until unit.Dead or (unit.UnitBeingBuilt:GetBlueprint().BlueprintId == upgradeID) -- Fix this!
                        end

                        if unit.Dead then
                            --LOG("*AI DEBUG "..aiBrain.Nickname.." STRUCTUREUpgrade "..unit.Sync.id.." "..unit:GetBlueprint().Description.." to "..upgradeID.." failed.  Dead is "..repr(unit.Dead))
                            upgradeIssued = false
                        end

                        if upgradeIssued then
                            WaitTicks(10)
                            continue
                        end
                    end
                end
            else
                if ScenarioInfo.StructureUpgradeDialog then
                    if not ( massTrend >= massTrendNeeded ) then
                        --LOG("*AI DEBUG "..aiBrain.Nickname.." STRUCTUREUpgrade "..unit.Sync.id.." "..unit:GetBlueprint().Description.." FAILS MASS Trend trigger "..massTrend.." needed "..massTrendNeeded)
                    end
                    if not ( energyTrend >= energyTrendNeeded ) then
                        --LOG("*AI DEBUG "..aiBrain.Nickname.." STRUCTUREUpgrade "..unit.Sync.id.." "..unit:GetBlueprint().Description.." FAILS ENER Trend trigger "..energyTrend.." needed "..energyTrendNeeded)
                    end
                    if not (energyTrend >= energyMaintenance) then
                        --LOG("*AI DEBUG "..aiBrain.Nickname.." STRUCTUREUpgrade "..unit.Sync.id.." "..unit:GetBlueprint().Description.." FAILS Maintenance trigger "..energyTrend.." "..energyMaintenance)  
                    end
                    if not ( massStorage >= (massNeeded * .8)) then
                        --LOG("*AI DEBUG "..aiBrain.Nickname.." STRUCTUREUpgrade "..unit.Sync.id.." "..unit:GetBlueprint().Description.." FAILS MASS storage trigger "..massStorage.." needed "..(massNeeded*.8) )
                    end
                    if not (energyStorage > (energyNeeded * .4)) then
                        --LOG("*AI DEBUG "..aiBrain.Nickname.." STRUCTUREUpgrade "..unit.Sync.id.." "..unit:GetBlueprint().Description.." FAILS ENER storage trigger "..energyStorage.." needed "..(energyNeeded*.4) )
                    end
                end
            end
        end
    end

    if upgradeIssued then
		--LOG('* AI-RNG: upgradeIssued is true')
		unit.Upgrading = true
        unit.DesiresAssist = true
        local unitbeingbuiltbp = false
		
		local unitbeingbuilt = unit.UnitBeingBuilt
        unitbeingbuiltbp = unitbeingbuilt:GetBlueprint()
        upgradeID = unitbeingbuiltbp.General.UpgradesTo or false
        --LOG('* AI-RNG: T1 extractor upgrading to T2 then upgrades to :'..upgradeID)
		
		-- if the upgrade has a follow on upgrade - start an upgrade thread for it --
        if upgradeID and not unitbeingbuilt.Dead then
			upgradeSpec.InitialDelay = upgradeSpec.InitialDelay + 60			-- increase delay before first check for next upgrade
            unitbeingbuilt.DesiresAssist = true			-- let engineers know they can assist this upgrade
            --LOG('* AI-RNG: Forking another instance of StructureUpgradeThread')
			unitbeingbuilt.UpgradeThread = unitbeingbuilt:ForkThread( StructureUpgradeThread, aiBrain, upgradeSpec, bypasseco )
        end
		-- assign mass extractors to their own platoon 
		if (not unitbeingbuilt.Dead) and EntityCategoryContains( categories.MASSEXTRACTION, unitbeingbuilt) then
			local extractorPlatoon = MakePlatoon( aiBrain,'ExtractorPlatoon'..tostring(unitbeingbuilt.Sync.id), 'none')
			extractorPlatoon.BuilderName = 'ExtractorPlatoon'..tostring(unitbeingbuilt.Sync.id)
            extractorPlatoon.MovementLayer = 'Land'
            --LOG('* AI-RNG: Extractor Platoon name is '..extractorPlatoon.BuilderName)
			AssignUnitsToPlatoon( aiBrain, extractorPlatoon, {unitbeingbuilt}, 'Support', 'none' )
			extractorPlatoon:ForkThread( extractorPlatoon.ExtractorCallForHelpAIRNG, aiBrain )
		elseif (not unitbeingbuilt.Dead) then
            AssignUnitsToPlatoon( aiBrain, aiBrain.StructurePool, {unitbeingbuilt}, 'Support', 'none' )
		end
        unit.UpgradeThread = nil
	end
end

function StructureUpgradeDelay( aiBrain, delay )

    aiBrain.UpgradeIssued = aiBrain.UpgradeIssued + 1
    
    if ScenarioInfo.StructureUpgradeDialog then
        --LOG("*AI DEBUG "..aiBrain.Nickname.." STRUCTUREUpgrade counter up to "..aiBrain.UpgradeIssued.." period is "..delay)
    end

    WaitTicks( delay )
    aiBrain.UpgradeIssued = aiBrain.UpgradeIssued - 1
    --LOG('Upgrade Issue delay over')
    
    if ScenarioInfo.StructureUpgradeDialog then
        --LOG("*AI DEBUG "..aiBrain.Nickname.." STRUCTUREUpgrade counter down to "..aiBrain.UpgradeIssued)
    end
end

function StructureUpgradeNumDelay(aiBrain, type, tech)
    -- Checked if a slot is available for unit upgrades
    local numLimit = false
    if type == 'MASSEXTRACTION' and tech == 'TECH1' then
        numLimit = aiBrain.EcoManager.ExtractorsUpgrading.TECH1
    elseif type == 'MASSEXTRACTION' and tech == 'TECH2' then
        numLimit = aiBrain.EcoManager.ExtractorsUpgrading.TECH2
    end
    if numLimit then
        return numLimit
    else
        return false
    end
    return false
end

function StructureTypeCheck(aiBrain, unitBp)
    -- Returns the tech and type of a structure unit
    local unitType = false
    local unitTech = false
    for k, v in unitBp.Categories do
        if v == 'MASSEXTRACTION' then
            --LOG('Unit is Mass Extractor')
            unitType = 'MASSEXTRACTION'
        else
            --LOG('Value Not Mass Extraction')
        end

        if v == 'TECH1' then
            --LOG('Extractor is Tech 1')
            unitTech = 'TECH1'
        elseif v == 'TECH2' then
            --LOG('Extractor is Tech 2')
            unitTech = 'TECH2'
        else
            --LOG('Value not TECH1, TECH2')
        end
    end
    if unitType and unitTech then
       return unitType, unitTech
    else
        return false, false
    end
    return false, false
end

function ExtractorClosest(aiBrain, unit, unitBp)
    -- Checks if the unit is closest to the main base
    local MassExtractorUnitList = false
    local unitType, unitTech = StructureTypeCheck(aiBrain, unitBp)
    local BasePosition = aiBrain.BuilderManagers['MAIN'].Position
    local DistanceToBase = nil
    local LowestDistanceToBase = nil
    local UnitPos

    if unitType == 'MASSEXTRACTION' and unitTech == 'TECH1' then
        MassExtractorUnitList = GetListOfUnits(aiBrain, categories.MASSEXTRACTION * (categories.TECH1), false, false)
    elseif unitType == 'MASSEXTRACTION' and unitTech == 'TECH2' then
        MassExtractorUnitList = GetListOfUnits(aiBrain, categories.MASSEXTRACTION * (categories.TECH2), false, false)
    end

    for k, v in MassExtractorUnitList do
        local TempID
        -- Check if we don't want to upgrade this unit
        if not v
            or v.Dead
            or v:BeenDestroyed()
            or v:IsPaused()
            or not EntityCategoryContains(ParseEntityCategory(unitTech), v)
            or v:GetFractionComplete() < 1
        then
            -- Skip this loop and continue with the next array
            continue
        end
        if v:IsUnitState('Upgrading') then
        -- skip upgrading buildings
            continue
        end
        -- Check for the nearest distance from mainbase
        UnitPos = v:GetPosition()
        DistanceToBase = VDist2Sq(BasePosition[1] or 0, BasePosition[3] or 0, UnitPos[1] or 0, UnitPos[3] or 0)
        if DistanceToBase < 2500 then
            --LOG('Mainbase extractor set true')
            v.MAINBASE = true
        end
        if (not LowestDistanceToBase and v.InitialDelay == false) or (DistanceToBase < LowestDistanceToBase and v.InitialDelay == false) then
            -- see if we can find a upgrade
            LowestDistanceToBase = DistanceToBase
            lowestUnitPos = UnitPos
        end
    end
    if unit:GetPosition() == lowestUnitPos then
        --LOG('Extractor is closest to base')
        return true
    else
        --LOG('Extractor is not closest to base')
        return false
    end
end

-- These 3 functions are from Uveso for CDR enhancements, modified slightly.
function CDREnhancementsRNG(aiBrain, cdr)
    local gameTime = GetGameTimeSeconds()
    if gameTime < 420 then
        WaitTicks(2)
        return
    end
    
    local cdrPos = cdr:GetPosition()
    local distSqAway = 2209
    local loc = cdr.CDRHome
    local upgradeMode = false
    if gameTime < 1500 then
        upgradeMode = 'Combat'
    else
        upgradeMode = 'Engineering'
    end
    --LOG('Enhancement Thread run at '..gameTime)
    if (cdr:IsIdleState() and VDist2Sq(cdrPos[1], cdrPos[3], loc[1], loc[3]) < distSqAway) or (cdr.GunUpgradeRequired and VDist2Sq(cdrPos[1], cdrPos[3], loc[1], loc[3]) < distSqAway) then
        --LOG('ACU within base range for enhancements')
        if (GetEconomyStoredRatio(aiBrain, 'MASS') > 0.05 and GetEconomyStoredRatio(aiBrain, 'ENERGY') > 0.95) or cdr.GunUpgradeRequired then
            --LOG('Economy good for ACU upgrade')
            cdr.GoingHome = false
            cdr.Combat = false
            cdr.Upgrading = false

            local ACUEnhancements = {
                -- UEF
                ['uel0001'] = {Combat = {'HeavyAntiMatterCannon', 'DamageStabilization', 'Shield'},
                            Engineering = {'AdvancedEngineering', 'Shield', 'T3Engineering', 'ResourceAllocation'},
                            },
                -- Aeon
                ['ual0001'] = {Combat = {'HeatSink', 'CrysalisBeam', 'Shield', 'ShieldHeavy'},
                            Engineering = {'AdvancedEngineering', 'Shield', 'T3Engineering','ShieldHeavy'}
                            },
                -- Cybran
                ['url0001'] = {Combat = {'CoolingUpgrade', 'StealthGenerator', 'MicrowaveLaserGenerator', 'CloakingGenerator'},
                            Engineering = {'AdvancedEngineering', 'StealthGenerator', 'T3Engineering','CloakingGenerator'}
                            },
                -- Seraphim
                ['xsl0001'] = {Combat = {'RateOfFire', 'DamageStabilization', 'BlastAttack', 'DamageStabilizationAdvanced'},
                            Engineering = {'AdvancedEngineering', 'T3Engineering',}
                            },
                -- Nomads
                ['xnl0001'] = {Combat = {'Capacitor', 'GunUpgrade', 'MovementSpeedIncrease', 'DoubleGuns'},},
            }
            local CRDBlueprint = cdr:GetBlueprint()
            --LOG('* RNGAI: BlueprintId '..repr(CRDBlueprint.BlueprintId))
            local ACUUpgradeList = ACUEnhancements[CRDBlueprint.BlueprintId][upgradeMode]
            --LOG('* RNGAI: ACUUpgradeList '..repr(ACUUpgradeList))
            local NextEnhancement = false
            local HaveEcoForEnhancement = false
            for _,enhancement in ACUUpgradeList or {} do
                local wantedEnhancementBP = CRDBlueprint.Enhancements[enhancement]
                local enhancementName = enhancement
                --LOG('* RNGAI: wantedEnhancementBP '..repr(wantedEnhancementBP))
                if not wantedEnhancementBP then
                    SPEW('* RNGAI: no enhancement found for  = '..repr(enhancement))
                elseif cdr:HasEnhancement(enhancement) then
                    NextEnhancement = false
                    --LOG('* RNGAI: * BuildACUEnhancements: Enhancement is already installed: '..enhancement)
                elseif EnhancementEcoCheckRNG(aiBrain, cdr, wantedEnhancementBP, enhancementName) then
                    --LOG('* RNGAI: * BuildACUEnhancements: Eco is good for '..enhancement)
                    if not NextEnhancement then
                        NextEnhancement = enhancement
                        HaveEcoForEnhancement = true
                        --LOG('* RNGAI: *** Set as Enhancememnt: '..NextEnhancement)
                    end
                else
                    --LOG('* RNGAI: * BuildACUEnhancements: Eco is bad for '..enhancement)
                    if not NextEnhancement then
                        NextEnhancement = enhancement
                        HaveEcoForEnhancement = false
                        -- if we don't have the eco for this ugrade, stop the search
                        --LOG('* RNGAI: canceled search. no eco available')
                        break
                    end
                end
            end
            if NextEnhancement and HaveEcoForEnhancement then
                --LOG('* RNGAI: * BuildACUEnhancements Building '..NextEnhancement)
                if BuildEnhancement(aiBrain, cdr, NextEnhancement) then
                    --LOG('* RNGAI: * BuildACUEnhancements returned true'..NextEnhancement)
                    return true
                else
                    --LOG('* RNGAI: * BuildACUEnhancements returned false'..NextEnhancement)
                    return false
                end
            end
            return false
        end
    end
end

EnhancementEcoCheckRNG = function(aiBrain,cdr,enhancement, enhancementName)

    local BuildRate = cdr:GetBuildRate()
    local priorityUpgrade = false
    local priorityUpgrades = {
        'HeavyAntiMatterCannon',
        'HeatSink',
        'CrysalisBeam',
        'CoolingUpgrade',
        'RateOfFire'
    }
    if not enhancement.BuildTime then
        WARN('* RNGAI: EcoGoodForUpgrade: Enhancement has no buildtime: '..repr(enhancement))
    end
    --LOG('Enhancement EcoCheck for '..enhancementName)
    for k, v in priorityUpgrades do
        if enhancementName == v then
            priorityUpgrade = true
            --LOG('Priority Upgrade is true')
            break
        end
    end
    --LOG('* RNGAI: cdr:GetBuildRate() '..BuildRate..'')
    local drainMass = (BuildRate / enhancement.BuildTime) * enhancement.BuildCostMass
    local drainEnergy = (BuildRate / enhancement.BuildTime) * enhancement.BuildCostEnergy
    --LOG('* RNGAI: drain: m'..drainMass..'  e'..drainEnergy..'')
    --LOG('* RNGAI: Pump: m'..math.floor(aiBrain:GetEconomyTrend('MASS')*10)..'  e'..math.floor(aiBrain:GetEconomyTrend('ENERGY')*10)..'')
    if priorityUpgrade and cdr.GunUpgradeRequired then
        if (GetGameTimeSeconds() < 1500) and (GetEconomyIncome(aiBrain, 'ENERGY') > 40)
         and (GetEconomyIncome(aiBrain, 'MASS') > 1.0) then
            --LOG('* RNGAI: Gun Upgrade Eco Check True')
            return true
        end
    elseif aiBrain:GetEconomyTrend('MASS')*10 >= drainMass and aiBrain:GetEconomyTrend('ENERGY')*10 >= drainEnergy
    and aiBrain:GetEconomyStoredRatio('MASS') > 0.05 and aiBrain:GetEconomyStoredRatio('ENERGY') > 0.95 then
        return true
    end
    --LOG('* RNGAI: Upgrade Eco Check False')
    return false
end

BuildEnhancement = function(aiBrain,cdr,enhancement)
    --LOG('* RNGAI: * BuildEnhancement '..enhancement)
    local priorityUpgrades = {
        'HeavyAntiMatterCannon',
        'HeatSink',
        'CrysalisBeam',
        'CoolingUpgrade',
        'RateOfFire'
    }
    cdr.Upgrading = true
    IssueStop({cdr})
    IssueClearCommands({cdr})
    
    if not cdr:HasEnhancement(enhancement) then
        
        local tempEnhanceBp = cdr:GetBlueprint().Enhancements[enhancement]
        local unitEnhancements = import('/lua/enhancementcommon.lua').GetEnhancements(cdr.EntityId)
        -- Do we have already a enhancment in this slot ?
        if unitEnhancements[tempEnhanceBp.Slot] and unitEnhancements[tempEnhanceBp.Slot] ~= tempEnhanceBp.Prerequisite then
            -- remove the enhancement
            --LOG('* RNGAI: * Found enhancement ['..unitEnhancements[tempEnhanceBp.Slot]..'] in Slot ['..tempEnhanceBp.Slot..']. - Removing...')
            local order = { TaskName = "EnhanceTask", Enhancement = unitEnhancements[tempEnhanceBp.Slot]..'Remove' }
            IssueScript({cdr}, order)
            coroutine.yield(10)
        end
        --LOG('* RNGAI: * BuildEnhancement: '..aiBrain.Nickname..' IssueScript: '..enhancement)
        if cdr.Upgrading then
            --LOG('cdr.Upgrading is set to true')
        end
        local order = { TaskName = "EnhanceTask", Enhancement = enhancement }
        IssueScript({cdr}, order)
    end
    while not cdr.Dead and not cdr:HasEnhancement(enhancement) do
        if cdr:GetHealthPercent() < 0.40 then
            --LOG('* RNGAI: * BuildEnhancement: '..platoon:GetBrain().Nickname..' Emergency!!! low health, canceling Enhancement '..enhancement)
            IssueStop({cdr})
            IssueClearCommands({cdr})
            cdr.Upgrading = false
            return false
        end
        coroutine.yield(10)
    end
    --LOG('* RNGAI: * BuildEnhancement: '..platoon:GetBrain().Nickname..' Upgrade finished '..enhancement)
    for k, v in priorityUpgrades do
        if enhancement == v then
            cdr.GunUpgradeRequired = false
            cdr.GunUpgradePresent = true
            --LOG('Gun upgrade completed, falgs set')
            break
        end
    end
    cdr.Upgrading = false
    return true
end

PlatoonRetreat = function (platoon)
    local aiBrain = platoon:GetBrain()
    local platoonThreatHigh = false
    local homeBaseLocation = aiBrain.BuilderManagers['MAIN'].Position
    --LOG('Start Retreat Behavior')
    --LOG('Home base location is '..repr(homeBaseLocation))
    while aiBrain:PlatoonExists(platoon) do
        local platoonPos = GetPlatoonPosition(platoon)
        if VDist2Sq(platoonPos[1], platoonPos[3], homeBaseLocation[1], homeBaseLocation[3]) > 14400 then
            --LOG('Retreat loop Behavior')
            local selfthreatAroundplatoon = 0
            local positionUnits = GetUnitsAroundPoint(aiBrain, categories.MOBILE * (categories.LAND + categories.COMMAND) - categories.SCOUT - categories.ENGINEER, platoonPos, 50, 'Ally')
            local bp
            for _,v in positionUnits do
                if not v.Dead and EntityCategoryContains(categories.COMMAND, v) then
                    selfthreatAroundplatoon = selfthreatAroundplatoon + 30
                elseif not v.Dead then
                    bp = __blueprints[v.UnitId].Defense
                    selfthreatAroundplatoon = selfthreatAroundplatoon + bp.SurfaceThreatLevel
                end
            end
            --LOG('Platoon Threat is '..selfthreatAroundplatoon)
            WaitTicks(3)
            local enemyUnits = GetUnitsAroundPoint(aiBrain, (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * (categories.LAND + categories.AIR + categories.COMMAND) - categories.SCOUT - categories.ENGINEER), platoonPos, 60, 'Enemy')
            local enemythreatAroundplatoon = 0
            for k,v in enemyUnits do
                if not v.Dead and EntityCategoryContains(categories.COMMAND, v) then
                    enemythreatAroundplatoon = enemythreatAroundplatoon + 30
                elseif not v.Dead then
                    --LOG('Enemt Unit ID is '..v.UnitId)
                    bp = __blueprints[v.UnitId].Defense
                    --LOG(repr(__blueprints[v.UnitId].Defense))
                    if bp.SurfaceThreatLevel ~= nil then
                        enemythreatAroundplatoon = enemythreatAroundplatoon + (bp.SurfaceThreatLevel * 1.2)
                        if enemythreatAroundplatoon > selfthreatAroundplatoon then
                            platoonThreatHigh = true
                            break
                        end
                    end
                end
            end
            --LOG('Enemy Platoon Threat is '..enemythreatAroundplatoon)
            WaitTicks(3)
            if platoonThreatHigh then
                --LOG('PlatoonThreatHigh is true')
                local platoonList = aiBrain:GetPlatoonsList()
                local remotePlatoonDistance = 100000
                local remotePlatoonLocation = {}
                local selfPlatoonPos = {}
                local remotePlatoon
                for k, v in platoonList do
                    if table.getn(v) > 3 then
                        local remotePlatoonPos = GetPlatoonPosition(v)
                        selfPlatoonPos = GetPlatoonPosition(platoon)
                        local platDistance = VDist2Sq(remotePlatoonPos[1], remotePlatoonPos[2], selfPlatoonPos[1], selfPlatoonPos[3])
                        --LOG('Remote Platoon distance is '..remotePlatoonDistance)
                        if platDistance < remotePlatoonDistance then
                            remotePlatoonDistance = platDistance
                            remotePlatoonLocation = remotePlatoonPos
                            remotePlatoon = v
                        end
                    end
                end
                if remotePlatoonDistance < 40000 then
                    --LOG('Best Retreat Platoon Position '..repr(remotePlatoonLocation))
                    --LOG('Best Retreat Platoon Distance '..remotePlatoonDistance)
                    local path, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, platoon.MovementLayer, selfPlatoonPos, remotePlatoonLocation, 100 , 200)
                    if path then
                        local position = GetPlatoonPosition(platoon)
                        if VDist2Sq(position[1], position[3], remotePlatoonLocation[1], remotePlatoonLocation[3]) > 262144 then
                            return platoon:ReturnToBaseAIRNG()
                        end
                        local pathLength = table.getn(path)
                        for i=1, pathLength - 1 do
                            --LOG('* AI-RNG: * PlatoonRetreat: moving to destination. i: '..i..' coords '..repr(path[i]))
                            platoon:MoveToLocation(path[i], false)
                            --LOG('* AI-RNG: * PlatoonRetreat: moving to Waypoint')
                            local PlatoonPosition
                            local remotePlatoonPos
                            local remotePlatoonDist
                            local Lastdist
                            local dist
                            local Stuck = 0
                            PlatoonPosition = GetPlatoonPosition(platoon) or nil
                            remotePlatoonPos = GetPlatoonPosition(remotePlatoon) or nil
                            remotePlatoonDist = VDist2Sq(PlatoonPosition[1], PlatoonPosition[3], remotePlatoonPos[1], remotePlatoonPos[3])
                            --LOG('Current Distance to destination platoon '..remotePlatoonDist)
                            if not PlatoonExists(aiBrain, remotePlatoon) then
                                --LOG('Remote Platoon No Longer Exist, RTB')
                                return platoon:ReturnToBaseAIRNG()
                            end
                            if remotePlatoonDist < 2500 then
                                -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                --LOG('We Should be at the other platoons position and about to merge')

                                platoon:Stop()
                                local planName = remotePlatoon:GetPlan()
                                --LOG('Trigger merge with '..table.getn(platoon:GetPlatoonUnits())..' units into a platoon with '..table.getn(remotePlatoon:GetPlatoonUnits())..' Units')
                                platoon:MergeWithNearbyPlatoonsRNG(planName, 50, 30)
                                break
                            end
                            while PlatoonExists(aiBrain, platoon) do
                                PlatoonPosition = GetPlatoonPosition(platoon) or nil
                                if not PlatoonPosition then break end
                                dist = VDist2Sq(path[i][1], path[i][3], PlatoonPosition[1], PlatoonPosition[3])
                                -- are we closer then 15 units from the next marker ? Then break and move to the next marker
                                if (dist < 400) then
                                    -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                    platoon:Stop()
                                    break
                                end
                                -- Do we move ?
                                if Lastdist ~= dist then
                                    Stuck = 0
                                    Lastdist = dist
                                -- No, we are not moving, wait 100 ticks then break and use the next weaypoint
                                else
                                    Stuck = Stuck + 1
                                    if Stuck > 15 then
                                        --LOG('* AI-RNG: * PlatoonRetreat: Stucked while moving to Waypoint. Stuck='..Stuck..' - '..repr(path[i]))
                                        platoon:Stop()
                                        break
                                    end
                                end
                                WaitTicks(15)
                            end
                        end
                    else
                        --LOG('No Path continue')
                        continue
                    end
                else
                    --LOG('No Platoons within range, return to base')
                    return platoon:ReturnToBaseAIRNG()
                end
            end
        end
        WaitTicks(50)
    end
end

TargetControlThread = function (platoon)
    local aiBrain = platoon:GetBrain()
    
    local TargetControlTemplates = {
        structureMode = {
                        'EXPERIMENTAL',
                        'STRUCTURE DEFENSE',
                        'MOBILE LAND INDIRECTFIRE',
                        'MOBILE LAND DIRECTFIRE',
                        'MASSEXTRACTION',
                        'ENERGYPRODUCTION',
                        'COMMAND',
                        'MASSFABRICATION',
                        'SHIELD',
                        'STRUCTURE',
                        'ALLUNITS',
                    },

        antiAirMode = {
                        'EXPERIMENTAL',
                        'MOBILE LAND ANTIAIR',
                        'STRUCTURE ANTIAIR',
                        'MOBILE LAND INDIRECTFIRE',
                        'MOBILE LAND DIRECTFIRE',
                        'STRUCTURE DEFENSE',
                        'MASSEXTRACTION',
                        'ENERGYPRODUCTION',
                        'COMMAND',
                        'MASSFABRICATION',
                        'SHIELD',
                        'STRUCTURE',
                        'ALLUNITS',
                    },

        antiLandMode = {
                        'EXPERIMENTAL',
                        'MOBILE LAND DIRECTFIRE',
                        'MOBILE LAND INDIRECTFIRE',
                        'STRUCTURE DEFENSE',
                        'MASSEXTRACTION',
                        'ENERGYPRODUCTION',
                        'COMMAND',
                        'MASSFABRICATION',
                        'SHIELD',
                        'STRUCTURE',
                        'ALLUNITS',
                    },
                }
    while aiBrain:PlatoonExists(platoon) do
        if aiBrain.EnemyIntel.EnemyThreatCurrent.DefenseAir > 20 then
            local artillerySquad = platoon:GetSquadUnits('Artillery')
            platoon:SetPrioritizedTargetList('Artillery', TargetControlTemplates.structureMode)
        end
        --LOG('TargetControlThread')
        WaitTicks(30)
    end
end

function FatBoyBehaviorRNG(self)
    local aiBrain = self:GetBrain()
    AssignExperimentalPriorities(self)

    local unit = GetExperimentalUnit(self)
    local targetUnit = false
    local lastBase = false
    

    local mainWeapon = unit:GetWeapon(1)
    unit.MaxWeaponRange = mainWeapon:GetBlueprint().MaxRadius
    unit.smartPos = {0,0,0}
    unit.Platoons = unit.Platoons or {}
    if mainWeapon.BallisticArc == 'RULEUBA_LowArc' then
        unit.WeaponArc = 'low'
    elseif mainWeapon.BallisticArc == 'RULEUBA_HighArc' then
        unit.WeaponArc = 'high'
    else
        unit.WeaponArc = 'none'
    end
    if not unit.Guards or not aiBrain:PlatoonExists(unit.Guards) then
        unit.Guards = aiBrain:MakePlatoon('Guards', '')
    end

    -- Find target loop
    while unit and not unit.Dead do
        local guards = unit.Guards
        local inWater = InWaterCheck(self)
        if guards and (table.getn(guards:GetPlatoonUnits()) < 4) and not inWater then
            FatBoyGuardsRNG(self)
        end
        targetUnit, lastBase = FindExperimentalTarget(self)
        if targetUnit then
            IssueClearCommands({unit})
            local targetPos = targetUnit:GetPosition()
            if inWater then
                IssueMove({unit}, targetPos)
            else
                IssueAttack({unit}, targetUnit)
            end

            -- Wait to get in range
            local pos = unit:GetPosition()
            while VDist2(pos[1], pos[3], lastBase.Position[1], lastBase.Position[3]) > unit.MaxWeaponRange + 10
                and not unit.Dead do
                    WaitTicks(50)
                    if guards and (table.getn(guards:GetPlatoonUnits()) < 4) and not inWater then
                        FatBoyGuardsRNG(self)
                    end
                    inWater = InWaterCheck(self)
                    --unit:SetCustomName('Moving to target')
                    if inWater then
                        WaitTicks(10)
                        if unit.Guards then
                            unit.Guards:ReturnToBaseAIRNG()
                        end
                    end
                    
                    if not inWater then
                        --LOG('In water is false')
                        local expPosition = unit:GetPosition()
                        local enemyUnitCount = aiBrain:GetNumUnitsAroundPoint(categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, expPosition, unit.MaxWeaponRange, 'Enemy')
                        if enemyUnitCount > 0 then
                            target = self:FindClosestUnit('attack', 'Enemy', true, categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL)
                            while unit and not unit.Dead do
                                if target and not target.Dead then
                                    IssueClearCommands({unit})
                                    targetPosition = target:GetPosition()
                                    if unit.Dead then continue end
                                    if not unit.MaxWeaponRange then
                                        continue
                                    end
                                    unitPos = unit:GetPosition()
                                    alpha = math.atan2 (targetPosition[3] - unitPos[3] ,targetPosition[1] - unitPos[1])
                                    x = targetPosition[1] - math.cos(alpha) * (unit.MaxWeaponRange - 15)
                                    y = targetPosition[3] - math.sin(alpha) * (unit.MaxWeaponRange - 15)
                                    smartPos = { x, GetTerrainHeight( x, y), y }
                                    -- check if the move position is new or target has moved
                                    if VDist2( smartPos[1], smartPos[3], unit.smartPos[1], unit.smartPos[3] ) > 0.7 or unit.TargetPos ~= targetPosition then
                                        -- clear move commands if we have queued more than 4
                                        if table.getn(unit:GetCommandQueue()) > 2 then
                                            IssueClearCommands({unit})
                                            coroutine.yield(3)
                                        end
                                        -- if our target is dead, jump out of the "for _, unit in self:GetPlatoonUnits() do" loop
                                        IssueMove({unit}, smartPos )
                                        if target.Dead then break end
                                        IssueAttack({unit}, target)
                                        --unit:SetCustomName('Fight micro moving')
                                        unit.smartPos = smartPos
                                        unit.TargetPos = targetPosition
                                    -- in case we don't move, check if we can fire at the target
                                    else
                                        local dist = VDist2( unit.smartPos[1], unit.smartPos[3], unit.TargetPos[1], unit.TargetPos[3] )
                                        if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, unit.WeaponArc) then
                                            --unit:SetCustomName('Fight micro WEAPON BLOCKED!!! ['..repr(target.UnitId)..'] dist: '..dist)
                                            IssueMove({unit}, targetPosition )
                                        else
                                            --unit:SetCustomName('Fight micro SHOOTING ['..repr(target.UnitId)..'] dist: '..dist)
                                        end
                                    end
                                else
                                    break
                                end
                            WaitTicks(20)
                            end
                        else
                            --LOG('In water is false')
                            IssueClearCommands({unit})
                            IssueMove({unit}, {lastBase.Position[1], 0 ,lastBase.Position[3]})
                            --LOG('Taret Position is'..repr(targetPos))
                            WaitTicks(40)
                        end
                    else
                        --LOG('In water is true')
                        IssueClearCommands({unit})
                        IssueMove({unit}, {lastBase.Position[1], 0 ,lastBase.Position[3]})
                        --LOG('Taret Position is'..repr(targetPos))
                        WaitTicks(40)
                    end
            end

            IssueClearCommands({unit})

            -- Send our homies to wreck this base
            local goodList = {}
            for _, platoon in unit.Platoons do
                local platoonUnits = false

                if aiBrain:PlatoonExists(platoon) then
                    platoonUnits = platoon:GetPlatoonUnits()
                end

                if platoonUnits and table.getn(platoonUnits) > 0 then
                    table.insert(goodList, platoon)
                end
            end

            unit.Platoons = goodList
            for _, platoon in goodList do
                platoon:ForkAIThread(FatboyChildBehavior, unit, lastBase)
            end

            -- Setup shop outside this guy's base
            while not unit.Dead and WreckBase(self, lastBase) do
                -- Build stuff if we haven't hit the unit cap.
                FatBoyBuildCheckRNG(self)

                -- Once we have 20 units, form them into a platoon and send them to attack the base we're attacking!
                if unit.NewPlatoon and table.getn(unit.NewPlatoon:GetPlatoonUnits()) >= 8 then
                    unit.NewPlatoon:ForkAIThread(FatboyChildBehavior, unit, lastBase)

                    table.insert(unit.Platoons, unit.NewPlatoon)
                    unit.NewPlatoon = nil
                end
                WaitSeconds(1)
            end
        end
        WaitSeconds(1)
    end
end

function FatBoyBuildCheckRNG(self)
    local aiBrain = self:GetBrain()
    local experimental = GetExperimentalUnit(self)

    -- Randomly build T3 MMLs, siege bots, and percivals.
    local buildUnits = {'uel0303', 'xel0305', 'xel0306', 'delk002'}
    local unitToBuild = buildUnits[Random(1, table.getn(buildUnits))]

    aiBrain:BuildUnit(experimental, unitToBuild, 1)
    WaitTicks(1)

    local unitBeingBuilt = false
    repeat
        unitBeingBuilt = unitBeingBuilt or experimental.UnitBeingBuilt
        WaitSeconds(1)
    until experimental.Dead or unitBeingBuilt or aiBrain:GetArmyStat("UnitCap_MaxCap", 0.0).Value - aiBrain:GetArmyStat("UnitCap_Current", 0.0).Value < 10

    repeat
        WaitSeconds(3)
    until experimental.Dead or experimental:IsIdleState() or aiBrain:GetArmyStat("UnitCap_MaxCap", 0.0).Value - aiBrain:GetArmyStat("UnitCap_Current", 0.0).Value < 10

    if not experimental.NewPlatoon or not aiBrain:PlatoonExists(experimental.NewPlatoon) then
        experimental.NewPlatoon = aiBrain:MakePlatoon('', '')
    end

    if unitBeingBuilt and not unitBeingBuilt.Dead then
        aiBrain:AssignUnitsToPlatoon(experimental.NewPlatoon, {unitBeingBuilt}, 'Attack', 'NoFormation')
        IssueClearCommands({unitBeingBuilt})
        IssueGuard({unitBeingBuilt}, experimental)
    end
end

function FatBoyGuardsRNG(self)
    local aiBrain = self:GetBrain()
    local experimental = GetExperimentalUnit(self)

    -- Randomly build T3 MMLs, siege bots, and percivals.
    local buildUnits = {'uel0205', 'delk002'}
    local unitToBuild = buildUnits[Random(1, table.getn(buildUnits))]

    aiBrain:BuildUnit(experimental, unitToBuild, 1)
    WaitTicks(1)

    local unitBeingBuilt = false
    repeat
        unitBeingBuilt = unitBeingBuilt or experimental.UnitBeingBuilt
        WaitSeconds(1)
    until experimental.Dead or unitBeingBuilt or aiBrain:GetArmyStat("UnitCap_MaxCap", 0.0).Value - aiBrain:GetArmyStat("UnitCap_Current", 0.0).Value < 10

    repeat
        WaitSeconds(3)
    until experimental.Dead or experimental:IsIdleState() or aiBrain:GetArmyStat("UnitCap_MaxCap", 0.0).Value - aiBrain:GetArmyStat("UnitCap_Current", 0.0).Value < 10

    if not experimental.Guards or not aiBrain:PlatoonExists(experimental.Guards) then
        experimental.Guards = aiBrain:MakePlatoon('Guards', '')
    end

    if unitBeingBuilt and not unitBeingBuilt.Dead then
        aiBrain:AssignUnitsToPlatoon(experimental.Guards, {unitBeingBuilt}, 'guard', 'NoFormation')
        IssueClearCommands({unitBeingBuilt})
        IssueGuard({unitBeingBuilt}, experimental)
    end
end

function BehemothBehaviorRNG(self, id)
    AssignExperimentalPriorities(self)

    local aiBrain = self:GetBrain()
    local experimental = GetExperimentalUnit(self)
    local targetUnit = false
    local lastBase = false
    local airUnit = EntityCategoryContains(categories.AIR, experimental)
    -- Don't forget we have the unit ID for specialized behaviors.
    -- Find target loop
    while experimental and not experimental.Dead do
        if lastBase then
            targetUnit, lastBase = WreckBase(self, lastBase)
        elseif not lastBase then
            targetUnit, lastBase = FindExperimentalTarget(self)
        end

        if targetUnit then
            IssueClearCommands({experimental})
            IssueAttack({experimental}, targetUnit)
        end

        -- Walk to and kill target loop
        while not experimental.Dead and not experimental:IsIdleState() do
            local unitPos = self:GetPlatoonPosition()
            local targetPos = targetUnit:GetPosition()
            local nearCommander = CommanderOverrideCheck(self)
            if nearCommander and nearCommander ~= targetUnit then
                IssueClearCommands({experimental})
                IssueAttack({experimental}, nearCommander)
                targetUnit = nearCommander
            end

            -- If no target jump out
            if not targetUnit then break end
            if aiBrain:CheckBlockingTerrain(unitPos, targetPos, 'none') then
                --LOG('Experimental WEAPON BLOCKED, moving to better position')
                IssueClearCommands({experimental})
                IssueMove({experimental}, targetPos )
                WaitTicks(50)
            end

            -- Check if we or the target are under a shield
            local closestBlockingShield = false
            if not airUnit then
                closestBlockingShield = GetClosestShieldProtectingTarget(experimental, experimental)
            end
            closestBlockingShield = closestBlockingShield or GetClosestShieldProtectingTarget(experimental, targetUnit)

            -- Kill shields loop
            while closestBlockingShield do
                IssueClearCommands({experimental})
                local shieldPosition = closestBlockingShield:GetPosition()
                IssueMove({experimental}, shieldPosition)
                WaitTicks(30)
                IssueAttack({experimental}, closestBlockingShield)

                -- Wait for shield to die loop
                while not closestBlockingShield.Dead and not experimental.Dead do
                    WaitTicks(20)
                    IssueMove({experimental}, shieldPosition)
                    WaitTicks(30)
                    IssueAttack({experimental}, closestBlockingShield)
                end

                closestBlockingShield = false
                if not airUnit then
                    closestBlockingShield = GetClosestShieldProtectingTarget(experimental, experimental)
                end
                closestBlockingShield = closestBlockingShield or GetClosestShieldProtectingTarget(experimental, targetUnit)
                WaitTicks(1)
            end
            WaitTicks(10)
        end
        WaitTicks(10)
    end
end

