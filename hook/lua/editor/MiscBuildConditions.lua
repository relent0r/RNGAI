local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local GetCurrentUnits = moho.aibrain_methods.GetCurrentUnits
local RNGSORT = table.sort
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

-- ##############################################################################################################
-- # function: ReclaimablesInArea = BuildCondition   doc = "Please work function docs."
-- #
-- # parameter 0: string   aiBrain     = "default_brain"
-- # parameter 1: string   locType     = "MAIN"
-- #
-- ##############################################################################################################
function ReclaimablesAvailableAtBase(aiBrain, locType)
    if aiBrain:GetEconomyStoredRatio('MASS') < .80 then
        for k, v in aiBrain.BuilderManagers do
            if locType == k then
                if v.ReclaimData.ReclaimAvailable then
                    local engineersRequired = v.ReclaimData.EngineersRequired or 4
                    if locType == 'MAIN' then
                        engineersRequired = engineersRequired * 3
                    end
                    if v.EngineerManager.ConsumptionUnits.Engineers.Count and v.EngineerManager.ConsumptionUnits.Engineers.Count < engineersRequired + 2 then
                        return true
                    end
                end
            end
        end
    end
    return false
end

function PathCheckToCurrentEnemyRNG(aiBrain, locationType, pathType, notCheck)
    local enemyX, enemyZ
    if aiBrain:GetCurrentEnemy() then
        enemyX, enemyZ = aiBrain:GetCurrentEnemy():GetArmyStartPos()
        -- if we don't have an enemy position then we can't search for a path. Return until we have an enemy position
        if not enemyX then
            return false
        end
    else
        -- if we don't have a current enemy then return false
        return false
    end

    -- Get the armyindex from the enemy
    local EnemyIndex = aiBrain:GetCurrentEnemy():GetArmyIndex()
    local OwnIndex = aiBrain:GetArmyIndex()

    -- Check if we have already done a path search to the current enemy
    if notCheck then
        if aiBrain.CanPathToEnemyRNG[OwnIndex][EnemyIndex][locationType] ~= pathType then
            return true
        end
        return false
    end
    if aiBrain.CanPathToEnemyRNG[OwnIndex][EnemyIndex][locationType] == pathType then
        return true
    end
    return false
end

function DamagedStructuresInAreaRNG(aiBrain, locationtype)
    local engineerManager = aiBrain.BuilderManagers[locationtype].EngineerManager
    if not engineerManager then
        return false
    end
    local Structures = AIUtils.GetOwnUnitsAroundPoint(aiBrain, categories.STRUCTURE - (categories.TECH1 - categories.FACTORY), engineerManager.Location, engineerManager.Radius)
    for k,v in Structures do
        if not v.Dead and v:GetHealthPercent() < .8 then
        --RNGLOG('*AI DEBUG: DamagedStructuresInArea return true')
            return true
        end
    end
    --RNGLOG('*AI DEBUG: DamagedStructuresInArea return false')
    return false
end

function CheckIfReclaimEnabled(aiBrain)
    if aiBrain.ReclaimEnabled == false then
        --RNGLOG('Reclaim Currently Disabled..validate last check time.')
        if (GetGameTimeSeconds() - aiBrain.ReclaimLastCheck) > 300 then
            --RNGLOG('Last check time older than 5 minutes, re-enabling')
            aiBrain.ReclaimEnabled = true
            return true
        else
            return false
        end
    else
        return true
    end
end

function CheckMustScoutAreas(aiBrain)
    local im = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua').GetIntelManager(aiBrain)
    if im.MapIntelStats.MustScoutArea then
        return true
    else
        return false
    end
end

function ACURequiresSupport(aiBrain)
    if aiBrain.ACUSupport.Supported then
        --RNGLOG('ACU Supported is TRUE')
        return true
    else
        return false
    end
    return false
end

function MassMarkersInWater(aiBrain)
    if aiBrain.MassMarkersInWater then
        return true
    end
    return false
end

function CanBuildAggressivebaseRNG( aiBrain, locationType, radius, tMin, tMax, tRings, tType)
    local ref, refName = AIUtils.AIFindAggressiveBaseLocationRNG( aiBrain, locationType, radius, tMin, tMax, tRings, tType)
    if not ref then
        return false
    end
    --RNGLOG('CanBuildAggressivebaseRNG is true')
    return true
end

function NumCloseMassMarkers(aiBrain, number)
    local massMarkers = RUtils.AIGetMassMarkerLocations(aiBrain, false, false)
    local engPos = aiBrain.BuilderManagers.MAIN.Position
    local closeMarkers = 0
    for k, marker in massMarkers do
        if VDist2Sq(marker.Position[1], marker.Position[3],engPos[1], engPos[3]) < 121 then
            closeMarkers = closeMarkers + 1
        end
    end
    --RNGLOG('Number of mass markers is :'..closeMarkers)
    if closeMarkers == number then
        return true
    elseif closeMarkers > 4 and number > 4 then
        return true
    else
        return false
    end
    return false
end

function TMLEnemyStartRangeCheck(aiBrain)
    local mainPos = aiBrain.BuilderManagers.MAIN.Position
    if aiBrain.EnemyIntel.EnemyStartLocations then
        if not table.empty(aiBrain.EnemyIntel.EnemyStartLocations) then
            for e, pos in aiBrain.EnemyIntel.EnemyStartLocations do
                if VDist2Sq(mainPos[1],  mainPos[3], pos.Position[1], pos.Position[3]) < 65536 then
                    --RNGLOG('TMLEnemyStartRangeCheck is true')
                    return true
                end
            end
        end
    end
    --RNGLOG('TMLEnemyStartRangeCheck is false')
    return false
end

function GreaterThanGameTimeRNG(aiBrain, num, caution)
    local time = GetGameTimeSeconds()
    local multiplier = aiBrain.EcoManager.EcoMultiplier
    if caution and aiBrain.UpgradeMode == 'Caution' then
        if aiBrain.CheatEnabled and (num / math.sqrt(multiplier)) < time then
            return true
        elseif num * 1.3 < time then
            return true
        end
    elseif aiBrain.CheatEnabled and (num / math.sqrt(multiplier)) < time then
        return true
    elseif num < time then
        return true
    end
    return false
end

function MapSizeLessThan(aiBrain, size)
    local mapSizeX, mapSizeZ = GetMapSize()
    if mapSizeX < size and mapSizeZ < size then
        if size == 4000 and mapSizeX > 2000 and mapSizeZ > 2000 then
            --RNGLOG('40 KM Map Check true')
            return true
        elseif size == 2000 and mapSizeX > 1000 and mapSizeZ > 1000 then
            --RNGLOG('20 KM Map Check true')
            return true
        elseif size == 1000 and mapSizeX > 500 and mapSizeZ > 500 then
            --RNGLOG('10 KM Map Check true')
            return true
        elseif size == 500 and mapSizeX > 200 and mapSizeZ > 200 then
            --RNGLOG('5 KM Map Check true')
            return true
        else
            return false
        end
    else
        return false
    end
    return false
end

function AirAttackModeCheck(aiBrain)
    local myAirThreat = aiBrain.BrainIntel.SelfThreat.AirNow
    local enemyAirThreat = aiBrain.EnemyIntel.EnemyThreatCurrent.Air
    if myAirThreat and enemyAirThreat then
        if myAirThreat / 2 > enemyAirThreat then
            return true
        else
            return false
        end
    end
    return false
end

function ExpansionIsActive(aiBrain)
    local activeExpansion = aiBrain.BrainIntel.ActiveExpansion
    if activeExpansion then
        return true
    end
    return false
end

function ArmyNeedOrWantTransports(aiBrain)
    if aiBrain and (not aiBrain.NoRush.Active ) and aiBrain.TransportRequested then
        return true
    end
    return false
end

-- Not in use
function CanBuildOnMassLessThanDistanceRNG(aiBrain, locationType, distance, threatMin, threatMax, threatRings, threatType, maxNum )
    local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
    if not engineerManager then
        return false
    end
    local position = engineerManager:GetLocationCoords()
    local markerTable = AIGetSortedMassLocationsThreatRNG(aiBrain, distance, threatMin, threatMax, threatRings, threatType, position)
    if markerTable[1] then
        return true
    end

    return false
end

function MassPointRatioAvailable(aiBrain)
    if aiBrain.BrainIntel.SelfThreat.MassMarkerBuildable / (aiBrain.EnemyIntel.EnemyCount + aiBrain.BrainIntel.AllyCount) > 0 then
        return true
    end
    return false
end

function StartReclaimGreaterThan(aiBrain, value)
    if aiBrain.StartReclaimCurrent > value then
        return true 
    end
    return false
end

function ReclaimPlatoonsActive(aiBrain, numPlatoon)
    --RNGLOG('Number of reclaim platoons '..aiBrain:GetNumPlatoonsTemplateNamed('RNGAI T1EngineerReclaimer'))
    if aiBrain.ReclaimEnabled then
        if GetEconomyStoredRatio(aiBrain, 'MASS') < 0.10 and aiBrain:GetNumPlatoonsTemplateNamed('RNGAI T1EngineerReclaimer') < numPlatoon then
            --RNGLOG('Less than 5 reclaim platoons')
            return true
        end
    end
    --RNGLOG('More than 5 reclaim platoons')
    return false
end

function FrigateRaidTrue(aiBrain)
    -- Will check if frigate raiding is enabled
    if aiBrain.EnemyIntel.FrigateRaid then
        return true
    end
    return false
end

function AirStagingWantedRNG(aiBrain)
    if aiBrain.BrainIntel.AirStagingRequired or GetGameTimeSeconds() > 480 then
        return true
    end
    return false
end

function BaseCouldBuildMobileAA(aiBrain, locationType)
    local basePosition = aiBrain.BuilderManagers[locationType].Position
    local zoneCount = aiBrain.BuilderManagers[locationType].PathableZones.PathableLandZoneCount
    if zoneCount > 0 then
        for k, v in aiBrain.BuilderManagers[baseName].PathableZones.Zones do
            math.ceil(zoneCount * (enemyairthreat / myairthreat))
        end
    end

end

function GatewayValidation(aiBrain)
    local multiplier = aiBrain.EcoManager.EcoMultiplier
    local numUnits = aiBrain:GetCurrentUnits(categories.FACTORY * categories.GATE * categories.TECH3)
    local gatewayLimit
    local currentRole = RUtils.GetCurrentRole(aiBrain)
    if aiBrain.RNGEXP then
        gatewayLimit = math.min(100 * (numUnits + 1), 1200)
    else
        gatewayLimit = math.min(200 * (numUnits + 1), 800)
    end
    if (aiBrain.EcoManager.CoreExtractorT3Percentage >= 1.0 or aiBrain.cmanager.income.r.m > 300) and (aiBrain.cmanager.income.r.m > (gatewayLimit * multiplier) or aiBrain.RNGEXP or currentRole == 'AirPlayer' ) then
        --LOG('gatewayLimit went true at income of '..tostring(gatewayLimit))
        return true
    end
    return false
end

function ScoutsRequiredForBase(aiBrain, locationType, baseRatio, scoutCategories)
    local scoutsRequired = 0
    if not aiBrain.ZonesInitialized then
        return false
    end
    if aiBrain.BuilderManagers[locationType].PathableZones then
        local manager = aiBrain.BuilderManagers[locationType]
        local layer = manager.Layer or 'Land'
        for _, v in manager.PathableZones.Zones do
            if v.ZoneID and v.PathType == layer then
                local zone = aiBrain.Zones[layer].zones[v.ZoneID]
                if zone.teamvalue then
                    local teamValue = zone.teamvalue
                    local adjustedRatio = baseRatio * (1 + (1 - teamValue))
                    if zone.intelassignment.RadarCoverage then
                        adjustedRatio = adjustedRatio * 0.5
                    end
                    if zone.enemylandthreat > 0 then
                        adjustedRatio = adjustedRatio * 1.2
                    end
                    scoutsRequired = scoutsRequired + math.min(adjustedRatio, 1)
                end
            end
        end
        --LOG('Scouts required for base '..tostring(locationType)..' '..tostring(scoutsRequired)..' current count it '..tostring(GetCurrentUnits(aiBrain, scoutCategories)))
        if math.floor(scoutsRequired) > GetCurrentUnits(aiBrain, scoutCategories) then
            return true
        end
    end
    return false
end

function DisableOnStrategy(aiBrain, strategyTable)
    for _,strategy in strategyTable do
        if aiBrain.BrainIntel.PlayerStrategy[strategy] then
            return false
        end
    end
    return true
end

function DisableOnRole(aiBrain, roleTable)
    for _,role in roleTable do
        if aiBrain.BrainIntel.PlayerRole[role] then
            return false
        end
    end
    return true
end