local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')


-- ##############################################################################################################
-- # function: ReclaimablesInArea = BuildCondition   doc = "Please work function docs."
-- #
-- # parameter 0: string   aiBrain     = "default_brain"
-- # parameter 1: string   locType     = "MAIN"
-- #
-- ##############################################################################################################
function ReclaimablesInArea(aiBrain, locType)
    if aiBrain:GetEconomyStoredRatio('MASS') > .9 then
        --LOG('Mass Storage Ratio Returning False')
        return false
    end
    
    local ents = AIUtils.AIGetReclaimablesAroundLocation( aiBrain, locType )
    if ents and table.getn(ents) > 0 then
        --LOG('Engineer Reclaim condition returned true')
        return true
    end
    
    return false
end
local CanPathToEnemyRNG = {}
function CanPathToCurrentEnemyRNG(aiBrain, locationType, bool) -- Uveso's function modified to work with expansions
    local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
    --We are getting the current base position rather than the start position so we can use this for expansions.
    local locPos = aiBrain.BuilderManagers[locationType].Position 
    -- added this incase the position came back nil
    if not locPos then
        locPos = aiBrain.BuilderManagers['MAIN'].Position
    end
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
    local EnemyIndex = ArmyBrains[aiBrain:GetCurrentEnemy():GetArmyIndex()].Nickname
    local OwnIndex = ArmyBrains[aiBrain:GetArmyIndex()].Nickname

    -- create a table for the enemy index in case it's nil
    CanPathToEnemyRNG[OwnIndex] = CanPathToEnemyRNG[OwnIndex] or {}
    CanPathToEnemyRNG[OwnIndex][EnemyIndex] = CanPathToEnemyRNG[OwnIndex][EnemyIndex] or {}
    -- Check if we have already done a path search to the current enemy
    if CanPathToEnemyRNG[OwnIndex][EnemyIndex][locationType] == 'LAND' then
        return true == bool
    elseif CanPathToEnemyRNG[OwnIndex][EnemyIndex][locationType] == 'WATER' then
        return false == bool
    end
    -- path wit AI markers from our base to the enemy base
    --LOG('Validation GenerateSafePath inputs locPos :'..repr(locPos)..'Enemy Pos: '..repr({enemyX,0,enemyZ}))
    local path, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, 'Land', locPos, {enemyX,0,enemyZ}, 1000)
    -- if we have a path generated with AI path markers then....
    if path then
        --LOG('* RNG CanPathToCurrentEnemyRNG: Land path to the enemy found! LAND map! - '..OwnIndex..' vs '..EnemyIndex..''..' Location '..locationType)
        CanPathToEnemyRNG[OwnIndex][EnemyIndex][locationType] = 'LAND'
    -- if we not have a path
    else
        -- "NoPath" means we have AI markers but can't find a path to the enemy - There is no path!
        if reason == 'NoPath' then
            --LOG('* RNG CanPathToCurrentEnemyRNG: No land path to the enemy found! WATER map! - '..OwnIndex..' vs '..EnemyIndex..''..' Location '..locationType)
            CanPathToEnemyRNG[OwnIndex][EnemyIndex][locationType] = 'WATER'
        -- "NoGraph" means we have no AI markers and cant graph to the enemy. We can't search for a path - No markers
        elseif reason == 'NoGraph' then
            --LOG('* RNG CanPathToCurrentEnemyRNG: No AI markers found! Using land/water ratio instead')
            -- Check if we have less then 50% water on the map
            if aiBrain:GetMapWaterRatio() < 0.50 then
                --lets asume we can move on land to the enemy
                --LOG(string.format('* RNG CanPathToCurrentEnemy: Water on map: %0.2f%%. Assuming LAND map! - '..OwnIndex..' vs '..EnemyIndex..''..' Location '..locationType ,aiBrain:GetMapWaterRatio()*100 ))
                CanPathToEnemyRNG[OwnIndex][EnemyIndex][locationType] = 'LAND'
            else
                -- we have more then 50% water on this map. Ity maybe a water map..
                --LOG(string.format('* RNG CanPathToCurrentEnemy: Water on map: %0.2f%%. Assuming WATER map! - '..OwnIndex..' vs '..EnemyIndex..''..' Location '..locationType ,aiBrain:GetMapWaterRatio()*100 ))
                CanPathToEnemyRNG[OwnIndex][EnemyIndex][locationType] = 'WATER'
            end
        end
    end
    if CanPathToEnemyRNG[OwnIndex][EnemyIndex][locationType] == 'LAND' then
        return true == bool
    elseif CanPathToEnemyRNG[OwnIndex][EnemyIndex][locationType] == 'WATER' then
        return false == bool
    end
    CanPathToEnemyRNG[OwnIndex][EnemyIndex][locationType] = 'WATER'
    return false == bool
end

function DamagedStructuresInAreaRNG(aiBrain, locationtype)
    local engineerManager = aiBrain.BuilderManagers[locationtype].EngineerManager
    if not engineerManager then
        return false
    end
    local Structures = AIUtils.GetOwnUnitsAroundPoint(aiBrain, categories.STRUCTURE - (categories.TECH1 - categories.FACTORY), engineerManager.Location, engineerManager.Radius)
    for k,v in Structures do
        if not v.Dead and v:GetHealthPercent() < .8 then
        --LOG('*AI DEBUG: DamagedStructuresInArea return true')
            return true
        end
    end
    --LOG('*AI DEBUG: DamagedStructuresInArea return false')
    return false
end

function CheckIfReclaimEnabled(aiBrain)
    if aiBrain.ReclaimEnabled == false then
        --LOG('Reclaim Currently Disabled..validate last check time.')
        if (GetGameTimeSeconds() - aiBrain.ReclaimLastCheck) > 300 then
            --LOG('Last check time older than 5 minutes, re-enabling')
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
    if table.getn(aiBrain.InterestList.MustScout) > 0 then
        return true
    else
        return false
    end
end

function ACURequiresSupport(aiBrain)
    if aiBrain.ACUSupport.Supported then
        --LOG('ACU Supported is TRUE')
        return true
    else
        return false
    end
    return false
end

function MassMarkersInWater(aiBrain)
    if aiBrain.MassMarkersInWater then
        return true
    else
        return false
    end
    return false
end

function CanBuildAggressivebaseRNG( aiBrain, locationType, radius, tMin, tMax, tRings, tType)
    local ref, refName = AIUtils.AIFindAggressiveBaseLocationRNG( aiBrain, locationType, radius, tMin, tMax, tRings, tType)
    if not ref then
        return false
    end
    --LOG('CanBuildAggressivebaseRNG is true')
    return true
end

function NumCloseMassMarkers(aiBrain, number)
    massMarkers = RUtils.AIGetMassMarkerLocations(aiBrain, false, false)
    engPos = aiBrain.BuilderManagers.MAIN.Position
    closeMarkers = 0
    for k, marker in massMarkers do
        if VDist2Sq(marker.Position[1], marker.Position[3],engPos[1], engPos[3]) < 121 then
            closeMarkers = closeMarkers + 1
        end
    end
    --LOG('Number of mass markers is :'..closeMarkers)
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
        if table.getn(aiBrain.EnemyIntel.EnemyStartLocations) > 0 then
            for e, pos in aiBrain.EnemyIntel.EnemyStartLocations do
                if VDist2Sq(mainPos[1],  mainPos[3], pos[1], pos[3]) < 65536 then
                    --LOG('TMLEnemyStartRangeCheck is true')
                    return true
                end
            end
        end
    end
    --LOG('TMLEnemyStartRangeCheck is false')
    return false
end

function GreaterThanGameTimeRNG(aiBrain, num, caution)
    local time = GetGameTimeSeconds()
    local multiplier = tonumber(ScenarioInfo.Options.BuildMult)
    if caution and aiBrain.UpgradeMode == 'Caution' then
        if aiBrain.CheatEnabled and ((num / multiplier) * 1.3) < time then
            return true
        elseif num * 1.3 < time then
            return true
        end
    elseif aiBrain.CheatEnabled and ((num / multiplier) * 1.2) < time then
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
            --LOG('40 KM Map Check true')
            return true
        elseif size == 2000 and mapSizeX > 1000 and mapSizeZ > 1000 then
            --LOG('20 KM Map Check true')
            return true
        elseif size == 1000 and mapSizeX > 500 and mapSizeZ > 500 then
            --LOG('10 KM Map Check true')
            return true
        elseif size == 500 and mapSizeX > 200 and mapSizeZ > 200 then
            --LOG('5 KM Map Check true')
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
    if aiBrain and aiBrain:GetNoRushTicks() <= 0 and aiBrain.NeedTransports and aiBrain.NeedTransports > 0  then
        return true
    elseif aiBrain and aiBrain:GetNoRushTicks() <= 0 and aiBrain.WantTransports then
        return true
    end
    return false
end
    
