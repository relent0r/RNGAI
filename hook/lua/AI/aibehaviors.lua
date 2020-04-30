WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] * RNGAI: offset aibehaviors.lua' )

--local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetMOARadii()
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local GetEconomyStored = moho.aibrain_methods.GetEconomyStored
local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local GetEconomyTrend = moho.aibrain_methods.GetEconomyTrend
local GetEconomyIncome = moho.aibrain_methods.GetEconomyIncome
local GetEconomyRequested = moho.aibrain_methods.GetEconomyRequested
local MakePlatoon = moho.aibrain_methods.MakePlatoon
local AssignUnitsToPlatoon = moho.aibrain_methods.AssignUnitsToPlatoon
local PlatoonExists = moho.aibrain_methods.PlatoonExists
local GetMostRestrictiveLayer = import('/lua/ai/aiattackutilities.lua').GetMostRestrictiveLayer

function CommanderBehaviorRNG(platoon)
    for _, v in platoon:GetPlatoonUnits() do
        if not v.Dead and not v.CommanderThread then
            v.CommanderThread = v:ForkThread(CommanderThreadRNG, platoon)
        end
    end
end

function CommanderThreadRNG(cdr, platoon)
    --LOG('* AI-RNG: Starting CommanderThreadRNG')
    local aiBrain = cdr:GetAIBrain()
    aiBrain:BuildScoutLocationsRNG()
    cdr.UnitBeingBuiltBehavior = false
    -- Added to ensure we know the start locations (thanks to Sorian).
    SetCDRHome(cdr, platoon)

    while not cdr.Dead do
        -- Overcharge
        if not cdr.Dead then 
            CDROverChargeRNG(aiBrain, cdr) 
        end
        WaitTicks(1)

        -- Go back to base
        if not cdr.Dead and aiBrain.ACUSupport.ReturnHome then 
            CDRReturnHomeRNG(aiBrain, cdr) 
        end
        WaitTicks(1)
        
        if not cdr.Dead then 
            CDRUnitCompletion(aiBrain, cdr) 
        end
        WaitTicks(1)
        if not cdr.Dead then
            CDRHideBehaviorRNG(aiBrain, cdr)
        end
        WaitTicks(1)

        -- Call platoon resume building deal...
        if not cdr.Dead and cdr:IsIdleState() and not cdr.GoingHome and not cdr:IsUnitState("Moving")
        and not cdr:IsUnitState("Building") and not cdr:IsUnitState("Guarding")
        and not cdr:IsUnitState("Attacking") and not cdr:IsUnitState("Repairing")
        and not cdr:IsUnitState("Upgrading") and not cdr:IsUnitState("Enhancing") 
        and not cdr:IsUnitState('BlockCommandQueue') and not cdr.UnitBeingBuiltBehavior then
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
        WaitTicks(1)
    end
end

function CDROverChargeRNG(aiBrain, cdr)
    local weapBPs = cdr:GetBlueprint().Weapon
    local overCharge = {}
    local weapon = {}
    local factionIndex = aiBrain:GetFactionIndex()
    
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
            weapon.Range = 30 - 3
        end
    elseif factionIndex == 2 then
        if cdr:HasEnhancement('CrysalisBeam') then
            weapon.Range = 35 - 3
        end
    elseif factionIndex == 3 then
        if cdr:HasEnhancement('CoolingUpgrade') then
            weapon.Range = 30 - 3
        end
    elseif factionIndex == 4 then
        if cdr:HasEnhancement('RateOfFire') then
            weapon.Range = 30 - 3
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
    local numUnits = aiBrain:GetNumUnitsAroundPoint(categories.LAND - categories.SCOUT, cdrPos, (maxRadius), 'Enemy')
    local acuUnits = aiBrain:GetNumUnitsAroundPoint(categories.LAND * categories.COMMAND - categories.SCOUT, cdrPos, (maxRadius), 'Enemy')
    local distressLoc = aiBrain:BaseMonitorDistressLocationRNG(cdrPos)
    local overCharging = false

    -- Don't move if upgrading
    if cdr:IsUnitState("Upgrading") or cdr:IsUnitState("Enhancing") then
        return
    end

    if Utilities.XZDistanceTwoVectors(cdrPos, cdr:GetPosition()) > maxRadius then
        return
    end

    if numUnits > 0 or (not cdr.DistressCall and distressLoc and Utilities.XZDistanceTwoVectors(distressLoc, cdrPos) < distressRange) then
        --LOG('Num of units greater than zero or base distress')
        if cdr.UnitBeingBuilt then
            --LOG('Unit being built is true, assign to cdr.UnitBeingBuiltBehavior')
            cdr.UnitBeingBuiltBehavior = cdr.UnitBeingBuilt
        end
        if cdr.PlatoonHandle and cdr.PlatoonHandle != aiBrain.ArmyPool then
            if PlatoonExists(aiBrain, cdr.PlatoonHandle) then
                --LOG("*AI DEBUG "..aiBrain.Nickname.." CDR disbands "..cdr.PlatoonHandle.BuilderName)
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
                    --LOG('No target found in sweep increasing search radius')
                until target or searchRadius >= maxRadius

                if target then
                    --LOG('Target Found')
                    local targetPos = target:GetPosition()
                    local cdrPos = cdr:GetPosition()
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
                        local movePos = RUtils.lerpy(cdrPos, targetPos, {targetDistance, targetDistance - weapon.Range})
                        cdr.PlatoonHandle:MoveToLocation(movePos, false)
                        if target and not target.Dead and not target:BeenDestroyed() then
                            IssueOverCharge({cdr}, target)
                        end
                    elseif target and not target.Dead and not target:BeenDestroyed() then -- Commander attacks even if not enough energy for overcharge
                        IssueClearCommands({cdr})
                        local movePos = RUtils.lerpy(cdrPos, targetPos, {targetDistance, targetDistance - weapon.Range})
                        local cdrNewPos = {}
                        --LOG('* AI-RNG: Move Position is'..repr(movePos))
                        --LOG('* AI-RNG: Moving to movePos to attack')
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

            if aiBrain:GetNumUnitsAroundPoint(categories.LAND - categories.SCOUT, cdrPos, maxRadius, 'Enemy') <= 0
                and (not distressLoc or Utilities.XZDistanceTwoVectors(distressLoc, cdrPos) > distressRange) then
                continueFighting = false
            end
            -- If com is down to yellow then dont keep fighting
            if (cdr:GetHealthPercent() < 0.75) and Utilities.XZDistanceTwoVectors(cdr.CDRHome, cdr:GetPosition()) > 30 then
                continueFighting = false
            end
            local enenyUnitLimit = aiBrain:GetNumUnitsAroundPoint(categories.LAND - categories.SCOUT, cdrPos, 70, 'Enemy')
            if enenyUnitLimit > 15 then
                --LOG('* AI-RNG: Enemy unit count too high cease fighting, numUnits :'..enenyUnitLimit)
                continueFighting = false
                
            end
            --[[
            if not continueFighting then
                LOG('Continue Fighting was set to false')
            else
                LOG('Continue Fighting is still true')
            end]]
            if not aiBrain:PlatoonExists(plat) then
                LOG('* AI-RNG: CDRAttack platoon no longer exist, something disbanded it')
            end
        until not continueFighting or not aiBrain:PlatoonExists(plat)
        cdr.Combat = false
        aiBrain.ACUSupport.ReturnHome = true
        aiBrain.ACUSupport.TargetPosition = false
        aiBrain.ACUSupport.Supported = false
        --LOG('* AI-RNG: ACUSupport.Supported set to false')
    end
end

function CDRReturnHomeRNG(aiBrain, cdr)
    -- This is a reference... so it will autoupdate
    local cdrPos = cdr:GetPosition()
    local distSqAway = 1600
    local loc = cdr.CDRHome
    local maxRadius = aiBrain.ACUSupport.ACUMaxSearchRadius
    --local newLoc = {}
    if not cdr.Dead and VDist2Sq(cdrPos[1], cdrPos[3], loc[1], loc[3]) > distSqAway then
        --LOG('CDR further than distSqAway')
        local plat = aiBrain:MakePlatoon('', '')
        
        aiBrain:AssignUnitsToPlatoon(plat, {cdr}, 'support', 'None')
        repeat
            CDRRevertPriorityChange(aiBrain, cdr)
            if not aiBrain:PlatoonExists(plat) then
                return
            end
            cdr.GoingHome = true
            IssueClearCommands({cdr})
            IssueStop({cdr})
            local acuPos1 = table.copy(cdrPos)
            --LOG('ACU Pos 1 :'..repr(acuPos1))
            --LOG('Home location is :'..repr(loc))
            cdr.PlatoonHandle:MoveToLocation(loc, false)
            WaitTicks(40)
            local acuPos2 = table.copy(cdrPos)
            --LOG('ACU Pos 2 :'..repr(acuPos2))
            local headingVec = {(2 * (10 * acuPos2[1] - acuPos1[1]*9) + loc[1])/3, 0, (2 * (10 * acuPos2[3] - acuPos1[3]*9) + loc[3])/3}
            --LOG('Heading Vector is :'..repr(headingVec))
            local movePosTable = RUtils.SetArcPoints(headingVec,acuPos2, 15, 3, 8)
            local indexVar = math.random(1,3)
            IssueClearCommands({cdr})
            IssueStop({cdr})
            if movePosTable[indexVar] ~= nil then
                cdr.PlatoonHandle:MoveToLocation(movePosTable[indexVar], false)
            else
                cdr.PlatoonHandle:MoveToLocation(loc, false)
            end
            WaitTicks(20)
            if (cdr:GetHealthPercent() > 0.75) then
                if (aiBrain:GetNumUnitsAroundPoint(categories.MOBILE * categories.LAND, loc, maxRadius, 'ENEMY') > 0 ) then
                    cdr.GoingHome = false
                    IssueStop({cdr})
                    return CDROverChargeRNG(aiBrain, cdr)
                end
            end
        until cdr.Dead or VDist2Sq(cdrPos[1], cdrPos[3], loc[1], loc[3]) <= distSqAway

        cdr.GoingHome = false
        IssueClearCommands({cdr})
    end
end

function CDRUnitCompletion(aiBrain, cdr)
    if cdr.UnitBeingBuiltBehavior then
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
        local nmaShield = aiBrain:GetNumUnitsAroundPoint(categories.SHIELD * categories.STRUCTURE, cdr:GetPosition(), 100, 'Ally')
        local nmaPD = aiBrain:GetNumUnitsAroundPoint(categories.DIRECTFIRE * categories.DEFENSE, cdr:GetPosition(), 100, 'Ally')
        local nmaAA = aiBrain:GetNumUnitsAroundPoint(categories.ANTIAIR * categories.DEFENSE, cdr:GetPosition(), 100, 'Ally')

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

function ACUDetection(platoon)
    local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
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
    local upgradeNumLimit
    local extractorUpgradeLimit = 5
    local extractorClosest = false
    
    local initial_delay = 0
    local ecoStartTime = GetGameTimeSeconds()
    if unitTech == 'TECH1' then
        ecoTimeOut = 480
    elseif unitTech == 'TECH2' then
        ecoTimeOut = 720
    end
    --LOG('* AI-RNG: Initial Variables set')
    while initial_delay < upgradeSpec.InitialDelay do
		if GetEconomyStored( aiBrain, 'MASS') >= 50 and GetEconomyStored( aiBrain, 'ENERGY') >= 1000 and unit:GetFractionComplete() == 1 then
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
        
        if (GetGameTimeSeconds() - ecoStartTime) > ecoTimeOut then
            --LOG('Extractor has not started upgrade for more than 10 mins, removing eco restriction')
            bypasseco = true
        end
        upgradeNumLimit = StructureUpgradeNumDelay(aiBrain, unitType, unitTech)
        if unitTech == 'TECH1' and bypasseco then
            WaitTicks(Random(1,50))
            extractorUpgradeLimit = aiBrain.EcoManager.ExtractorUpgradeLimit.TECH1
        elseif unitTech == 'TECH2' and bypasseco then
            WaitTicks(Random(1,50))
            extractorUpgradeLimit = aiBrain.EcoManager.ExtractorUpgradeLimit.TECH2
        end
        if upgradeNumLimit >= extractorUpgradeLimit then
            continue
        end
        --LOG('Current Upgrade Limit is :'..upgradeNumLimit)
        extractorClosest = ExtractorClosest(aiBrain, unit, unitBp)
        if not extractorClosest then
            --LOG('ExtractorClosest is false')
            continue
        end
        
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
                or ((massStorageRatio > .60 and energyStorageRatio > .70))
                or (massStorage > (massNeeded * .7) and energyStorage > (energyNeeded * .4 ) ) or bypasseco then
                --LOG('* AI-RNG: low_trigger_good = true')
            else
                continue
            end
            --[[
            if (massEfficiency <= upgradeSpec.MassHighTrigger and energyEfficiency <= upgradeSpec.EnergyHighTrigger) then
                --LOG('* AI-RNG: hi_trigger_good = true')
            else
                continue
            end]]

            if ( massTrend >= massTrendNeeded and energyTrend >= energyTrendNeeded and energyTrend >= energyMaintenance )
				or ( massStorage >= (massNeeded * .7) and energyStorage > (energyNeeded * .4) ) or bypasseco then
				-- we need to have 15% of the resources stored -- some things like MEX can bypass this last check
				if (massStorage > ( massNeeded * .15 * upgradeSpec.MassLowTrigger) and energyStorage > ( energyNeeded * .15 * upgradeSpec.EnergyLowTrigger)) or bypasseco then
                    if aiBrain.UpgradeIssued < aiBrain.UpgradeIssuedLimit then
						if not unit.Dead then

                            upgradeIssued = true
                            IssueUpgrade({unit}, upgradeID)
                            
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
        MassExtractorUnitList = aiBrain:GetListOfUnits(categories.MASSEXTRACTION * (categories.TECH1), false, false)
    elseif unitType == 'MASSEXTRACTION' and unitTech == 'TECH2' then
        MassExtractorUnitList = aiBrain:GetListOfUnits(categories.MASSEXTRACTION * (categories.TECH2), false, false)
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

function TacticalResponse(platoon)
    local aiBrain = platoon:GetBrain()
    local platoonPos = platoon:GetPlatoonPosition()
    local acuTarget = false
    local targetDistance = 0
    while aiBrain:PlatoonExists(platoon) do
        --local tacticalThreat = aiBrain.EnemyIntel.EnemyThreatLocations
        if aiBrain.ACUSupport.Supported then
            acuTarget = aiBrain.ACUSupport.TargetPosition
            --LOG('Platoon Pos :'..repr(platoonPos)..' ACU TargetPos :'..repr(acuTarget))
            targetDistance = VDist2Sq(platoonPos[1], platoonPos[3], acuTarget[1], acuTarget[3])
            if targetDistance > 50 and targetDistance < 200 then
                platoon:Stop()
                platoon:SetAIPlan('TacticalResponseAIRNG')
            end
        end
        --[[elseif table.getn(tacticalThreat) > 0 then
            --LOG('* AI-RNG: TacticalResponse Cycle')
            local threat = 0
            local threatType = platoon.MovementLayer
            local platoonThreat = platoon:CalculatePlatoonThreat(threatType, categories.ALLUNITS)
            local threatCutOff = platoonThreat * 0.50
            for _, v in tacticalThreat do
                if v.Threat > threat and v.Threat > threatCutOff then
                    platoon:SetAIPlan('TacticalResponseAIRNG')
                    break
                end
            end
        end]]
        WaitTicks(100)
    end
end