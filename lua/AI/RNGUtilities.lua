local AIUtils = import('/lua/ai/AIUtilities.lua')
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local Utils = import('/lua/utilities.lua')
--[[
Valid Threat Options:
            Overall
            OverallNotAssigned
            StructuresNotMex
            Structures
            Naval
            Air
            Land
            Experimental
            Commander
            Artillery
            AntiAir
            AntiSurface
            AntiSub
            Economy
            Unknown
]]

local PropBlacklist = {}
-- This uses a mix of Uveso's reclaim logic and my own
function ReclaimRNGAIThread(platoon, self, aiBrain)
    -- Caution this is extremely barebones and probably will break stuff or reclaim stuff it shouldn't
    LOG('* AI-RNG: Start Reclaim Function')
    IssueClearCommands({self})
    local locationType = self.PlatoonData.LocationType
    local initialRange = 40
    local createTick = GetGameTick()
    local reclaimLoop = 0

    self.BadReclaimables = self.BadReclaimables or {}

    while aiBrain:PlatoonExists(platoon) and self and not self.Dead do
        local furtherestReclaim = nil
        local closestReclaim = nil
        local closestDistance = 10000
        local furtherestDistance = 0
        local engPos = self:GetPosition()
        local x1 = engPos[1] - initialRange
        local x2 = engPos[1] + initialRange
        local z1 = engPos[3] - initialRange
        local z2 = engPos[3] + initialRange
        local rect = Rect(x1, z1, x2, z2)
        local reclaimRect = {}
        reclaimRect = GetReclaimablesInRect(rect)
        if not engPos then
            WaitTicks(1)
            return
        end

        local reclaim = {}
        local needEnergy = aiBrain:GetEconomyStoredRatio('ENERGY') < 0.5
        --LOG('* AI-RNG: Going through reclaim table')
        if reclaimRect and table.getn( reclaimRect ) > 0 then
            for k,v in reclaimRect do
                if not IsProp(v) or self.BadReclaimables[v] then continue end
                local rpos = v:GetCachePosition()
                -- Start Blacklisted Props
                local blacklisted = false
                for _, BlackPos in PropBlacklist do
                    if rpos[1] == BlackPos[1] and rpos[3] == BlackPos[3] then
                        blacklisted = true
                        break
                    end
                end
                if blacklisted then continue end
                -- End Blacklisted Props
                if not needEnergy or v.MaxEnergyReclaim then
                    if v.MaxMassReclaim and v.MaxMassReclaim > 1 then
                        if not self.BadReclaimables[v] then
                            local distance = VDist2(engPos[1], engPos[3], rpos[1], rpos[3])
                            if distance < closestDistance then
                                closestReclaim = rpos
                                closestDistance = distance
                            end
                            if distance > furtherestDistance then -- and distance < closestDistance + 20
                                furtherestReclaim = rpos
                                furtherestDistance = distance
                            end
                            if furtherestDistance - closestDistance > 20 then
                                break
                            end
                        end
                    end
                end
            end
        else
            initialRange = initialRange + 100
            LOG('* AI-RNG: initialRange is'..initialRange)
            if initialRange > 200 then
                LOG('* AI-RNG: Reclaim range > 200, Disabling Reclaim.')
                PropBlacklist = {}
                aiBrain.ReclaimEnabled = false
                aiBrain.ReclaimLastCheck = GetGameTimeSeconds()
                return
            end
            continue
        end
        if closestDistance == 10000 then
            initialRange = initialRange + 100
            LOG('* AI-RNG: initialRange is'..initialRange)
            if initialRange > 200 then
                LOG('* AI-RNG: Reclaim range > 200, Disabling Reclaim.')
                PropBlacklist = {}
                aiBrain.ReclaimEnabled = false
                aiBrain.ReclaimLastCheck = GetGameTimeSeconds()
                return
            end
            continue
        end
        if self.Dead then 
            return
        end
        LOG('* AI-RNG: Closest Distance is : '..closestDistance..'Furtherest Distance is :'..furtherestDistance)
        -- Clear Commands first
        IssueClearCommands({self})
        --LOG('* AI-RNG: Attempting move to closest reclaim')
        --LOG('* AI-RNG: Closest reclaim is '..repr(closestReclaim))
        if not closestReclaim then
            return
        end
        if self.lastXtarget == closestReclaim[1] and self.lastYtarget == closestReclaim[3] then
            self.blocked = self.blocked + 1
            LOG('* AI-RNG: Reclaim Blocked + 1 :'..self.blocked)
            if self.blocked > 3 then
                self.blocked = 0
                table.insert (PropBlacklist, closestReclaim)
                LOG('* AI-RNG: Reclaim Added to blacklist')
            end
        else
            self.blocked = 0
            self.lastXtarget = closestReclaim[1]
            self.lastYtarget = closestReclaim[3]
            StartMoveDestination(self, closestReclaim)
        end
        local brokenDistance = closestDistance / 8
        --LOG('* AI-RNG: One 6th of distance is '..brokenDistance)
        local moveWait = 0
        while VDist2(engPos[1], engPos[3], closestReclaim[1], closestReclaim[3]) > brokenDistance do
            --LOG('* AI-RNG: Waiting for engineer to get close, current distance : '..VDist2(engPos[1], engPos[3], closestReclaim[1], closestReclaim[3])..'closestDistance'..closestDistance)
            WaitTicks(20)
            moveWait = moveWait + 1
            engPos = self:GetPosition()
            if moveWait == 10 then
                break
            end
        end
        --LOG('* AI-RNG: Attempting agressive move to furtherest reclaim')
        -- Clear Commands first
        IssueClearCommands({self})
        IssueAggressiveMove({self}, furtherestReclaim)
        local reclaiming = not self:IsIdleState()
        local max_time = platoon.PlatoonData.ReclaimTime
        while reclaiming do
            --LOG('* AI-RNG: Engineer is reclaiming')
            WaitSeconds(max_time)
           if self:IsIdleState() or (max_time and (GetGameTick() - createTick)*10 > max_time) then
                --LOG('* AI-RNG: Engineer no longer reclaiming')
                reclaiming = false
            end
        end
        local basePosition = aiBrain.BuilderManagers['MAIN'].Position
        local location = AIUtils.RandomLocation(basePosition[1],basePosition[3])
        --LOG('* AI-RNG: basePosition random location :'..repr(location))
        IssueClearCommands({self})
        StartMoveDestination(self, location)
        WaitTicks(50)
        reclaimLoop = reclaimLoop + 1
        if reclaimLoop == 5 then
            LOG('* AI-RNG: reclaimLopp = 5 returning')
            return
        end
    end
end

function StartMoveDestination(self,destination)
    local NowPosition = self:GetPosition()
    local x, z, y = unpack(self:GetPosition())
    local count = 0
    IssueClearCommands({self})
    while x == NowPosition[1] and y == NowPosition[3] and count < 20 do
        count = count + 1
        IssueClearCommands({self})
        IssueMove( {self}, destination )
        WaitTicks(10)
    end
end
-- Get the military operational areas of the map. Credit to Uveso, this is based on his zones but a little more for small map sizes.
function GetMOARadii(bool)
    -- Military area is slightly less than half the map size (10x10map) or maximal 200.
    local BaseMilitaryArea = math.max( ScenarioInfo.size[1]-50, ScenarioInfo.size[2]-50 ) / 2.2
    BaseMilitaryArea = math.max( 180, BaseMilitaryArea )
    -- DMZ is half the map. Mainly used for air formers
    local BaseDMZArea = math.max( ScenarioInfo.size[1]-40, ScenarioInfo.size[2]-40 ) / 2
    -- Restricted Area is half the BaseMilitaryArea. That's a little less than 1/4 of a 10x10 map
    local BaseRestrictedArea = BaseMilitaryArea / 2
    -- Make sure the Restricted Area is not smaller than 50 or greater than 100
    BaseRestrictedArea = math.max( 50, BaseRestrictedArea )
    BaseRestrictedArea = math.min( 100, BaseRestrictedArea )
    -- The rest of the map is enemy area
    local BaseEnemyArea = math.max( ScenarioInfo.size[1], ScenarioInfo.size[2] ) * 1.5
    -- "bool" is only true if called from "AIBuilders/Mobile Land.lua", so we only print this once.
    if bool then
        LOG('* RNGAI: BaseRestrictedArea= '..math.floor( BaseRestrictedArea * 0.01953125 ) ..' Km - ('..BaseRestrictedArea..' units)' )
        LOG('* RNGAI: BaseMilitaryArea= '..math.floor( BaseMilitaryArea * 0.01953125 )..' Km - ('..BaseMilitaryArea..' units)' )
        LOG('* RNGAI: BaseDMZArea= '..math.floor( BaseDMZArea * 0.01953125 )..' Km - ('..BaseDMZArea..' units)' )
        LOG('* RNGAI: BaseEnemyArea= '..math.floor( BaseEnemyArea * 0.01953125 )..' Km - ('..BaseEnemyArea..' units)' )
    end
    return BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea
end

function AirScoutPatrolRNGAIThread(self, aiBrain)
    
    local scout = self:GetPlatoonUnits()[1]
    if not scout then
        return
    end

    -- build scoutlocations if not already done.
    if not aiBrain.InterestList then
        aiBrain:BuildScoutLocations()
    end

    --If we have Stealth (are cybran), then turn on our Stealth
    if scout:TestToggleCaps('RULEUTC_CloakToggle') then
        scout:EnableUnitIntel('Toggle', 'Cloak')
    end

    while not scout.Dead do
        local targetArea = false
        local highPri = false

        local mustScoutArea, mustScoutIndex = aiBrain:GetUntaggedMustScoutArea()
        local unknownThreats = aiBrain:GetThreatsAroundPosition(scout:GetPosition(), 16, true, 'Unknown')

        --1) If we have any "must scout" (manually added) locations that have not been scouted yet, then scout them
        if mustScoutArea then
            mustScoutArea.TaggedBy = scout
            targetArea = mustScoutArea.Position

        --2) Scout "unknown threat" areas with a threat higher than 25
        elseif table.getn(unknownThreats) > 0 and unknownThreats[1][3] > 25 then
            aiBrain:AddScoutArea({unknownThreats[1][1], 0, unknownThreats[1][2]})

        --3) Scout high priority locations
        elseif aiBrain.IntelData.AirHiPriScouts < aiBrain.NumOpponents and aiBrain.IntelData.AirLowPriScouts < 1
        and table.getn(aiBrain.InterestList.HighPriority) > 0 then
            aiBrain.IntelData.AirHiPriScouts = aiBrain.IntelData.AirHiPriScouts + 1

            highPri = true

            targetData = aiBrain.InterestList.HighPriority[1]
            targetData.LastScouted = GetGameTimeSeconds()
            targetArea = targetData.Position

            aiBrain:SortScoutingAreas(aiBrain.InterestList.HighPriority)

        --4) Every time we scout NumOpponents number of high priority locations, scout a low priority location
        elseif aiBrain.IntelData.AirLowPriScouts < 1 and table.getn(aiBrain.InterestList.LowPriority) > 0 then
            aiBrain.IntelData.AirHiPriScouts = 0
            aiBrain.IntelData.AirLowPriScouts = aiBrain.IntelData.AirLowPriScouts + 1

            targetData = aiBrain.InterestList.LowPriority[1]
            targetData.LastScouted = GetGameTimeSeconds()
            targetArea = targetData.Position

            aiBrain:SortScoutingAreas(aiBrain.InterestList.LowPriority)
        else
            --Reset number of scoutings and start over
            aiBrain.IntelData.AirLowPriScouts = 0
            aiBrain.IntelData.AirHiPriScouts = 0
        end

        --Air scout do scoutings.
        if targetArea then
            self:Stop()

            local vec = self:DoAirScoutVecs(scout, targetArea)

            while not scout.Dead and not scout:IsIdleState() do

                --If we're close enough...
                if VDist2Sq(vec[1], vec[3], scout:GetPosition()[1], scout:GetPosition()[3]) < 15625 then
                    if mustScoutArea then
                        --Untag and remove
                        for idx,loc in aiBrain.InterestList.MustScout do
                            if loc == mustScoutArea then
                               table.remove(aiBrain.InterestList.MustScout, idx)
                               break
                            end
                        end
                    end
                    --Break within 125 ogrids of destination so we don't decelerate trying to stop on the waypoint.
                    break
                end

                if VDist3(scout:GetPosition(), targetArea) < 25 then
                    break
                end

                WaitTicks(50)
            end
        else
            WaitTicks(10)
        end
        WaitTicks(5)
    end
end

function EngineerTryReclaimCaptureArea(aiBrain, eng, pos)
    if not pos then
        return false
    end
    local Reclaiming = false
    --Temporary for troubleshooting
    local GetBlueprint = moho.entity_methods.GetBlueprint
    -- Check if enemy units are at location
    local checkUnits = aiBrain:GetUnitsAroundPoint( (categories.STRUCTURE + categories.MOBILE) - categories.AIR, pos, 15, 'Enemy')
    -- reclaim units near our building place.
    if checkUnits and table.getn(checkUnits) > 0 then
        for num, unit in checkUnits do
            --temporary for troubleshooting
            unitdesc = GetBlueprint(unit).Description
            if unit.Dead or unit:BeenDestroyed() then
                continue
            end
            if not IsEnemy( aiBrain:GetArmyIndex(), unit:GetAIBrain():GetArmyIndex() ) then
                continue
            end
            if unit:IsCapturable() and not EntityCategoryContains(categories.TECH1 * categories.MOBILE, unit) then 
                LOG('* AI-RNG: Unit is capturable and not category t1 mobile'..unitdesc)
                -- if we can capture the unit/building then do so
                unit.CaptureInProgress = true
                IssueCapture({eng}, unit)
            else
                LOG('* AI-RNG: We are going to reclaim the unit'..unitdesc)
                -- if we can't capture then reclaim
                unit.ReclaimInProgress = true
                IssueReclaim({eng}, unit)
            end
        end
        Reclaiming = true
    end
    -- reclaim rocks etc or we can't build mexes or hydros
    local Reclaimables = GetReclaimablesInRect(Rect(pos[1], pos[3], pos[1], pos[3]))
    if Reclaimables and table.getn( Reclaimables ) > 0 then
        for k,v in Reclaimables do
            if v.MaxMassReclaim and v.MaxMassReclaim > 0 or v.MaxEnergyReclaim and v.MaxEnergyReclaim > 0 then
                IssueReclaim({eng}, v)
            end
        end
    end
    return Reclaiming
end

function EngineerMoveWithSafePathRNG(aiBrain, unit, destination)
    if not destination then
        return false
    end
    local pos = unit:GetPosition()
    -- don't check a path if we are in build range
    if VDist2(pos[1], pos[3], destination[1], destination[3]) < 25 then
        return true
    end
    local result, bestPos = unit:CanPathTo(destination)
    local bUsedTransports = false
    -- Increase check to 300 for transports
    if not result or VDist2Sq(pos[1], pos[3], destination[1], destination[3]) > 300 * 300
    and unit.PlatoonHandle and not EntityCategoryContains(categories.COMMAND, unit) then
        -- If we can't path to our destination, we need, rather than want, transports
        local needTransports = not result
        if VDist2Sq(pos[1], pos[3], destination[1], destination[3]) > 300 * 300 then
            needTransports = true
        end

        -- Skip the last move... we want to return and do a build
        bUsedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheck(aiBrain, unit.PlatoonHandle, destination, needTransports, true, false)

        if bUsedTransports then
            return true
        elseif VDist2Sq(pos[1], pos[3], destination[1], destination[3]) > 512 * 512 then
            -- If over 512 and no transports dont try and walk!
            return false
        end
    end

    -- If we're here, we haven't used transports and we can path to the destination
    if result then
        local path, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, 'Amphibious', pos, destination)
        if path then
            local pathSize = table.getn(path)
            -- Move to way points (but not to destination... leave that for the final command)
            for widx, waypointPath in path do
                if pathSize ~= widx then
                    IssueMove({unit}, waypointPath)
                end
            end
        end
        -- If there wasn't a *safe* path (but dest was pathable), then the last move would have been to go there directly
        -- so don't bother... the build/capture/reclaim command will take care of that after we return
        return true
    end
    return false
end

function EngineerTryRepair(aiBrain, eng, whatToBuild, pos)
    if not pos then
        return false
    end

    local structureCat = ParseEntityCategory(whatToBuild)
    local checkUnits = aiBrain:GetUnitsAroundPoint(structureCat, pos, 1, 'Ally')
    if checkUnits and table.getn(checkUnits) > 0 then
        for num, unit in checkUnits do
            IssueRepair({eng}, unit)
        end
        return true
    end

    return false
end

function AIFindUnmarkedExpansionMarkerNeedsEngineerRNG(aiBrain, locationType, radius, tMin, tMax, tRings, tType, eng)
    local pos = aiBrain:PBMGetLocationCoords(locationType)
    if not pos then
        return false
    end

    local validPos = AIUtils.AIGetMarkersAroundLocation(aiBrain, 'Unmarked Expansion', pos, radius, tMin, tMax, tRings, tType)

    local retPos, retName
    if eng then
        retPos, retName = AIUtils.AIFindMarkerNeedsEngineer(aiBrain, eng:GetPosition(), radius, tMin, tMax, tRings, tType, validPos)
    else
        retPos, retName = AIUtils.AIFindMarkerNeedsEngineer(aiBrain, pos, radius, tMin, tMax, tRings, tType, validPos)
    end

    return retPos, retName
end

function AIFindLargeExpansionMarkerNeedsEngineerRNG(aiBrain, locationType, radius, tMin, tMax, tRings, tType, eng)
    local pos = aiBrain:PBMGetLocationCoords(locationType)
    if not pos then
        return false
    end

    local validPos = AIUtils.AIGetMarkersAroundLocation(aiBrain, 'Large Expansion Area', pos, radius, tMin, tMax, tRings, tType)

    local retPos, retName
    if eng then
        retPos, retName = AIUtils.AIFindMarkerNeedsEngineer(aiBrain, eng:GetPosition(), radius, tMin, tMax, tRings, tType, validPos)
    else
        retPos, retName = AIUtils.AIFindMarkerNeedsEngineer(aiBrain, pos, radius, tMin, tMax, tRings, tType, validPos)
    end

    return retPos, retName
end

function AIFindStartLocationNeedsEngineerRNG(aiBrain, locationType, radius, tMin, tMax, tRings, tType, eng)
    local pos = aiBrain:PBMGetLocationCoords(locationType)
    if not pos then
        return false
    end

    local validPos = {}

    local positions = AIUtils.AIGetMarkersAroundLocation(aiBrain, 'Blank Marker', pos, radius, tMin, tMax, tRings, tType)
    local startX, startZ = aiBrain:GetArmyStartPos()
    for _, v in positions do
        if string.sub(v.Name, 1, 5) == 'ARMY_' then
            if startX ~= v.Position[1] and startZ ~= v.Position[3] then
                table.insert(validPos, v)
            end
        end
    end

    local retPos, retName
    if eng then
        retPos, retName = AIUtils.AIFindMarkerNeedsEngineer(aiBrain, eng:GetPosition(), radius, tMin, tMax, tRings, tType, validPos)
    else
        retPos, retName = AIUtils.AIFindMarkerNeedsEngineer(aiBrain, pos, radius, tMin, tMax, tRings, tType, validPos)
    end

    return retPos, retName
end

function AIGetMassMarkerLocations(aiBrain, includeWater, waterOnly)
    local markerList = {}
        local markers = ScenarioUtils.GetMarkers()
        if markers then
            for k, v in markers do
                if v.type == 'Mass' then
                    if waterOnly then
                        if PositionInWater(v.position) then
                            table.insert(markerList, {Position = v.position, Name = k})
                        end
                    elseif includeWater then
                        table.insert(markerList, {Position = v.position, Name = k})
                    else
                        if not PositionInWater(v.position) then
                            table.insert(markerList, {Position = v.position, Name = k})
                        end
                    end
                end
            end
        end
    return markerList
end

-- This is Sproutos function 
function PositionInWater(pos)
	return GetTerrainHeight(pos[1], pos[3]) < GetSurfaceHeight(pos[1], pos[3])
end

function GetClosestMassMarker(aiBrain, unit)
    local markerList = {}
    local markers = ScenarioUtils.GetMarkers()
    if markers then
        for k, v in markers do
            if v.type == 'Mass' then
                table.insert(markerList, {Position = v.position, Name = k})
            end
        end
    end

    engPos = unit:GetPosition()
    local loc, distance, lowest, name = nil

    for _, v in markerList do
        local x = v.Position[1]
        local y = v.Position[2]
        local z = v.Position[3]
        distance = VDist2(engPos[1], engPos[3], x, z)
        if not lowest or distance < lowest then
            loc = v.Position
            name = v.Name
            lowest = distance
        end
    end

    return loc, name
end


function GetStartLocationMassMarkers(aiBrain, massLocations)
    local startLocations

    for i = 1, 16 do
        local army = ScenarioInfo.ArmySetup['ARMY_' .. i]
        local startPos = ScenarioUtils.GetMarker('ARMY_' .. i).position

        if army and startPos then
            if army.ArmyIndex == myArmy.ArmyIndex or (army.Team == myArmy.Team and army.Team ~= 1) then
                allyStarts['ARMY_' .. i] = startPos
            else
                numOpponents = numOpponents + 1
            end
        end
    end

    aiBrain.NumOpponents = numOpponents

    -- If the start location is not ours or an ally's, it is suspicious
    local starts = AIUtils.AIGetMarkerLocations(aiBrain, 'Start Location')
    for _, loc in starts do
        -- If vacant
        if not allyStarts[loc.Name] then
            table.insert(aiBrain.InterestList.LowPriority,
                {
                    Position = loc.Position,
                    LastScouted = 0,
                }
            )
            table.insert(startLocations, startPos)
        end
    end
end

function GetLastACUPosition(aiBrain, enemyIndex)
    local acuPos = {}
    local lastSpotted = 0
    if aiBrain.EnemyIntel.ACU then
        for k, v in aiBrain.EnemyIntel.ACU do
            if k == enemyIndex then
                acuPos = v.Position
                lastSpotted = v.LastSpotted
                LOG('* AI-RNG: acuPos has data')
            else
                --LOG('* AI-RNG: acuPos is currently false')
            end
        --[[if aiBrain.EnemyIntel.ACU[enemyIndex] == enemyIndex then
            acuPos = aiBrain.EnemyIntel.ACU[enemyIndex].ACUPosition
            lastSpotted = aiBrain.EnemyIntel.ACU[enemyIndex].LastSpotted
            LOG('* AI-RNG: acuPos has data')
        else
            LOG('* AI-RNG: acuPos is currently false')
        end]]
        end
    end
    return acuPos, lastSpotted
end


function lerpy(vec1, vec2, distance)
    -- Courtesy of chp2001
    -- note the distance param is {distance, distance - weapon range}
    -- vec1 is friendly unit, vec2 is enemy unit
    distanceFrac = distance[2] / distance[1]
    x = vec1[1] * (1 - distanceFrac) + vec2[1] * distanceFrac
    y = vec1[2] * (1 - distanceFrac) + vec2[2] * distanceFrac
    z = vec1[3] * (1 - distanceFrac) + vec2[3] * distanceFrac
    return {x,y,z}
end

function LerpyRotate(vec1, vec2, distance)
    -- Courtesy of chp2001
    -- note the distance param is {distance, weapon range}
    -- vec1 is friendly unit, vec2 is enemy unit
    distanceFrac = distance[2] / distance[1]
    z = vec2[3] + distanceFrac * (vec2[1] - vec1[1])
    y = vec2[2] - distanceFrac * (vec2[2] - vec1[2])
    x = vec2[1] - distanceFrac * (vec2[3] - vec1[3])
    return {x,y,z}
end

function CheckCustomPlatoons(aiBrain)
    if not aiBrain.StructurePool then
        LOG('* AI-RNG: Creating Structure Pool Platoon')
        local structurepool = aiBrain:MakePlatoon('StructurePool', 'none')
        structurepool:UniquelyNamePlatoon('StructurePool')
        structurepool.BuilderName = 'Structure Pool'
        aiBrain.StructurePool = structurepool
    end
end

function AIFindBrainTargetInRangeRNG(aiBrain, position, platoon, squad, maxRange, atkPri, enemyBrain)
    local position = platoon:GetPlatoonPosition()
    if not aiBrain or not position or not maxRange or not platoon or not enemyBrain then
        return false
    end

    local enemyIndex = enemyBrain:GetArmyIndex()
    local targetUnits = aiBrain:GetUnitsAroundPoint(categories.ALLUNITS, position, maxRange, 'Enemy')
    for _, v in atkPri do
        local category = v
        if type(category) == 'string' then
            category = ParseEntityCategory(category)
        end
        local retUnit = false
        local distance = false
        for num, unit in targetUnits do
            if not unit.Dead and EntityCategoryContains(category, unit) and unit:GetAIBrain():GetArmyIndex() == enemyIndex and platoon:CanAttackTarget(squad, unit) then
                local unitPos = unit:GetPosition()
                if not retUnit or Utils.XZDistanceTwoVectors(position, unitPos) < distance then
                    retUnit = unit
                    distance = Utils.XZDistanceTwoVectors(position, unitPos)
                end
            end
        end
        if retUnit then
            return retUnit
        end
    end

    return false
end

-- 99% of the below was Sprouto's work
function StructureUpgradeInitialize(finishedUnit, aiBrain)
    local StructureUpgradeThread = import('/lua/ai/aibehaviors.lua').StructureUpgradeThread
    local structurePool = aiBrain.StructurePool
    local AssignUnitsToPlatoon = moho.aibrain_methods.AssignUnitsToPlatoon
    --LOG('* AI-RNG: Structure Upgrade Initializing')
    if EntityCategoryContains(categories.MASSEXTRACTION, finishedUnit) then
        local extractorPlatoon = aiBrain:MakePlatoon('ExtractorPlatoon'..tostring(finishedUnit.Sync.id), 'none')
        extractorPlatoon.BuilderName = 'ExtractorPlatoon'..tostring(finishedUnit.Sync.id)
        extractorPlatoon.MovementLayer = 'Land'
        --LOG('* AI-RNG: Assigning Extractor to new platoon')
        AssignUnitsToPlatoon(aiBrain, extractorPlatoon, {finishedUnit}, 'Support', 'none')

        if not finishedUnit.UpgradeThread then
            --LOG('* AI-RNG: Forking Upgrade Thread')
            upgradeSpec = aiBrain:GetUpgradeSpec(finishedUnit)
            --LOG('* AI-RNG: UpgradeSpec'..repr(upgradeSpec))
            finishedUnit.UpgradeThread = finishedUnit:ForkThread(StructureUpgradeThread, aiBrain, upgradeSpec, false)
        end
    end
    if finishedUnit.UpgradeThread then
        finishedUnit.Trash:Add(finishedUnit.UpgradeThread)
    end
end

function InitialMassMarkersInWater(aiBrain)
    if table.getn(AIGetMassMarkerLocations(aiBrain, false, true)) > 0 then
        return true
    else
        return false
    end
end

function PositionOnWater(aiBrain, positionX, positionZ)
    --Check if a position is under water. Used to identify if threat/unit position is over water
    -- Terrain >= Surface = Target is on land
    -- Terrain < Surface = Target is in water

    local TerrainHeight = GetTerrainHeight( positionX, positionZ ) -- terran high
    local SurfaceHeight = GetSurfaceHeight( positionX, positionZ ) -- water(surface) high
    if TerrainHeight < SurfaceHeight then
        return true
    else
        return false
    end
end

function ManualBuildStructure(aiBrain, eng, structureType, tech, position)
    -- Usage ManualBuildStructure(aiBrain, engineerunit, 'AntiSurface', 'TECH2', {123:20:123})
    factionIndex = aiBrain:GetFactionIndex()
    -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
    DefenseTable = {
        { 
        AntiAir = {
            TECH1 = 'ueb2104',
            TECH2 = 'ueb2204',
            TECH3 = 'ueb2304'
            },
        AntiSurface = {
            TECH1 = 'ueb2101',
            TECH2 = 'ueb2301',
            TECH3 = 'xeb2306'
            },
        AntiNaval = {
            TECH1 = 'ueb2109',
            TECH2 = 'ueb2205',
            TECH3 = ''
            }
        },
        {
        AntiAir = {
            TECH1 = 'uab2104',
            TECH2 = 'uab2204',
            TECH3 = 'uab2304'
            },
        AntiSurface = {
            TECH1 = 'uab2101',
            TECH2 = 'uab2301',
            TECH3 = ''
            },
        AntiNaval = {
            TECH1 = 'uab2109',
            TECH2 = 'uab2205',
            TECH3 = ''
            }
        },
        {
        AntiAir = {
            TECH1 = 'urb2104',
            TECH2 = 'urb2204',
            TECH3 = 'urb2304'
            },
        AntiSurface = {
            TECH1 = 'urb2101',
            TECH2 = 'urb2301',
            TECH3 = ''
            },
        AntiNaval = {
            TECH1 = 'urb2109',
            TECH2 = 'urb2205',
            TECH3 = 'xrb2308'
            }
        },
        {
        AntiAir = {
            TECH1 = 'xsb2104',
            TECH2 = 'xsb2204',
            TECH3 = 'xsb2304'
            },
        AntiSurface = {
            TECH1 = 'xsb2101',
            TECH2 = 'xsb2301',
            TECH3 = ''
            },
        AntiNaval = {
            TECH1 = 'xsb2109',
            TECH2 = 'xsb2205',
            TECH3 = ''
            }
        }
    }
    blueprintID = DefenseTable[factionIndex][structureType][tech]
    if aiBrain:CanBuildStructureAt(blueprintID, position) then
        IssueStop({eng})
        IssueClearCommands({eng})
        aiBrain:BuildStructure(eng, blueprintID, position, false)
    end
end

function TacticalMassLocationsold(aiBrain)
    -- Scans the map and trys to figure out tactical locations with multiple mass markers
    -- markerLocations will be returned in the table full of these tables { Name="Mass7", Position={ 189.5, 24.240200042725, 319.5, type="VECTOR3" } }
    LOG('* AI-RNG: * Starting Tactical Mass Location Function')
    local markerGroups = {}
    local markerLocations = AIGetMassMarkerLocations(aiBrain, false, false)
    local group = 1
    local duplicateMarker = {}
    -- loop thru all the markers --
    for key_1, marker_1 in markerLocations do
        -- only process a marker that has not already been used
        if duplicateMarker[key_1] then
            LOG('Duplicate Found Skipping :'..repr(marker_1)..'at key :'..key_1)
            continue
        else
            local groupSet = {MarkerGroup=group, Markers={}}
            -- record that marker has been used
            LOG('Inserting Duplicate Marker phase 1:'..repr(marker_1)..'at key :'..key_1)
            table.insert(duplicateMarker, key_1, marker_1)
            -- loop thru all the markers --
            for key_2, marker_2 in markerLocations do
                -- bypass any marker that's already been used
                if duplicateMarker[key_2] then
                    LOG('Duplicate Found Skipping :'..repr(marker_2)..'at key :'..key_2)
                    continue
                else
                    if VDist2Sq(marker_1.Position[1], marker_1.Position[3], marker_2.Position[1], marker_2.Position[3]) < 1600 then
                        -- record that marker has been used
                        LOG('Inserting Duplicate Marker phase 2:'..repr(marker_2)..'at key :'..key_2)
                        table.insert(duplicateMarker, key_2, marker_2)
                        -- insert marker into group --
                        table.insert(groupSet['Markers'], marker_2)
                    end
                end
            end
            table.insert(groupSet['Markers'], marker_1)
            if table.getn(groupSet['Markers']) > 2 then
                table.insert(markerGroups, groupSet)
                LOG('Group Set Markers :'..repr(groupSet))
                group = group + 1
            end
        
        end
    end
    LOG('Duplicate Marker Set :'..repr(duplicateMarker))
    aiBrain.TacticalMonitor.TacticalMassLocations = markerGroups
    --LOG('* AI-RNG: * Marker Groups :'..repr(aiBrain.TacticalMonitor.TacticalMassLocations))
end

function TacticalMassLocations(aiBrain)
    -- Scans the map and trys to figure out tactical locations with multiple mass markers
    -- markerLocations will be returned in the table full of these tables { Name="Mass7", Position={ 189.5, 24.240200042725, 319.5, type="VECTOR3" } }

    LOG('* AI-RNG: * Starting Tactical Mass Location Function')
    local markerGroups = {}
    local markerLocations = AIGetMassMarkerLocations(aiBrain, false, false)
    local group = 1
    local duplicateMarker = {}
    -- loop thru all the markers --
    for key_1, marker_1 in markerLocations do
        -- only process a marker that has not already been used
            local groupSet = {MarkerGroup=group, Markers={}}
            -- loop thru all the markers --
            for key_2, marker_2 in markerLocations do
                -- bypass any marker that's already been used
                if VDist2Sq(marker_1.Position[1], marker_1.Position[3], marker_2.Position[1], marker_2.Position[3]) < 1600 then
                    -- insert marker into group --
                    table.insert(groupSet['Markers'], marker_2)
                    markerLocations[key_2] = nil
                end
            end
            markerLocations[key_1] = nil
            if table.getn(groupSet['Markers']) > 2 then
                table.insert(markerGroups, groupSet)
                --LOG('Group Set Markers :'..repr(groupSet))
                group = group + 1
            end
    end
    LOG('End Marker Groups :'..repr(markerGroups))
    aiBrain.TacticalMonitor.TacticalMassLocations = markerGroups
    --LOG('* AI-RNG: * Marker Groups :'..repr(aiBrain.TacticalMonitor.TacticalMassLocations))
end

function MarkTacticalMassLocations(aiBrain)
--[[ Gets tactical mass locations and sets markers on ones with no existing expansion markers
    'Air Path Node',
    'Amphibious Path Node',
    'Blank Marker',
    'Camera Info',
    'Combat Zone',
    'Defensive Point',
    'Effect',
    'Expansion Area',
    'Hydrocarbon',
    'Island',
    'Land Path Node',
    'Large Expansion Area',
    'Mass',
    'Naval Area',
    'Naval Defensive Point',
    'Naval Exclude',
    'Naval Link',
    'Naval Rally Point',
    'Protected Experimental Construction',
    'Rally Point',
    'Transport Marker',
    'Water Path Node',
    'Weather Definition',
    'Weather Generator',]]

    local massGroups = aiBrain.TacticalMonitor.TacticalMassLocations
    local expansionMarkers = ScenarioUtils.GetMarkers()
    local markerList = {}
    --LOG('Pre Sorted MassGroups'..repr(massGroups))
    if massGroups then
        if expansionMarkers then
            for k, v in expansionMarkers do
                if v.type == 'Expansion Area' or v.type == 'Large Expansion Area' then
                    table.insert(markerList, {Position = v.position})
                end
            end
        end
        for i = 1, 16 do
            if Scenario.MasterChain._MASTERCHAIN_.Markers['ARMY_'..i] then
                table.insert(markerList, {Position = Scenario.MasterChain._MASTERCHAIN_.Markers['ARMY_'..i].position})
            end
        end
        for key, group in massGroups do
            for key2, marker in markerList do
                if VDist2Sq(group.Markers[1].Position[1], group.Markers[1].Position[3], marker.Position[1], marker.Position[3]) < 2500 then
                    --LOG('Location :'..repr(group.Markers[1])..' is less than 2500 from :'..repr(marker))
                    massGroups[key] = nil
                else
                    --LOG('Location :'..repr(group.Markers[1])..' is more than 2500 from :'..repr(marker))
                    --LOG('Location distance :'..VDist2Sq(group.Markers[1].Position[1], group.Markers[1].Position[3], marker.Position[1], marker.Position[3]))
                end
            end
        end
        aiBrain:RebuildTable(massGroups)
    end
    aiBrain.TacticalMonitor.TacticalUnmarkedMassGroups = massGroups
    --LOG('* AI-RNG: * Total Expansion, Large expansion markers'..repr(markerList))
    LOG('* AI-RNG: * Unmarked Mass Groups'..repr(massGroups))
end

function GenerateMassGroupMarkerLocations(aiBrain)
    -- Will generate locations for markers on the center point for each unmarked mass group
    local markerGroups = aiBrain.TacticalMonitor.TacticalUnmarkedMassGroups
    local newMarkerLocations = {}
    if table.getn(markerGroups) > 0 then
        for key, group in markerGroups do
            local position = MassGroupCenter(group)
            table.insert(newMarkerLocations, position)
            --LOG('Position for new marker is :'..repr(position))
        end
        --LOG('Completed New marker positions :'..repr(newMarkerLocations))
        return newMarkerLocations
    end
    return false
end

function CreateMarkers(markerType, newMarkers)
-- markerType = string e.g "Marker Area"
-- newMarkers = a table of new marker positions e.g {{123,12,123}}
--[[    
    for k, v in Scenario.MasterChain._MASTERCHAIN_.Markers do
        if v.type == 'Expansion Area' then
            if string.find(k, 'ExpansionArea') then
                WARN('* AI-Uveso: ValidateMapAndMarkers: MarkerType: [\''..v.type..'\'] Has wrong Index Name ['..k..']. (Should be [Expansion Area xx]!!!)')
            elseif not string.find(k, 'Expansion Area') then
                WARN('* AI-Uveso: ValidateMapAndMarkers: MarkerType: [\''..v.type..'\'] Has wrong Index Name ['..k..']. (Should be [Expansion Area xx]!!!)')
            end
        end
    end
]]
    --LOG('Marker Dump'..repr(Scenario.MasterChain._MASTERCHAIN_.Markers))
    for index, markerPosition in newMarkers do    
        --LOG('markerType is : '..markerType..' Index is : '..index)
        --local markerName = markerType..' '..index
        Scenario.MasterChain._MASTERCHAIN_.Markers[markerType..' '..index] = { }
        Scenario.MasterChain._MASTERCHAIN_.Markers[markerType..' '..index].color = 'ff000000'
        Scenario.MasterChain._MASTERCHAIN_.Markers[markerType..' '..index].hint = true
        Scenario.MasterChain._MASTERCHAIN_.Markers[markerType..' '..index].orientation = { 0, 0, 0 }
        Scenario.MasterChain._MASTERCHAIN_.Markers[markerType..' '..index].prop = "/env/common/props/markers/M_Expansion_prop.bp"
        Scenario.MasterChain._MASTERCHAIN_.Markers[markerType..' '..index].type = markerType
        Scenario.MasterChain._MASTERCHAIN_.Markers[markerType..' '..index].position = markerPosition
    end
    for k, v in Scenario.MasterChain._MASTERCHAIN_.Markers do
        if v.type == 'Unmarked Expansion' then
            LOG('Unmarked Expansion Marker at :'..repr(v.position))
        end
    end
end

function GeneratePointsAroundPosition(position,radius,num)
    -- Courtesy of chp2001
    -- position = { 233.5, 25.239820480347, 464.5, type="VECTOR3" }
    -- radius = the size of the circle
    -- num = the number of points around the circle

    local nnn=0
    local coords = {}
    while nnn < num do
        local xxx = 0
        local zzz = 0
        xxx = position[1] + radius * math.cos (nnn/num* (2 * math.pi))
        zzz = position[3] + radius * math.sin (nnn/num* (2 * math.pi))
        table.insert(coords, {xxx, zzz})
        nnn = nnn + 1
    end
    return coords
end


function MassGroupCenter(massGroup)
    -- Courtesy of chp2001
    -- takes a group of mass marker positions and will return the center point
    -- Mark Group definition = {MarkerGroup=1,Markers={{ Name="Mass 20", Position={ 159.5, 10.000610351563, 418.5, type="VECTOR3" }}}
    local xx1=0
    local yy1=0
    local zz1=0
    local nn1=0
    for key_1, marker_1 in massGroup.Markers do
        xx1=xx1+marker_1.Position[1]
        yy1=yy1+marker_1.Position[2]
        zz1=zz1+marker_1.Position[3]
        nn1=nn1 + 1
    end
    return {xx1/nn1,yy1/nn1,zz1/nn1}
end

function SetArcPoints(position,enemyPosition,radius,num,arclength)
    -- Courtesy of chp2001
    -- position = engineer position
    -- enemyPosition = base or assault point
    -- radius = distance from the enemyPosition
    -- num = number of points along the arc. Must be greater than 1.
    -- arclength - length of the arc in game units
    -- The radius impacts how large the arclength will be, the arclength has a maximum of around 32
    -- so to increase the width of the arc you also need to increase the radius.
    -- Example set
    -- local arcenemyBase = { 360.5, 10, 365.5, type="VECTOR3" }
    -- local arcengineer = { 233.5, 10, 386.5, type="VECTOR3" }
    -- RUtils.SetArcPoints(arcengineer, arcenemyBase, 80, 3, 30)

    local nnn=0
    local num1 = num-1
    local coords = {}
    local distvec = {position[1]-enemyPosition[1],position[3]-enemyPosition[3]}
    local angoffset = math.atan2(distvec[2],distvec[1])
    local arcangle = arclength/radius
    while nnn <= num1 do
        local xxx = 0
        local zzz = 0
        xxx = enemyPosition[1] + radius * math.cos (nnn/num1* (arcangle)+angoffset-arcangle/2)
        zzz = enemyPosition[3] + radius * math.sin (nnn/num1* (arcangle)+angoffset-arcangle/2)
        table.insert(coords, {xxx,0,zzz})
        nnn = nnn + 1
    end
    LOG('Resulting Table :'..repr(coords))
    return coords
end

function ExtractorsBeingUpgraded(aiBrain)
    -- Returns number of extractors upgrading

    local tech1ExtractorUpgrading = aiBrain:GetListOfUnits(categories.MASSEXTRACTION * categories.TECH1, false)
    local tech2ExtractorUpgrading = aiBrain:GetListOfUnits(categories.MASSEXTRACTION * categories.TECH2, false)
    local tech1ExtNumBuilding = 0
    local tech2ExtNumBuilding = 0
    -- own armyIndex
    local armyIndex = aiBrain:GetArmyIndex()
    -- loop over all units and search for upgrading units
    for t1extKey, t1extrator in tech1ExtractorUpgrading do
        if not t1extrator.Dead and not t1extrator:BeenDestroyed() and t1extrator:IsUnitState('Upgrading') and t1extrator:GetAIBrain():GetArmyIndex() == armyIndex then
            tech1ExtNumBuilding = tech1ExtNumBuilding + 1
        end
    end
    for t2extKey, t2extrator in tech2ExtractorUpgrading do
        if not t2extrator.Dead and not t2extrator:BeenDestroyed() and t2extrator:IsUnitState('Upgrading') and t2extrator:GetAIBrain():GetArmyIndex() == armyIndex then
            tech2ExtNumBuilding = tech2ExtNumBuilding + 1
        end
    end
    
    return {TECH1 = tech1ExtNumBuilding, TECH2 = tech2ExtNumBuilding}
end

