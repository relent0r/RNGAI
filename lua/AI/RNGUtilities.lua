local AIUtils = import('/lua/ai/AIUtilities.lua')
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local MarkerUtils = import("/lua/sim/MarkerUtilities.lua")
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
--local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()
local GetMarkersRNG = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local Utils = import('/lua/utilities.lua')
local NavUtils = import('/lua/sim/NavUtils.lua')
local MABC = import('/lua/editor/MarkerBuildConditions.lua')
local AIBehaviors = import('/lua/ai/AIBehaviors.lua')
local ToString = import('/lua/sim/CategoryUtils.lua').ToString
local GetCurrentUnits = moho.aibrain_methods.GetCurrentUnits
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt
local GetPlatoonPosition = moho.platoon_methods.GetPlatoonPosition
local GetConsumptionPerSecondMass = moho.unit_methods.GetConsumptionPerSecondMass
local GetConsumptionPerSecondEnergy = moho.unit_methods.GetConsumptionPerSecondEnergy
local GetProductionPerSecondMass = moho.unit_methods.GetProductionPerSecondMass
local GetProductionPerSecondEnergy = moho.unit_methods.GetProductionPerSecondEnergy
local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local PlatoonExists = moho.aibrain_methods.PlatoonExists
local ALLBPS = __blueprints
local WeakValueTable = { __mode = 'v' }

-- TEMPORARY LOUD LOCALS
local RNGPOW = math.pow
local RNGSQRT = math.sqrt
local RNGMAX = math.max
local RNGGETN = table.getn
local RNGINSERT = table.insert
local RNGREMOVE = table.remove
local RNGSORT = table.sort
local RNGTableEmpty = table.empty
local RNGFLOOR = math.floor
local RNGCEIL = math.ceil
local RNGPI = math.pi
local RNGCAT = table.cat
local RNGCOPY = table.copy
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

-- Cached categories
local CategoriesShield = categories.DEFENSE * categories.SHIELD * categories.STRUCTURE
local CategoriesLandDefense = categories.STRUCTURE * categories.DEFENSE * categories.DIRECTFIRE
local CategoriesSMD = categories.TECH3 * categories.ANTIMISSILE * categories.SILO

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
    
            It should be noted that calculateplatoonthreat does not use imap values but looks to perform a string search through the blueprints
            of the threat types. e.g there is no antisurface, but there is a surface. If you use a non valid threat type you will get overall.
        self:SetUpAttackVectorsToArmy(categories.STRUCTURE - (categories.MASSEXTRACTION))
        --RNGLOG('Attack Vectors'..repr(self:GetAttackVectors()))

        setfocusarmy -1 = back to observer
]]

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

function StartMoveDestination(self,destination)
    local NowPosition = self:GetPosition()
    local x, z, y = unpack(self:GetPosition())
    local count = 0
    IssueClearCommands({self})
    while x == NowPosition[1] and y == NowPosition[3] and count < 20 do
        count = count + 1
        IssueClearCommands({self})
        IssueMove( {self}, destination )
        coroutine.yield(10)
    end
end

---@param aiBrain AIBrain
---@param eng Unit
---@param movementLayer string
---@return number
---@return number
function EngFindReclaimCell(aiBrain, eng, movementLayer, searchType)
    -- Will find a reclaim grid cell to target for reclaim engineers
    -- requires the GridReclaim and GridBrain to have an instance against the 
    -- AI Brain, movementLayer is included for mods that have different layer engineers
    -- searchRadius could be improved to be dynamic
        -----------------------------------
    -- find a nearby cell to reclaim --

    -- @Relent0r this uses the newly introduced API to find nearby cells. Short descriptions:
    -- `MaximumInRadius`            Finds most valuable cell to reclaim in a radius
    -- `FilterInRadius`             Finds all cells that meets some threshold
    -- `FilterAndSortInRadius`      Finds all cells that meets some threshold and sorts the list of cells from high value to low value
    local CanPathTo = import("/lua/sim/navutils.lua").CanPathTo
    local reclaimGridInstance = aiBrain.GridReclaim
    local brainGridInstance = aiBrain.GridBrain
    local maxmapdimension = math.max(ScenarioInfo.size[1],ScenarioInfo.size[2])
    local searchRadius = 16
    if maxmapdimension == 256 then
        searchRadius = 8
    end
    if searchType == 'MAIN' then
        searchRadius = aiBrain.BrainIntel.IMAPConfig.Rings
    end
   --('Find reclaim cell, search radius is '..searchRadius)
    local searchLoop = 0
    local reclaimTargetX, reclaimTargetZ
    local engPos = eng:GetPosition()
    local gx, gz = reclaimGridInstance:ToGridSpace(engPos[1],engPos[3])
    while searchLoop < searchRadius and (not (reclaimTargetX and reclaimTargetZ)) do 
        WaitTicks(1)

        -- retrieve a list of cells with some mass value
        local cells, count = reclaimGridInstance:FilterAndSortInRadius(gx, gz, searchRadius, 10)
        -- find out if we can path to the center of the cell and check engineer maximums
        for k = 1, count do
            local cell = cells[k] --[[@as AIGridReclaimCell]]
            local centerOfCell = reclaimGridInstance:ToWorldSpace(cell.X, cell.Z)
            local maxEngineers = math.min(math.ceil(cell.TotalMass / 500), 8)
            -- make sure we can path to it and it doesnt have high threat e.g Point Defense
            if CanPathTo(movementLayer, engPos, centerOfCell) and aiBrain:GetThreatAtPosition(centerOfCell, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface') < 10 then
                local brainCell = brainGridInstance:ToCellFromGridSpace(cell.X, cell.Z)
                local engineersInCell = brainGridInstance:CountReclaimingEngineers(brainCell)
                if engineersInCell < maxEngineers then
                    reclaimTargetX, reclaimTargetZ = cell.X, cell.Z
                    break
                end
            end
        end
        searchLoop = searchLoop + 1
    end
    if reclaimTargetX and reclaimTargetZ then
        --LOG('Returned reclaim target of X:'..reclaimTargetX..' Z:'..reclaimTargetZ)
        return reclaimTargetX, reclaimTargetZ
    end
end

-- Get the military operational areas of the map. Credit to Uveso, this is based on his zones but a little more for small map sizes.
function GetOpAreaRNG(bool)
    -- Military area is slightly less than half the map size (10x10map) or maximal 200.
    -- We try to use playable area so that we take into account map gen maps.
    local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
    local playableMapSizes = { playableArea[3], playableArea[4] }
    local mapSizes
    if playableMapSizes[1] and playableMapSizes[2] then
        mapSizes = playableMapSizes
    else
        mapSizes = { ScenarioInfo.size[1], ScenarioInfo.size[2] }
    end
    local BaseMilitaryArea = math.max( mapSizes[1]-50, mapSizes[2]-50 ) / 2.2
    BaseMilitaryArea = math.max( 180, BaseMilitaryArea )
    -- DMZ is half the map. Mainly used for air formers
    local BaseDMZArea = math.max( mapSizes[1]-40, mapSizes[2]-40 ) / 2
    -- Restricted Area is half the BaseMilitaryArea. That's a little less than 1/4 of a 10x10 map
    local BaseRestrictedArea = BaseMilitaryArea / 2
    -- Make sure the Restricted Area is not smaller than 50 or greater than 100
    BaseRestrictedArea = math.max( 60, BaseRestrictedArea )
    BaseRestrictedArea = math.min( 120, BaseRestrictedArea )
    -- The rest of the map is enemy area
    local BaseEnemyArea = math.max( mapSizes[1], mapSizes[2] ) * 1.5
    -- "bool" is only true if called from "AIBuilders/Mobile Land.lua", so we only print this once.
    if bool then
        --RNGLOG('* RNGAI: BaseRestrictedArea= '..math.floor( BaseRestrictedArea * 0.01953125 ) ..' Km - ('..BaseRestrictedArea..' units)' )
        --RNGLOG('* RNGAI: BaseMilitaryArea= '..math.floor( BaseMilitaryArea * 0.01953125 )..' Km - ('..BaseMilitaryArea..' units)' )
        --RNGLOG('* RNGAI: BaseDMZArea= '..math.floor( BaseDMZArea * 0.01953125 )..' Km - ('..BaseDMZArea..' units)' )
        --RNGLOG('* RNGAI: BaseEnemyArea= '..math.floor( BaseEnemyArea * 0.01953125 )..' Km - ('..BaseEnemyArea..' units)' )
    end
    return BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea
end

function EngineerTryReclaimCaptureArea(aiBrain, eng, pos, pointRadius)
    if not pos then
        return false
    end
    if not pointRadius then
        pointRadius = 10
    end
    local Reclaiming = false
    --Temporary for troubleshooting
    --local GetBlueprint = moho.entity_methods.GetBlueprint
    -- Check if enemy units are at location
    local checkUnits = GetUnitsAroundPoint(aiBrain, (categories.STRUCTURE + categories.MOBILE) - categories.AIR, pos, pointRadius, 'Enemy')
    -- reclaim units near our building place.
    if checkUnits and not table.empty(checkUnits) then
        for num, unit in checkUnits do
            --temporary for troubleshooting
            --unitdesc = GetBlueprint(unit).Description
            if unit.Dead or unit:BeenDestroyed() then
                continue
            end
            if not IsEnemy( aiBrain:GetArmyIndex(), unit:GetAIBrain():GetArmyIndex() ) then
                continue
            end
            if unit:IsCapturable() and not EntityCategoryContains(categories.TECH1 * (categories.MOBILE + categories.WALL), unit) and unit:GetFractionComplete() == 1 then 
                --RNGLOG('* AI-RNG: Unit is capturable and not category t1 mobile'..unitdesc)
                -- if we can capture the unit/building then do so
                unit.CaptureInProgress = true
                IssueCapture({eng}, unit)
            else
                --RNGLOG('* AI-RNG: We are going to reclaim the unit'..unitdesc)
                -- if we can't capture then reclaim
                unit.ReclaimInProgress = true
                IssueReclaim({eng}, unit)
            end
        end
        Reclaiming = true
    end
    -- reclaim rocks etc or we can't build mexes or hydros
    local Reclaimables = GetReclaimablesInRect(Rect(pos[1]-pointRadius, pos[3]-pointRadius, pos[1]+pointRadius, pos[3]+pointRadius))
    if Reclaimables and not table.empty( Reclaimables ) then
        for k,v in Reclaimables do
            if v.MaxMassReclaim and v.MaxMassReclaim >= 5 or v.MaxEnergyReclaim and v.MaxEnergyReclaim > 5 then
                IssueReclaim({eng}, v)
            end
        end
    end
    return Reclaiming
end

function CheckReclaimSafety(aiBrain)
    local candidates = cache or { }
    local head = 1
    local cells = aiBrain.ReclaimGrid.Cells
    local gridPresence = aiBrain.GridPresence
    for lx = -radius, radius do
        local column = cells[bx + lx]
        if column then
            for lz = -radius, radius do
                local cell = column[bz + lz]
                if cell then
                    if cell.TotalMass >= threshold then
                        candidates[head] = cell
                        head = head + 1
                    end
                end
            end
        end
    end
    return candidates, head - 1
end

function EngineerTryRepair(aiBrain, eng, whatToBuild, pos)
    if not pos then
        return false
    end
    local structureCat = ParseEntityCategory(whatToBuild)
    local checkUnits = GetUnitsAroundPoint(aiBrain, structureCat, pos, 1, 'Ally')
    if checkUnits and not table.empty(checkUnits) then
        for num, unit in checkUnits do
            IssueRepair({eng}, unit)
        end
        return true
    end

    return false
end

function AIFindStartLocationNeedsEngineerRNG(aiBrain, locationType, radius, tMin, tMax, tRings, tType, eng)
    local pos = aiBrain.BuilderManagers[locationType].EngineerManager.Location
    if not pos then
        return false
    end

    local validPos = {}

    local positions = AIUtils.AIGetMarkersAroundLocationRNG(aiBrain, 'Spawn', pos, radius, tMin, tMax, tRings, tType)
    local startX, startZ = aiBrain:GetArmyStartPos()
    --LOG('positions '..repr(positions))
    for _, v in positions do
        if startX ~= v.Position[1] and startZ ~= v.Position[3] then
            table.insert(validPos, v)
        end
    end
    --LOG('Valid Pos table '..repr(validPos))

    local retPos, retName
    if eng then
        retPos, retName = AIUtils.AIFindMarkerNeedsEngineerThreatRNG(aiBrain, eng:GetPosition(), radius, tMin, tMax, tRings, tType, validPos)
    else
        retPos, retName = AIUtils.AIFindMarkerNeedsEngineerThreatRNG(aiBrain, pos, radius, tMin, tMax, tRings, tType, validPos)
    end

    return retPos, retName
end

function AIGetMassMarkerLocations(aiBrain, includeWater, waterOnly)
    local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
    local adaptiveResourceMarkers = GetMarkersRNG()
    local markerList = {}
    for k, v in adaptiveResourceMarkers do
        if v.type == 'Mass' then
            if v.position[1] > playableArea[1] and v.position[1] < playableArea[3] and v.position[3] > playableArea[2] and v.position[3] < playableArea[4] then
                if waterOnly then
                    if v.Water then
                        table.insert(markerList, {Position = v.position, Name = k})
                    end
                elseif includeWater then
                    table.insert(markerList, {Position = v.position, Name = k})
                else
                    if not v.Water then
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

function GetClosestMassMarkerToPos(aiBrain, pos)
    local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
    local adaptiveResourceMarkers = GetMarkersRNG()
    local markerList = {}
        for k, v in adaptiveResourceMarkers do
            if v.type == 'Mass' then
                if v.position[1] > playableArea[1] and v.position[1] < playableArea[3] and v.position[3] > playableArea[2] and v.position[3] < playableArea[4] then
                    table.insert(markerList, {Position = v.position, Name = k})
                end
            end
        end
    local loc, distance, lowest, name = nil

    for _, v in markerList do
        local x = v.Position[1]
        local y = v.Position[2]
        local z = v.Position[3]
        distance = VDist2Sq(pos[1], pos[3], x, z)
        if (not lowest or distance < lowest) and CanBuildStructureAt(aiBrain, 'ueb1103', v.Position) then
            --RNGLOG('Can build at position '..repr(v.Position))
            loc = v.Position
            name = v.Name
            lowest = distance
        else
            --RNGLOG('Cant build at position '..repr(v.Position))
        end
    end

    return loc, name
end

function GetClosestMassMarker(aiBrain, unit)
    local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
    local adaptiveResourceMarkers = GetMarkersRNG()
    local markerList = {}
    for k, v in adaptiveResourceMarkers do
        if v.type == 'Mass' then
            if v.position[1] > playableArea[1] and v.position[1] < playableArea[3] and v.position[3] > playableArea[2] and v.position[3] < playableArea[4] then
                table.insert(markerList, {Position = v.position, Name = k})
            end
        end
    end

    local engPos = unit:GetPosition()
    local loc, distance, lowest, name = nil

    for _, v in markerList do
        local x = v.Position[1]
        local y = v.Position[2]
        local z = v.Position[3]
        distance = VDist2Sq(engPos[1], engPos[3], x, z)
        if (not lowest or distance < lowest) and CanBuildStructureAt(aiBrain, 'ueb1103', v.Position) then
            loc = v.Position
            name = v.Name
            lowest = distance
        end
    end

    return loc, name
end

function GetLastACUPosition(aiBrain, enemyIndex)
    local acuPos = {}
    local lastSpotted = 0
    if aiBrain.EnemyIntel.ACU then
        for k, v in aiBrain.EnemyIntel.ACU do
            if v.Position[1] and k == enemyIndex then
                acuPos = v.Position
                lastSpotted = v.LastSpotted
                --RNGLOG('* AI-RNG: acuPos has data')
            else
                --RNGLOG('* AI-RNG: acuPos is currently false')
            end
        end
    end
    return acuPos, lastSpotted
end


function lerpy(vec1, vec2, distance)
    -- Courtesy of chp2001
    -- note the distance param is {distance, distance - weapon range}
    -- vec1 is friendly unit, vec2 is enemy unit
    local distanceFrac = distance[2] / distance[1]
    local x = vec1[1] * (1 - distanceFrac) + vec2[1] * distanceFrac
    local y = vec1[2] * (1 - distanceFrac) + vec2[2] * distanceFrac
    local z = vec1[3] * (1 - distanceFrac) + vec2[3] * distanceFrac
    return {x,y,z}
end

function LerpyRotate(vec1, vec2, distance)
    -- Courtesy of chp2001
    -- note the distance param is {distance, weapon range}
    -- vec1 is friendly unit, vec2 is enemy unit
    -- Had to add more documentation cause I suck at maths
    -- distance[1] is the degrees from vec2 e.g 90 is right, -90 is left
    -- distance[2] is the distance from vec2
    -- So for say acu support, vec1 is the enemy position, vec2 is the acu position, distance[1] is degrees right or left.
    -- then distance[2] is how far from the acu they will stand
    -- Actually thats still not right, I dont fully understand what distance[1] does, yea I know just learn vectors
    local distanceFrac = distance[2] / distance[1]
    local z = vec2[3] + distanceFrac * (vec2[1] - vec1[1])
    local y = vec2[2] - distanceFrac * (vec2[2] - vec1[2])
    local x = vec2[1] - distanceFrac * (vec2[3] - vec1[3])
    return {x,y,z}
end

-- This is softles, I was curious to see what it looked like compared to lerpy. Used in scouts avoiding enemy tanks.
function AvoidLocation(pos,target,dist)
    if not target then
        return pos
    elseif not pos then
        return target
    end
    local delta = VDiff(target,pos)
    local norm = math.max(VDist2(delta[1],delta[3],0,0),1)
    local x = pos[1]+dist*delta[1]/norm
    local z = pos[3]+dist*delta[3]/norm
    x = math.min(ScenarioInfo.size[1]-5,math.max(5,x))
    z = math.min(ScenarioInfo.size[2]-5,math.max(5,z))
    return {x,GetTerrainHeight(x,z),z}
end

function HaveUnitVisual(aiBrain, unit, checkBlipOnly)
    -- This was from Maudlin. He figured how to leverage blips better.
    --returns true if aiBrain can see a unit
    --checkBlipOnly - returns true if can see a blip
    --RNGLOG('HaveUnitVisual : Check if available')
    if ScenarioInfo.Options.OmniCheat == "on" then
        return true
    end
    local iArmyIndex = aiBrain:GetArmyIndex()
    if checkBlipOnly == nil then checkBlipOnly = false end
    local unitBrain
    if not unit.Dead and unit.GetAIBrain then
        unitBrain = unit:GetAIBrain()
    end
    if unitBrain and unitBrain:GetArmyIndex() == iArmyIndex then 
        return true
    else
        local bCanSeeUnit = false
        if not(unit.Dead) then
            if not(unit.GetBlip) then
                if unit.GetPosition then
                    return true
                end
            else
                local blip = unit:GetBlip(iArmyIndex)
                if blip then
                    if checkBlipOnly then 
                        return true
                    elseif blip:IsSeenEver(iArmyIndex) then 
                        return true 
                    end
                end
            end
        end
    end
    return false
end

function MoveInDirection(tStart, iAngle, iDistance, bKeepInMapBounds, bTravelUnderwater)
    -- This is Maudlins code 
    --iAngle: 0 = north, 90 = east, etc.; use GetAngleFromAToB if need angle from 2 positions
    --tStart = {x,y,z} (y isnt used)
    --if bKeepInMapBounds is true then will limit to map bounds
    --bTravelUnderwater - if true then will get the terrain height instead of the surface height
    local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
    local function ConvertAngleToRadians(iAngle)
        return iAngle * math.pi / 180
    end
    local iTheta = ConvertAngleToRadians(iAngle)
    --if bDebugMessages == true then LOG(sFunctionRef..': iAngle='..(iAngle or 'nil')..'; iTheta='..(iTheta or 'nil')..'; iDistance='..(iDistance or 'nil')) end
    local iXAdj = math.sin(iTheta) * iDistance
    local iZAdj = -math.cos(iTheta) * iDistance
    --local iXAdj = math.cos(iTheta) * iDistance * iFactor[1]
    --local iZAdj = math.sin(iTheta) * iDistance * iFactor[2]


    if not(bKeepInMapBounds) then
        --if bDebugMessages == true then LOG(sFunctionRef..': Are within map bounds, iXAdj='..iXAdj..'; iZAdj='..iZAdj..'; iTheta='..iTheta..'; position='..repru({tStart[1] + iXAdj, GetSurfaceHeight(tStart[1] + iXAdj, tStart[3] + iZAdj), tStart[3] + iZAdj})) end
        if bTravelUnderwater then
            return {tStart[1] + iXAdj, GetTerrainHeight(tStart[1] + iXAdj, tStart[3] + iZAdj), tStart[3] + iZAdj}
        else
            return {tStart[1] + iXAdj, GetSurfaceHeight(tStart[1] + iXAdj, tStart[3] + iZAdj), tStart[3] + iZAdj}
        end
    else
        local tTargetPosition
        if bTravelUnderwater then
            tTargetPosition = {tStart[1] + iXAdj, GetTerrainHeight(tStart[1] + iXAdj, tStart[3] + iZAdj), tStart[3] + iZAdj}
        else
            tTargetPosition = {tStart[1] + iXAdj, GetSurfaceHeight(tStart[1] + iXAdj, tStart[3] + iZAdj), tStart[3] + iZAdj}
        end
        --Get actual distance required to keep within map bounds
        --local iMaxDistanceFlat = 0
        local iNewDistWanted = 10000
        --rMapPlayableArea = 2 --{x1,z1, x2,z2} - Set at start of the game, use instead of the scenarioinfo method
        if tTargetPosition[1] < playableArea[1] then iNewDistWanted = iDistance * (tStart[1] - playableArea[1]) / (tStart[1] - tTargetPosition[1]) end
        if tTargetPosition[3] < playableArea[2] then iNewDistWanted = math.min(iNewDistWanted, iDistance * (tStart[3] - playableArea[2]) / (tStart[3] - tTargetPosition[3])) end
        if tTargetPosition[1] > playableArea[3] then iNewDistWanted = math.min(iNewDistWanted, iDistance * (playableArea[3] - tStart[1]) / (tTargetPosition[1] - tStart[1])) end
        if tTargetPosition[3] > playableArea[4] then iNewDistWanted = math.min(iNewDistWanted, iDistance * (playableArea[4] - tStart[3]) / (tTargetPosition[3] - tStart[3])) end

        if iNewDistWanted == 10000 then
            return tTargetPosition
        else
            --Are out of playable area, so adjust the position; Can use the ratio of the amount we have moved left/right or top/down vs the long line length to work out the long line length if we reduce the left/right so its within playable area
            return MoveInDirection(tStart, iAngle, iNewDistWanted - 0.1, false)
        end
    end
end

function AIFindBrainTargetInRangeOrigRNG(aiBrain, position, platoon, squad, maxRange, atkPri)
    if not position then
        position = platoon:GetPlatoonPosition()
    end
    if not aiBrain or not position or not maxRange or not platoon then
        return false
    end
    local VDist2 = VDist2
    local RangeList = { [1] = maxRange }
    if maxRange > 512 then
        RangeList = {
            [1] = 30,
            [2] = 64,
            [3] = 128,
            [4] = 192,
            [5] = 256,
            [6] = 384,
            [7] = 512,
            [8] = maxRange,
        }
    elseif maxRange > 256 then
        RangeList = {
            [1] = 30,
            [2] = 64,
            [3] = 128,
            [4] = 192,
            [5] = 256,
            [6] = maxRange,
        }
    elseif maxRange > 64 then
        RangeList = {
            [1] = 30,
            [2] = maxRange,
        }
    end

    for _, range in RangeList do
        local targetUnits = GetUnitsAroundPoint(aiBrain, categories.ALLUNITS - categories.INSIGNIFICANTUNIT, position, maxRange, 'Enemy')
        for _, v in atkPri do
            local category = v
            if type(category) == 'string' then
                category = ParseEntityCategory(category)
            end
            local retUnit = false
            local retDistance = false
            for num, unit in targetUnits do
                if not unit.Dead and not unit.CaptureInProgress and EntityCategoryContains(category, unit) and platoon:CanAttackTarget(squad, unit) then
                    local unitPos = unit:GetPosition()
                    if platoon.Defensive and aiBrain.GridPresence then
                        if aiBrain.GridPresence:GetInferredStatus(unitPos) == 'Hostile' then
                            continue
                        end
                    end
                    local dx = unitPos[1] - position[1]
                    local dz = unitPos[3] - position[3]
                    local distance = dx * dx + dz * dz
                    if not retUnit or distance < retDistance then
                        retUnit = unit
                        retDistance = distance
                    end
                end
            end
            if retUnit then
                return retUnit
            end
        end
    end

    return false
end

function PositionOnWater(positionX, positionZ)
    --Check if a position is under water. Used to identify if threat/unit position is over water
    -- Terrain >= Surface = Target is on land
    -- Terrain < Surface = Target is in water
    if positionX and positionZ then
        return GetTerrainHeight( positionX, positionZ ) < GetSurfaceHeight( positionX, positionZ )
    end
    return false
end

function ManualBuildQueueItem(aiBrain, eng, structureToBuild, adjacent, category)
    --[[
        Example
            
        local buildLocation, whatToBuild = RUtils.ManualBuildQueueItem(aiBrain, eng, 'T1AirFactory', true, categories.HYDROCARBON)
        if buildLocation and whatToBuild then
            local newEntry = {whatToBuild, buildLocation, true, BorderWarning=false}
            RNGINSERT(eng.EngineerBuildQueue, newEntry)
        end

    ]]

    if not eng or eng.Dead or not structureToBuild then
        return
    end
    local factionIndex = aiBrain:GetFactionIndex()
    local baseTmplFile = import('/lua/BaseTemplates.lua')
    local buildingTmplFile = import('/lua/BuildingTemplates.lua')
    local buildingTmpl = buildingTmplFile[('BuildingTemplates')][factionIndex]
    local buildLocation, whatToBuild, borderWarning = GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplFile['BaseTemplates'][factionIndex], structureToBuild, eng, adjacent, category, 15, true)
    if buildLocation and whatToBuild then
        return buildLocation, whatToBuild
    end
    return false
end

--[[
function ManualBuildStructure(aiBrain, eng, structureType, tech, position)
    -- Usage ManualBuildStructure(aiBrain, engineerunit, 'AntiSurface', 'TECH2', {123:20:123})
    local factionIndex = aiBrain:GetFactionIndex()
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
    local blueprintID = DefenseTable[factionIndex][structureType][tech]
    if CanBuildStructureAt(aiBrain, blueprintID, position) then
        IssueStop({eng})
        IssueClearCommands({eng})
        aiBrain:BuildStructure(eng, blueprintID, position, false)
    end
end]]

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
        coroutine.yield(1)
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
        coroutine.yield(1)
    end
    --RNGLOG('Resulting Table :'..repr(coords))
    return coords
end

function AIAdvancedFindACUTargetRNG(aiBrain, cdrPos, movementLayer, maxRange, basePosition, cdrThreat)

    if not cdrPos then
        cdrPos = aiBrain.CDRUnit.Position
    end
    if not maxRange then
        maxRange = aiBrain.CDRUnit.MaxBaseRange
    end
    if not movementLayer then
        movementLayer = 'Amphibious'
    end
    if not basePosition then
        basePosition = aiBrain.BuilderManagers['MAIN'].Position
    end
    if not cdrThreat then
        cdrThreat = aiBrain.CDRUnit:EnhancementThreatReturn()
    end
    local operatingArea = aiBrain.OperatingAreas['BaseMilitaryArea']
    local RangeList = {
        [1] = 30,
        [2] = 64,
        [3] = 128,
        [4] = 192,
        [5] = 256,
        [6] = 384,
        [7] = 512,
        [8] = maxRange,
    }
    local targetUnits = {}
    local mobileTargets = { }
    local mobileThreat = 0
    local structureTargets = { }
    local oportunisticTargets = {}
    local structureThreat = 0
    local enemyACUTargets = {}
    local defenseTargets = {}
    local returnAcu = false
    local returnTarget = false
    local highThreat = 0
    local acuDistanceToBase = VDist3Sq(cdrPos, basePosition)
    if aiBrain.BasePerimeterMonitor['MAIN'].LandThreat > 15 then
        --RNGLOG('High Threat at main base, get target from there')
        cdrPos = aiBrain.BuilderManagers['MAIN'].Position
    end
    local closestDistance = false
    local closestTarget = false
    local closestTargetPosition = false
    local enemyACUPresent
    --RNGLOG('ACUTARGETTING : MaxRange on target search '..maxRange)
    for _, range in RangeList do
        if maxRange > range then
            targetUnits = GetUnitsAroundPoint(aiBrain, categories.ALLUNITS - categories.AIR - categories.SCOUT - categories.INSIGNIFICANTUNIT, cdrPos, range, 'Enemy')
            for _, target in targetUnits do
                if not target.Dead then
                    local targetPos = target:GetPosition()
                    local rx = cdrPos[1] - targetPos[1]
                    local rz = cdrPos[3] - targetPos[3]
                    local targetDistance = rx * rx + rz * rz
                    if target.Blueprint.CategoriesHash.COMMAND then
                        if target.EntityId and not enemyACUTargets[target.EntityId] then
                            enemyACUTargets[target.EntityId] = { unit = target, position = targetPos, distance = targetDistance }
                        end
                    elseif target.Blueprint.CategoriesHash.MOBILE then
                        if target.EntityId and not mobileTargets[target.EntityId] then
                            mobileTargets[target.EntityId] = { unit = target, position = targetPos, distance = targetDistance }
                        end
                    elseif target.Blueprint.CategoriesHash.STRUCTURE then
                        if target.EntityId and not structureTargets[target.EntityId] then
                            structureTargets[target.EntityId] = { unit = target, position = targetPos, distance = targetDistance }
                            structureThreat = structureThreat + target.Blueprint.Defense.SurfaceThreatLevel
                        end
                    end
                    if not closestDistance or targetDistance < closestDistance then
                        closestDistance = targetDistance
                        closestTarget = target
                        closestTargetPosition = targetPos
                    end
                end
            end
        end
    end
    if not returnTarget then
        if not RNGTableEmpty(structureTargets) then
            table.sort(structureTargets, function(a,b) return a.distance < b.distance end)
            --RNGLOG('ACUTARGETTING : Mobile Targets are within range')
            for k, v in structureTargets do
                local unitCat = v.unit.Blueprint.CategoriesHash
                if v.distance < 14400 then
                    if unitCat.DEFENSE and (unitCat.DIRECTFIRE or unitCat.INDIRECTFIRE) then
                        table.insert(defenseTargets, v)
                    end
                end
                if unitCat.MASSEXTRACTION then
                    oportunisticTargets[v.unit.EntityId] = v
                    continue
                end
                if not v.unit:BeenDestroyed() then
                    local surfaceThreat = GetThreatAtPosition(aiBrain, v.position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface')
                    if v.distance < math.min(closestDistance * 2,closestDistance + 30) and surfaceThreat < math.max(55, cdrThreat) 
                    or (acuDistanceToBase < 6400 and unitCat.DEFENSE and (unitCat.DIRECTFIRE or unitCat.INDIRECTFIRE)) then
                        local cdrLayer = aiBrain.CDRUnit:GetCurrentLayer()
                        local targetLayer = v.unit:GetCurrentLayer()
                        if not (cdrLayer == 'Land' and (targetLayer == 'Air' or targetLayer == 'Sub' or targetLayer == 'Seabed')) and
                        not (cdrLayer == 'Seabed' and (targetLayer == 'Air' or targetLayer == 'Water')) then
                            if NavUtils.CanPathTo('Land', v.position, cdrPos) then
                                --RNGLOG('ACUTARGETTING : returnTarget set in for loop for mobileTargets')
                                returnTarget = v.unit
                                break
                            elseif NavUtils.CanPathTo('Amphibious', v.position, cdrPos) and v.distance < (operatingArea * operatingArea) then
                                returnTarget = v.unit
                                break
                            end
                        end
                    elseif v.distance < (closestDistance * 2) and GetThreatAtPosition(aiBrain, v.position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'Commander') > 0 then
                        local enemyUnits = GetUnitsAroundPoint(aiBrain, (categories.STRUCTURE * categories.DEFENSE - categories.WALL) + (categories.MOBILE * (categories.LAND + categories.AIR) - categories.SCOUT ), v.position, 50, 'Enemy')
                        local enemyUnitThreat = 0
                        for _,c in enemyUnits do
                            if c and not c.Dead then
                                if c.Blueprint.CategoriesHash.COMMAND then
                                    enemyACUPresent = true
                                    enemyUnitThreat = enemyUnitThreat + c:EnhancementThreatReturn()
                                else
                                    enemyUnitThreat = enemyUnitThreat + c.Blueprint.Defense.SurfaceThreatLevel
                                end
                            end
                        end
                        if enemyUnitThreat < math.max(55, cdrThreat) then
                            local cdrLayer = aiBrain.CDRUnit:GetCurrentLayer()
                            local targetLayer = v.unit:GetCurrentLayer()
                            if not (cdrLayer == 'Land' and (targetLayer == 'Air' or targetLayer == 'Sub' or targetLayer == 'Seabed')) and
                            not (cdrLayer == 'Seabed' and (targetLayer == 'Air' or targetLayer == 'Water')) then
                                if NavUtils.CanPathTo('Land', v.position, cdrPos) then
                                    --RNGLOG('ACUTARGETTING : returnTarget set in for loop for mobileTargets')
                                    returnTarget = v.unit
                                    break
                                elseif NavUtils.CanPathTo('Amphibious', v.position, cdrPos) and v.distance < (operatingArea * operatingArea) then
                                    returnTarget = v.unit
                                    break
                                end
                            end
                        end
                    else
                        highThreat = highThreat + surfaceThreat
                        --RNGLOG('ACUTARGETTING : Mobile Threat too high at target location structure')
                    end
                end
                
            end
        end
    end
    if not RNGTableEmpty(enemyACUTargets) then
        table.sort(enemyACUTargets, function(a,b) return a.distance < b.distance end)
        --RNGLOG('ACUTARGETTING : ACU Targets are within range')
        for k, v in enemyACUTargets do
            if not v.unit:BeenDestroyed() then
                if v.distance < 900 then
                    local cdrLayer = aiBrain.CDRUnit:GetCurrentLayer()
                    local targetLayer = v.unit:GetCurrentLayer()
                    if not (cdrLayer == 'Land' and (targetLayer == 'Air' or targetLayer == 'Sub' or targetLayer == 'Seabed')) and
                       not (cdrLayer == 'Seabed' and (targetLayer == 'Air' or targetLayer == 'Water')) then
                        if NavUtils.CanPathTo('Land', v.position, cdrPos) then
                            --RNGLOG('ACUTARGETTING : returnTarget set in for loop for mobileTargets')
                            returnTarget = v.unit
                            returnAcu = true
                            break
                        elseif NavUtils.CanPathTo('Amphibious', v.position, cdrPos) and v.distance < (operatingArea * operatingArea) then
                            returnTarget = v.unit
                            returnAcu = true
                            break
                        end
                    end
                end
                local surfaceThreat = GetThreatAtPosition(aiBrain, v.position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface')
                --RNGLOG('ACU distance '..v.distance..' closest distance '..(closestDistance * 2))
                --RNGLOG('Commander threat is '..GetThreatAtPosition(aiBrain, v.position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'Commander'))
                if VDist3Sq(v.position, basePosition) < acuDistanceToBase then
                    local cdrLayer = aiBrain.CDRUnit:GetCurrentLayer()
                    local targetLayer = v.unit:GetCurrentLayer()
                    if not (cdrLayer == 'Land' and (targetLayer == 'Air' or targetLayer == 'Sub' or targetLayer == 'Seabed')) and
                       not (cdrLayer == 'Seabed' and (targetLayer == 'Air' or targetLayer == 'Water')) then
                        if NavUtils.CanPathTo('Land', v.position, cdrPos) then
                            --RNGLOG('ACUTARGETTING : returnTarget set in for loop for mobileTargets')
                            returnTarget = v.unit
                            returnAcu = true
                            break
                        elseif NavUtils.CanPathTo('Amphibious', v.position, cdrPos) and v.distance < (operatingArea * operatingArea) then
                            returnTarget = v.unit
                            returnAcu = true
                            break
                        end
                    end
                end
                if v.distance < (closestDistance * 2) and surfaceThreat < math.max(55, cdrThreat) or acuDistanceToBase < 6400 then
                    local cdrLayer = aiBrain.CDRUnit:GetCurrentLayer()
                    local targetLayer = v.unit:GetCurrentLayer()
                    if not (cdrLayer == 'Land' and (targetLayer == 'Air' or targetLayer == 'Sub' or targetLayer == 'Seabed')) and
                       not (cdrLayer == 'Seabed' and (targetLayer == 'Air' or targetLayer == 'Water')) then
                        if NavUtils.CanPathTo('Land', v.position, cdrPos) then
                            --RNGLOG('ACUTARGETTING : returnTarget set in for loop for mobileTargets')
                            returnTarget = v.unit
                            returnAcu = true
                            break
                        elseif NavUtils.CanPathTo('Amphibious', v.position, cdrPos) and v.distance < (operatingArea * operatingArea) then
                            returnTarget = v.unit
                            returnAcu = true
                            break
                        end
                    end
                elseif v.distance < (closestDistance * 2) and GetThreatAtPosition(aiBrain, v.position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'Commander') > 0 then
                    local enemyUnits = GetUnitsAroundPoint(aiBrain, (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE - categories.SCOUT), v.position, 50, 'Enemy')
                    local enemyUnitThreat = 0
                    for _,c in enemyUnits do
                        if c and not c.Dead then
                            if c.Blueprint.CategoriesHash.COMMAND then
                                enemyACUPresent = true
                                enemyUnitThreat = enemyUnitThreat + c:EnhancementThreatReturn()
                            else
                                enemyUnitThreat = enemyUnitThreat + c.Blueprint.Defense.SurfaceThreatLevel
                            end
                        end
                    end
                    --RNGLOG('Enemy CDR Threat present real threat is '..enemyUnitThreat)
                    if enemyUnitThreat < math.max(55, cdrThreat) then
                        local cdrLayer = aiBrain.CDRUnit:GetCurrentLayer()
                        local targetLayer = v.unit:GetCurrentLayer()
                        if not (cdrLayer == 'Land' and (targetLayer == 'Air' or targetLayer == 'Sub' or targetLayer == 'Seabed')) and
                        not (cdrLayer == 'Seabed' and (targetLayer == 'Air' or targetLayer == 'Water')) then
                            if NavUtils.CanPathTo('Land', v.position, cdrPos) then
                                --RNGLOG('ACUTARGETTING : returnTarget set in for loop for mobileTargets')
                                returnTarget = v.unit
                                returnAcu = true
                                break
                            elseif NavUtils.CanPathTo('Amphibious', v.position, cdrPos) and v.distance < (operatingArea * operatingArea) then
                                returnTarget = v.unit
                                returnAcu = true
                                break
                            end
                        end
                    end
                else
                    highThreat = highThreat + surfaceThreat
                    --RNGLOG('ACUTARGETTING : ACU Threat too high at target location Mobile')
                end
            end
        end
    end
    if not returnTarget then
        if not RNGTableEmpty(mobileTargets) then
            table.sort(mobileTargets, function(a,b) return a.distance < b.distance end)
            --RNGLOG('ACUTARGETTING : Mobile Targets are within range')
            for k, v in mobileTargets do
                if not v.unit:BeenDestroyed() then
                    if not PositionInWater(v.position) then
                        local surfaceThreat = GetThreatAtPosition(aiBrain, v.position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface')
                        if v.distance < (closestDistance * 2) and surfaceThreat < math.max(55, cdrThreat) or acuDistanceToBase < 6400 or v.distance < 400 then
                            local cdrLayer = aiBrain.CDRUnit:GetCurrentLayer()
                            local targetLayer = v.unit:GetCurrentLayer()
                            if not (cdrLayer == 'Land' and (targetLayer == 'Air' or targetLayer == 'Sub' or targetLayer == 'Seabed')) and
                            not (cdrLayer == 'Seabed' and (targetLayer == 'Air' or targetLayer == 'Water')) then
                                if NavUtils.CanPathTo('Land', v.position, cdrPos) then
                                    --RNGLOG('ACUTARGETTING : returnTarget set in for loop for mobileTargets')
                                    returnTarget = v.unit
                                    break
                                elseif NavUtils.CanPathTo('Amphibious', v.position, cdrPos) and v.distance < (operatingArea * operatingArea) then
                                    returnTarget = v.unit
                                    break
                                end
                            end
                        elseif v.distance < (closestDistance * 2) and GetThreatAtPosition(aiBrain, v.position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'Commander') > 0 then
                            local enemyUnits = GetUnitsAroundPoint(aiBrain, (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * (categories.LAND + categories.AIR) - categories.SCOUT ), v.position, 50, 'Enemy')
                            local enemyUnitThreat = 0
                            for _,c in enemyUnits do
                                if c and not c.Dead then
                                    if c.Blueprint.CategoriesHash.COMMAND then
                                        enemyACUPresent = true
                                        enemyUnitThreat = enemyUnitThreat + c:EnhancementThreatReturn()
                                    else
                                        enemyUnitThreat = enemyUnitThreat + c.Blueprint.Defense.SurfaceThreatLevel
                                    end
                                end
                            end
                            if enemyUnitThreat < math.max(55, cdrThreat) then
                                local cdrLayer = aiBrain.CDRUnit:GetCurrentLayer()
                                local targetLayer = v.unit:GetCurrentLayer()
                                if not (cdrLayer == 'Land' and (targetLayer == 'Air' or targetLayer == 'Sub' or targetLayer == 'Seabed')) and
                                not (cdrLayer == 'Seabed' and (targetLayer == 'Air' or targetLayer == 'Water')) then
                                    if NavUtils.CanPathTo('Land', v.position, cdrPos) then
                                        --RNGLOG('ACUTARGETTING : returnTarget set in for loop for mobileTargets')
                                        returnTarget = v.unit
                                        break
                                    elseif NavUtils.CanPathTo('Amphibious', v.position, cdrPos) and v.distance < (operatingArea * operatingArea) then
                                        returnTarget = v.unit
                                        break
                                    end
                                end
                            end
                        else
                            highThreat = highThreat + surfaceThreat
                            --RNGLOG('ACUTARGETTING : Mobile Threat too high at target location Mobile')
                        end
                    end
                end
            end
        end
    end
    if not returnTarget then
        if not RNGTableEmpty(oportunisticTargets) then
            table.sort(oportunisticTargets, function(a,b) return a.distance < b.distance end)
            --RNGLOG('ACUTARGETTING : Mobile Targets are within range')
            for k, v in oportunisticTargets do
                local unitCat = v.unit.Blueprint.CategoriesHash
                if not v.unit:BeenDestroyed() then
                    local surfaceThreat = GetThreatAtPosition(aiBrain, v.position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface')
                    if v.distance < (closestDistance * 2) and surfaceThreat < math.max(55, cdrThreat) or acuDistanceToBase < 6400 then
                        local cdrLayer = aiBrain.CDRUnit:GetCurrentLayer()
                        local targetLayer = v.unit:GetCurrentLayer()
                        if not (cdrLayer == 'Land' and (targetLayer == 'Air' or targetLayer == 'Sub' or targetLayer == 'Seabed')) and
                        not (cdrLayer == 'Seabed' and (targetLayer == 'Air' or targetLayer == 'Water')) then
                            if NavUtils.CanPathTo('Land', v.position, cdrPos) then
                                --RNGLOG('ACUTARGETTING : returnTarget set in for loop for mobileTargets')
                                returnTarget = v.unit
                                break
                            elseif NavUtils.CanPathTo('Amphibious', v.position, cdrPos) and v.distance < (operatingArea * operatingArea) then
                                returnTarget = v.unit
                                break
                            end
                        end
                    elseif v.distance < (closestDistance * 2) and GetThreatAtPosition(aiBrain, v.position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'Commander') > 0 then
                        local enemyUnits = GetUnitsAroundPoint(aiBrain, (categories.STRUCTURE * categories.DEFENSE - categories.WALL) + (categories.MOBILE * (categories.LAND + categories.AIR) - categories.SCOUT ), v.position, 50, 'Enemy')
                        local enemyUnitThreat = 0
                        for _,c in enemyUnits do
                            if c and not c.Dead then
                                if c.Blueprint.CategoriesHash.COMMAND then
                                    enemyACUPresent = true
                                    enemyUnitThreat = enemyUnitThreat + c:EnhancementThreatReturn()
                                else
                                    enemyUnitThreat = enemyUnitThreat + c.Blueprint.Defense.SurfaceThreatLevel
                                end
                            end
                        end
                        if enemyUnitThreat < math.max(55, cdrThreat) then
                            local cdrLayer = aiBrain.CDRUnit:GetCurrentLayer()
                            local targetLayer = v.unit:GetCurrentLayer()
                            if not (cdrLayer == 'Land' and (targetLayer == 'Air' or targetLayer == 'Sub' or targetLayer == 'Seabed')) and
                            not (cdrLayer == 'Seabed' and (targetLayer == 'Air' or targetLayer == 'Water')) then
                                if NavUtils.CanPathTo('Land', v.position, cdrPos) then
                                    --RNGLOG('ACUTARGETTING : returnTarget set in for loop for mobileTargets')
                                    returnTarget = v.unit
                                    break
                                elseif NavUtils.CanPathTo('Amphibious', v.position, cdrPos) and v.distance < (operatingArea * operatingArea) then
                                    returnTarget = v.unit
                                    break
                                end
                            end
                        end
                    else
                        highThreat = highThreat + surfaceThreat
                        --RNGLOG('ACUTARGETTING : Mobile Threat too high at target location structure')
                    end
                end
                
            end
        end
    end
    if returnTarget then
        local targetPos = returnTarget:GetPosition()
        if highThreat < 1 then
            highThreat = GetThreatAtPosition(aiBrain, targetPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface')
        end
        if not aiBrain.ACUSupport.Supported then
            aiBrain.ACUSupport.Supported = true
            --RNGLOG('* AI-RNG: ACUSupport.Supported set to true')
            aiBrain.ACUSupport.TargetPosition = targetPos
        end
        --RNGLOG('ACUTARGETTING : Returning Target')
        return returnTarget, returnAcu, highThreat, closestDistance, closestTarget, closestTargetPosition, defenseTargets
    end
    --RNGLOG('No target being returned for ACU targeting')
    return returnTarget, returnAcu, highThreat, closestDistance, closestTarget, closestTargetPosition, defenseTargets
end

function AIFindBrainTargetInRangeRNG(aiBrain, position, platoon, squad, maxRange, atkPri, avoidbases, platoonThreat, index, ignoreCivilian, ignoreNotCompleted, navalOnly)
    if not position then
        position = platoon:GetPlatoonPosition()
    end
    local VDist2 = VDist2
    if platoon.PlatoonData.GetTargetsFromBase then
        --RNGLOG('Looking for targets from position '..platoon.PlatoonData.LocationType)
        position = aiBrain.BuilderManagers[platoon.PlatoonData.LocationType].Position
    end
    local enemyThreat, targetUnits, category, unit
    local RangeList = { [1] = maxRange }
    if not aiBrain or not position or not maxRange then
        return false
    end
    if not avoidbases then
        avoidbases = false
    end
    if not platoon.MovementLayer then
        AIAttackUtils.GetMostRestrictiveLayerRNG(platoon)
    end
    
    if maxRange > 512 then
        RangeList = {
            [1] = 30,
            [2] = 64,
            [3] = 128,
            [4] = 192,
            [5] = 256,
            [6] = 384,
            [7] = 512,
            [8] = maxRange,
        }
    elseif maxRange > 256 then
        RangeList = {
            [1] = 30,
            [2] = 64,
            [3] = 128,
            [4] = 192,
            [5] = 256,
            [6] = maxRange,
        }
    elseif maxRange > 64 then
        RangeList = {
            [1] = 30,
            [2] = maxRange,
        }
    end

    for _, range in RangeList do
        targetUnits = GetUnitsAroundPoint(aiBrain, categories.ALLUNITS - categories.INSIGNIFICANTUNIT, position, range, 'Enemy')
        for _, v in atkPri do
            category = v
            if type(category) == 'string' then
                category = ParseEntityCategory(category)
            end
            local retUnit = false
            local retDistance = false
            local targetShields = 9999
            for num, unit in targetUnits do
                if not unit.Dead and not unit.Tractored then
                    local unitCats = unit.Blueprint.CategoriesHash
                    if ignoreNotCompleted then
                        if unit:GetFractionComplete() ~= 1 then
                            continue
                        end
                    end
                    if index then
                        for k, v in index do
                            if unit:GetAIBrain():GetArmyIndex() == v then
                                if not unit.CaptureInProgress and EntityCategoryContains(category, unit) and platoon:CanAttackTarget(squad, unit) then
                                    local unitPos = unit:GetPosition()
                                    if navalOnly then
                                        if unitCats.HOVER or unitCats.AIR or not PositionInWater(unitPos) then
                                            continue
                                        end
                                    end
                                    if platoon.Defensive and aiBrain.GridPresence then
                                        if aiBrain.GridPresence:GetInferredStatus(unitPos) == 'Hostile' then
                                            continue
                                        end
                                    end
                                    local dx = unitPos[1] - position[1]
                                    local dz = unitPos[3] - position[3]
                                    local distance = dx * dx + dz * dz
                                    if not retUnit or distance < retDistance then
                                        retUnit = unit
                                        retDistance = distance
                                    end
                                    if platoon.MovementLayer == 'Air' and platoonThreat then
                                        enemyThreat = GetThreatAtPosition( aiBrain, unitPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')
                                        --RNGLOG('Enemy Threat is '..enemyThreat..' and my threat is '..platoonThreat)
                                        if enemyThreat > platoonThreat then
                                            continue
                                        end
                                    end
                                    local numShields = aiBrain:GetNumUnitsAroundPoint(CategoriesShield, unitPos, 46, 'Enemy')
                                    if not retUnit or numShields < targetShields or (numShields == targetShields and distance < retDistance) then
                                        retUnit = unit
                                        retDistance = distance
                                        targetShields = numShields
                                    end
                                end
                            end
                        end
                    else
                        if not unit.Dead and EntityCategoryContains(category, unit) and platoon:CanAttackTarget(squad, unit) then
                            if ignoreCivilian then
                                if ArmyIsCivilian(unit:GetArmy()) then
                                    --RNGLOG('Unit is civilian')
                                    continue
                                end
                            end
                            local unitPos = unit:GetPosition()
                            if navalOnly then
                                if unitCats.HOVER or unitCats.AIR or not PositionInWater(unitPos) then
                                    continue
                                end
                            end
                            if platoon.Defensive and aiBrain.GridPresence then
                                if aiBrain.GridPresence:GetInferredStatus(unitPos)  == 'Hostile' then
                                    continue
                                end
                            end
                            if avoidbases then
                                if not table.empty(aiBrain.EnemyIntel.EnemyStartLocations) then
                                    for _, start in aiBrain.EnemyIntel.EnemyStartLocations do
                                        local dx = unitPos[1] - start.Position[1]
                                        local dz = unitPos[3] - start.Position[3]
                                        local startDist = dx * dx + dz * dz
                                        if startDist < 22500 then
                                            continue
                                        end
                                    end
                                else
                                    for _, w in ArmyBrains do
                                        if IsEnemy(w:GetArmyIndex(), aiBrain:GetArmyIndex()) or (aiBrain:GetArmyIndex() == w:GetArmyIndex()) then
                                            local estartX, estartZ = w:GetArmyStartPos()
                                            local dx = unitPos[1] - estartX
                                            local dz = unitPos[3] - estartZ
                                            local startDist = dx * dx + dz * dz
                                            if startDist < 22500 then
                                                continue
                                            end
                                        end
                                    end
                                end
                            end
                            if platoon.MovementLayer == 'Air' and platoonThreat then
                                enemyThreat = GetThreatAtPosition( aiBrain, unitPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')
                                --RNGLOG('Enemy Threat is '..enemyThreat..' and my threat is '..platoonThreat)
                                if enemyThreat > platoonThreat then
                                    continue
                                end
                            end
                            local numShields = aiBrain:GetNumUnitsAroundPoint(CategoriesShield, unitPos, 46, 'Enemy')
                            local dx = unitPos[1] - position[1]
                            local dz = unitPos[3] - position[3]
                            local distance = dx * dx + dz * dz
                            if not retUnit or numShields < targetShields or (numShields == targetShields and distance < retDistance) then
                                retUnit = unit
                                retDistance = distance
                                targetShields = numShields
                            end
                        end
                    end
                end
            end
            if retUnit and targetShields > 0 and platoon.CurrentPlatoonThreatAntiSurface > 0 then
                local platoonUnits = platoon:GetPlatoonUnits()
                for _, w in platoonUnits do
                    if not w.Dead then
                        unit = w
                        break
                    end
                end
                local closestBlockingShield, shieldHealth = GetClosestShieldProtectingTargetRNG(unit, retUnit)
                if closestBlockingShield then
                    return closestBlockingShield, shieldHealth
                end
            end
            if retUnit then
                return retUnit
            end
        end
        coroutine.yield(1)
        if IsDestroyed(platoon) then
            return
        end
    end
    return false
end

function AIFindBrainTargetInACURangeRNG(aiBrain, position, platoon, squad, maxRange, atkPri, platoonThreat, ignoreCivilian, ignoreNotCompleted)
    if not position then
        position = platoon:GetPlatoonPosition()
    end
    local VDist2 = VDist2
    local enemyThreat, targetUnits, category
    local RangeList = { [1] = maxRange }
    if not aiBrain or not position or not maxRange then
        return false
    end
    if not platoon.MovementLayer then
        AIAttackUtils.GetMostRestrictiveLayerRNG(platoon)
    end
    
    if maxRange > 512 then
        RangeList = {
            [1] = 30,
            [2] = 64,
            [3] = 128,
            [4] = 192,
            [5] = 256,
            [6] = 384,
            [7] = 512,
            [8] = maxRange,
        }
    elseif maxRange > 256 then
        RangeList = {
            [1] = 30,
            [2] = 64,
            [3] = 128,
            [4] = 192,
            [5] = 256,
            [6] = maxRange,
        }
    elseif maxRange > 64 then
        RangeList = {
            [1] = 30,
            [2] = maxRange,
        }
    end
    local acuUnit = false
    local SquadTargetList = {
        Attack = {
            Unit = false,
            Distance = false
        },
        Artillery = {
            Unit = false,
            Distance = false
        }
    }

    for _, range in RangeList do
        targetUnits = GetUnitsAroundPoint(aiBrain, categories.ALLUNITS - categories.INSIGNIFICANTUNIT, position, range, 'Enemy')
        for _, category in atkPri do
            local retUnit = false
            local distance = false
            local targetShields = 9999
            for num, unit in targetUnits do
                if not unit.Dead and EntityCategoryContains(category, unit) and platoon:CanAttackTarget(squad, unit) then
                    if ignoreCivilian and ArmyIsCivilian(unit:GetArmy()) then
                        --RNGLOG('Unit is civilian')
                        continue
                    end
                    if ignoreNotCompleted and unit:GetFractionComplete() ~= 1 then
                        continue
                    end
                    local unitPos = unit:GetPosition()
                    if platoon.MovementLayer == 'Air' and platoonThreat then
                        enemyThreat = GetThreatAtPosition( aiBrain, unitPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')
                        --RNGLOG('Enemy Threat is '..enemyThreat..' and my threat is '..platoonThreat)
                        if enemyThreat > platoonThreat then
                            continue
                        end
                    end
                    if EntityCategoryContains(categories.COMMAND, unit) then
                        acuUnit = unit
                    end
                    local dx = unitPos[1] - position[1]
                    local dz = unitPos[3] - position[3]
                    local unitDistance = dx * dx + dz * dz
                    if EntityCategoryContains(categories.MOBILE, unit) then
                        if not SquadTargetList.Attack.Unit or unitDistance < SquadTargetList.Attack.Distance then
                            SquadTargetList.Attack.Unit = unit
                            SquadTargetList.Attack.Distance = unitDistance
                        end
                    elseif EntityCategoryContains(categories.STRUCTURE, unit) then
                        if not SquadTargetList.Artillery.Unit or unitDistance < SquadTargetList.Artillery.Distance then
                            SquadTargetList.Artillery.Unit = unit
                            SquadTargetList.Artillery.Distance = unitDistance
                        end
                    end
                end
            end
            if SquadTargetList.Attack.Unit or SquadTargetList.Artillery.Unit then
                return SquadTargetList, acuUnit
            end
        end
        coroutine.yield(2)
    end
    return false
end

function AIFindACUTargetInRangeRNG(aiBrain, platoon, position, squad, maxRange, platoonThreat, index)
    local VDist2 = VDist2
    local enemyThreat
    if not aiBrain or not position or not maxRange then
        return false
    end
    if not platoon.MovementLayer then
        AIAttackUtils.GetMostRestrictiveLayerRNG(platoon)
    end
    local targetUnits = GetUnitsAroundPoint(aiBrain, categories.COMMAND, position, maxRange, 'Enemy')
    local retUnit = false
    local unit
    local retDistance = false
    local targetShields = 9999
    for num, unit in targetUnits do
        if index then
            for k, v in index do
                if unit:GetAIBrain():GetArmyIndex() == v then
                    if not unit.Dead and EntityCategoryContains(categories.COMMAND, unit) and platoon:CanAttackTarget(squad, unit) and not unit.Tractored then
                        local unitPos = unit:GetPosition()
                        local unitArmyIndex = unit:GetArmy()
        
                        --[[if not aiBrain.EnemyIntel.ACU[unitArmyIndex].OnField then
                            continue
                        end]]
                        if platoon.MovementLayer == 'Air' and platoonThreat then
                            enemyThreat = GetThreatAtPosition( aiBrain, unitPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')
                            --RNGLOG('Enemy Threat is '..enemyThreat..' and my threat is '..platoonThreat)
                            if enemyThreat > platoonThreat then
                                continue
                            end
                        end
                        local numShields = GetNumUnitsAroundPoint(aiBrain, CategoriesShield, unitPos, 46, 'Enemy')
                        local dx = unitPos[1] - position[1]
                        local dz = unitPos[3] - position[3]
                        local distance = dx * dx + dz * dz
                        if not retUnit or numShields < targetShields or (numShields == targetShields and distance < retDistance) then
                            retUnit = unit
                            retDistance = distance
                            targetShields = numShields
                        end
                    end
                end
            end
        else
            if not unit.Dead and EntityCategoryContains(categories.COMMAND, unit) and platoon:CanAttackTarget(squad, unit) and not unit.Tractored then
                local unitPos = unit:GetPosition()
                local unitArmyIndex = unit:GetArmy()

                if not aiBrain.EnemyIntel.ACU[unitArmyIndex].OnField then
                    continue
                end
                if platoon.MovementLayer == 'Air' and platoonThreat then
                    enemyThreat = GetThreatAtPosition( aiBrain, unitPos, 0, true, 'AntiAir')
                    --RNGLOG('Enemy Threat is '..enemyThreat..' and my threat is '..platoonThreat)
                    if enemyThreat > platoonThreat then
                        continue
                    end
                end
                local numShields = GetNumUnitsAroundPoint(aiBrain, CategoriesShield, unitPos, 46, 'Enemy')
                local dx = unitPos[1] - position[1]
                local dz = unitPos[3] - position[3]
                local distance = dx * dx + dz * dz
                if not retUnit or numShields < targetShields or (numShields == targetShields and distance < retDistance) then
                    retUnit = unit
                    retDistance = distance
                    targetShields = numShields
                end
            end
        end
    end
    if retUnit and targetShields > 0 then
        local platoonUnits = platoon:GetPlatoonUnits()
        for _, w in platoonUnits do
            if not w.Dead then
                unit = w
                break
            end
        end
        local closestBlockingShield, shieldHealth = GetClosestShieldProtectingTargetRNG(unit, retUnit)
        if closestBlockingShield then
            return closestBlockingShield, shieldHealth
        end
    end
    if retUnit then
        return retUnit
    end

    return false
end

function AIFindBrainTargetInCloseRangeRNG(aiBrain, platoon, position, squad, maxRange, targetQueryCategory, TargetSearchCategory, enemyBrain, ignoreNotCompleted)
    if type(TargetSearchCategory) == 'string' then
        TargetSearchCategory = ParseEntityCategory(TargetSearchCategory)
    end
    local enemyIndex = false
    local VDist2 = VDist2
    local MyArmyIndex = aiBrain:GetArmyIndex()
    if enemyBrain then
        enemyIndex = enemyBrain:GetArmyIndex()
    end
    local acuPresent = false
    local acuUnit = false
    local unitThreatTable = {}
    local defensiveStructureTable = {}
    local threatTable = { AntiSurface = 0, Air = 0, AntiNaval = 0 }
    local RangeList = {
        [1] = 10,
        [2] = maxRange,
        [3] = maxRange + 30,
    }
    local TargetUnit = false
    local TargetsInRange, TargetPosition, category, distance, targetRange, baseTargetRange, canAttack
    for _, range in RangeList do
        if not position then
            WARN('* AI-RNG: AIFindNearestCategoryTargetInCloseRange: position is empty')
            return false
        end
        if not range then
            WARN('* AI-RNG: AIFindNearestCategoryTargetInCloseRange: range is empty')
            return false
        end
        if not TargetSearchCategory then
            WARN('* AI-RNG: AIFindNearestCategoryTargetInCloseRange: TargetSearchCategory is empty '..repr(platoon.BuilderName)..' '..repr(platoon.PlanName))
            return false
        end
        TargetsInRange = GetUnitsAroundPoint(aiBrain, targetQueryCategory, position, range, 'Enemy')
        --DrawCircle(position, range, '0000FF')
        for _, v in TargetSearchCategory do
            category = v
            if type(category) == 'string' then
                category = ParseEntityCategory(category)
            end
            distance = maxRange * maxRange
            --RNGLOG('* AIFindNearestCategoryTargetInRange: numTargets '..RNGGETN(TargetsInRange)..'  ')
            for num, Target in TargetsInRange do
                if not Target.Dead and not Target.Tractored then
                    if ignoreNotCompleted then
                        if Target:GetFractionComplete() ~= 1 then
                            continue
                        end
                    end
                    if Target.EntityId and not unitThreatTable[Target.EntityId] then
                        if platoon.MovementLayer == 'Water' then
                            threatTable['AntiNaval'] = threatTable['AntiNaval'] +  Target.Blueprint.Defense.SubThreatLevel
                            threatTable['AntiSurface'] = threatTable['AntiSurface'] + Target.Blueprint.Defense.SurfaceThreatLevel
                        elseif platoon.MovementLayer == 'Air' then
                            threatTable['Air'] = threatTable['Air'] + Target.Blueprint.Defense.AirThreatLevel
                        else
                            threatTable['AntiSurface'] = threatTable['AntiSurface'] + Target.Blueprint.Defense.SurfaceThreatLevel
                        end
                        if EntityCategoryContains(CategoriesLandDefense, Target) then
                            RNGINSERT(defensiveStructureTable, Target)
                        end
                        unitThreatTable[Target.EntityId] = true
                    end
                    TargetPosition = Target:GetPosition()
                    -- check if we have a special player as enemy
                    if enemyBrain and enemyIndex and enemyBrain ~= enemyIndex then continue end
                    if EntityCategoryContains(categories.COMMAND, Target) then
                        acuPresent = true
                        acuUnit = Target
                    end
                    -- check if the Target is still alive, matches our target priority and can be attacked from our platoon
                    if not Target.Dead and not Target.CaptureInProgress and EntityCategoryContains(category, Target) and platoon:CanAttackTarget(squad, Target) then
                        -- yes... we need to check if we got friendly units with GetUnitsAroundPoint(_, _, _, 'Enemy')
                        if not IsEnemy( MyArmyIndex, Target:GetAIBrain():GetArmyIndex() ) then continue end
                        if Target.ReclaimInProgress then
                            --WARN('* AIFindNearestCategoryTargetInRange: ReclaimInProgress !!! Ignoring the target.')
                            continue
                        end
                        if Target.CaptureInProgress then
                            --WARN('* AIFindNearestCategoryTargetInRange: CaptureInProgress !!! Ignoring the target.')
                            continue
                        end
                        targetRange = VDist2Sq(position[1],position[3],TargetPosition[1],TargetPosition[3])
                        -- check if the target is in range of the unit and in range of the base
                        if targetRange < distance then
                            TargetUnit = Target
                            distance = targetRange
                        end
                    end
                end
            end
            if TargetUnit then
                --RNGLOG('Target Found in target aquisition function')
                return TargetUnit, acuPresent, acuUnit, threatTable, TargetsInRange, defensiveStructureTable
            end
        end
        if platoon.Dead then return end
        coroutine.yield(2)
    end
    --RNGLOG('NO Target Found in target aquisition function')
    return TargetUnit, acuPresent, acuUnit, threatTable, TargetsInRange, defensiveStructureTable
end

function AIFindBrainTargetACURNG(aiBrain, platoon, position, squad, maxRange, targetQueryCategory, TargetSearchCategory, enemyBrain)
    if type(TargetSearchCategory) == 'string' then
        TargetSearchCategory = ParseEntityCategory(TargetSearchCategory)
    end
    local enemyIndex = false
    local MyArmyIndex = aiBrain:GetArmyIndex()
    if enemyBrain then
        enemyIndex = enemyBrain:GetArmyIndex()
    end
    local totalThreat = 0
    local unitThreatTable = {}
    local acuPresent = false
    local acuUnit = false
    local RangeList = {
        [1] = maxRange,
        [2] = maxRange + 30,
    }
    local TargetUnit = false
    local TargetsInRange, EnemyStrength, TargetPosition, category, distance, targetRange, baseTargetRange, canAttack
    for _, range in RangeList do
        if not position then
            WARN('* AI-RNG: AIFindBrainTargetACURNG: position is empty')
            return false
        end
        if not range then
            WARN('* AI-RNG: AIFindBrainTargetACURNG: range is empty')
            return false
        end
        if not TargetSearchCategory then
            WARN('* AI-RNG: AIFindBrainTargetACURNG: TargetSearchCategory is empty '..repr(platoon.BuilderName)..' '..repr(platoon.PlanName))
            return false
        end
        TargetsInRange = GetUnitsAroundPoint(aiBrain, targetQueryCategory, position, range, 'Enemy')
        --DrawCircle(position, range, '0000FF')
        for _, v in TargetSearchCategory do
            category = v
            if type(category) == 'string' then
                category = ParseEntityCategory(category)
            end
            distance = maxRange * maxRange
            --RNGLOG('* AIFindNearestCategoryTargetInRange: numTargets '..RNGGETN(TargetsInRange)..'  ')
            for num, Target in TargetsInRange do
                if Target.Dead or Target:BeenDestroyed() then
                    continue
                end
                if Target.EntityId and not unitThreatTable[Target.EntityId] then
                    totalThreat = totalThreat + Target.Blueprint.Defense.SurfaceThreatLevel
                    unitThreatTable[Target.EntityId] = true
                end
                TargetPosition = Target:GetPosition()
                EnemyStrength = 0
                -- check if we have a special player as enemy
                if enemyBrain and enemyIndex and enemyBrain ~= enemyIndex then continue end
                if EntityCategoryContains(categories.COMMAND, Target) then
                    acuPresent = true
                    acuUnit = Target
                end
                -- check if the Target is still alive, matches our target priority and can be attacked from our platoon
                if not Target.Dead and not Target.CaptureInProgress and EntityCategoryContains(category, Target) and platoon:CanAttackTarget(squad, Target) then
                    -- yes... we need to check if we got friendly units with GetUnitsAroundPoint(_, _, _, 'Enemy')
                    if not IsEnemy( MyArmyIndex, Target:GetAIBrain():GetArmyIndex() ) then continue end
                    if Target.ReclaimInProgress then
                        --WARN('* AIFindNearestCategoryTargetInRange: ReclaimInProgress !!! Ignoring the target.')
                        continue
                    end
                    if Target.CaptureInProgress then
                        --WARN('* AIFindNearestCategoryTargetInRange: CaptureInProgress !!! Ignoring the target.')
                        continue
                    end
                    targetRange = VDist2Sq(position[1],position[3],TargetPosition[1],TargetPosition[3])
                    -- check if the target is in range of the unit and in range of the base
                    if targetRange < distance then
                        TargetUnit = Target
                        distance = targetRange
                    end
                end
            end
            if TargetUnit then
                --RNGLOG('Target Found in target aquisition function')
                return TargetUnit, acuPresent, acuUnit, totalThreat
            end
           coroutine.yield(2)
        end
        coroutine.yield(1)
    end
    --RNGLOG('NO Target Found in target aquisition function')
    return TargetUnit, acuPresent, acuUnit, totalThreat
end

function GetAssisteesRNG(aiBrain, locationType, assisteeType, buildingCategory, assisteeCategory)
    if assisteeType == categories.FACTORY then
        -- Sift through the factories in the location
        local manager = aiBrain.BuilderManagers[locationType].FactoryManager
        return manager:GetFactoriesWantingAssistance(buildingCategory, assisteeCategory)
    elseif assisteeType == categories.ENGINEER then
        local manager = aiBrain.BuilderManagers[locationType].EngineerManager
        return manager:GetEngineersWantingAssistance(buildingCategory, assisteeCategory)
    elseif assisteeType == categories.STRUCTURE then
        local manager = aiBrain.BuilderManagers[locationType].PlatoonFormManager
        return manager:GetUnitsBeingBuilt(buildingCategory, assisteeCategory)
    else
        error('*AI ERROR: Invalid assisteeType - ' .. ToString(assisteeType))
    end

    return false
end

function ExpansionSpamBaseLocationCheck(aiBrain, location)
    local validLocation = false
    local enemyStarts = {}
    if not location then
        return false
    end

    if not table.empty(aiBrain.EnemyIntel.EnemyStartLocations) then
        --RNGLOG('*AI RNG: Enemy Start Locations are present for ExpansionSpamBase')
        --RNGLOG('*AI RNG: SpamBase position is'..repr(location))
        enemyStarts = aiBrain.EnemyIntel.EnemyStartLocations
    else
        return false
    end
    
    for key, startloc in enemyStarts do
        
        local locationDistance = VDist2Sq(startloc.Position[1], startloc.Position[3],location[1], location[3])
        --RNGLOG('*AI RNG: location position distance for ExpansionSpamBase is '..locationDistance)
        if  locationDistance > 25600 and locationDistance < 250000 then
            --RNGLOG('*AI RNG: SpamBase distance is within bounds, position is'..repr(location))
            --RNGLOG('*AI RNG: Enemy Start Position is '..repr(startloc))
            if NavUtils.CanPathTo('Land', startloc.Position, location) then
                --RNGLOG('Can graph to enemy location for spam base')
                --RNGLOG('*AI RNG: expansion position is within range and pathable to an enemy base for ExpansionSpamBase')
                validLocation = true
                break
            else
                continue
            end
        else
            continue
        end
    end

    if validLocation then
        --RNGLOG('*AI RNG: Spam base is true')
        return true
    else
        --RNGLOG('*AI RNG: Spam base is false')
        return false
    end

    return false
end

function GetNavalPlatoonMaxRangeRNG(aiBrain, platoon)
    local maxRange = 0
    local platoonUnits = platoon:GetPlatoonUnits()
    local isTech1
    local selectedWeaponArc
    for _,unit in platoonUnits do
        if unit.Dead then
            continue
        end
        local unitBp = unit.Blueprint

        for _,weapon in unitBp.Weapon do
            if not weapon.FireTargetLayerCapsTable or not weapon.FireTargetLayerCapsTable.Water then
                continue
            end

            --Check if the weapon can hit land from water
            local canAttackLand = string.find(weapon.FireTargetLayerCapsTable.Water, 'Land', 1, true)

            if canAttackLand and weapon.MaxRadius > maxRange then
                isTech1 = EntityCategoryContains(categories.TECH1, unit)
                maxRange = weapon.MaxRadius

                if weapon.BallisticArc == 'RULEUBA_LowArc' then
                    selectedWeaponArc = 'low'
                elseif weapon.BallisticArc == 'RULEUBA_HighArc' then
                    selectedWeaponArc = 'high'
                else
                    selectedWeaponArc = 'none'
                end
            end
        end
    end

    if maxRange == 0 then
        return false
    end

    -- T1 naval units don't hit land targets very well. Bail out!
    if isTech1 then
        return false
    end

    return maxRange, selectedWeaponArc
end

function UnitRatioCheckRNG(aiBrain, ratio, categoryOne, compareType, categoryTwo)
    local numOne = GetCurrentUnits(aiBrain, categoryOne)
    local numTwo = GetCurrentUnits(aiBrain, categoryTwo)
    --RNGLOG(aiBrain:GetArmyIndex()..' CompareBody {World} ( '..numOne..' '..compareType..' '..numTwo..' ) -- ['..ratio..'] -- return '..repr(CompareBody(numOne / numTwo, ratio, compareType)))
    return CompareBodyRNG(numOne / numTwo, ratio, compareType)
end

function CompareBodyRNG(numOne, numTwo, compareType)
    if compareType == '>' then
        if numOne > numTwo then
            return true
        end
    elseif compareType == '<' then
        if numOne < numTwo then
            return true
        end
    elseif compareType == '>=' then
        if numOne >= numTwo then
            return true
        end
    elseif compareType == '<=' then
        if numOne <= numTwo then
            return true
        end
    else
       error('*AI ERROR: Invalid compare type: ' .. compareType)
       return false
    end
    return false
end

function DebugArrayRNG(Table)
   --RNGLOG('DebugArrayRNG Checking Table')
    for Index, Array in Table do
        if type(Array) == 'thread' or type(Array) == 'userdata' then
           --RNGLOG('Index['..Index..'] is type('..type(Array)..'). I won\'t print that!')
        elseif type(Array) == 'table' then
           --RNGLOG('Index['..Index..'] is type('..type(Array)..'). I won\'t print that!')
        else
           --RNGLOG('Index['..Index..'] is type('..type(Array)..'). "', repr(Array),'".')
        end
    end
end




--[[
   This is Sproutos work, an early function from the master himself
   Inputs : 
   location, location name string
   radius, radius from location position int
   orientation, return positions based on string 'FRONT', 'REAR', 'ALL'
   positionselection, return all, random, selection int or bool
   layer, movement layer string
   patroltype return sequence bool or nil

   Returns :
   sortedList, position table
   Orient, string NESW
   positionselection, int
   ]]
function GetBasePerimeterPoints( aiBrain, location, radius, orientation, positionselection, layer, patroltype )
    
	local newloc = false
	local Orient = false
	local Basename = false
	
	-- we've been fed a base name rather than 3D co-ordinates
	-- store the Basename and convert location into a 3D position
	if type(location) == 'string' then
		Basename = location
		newloc = aiBrain.BuilderManagers[location].Position or false
		Orient = aiBrain.BuilderManagers[location].Orientation or false
		if newloc then
			location = table.copy(newloc)
		end
	end

	-- we dont have a valid 3D location
	-- likely base is no longer active --
	if not location[3] then
		return {}
	end

	if not layer then
		layer = 'Amphibious'
	end

	if not patroltype then
		patroltype = false
	end

	-- get the map dimension sizes
	local Mx = ScenarioInfo.size[1]
	local Mz = ScenarioInfo.size[2]	
	
	if orientation then
		local Sx = RNGCEIL(location[1])
		local Sz = RNGCEIL(location[3])
	
		if not Orient then
			-- tracks if we used threat to determine Orientation
			local Direction = false
			local threats = aiBrain:GetThreatsAroundPosition( location, 16, true, 'Economy' )
			RNGSORT( threats, function(a,b) return VDist2Sq(a[1],a[2],location[1],location[3]) + a[3] < VDist2Sq(b[1],b[2],location[1],location[3]) + b[3] end )
			for _,v in threats do
				Direction = GetDirectionInDegrees( {v[1],location[2],v[2]}, location )
				break	-- process only the first one
			end
			
			if Direction then
				if Direction < 45 or Direction > 315 then
					Orient = 'S'
				elseif Direction >= 45 and Direction < 135 then
					Orient = 'E'
				elseif Direction >= 135 and Direction < 225 then
					Orient = 'N'
				else
					Orient = 'W'
				end
			else
				-- Use map position to determine orientation
				-- First step is too determine if you're in the top or bottom 25% of the map
				-- if you are then you will orient N or S otherwise E or W
				-- the OrientvalueREAR will be set to value of the REAR positions (either the X or Z value depending upon NSEW Orient value)

				-- check if upper or lower quarter		
				if ( Sz <= (Mz * .25) or Sz >= (Mz * .75) ) then
					Orient = 'NS'
				-- otherwise use East/West orientation
				else
					Orient = 'EW'
				end

				-- orientation will be overridden if we are particularily close to a map edge
				-- check if extremely close to an edge (within 11% of map size)
				if (Sz <= (Mz * .11) or Sz >= (Mz * .89)) then
					Orient = 'NS'
				end

				if (Sx <= (Mx * .11) or Sx >= (Mx * .89)) then
					Orient = 'EW'
				end

				-- Second step is to determine if we are N or S - or - E or W
				
				if Orient == 'NS' then 
					-- if N/S and in the lower half of map
					if (Sz > (Mz* 0.5)) then
						Orient = 'N'
					-- else we must be in upper half
					else	
						Orient = 'S'
					end
				else
					-- if E/W and we are in the right side of the map
					if (Sx > (Mx* 0.5)) then
						Orient = 'W'
					-- else we must on the left side
					else
						Orient = 'E'
					end
				end
			end

			-- store the Orientation for any given base
			if Basename then
				aiBrain.BuilderManagers[Basename].Orientation = Orient		
			end
		end
		
		if Orient == 'S' then
			OrientvalueREAR = Sz - radius
			OrientvalueFRONT = Sz + radius		
		elseif Orient == 'E' then
			OrientvalueREAR = Sx - radius
			OrientvalueFRONT = Sx + radius
		elseif Orient == 'N' then
			OrientvalueREAR = Sz + radius
			OrientvalueFRONT = Sz - radius
		elseif Orient == 'W' then
			OrientvalueREAR = Sx + radius
			OrientvalueFRONT = Sz - radius
		end
	end

	-- If radius is very small just return the centre point and orientation
	-- this is often used by engineers to build structures according to a base template with fixed positions
	-- and still maintain the appropriate rotation -- 
	if radius < 4 then
		return { {location[1],0,location[3]} }, Orient
	end	

	local locList = {}
	local counter = 0

	local lowlimit = (radius * -1)
	local highlimit = radius
	local steplimit = (radius / 2)
	
	-- build an array of points in the shape of a box w 5 points to a side
	-- eliminating the corner positions along the way
	-- the points will be numbered from upper left to lower right
	-- this code will always return the 12 points around whatever position it is fed
	-- even if those points result in some point off of the map
	for x = lowlimit, highlimit, steplimit do
		
		for y = lowlimit, highlimit, steplimit do
			
			-- this code lops off the corners of the box and the interior points leaving us with 3 points to a side
			-- basically it forms a '+' shape
			if not (x == 0 and y == 0)	and	(x == lowlimit or y == lowlimit or x == highlimit or y == highlimit)
			and not ((x == lowlimit and y == lowlimit) or (x == lowlimit and y == highlimit)
			or ( x == highlimit and y == highlimit) or ( x == highlimit and y == lowlimit)) then
				locList[counter+1] = { RNGCEIL(location[1] + x), GetSurfaceHeight(location[1] + x, location[3] + y), RNGCEIL(location[3] + y) }
				counter = counter + 1
			end
		end
	end

	-- if we have an orientation build a list of those points that meet that specification
	-- FRONT will have all points that do not match the OrientvalueREAR (9 points)
	-- REAR will have all point that DO match the OrientvalueREAR (3 points)
	-- otherwise we keep all 12 generated points
	if orientation == 'FRONT' or orientation == 'REAR' then
		
		local filterList = {}
		counter = 0

		for k,v in locList do
			local x = v[1]
			local z = v[3]

			if Orient == 'N' or Orient == 'S' then
				if orientation == 'FRONT' and z ~= OrientvalueREAR then
					filterList[counter+1] = v
					counter = counter + 1
				elseif orientation == 'REAR' and z == OrientvalueREAR then
					filterList[counter+1] = v
					counter = counter + 1
				end
			elseif Orient == 'W' or Orient == 'E' then
				if orientation == 'FRONT' and x ~= OrientvalueREAR then
					filterList[counter+1] = v
					counter = counter + 1
				elseif orientation == 'REAR' and x == OrientvalueREAR then
					filterList[counter+1] = v
					counter = counter + 1
				end
			end
		end
		locList = filterList
	end
	
	-- sort the points from front to rear based upon orientation
	if Orient == 'N' then
		table.sort(locList, function(a,b) return a[3] < b[3] end)
	elseif Orient == 'S' then
		table.sort(locList, function(a,b) return a[3] > b[3] end)
	elseif Orient == 'E' then 
		table.sort(locList, function(a,b) return a[1] > b[1] end)
	elseif Orient == 'W' then
		table.sort(locList, function(a,b) return a[1] < b[1] end)
	end

	local sortedList = {}
	
	if table.getsize(locList) == 0 then
		return {} 
	end
	
	-- Originally I always did this and it worked just fine but I want
	-- to find a way to get the AI to rotate templated builds so I need
	-- to provide a consistent result based upon orientation and NOT 
	-- sorted by proximity to map centre -- as I had been doing -- so 
	-- now I only sort the list if its a patrol or Air request
	-- I have kept the original code contained inside this loop but 
	-- it doesn't run
	if patroltype or layer == 'Air' then
		local lastX = Mx* 0.5
		local lastZ = Mz* 0.5
	
		if patroltype or layer == 'Air' then
			lastX = location[1]
			lastZ = location[3]
		end
		
	
		-- Sort points by distance from (lastX, lastZ) - map centre
		-- or if patrol or 'Air', then from the provided location
		for i = 1, counter do
		
			local lowest
			local czX, czZ, pos, distance, key
		
			for k, v in locList do
				local x = v[1]
				local z = v[3]
				distance = VDist2Sq(lastX, lastZ, x, z)
				if not lowest or distance < lowest then
					pos = v
					lowest = distance
					key = k
				end
			end
		
			if not pos then
				return {} 
			end
		
			sortedList[i] = pos
			
			-- use the last point selected as the start point for the next distance check
			if patroltype or layer == 'Air' then
				lastX = pos[1]
				lastZ = pos[3]
			end
			RNGREMOVE(locList, key)
		end
	else
		sortedList = locList
	end

	-- pick a specific position
	if positionselection then
	
		if type(positionselection) == 'boolean' then
			positionselection = Random( 1, counter )	--RNGGETN(sortedList))
		end

	end


	return sortedList, Orient, positionselection
end

function GetDistanceBetweenTwoVectors( v1, v2 )
    return VDist3(v1, v2)
end

function XZDistanceTwoVectors( v1, v2 )
    return VDist2( v1[1], v1[3], v2[1], v2[3] )
end

function GetVectorLength( v )
    return RNGSQRT( math.pow( v[1], 2 ) + math.pow( v[2], 2 ) + math.pow(v[3], 2 ) )
end

function NormalizeVector( v )

	if v.x then
		v = {v.x, v.y, v.z}
	end
	
    local length = RNGSQRT( math.pow( v[1], 2 ) + math.pow( v[2], 2 ) + math.pow(v[3], 2 ) )
	
    if length > 0 then
        local invlength = 1 / length
        return Vector( v[1] * invlength, v[2] * invlength, v[3] * invlength )
    else
        return Vector( 0,0,0 )
    end
end

function GetDifferenceVector( v1, v2 )
    return Vector(v1[1] - v2[1], v1[2] - v2[2], v1[3] - v2[3])
end

function GetDirectionVector( v1, v2 )
    return NormalizeVector( Vector(v1[1] - v2[1], v1[2] - v2[2], v1[3] - v2[3]) )
end

function GetDirectionInDegrees( v1, v2 )
    local RNGACOS = math.acos
	local vec = GetDirectionVector( v1, v2)
	
	if vec[1] >= 0 then
		return RNGACOS(vec[3]) * (360/(RNGPI*2))
	end
	
	return 360 - (RNGACOS(vec[3]) * (360/(RNGPI*2)))
end

function ComHealthRNG(cdr)
    local armorPercent = 100 / cdr:GetMaxHealth() * cdr:GetHealth()
    local shieldPercent = armorPercent
    if cdr.MyShield then
        shieldPercent = 100 / cdr.MyShield:GetMaxHealth() * cdr.MyShield:GetHealth()
    end
    return ( armorPercent + shieldPercent ) / 2
end

-- This is Uvesos lead target function 
function LeadTargetRNG(LauncherPos, target, minRadius, maxRadius)
    -- Get launcher and target position
    --local LauncherPos = launcher:GetPosition()
    local TargetPos
    -- Get target position in 1 second intervals.
    -- This allows us to get speed and direction from the target
    local TargetStartPosition=0
    local Target1SecPos=0
    local Target2SecPos=0
    local XmovePerSec=0
    local YmovePerSec=0
    local XmovePerSecCheck=-1
    local YmovePerSecCheck=-1
    -- Check if the target is runing straight or circling
    -- If x/y and xcheck/ycheck are equal, we can be sure the target is moving straight
    -- in one direction. At least for the last 2 seconds.
    local LoopSaveGuard = 0
    while target and (XmovePerSec ~= XmovePerSecCheck or YmovePerSec ~= YmovePerSecCheck) and LoopSaveGuard < 10 do
        -- 1st position of target
        TargetPos = target:GetPosition()
        TargetStartPosition = {TargetPos[1], 0, TargetPos[3]}
        coroutine.yield(10)
        -- 2nd position of target after 1 second
        TargetPos = target:GetPosition()
        Target1SecPos = {TargetPos[1], 0, TargetPos[3]}
        XmovePerSec = (TargetStartPosition[1] - Target1SecPos[1])
        YmovePerSec = (TargetStartPosition[3] - Target1SecPos[3])
        coroutine.yield(10)
        -- 3rd position of target after 2 seconds to verify straight movement
        TargetPos = target:GetPosition()
        Target2SecPos = {TargetPos[1], TargetPos[2], TargetPos[3]}
        XmovePerSecCheck = (Target1SecPos[1] - Target2SecPos[1])
        YmovePerSecCheck = (Target1SecPos[3] - Target2SecPos[3])
        --We leave the while-do check after 10 loops (20 seconds) and try collateral damage
        --This can happen if a player try to fool the targetingsystem by circling a unit.
        LoopSaveGuard = LoopSaveGuard + 1
    end
    -- Get launcher position height
    local fromheight = GetTerrainHeight(LauncherPos[1], LauncherPos[3])
    if GetSurfaceHeight(LauncherPos[1], LauncherPos[3]) > fromheight then
        fromheight = GetSurfaceHeight(LauncherPos[1], LauncherPos[3])
    end
    -- Get target position height
    local toheight = GetTerrainHeight(Target2SecPos[1], Target2SecPos[3])
    if GetSurfaceHeight(Target2SecPos[1], Target2SecPos[3]) > toheight then
        toheight = GetSurfaceHeight(Target2SecPos[1], Target2SecPos[3])
    end
    -- Get height difference between launcher position and target position
    -- Adjust for height difference by dividing the height difference by the missiles max speed
    local HeightDifference = math.abs(fromheight - toheight) / 12
    -- Speed up time is distance the missile will travel while reaching max speed (~22.47 MapUnits)
    -- divided by the missiles max speed (12) which is equal to 1.8725 seconds flight time
    local SpeedUpTime = 22.47 / 12
    --  Missile needs 3 seconds to launch
    local LaunchTime = 3
    -- Get distance from launcher position to targets starting position and position it moved to after 1 second
    local dist1 = VDist2(LauncherPos[1], LauncherPos[3], Target1SecPos[1], Target1SecPos[3])
    local dist2 = VDist2(LauncherPos[1], LauncherPos[3], Target2SecPos[1], Target2SecPos[3])
    -- Missile has a faster turn rate when targeting targets < 50 MU away, so it will level off faster
    local LevelOffTime = 0.25
    local CollisionRangeAdjust = 0
    if dist2 < 50 then
        LevelOffTime = 0.02
        CollisionRangeAdjust = 2
    end
    -- Divide both distances by missiles max speed to get time to impact
    local time1 = (dist1 / 12) + LaunchTime + SpeedUpTime + LevelOffTime + HeightDifference
    local time2 = (dist2 / 12) + LaunchTime + SpeedUpTime + LevelOffTime + HeightDifference
    -- Get the missile travel time by extrapolating speed and time from dist1 and dist2
    local MissileTravelTime = (time2 + (time2 - time1)) + ((time2 - time1) * time2)
    -- Now adding all times to get final missile flight time to the position where the target will be
    local MissileImpactTime = MissileTravelTime + LaunchTime + SpeedUpTime + LevelOffTime + HeightDifference
    -- Create missile impact corrdinates based on movePerSec * MissileImpactTime
    local MissileImpactX = Target2SecPos[1] - (XmovePerSec * MissileImpactTime)
    local MissileImpactY = Target2SecPos[3] - (YmovePerSec * MissileImpactTime)
    -- Adjust for targets CollisionOffsetY. If the hitbox of the unit is above the ground
    -- we nedd to fire "behind" the target, so we hit the unit in midair.
    local TargetCollisionBoxAdjust = 0
    local TargetBluePrint = target.Blueprint
    if TargetBluePrint.CollisionOffsetY and TargetBluePrint.CollisionOffsetY > 0 then
        -- if the unit is far away we need to target farther behind the target because of the projectile flight angel
        local DistanceOffset = (100 / 256 * dist2) * 0.06
        TargetCollisionBoxAdjust = TargetBluePrint.CollisionOffsetY * CollisionRangeAdjust + DistanceOffset
    end
    -- To calculate the Adjustment behind the target we use a variation of the Pythagorean theorem. (Percent scale technique)
    -- (a²+b²=c²) If we add x% to c² then also a² and b² are x% larger. (a²)*x% + (b²)*x% = (c²)*x%
    local Hypotenuse = VDist2(LauncherPos[1], LauncherPos[3], MissileImpactX, MissileImpactY)
    local HypotenuseScale = 100 / Hypotenuse * TargetCollisionBoxAdjust
    local aLegScale = (MissileImpactX - LauncherPos[1]) / 100 * HypotenuseScale
    local bLegScale = (MissileImpactY - LauncherPos[3]) / 100 * HypotenuseScale
    -- Add x percent (behind) the target coordinates to get our final missile impact coordinates
    MissileImpactX = MissileImpactX + aLegScale
    MissileImpactY = MissileImpactY + bLegScale
    -- Cancel firing if target is outside map boundries
    if MissileImpactX < 0 or MissileImpactY < 0 or MissileImpactX > ScenarioInfo.size[1] or MissileImpactY > ScenarioInfo.size[2] then
        --RNGLOG('Target outside map boundries')
        return false
    end
    local dist3 = VDist2(LauncherPos[1], LauncherPos[3], MissileImpactX, MissileImpactY)
    if dist3 < minRadius or dist3 > maxRadius then
        --RNGLOG('Target outside max radius')
        return false
    end
    -- return extrapolated target position / missile impact coordinates
    return {MissileImpactX, Target2SecPos[2], MissileImpactY}
end

function AIFindRangedAttackPositionRNG(aiBrain, platoon, MaxPlatoonWeaponRange)
    local startPositions = {}
    local myArmy = ScenarioInfo.ArmySetup[aiBrain.Name]
    local mainBasePos = aiBrain.BuilderManagers['MAIN'].Position
    local platoonPosition = platoon:GetPlatoonPosition()

    for i = 1, 16 do
        local army = ScenarioInfo.ArmySetup['ARMY_' .. i]
        local startPos = ScenarioUtils.GetMarker('ARMY_' .. i).position
        local posThreat = 0
        local posDistance = 0
        if startPos then
            if army.ArmyIndex ~= myArmy.ArmyIndex and (army.Team ~= myArmy.Team or army.Team == 1) then
                posThreat = GetThreatAtPosition(aiBrain, startPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'StructuresNotMex')
                --RNGLOG('Ranged attack loop position is '..repr(startPos)..' with threat of '..posThreat)
                if posThreat > 5 then
                    if GetNumUnitsAroundPoint(aiBrain, categories.STRUCTURE - categories.WALL, startPos, 50, 'Enemy') > 0 then
                        --RNGLOG('Ranged attack position has structures within range')
                        posDistance = VDist2Sq(mainBasePos[1], mainBasePos[3], startPos[1], startPos[2])
                        --RNGLOG('Potential Naval Ranged attack position :'..repr(startPos)..' Threat at Position :'..posThreat..' Distance :'..posDistance)
                        table.insert(startPositions,
                            {
                                Position = startPos,
                                Threat = posThreat,
                                Distance = posDistance,
                            }
                        )
                    else
                        --RNGLOG('Ranged attack position has threat but no structures within range')
                    end
                end
            end
        end
    end
    --RNGLOG('Potential Positions Table '..repr(startPositions))
    -- We sort the positions so the closest are first
    RNGSORT( startPositions, function(a,b) return a.Distance < b.Distance end )
    --RNGLOG('Potential Positions Sorted by distance'..repr(startPositions))
    local attackPosition = false
    local targetStartPosition = false
    --We look for the closest
    for k, s in startPositions do
        local positionTable = NavUtils.GetPositionsInRadius('Water', s.Position, (MaxPlatoonWeaponRange + 30), 9)
        --LOG('ranged positions table for position '..repr(v)..' '..repr(positionTable))
        for _, v in positionTable do
            local dx = s.Position[1] - v[1]
            local dz = s.Position[3] - v[3]
            local posDist = dx * dx + dz * dz
            if posDist <= (MaxPlatoonWeaponRange * MaxPlatoonWeaponRange + 900) then
                if not aiBrain:CheckBlockingTerrain({v[1], v[2], v[3]}, s.Position, 'low') then
                    --LOG('Nothing is blocking this position to the enemy unit position')
                    if NavUtils.CanPathTo(platoon.MovementLayer, platoonPosition, {v[1], v[2], v[3]}) then
                        --LOG('Can path to ranged attack position')
                        attackPosition = {v[1], v[2], v[3]}
                        targetStartPosition = s.Position
                        break
                    end
                end
            end
        end
    end
    if attackPosition then
        --RNGLOG('Valid Attack Position '..repr(attackPosition)..' target Start Position '..repr(targetStartPosition))
    end
    return attackPosition, targetStartPosition
end
-- Another of Sproutos functions
function GetEnemyUnitsInRect( aiBrain, x1, z1, x2, z2 )
    
    local units = GetUnitsInRect(x1, z1, x2, z2)
    
    if units then
	
        local enemyunits = {}
		local counter = 0
		
        local IsEnemy = IsEnemy
		local GetAIBrain = moho.entity_methods.GetAIBrain
		
        for _,v in units do
		
            if not v.Dead and IsEnemy( GetAIBrain(v).ArmyIndex, aiBrain.ArmyIndex) then
                enemyunits[counter+1] =  v
				counter = counter + 1
            end
        end 
		
        if counter > 0 then
            return enemyunits, counter
        end
    end
    
    return {}, 0
end

function AIGetSortedMassLocationsThreatRNG(aiBrain, minDist, maxDist, tMin, tMax, tRings, tType, position)
    local GetMarkersByType = MarkerUtils.GetMarkersByType

    local threatCheck = false
    local maxDistance = 2000
    local minDistance = 0
    local VDist2Sq = VDist2Sq


    local startX, startZ
    
    if position then
        startX = position[1]
        startZ = position[3]
    else
        startX, startZ = aiBrain:GetArmyStartPos()
    end
    if maxDist and minDist then
        maxDistance = maxDist * maxDist
        minDistance = minDist * minDist
    end

    if tMin and tMax and tType then
        threatCheck = true
    else
        threatCheck = false
    end

    local markerList = GetMarkersByType('Mass')
    RNGSORT(markerList, function(a,b) return VDist2Sq(a.position[1],a.position[3], startX,startZ) < VDist2Sq(b.position[1],b.position[3], startX,startZ) end)
    --RNGLOG('Sorted Mass Marker List '..repr(markerList))
    local newList = {}
    for _, v in markerList do
        -- check distance to map border. (game engine can't build mass closer then 8 mapunits to the map border.) 
        if VDist2Sq(v.position[1], v.position[3], startX, startZ) < minDistance then
            continue
        end
        if VDist2Sq(v.position[1], v.position[3], startX, startZ) > maxDistance  then
            --RNGLOG('Current Distance of marker..'..VDist2Sq(v.Position[1], v.Position[3], startX, startZ))
            --RNGLOG('Max Distance'..maxDistance)
            --RNGLOG('mass marker MaxDistance Reached, breaking loop')
            break
        end
        if CanBuildStructureAt(aiBrain, 'ueb1103', v.position) then
            if threatCheck then
                if GetThreatAtPosition(aiBrain, v.position, 0, true, tType) >= tMax then
                    --RNGLOG('mass marker threatMax Reached, continuing')
                    continue
                end
            end
            table.insert(newList, v)
        end
    end
    --RNGLOG('Return marker list has '..RNGGETN(newList)..' entries')
    return newList
end

function EdgeDistance(x,y,mapwidth)
    local edgeDists = { x, y, math.abs(x-mapwidth), math.abs(y-mapwidth)}
    RNGSORT(edgeDists, function(k1, k2) return k1 < k2 end)
    return edgeDists[1]
end

function GetDirectorTarget(aiBrain, platoon, threatType, platoonThreat)


    
    if not platoon.MovementLayer then
        AIAttackUtils.GetMostRestrictiveLayerRNG(platoon)
    end

end

DisplayBaseMexAllocationRNG = function(aiBrain)
    local starts = AIUtils.AIGetMarkerLocationsRNG(aiBrain, 'Start Location')
    local adaptiveResourceMarkers = GetMarkersRNG()
    local MassMarker = {}
    for _, v in adaptiveResourceMarkers do
        if v.type == 'Mass' then
            table.insert(MassMarker, v)
        end
    end
    while aiBrain.Status ~= "Defeat" do
        for _, v in MassMarker do
            local pos1={0,0,0}
            local pos2={0,0,0}
            table.sort(starts,function(k1,k2) return VDist2Sq(k1.Position[1],k1.Position[3],v.position[1],v.position[3])<VDist2Sq(k2.Position[1],k2.Position[3],v.position[1],v.position[3]) end)
            local chosenstart = starts[1]
            pos1=v.position
            pos2=chosenstart.Position
            DrawLinePop(pos1,pos2,'ffFF0000')
        end
        coroutine.yield(2)
    end
end

-- start of supporting functions for zone area thingy
GenerateDistinctColorTable = function(num)
    local function factorial(n,min)
        if n>min and n>1 then
            return n*factorial(n-1)
        else
            return n
        end
    end
    local function combintoid(a,b,c)
        local o=tostring(0)
        local tab={a,b,c}
        local tabid={}
        for k,v in tab do
            local n=v
            tabid[k]=tostring(v)
            while n<1000 do
                n=n*10
                tabid[k]=o..tabid[k]
            end
        end
        return tabid[1]..tabid[2]..tabid[3]
    end
    local i=0
    local n=1
    while i<num do
        n=n+1
        i=n*n*n-n
    end
    local ViableValues={}
    for x=0,256,256/(n-1) do
        table.insert(ViableValues,ToColorRNG(0,256,x/256))
    end
    local colortable={}
    local combinations={}
    --[[for k,v in ViableValues do
        table.insert(colortable,v..v..v)
        combinations[combintoid(k,k,k)]=1
    end]]
    local max=ViableValues[RNGGETN(ViableValues)]
    local min=ViableValues[1]
    local primaries={min..min..min,max..max..min,max..min..max,min..max..max,max..min..min,min..max..min,min..min..max,max..max..max}
    combinations[combintoid(max,max,min)]=1
    combinations[combintoid(max,min,max)]=1
    combinations[combintoid(min,max,max)]=1
    combinations[combintoid(max,min,min)]=1
    combinations[combintoid(min,max,min)]=1
    combinations[combintoid(min,min,max)]=1
    combinations[combintoid(max,max,max)]=1
    combinations[combintoid(min,min,min)]=1
    for a,d in ViableValues do
        for b,e in ViableValues do
            for c,f in ViableValues do
                if not combinations[combintoid(a,b,c)] and not (a==b and b==c) then
                    table.insert(colortable,d..e..f)
                    combinations[combintoid(a,b,c)]=1
                end
            end
        end
    end
    for _,v in primaries do
        table.insert(colortable,v)
    end
    return colortable
end

GrabRandomDistinctColor = function(num)
    local output=GenerateDistinctColorTable(num)
    return output[math.random(RNGGETN(output))]
end


ShowLastKnown = function(aiBrain)
    coroutine.yield(50)
    local im = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua').GetIntelManager(aiBrain)
    while not im.MapIntelGrid do
        coroutine.yield(30)
    end
    while aiBrain.Status ~= "Defeat" do
        local time=GetGameTimeSeconds()
        for i=im.MapIntelGridXMin, im.MapIntelGridXMax do
            for k=im.MapIntelGridZMin, im.MapIntelGridZMax do
                if im.MapIntelGrid[i][k].EnemyUnits then
                    for c, b in im.MapIntelGrid[i][k].EnemyUnits do
                        if b.recent then
                            DrawCircle(b.Position,3,'aaffaa')
                        else
                            DrawCircle(b.Position,2,'aa000000')
                        end
                    end
                end
            end
        end
        coroutine.yield(2)
    end
end

ToColorRNG = function(min,max,ratio)
    local ToBase16 = function(num)
        if num<10 then
            return tostring(num)
        elseif num==10 then
            return 'a'
        elseif num==11 then
            return 'b'
        elseif num==12 then
            return 'c'
        elseif num==13 then
            return 'd'
        elseif num==14 then
            return 'e'
        else
            return 'f'
        end
    end
    local baseones=0
    local basetwos=0
    local numinit=math.abs(math.ceil((max-min)*ratio+min))
    basetwos=math.floor(numinit/16)
    baseones=numinit-basetwos*16
    return ToBase16(basetwos)..ToBase16(baseones)
end

-- end of supporting functions for zone area thingy

-- TruePlatoon Support functions

GrabPosDangerRNG = function(aiBrain, pos, allyRadius, enemyRadius,includeSurface, includeSub, includeAir, includeStructure)
    if pos and allyRadius and enemyRadius then
        local brainThreats = {allyTotal=0,enemyTotal=0,allySurface=0,allyACU=0, allyACUUnits = {},enemySurface=0,allyStructure=0,enemyStructure=0, enemyStructureUnits={},allyAir=0,enemyAir=0,allySub=0,enemySub=0,enemyrange=0,allyrange=0, enemyscoutrange=0,allyscoutrange=0}
        local enemyMaxRadius = 0
        local enemyScoutMaxRadius = 0
        local allyMaxRadius = 0
        local allyScoutMaxRadius = 0
        local enemyunits=GetUnitsAroundPoint(aiBrain, categories.DIRECTFIRE+categories.INDIRECTFIRE,pos,enemyRadius,'Enemy')
        local enemyUnitCount = 0
        for _,v in enemyunits do
            if not v.Dead then
                enemyUnitCount = enemyUnitCount + 1
                local mult=1
                local bp = v.Blueprint
                if bp.CategoriesHash.INDIRECTFIRE then
                    mult=0.3
                end
                if bp.CategoriesHash.COMMAND then
                    local commanderThreat = v:EnhancementThreatReturn()
                    brainThreats.enemySurface = brainThreats.enemySurface + commanderThreat
                    brainThreats.enemyTotal = brainThreats.enemyTotal + commanderThreat
                else
                    if includeSurface and bp.Defense.SurfaceThreatLevel ~= nil and bp.Defense.SurfaceThreatLevel > 0 and not bp.CategoriesHash.STRUCTURE then
                        brainThreats.enemySurface = brainThreats.enemySurface + bp.Defense.SurfaceThreatLevel*mult
                        brainThreats.enemyTotal = brainThreats.enemyTotal + bp.Defense.SurfaceThreatLevel*mult
                        if bp.CategoriesHash.SCOUT then
                            if bp.Weapon[1].MaxRadius > enemyScoutMaxRadius then
                                enemyScoutMaxRadius = bp.Weapon[1].MaxRadius
                            end
                        else
                            if bp.Weapon[1].MaxRadius > enemyMaxRadius then
                                enemyMaxRadius = bp.Weapon[1].MaxRadius
                            end
                        end
                    end
                    if includeStructure and bp.Defense.SurfaceThreatLevel ~= nil and bp.Defense.SurfaceThreatLevel > 0 and bp.CategoriesHash.STRUCTURE then
                        if bp.CategoriesHash.TACTICALMISSILEPLATFORM then
                            mult=0.1
                        else
                            mult=1.5
                        end
                        if v.GetFractionComplete and v:GetFractionComplete() > 0.7 then
                            if bp.CategoriesHash.DIRECTFIRE then
                                RNGINSERT(brainThreats.enemyStructureUnits, v)
                            end
                            if bp.Weapon[1].MaxRadius > enemyMaxRadius then
                                enemyMaxRadius = bp.Weapon[1].MaxRadius
                            end
                            brainThreats.enemyStructure = brainThreats.enemyStructure + bp.Defense.SurfaceThreatLevel*mult
                            brainThreats.enemyTotal = brainThreats.enemyTotal + bp.Defense.SurfaceThreatLevel*mult
                        end
                    end
                    if includeSub and bp.Defense.SubThreatLevel ~= nil and bp.Defense.SubThreatLevel > 0 then
                        brainThreats.enemySub = brainThreats.enemySub + bp.Defense.SubThreatLevel*mult
                        brainThreats.enemyTotal = brainThreats.enemyTotal + bp.Defense.SubThreatLevel*mult
                        if bp.Weapon[1].MaxRadius > enemyMaxRadius then
                            enemyMaxRadius = bp.Weapon[1].MaxRadius
                        end
                    end
                    if includeAir and bp.Defense.AirThreatLevel ~= nil and bp.Defense.AirThreatLevel > 0 then
                        brainThreats.enemyAir = brainThreats.enemyAir + bp.Defense.AirThreatLevel*mult
                        brainThreats.enemyTotal = brainThreats.enemyTotal + bp.Defense.AirThreatLevel*mult
                        if bp.Weapon[1].MaxRadius > enemyMaxRadius then
                            enemyMaxRadius = bp.Weapon[1].MaxRadius
                        end
                    end
                end
            end
        end
        brainThreats.enemyrange = enemyMaxRadius
        brainThreats.enemyscoutrange = enemyScoutMaxRadius

        local allyunits=GetUnitsAroundPoint(aiBrain, categories.DIRECTFIRE+categories.INDIRECTFIRE,pos,allyRadius,'Ally')
        for _,v in allyunits do
            if not v.Dead then
                local mult=1
                local bp = v.Blueprint
                if bp.CategoriesHash.INDIRECTFIRE then
                    mult=0.3
                end
                if bp.CategoriesHash.COMMAND then
                    local commanderThreat = v:EnhancementThreatReturn()
                    brainThreats.allyACU = brainThreats.allyACU + commanderThreat
                    brainThreats.allySurface = brainThreats.allySurface + commanderThreat
                    brainThreats.allyTotal = brainThreats.allyTotal + commanderThreat
                    RNGINSERT(brainThreats.allyACUUnits, v)
                else
                    if includeSurface and bp.Defense.SurfaceThreatLevel ~= nil and not bp.CategoriesHash.STRUCTURE and bp.Defense.SurfaceThreatLevel > 0 then
                        brainThreats.allySurface = brainThreats.allySurface + bp.Defense.SurfaceThreatLevel*mult
                        brainThreats.allyTotal = brainThreats.allyTotal + bp.Defense.SurfaceThreatLevel*mult
                        if bp.CategoriesHash.SCOUT then
                            if bp.Weapon[1].MaxRadius > allyScoutMaxRadius then
                                allyScoutMaxRadius = bp.Weapon[1].MaxRadius
                            end
                        else
                            if bp.Weapon[1].MaxRadius > allyMaxRadius then
                                allyMaxRadius = bp.Weapon[1].MaxRadius
                            end
                        end
                    end
                    if includeStructure and bp.CategoriesHash.STRUCTURE and bp.Defense.SurfaceThreatLevel ~= nil and bp.Defense.SurfaceThreatLevel > 0 then
                        brainThreats.allyStructure = brainThreats.allyStructure + bp.Defense.SurfaceThreatLevel
                    end
                    if includeSub and bp.Defense.SubThreatLevel ~= nil and bp.Defense.SubThreatLevel > 0 then
                        brainThreats.allySub = brainThreats.allySub + bp.Defense.SubThreatLevel*mult
                        brainThreats.allyTotal = brainThreats.allyTotal + bp.Defense.SubThreatLevel*mult
                        if bp.Weapon[1].MaxRadius > allyMaxRadius then
                            allyMaxRadius = bp.Weapon[1].MaxRadius
                        end
                    end
                    if includeAir and bp.Defense.AirThreatLevel ~= nil and bp.Defense.AirThreatLevel > 0 then
                        brainThreats.allyAir = brainThreats.allyAir + bp.Defense.AirThreatLevel*mult
                        brainThreats.allyTotal = brainThreats.allyTotal + bp.Defense.AirThreatLevel*mult
                        if bp.Weapon[1].MaxRadius > allyMaxRadius then
                            allyMaxRadius = bp.Weapon[1].MaxRadius
                        end
                    end
                end
            end
        end
        brainThreats.allyrange = allyMaxRadius
        brainThreats.allyscoutrange = allyScoutMaxRadius
        return brainThreats
    end
end

GrabPosDetailedDangerRNG = function(aiBrain,pos,radius, detailType)
    if detailType == 'AntiAir' then
        if pos and radius then
            local brainThreats = {allyTotal=0,enemyTotal=0,allySurface=0,enemySurface=0,allyStructure=0,enemyStructure=0,allyAir=0,allySurfaceAir=0,enemyAir=0,enemySurfaceAir=0,allySub=0,enemySub=0,enemyrange=0,allyrange=0}
            local enemyMaxRadius = 0
            local allyMaxRadius = 0
            local enemyunits=GetUnitsAroundPoint(aiBrain, categories.DIRECTFIRE+categories.INDIRECTFIRE,pos,radius,'Enemy')
            local enemyUnitCount = 0
            for _,v in enemyunits do
                if not v.Dead then
                    enemyUnitCount = enemyUnitCount + 1
                    local bp = v.Blueprint
                    local unitCats = bp.CategoriesHash
                    local mult = v:GetHealthPercent() or 1
                    if bp.Defense.AirThreatLevel ~= nil then
                        if unitCats.AIR then
                            brainThreats.enemyAir = brainThreats.enemyAir + bp.Defense.AirThreatLevel*mult
                            brainThreats.enemyTotal = brainThreats.enemyTotal + bp.Defense.AirThreatLevel*mult
                            if bp.Weapon[1].MaxRadius > enemyMaxRadius then
                                enemyMaxRadius = bp.Weapon[1].MaxRadius
                            end
                        elseif unitCats.LAND or unitCats.HOVER or unitCats.AMPHIBIOUS then
                            brainThreats.enemySurfaceAir = brainThreats.enemySurfaceAir + bp.Defense.AirThreatLevel*mult
                            brainThreats.enemyTotal = brainThreats.enemyTotal + bp.Defense.AirThreatLevel*mult
                            if bp.Weapon[1].MaxRadius > enemyMaxRadius then
                                enemyMaxRadius = bp.Weapon[1].MaxRadius
                            end
                        end
                    end
                end
            end
            return brainThreats
        end
    end
end

GrabPosDangerRNGOriginal = function(aiBrain,pos,radius)
    local function GetWeightedHealthRatio(unit)
        if unit.MyShield then
            return (unit.MyShield:GetHealth()+unit:GetHealth())/(unit.MyShield:GetMaxHealth()+unit:GetMaxHealth())
        else
            return unit:GetHealthPercent()
        end
    end
    local brainThreats = {ally=0,enemy=0}
    local allyunits=GetUnitsAroundPoint(aiBrain, categories.DIRECTFIRE+categories.INDIRECTFIRE,pos,radius,'Ally')
    local enemyunits=GetUnitsAroundPoint(aiBrain, categories.DIRECTFIRE+categories.INDIRECTFIRE,pos,radius,'Enemy')
    for _,v in allyunits do
        if not v.Dead then
            local mult=1
            if EntityCategoryContains(categories.INDIRECTFIRE,v) then
                mult=0.3
            end
            local bp = __blueprints[v.UnitId].Defense
            --RNGLOG(repr(__blueprints[v.UnitId].Defense))
            if bp.SurfaceThreatLevel ~= nil then
                brainThreats.ally = brainThreats.ally + bp.SurfaceThreatLevel*GetWeightedHealthRatio(v)*mult
            end
        end
    end
    for _,v in enemyunits do
        if not v.Dead then
            local mult=1
            if EntityCategoryContains(categories.INDIRECTFIRE,v) then
                mult=0.3
            end
            local bp = __blueprints[v.UnitId].Defense
            --RNGLOG(repr(__blueprints[v.UnitId].Defense))
            if bp.SurfaceThreatLevel ~= nil then
                brainThreats.enemy = brainThreats.enemy + bp.SurfaceThreatLevel*GetWeightedHealthRatio(v)*mult
            end
        end
    end
    return brainThreats
end

GrabPosEconRNG = function(aiBrain,pos,radius)
    local brainThreats = {ally=0,enemy=0}
    local allyunits=GetUnitsAroundPoint(aiBrain, categories.STRUCTURE,pos,radius,'Ally')
    if not allyunits then return brainThreats end
    local enemyunits=GetUnitsAroundPoint(aiBrain, categories.STRUCTURE,pos,radius,'Enemy')
    for _,v in allyunits do
        if not v.Dead then
            local index = v:GetAIBrain():GetArmyIndex()
            --RNGLOG('Unit Defense is'..repr(v:GetBlueprint().Defense))
            --RNGLOG('Unit ID is '..v.UnitId)
            --bp = v:GetBlueprint().Defense
            local bp = __blueprints[v.UnitId].Defense
            --RNGLOG(repr(__blueprints[v.UnitId].Defense))
            if bp.EconomyThreatLevel ~= nil then
                brainThreats.ally = brainThreats.ally + bp.EconomyThreatLevel
            end
        end
    end
    for _,v in enemyunits do
        if not v.Dead then
            local index = v:GetAIBrain():GetArmyIndex()
            --RNGLOG('Unit Defense is'..repr(v:GetBlueprint().Defense))
            --RNGLOG('Unit ID is '..v.UnitId)
            --bp = v:GetBlueprint().Defense
            local bp = __blueprints[v.UnitId].Defense
            --RNGLOG(repr(__blueprints[v.UnitId].Defense))
            if bp.EconomyThreatLevel ~= nil then
                brainThreats.enemy = brainThreats.enemy + bp.EconomyThreatLevel
            end
        end
    end
    return brainThreats
end

PlatoonReclaimQueryRNGRNG = function(aiBrain,platoon)
    -- we need to figure a way to make sure we arn't to close to an existing tagged reclaim area
    if aiBrain.ReclaimEnabled then
        local baseDMZArea = self.OperatingAreas['BaseDMZArea']
        local homeBaseLocation = aiBrain.BuilderManagers['MAIN'].Position
        local platoonPos = platoon:GetPosition()
        if VDist2Sq(platoonPos[1], platoonPos[3], homeBaseLocation[1], homeBaseLocation[3]) < (baseDMZArea * baseDMZArea) then
            local valueTrigger = 200
            local currentValue = 0
            local x1 = platoonPos[1] - 20
            local x2 = platoonPos[1] + 20
            local z1 = platoonPos[3] - 20
            local z2 = platoonPos[3] + 20
            local rect = Rect(x1, z1, x2, z2)
            local reclaimRect = {}
            reclaimRect = GetReclaimablesInRect(rect)
            if not platoonPos then
                coroutine.yield(1)
                return
            end
            if reclaimRect and not table.empty( reclaimRect ) then
                for k,v in reclaimRect do
                    if not IsProp(v) or self.BadReclaimables[v] then continue end
                    currentValue = currentValue + v.MaxMassReclaim
                    if currentValue > valueTrigger then
                        --insert into table stuff
                        --break
                    end
                end
            end
        end
    end
end

function MexUpgradeManagerRNG(aiBrain)
    local homebasex,homebasey = aiBrain:GetArmyStartPos()
    local VDist3Sq = VDist3Sq
    local homepos = {homebasex,GetTerrainHeight(homebasex,homebasey),homebasey}
    local ratio=0.35
    local currentlyUpgrading = 0
    while aiBrain.Status ~= "Defeat" or GetGameTimeSeconds()<250 do
        local extractors = aiBrain:GetListOfUnits(categories.MASSEXTRACTION * (categories.TECH1 + categories.TECH2), true)


        coroutine.yield(40)
    end
    while aiBrain.Status ~= "Defeat" do
        local mexes1 = aiBrain:GetListOfUnits(categories.MASSEXTRACTION - categories.TECH3, true, false)
        local time=GetGameTimeSeconds()
        --[[if aiBrain.EcoManagerPowerStateCheck(aiBrain) then
            WaitSeconds(4)
            continue
        end]]
        local currentupgradecost=0
        local mexes={}
        for i,v in mexes1 do
            --if not v.UCost then
            if v:IsUnitState('Upgrading') and v.UCost then currentupgradecost=currentupgradecost+v.UCost table.remove(mexes,i) continue end
            local spende=GetConsumptionPerSecondEnergy(v)
            local producem=GetProductionPerSecondMass(v)
            local unit=v:GetBlueprint()
            if spende<unit.Economy.MaintenanceConsumptionPerSecondEnergy and spende>0 then
                v.UEmult=spende/unit.Economy.MaintenanceConsumptionPerSecondEnergy
            else
                v.UEmult=1
            end
            if producem>unit.Economy.ProductionPerSecondMass then
                v.UMmult=producem/unit.Economy.ProductionPerSecondMass
            else
                v.UMmult=1
            end
            local uunit=aiBrain:GetUnitBlueprint(unit.General.UpgradesTo)
            local mcost=uunit.Economy.BuildCostMass/uunit.Economy.BuildTime*unit.Economy.BuildRate
            local ecost=uunit.Economy.BuildCostEnergy/uunit.Economy.BuildTime*unit.Economy.BuildRate
            v.UCost=mcost
            v.UECost=ecost
            v.TMCost=uunit.Economy.BuildCostMass
            v.Uupgrade=unit.General.UpgradesTo
        --end
            if not v.UAge then
                v.UAge=time
            end
            v.TAge=1/(1+math.min(120,time-v.UAge)/120)
            table.insert(mexes,v)
        end
        --[[if 10>aiBrain.cmanager.income.r.m*ratio then
            WaitSeconds(3)
            continue
        end]]
        if currentupgradecost<aiBrain.cmanager.income.r.m*ratio then
            table.sort(mexes,function(a,b) return (1+VDist3Sq(a:GetPosition(),homepos)/ScenarioInfo.size[2]/ScenarioInfo.size[2]/2)*(1-VDist3Sq(aiBrain.emanager.enemy.Position,a:GetPosition())/ScenarioInfo.size[2]/ScenarioInfo.size[2]/2)*a.UCost*a.TMCost*a.UECost*a.UEmult*a.TAge/a.UMmult/a.UMmult<(1+VDist3Sq(b:GetPosition(),homepos)/ScenarioInfo.size[2]/ScenarioInfo.size[2]/2)*(1-VDist3Sq(aiBrain.emanager.enemy.Position,b:GetPosition())/ScenarioInfo.size[2]/ScenarioInfo.size[2]/2)*b.UCost*b.TMCost*b.UECost*b.UEmult*b.TAge/b.UMmult/b.UMmult end)
            local startval=aiBrain.cmanager.income.r.m*ratio-currentupgradecost
            --local starte=aiBrain.cmanager.income.r.e*1.3-aiBrain.cmanager.spend.e
            for _,v in mexes do
                if startval>0 then
                    IssueUpgrade({v}, v.Uupgrade)
                    startval=startval-v.UCost
                else
                    break
                end
            end
        end
        coroutine.yield(40)
    end
end

AIFindZoneExpansionPointRNG = function(aiBrain, locationType, radius, position, avoidZones)
    local im = IntelManagerRNG.GetIntelManager(aiBrain)
    local pos = aiBrain.BuilderManagers[locationType].EngineerManager.Location or position
    local zoneSet = aiBrain.Zones.Land.zones
    local currentTime = GetGameTimeSeconds()
    local retPos, retName, refZone
    radius = radius * radius

    if not pos then
        return false
    else
       --RNGLOG('Location Pos is '..repr(pos))
    end
   --RNGLOG('Checking if Dynamic Expansions Table Exist')
    if not table.empty(im.ZoneExpansions.Pathable) then
        for _, v in im.ZoneExpansions.Pathable do
            local skipPos = false
            if avoidZones and avoidZones[v.ZoneID] then
                skipPos = true
            end
            if not skipPos and v and VDist3Sq(pos, v.Position) < radius and not zoneSet[v.ZoneID].BuilderManager.FactoryManager.LocationActive
            and (not zoneSet[v.ZoneID].engineerplatoonallocated or IsDestroyed(zoneSet[v.ZoneID].engineerplatoonallocated)) and (currentTime >= zoneSet[v.ZoneID].lastexpansionattempt + 30 or zoneSet[v.ZoneID].lastexpansionattempt == 0 ) then
                retPos = zoneSet[v.ZoneID].pos
                retName = 'ZONE_'..v.ZoneID
                refZone = v.ZoneID
                break
            end
        end
    end
    if retPos then
        return retPos, retName, refZone
    end
    return false
end

function GetEngineerFactionRNG(engineer)
    if EntityCategoryContains(categories.UEF, engineer) then
        return 'UEF'
    elseif EntityCategoryContains(categories.AEON, engineer) then
        return 'Aeon'
    elseif EntityCategoryContains(categories.CYBRAN, engineer) then
        return 'Cybran'
    elseif EntityCategoryContains(categories.SERAPHIM, engineer) then
        return 'Seraphim'
    elseif EntityCategoryContains(categories.NOMADS, engineer) then
        return 'Nomads'
    else
        return false
    end
end

GetEngineerFactionIndexRNG = function(engineer)
    if EntityCategoryContains(categories.UEF, engineer) then
        return 1
    elseif EntityCategoryContains(categories.AEON, engineer) then
        return 2
    elseif EntityCategoryContains(categories.CYBRAN, engineer) then
        return 3
    elseif EntityCategoryContains(categories.SERAPHIM, engineer) then
        return 4
    else
        return 5
    end
end

function GetTemplateReplacementRNG(aiBrain, building, faction, buildingTmpl)
    local retTemplate = false
    local templateData = aiBrain.CustomUnits[building]
    -- check if we have an original building
    local BuildingExist = nil
    for k,v in buildingTmpl do
        if v[1] == building then
            BuildingExist = true
            break
        end
    end
    -- If there are Custom Units for this unit type and faction
    if templateData and templateData[faction] then
        local rand = Random(1,100)
        local possibles = {}
        -- Add all the possibile replacements into a table
        for k,v in templateData[faction] do
            if rand <= v[2] or not BuildingExist then
                table.insert(possibles, v[1])
            end
        end
        -- If we found a possibility
        if not table.empty(possibles) then
            rand = Random(1,table.getn(possibles))
            local customUnitID = possibles[rand]
            retTemplate = { { building, customUnitID, } }
        end
    end
    return retTemplate
end

function AIBuildBaseTemplateFromLocationRNG(baseTemplate, location)
    local baseT = {}
    if location and baseTemplate then
        for templateNum, template in baseTemplate do
            baseT[templateNum] = {}
            for rowNum,rowData in template do -- rowNum, rowData in template do
                if type(rowData[1]) == 'number' then
                    baseT[templateNum][rowNum] = {}
                    baseT[templateNum][rowNum][1] = math.floor(rowData[1] + location[1]) + 0.5
                    baseT[templateNum][rowNum][2] = math.floor(rowData[2] + location[3]) + 0.5
                    baseT[templateNum][rowNum][3] = 0
                else
                    baseT[templateNum][rowNum] = template[rowNum]
                end
            end
        end
    end
    return baseT
end

function GetBuildUnit(aiBrain, eng, buildingTemplate, buildUnit)
    local IsRestricted = import('/lua/game.lua').IsRestricted
    local index = aiBrain:GetArmyIndex()
    local whatToBuild = aiBrain:DecideWhatToBuild(eng, buildUnit, buildingTemplate)
    if not whatToBuild then
        local BuildUnitWithID
        for Key, Data in buildingTemplate do
            if Data[1] and Data[2] and Data[1] == buildUnit then
                BuildUnitWithID = Data[2]
                break
            end
        end
        if IsRestricted(BuildUnitWithID, index) then
            WARN('AI-RNG : Unit '..tostring(BuildUnitWithID)..' is restricted, cannot build')
            return false
        end
        if BuildUnitWithID then
            whatToBuild = BuildUnitWithID
        else
            WARN('AI-RNG : Unable to find unit to build, type was '..tostring(buildUnit))
            return false
        end
    end
    return whatToBuild
end

function GetBuildLocationRNG(aiBrain, buildingTemplate, baseTemplate, buildUnit, eng, adjacent, category, radius, relative, increaseSearch)
    -- A small note that caught me out.
    -- Always set the engineers position to zero in the build location otherwise youll get buildings are super strange angles
    -- and you wont understand why. I think the 3rd param is actually rotation not height.
    local buildLocation = false
    local borderWarning = false
    if aiBrain.CustomUnits and aiBrain.CustomUnits[buildUnit] then
        local faction = GetEngineerFactionRNG(eng)
        buildingTemplate = GetTemplateReplacementRNG(aiBrain, buildUnit, faction, buildingTemplate)
    end
    if not relative then
        relative = true
    end
    local whatToBuild = GetBuildUnit(aiBrain, eng, buildingTemplate, buildUnit)
    if not whatToBuild then
        return false
    end
    local engPos = eng:GetPosition()
    local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
    local function normalposition(vec)
        return {vec[1],GetTerrainHeight(vec[1],vec[2]),vec[2]}
    end
    local function heightbuildpos(vec)
        return {vec[1],vec[2],0}
    end
    
    if adjacent then
        local searchRadius = radius
        if increaseSearch then
            searchRadius = radius + increaseSearch
        end
        ----LOG('searchRadius is '..searchRadius)
        local unitSize = aiBrain:GetUnitBlueprint(whatToBuild).Physics
        local testUnits  = aiBrain:GetUnitsAroundPoint(category, engPos, searchRadius, 'Ally')
        --LOG('Number of test units found '..table.getn(testUnits))
        local index = aiBrain:GetArmyIndex()
        local closeUnits = {}
        for _, v in testUnits do
            if not v.Dead and not v:IsBeingBuilt() and v:GetAIBrain():GetArmyIndex() == index then
                table.insert(closeUnits, v)
            end
        end
        --LOG('Close units found '..table.getn(closeUnits))
        local template = {}
        table.insert(template, {})
        table.insert(template[1], { buildUnit })
        for _,unit in closeUnits do
            local targetSize = unit:GetBlueprint().Physics
            local targetPos = unit:GetPosition()
            local differenceX=math.abs(targetSize.SkirtSizeX-unitSize.SkirtSizeX)
            local offsetX=math.floor(differenceX/2)
            local differenceZ=math.abs(targetSize.SkirtSizeZ-unitSize.SkirtSizeZ)
            local offsetZ=math.floor(differenceZ/2)
            local offsetfactory=0
            if EntityCategoryContains(categories.FACTORY, unit) and (buildUnit=='T1LandFactory' or buildUnit=='T1AirFactory' or buildUnit=='T2SupportLandFactory' or buildUnit=='T3SupportLandFactory') then
                offsetfactory=2
            end
            -- Top/bottom of unit
            for i=-offsetX,offsetX do
                local testPos = { targetPos[1] + (i * 1), targetPos[3]-targetSize.SkirtSizeZ/2-(unitSize.SkirtSizeZ/2)-offsetfactory, 0 }
                local testPos2 = { targetPos[1] + (i * 1), targetPos[3]+targetSize.SkirtSizeZ/2+(unitSize.SkirtSizeZ/2)+offsetfactory, 0 }
                -- check if the buildplace is to close to the border or inside buildable area
                if testPos[1] > 8 and testPos[1] < ScenarioInfo.size[1] - 8 and testPos[2] > 8 and testPos[2] < ScenarioInfo.size[2] - 8 then
                    if CanBuildStructureAt(aiBrain, whatToBuild, normalposition(testPos)) and VDist3Sq(engPos,normalposition(testPos)) < radius * radius then
                        return heightbuildpos(testPos), whatToBuild
                    end
                end
                if testPos2[1] > 8 and testPos2[1] < ScenarioInfo.size[1] - 8 and testPos2[2] > 8 and testPos2[2] < ScenarioInfo.size[2] - 8 then
                    if CanBuildStructureAt(aiBrain, whatToBuild, normalposition(testPos2)) then
                        if CanBuildStructureAt(aiBrain, whatToBuild, normalposition(testPos2)) and VDist3Sq(engPos,normalposition(testPos2)) < radius * radius then
                            return heightbuildpos(testPos2), whatToBuild
                        end
                    end
                end
            end
            -- Sides of unit
            for i=-offsetZ,offsetZ do
                local testPos = { targetPos[1]-targetSize.SkirtSizeX/2-(unitSize.SkirtSizeX/2)-offsetfactory, targetPos[3] + (i * 1), 0 }
                local testPos2 = { targetPos[1]+targetSize.SkirtSizeX/2+(unitSize.SkirtSizeX/2)+offsetfactory, targetPos[3] + (i * 1), 0 }
                if testPos[1] > 8 and testPos[1] < ScenarioInfo.size[1] - 8 and testPos[2] > 8 and testPos[2] < ScenarioInfo.size[2] - 8 then
                    if CanBuildStructureAt(aiBrain, whatToBuild, normalposition(testPos)) and VDist3Sq(engPos,normalposition(testPos)) < radius * radius then
                        return heightbuildpos(testPos), whatToBuild
                    end
                end
                if testPos2[1] > 8 and testPos2[1] < ScenarioInfo.size[1] - 8 and testPos2[2] > 8 and testPos2[2] < ScenarioInfo.size[2] - 8 then
                    if CanBuildStructureAt(aiBrain, whatToBuild, normalposition(testPos2)) then
                        if CanBuildStructureAt(aiBrain, whatToBuild, normalposition(testPos2)) and VDist3Sq(engPos,normalposition(testPos2)) < radius * radius then
                            return heightbuildpos(testPos2), whatToBuild
                        end
                    end
                end
            end
        end
    else
        local location = aiBrain:FindPlaceToBuild(buildUnit, whatToBuild, baseTemplate, relative, eng, nil, engPos[1], engPos[3])
        --LOG('Relative location is '..tostring(location[1])..':'..tostring(location[2]))
        if location and relative then
            local relativeLoc = {location[1] + engPos[1], location[2] + engPos[3], 0}
            if relativeLoc[1] - playableArea[1] <= 8 or relativeLoc[1] >= playableArea[3] - 8 or relativeLoc[2] - playableArea[2] <= 8 or relativeLoc[2] >= playableArea[4] - 8 then
                borderWarning = true
            end
            --LOG('Location returned is '..tostring(relativeLoc[1])..':'..tostring(relativeLoc[2]))
            return relativeLoc, whatToBuild, borderWarning
        else
            return location, whatToBuild, borderWarning
        end
    end
    return false
end


function GetAngleRNG(myX, myZ, myDestX, myDestZ, theirX, theirZ)
    --[[ Softles gave me this to help improve retreat mechanics
       If (myX,myZ) is the platoon, (myDestX,myDestZ) the mass point, and (theirX, theirZ) the enemy threat
       Then 0 => mass point in same direction as enemy, 1 => mass point in complete opposite direction
       You, your dest, and them form a triangle.
       First work out side lengths
    ]]
    local aSq = (myX - myDestX)*(myX - myDestX) + (myZ - myDestZ)*(myZ - myDestZ)
    local bSq = (myX - theirX)*(myX - theirX) + (myZ - theirZ)*(myZ - theirZ)
    local cSq = (myDestX - theirX)*(myDestX - theirX) + (myDestZ - theirZ)*(myDestZ - theirZ)
    -- Quick check to see if anything is a 0 length (a problem, since it then wouldn't be a triangle)
    if aSq == 0 or bSq == 0 or cSq == 0 then
        return 0
    end
    -- Now use cosine rule to get angle
    -- c^2 = b^2 + a^2 - 2ab*cos(angle) => angle = acos((a^2+b^2-c^2)/2ab)
    local prepStep = (bSq + aSq - cSq)/(2*math.sqrt(aSq*bSq))
    -- Quickly check it is between 1 and -1, if it gets rounded (because computers) to -1.0000001 then we'd throw an error (bad!)
    if prepStep > 1 then
        return 0
    elseif prepStep < -1 then
        return 1
    end
    local angle = math.acos(prepStep)
    -- Now normalise into a [0 to 1] value
    return angle/math.pi
end

function ClosestResourceMarkersWithinRadius(aiBrain, pos, markerType, radius, canBuild, maxThreat, threatType)
    local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
    local adaptiveResourceMarkers = GetMarkersRNG()
    local markerTable = {}
    local radiusLimit = radius * radius
    for k, v in adaptiveResourceMarkers do
        if v.type == markerType then
            if v.position[1] > playableArea[1] and v.position[1] < playableArea[3] and v.position[3] > playableArea[2] and v.position[3] < playableArea[4] then
                RNGINSERT(markerTable, {Position = v.position, Name = k, Distance = VDist2Sq(pos[1], pos[3], v.position[1], v.position[3])})
            end
        end
    end
    table.sort(markerTable, function(a,b) return a.Distance < b.Distance end)
    for k, v in markerTable do
        if v.Distance <= radiusLimit then
            --RNGLOG('Marker is within distance with '..v.Distance)
            if canBuild then
                if CanBuildStructureAt(aiBrain, 'ueb1102', v.Position) then
                    --RNGLOG('We can build on this hydro '..repr(v.Position))
                    if maxThreat and threatType then
                        --RNGLOG('Threat at position is '..GetThreatAtPosition(aiBrain, v.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, threatType))
                        --RNGLOG('Max Threat is')
                        if GetThreatAtPosition(aiBrain, v.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, threatType) < maxThreat then
                            --RNGLOG('Return true with threat check')
                            return v
                        end
                    else
                        return v
                    end
                end
            else
                return v
            end
            
        end
    end
    --RNGLOG('ClosestMarkersWithin radius failing '..radius)
    return false
end

function DrawCirclePoints(points, radius, center)
    local circlePoints = {}
    local slice = 2 * math.pi / points
    for i=1, points do
        local angle = slice * i
        local newX = center[1] + radius * math.cos(angle)
        local newY = center[3] + radius * math.sin(angle)
        table.insert(circlePoints, { newX, 0 , newY})
    end
    return circlePoints
end

function GetBomberGroundAttackPosition(aiBrain, platoon, target, platoonPosition, targetPosition, targetDistance)
    local function DrawCirclePoints(points, radius, center)
        local circlePoints = {}
        local slice = 2 * math.pi / points
        for i=1, points do
            local angle = slice * i
            local newX = center[1] + radius * math.cos(angle)
            local newY = center[3] + radius * math.sin(angle)
            table.insert(circlePoints, { newX, 0 , newY})
        end
        return circlePoints
    end
    --LOG('Platoon Strike radius is '..repr(platoon['rngdata'].PlatoonStrikeRadius))
    local pointTable = DrawCirclePoints(8, platoon['rngdata'].PlatoonStrikeRadius, targetPosition)
    local maxDamage = target.Blueprint.Economy.BuildCostMass
    local setPointPos = false
    local strikeCategories = categories.STRUCTURE
    if target:GetFractionComplete() < 0.8 then
        strikeCategories = categories.STRUCTURE + categories.ENGINEER
    end
    -- Check radius of target position to set the minimum damage
    local enemiesAroundTarget = GetUnitsAroundPoint(aiBrain, strikeCategories, targetPosition, platoon['rngdata'].PlatoonStrikeRadius + 4, 'Enemy')
    local damage = 0
    for _, unit in enemiesAroundTarget do
        if not unit.Dead then
            local unitPos = unit:GetPosition()
            local damageRadius = (unit.Blueprint.SizeX or 1 + unit.Blueprint.SizeZ or 1) / 4
            --RNGLOG('Unit is '..unit.UnitId)
            --RNGLOG('unitPos is '..repr(unitPos))
            --RNGLOG('Distance between units '..VDist2(targetPosition[1], targetPosition[3], unitPos[1], unitPos[3]))
            --RNGLOG('strike radius + damage radius '..(platoon['rngdata'].PlatoonStrikeRadius + damageRadius))
            if VDist2(targetPosition[1], targetPosition[3], unitPos[1], unitPos[3]) <= (platoon['rngdata'].PlatoonStrikeRadius * 1.9 + damageRadius) then
                if platoon['rngdata'].PlatoonStrikeDamage > unit.Blueprint.Defense.MaxHealth or platoon['rngdata'].PlatoonStrikeDamage > (unit:GetHealth() / 3) then
                    damage = damage + unit.Blueprint.Economy.BuildCostMass
                else
                    --RNGLOG('Strike will not kill target or 3 passes')
                end
            end
        end
        --RNGLOG('Current potential strike damage '..damage)
    end
    maxDamage = damage
    -- Now look at points for a better strike target
    --RNGLOG('StrikeForce Looking for better strike target position')
    for _, pointPos in pointTable do
        --RNGLOG('pointPos is '..repr(pointPos))
        --RNGLOG('pointPos distance from targetpos is '..VDist2(pointPos[1],pointPos[2],targetPosition[1],targetPosition[3]))
        
        local damage = 0
        local enemiesAroundTarget = GetUnitsAroundPoint(aiBrain, strikeCategories, {pointPos[1], 0, pointPos[3]}, platoon['rngdata'].PlatoonStrikeRadius + 4, 'Enemy')
        --RNGLOG('Table count of enemies at pointPos '..table.getn(enemiesAroundTarget))
        for _, unit in enemiesAroundTarget do
            if not unit.Dead then
                local unitPos = unit:GetPosition()
                local damageRadius = (unit.Blueprint.SizeX or 1 + unit.Blueprint.SizeZ or 1) / 4
                --RNGLOG('Unit is '..unit.UnitId)
                --RNGLOG('unitPos is '..repr(unitPos))
                --RNGLOG('Distance between units '..VDist2(targetPosition[1], targetPosition[3], unitPos[1], unitPos[3]))
                --RNGLOG('strike radius + damage radius '..(platoon['rngdata'].PlatoonStrikeRadius + damageRadius))
                if VDist2(targetPosition[1], targetPosition[3], unitPos[1], unitPos[3]) <= (platoon['rngdata'].PlatoonStrikeRadius * 1.9 + damageRadius) then
                    if platoon['rngdata'].PlatoonStrikeDamage > unit.Blueprint.Defense.MaxHealth or platoon['rngdata'].PlatoonStrikeDamage > (unit:GetHealth() / 3) then
                        damage = damage + unit.Blueprint.Economy.BuildCostMass
                    else
                        --RNGLOG('Strike will not kill target or 3 passes')
                    end
                end
            end
            --RNGLOG('Initial strike damage '..damage)
        end
        --RNGLOG('Current maxDamage is '..maxDamage)
        if damage > maxDamage then
            --RNGLOG('StrikeForce found better strike damage of '..damage)
            maxDamage = damage
            setPointPos = pointPos
        end
    end
    if setPointPos then
        setPointPos = {setPointPos[1], GetTerrainHeight(setPointPos[1], setPointPos[3]), setPointPos[3]} 
        local movePoint = lerpy(platoonPosition, targetPosition, {targetDistance, targetDistance - (platoon['rngdata'].PlatoonStrikeRadiusDistance + 25)})
        if aiBrain.RNGDEBUG then
            platoon:ForkThread(platoon.DrawTargetRadius, movePoint, platoon['rngdata'].PlatoonStrikeRadius)
            platoon:ForkThread(platoon.DrawTargetRadius, setPointPos, platoon['rngdata'].PlatoonStrikeRadius)
        end
        return setPointPos, movePoint
    end
    return false
end

-- need to ask maudlin about these unless I want to reinvent the rather cleverly done wheel here

function GetBomberRange(oUnit)
    -- Gets  + 25 added to the return value. Assume to give the strat a better runup?
    local oBP = oUnit:GetBlueprint()
    local iRange = 0
    for sWeaponRef, tWeapon in oBP.Weapon do
        if tWeapon.WeaponCategory == 'Bomb' or tWeapon.WeaponCategory == 'Direct Fire' then
            if (tWeapon.MaxRadius or 0) > iRange then
                iRange = tWeapon.MaxRadius
            end
        end
    end
    return iRange
end

function DrawAngleDistance(Pos1, Pos2, Pos3)
    local counter = 0
    while counter < 500 do
        WaitTicks(2)
        DrawCircle(Pos1, 10, '0000FF')
        DrawCircle(Pos2, 10, '0000FF')
        DrawCircle(Pos3, 10, 'FFA500')

        DrawLine(Pos1, Pos2, '0000FF')
        DrawLine(Pos3, Pos2, 'FFA500')
        counter = counter + 1
    end
end

function GetAngleToPosition(Pos1, Pos2)
    -- Returns an angle 0 = north, 90 = east, etc. based on direction of Pos2 from Pos1
    local deltaY = Pos2[3] - Pos1[3]
    local deltaX = Pos2[1] - Pos1[1]
    local angle = math.atan2(deltaY , deltaX) * 180 / math.pi
    angle =  modulo(angle + 360, 360) 
    --local newPos = GetPositionTowardsAngle(Pos2, angle, 30)
    --ForkThread(DrawAngleDistance, Pos1, Pos2, newPos)
    return angle
end

function GetPointOffset(position, angle, distance)
    local radians = math.rad(angle)  -- Convert angle to radians
    local offsetX = distance * math.cos(radians)  -- X offset
    local offsetZ = distance * math.sin(radians)  -- Z offset
    return { position[1] + offsetX, position[2], position[3] + offsetZ }
end

function GetHeadingAngle(unit)
    if unit and not unit.Dead then
        return modulo(450 - unit:GetHeading() * (180 / math.pi), 360)
    end
end

function modulo(a, b)
    return a - math.floor(a / b) * b
end

function GetPositionTowardsAngle(Pos1, angle, distance)
    -- Calculate the new position based on the provided angle and distance
    local angleRad = math.rad(angle) -- Convert angle to radians
    local newX = Pos1[1] + distance * math.cos(angleRad)
    local newZ = Pos1[3] + distance * math.sin(angleRad)

    -- Return the new position as a vector3
    return {newX, Pos1[2], newZ}
end


function ShieldProtectingTargetRNG(aiBrain, targetUnit, shields)
    local function GetShieldRadiusAboveGroundSquaredRNG(shield)
        local width = shield.Blueprint.Defense.Shield.ShieldSize
        local height = shield.Blueprint.Defense.Shield.ShieldVerticalOffset
    
        return width * width - height * height
    end
    -- if no target unit, then we can skip
    if not targetUnit then
        return false
    end
    -- defensive programming
    shields = shields or GetUnitsAroundPoint(aiBrain, CategoriesShield, targetUnit:GetPosition(), 50, 'Enemy')
    -- determine if target unit is part of some shield
    local tPos = targetUnit:GetPosition()
    for _, shield in shields do
        if not shield.Dead then
            local shieldPos = shield:GetPosition()
            local shieldSizeSq = GetShieldRadiusAboveGroundSquaredRNG(shield)
            if VDist2Sq(tPos[1], tPos[3], shieldPos[1], shieldPos[3]) < shieldSizeSq then
                return true
            end
        end
    end
    return false
end

function GetClosestShieldProtectingTargetRNG(attackingUnit, targetUnit, attackingPosition)
    local function GetShieldRadiusAboveGroundSquaredRNG(shield)
        local width = shield.Blueprint.Defense.Shield.ShieldSize
        local height = shield.Blueprint.Defense.Shield.ShieldVerticalOffset
    
        return width * width - height * height
    end
    if not targetUnit or not attackingUnit then
        return false
    end
    local blockingList = {}

    -- If targetUnit is within the radius of any shields, the shields need to be destroyed.
    local aiBrain
    local aPos = attackingUnit:GetPosition()
    if attackingUnit then
        aiBrain = attackingUnit:GetAIBrain()
        aPos = attackingUnit:GetPosition()
    elseif attackingPosition then
        aPos = attackingPosition
    end

    local tPos = targetUnit:GetPosition()
    
    local shields = aiBrain:GetUnitsAroundPoint(categories.SHIELD * categories.STRUCTURE, targetUnit:GetPosition(), 50, 'Enemy')
    for _, shield in shields do
        if not shield.Dead then
            local shieldPos = shield:GetPosition()
            local shieldSizeSq = GetShieldRadiusAboveGroundSquaredRNG(shield)

            if VDist2Sq(tPos[1], tPos[3], shieldPos[1], shieldPos[3]) < shieldSizeSq then
                table.insert(blockingList, shield)
            end
        end
    end

    -- Return the closest blocking shield
    local closest = false
    local closestDistSq = 999999
    local closestHealth = 0
    for _, shield in blockingList do
        if shield and not shield.Dead then
            local shieldPos = shield:GetPosition()
            local distSq = VDist2Sq(aPos[1], aPos[3], shieldPos[1], shieldPos[3])

            if distSq < closestDistSq then
                closest = shield
                closestDistSq = distSq
            end
        end
    end
    local shieldHealth = 0
    if closest.MyShield then
        shieldHealth = closest.MyShield:GetHealth()
    end
    return closest, shieldHealth
end

-- Borrowed this from Balth I think.
function CalculatedDPSRNG(weapon)
    -- Base values
    local MathMax = math.max
    local MathFloor = math.floor
    local ProjectileCount
    --LOG('Running Calculated DPS')
    --LOG('Weapon '..repr(weapon))
    if weapon.MuzzleSalvoDelay == 0 then
        ProjectileCount = MathMax(1, RNGGETN(weapon.RackBones[1].MuzzleBones or {'nehh'} ) )
    else
        ProjectileCount = (weapon.MuzzleSalvoSize or 1)
    end
    if weapon.RackFireTogether then
        ProjectileCount = ProjectileCount * MathMax(1, RNGGETN(weapon.RackBones or {'nehh'} ) )
    end
    -- Game logic rounds the timings to the nearest tick --  MathMax(0.1, 1 / (weapon.RateOfFire or 1)) for unrounded values
    local DamageInterval = MathFloor((MathMax(0.1, 1 / (weapon.RateOfFire or 1)) * 10) + 0.5) / 10 + ProjectileCount * (MathMax(weapon.MuzzleSalvoDelay or 0, weapon.MuzzleChargeDelay or 0) * (weapon.MuzzleSalvoSize or 1) )
    local Damage = ((weapon.Damage or 0) + (weapon.NukeInnerRingDamage or 0)) * ProjectileCount * (weapon.DoTPulses or 1)

    -- Beam calculations.
    if weapon.BeamLifetime and weapon.BeamLifetime == 0 then
        -- Unending beam. Interval is based on collision delay only.
        DamageInterval = 0.1 + (weapon.BeamCollisionDelay or 0)
    elseif weapon.BeamLifetime and weapon.BeamLifetime > 0 then
        -- Uncontinuous beam. Interval from start to next start.
        DamageInterval = DamageInterval + weapon.BeamLifetime
        -- Damage is calculated as a single glob, beam weapons are typically underappreciated
        Damage = Damage * (weapon.BeamLifetime / (0.1 + (weapon.BeamCollisionDelay or 0)))
    end

    return Damage * (1 / DamageInterval) or 0
end

function PerformEngReclaim(aiBrain, eng, minimumReclaim)
    local engPos = eng:GetPosition()
    local maxReclaimDistance = eng.Blueprint.Economy.MaxBuildDistance or 10
    maxReclaimDistance = maxReclaimDistance * maxReclaimDistance
    local rectDef = Rect(engPos[1] - 10, engPos[3] - 10, engPos[1] + 10, engPos[3] + 10)
    local reclaimRect = GetReclaimablesInRect(rectDef)
    local maxReclaimCount = 0
    local reclaimed = false
    if reclaimRect then
        local closeReclaim = {}
        for c, b in reclaimRect do
            if not IsProp(b) then continue end
            if b.MaxMassReclaim and b.MaxMassReclaim >= minimumReclaim then
                if VDist3Sq(engPos, b.CachePosition) <= maxReclaimDistance then
                    RNGINSERT(closeReclaim, b)
                    maxReclaimCount = maxReclaimCount + 1
                end
            end
            if maxReclaimCount > 10 then
                break
            end
        end
        if RNGGETN(closeReclaim) > 0 then
            IssueClearCommands({eng})
            for _, rec in closeReclaim do
                IssueReclaim({eng}, rec)
            end
            coroutine.yield(20)
            reclaimed = true
        end
    end
    return reclaimed
end

function GetNumberUnitsBeingBuilt(aiBrain, category)
    local unitsBuilding = aiBrain:GetListOfUnits(categories.CONSTRUCTION + category, false)
    local catNumBuilding = 0
    for _, unit in unitsBuilding do
        if not unit.Dead then
            if unit:IsUnitState('Building') then
                if unit.UnitBeingBuilt and unit.UnitBeingBuilt ~= unit.UnitBeingAssist then
                    local buildingUnit = unit.UnitBeingBuilt
                    if buildingUnit and not buildingUnit.Dead and EntityCategoryContains(category, buildingUnit) then
                        catNumBuilding = catNumBuilding + 1
                    end
                end
            elseif EntityCategoryContains(category, unit) and unit:GetFractionComplete() < 1 then
                catNumBuilding = catNumBuilding + 1
            end
        end
    end
    --RNGLOG('Number of units building from GetNumberUnitsBuilding (which is experimentals right now) is '..catNumBuilding)
    return catNumBuilding
end

function GetNumberUnitsBuilding(aiBrain, category)
    local unitsBuilding = aiBrain:GetListOfUnits(categories.CONSTRUCTION, false)
    local catNumBuilding = 0
    for _, unit in unitsBuilding do
        if not unit:BeenDestroyed() and unit:IsUnitState('Building') then
            if unit.UnitBeingBuilt and unit.UnitBeingBuilt ~= unit.UnitBeingAssist then
                local buildingUnit = unit.UnitBeingBuilt
                if buildingUnit and not buildingUnit.Dead and EntityCategoryContains(category, buildingUnit) then
                    catNumBuilding = catNumBuilding + 1
                end
            end
        end
        --DUNCAN - added to pick up engineers that havent started building yet... does it work?
        if not unit:BeenDestroyed() and not unit:IsUnitState('Building') then
            if unit.UnitBeingBuilt and unit.UnitBeingBuilt ~= unit.UnitBeingAssist then
                local buildingUnit = unit.UnitBeingBuilt
                if buildingUnit and not buildingUnit.Dead and EntityCategoryContains(category, buildingUnit) then
                    --RNGLOG('Engi building but not in building state...')
                    catNumBuilding = catNumBuilding + 1
                end
            end
        end
    end
    --RNGLOG('Number of units building from GetNumberUnitsBuilding (which is experimentals right now) is '..catNumBuilding)
    return catNumBuilding
end

GenerateDefensivePointTable = function (aiBrain, baseName, range, position)
    local function DrawCirclePoints(points, radius, center)
        local circlePoints = {}
        local slice = 2 * math.pi / points
        for i=1, points do
            local angle = slice * i
            local newX = center[1] + radius * math.cos(angle)
            local newY = center[3] + radius * math.sin(angle)
            table.insert(circlePoints, { newX, GetTerrainHeight(newX, newY) , newY})
        end
        return circlePoints
    end
    local defensivePointTable = {
        [1] = {},
        [2] = {}
    }
    local defensivePointsT1 = DrawCirclePoints(8, range/3, position)
    local defensivePointT1Key = 1
    if position[2] == 0 then
        position[2] = GetTerrainHeight(position[1], position[3])
    end
    --RNGLOG('DefensivePoints being generated')
    for _, v in defensivePointsT1 do
        if v[1] <= 15 or v[1] >= ScenarioInfo.size[1] - 15 or v[3] <= 15 or v[3] >= ScenarioInfo.size[2] - 15 then
            continue
        end
        --RNGLOG('Surface Height  '..GetSurfaceHeight(v[1], v[3])..' vs base pos height'..position[2])
        if GetTerrainHeight(v[1], v[3]) - 4 > position[2] then
            --RNGLOG('SurfaceHeight of base position '..position[2]..'surface height of modified defensivepoint '..GetSurfaceHeight(v[1], v[3]))
            continue
        end
        if GetTerrainHeight(v[1], v[3]) >= GetSurfaceHeight(v[1], v[3]) then
            defensivePointTable[1][defensivePointT1Key] = {Position = v, Radius = 15, Enabled = true, Shields = {}, DirectFire = {}, AntiAir = {}, Indirectfire = {}, TMD = {}, TML = {}, AntiSurfaceThreat = 0, AntiAirThreat = 0}
        else
            defensivePointTable[1][defensivePointT1Key] = {Position = v, Radius = 15, Enabled = false, Shields = {}, DirectFire = {}, AntiAir = {}, Indirectfire = {}, TMD = {}, TML = {}, AntiSurfaceThreat = 0, AntiAirThreat = 0}
        end
        defensivePointT1Key = defensivePointT1Key + 1
    end
    local defensivePointsT2 = DrawCirclePoints(8, range/2, position)
    local pointCheck = GetAngleToPosition(position, aiBrain.MapCenterPoint)
    local acuHoldPoint = false
    local defensivePointT2Key = 1
    for k, v in defensivePointsT2 do
        if v[1] <= 15 or v[1] >= ScenarioInfo.size[1] - 15 or v[3] <= 15 or v[3] >= ScenarioInfo.size[2] - 15 then
            continue
        end
        --RNGLOG('Surface Height  '..GetSurfaceHeight(v[1], v[3])..' vs base pos height'..position[2])
        if GetTerrainHeight(v[1], v[3]) - 4 > position[2] then
            --RNGLOG('SurfaceHeight of base position '..position[2]..'surface height of modified defensivepoint '..GetSurfaceHeight(v[1], v[3]))
            continue
        end
        if GetTerrainHeight(v[1], v[3]) >= GetSurfaceHeight(v[1], v[3]) then
            defensivePointTable[2][defensivePointT2Key] = {Position = v, Radius = 15, Enabled = true, AcuHoldPosition = false, Shields = {}, DirectFire = {}, AntiAir = {}, IndirectFire = {}, TMD = {}, TML = {}, AntiSurfaceThreat = 0, AntiAirThreat = 0}
            local pointAngle = GetAngleToPosition(position, v)
            local graphArea = NavUtils.GetLabel('Land', v)
            if (not acuHoldPoint or (math.abs(pointCheck - pointAngle) < acuHoldPoint.Angle)) and graphArea then
                acuHoldPoint = { Key = defensivePointT2Key, Angle = math.abs(pointCheck - pointAngle)}
            end
        else
            defensivePointTable[2][defensivePointT2Key] = {Position = v, Radius = 15, Enabled = false, AcuHoldPosition = false, Shields = {}, DirectFire = {}, AntiAir = {}, IndirectFire = {}, TMD = {}, TML = {}, AntiSurfaceThreat = 0, AntiAirThreat = 0}
        end
        defensivePointT2Key = defensivePointT2Key + 1
    end
    if acuHoldPoint then
        defensivePointTable[2][acuHoldPoint.Key].AcuHoldPosition = true
        aiBrain.BrainIntel.ACUDefensivePositionKeyTable[baseName] = { PositionKey = acuHoldPoint.Key }
        --LOG('ACU Hold position set')
        --LOG('Key is '..repr(aiBrain.BrainIntel.ACUDefensivePositionKeyTable))
        --LOG('defensive point is '..repr(defensivePointTable[2][acuHoldPoint.Key]))
    end
    return defensivePointTable
end

GetDefensivePointRNG = function(aiBrain, baseLocation, pointTier, type)
    -- Finds the best defensive point based on tier and angle of last seen enemy, requires base perimeter monitoring system
    local defensivePoint = false
    local basePosition = aiBrain.BuilderManagers[baseLocation].Position
    if type == 'Land' then
        local bestPoint = false
        local bestIndex = false
        if not RNGTableEmpty(aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier]) then
            if aiBrain.BasePerimeterMonitor[baseLocation].RecentLandAngle then
                local pointCheck = aiBrain.BasePerimeterMonitor[baseLocation].RecentLandAngle
                for _, v in aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier] do
                    local pointAngle = GetAngleToPosition(basePosition, v.Position)
                    if not bestPoint or (math.abs(pointCheck - pointAngle) < bestPoint.Angle) then
                        if bestPoint then
                            --RNGLOG('Angle to find '..aiBrain.BasePerimeterMonitor[baseLocation].RecentLandAngle..' bestPoint was '..bestPoint.Angle..' but is now '..repr({ Position = v, Angle = pointAngle}))
                        end
                        bestPoint = { Position = v.Position, Angle = math.abs(pointCheck - pointAngle)}
                    end
                end
            end
        end
        if bestPoint then
            defensivePoint = bestPoint.Position
        end
        --RNGLOG('defensivePoint being passed to engineer build platoon function'..repr(defensivePoint)..' bestpointangle is '..bestPoint.Angle)
    elseif type == 'AntiAir' then
        local bestPoint = false
        local bestIndex = false
        local acuDefenseRequired = false
        --RNGLOG('Performing DirectFire Structure Check')
        if pointTier == 2 and aiBrain.IntelManager.StrategyFlags.EnemyAirSnipeThreat then
            local positionKey = aiBrain.BrainIntel.ACUDefensivePositionKeyTable[baseLocation].PositionKey
            if positionKey then
                local aaCovered
                local aaCount = 0
                for k , v in aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier][positionKey].AntiAir do
                    if v and not v.Dead then
                        aaCount = aaCount + 1
                        if aaCount > 1 then
                            aaCovered = true
                            break
                        end
                    end
                end
                if not aaCovered then
                    --LOG('ACU defense required during engineer build')
                    acuDefenseRequired = true
                end
                bestPoint = aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier][positionKey]
            end
        end 
        if not acuDefenseRequired then
            if not RNGTableEmpty(aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier]) then
                if aiBrain.BasePerimeterMonitor[baseLocation].RecentLandAngle then
                    local pointCheck = aiBrain.BasePerimeterMonitor[baseLocation].RecentLandAngle
                    for _, v in aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier] do
                        local pointAngle = GetAngleToPosition(basePosition, v.Position)
                        if not bestPoint or (math.abs(pointCheck - pointAngle) < bestPoint.Angle) then
                            if bestPoint then
                                --RNGLOG('Angle to find '..aiBrain.BasePerimeterMonitor[baseLocation].RecentLandAngle..' bestPoint was '..bestPoint.Angle..' but is now '..repr({ Position = v, Angle = pointAngle}))
                            end
                            bestPoint = { Position = v.Position, Angle = math.abs(pointCheck - pointAngle)}
                        end
                    end
                end
            end
        end
        if bestPoint then
            --LOG('returning defensivePoint for aa defense '..repr(bestPoint.Position))
            defensivePoint = bestPoint.Position
        end
        --RNGLOG('defensivePoint being passed to engineer build platoon function'..repr(defensivePoint)..' bestpointangle is '..bestPoint.Angle)
    elseif type == 'Silo' then
        local bestPoint = false
        local bestIndex = false
        if not RNGTableEmpty(aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier]) then
            if aiBrain.BasePerimeterMonitor[baseLocation].RecentMobileSiloAngle then
                --LOG('MobileSilo recent angle '..tostring(aiBrain.BasePerimeterMonitor[baseLocation].RecentMobileSiloAngle))
                --LOG('Point Tier '..tostring(pointTier))
                local pointCheck = aiBrain.BasePerimeterMonitor[baseLocation].RecentMobileSiloAngle
                for _, v in aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier] do
                    local pointAngle = GetAngleToPosition(basePosition, v.Position)
                    if not bestPoint or (math.abs(pointCheck - pointAngle) < bestPoint.Angle) then
                        if bestPoint then
                            --RNGLOG('Angle to find '..aiBrain.BasePerimeterMonitor[baseLocation].RecentLandAngle..' bestPoint was '..bestPoint.Angle..' but is now '..repr({ Position = v, Angle = pointAngle}))
                        end
                        bestPoint = { Position = v.Position, Angle = math.abs(pointCheck - pointAngle)}
                    end
                end
            end
        end
        if bestPoint then
            if aiBrain:GetNumUnitsAroundPoint(categories.MOBILE * (categories.DIRECTFIRE + categories.INDIRECTFIRE), bestPoint.Position, 25, 'Enemy') > 0 then
                defensivePoint = aiBrain.BuilderManagers[baseLocation].Position
            else
                defensivePoint = bestPoint.Position
            end
        end
    elseif type == 'TML' then
        local bestPoint = false
        local bestIndex = false
        if not RNGTableEmpty(aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier]) then
            if aiBrain.BasePerimeterMonitor[baseLocation].RecentTMLAngle then
                local pointCheck = aiBrain.BasePerimeterMonitor[baseLocation].RecentTMLAngle
                for _, v in aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier] do
                    local pointAngle = GetAngleToPosition(basePosition, v.Position)
                    if bestPoint.Angle then
                        --RNGLOG('Defensive Point Check '..(math.abs(pointCheck - pointAngle)..' is it less than '..bestPoint.Angle))
                    end
                    if not bestPoint or (math.abs(pointCheck - pointAngle) < bestPoint.Angle) then
                        if bestPoint then
                            --RNGLOG('TML Angle to find '..aiBrain.BasePerimeterMonitor[baseLocation].RecentTMLAngle..' bestPoint was '..bestPoint.Angle..' but is now '..repr({ Position = v, Angle = pointAngle}))
                        end
                        bestPoint = { Position = v.Position, Angle = math.abs(pointCheck - pointAngle)}
                    end
                end
            else
                local bestTargetDistance
                local bestTargetPoint
                for k, v in aiBrain.EnemyIntel.EnemyStartLocations do
                    local currentTargetDistance = VDist3Sq(aiBrain.BuilderManagers[baseLocation].Position, v.Position)
                    if not bestPoint or currentTargetDistance < bestTargetDistance then
                        bestTargetDistance = currentTargetDistance
                        bestTargetPoint = v.Position
                    end
                end
                if not bestTargetPoint then
                    bestTargetPoint = aiBrain.MapCenterPoint
                end
                if bestTargetPoint then
                    --RNGLOG('BestTargetPoint is '..repr(bestTargetPoint))
                    local pointCheck = GetAngleToPosition(basePosition, bestTargetPoint)
                    --RNGLOG('Angle to pointCheck is '..pointCheck)
                    for _, v in aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier] do
                        local pointAngle = GetAngleToPosition(basePosition, v.Position)
                        if not bestPoint or (math.abs(pointCheck - pointAngle) < bestPoint.Angle) then
                            local tmdPresent = false
                            if aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier].TMD then
                                for _, c in aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier].TMD do
                                    if c and not c.Dead then
                                        --RNGLOG('TMD is present at defense point and this is not a reactive build')
                                        tmdPresent = true
                                        break
                                    end
                                end
                            end
                            if (not tmdPresent) then
                                --RNGLOG('TMD is not present at defense point, return position')
                                bestPoint = { Position = v.Position, Angle = math.abs(pointCheck - pointAngle)}
                            end
                        end
                    end
                end
            end
        end
        if bestPoint then
            --RNGLOG('bestPoint for TMD is '..repr(bestPoint.Position))
            defensivePoint = bestPoint.Position
        end
    elseif type == 'STRUCTURE' then
        local bestPoint = false
        local bestIndex = false
        --RNGLOG('Performing TML Structure Check')
        if not RNGTableEmpty(aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier]) then
            local bestTargetDistance
            local bestTargetPoint
            for k, v in aiBrain.EnemyIntel.EnemyStartLocations do
                local currentTargetDistance = VDist3Sq(aiBrain.BuilderManagers[baseLocation].Position, v.Position)
                if not bestTargetPoint or currentTargetDistance < bestTargetDistance then
                    bestTargetDistance = currentTargetDistance
                    bestTargetPoint = v.Position
                end
            end
            if not bestTargetPoint then
                bestTargetPoint = aiBrain.MapCenterPoint
            end
            if bestTargetPoint then
                --RNGLOG('BestTargetPoint is '..repr(bestTargetPoint))
                local pointCheck = GetAngleToPosition(basePosition, bestTargetPoint)
                --RNGLOG('Angle to pointCheck is '..pointCheck)
                for _, v in aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier] do
                    local pointAngle = GetAngleToPosition(basePosition, v.Position)
                    if not bestPoint or (math.abs(pointCheck - pointAngle) < bestPoint.Angle) then
                        bestPoint = { Position = v.Position, Angle = math.abs(pointCheck - pointAngle)}
                    end
                end
            end
        end
        if bestPoint then
            --RNGLOG('bestPoint is '..repr(bestPoint.Position))
            defensivePoint = bestPoint.Position
        end
    elseif type == 'SHIELD' then
        local bestPoint = false
        local acuShieldRequired = false
        --RNGLOG('Performing DirectFire Structure Check')
        if pointTier == 2 and aiBrain.IntelManager.StrategyFlags.EnemyAirSnipeThreat then
            local positionKey = aiBrain.BrainIntel.ACUDefensivePositionKeyTable[baseLocation].PositionKey
            if positionKey then
                local shieldCovered
                for k , v in aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier][positionKey].Shields do
                    if v and not v.Dead then
                        shieldCovered = true
                        break
                    end
                end
                if not shieldCovered then
                    acuShieldRequired = true
                end
                bestPoint = aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier][positionKey].Position
            end
        end 
        if not acuShieldRequired then
            if not RNGTableEmpty(aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier]) then
                for k, v in aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier] do
                    local unitCount = 0
                    for _, b in v.DirectFire do
                        if b and not b.Dead then
                            unitCount = unitCount + 1
                        end
                    end
                    if unitCount > 1 then
                        local shieldPresent = false
                        for _, b in v.Shields do
                            if b and not b.Dead then
                                shieldPresent = true
                                break
                            end
                        end
                        if not shieldPresent then
                            bestPoint = v.Position
                            break
                        end
                    end
                end
            end
        end
        if bestPoint then
            if acuShieldRequired then
                --LOG('ACU Shield required at position '..repr(bestPoint))
            end
            defensivePoint = bestPoint
        end
    end
    if defensivePoint then
        if aiBrain.RNGDEBUG then
            aiBrain:ForkThread(DrawCircleAtPosition, defensivePoint)
        end
        return defensivePoint
    end
    return false
end

DefensivePointUnitCountRNG = function(aiBrain, baseLocation, pointTier, type, count)
    -- Finds the best defensive point based on tier and angle of last seen enemy, requires base perimeter monitoring system
    local defensivePointUnitCount = 0
    local basePosition = aiBrain.BuilderManagers[baseLocation].Position
    if type == 'Land' then
        local bestPoint = false
        local bestIndex = false
        if not RNGTableEmpty(aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier]) then
            if aiBrain.BasePerimeterMonitor[baseLocation].RecentLandAngle then
                local pointCheck = aiBrain.BasePerimeterMonitor[baseLocation].RecentLandAngle
                for k, v in aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier] do
                    local pointAngle = GetAngleToPosition(basePosition, v.Position)
                    if not bestPoint or (math.abs(pointCheck - pointAngle) < bestPoint.Angle) then
                        if bestPoint then
                            --RNGLOG('Angle to find '..aiBrain.BasePerimeterMonitor[baseLocation].RecentLandAngle..' bestPoint was '..bestPoint.Angle..' but is now '..repr({ Position = v, Angle = pointAngle}))
                        end
                        bestPoint = { Position = v.Position, Angle = math.abs(pointCheck - pointAngle)}
                        bestIndex = k
                    end
                end
            end
        end
        if bestPoint then
            for _, v in aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier][bestIndex].DirectFire do
                defensivePointUnitCount = defensivePointUnitCount + 1
            end
        end
        --RNGLOG('defensivePoint being passed to engineer build platoon function'..repr(defensivePoint)..' bestpointangle is '..bestPoint.Angle)
    elseif type == 'TML' then
        local bestPoint = false
        local bestIndex = false
        if not RNGTableEmpty(aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier]) then
            if aiBrain.BasePerimeterMonitor[baseLocation].RecentTMLAngle then
                local pointCheck = aiBrain.BasePerimeterMonitor[baseLocation].RecentTMLAngle
                for k, v in aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier] do
                    local pointAngle = GetAngleToPosition(basePosition, v.Position)
                    if not bestPoint or (math.abs(pointCheck - pointAngle) < bestPoint.Angle) then
                        if bestPoint then
                            --RNGLOG('TML Angle to find '..aiBrain.BasePerimeterMonitor[baseLocation].RecentTMLAngle..' bestPoint was '..bestPoint.Angle..' but is now '..repr({ Position = v, Angle = pointAngle}))
                        end
                        bestPoint = { Position = v.Position, Angle = math.abs(pointCheck - pointAngle)}
                        bestIndex = k
                    end
                end
            end
        end
        if bestPoint then
            for _, v in aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier][bestIndex].TML do
                defensivePointUnitCount = defensivePointUnitCount + 1
            end
        end
    elseif type == 'TMD' then
        local bestPoint = false
        local bestIndex = false
        if not RNGTableEmpty(aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier]) then
            if aiBrain.BasePerimeterMonitor[baseLocation].RecentTMLAngle then
                local pointCheck = aiBrain.BasePerimeterMonitor[baseLocation].RecentTMLAngle
                for k, v in aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier] do
                    local pointAngle = GetAngleToPosition(basePosition, v.Position)
                    if not bestPoint or (math.abs(pointCheck - pointAngle) < bestPoint.Angle) then
                        if bestPoint then
                            --RNGLOG('TML Angle to find '..aiBrain.BasePerimeterMonitor[baseLocation].RecentTMLAngle..' bestPoint was '..bestPoint.Angle..' but is now '..repr({ Position = v, Angle = pointAngle}))
                        end
                        bestPoint = { Position = v.Position, Angle = math.abs(pointCheck - pointAngle)}
                        bestIndex = k
                    end
                end
            end
        end
        if bestPoint then
            --RNGLOG('TMD Table '..repr(aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier][bestIndex].TMD))
            for _, v in aiBrain.BuilderManagers[baseLocation].DefensivePoints[pointTier][bestIndex].TMD do
                defensivePointUnitCount = defensivePointUnitCount + 1
            end
        end
    end
    if defensivePointUnitCount then
        --RNGLOG('Number of defensive units at defensive point are '..defensivePointUnitCount)
        return defensivePointUnitCount
    end
    return false
end

AddDefenseUnit = function(aiBrain, locationType, finishedUnit)
    -- Adding a defense unit to a base
    local closestPoint = false
    local closestDistance = false
    local pointTier = 1
    --LOG('Attempting to add defensive unit in defensepoint table at '..locationType)
    --LOG('Unit ID is '..finishedUnit.UnitId)
    if not finishedUnit.Dead then
        --RNGLOG('Attempting to add defensive unit to defensepoint table at '..locationType)
        --RNGLOG('Unit ID is '..finishedUnit.UnitId)
        local unitPos = finishedUnit:GetPosition()
        if finishedUnit.Blueprint.CategoriesHash.TECH1 then
            for k, v in aiBrain.BuilderManagers[locationType].DefensivePoints[1] do
                local distance = VDist3Sq(v.Position, unitPos)
                if not closestPoint or distance < closestDistance then
                    closestPoint = k
                    closestDistance = distance
                end
            end
            if not closestPoint then
                --LOG('AddDefenseUnit No closest point found defensive point dump '..repr(aiBrain.BuilderManagers[locationType].DefensivePoints))
            end
            --LOG('ClosestPoint distance is '..math.sqrt(closestDistance)..'radius is '..aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].Radius)
            if closestPoint and math.sqrt(closestDistance) <= aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].Radius then
                --RNGLOG('Adding T1 defensive unit to defensepoint table at key '..closestPoint)
                if finishedUnit.Blueprint.CategoriesHash.ANTIAIR and not aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].AntiAir[finishedUnit.EntityId] then
                    aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].AntiAir[finishedUnit.EntityId] = finishedUnit
                    --LOG('Added entity id '..finishedUnit.EntityId)
                    aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].AntiAirThreat = aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].AntiAirThreat + finishedUnit.Blueprint.Defense.AirThreatLevel
                    --LOG('Current air threat as defensive point is '..aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].AntiAirThreat)
                elseif finishedUnit.Blueprint.CategoriesHash.DIRECTFIRE and not aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].DirectFire[finishedUnit.EntityId] then
                    aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].DirectFire[finishedUnit.EntityId] = finishedUnit
                    --LOG('Added entity id '..finishedUnit.EntityId)
                    aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].AntiSurfaceThreat = aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].AntiSurfaceThreat + finishedUnit.Blueprint.Defense.SurfaceThreatLevel
                    --LOG('Current surface threat as defensive point is '..aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].AntiSurfaceThreat)
                end
            end
        elseif finishedUnit.Blueprint.CategoriesHash.TECH2 then
            if finishedUnit.Blueprint.CategoriesHash.ANTIMISSILE then
                --RNGLOG('TMD defensive unit to defensepoint table')
                for k, v in aiBrain.BuilderManagers[locationType].DefensivePoints[1] do
                    local distance = VDist3Sq(v.Position, unitPos)
                    if not closestPoint or closestDistance > distance then
                        closestPoint = k
                        closestDistance = distance
                    end
                end
                if not closestPoint then
                    --LOG('AddDefenseUnit No closest point found defensive point dump '..repr(aiBrain.BuilderManagers[locationType].DefensivePoints))
                end
                if closestPoint and math.sqrt(closestDistance) <= aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].Radius and not aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].TMD[finishedUnit.EntityId] then
                    aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].TMD[finishedUnit.EntityId] = finishedUnit
                    --LOG('Added entity id '..finishedUnit.EntityId)
                end
            else
                for k, v in aiBrain.BuilderManagers[locationType].DefensivePoints[2] do
                    local distance = VDist3(v.Position, unitPos)
                    if not closestPoint or distance < closestDistance then
                        closestPoint = k
                        closestDistance = distance
                    end
                end
                if not closestPoint then
                    --LOG('AddDefenseUnit No closest point found defensive point dump '..repr(aiBrain.BuilderManagers[locationType].DefensivePoints))
                end
                if closestPoint and math.sqrt(closestDistance) <= aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].Radius then
                    if finishedUnit.Blueprint.CategoriesHash.ANTIMISSILE and not aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].TMD[finishedUnit.EntityId] then
                        aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].TMD[finishedUnit.EntityId] = finishedUnit
                        --LOG('Added entity id '..finishedUnit.EntityId)
                    elseif finishedUnit.Blueprint.CategoriesHash.TACTICALMISSILEPLATFORM and not aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].TML[finishedUnit.EntityId] then
                        aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].TML[finishedUnit.EntityId] = finishedUnit
                        --LOG('Added entity id '..finishedUnit.EntityId)
                    elseif finishedUnit.Blueprint.CategoriesHash.ANTIAIR and not aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].AntiAir[finishedUnit.EntityId] then
                        aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].AntiAir[finishedUnit.EntityId] = finishedUnit
                        --LOG('Added entity id '..finishedUnit.EntityId)
                        aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].AntiAirThreat = aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].AntiAirThreat + finishedUnit.Blueprint.Defense.AirThreatLevel
                        --LOG('Current air threat as defensive point is '..aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].AntiAirThreat)
                    elseif finishedUnit.Blueprint.CategoriesHash.INDIRECTFIRE and not aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].IndirectFire[finishedUnit.EntityId] then
                        aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].IndirectFire[finishedUnit.EntityId] = finishedUnit
                        --LOG('Added entity id '..finishedUnit.EntityId)
                        aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].AntiSurfaceThreat = aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].AntiSurfaceThreat + finishedUnit.Blueprint.Defense.SurfaceThreatLevel
                        --LOG('Current surface threat as defensive point is '..aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].AntiSurfaceThreat)
                    elseif finishedUnit.Blueprint.CategoriesHash.DIRECTFIRE and not aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].DirectFire[finishedUnit.EntityId] then
                        aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].DirectFire[finishedUnit.EntityId] = finishedUnit
                        --LOG('Added entity id '..finishedUnit.EntityId)
                        aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].AntiSurfaceThreat = aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].AntiSurfaceThreat + finishedUnit.Blueprint.Defense.SurfaceThreatLevel
                        --LOG('Current surface threat as defensive point is '..aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].AntiSurfaceThreat)
                    elseif finishedUnit.Blueprint.CategoriesHash.SHIELD and not aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].Shields[finishedUnit.EntityId] then
                        aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].Shields[finishedUnit.EntityId] = finishedUnit
                        --LOG('Added entity id '..finishedUnit.EntityId)
                    end
                end
            end
        end
    end
end

RemoveDefenseUnit = function(aiBrain, locationType, killedUnit)
    -- Adding a defense unit to a base
    local closestPoint = false
    local closestDistance = false
    local pointTier = 1

    --LOG('Attempting to remove defensive unit in defensepoint table at '..locationType)
    --LOG('Unit ID is '..killedUnit.UnitId)
    local unitPos = killedUnit:GetPosition()
    if killedUnit.Blueprint.CategoriesHash.TECH1 then
        for k, v in aiBrain.BuilderManagers[locationType].DefensivePoints[1] do
            if v then
                local distance = VDist3Sq(v.Position, unitPos)
                if not closestPoint or distance < closestDistance then
                    closestPoint = k
                    closestDistance = distance
                end
            end
        end
        if closestPoint and math.sqrt(closestDistance) <= aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].Radius then
            --RNGLOG('Removing T1 defensive unit to defensepoint table at key '..closestPoint)
            if killedUnit.Blueprint.CategoriesHash.ANTIAIR then
                if aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].AntiAir[killedUnit.EntityId] then
                    aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].AntiAir[killedUnit.EntityId] = nil
                    --LOG('Removed Unit T1AA with entity '..killedUnit.EntityId)
                    aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].AntiAirThreat = aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].AntiAirThreat - killedUnit.Blueprint.Defense.AirThreatLevel
                    --LOG('Current Defense threat for T1 at '..closestPoint..' is now '..aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].AntiAirThreat)
                end
            elseif killedUnit.Blueprint.CategoriesHash.DIRECTFIRE then
                if aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].DirectFire[killedUnit.EntityId] then
                    aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].DirectFire[killedUnit.EntityId] = nil
                    --LOG('Removed Unit T1 PD with entity '..killedUnit.EntityId)
                    aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].AntiSurfaceThreat = aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].AntiSurfaceThreat - killedUnit.Blueprint.Defense.SurfaceThreatLevel
                    --LOG('Current Defense threat for T1 at '..closestPoint..' is now '..aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].AntiSurfaceThreat)
                end
            end
        end
    elseif killedUnit.Blueprint.CategoriesHash.TECH2 then
        if killedUnit.Blueprint.CategoriesHash.ANTIMISSILE then
            --RNGLOG('TMD defensive unit to defensepoint table')
            for k, v in aiBrain.BuilderManagers[locationType].DefensivePoints[1] do
                if v then
                    local distance = VDist3Sq(v.Position, unitPos)
                    if not closestPoint or closestDistance > distance then
                        closestPoint = k
                        closestDistance = distance
                    end
                end
            end
            if closestPoint and math.sqrt(closestDistance) <= aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].Radius then
                --RNGLOG('Adding T2 defensive unit to defensepoint table')
                --RNGLOG('Unit ID is '..finishedUnit.UnitId)
                if aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].TMD[killedUnit.EntityId] then
                    aiBrain.BuilderManagers[locationType].DefensivePoints[1][closestPoint].TMD[killedUnit.EntityId] = nil
                    --LOG('Removed Unit TMD with entity '..killedUnit.EntityId)
                end
            end
        else
            if aiBrain.BuilderManagers[locationType].DefensivePoints[2] then
                for k, v in aiBrain.BuilderManagers[locationType].DefensivePoints[2] do
                    if v then
                        local distance = VDist3Sq(v.Position, unitPos)
                        if not closestPoint or distance < closestDistance then
                            closestPoint = k
                            closestDistance = distance
                        end
                    end
                end
            end
            if closestPoint and math.sqrt(closestDistance) <= aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].Radius then
                if killedUnit.Blueprint.CategoriesHash.ANTIMISSILE then
                    if aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].TMD[killedUnit.EntityId] then
                        aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].TMD[killedUnit.EntityId] = nil
                        --LOG('Removed Unit TMD with entity '..killedUnit.EntityId)
                    end
                elseif killedUnit.Blueprint.CategoriesHash.TACTICALMISSILEPLATFORM then
                    if aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].TML[killedUnit.EntityId] then
                        aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].TML[killedUnit.EntityId] = nil
                        --LOG('Removed Unit TML with entity '..killedUnit.EntityId)
                    end
                elseif killedUnit.Blueprint.CategoriesHash.ANTIAIR then
                    if aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].AntiAir[killedUnit.EntityId] then
                        aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].AntiAir[killedUnit.EntityId] = nil
                        --LOG('Removed Unit antiair with entity '..killedUnit.EntityId)
                        aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].AntiAirThreat = aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].AntiAirThreat - killedUnit.Blueprint.Defense.AirThreatLevel
                        --LOG('Current Air Defense threat for T2 at '..closestPoint..' is now '..aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].AntiAirThreat)
                    end
                elseif killedUnit.Blueprint.CategoriesHash.INDIRECTFIRE then
                    if aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].IndirectFire[killedUnit.EntityId] then
                        aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].IndirectFire[killedUnit.EntityId] = nil
                        --LOG('Removed Unit indirectfire with entity '..killedUnit.EntityId)
                        aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].AntiSurfaceThreat = aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].AntiSurfaceThreat - killedUnit.Blueprint.Defense.SurfaceThreatLevel
                        --LOG('Current Defense IndirectFire threat for T2 at '..closestPoint..' is now '..aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].AntiSurfaceThreat)
                    end
                elseif killedUnit.Blueprint.CategoriesHash.DIRECTFIRE then
                    if aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].DirectFire[killedUnit.EntityId] then
                        aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].DirectFire[killedUnit.EntityId] = nil
                        --LOG('Removed Unit directfire with entity '..killedUnit.EntityId)
                        aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].AntiSurfaceThreat = aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].AntiSurfaceThreat - killedUnit.Blueprint.Defense.SurfaceThreatLevel
                        --LOG('Current Defense DirectFire threat for T2 at '..closestPoint..' is now '..aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].AntiSurfaceThreat)
                    end
                elseif killedUnit.Blueprint.CategoriesHash.SHIELD then
                    if aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].Shields[killedUnit.EntityId] then
                        aiBrain.BuilderManagers[locationType].DefensivePoints[2][closestPoint].Shields[killedUnit.EntityId] = nil
                        --LOG('Removed Unit shield with entity '..killedUnit.EntityId)
                    end
                end
            end
        end
    end
end

AIWarningChecks = function(aiBrain)
    --Pregame warning check
    coroutine.yield( 70 )
    local uveso_enabled = false
    local SUtils = import('/lua/AI/sorianutilities.lua')
    for _, mod in __active_mods do
        if mod.enabled and string.find( mod.name,'Uveso') then
            --RNGLOG(repr(mod))
            --RNGLOG('Uveso is enabled')
            uveso_enabled = true
        end
    end
    --[[
    if not uveso_enabled then
        SUtils.AISendChat('all', aiBrain.Nickname, 'Uveso AI mod is not enabled, it is required for correct AI pathing when using RNGAI')
        coroutine.yield( 30 )
    end
    ]]
end

GetShieldCoverAroundUnit = function(aiBrain, unit)
    local function GetShieldRadiusAboveGroundSquaredRNG(shield)
        local width = shield.Blueprint.Defense.Shield.ShieldSize
        local height = shield.Blueprint.Defense.Shield.ShieldVerticalOffset
    
        return width * width - height * height
    end
    local tPos = unit:GetPosition()
    local totalShieldHealth = 0
    local totalShields = 0
    if not unit.Dead then
        local shields = aiBrain:GetUnitsAroundPoint(categories.SHIELD, tPos, 30, 'Enemy')
        for _, shield in shields do
            if not shield.Dead and shield.MyShield then
                local shieldPos = shield:GetPosition()
                local shieldSizeSq = GetShieldRadiusAboveGroundSquaredRNG(shield)
                if VDist3Sq(tPos, shieldPos) < shieldSizeSq then
                    totalShieldHealth = totalShieldHealth + shield.MyShield:GetHealth()
                    totalShields = totalShields + 1
                end
            end
        end
    end

    if totalShieldHealth > 0 then
        --RNGLOG('totalShieldHealth and number for acu '..totalShieldHealth..' '..totalShields)
        return totalShieldHealth, totalShields
    end
    return false, false
end

SortScoutingAreasRNG = function(aiBrain, list)
    table.sort(list, function(a, b)
        if a.LastScouted == b.LastScouted then
            local MainPos = aiBrain.BuilderManagers.MAIN.Position
            local distA = VDist2Sq(MainPos[1], MainPos[3], a.Position[1], a.Position[3])
            local distB = VDist2Sq(MainPos[1], MainPos[3], b.Position[1], b.Position[3])

            return distA < distB
        else
            return a.LastScouted < b.LastScouted
        end
    end)
end

GetLandScoutLocationRNG = function(platoon, aiBrain, scout)
    local scoutingData
    local scoutType
    local platoonNeedScout, supportPlatoon, supportPlatoonDistance
    local currentGameTime = GetGameTimeSeconds()
    local scoutPos = scout:GetPosition()
    local im = IntelManagerRNG.GetIntelManager(aiBrain)
    local locationType = platoon.PlatoonData.LocationType or 'MAIN'
    if not im.MapIntelGrid then
        WARN('MapIntelGrid is not initialized')
    end
    if not im.MapIntelStats.ScoutLocationsBuilt then
        aiBrain:BuildScoutLocationsRNG()
    end

    if platoon.FindPlatoonCounter and (not platoonNeedScout) and platoon.FindPlatoonCounter < 5 then
        coroutine.yield(3)
        platoonNeedScout, supportPlatoon, supportPlatoonDistance = ScoutFindNearbyPlatoonsRNG(platoon, 125)
        platoon.FindPlatoonCounter = platoon.FindPlatoonCounter + 1
    end
    if aiBrain.CDRUnit.Active then
        if (not aiBrain.CDRUnit.Scout or aiBrain.CDRUnit.Scout.Dead) and aiBrain.CDRUnit.DistanceToHome > 900 
            and (not platoonNeedScout or platoonNeedScout and supportPlatoonDistance > 3025) then
            --LOG('LAND-SCOUT Land scout getting acu position')
            if NavUtils.CanPathTo(platoon.MovementLayer, scoutPos, aiBrain.CDRUnit.Position) then
                --LOG('LAND-SCOUT Can path to acu, return unit')
                aiBrain.CDRUnit.Scout = scout
                scoutType = 'AssistUnit'
                return aiBrain.CDRUnit, scoutType
            end
        end
    end
    if platoonNeedScout then
        if supportPlatoon and PlatoonExists(aiBrain, supportPlatoon) then
            scoutType = 'AssistPlatoon'
            return supportPlatoon, scoutType
        end
    end
    if (not platoonNeedScout) and (not platoon.ZonesValidated) then
        scoutPos = scout:GetPosition()
        local scoutMarker
        for k, zone in aiBrain.Zones.Land.zones do
            if zone.teamvalue > 1.5 and zone.intelassignment then
                local ia = zone.intelassignment
                if (not ia.RadarCoverage) and (not ia.ScoutUnit or ia.ScoutUnit.Dead) and (not ia.StartPosition) then
                    if NavUtils.CanPathTo(platoon.MovementLayer, scoutPos, zone.pos) then
                        scoutMarker = { Position = zone.pos }
                        ia.ScoutUnit = scout
                        break
                    else
                        coroutine.yield(5)
                    end
                end
            end
        end
        if scoutMarker then
            --RNGLOG('Scout Marker Found, moving to position')
            scoutType = 'ZoneLocation'
            --RNGLOG('ScoutDest is zone location')
            return scoutMarker, scoutType
        end
    end
    if platoon.FindPlatoonCounter and (not platoonNeedScout) and platoon.FindPlatoonCounter < 5 then
        coroutine.yield(3)
        platoonNeedScout, supportPlatoon = ScoutFindNearbyPlatoonsRNG(platoon, 250)
        platoon.FindPlatoonCounter = platoon.FindPlatoonCounter + 1
    end
    if platoonNeedScout then
        if supportPlatoon and PlatoonExists(aiBrain, supportPlatoon) then
            scoutType = 'AssistPlatoon'
            return supportPlatoon, scoutType
        end
    end
    if (not platoonNeedScout) and (not platoon.ZonesValidated) then
        scoutPos = scout:GetPosition()
        local scoutMarker
        for k, zone in aiBrain.Zones.Land.zones do
            if zone.intelassignment then
                local ia = zone.intelassignment
                if (not ia.RadarCoverage) and (not ia.ScoutUnit or ia.ScoutUnit.Dead) and (not ia.StartPosition) then
                    if NavUtils.CanPathTo(platoon.MovementLayer, scoutPos, zone.pos) then
                        scoutMarker = { Position = zone.pos }
                        ia.ScoutUnit = scout
                        break
                    else
                        coroutine.yield(5)
                    end
                end
            end
        end
        if scoutMarker then
            --RNGLOG('Scout Marker Found, moving to position')
            scoutType = 'ZoneLocation'
            --RNGLOG('ScoutDest is zone location')
            return scoutMarker, scoutType
        else
            platoon.ZonesValidated = true
        end
    end
    --RNGLOG('GetLandScoutLocationRNG ')
    --RNGLOG(repr(aiBrain.IntelData.HiPriScouts))
    --RNGLOG(repr(aiBrain.NumOpponents))
    if aiBrain.IntelData.HiPriScouts < aiBrain.NumOpponents then
        local highestGrid = {x = 0, z = 0, Priority = 0}
        local currentGrid = {x = 0, z = 0, Priority = 0}
        for i=im.MapIntelGridXMin, im.MapIntelGridXMax do
            for k=im.MapIntelGridZMin, im.MapIntelGridZMax do
                if im.MapIntelGrid[i][k].Enabled and not im.MapIntelGrid[i][k].IntelCoverage and im.MapIntelGrid[i][k].ScoutPriority >= 100 then
                    if not im.MapIntelGrid[i][k].Graphs[locationType].GraphChecked then
                        --RNGLOG('Trying to set graphs for '..i..k..' current grid position is '..repr(im.MapIntelGrid[i][k].Position))
                        im:IntelGridSetGraph(locationType, i, k, aiBrain.BuilderManagers[locationType].Position, im.MapIntelGrid[i][k].Position)
                    end
                    if im.MapIntelGrid[i][k].TimeScouted == 0 or im.MapIntelGrid[i][k].TimeScouted > 45 then
                        --RNGLOG('ScoutPriority is '..im.MapIntelGrid[i][k].ScoutPriority)
                        --RNGLOG('LastScouted is '..im.MapIntelGrid[i][k].LastScouted)
                        --RNGLOG('DistanceToMain is '..im.MapIntelGrid[i][k].DistanceToMain)
                        if im.MapIntelGrid[i][k].LastScouted == 0 then
                            im.MapIntelGrid[i][k].LastScouted = 1
                        end
                        if im.MapIntelGrid[i][k].DistanceToMain == 0 then
                            im.MapIntelGrid[i][k].DistanceToMain = 1
                        end
                        if im.MapIntelGrid[i][k].TimeScouted == 0 then
                            im.MapIntelGrid[i][k].TimeScouted = 1
                        end
                        local priority = (im.MapIntelGrid[i][k].ScoutPriority * im.MapIntelGrid[i][k].ScoutPriority) / im.MapIntelGrid[i][k].TimeScouted * im.MapIntelGrid[i][k].DistanceToMain
                        local cellStatus = aiBrain.GridPresence:GetInferredStatus(im.MapIntelGrid[i][k].Position)
                        if cellStatus == 'Allied' then
                            priority = priority * 0.80
                        end
                        currentGrid = {x = i, z = k, Priority = priority }
                        --RNGLOG('CurrentGrid Priority is '..currentGrid.Priority)
                        --RNGLOG('TimeScouted is '..im.MapIntelGrid[i][k].TimeScouted)
                        if currentGrid.Priority > highestGrid.Priority then
                            highestGrid = currentGrid
                        end
                    end
                end
            end
        end
        if highestGrid.Priority > 0 then
            scoutingData = im.MapIntelGrid[highestGrid.x][highestGrid.z]
            scoutingData.LastScouted = currentGameTime
            scoutingData.TimeScouted = 1
            scoutType = 'Location'
            --RNGLOG('Current Game Time '..currentGameTime)
            --RNGLOG('HighPri Scouting Data '..repr(scoutingData))
        end
        aiBrain.IntelData.HiPriScouts = aiBrain.IntelData.HiPriScouts + 1
    elseif aiBrain.IntelData.LowPriScouts < 2 then
        local highestGrid = {x = 0, z = 0, Priority = 0}
        local currentGrid = {x = 0, z = 0, Priority = 0}
        for i=im.MapIntelGridXMin, im.MapIntelGridXMax do
            for k=im.MapIntelGridZMin, im.MapIntelGridZMax do
                if im.MapIntelGrid[i][k].Enabled and not im.MapIntelGrid[i][k].IntelCoverage and im.MapIntelGrid[i][k].ScoutPriority < 100 then
                    if not im.MapIntelGrid[i][k].Graphs[locationType].GraphChecked then
                        --RNGLOG('Trying to set graphs for '..i..k..' current grid position is '..repr(im.MapIntelGrid[i][k].Position))
                        im:IntelGridSetGraph(locationType, i, k, aiBrain.BuilderManagers[locationType].Position, im.MapIntelGrid[i][k].Position)
                    end
                    if im.MapIntelGrid[i][k].TimeScouted == 0 or im.MapIntelGrid[i][k].TimeScouted > 60 then
                        --RNGLOG('LastScouted is '..im.MapIntelGrid[i][k].LastScouted)
                        --RNGLOG('DistanceToMain is '..im.MapIntelGrid[i][k].DistanceToMain)
                        if im.MapIntelGrid[i][k].LastScouted == 0 then
                            im.MapIntelGrid[i][k].LastScouted = 1
                        end
                        if im.MapIntelGrid[i][k].DistanceToMain == 0 then
                            im.MapIntelGrid[i][k].DistanceToMain = 1
                        end
                        local priority = (im.MapIntelGrid[i][k].ScoutPriority * im.MapIntelGrid[i][k].ScoutPriority) / im.MapIntelGrid[i][k].TimeScouted * im.MapIntelGrid[i][k].DistanceToMain
                        local cellStatus = aiBrain.GridPresence:GetInferredStatus(im.MapIntelGrid[i][k].Position)
                        if cellStatus == 'Allied' then
                            priority = priority * 0.80
                        end
                        currentGrid = {x = i, z = k, Priority = priority }
                        --RNGLOG('CurrentGrid Priority is '..currentGrid.Priority)
                        --RNGLOG(im.MapIntelGrid[i][k].ScoutPriority..','..im.MapIntelGrid[i][k].LastScouted..','..im.MapIntelGrid[i][k].DistanceToMain..','..im.MapIntelGrid[i][k].TimeScouted..','..currentGrid.Priority)
                        --RNGLOG('TimeScouted is '..im.MapIntelGrid[i][k].TimeScouted)
                        if currentGrid.Priority > highestGrid.Priority then
                            highestGrid = currentGrid
                        end
                    end
                end
            end
        end
        if highestGrid.Priority > 0 then
            scoutingData = im.MapIntelGrid[highestGrid.x][highestGrid.z]
            aiBrain.IntelData.HiPriScouts = 0
            scoutingData.LastScouted = currentGameTime
            scoutingData.TimeScouted = 1
            scoutType = 'Location'
        end
        aiBrain.IntelData.LowPriScouts = aiBrain.IntelData.LowPriScouts + 1
    else
        --Reset number of scoutings and start over
        aiBrain.IntelData.HiPriScouts = 0
        aiBrain.IntelData.LowPriScouts = 0
    end
    if aiBrain.RNGDEBUG then
        if scoutingData.Position then
            --RNGLOG('Trying to draw scoutingData position '..repr(scoutingData.Position))
            aiBrain:ForkThread(drawScoutMarker, scoutingData.Position)
        end
    end
    if aiBrain.RNGDEBUG and not scoutingData then
        RNGLOG('Scout Assignment returned nothing')
    end
    return scoutingData, scoutType
end

ScoutFindNearbyPlatoonsRNG = function(platoon, radius)
    local aiBrain = platoon:GetBrain()
    if not aiBrain then return end
    local platPos = GetPlatoonPosition(platoon)
    local allyPlatPos = false
    if not platPos then
        return
    end
    local radiusSq = radius*radius
    AlliedPlatoons = aiBrain:GetPlatoonsList()
    local platRequiresScout = false
    for _,aPlat in AlliedPlatoons do
        if aPlat == platoon then continue end
        if aPlat.ScoutSupported then
            if not aPlat.ScoutPresent and not aPlat.UsingTransport and aPlat.PlatoonName ~= 'LandScoutBehavior' then  
                allyPlatPos = GetPlatoonPosition(aPlat)
                if not allyPlatPos or not PlatoonExists(aiBrain, aPlat) then
                    allyPlatPos = false
                    continue
                end
                if not aPlat.MovementLayer then
                    AIAttackUtils.GetMostRestrictiveLayerRNG(aPlat)
                end
                -- make sure we're the same movement layer type to avoid hamstringing air of amphibious
                if platoon.MovementLayer ~= 'Amphibious' and platoon.MovementLayer ~= aPlat.MovementLayer then
                    continue
                end
                local allyPlatDistance = VDist3Sq(platPos, allyPlatPos)
                if  allyPlatDistance <= radiusSq then
                    if not NavUtils.CanPathTo(platoon.MovementLayer, platPos, allyPlatPos) then continue end
                    if aiBrain.RNGDEBUG then
                        RNGLOG("*AI DEBUG: Scout moving to allied platoon position for plan "..aPlat.PlanName)
                    end
                    return true, aPlat, allyPlatDistance
                end
            end
        end
    end
    return false
end

GetAirScoutLocationRNG = function(platoon, aiBrain, scout, optics)
    local scoutingData = false
    local scoutType = false
    local currentGameTime = GetGameTimeSeconds()
    local scoutPos = scout:GetPosition()
    local im = IntelManagerRNG.GetIntelManager(aiBrain)
    if not im.MapIntelGrid then
        WARN('MapIntelGrid is not initialized')
    end
    if not im.MapIntelStats.ScoutLocationsBuilt then
        aiBrain:BuildScoutLocationsRNG()
    end

    --RNGLOG('GetAirScoutLocationRNG ')
    if aiBrain.RNGDEBUG then
        if im.MapIntelStats.MustScoutArea then
            RNGLOG('im.MapIntelStats.MustScoutArea is true')
        else
            RNGLOG('im.MapIntelStats.MustScoutArea is false')
        end
    end

    if im.MapIntelStats.MustScoutArea then
        --RNGLOG('AirScout MustScoutArea is set')
        local highestGrid = {x = 0, z = 0, Priority = 0}
        local currentGrid = {x = 0, z = 0, Priority = 0}
        local mustScoutArea = false
        for i=im.MapIntelGridXMin, im.MapIntelGridXMax do
            for k=im.MapIntelGridZMin, im.MapIntelGridZMax do
                if im.MapIntelGrid[i][k].MustScout then
                    if not im.MapIntelGrid[i][k].ScoutAssigned or im.MapIntelGrid[i][k].ScoutAssigned.Dead then
                        mustScoutArea = true
                        if im.MapIntelGrid[i][k].DistanceToMain == 0 then
                            im.MapIntelGrid[i][k].DistanceToMain = 1
                        end
                        if im.MapIntelGrid[i][k].TimeScouted == 0 then
                            im.MapIntelGrid[i][k].TimeScouted = 1
                        end
                        local mustScoutPriority
                        if im.MapIntelGrid[i][k].ScoutPriority == 0 then
                            mustScoutPriority = 100
                        else
                            mustScoutPriority = im.MapIntelGrid[i][k].ScoutPriority
                        end
                        currentGrid = {x = i, z = k, Priority = (mustScoutPriority * mustScoutPriority) / im.MapIntelGrid[i][k].TimeScouted * im.MapIntelGrid[i][k].DistanceToMain }
                        if currentGrid.Priority > highestGrid.Priority then
                            highestGrid = currentGrid
                        end
                        --RNGLOG(' TimeScouted '..repr(im.MapIntelGrid[i][k].TimeScouted))
                        --RNGLOG(' Distance to main '..repr(im.MapIntelGrid[i][k].DistanceToMain))
                        --RNGLOG('Current Grid for mustscout '..repr(currentGrid))
                    else
                        --RNGLOG('MustScout Area already has scout assigned '..im.MapIntelGrid[i][k].ScoutAssigned.UnitId)
                        --RNGLOG('Scout is current at pos '..repr(im.MapIntelGrid[i][k].ScoutAssigned:GetPosition()))
                    end
                end
            end
        end
        if not mustScoutArea then
            --RNGLOG('AirScout MustScoutArea is being set to false')
            im.MapIntelStats.MustScoutArea = false
        end
        if highestGrid.Priority > 0 then
            --LOG('Highest Grid priority was '..tostring(highestGrid.Priority))
            --RNGLOG('AirScout MustScoutArea is greater than 0 and being set')
            scoutingData = im.MapIntelGrid[highestGrid.x][highestGrid.z]
            if not optics then
                scoutingData.ScoutAssigned = scout
            end
            scoutingData.LastScouted = currentGameTime
            scoutingData.TimeScouted = 1
            scoutType = 'Location'
            --RNGLOG('AirScouting Current Game Time '..currentGameTime)
            --RNGLOG('AirScouting MustScout Scouting Data '..repr(scoutingData))
        end
    elseif aiBrain.IntelData.AirHiPriScouts < aiBrain.NumOpponents and aiBrain.IntelData.AirLowPriScouts < 1 then
        --RNGLOG('AirScout HiPriArea is set')
        local highestGrid = {x = 0, z = 0, Priority = 0}
        local currentGrid = {x = 0, z = 0, Priority = 0}
        for i=im.MapIntelGridXMin, im.MapIntelGridXMax do
            for k=im.MapIntelGridZMin, im.MapIntelGridZMax do
                if im.MapIntelGrid[i][k].ScoutPriority >= 100 then
                    if im.MapIntelGrid[i][k].TimeScouted == 0 or im.MapIntelGrid[i][k].TimeScouted > 45 then
                        --RNGLOG('AirScouting ScoutPriority is '..im.MapIntelGrid[i][k].ScoutPriority)
                        --RNGLOG('AirScouting LastScouted is '..im.MapIntelGrid[i][k].LastScouted)
                        --RNGLOG('AirScouting DistanceToMain is '..im.MapIntelGrid[i][k].DistanceToMain)
                        if im.MapIntelGrid[i][k].LastScouted == 0 then
                            im.MapIntelGrid[i][k].LastScouted = 1
                        end
                        if im.MapIntelGrid[i][k].DistanceToMain == 0 then
                            im.MapIntelGrid[i][k].DistanceToMain = 1
                        end
                        if im.MapIntelGrid[i][k].TimeScouted == 0 then
                            im.MapIntelGrid[i][k].TimeScouted = 1
                        end
                        currentGrid = {x = i, z = k, Priority = (im.MapIntelGrid[i][k].ScoutPriority * im.MapIntelGrid[i][k].ScoutPriority) / im.MapIntelGrid[i][k].TimeScouted * im.MapIntelGrid[i][k].DistanceToMain }
                        --RNGLOG('AirScouting CurrentGrid Priority is '..currentGrid.Priority)
                        --RNGLOG('AirScouting TimeScouted is '..im.MapIntelGrid[i][k].TimeScouted)
                        if currentGrid.Priority > highestGrid.Priority then
                            highestGrid = currentGrid
                        end
                    end
                end
            end
        end
        if highestGrid.Priority > 0 then
            scoutingData = im.MapIntelGrid[highestGrid.x][highestGrid.z]
            scoutingData.LastScouted = currentGameTime
            scoutingData.TimeScouted = 1
            scoutType = 'Location'
            --RNGLOG('AirScouting Current Game Time '..currentGameTime)
            --RNGLOG('AirScouting HighPri Scouting Data '..repr(scoutingData))
        end
        if not optics then
            aiBrain.IntelData.AirHiPriScouts = aiBrain.IntelData.AirHiPriScouts + 1
        end
    elseif aiBrain.IntelData.AirLowPriScouts < 1 then
        --RNGLOG('AirScout LowPri is set')
        local highestGrid = {x = 0, z = 0, Priority = 0}
        local currentGrid = {x = 0, z = 0, Priority = 0}
        for i=im.MapIntelGridXMin, im.MapIntelGridXMax do
            for k=im.MapIntelGridZMin, im.MapIntelGridZMax do
                if im.MapIntelGrid[i][k].ScoutPriority < 100 then
                    if im.MapIntelGrid[i][k].TimeScouted == 0 or im.MapIntelGrid[i][k].TimeScouted > 60 then
                        --RNGLOG('LastScouted is '..im.MapIntelGrid[i][k].LastScouted)
                        --RNGLOG('DistanceToMain is '..im.MapIntelGrid[i][k].DistanceToMain)
                        if im.MapIntelGrid[i][k].LastScouted == 0 then
                            im.MapIntelGrid[i][k].LastScouted = 1
                        end
                        if im.MapIntelGrid[i][k].DistanceToMain == 0 then
                            im.MapIntelGrid[i][k].DistanceToMain = 1
                        end
                        currentGrid = {x = i, z = k, Priority = (im.MapIntelGrid[i][k].ScoutPriority * im.MapIntelGrid[i][k].ScoutPriority) / im.MapIntelGrid[i][k].TimeScouted * im.MapIntelGrid[i][k].DistanceToMain }
                        --RNGLOG('CurrentGrid Priority is '..currentGrid.Priority)
                        --RNGLOG(im.MapIntelGrid[i][k].ScoutPriority..','..im.MapIntelGrid[i][k].LastScouted..','..im.MapIntelGrid[i][k].DistanceToMain..','..im.MapIntelGrid[i][k].TimeScouted..','..currentGrid.Priority)
                        --RNGLOG('TimeScouted is '..im.MapIntelGrid[i][k].TimeScouted)
                        if currentGrid.Priority > highestGrid.Priority then
                            highestGrid = currentGrid
                        end
                    end
                end
            end
        end
        if highestGrid.Priority > 0 then
            scoutingData = im.MapIntelGrid[highestGrid.x][highestGrid.z]
            scoutingData.LastScouted = currentGameTime
            scoutType = 'Location'
            --RNGLOG('AirScouting Current Game Time '..currentGameTime)
            --RNGLOG('AirScouting LowPri Scouting Data '..repr(scoutingData))
            --RNGLOG('AirScouting Scouting LowPriority Point')
            aiBrain.IntelData.HiPriScouts = 0
            scoutingData.LastScouted = currentGameTime
            scoutingData.TimeScouted = 1
            scoutType = 'Location'
        end
        if not optics then
            aiBrain.IntelData.AirHiPriScouts = 0
            aiBrain.IntelData.AirLowPriScouts = aiBrain.IntelData.AirLowPriScouts + 1
        end
    else
        --Reset number of scoutings and start over
        --RNGLOG('AirScout Resetting AirLowPriScouts and AirHiPriScouts')
        if not optics then
            aiBrain.IntelData.AirLowPriScouts = 0
            aiBrain.IntelData.AirHiPriScouts = 0
        end
    end
    if aiBrain.RNGDEBUG then
        if scoutingData and scoutingData.Position then
            --RNGLOG('Trying to draw scoutingData position '..repr(scoutingData.Position))
            aiBrain:ForkThread(drawScoutMarker, scoutingData.Position)
        end
    end
    return scoutingData, scoutType
end

drawScoutMarker = function(brain, position)
    --RNGLOG('Starting DrawScout position at '..repr(position))
    local counter = 0
    while counter < 180 do
        DrawCircle(position, 10, '0000FF')
        counter = counter + 1
        WaitTicks(2)
    end
end

DrawCircleAtPosition = function(aiBrain, position)
    local count = 0
    while count < 60 do
        DrawCircle(position,10,'FF6600')
        coroutine.yield(2)
        count = count + 1
    end
end

CanPathToCurrentEnemyRNG = function(aiBrain) -- Uveso's function modified to run as a thread and validate land vs amphib vs nopath
    -- Validate Pathing to enemies based on map pathing markers
    -- Removed from build conditions so it can run on a slower loop
    -- added amphib vs nopath results so we can tell when we are trapped on a plateu
    coroutine.yield(Random(5,20))
    while true do
        if aiBrain.RNGDEBUG then
            --RNGLOG('Start path checking')
            --RNGLOG('CanPathToEnemyRNG Table '..repr(aiBrain.CanPathToEnemyRNG))
        end
        if not NavUtils.IsGenerated() then
            WARN('No Navmesh yet, waiting...')
            coroutine.yield(50)
            continue
        end
        --We are getting the current base position rather than the start position so we can use this for expansions.
        for k, v in aiBrain.BuilderManagers do
            if k ~= 'FLOATING' then
                local locPos = v.Position 
                -- added this incase the position came back nil
                local enemyX, enemyZ
                if aiBrain:GetCurrentEnemy() then
                    enemyX, enemyZ = aiBrain:GetCurrentEnemy():GetArmyStartPos()
                    -- if we don't have an enemy position then we can't search for a path. Return until we have an enemy position
                    if not enemyX then
                        coroutine.yield(30)
                        break
                    end
                else
                    coroutine.yield(30)
                    break
                end

                -- Get the armyindex from the enemy
                local EnemyIndex = aiBrain:GetCurrentEnemy():GetArmyIndex()
                local OwnIndex = aiBrain:GetArmyIndex()
                -- create a table for the enemy index in case it's nil
                aiBrain.CanPathToEnemyRNG[OwnIndex] = aiBrain.CanPathToEnemyRNG[OwnIndex] or {}
                aiBrain.CanPathToEnemyRNG[OwnIndex][EnemyIndex] = aiBrain.CanPathToEnemyRNG[OwnIndex][EnemyIndex] or {}
                -- Check if we have already done a path search to the current enemy
                if aiBrain.CanPathToEnemyRNG[OwnIndex][EnemyIndex][k] == 'LAND' then
                    coroutine.yield(20)
                    continue
                elseif aiBrain.CanPathToEnemyRNG[OwnIndex][EnemyIndex][k] == 'AMPHIBIOUS' then
                    coroutine.yield(20)
                    continue
                elseif aiBrain.CanPathToEnemyRNG[OwnIndex][EnemyIndex][k] == 'NOPATH' then
                    coroutine.yield(20)
                    continue
                end
                -- path wit AI markers from our base to the enemy base
                --RNGLOG('Validation GenerateSafePath inputs locPos :'..repr(locPos)..'Enemy Pos: '..repr({enemyX,0,enemyZ}))
                local path, reason = NavUtils.CanPathTo('Land', locPos, {enemyX,0,enemyZ})
                -- if we have a path generated with AI path markers then....
                if path then
                    aiBrain.CanPathToEnemyRNG[OwnIndex][EnemyIndex][k] = 'LAND'
                -- if we not have a path
                else
                    --RNGLOG('* RNG CanPathToCurrentEnemyRNG not path returned ')
                    --"NoPath" means we have AI markers but can't find a path to the enemy - There is no path!
                    --RNGLOG('* RNG CanPathToCurrentEnemyRNG: No land path to the enemy found! Testing Amphib map! - '..OwnIndex..' vs '..EnemyIndex..''..' Location '..k)
                    local amphibPath, amphibReason = NavUtils.CanPathTo('Amphibious', locPos, {enemyX,0,enemyZ})
                    --RNGLOG('amphibReason '..amphibReason)
                    if not amphibPath then
                        aiBrain.CanPathToEnemyRNG[OwnIndex][EnemyIndex][k] = 'NOPATH'
                    else
                        aiBrain.CanPathToEnemyRNG[OwnIndex][EnemyIndex][k] = 'AMPHIBIOUS'
                    end
                end
            end
            coroutine.yield(10)
        end
        coroutine.yield(100)
    end
end

GetHoldingPosition = function(aiBrain, platoon, threatType, maxRadius)
    local holdingPos = false
    local threatLocations = aiBrain:GetThreatsAroundPosition( aiBrain.BuilderManagers['MAIN'].Position, 16, true, threatType )
    local operatingArea = aiBrain.OperatingAreas['BaseDMZArea'] * aiBrain.OperatingAreas['BaseDMZArea']
    local bestThreat
    local bestThreatPos
    local bestThreatDist
    if aiBrain.RNGDEBUG then
        --RNGLOG('CurrentPlatoonThreat '..platoon.CurrentPlatoonThreat)
        --RNGLOG('threatLocations for antiair platoon '..repr(threatLocations))
    end

    if not RNGTableEmpty(threatLocations) then
        for k, v in threatLocations do
            local locationDistance = VDist3Sq(aiBrain.BuilderManagers['MAIN'].Position, {v[1],0,v[2]})
            if locationDistance > 625 and (not bestThreat or locationDistance < bestThreatDist) then
                bestThreat = v[3]
                bestThreatPos = {v[1],0,v[2]}
                bestThreatDist = locationDistance
            end
        end
    end
    if bestThreatPos then
        local distance = VDist3Sq(aiBrain.BuilderManagers['MAIN'].Position, bestThreatPos)
        local maxRadiusSquared = maxRadius * maxRadius
        local distanceSplit
        if distance / 4 > maxRadiusSquared then
            distanceSplit = maxRadiusSquared
        else
            distanceSplit = distance / 4
        end
        local closestBaseDist
        local bestBasePos
        for baseName, base in aiBrain.BuilderManagers do
            if base.Position then
                local baseDist = VDist3Sq(bestThreatPos, base.Position)
                if (not closestBaseDist or (baseDist < closestBaseDist and baseDist < distance)) and baseDist < operatingArea then
                    local friendlyAntiAirStructures = aiBrain:GetNumUnitsAroundPoint(categories.DEFENSE * categories.ANTIAIR, base.Position, 65, 'Ally')
                    if friendlyAntiAirStructures > 0 then
                        bestBase = base
                        bestBasePos = base.Position
                        closestBaseDist = baseDist
                    end
                end
            end
        end
        if bestBasePos and closestBaseDist < distance then
            holdingPos = bestBasePos
        else
            holdingPos = lerpy(aiBrain.BuilderManagers['MAIN'].Position, bestThreatPos, {math.sqrt(distance), (math.sqrt(distanceSplit))})
        end
        if aiBrain.RNGDEBUG then
            RNGLOG('Holding Position is set to '..repr(holdingPos))
        end
    end
    return holdingPos
end

CDRWeaponCheckRNG = function (aiBrain, cdr, selfThreat)

    local factionIndex = aiBrain:GetFactionIndex()
    local gunUpgradePresent = false
    local weaponRange
    local threatLimit

    if cdr.Blueprint.Weapon then
        for _, v in cdr.Blueprint.Weapon do
            if v.Damage > 0 and v.MaxRadius > 0 and v.RangeCategory == "UWRC_DirectFire" then
                weaponRange = v.MaxRadius
                break
            end
        end
    else
        weaponRange = 22
    end

        -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
    if not cdr.GunUpgradePresent then
        if factionIndex == 1 then
            if cdr:HasEnhancement('HeavyAntiMatterCannon') then
                local enhancement = cdr.Blueprint.Enhancements
                cdr.GunUpgradePresent = true
                weaponRange = enhancement.HeavyAntiMatterCannon.NewMaxRadius or 30
                threatLimit = 48
            end
        elseif factionIndex == 2 then
            if cdr:HasEnhancement('HeatSink') then
                cdr.GunUpgradePresent = true
                threatLimit = 43
            end
            if cdr:HasEnhancement('CrysalisBeam') then
                local enhancement = cdr.Blueprint.Enhancements
                cdr.GunUpgradePresent = true
                weaponRange = enhancement.CrysalisBeam.NewMaxRadius or 30
                threatLimit = 48
            end
            if cdr:HasEnhancement('FAF_CrysalisBeamAdvanced') then
                local enhancement = cdr.Blueprint.Enhancements
                cdr.GunUpgradePresent = true
                weaponRange = enhancement.FAF_CrysalisBeamAdvanced.NewMaxRadius or 35
                threatLimit = 50
            end
        elseif factionIndex == 3 then
            if cdr:HasEnhancement('CoolingUpgrade') then
                local enhancement = cdr.Blueprint.Enhancements
                cdr.GunUpgradePresent = true
                weaponRange = enhancement.CoolingUpgrade.NewMaxRadius or 30
                threatLimit = 48
            end
        elseif factionIndex == 4 then
            if cdr:HasEnhancement('RateOfFire') then
                cdr.GunUpgradePresent = true
                weaponRange = enhancement.RateOfFire.NewMaxRadius or 30
                threatLimit = 48
            end
        end
    end
    if selfThreat then
        cdr.GunUpgradePresent = gunUpgradePresent
        cdr.WeaponRange = weaponRange
        cdr.ThreatLimit = threatLimit
    end
end

CheckACUSnipe = function(aiBrain, layerType)
    -- checks if less than 500 seconds have passed since an acu snipe mission was added
    local potentialTarget = false
    local requiredCount = 0
    local requiredStrikeDamage
    local acuIndex
    for k, v in aiBrain.TacticalMonitor.TacticalMissions.ACUSnipe do
        if layerType == 'Land' then
            if v.LAND and v.LAND.GameTime then
                if v.LAND.GameTime + 300 > GetGameTimeSeconds() then
                    if HaveUnitVisual(aiBrain, aiBrain.EnemyIntel.ACU[k].Unit, true) then
                        potentialTarget = aiBrain.EnemyIntel.ACU[k].Unit
                        requiredCount = v.LAND.CountRequired
                        acuIndex = k
                        break
                    end
                end
            end
        elseif layerType == 'Air' then
            if v.AIR and v.AIR.GameTime then
                if v.AIR.GameTime + 300 > GetGameTimeSeconds() then
                    local unit = aiBrain.EnemyIntel.ACU[k].Unit
                    if HaveUnitVisual(aiBrain, aiBrain.EnemyIntel.ACU[k].Unit, true) then
                        potentialTarget = aiBrain.EnemyIntel.ACU[k].Unit
                        requiredCount = v.AIR.CountRequired
                        requiredStrikeDamage = v.AIR.StrikeDamage
                        acuIndex = k
                        --LOG('An air snipe has been verified with a unit of '..tostring(potentialTarget.UnitId))
                        break
                    end
                end
            end
        elseif layerType == 'AirAntiNavy' then
            if v.AIR and v.AIR.GameTime then
                if v.AIR.GameTime + 300 > GetGameTimeSeconds() then
                    if HaveUnitVisual(aiBrain, aiBrain.EnemyIntel.ACU[k].Unit, true) and PositionInWater(aiBrain.EnemyIntel.ACU[k].Position) then
                        potentialTarget = aiBrain.EnemyIntel.ACU[k].Unit
                        requiredCount = v.AIR.CountRequired
                        acuIndex = k
                        break
                    end
                end
            end
        end
    end
    return potentialTarget, requiredCount, acuIndex, requiredStrikeDamage
end

CheckForExperimental = function(aiBrain, im, platoon, avoid, naval)
    local platPos
    local closestTarget
    local highestPriority = 0
    local operatingArea = aiBrain.OperatingAreas['BaseDMZArea']
    local baseRestrictedArea = aiBrain.OperatingAreas['BaseRestrictedArea'] * 1.5
    local homeLocation = platoon.Home or aiBrain.BrainIntel.StartPos
    if aiBrain.EnemyIntel.HighPriorityTargetAvailable then
        if platoon then
            platPos = platoon.Pos or platoon:GetPlatoonPosition()
        end
        -- again because we are dealing with vdist3sq in ClosestEnemyBase the rangeCheck is also squared
        local rangeCheck = 4
        if avoid then
            rangeCheck = 9
        end
        if platPos then
            local platDistance = VDist3Sq(platPos, aiBrain.BrainIntel.StartPos)
            if platDistance < (aiBrain.EnemyIntel.ClosestEnemyBase / rangeCheck) then
                for k, v in aiBrain.EnemyIntel.Experimental do
                    if v.object and not v.object.Dead and v.object:GetFractionComplete() > 0.9 then
                        local unitCats = v.object.Blueprint.CategoriesHash
                        local unitPos = v.object:GetPosition()
                        local unitDist = VDist3Sq(unitPos,homeLocation)
                        if naval then
                            if not unitCats.HOVER and not unitCats.AIR and PositionInWater(v.position) then
                                closestTarget = v.object
                            end
                        elseif platoon.MovementLayer == 'Air' then
                            if unitDist > operatingArea * operatingArea then
                                local currentThreat = aiBrain:GetThreatAtPosition( unitPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir' )
                                if currentThreat < 30 then
                                    closestTarget = v.object
                                end
                            else
                                closestTarget = v.object
                            end
                        else
                            if unitDist < baseRestrictedArea * baseRestrictedArea then
                                closestTarget = v.object
                            end
                        end
                    end
                end
            end
        end
    end
end

CheckHighPriorityTarget = function(aiBrain, im, platoon, avoid, naval, ignoreAcu, experimentalCheck, strategicBomber, airOnly)
    local platPos
    local closestTarget
    local highestPriority = 0
    local operatingArea = aiBrain.OperatingAreas['BaseDMZArea']
    local baseRestrictedArea = aiBrain.OperatingAreas['BaseRestrictedArea'] * 1.5
    local homeLocation = platoon.Home or aiBrain.BrainIntel.StartPos
    local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()
    local zoneType
    if platoon.MovementLayer == 'Land' or platoon.MovementLayer == 'Amphibious' then
        zoneType = 'Land'
    end
    if aiBrain.EnemyIntel.HighPriorityTargetAvailable then
        if platoon then
            platPos = platoon.Pos or platoon:GetPlatoonPosition()
        end
        -- again because we are dealing with vdist3sq in ClosestEnemyBase the rangeCheck is also squared
        local rangeCheck = 4
        if avoid then
            rangeCheck = 9
        end

        if platPos then
            local platDistance = VDist3Sq(platPos, aiBrain.BrainIntel.StartPos)
            if platDistance < (aiBrain.EnemyIntel.ClosestEnemyBase / rangeCheck) then
                for k, v in aiBrain.EnemyIntel.Experimental do
                    if v.object and not v.object.Dead and v.object:GetFractionComplete() > 0.9 then
                        --LOG('Platoon with movement layer '..tostring(platoon.MovementLayer)..' has found experimental of type '..tostring(v.object.UnitId))
                        local unitCats = v.object.Blueprint.CategoriesHash
                        local unitPos = v.object:GetPosition()
                        local unitDist = VDist3Sq(unitPos,homeLocation)
                        if naval then
                            if (not unitCats.HOVER or unitCats.HOVER and platoon.CurrentPlatoonThreatAntiSurface > 0) and (not unitCats.AIR or unitCats.AIR and platoon.CurrentPlatoonThreatAntiAir > 0) and PositionInWater(unitPos) then
                                closestTarget = v.object
                            end
                        elseif airOnly then
                            if unitCats.AIR then
                                if unitDist > operatingArea * operatingArea then
                                    local currentThreat = aiBrain:GetThreatAtPosition( unitPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir' )
                                    if currentThreat < 30 then
                                        closestTarget = v.object
                                    end
                                else
                                    closestTarget = v.object
                                end
                            end
                        else
                            if unitDist < baseRestrictedArea * baseRestrictedArea then
                                closestTarget = v.object
                            end
                        end
                    end
                end
                if not experimentalCheck and not closestTarget then
                    for k, v in aiBrain.prioritypointshighvalue do
                        if not v.unit.Dead and not v.unit.Tractored then
                            local unitCats = v.unit.Blueprint.CategoriesHash
                            if ignoreAcu then
                                if unitCats.COMMAND then
                                    local skipAcu
                                    if platoon.MovementLayer == 'Air' then
                                        local acuTarget = CheckACUSnipe(aiBrain, 'Air')
                                        if acuTarget and not acuTarget.Dead then
                                            local brainIndex = v.unit:GetAIBrain():GetArmyIndex()
                                            local acuIndex = acuTarget:GetAIBrain():GetArmyIndex()
                                            if brainIndex ~= acuIndex then
                                                skipAcu = true
                                            end
                                        else
                                            skipAcu = true
                                        end
                                    end
                                    if skipAcu then
                                        continue
                                    end
                                end
                            end
                            if naval then
                                if (not unitCats.HOVER or unitCats.HOVER and platoon.CurrentPlatoonThreatAntiSurface > 0) and (not unitCats.AIR or unitCats.AIR and platoon.CurrentPlatoonThreatAntiAir > 0) and PositionInWater(v.Position) then
                                    local targetDistance = VDist3Sq(v.Position, aiBrain.BrainIntel.StartPos)
                                    local tempPoint = (v.priority + (v.danger or 0))/RNGMAX(targetDistance,30*30)
                                    if tempPoint > highestPriority then
                                        if NavUtils.CanPathTo(platoon.MovementLayer, platPos, v.Position) then
                                            highestPriority = tempPoint
                                            closestTarget = v.unit
                                        end
                                    end
                                end
                            elseif airOnly then
                                if unitCats.AIR and (v.type == 'bomber' or v.type == 'gunship') then
                                    if v.priority * priorityModifier >= 250 then
                                        tempPoint = (v.priority * priorityModifier + (v.danger or 0))/RNGMAX(targetDistance,30*30)
                                        if tempPoint > highestPriority and highestPriority >= 250 then
                                            highestPriority = tempPoint
                                            closestTarget = v.unit
                                        end
                                    end
                                end
                            else
                                if not unitCats.SCOUT and (not strategicBomber or (not unitCats.TECH1 or unitCats.COMMAND)) and not (v.type == 'gunship' or v.type == 'bomber') then
                                    local priorityModifier = 1
                                    local targetDistance = VDist3Sq(v.Position, aiBrain.BrainIntel.StartPos)
                                    local tempPoint
                                    if zoneType == 'Land' then
                                        local enemyThreat = 0
                                        local zoneId = MAP:GetZoneID(v.Position,aiBrain.Zones.Land.index)
                                        local landZone = aiBrain.Zones.Land.zones[zoneId]
                                        if landZone then
                                            enemyThreat = enemyThreat + landZone.enemylandthreat
                                            for _, v in landZone.edges do
                                                enemyThreat = enemyThreat + v.zone.enemylandthreat
                                            end
                                            if landZone.friendlydirectfireantisurfacethreat > enemyThreat * 1.5 then
                                                priorityModifier = 0.5
                                            end
                                        end
                                    end
                                    if v.priority * priorityModifier >= 250 then
                                        tempPoint = (v.priority * priorityModifier + (v.danger or 0))/RNGMAX(targetDistance,30*30)
                                        if tempPoint > highestPriority and highestPriority >= 250 then
                                            if NavUtils.CanPathTo(platoon.MovementLayer, platPos, v.Position) then
                                                highestPriority = tempPoint
                                                closestTarget = v.unit
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                if closestTarget then
                    return closestTarget
                end
            end
        end
    end
    return false
end

CheckPriorityTarget = function(aiBrain, im, platoon, threatType, threatAmount, presenceCheck, ignoreScouts, airOnly)

    local pointHighest = 0
    local point = false
    local platPos = platoon.Pos or platoon:GetPlatoonPosition()
    for _, v in aiBrain.prioritypoints do
        local dx = platPos[1] - v.Position[1]
        local dz = platPos[3] - v.Position[3]
        local distance = dx * dx + dz * dz
        local tempPoint = v.priority/(RNGMAX(distance,30*30)+(v.danger or 0))
        if tempPoint > pointHighest then
            local validated = true
            if presenceCheck and aiBrain.GridPresence:GetInferredStatus(v.Position) ~= presenceCheck then
                validated = false
            end
            if threatType and GetThreatAtPosition(aiBrain, v.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, threatType) > threatAmount then
                validated = false
            end
            if ignoreScouts then
                local unitCats = v.unit.Blueprint.CategoriesHash
                if unitCats.SCOUT then
                    validated = false
                end
            end
            if airOnly then
                local unitCats = v.unit.Blueprint.CategoriesHash
                if not unitCats.AIR then
                    validated = false
                end
            end
            if validated then
                pointHighest = tempPoint
                point = v
            end
        end
    end
    return point
end


GetPlatUnitEnemyBias = function(aiBrain, platoon, acuSupport)

    local enemy = aiBrain:GetCurrentEnemy()
    local closestUnit
    if enemy and not acuSupport then
        local enemyX, enemyZ = enemy:GetArmyStartPos()
        local closestDistance
        for _, v in GetPlatoonUnits(platoon) do
            if not v.Dead and (not v.Blueprint.CategoriesHash.SCOUT) then
                local unitPos = v:GetPosition()
                local distance = VDist2Sq(unitPos[1], unitPos[3], enemyX, enemyZ)
                if not closestUnit or distance < closestDistance then
                    closestUnit = v
                    closestDistance = distance
                end
            end
        end
    elseif acuSupport then
        local acuPos = aiBrain.CDRUnit.Position
        local closestDistance
        --RNGLOG('acuPos is '..repr(acuPos))
        for _, v in GetPlatoonUnits(platoon) do
            if not v.Dead and (not v.Blueprint.CategoriesHash.SCOUT) then
                local unitPos = v:GetPosition()
                local distance = VDist3Sq(unitPos, acuPos)
                if not closestUnit or distance < closestDistance then
                    closestUnit = v
                    closestDistance = distance
                end
            end
        end
    else
        for _, v in GetPlatoonUnits(platoon) do
            if not v.Dead and (not v.Blueprint.CategoriesHash.SCOUT) then
                closestUnit = v
                break
            end
        end
    end
    return closestUnit
end

GetTargetRange = function(target)
    local maxRange
    if target and target.Blueprint.Weapon then
        for _, v in target.Blueprint.Weapon do
            if not(v.CannotAttackGround == true) then
                if not(v.ManualFire == true) and not(v.BelowWaterFireOnly == true)then
                    if not maxRange or v.MaxRadius > maxRange then
                        maxRange = v.MaxRadius
                    end
                end
            end
        end
    end
    return maxRange
end

CheckDefenseThreat = function(aiBrain, targetPos)
    
    local enemyDefenses = GetUnitsAroundPoint(aiBrain, categories.STRUCTURE * categories.DEFENSE * categories.DIRECTFIRE, targetPos, 45, 'Enemy')
    local totalDefenseThreat = 0
    for _, v in enemyDefenses do
        if v and not v.Dead and v.Blueprint.Defense.SurfaceThreatLevel and v.Blueprint.Weapon[1].MaxRadius then
            if VDist3Sq(v:GetPosition(),targetPos) <= (v.Blueprint.Weapon[1].MaxRadius * v.Blueprint.Weapon[1].MaxRadius) then
                totalDefenseThreat = totalDefenseThreat + v.Blueprint.Defense.SurfaceThreatLevel
            end
        end
    end
    return totalDefenseThreat
end

function SetAcuSnipeMode(unit, bool)
    local targetPriorities = {}
    --RNGLOG('Set ACU weapon priorities.')
    if bool then
       targetPriorities = {
                categories.COMMAND,
                categories.MOBILE * categories.EXPERIMENTAL,
                categories.MOBILE * categories.TECH3,
                categories.MOBILE * categories.TECH2,
                categories.STRUCTURE * categories.DEFENSE * categories.DIRECTFIRE,
                (categories.STRUCTURE * categories.DEFENSE - categories.ANTIMISSILE),
                categories.MOBILE * categories.TECH1,
                (categories.ALLUNITS - categories.SPECIALLOWPRI - categories.INSIGNIFICANTUNIT),
            }
        --RNGLOG('Setting to snipe mode')
    else
       targetPriorities = {
                categories.MOBILE * categories.EXPERIMENTAL,
                categories.MOBILE * categories.TECH3,
                categories.MOBILE * categories.TECH2,
                categories.MOBILE * categories.TECH1,
                categories.COMMAND,
                (categories.STRUCTURE * categories.DEFENSE - categories.ANTIMISSILE),
                (categories.ALLUNITS - categories.SPECIALLOWPRI - categories.INSIGNIFICANTUNIT),
            }
        --RNGLOG('Setting to default weapon mode')
    end
    for i = 1, unit:GetWeaponCount() do
        local wep = unit:GetWeapon(i)
        wep:SetWeaponPriorities(targetPriorities)
    end
end

CenterPlatoonUnitsRNG = function(platoon, platoonPos)
    local furtherest
    local furtherestSpeed
    for _, v in GetPlatoonUnits(platoon) do
        if not v.Dead then
            local unitPos = v:GetPosition()
            local distance = VDist3Sq(unitPos, platoonPos)
            if VDist3Sq(unitPos, platoonPos) > 625 then
                IssueClearCommands({v})
                IssueMove({v}, platoonPos)
                if not furtherest or distance > furtherest then
                    furtherest = distance
                    furtherestSpeed = v.Blueprint.Physics.MaxSpeed
                end
            end
        end
    end
    if furtherestSpeed and furtherestSpeed > 0 then
        return furtherestSpeed
    else
        return 4
    end
end

DefensiveClusterCheck = function(aiBrain, position)
    if aiBrain.EnemyIntel.DirectorData.DefenseCluster then
        for _, v in aiBrain.EnemyIntel.DirectorData.DefenseCluster do
            if v.DefensiveCount > 0 and VDist2Sq(position[1],position[3],v.aggx, v.aggz) < 19600 then
                return true
            end
        end
    end
end

GetArtilleryCounterPosition = function(aiBrain, baseTemplate, unit, basePosition)
    
    local unitId = GetUnitIDFromTemplate(aiBrain, unit)
    if not unitId then
        return false
    end
    local rangeCheck = ALLBPS[unitId].Weapon[1].MaxRadius

    if aiBrain.EnemyIntel.DirectorData.DefenseCluster then
        for _, v in aiBrain.EnemyIntel.DirectorData.DefenseCluster do
            if v.DefensiveCount > 0 and VDist2Sq(basePosition[1],basePosition[3],v.aggx, v.aggz) < 19600 then
                local distance = math.sqrt(VDist2Sq(basePosition[1],basePosition[3],v.aggx, v.aggz))
                local location = lerpy(basePosition, {v.aggx,GetSurfaceHeight(v.aggx, v.aggz),v.aggz}, {distance, distance - rangeCheck })
                for l,bType in baseTemplate do
                    for m,bString in bType[1] do
                        if bString == unit then
                            for n,position in bType do
                                if n > 1 then
                                    local reference = {position[1] + location[1], GetSurfaceHeight(position[1], position[2]) + location[2], position[2] + location[3]}
                                    if aiBrain:CanBuildStructureAt(unitId, reference) then
                                        return reference
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end

CheckHighValueUnitsBuilding = function(aiBrain, locationType)
    --LOG('CheckHighValueUnitsBuilding at '..repr(locationType))
    if not locationType then
        locationType = 'MAIN'
    end
    local baseposition = aiBrain.BuilderManagers[locationType].FactoryManager.Location
    local radius = aiBrain.BuilderManagers[locationType].FactoryManager.Radius
    local count = 0
    if not baseposition then
        --RNGLOG('No Base Position for GetUnitsBeingBuildlocation')
        return false
    end
    if aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime < 1.3 or aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime < 1.2 or GetEconomyStoredRatio(aiBrain, 'MASS') < 0.10 then
        local filterUnits = GetOwnUnitsAroundLocationRNG(aiBrain, categories.ENGINEER * categories.MOBILE - categories.STATIONASSISTPOD, baseposition, radius)
        local highestCompletion
        local bestUnitId
        for k,v in filterUnits do
            if v:IsUnitState('Building') then
                local beingBuiltUnit = v.UnitBeingBuilt
                if beingBuiltUnit and EntityCategoryContains(categories.EXPERIMENTAL + categories.TECH3 * categories.STRATEGIC, beingBuiltUnit) then
                    count = count + 1
                end
            end
        end
        if count then
            --LOG('Return count of high value units is '..count)
            return count
        end
    end
    return false
end

function GetOwnUnitsAroundLocationRNG(aiBrain, category, location, radius)
    local units = aiBrain:GetUnitsAroundPoint(category, location, radius, 'Ally')
    local index = aiBrain:GetArmyIndex()
    local retUnits = {}
    for _, v in units do
        if not v.Dead and v:GetAIBrain():GetArmyIndex() == index then
            RNGINSERT(retUnits, v)
        end
    end
    return retUnits
end

function GetLateralMovePos(unit_position, enemy_position, offset_distance, is_on_right)
    -- Step 1: Calculate the direction vector from the friendly unit to the enemy unit.
    local direction_vector = {
        enemy_position[1] - unit_position[1],
        enemy_position[2] - unit_position[2],
        enemy_position[3] - unit_position[3]
    }

    -- Step 2: Find a perpendicular vector to the direction vector.
    local perpendicular_vector = {
        -direction_vector[3],
        direction_vector[2],
        direction_vector[1]
    }

    -- Step 3: Normalize the perpendicular vector.
    local perpendicular_magnitude = math.sqrt(perpendicular_vector[1] * perpendicular_vector[1] + perpendicular_vector[2] * perpendicular_vector[2] + perpendicular_vector[3] * perpendicular_vector[3])
    if perpendicular_magnitude > 0 then
        perpendicular_vector[1] = perpendicular_vector[1] / perpendicular_magnitude
        perpendicular_vector[2] = perpendicular_vector[2] / perpendicular_magnitude
        perpendicular_vector[3] = perpendicular_vector[3] / perpendicular_magnitude
    end

    -- Step 4: Multiply the normalized perpendicular vector by the fixed offset_distance.
    local sign = is_on_right and 1 or 0 -- Use 1 for right, -1 for left
    local lateral_move_position = {
        unit_position[1] + sign * perpendicular_vector[1] * offset_distance,
        unit_position[2] + sign * perpendicular_vector[2] * offset_distance,
        unit_position[3] + sign * perpendicular_vector[3] * offset_distance
    }

    return lateral_move_position
end

function GetCappingPosition(aiBrain, eng, pos, refunits, baseTemplate, buildingTemplate)
    local closestUnit
    local bestValue
    local unitIds = {}
    local engIndex = GetEngineerFactionIndexRNG(eng)
    local buildingTmplFile = import('/lua/BuildingTemplates.lua')
    local buildingTmpl = buildingTmplFile[('BuildingTemplates')][engIndex]
    for _, v in refunits do
        if not IsDestroyed(v) then
            local extratorPos = v:GetPosition()
            local distance = VDist3(pos, extratorPos)
            local unitValue = closestUnit.Blueprint.Economy.BuildCostEnergy.BuildCostMass or 50
            local value = unitValue / distance
            if (not bestValue or distance == 0) or value > bestValue then
                local canBeCapped = false
                for l,bType in baseTemplate do
                    for m,bString in bType[1] do
                        if aiBrain.CustomUnits and aiBrain.CustomUnits[bString] then
                            local faction = GetEngineerFactionRNG(eng)
                            buildingTemplate = GetTemplateReplacementRNG(aiBrain, bString, faction, buildingTemplate)
                        end
                        local whatToBuild = aiBrain:DecideWhatToBuild(eng, bString, buildingTemplate)
                        if whatToBuild then
                            for n,position in bType do
                                if n > 1 then
                                    local reference = {position[1] + extratorPos[1], GetSurfaceHeight(position[1], position[2]) + extratorPos[2], position[2] + extratorPos[3]}
                                    if aiBrain:CanBuildStructureAt(whatToBuild, reference) then
                                        canBeCapped = true
                                        closestUnit = v
                                        bestValue = value
                                    end
                                end
                                if canBeCapped then
                                    break
                                end
                            end
                        end
                        if canBeCapped then
                            break
                        end
                    end
                    if canBeCapped then
                        break
                    end
                end
            end
        end
    end
    if closestUnit and not IsDestroyed(closestUnit) then
        --LOG('Returning closestUnit Position '..repr(closestUnit:GetPosition()))
        return closestUnit:GetPosition()
    end
end

function GetFabricatorPosition(aiBrain, eng, pos, refunits, baseTemplate, buildingTemplate)
    local closestUnit
    local bestValue
    local unitIds = {}
    local engIndex = GetEngineerFactionIndexRNG(eng)
    local buildingTmplFile = import('/lua/BuildingTemplates.lua')
    local buildingTmpl = buildingTmplFile[('BuildingTemplates')][engIndex]
    for _, v in refunits do
        if not IsDestroyed(v) then
            local extratorPos = v:GetPosition()
            local distance = VDist3(pos, extratorPos)
            local unitValue = closestUnit.Blueprint.Economy.BuildCostEnergy.BuildCostMass or 50
            local value = unitValue / distance
            if (not bestValue or distance == 0) or value > bestValue then
                local canBeCapped = false
                local storageUnits  = AIUtils.GetOwnUnitsAroundPoint(aiBrain, categories.MASSSTORAGE * categories.STRUCTURE, extratorPos, 4)
                for _, s in storageUnits do
                    if not IsDestroyed(s) then
                        local storagePos = s:GetPosition()
                        for l,bType in baseTemplate do
                            for m,bString in bType[1] do
                                if aiBrain.CustomUnits and aiBrain.CustomUnits[bString] then
                                    local faction = GetEngineerFactionRNG(eng)
                                    buildingTemplate = GetTemplateReplacementRNG(aiBrain, bString, faction, buildingTemplate)
                                end
                                local whatToBuild = aiBrain:DecideWhatToBuild(eng, bString, buildingTemplate)
                                if whatToBuild then
                                    for n,position in bType do
                                        if n > 1 then
                                            local reference = {position[1] + storagePos[1], GetSurfaceHeight(position[1], position[2]) + storagePos[2], position[2] + storagePos[3]}
                                            if aiBrain:CanBuildStructureAt(whatToBuild, reference) then
                                                canBeCapped = true
                                                closestUnit = s
                                                bestValue = value
                                            end
                                        end
                                        if canBeCapped then
                                            break
                                        end
                                    end
                                end
                                if canBeCapped then
                                    break
                                end
                            end
                            if canBeCapped then
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    if closestUnit and not IsDestroyed(closestUnit) then
        --LOG('Returning closestUnit Position '..repr(closestUnit:GetPosition()))
        return closestUnit:GetPosition()
    end
end

function GetUnitIDFromTemplate(aiBrain, buildingType)
    local factionIndex = aiBrain:GetFactionIndex()
    local buildingTmplFile = import('/lua/BuildingTemplates.lua')
    local buildingTmpl = buildingTmplFile[('BuildingTemplates')][factionIndex]

    for _, bString in buildingTmpl do
        if bString[1] == buildingType and bString[2] then
            local unitId = bString[2]
            if aiBrain.CustomUnits and aiBrain.CustomUnits[unitId] then
                local factionString
                local factionIndexToName = {[1] = 'UEF', [2] = 'AEON', [3] = 'CYBRAN', [4] = 'SERAPHIM', [5] = 'NOMADS', [6] = 'ARM', [7] = 'CORE' }
                local factionString = factionIndexToName[factionIndex]
                unitId = GetTemplateReplacementRNG(aiBrain, unitId, faction, buildingTmpl)
            end
            return unitId
        end
    end
end

function EngineerEnemyAction(aiBrain, eng)
    if not IsDestroyed(eng) then
        local actionTaken = false
        local engPos = eng:GetPosition()
        local enemyUnits = GetUnitsAroundPoint(aiBrain, categories.LAND * categories.MOBILE, engPos, 45, 'Enemy')
        for _, unit in enemyUnits do
            local enemyUnitPos = unit:GetPosition()
            if EntityCategoryContains(categories.SCOUT + categories.ENGINEER * (categories.TECH1 + categories.TECH2) - categories.COMMAND, unit) then
                if VDist3Sq(enemyUnitPos, engPos) < 144 then
                    --RNGLOG('MexBuild found enemy engineer or scout, try reclaiming')
                    if unit and not unit.Dead and unit:GetFractionComplete() == 1 then
                        local ex = engPos[1] - enemyUnitPos[1]
                        local ez = engPos[3] - enemyUnitPos[3]
                        if (ex * ex + ez * ez) < 156 then
                            IssueClearCommands({eng})
                            IssueReclaim({eng}, unit)
                            actionTaken = true
                            break
                        end
                    end
                end
            elseif EntityCategoryContains(categories.LAND * categories.MOBILE - categories.SCOUT, unit) then
                --RNGLOG('MexBuild found enemy unit, try avoid it')
                local ex = engPos[1] - enemyUnitPos[1]
                local ez = engPos[3] - enemyUnitPos[3]
                if (ex * ex + ez * ez) < 81 then
                    --RNGLOG('enemy unit too close, try reclaim')
                    if unit and not unit.Dead and unit:GetFractionComplete() == 1 then
                        IssueClearCommands({eng})
                        IssueReclaim({eng}, unit)
                        actionTaken = true
                        break
                    end
                else
                    IssueClearCommands({eng})
                    IssueMove({eng}, AvoidLocation(enemyUnitPos, engPos, 50))
                    coroutine.yield(60)
                    actionTaken = true
                end
            end
        end
    end
end

--[[
-- Calculate the distance ratio for a given position
local function getDistanceRatio(position, startX, startZ, platLoc, mapSize)
    local distanceToBorderX = math.min(position[1] - startX, mapSize[1] - position[1] + startX)
    local distanceToBorderZ = math.min(position[3] - startZ, mapSize[2] - position[3] + startZ)
    local distanceToBorder = math.min(distanceToBorderX, distanceToBorderZ)
    
    local distanceToPlatform = VDist2Sq(position[1], position[3], platLoc[1], platLoc[3])
    local edgeDistance = RUtils.EdgeDistance(position[1], position[3], mapSize[1], mapSize[2])
    
    return distanceToBorder / (distanceToPlatform + edgeDistance)
end

-- Sort the MassMarkerTable using a lambda function as the comparison key
table.sort(self.MassMarkerTable, function(a, b)
    local ratioA = getDistanceRatio(a.Position, startX, startZ, platLoc, ScenarioInfo.size)
    local ratioB = getDistanceRatio(b.Position, startX, startZ, platLoc, ScenarioInfo.size)
    return ratioA < ratioB -- Use < instead of > to sort in ascending order (closest to farthest)
end)
]]
--[[ 
function Vector3Subtract(a, b)
    return {a[1] - b[1], a[2] - b[2], a[3] - b[3]}
end

function Vector3Normalize(v)
    local length = math.sqrt(v[1]^2 + v[2]^2 + v[3]^2)
    return {v[1] / length, v[2] / length, v[3] / length}
end

function AvoidObstacle(startPosition, targetPosition, obstaclePosition, avoidanceRadius)
    local directionToTarget = Vector3Normalize(Vector3Subtract(targetPosition, startPosition))
    local directionToObstacle = Vector3Normalize(Vector3Subtract(obstaclePosition, startPosition))
    local distanceToObstacle = math.sqrt(directionToObstacle[1]^2 + directionToObstacle[2]^2 + directionToObstacle[3]^2)

    if distanceToObstacle > avoidanceRadius then
        -- Obstacle is far enough, move towards the target position
        return directionToTarget
    else
        -- Calculate a new position to avoid the obstacle
        local epsilon = 0.1
        local newPosition = {
            obstaclePosition[1] + (avoidanceRadius + epsilon) * directionToObstacle[1],
            obstaclePosition[2] + (avoidanceRadius + epsilon) * directionToObstacle[2],
            obstaclePosition[3] + (avoidanceRadius + epsilon) * directionToObstacle[3]
        }
        return Vector3Normalize(Vector3Subtract(newPosition, startPosition))
    end
end

local startPosition = {0, 0, 0}
local targetPosition = {10, 0, 0}
local obstaclePosition = {5, 5, 0}
local avoidanceRadius = 2

local direction = AvoidObstacle(startPosition, targetPosition, obstaclePosition, avoidanceRadius)

function Vector3Add(a, b)
    return {a[1] + b[1], a[2] + b[2], a[3] + b[3]}
end

function GetPositionAlongDirection(startPosition, direction, distance)
    -- Scale the direction vector by the distance
    local displacement = {direction[1] * distance, direction[2] * distance, direction[3] * distance}
    -- Add the displacement to the starting position to get the new position
    return Vector3Add(startPosition, displacement)
end

local startPosition = {0, 0, 0}
local direction = {1, 0, 0} -- Example direction (unit vector)
local distance = 5 -- Distance to move along the direction

local newPosition = GetPositionAlongDirection(startPosition, direction, distance)

Bresenham Line
]]


-- Function to get a list of positions forming a straight line at a given step size
local function get_straight_line_at_step(start_positions)
    local function calculate_center(map_size)
        return {
            math.floor(map_size[1] / 2),
            math.floor(map_size[2] / 2)
        }
    end
    
    -- Function to determine the direction of the line based on player starting positions
    local function get_line_direction(player_start_positions)
        local x1, z1 = player_start_positions[1][1], player_start_positions[1][2]
        local x2, z2 = player_start_positions[2][1], player_start_positions[2][2]
    
        if x1 == x2 then
            return "vertical"
        else
            return "horizontal"
        end
    end
    
    -- Function to get a list of positions forming a straight line across the center of the map
    local function get_center_line(map_size, player_start_positions)
        local center_pos = calculate_center(map_size)
        local line_positions = {}
        local direction = get_line_direction(player_start_positions)
    
        if direction == "vertical" then
            for z = 0, map_size[2] - 1 do
                table.insert(line_positions, {center_pos[1], z})
            end
        else
            for x = 0, map_size[1] - 1 do
                table.insert(line_positions, {x, center_pos[2]})
            end
        end
    
        return line_positions
    end

    local map_size = {ScenarioInfo.size[1], ScenarioInfo.size[2]} -- Replace this with the actual size of your 2D map
    local line_positions = get_center_line(map_size, start_positions)


    return line_positions
end

function GenerateChokePointLines(aiBrain)
    local function DrawTargetRadius(aiBrain, position)
        --RNGLOG('Draw Target Radius points')
        local counter = 0
        while counter < 60 do
            DrawCircle({position[1], 0, position[2]}, 20, 'cc0000')
            counter = counter + 1
            coroutine.yield( 2 )
        end
    end
    local enemyx, enemyz = aiBrain:GetCurrentEnemy():GetArmyStartPos()
    local player_start_positions = {
        {aiBrain.BrainIntel.StartPos[1], aiBrain.BrainIntel.StartPos[3]},   -- Player 1 starting position
        {enemyx, enemyz}, -- Player 2 starting position
    }
    --LOG('Player Start Positions '..repr(player_start_positions))
    local step_size = 5
    local line_positions = get_straight_line_at_step(player_start_positions)
    for _, v in line_positions do
        --LOG('pos '..repr(v))
        aiBrain:ForkThread(DrawTargetRadius, v)
    end
end

BetweenNumber = function(number, lowerBound, upperBound)
    return number >= lowerBound and number <= upperBound
end

ConfigurePlatoon = function(platoon)
    local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()
    local function SetZone(pos, zoneIndex)
        --RNGLOG('Set zone with the following params position '..repr(pos)..' zoneIndex '..zoneIndex)
        if not pos then
            --RNGLOG('No pos in configure platoon function')
            return false
        end
        local zoneID = MAP:GetZoneID(pos,zoneIndex)
        -- zoneID <= 0 => not in a zone
        if zoneID > 0 then
            platoon.Zone = zoneID
        else
            platoon.Zone = false
        end
    end
    AIAttackUtils.GetMostRestrictiveLayerRNG(platoon)
    platoon.CurrentPlatoonThreat = platoon:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
    if platoon.MovementLayer == 'Water' or platoon.MovementLayer == 'Amphibious' then
        platoon.CurrentPlatoonThreatDirectFireAntiSurface = platoon:CalculatePlatoonThreat('Surface', categories.DIRECTFIRE)
        platoon.CurrentPlatoonThreatIndirectFireAntiSurface = platoon:CalculatePlatoonThreat('Surface', categories.INDIRECTFIRE)
        platoon.CurrentPlatoonThreatAntiSurface = platoon.CurrentPlatoonThreatDirectFireAntiSurface + platoon.CurrentPlatoonThreatIndirectFireAntiSurface
        platoon.CurrentPlatoonThreatAntiNavy = platoon:CalculatePlatoonThreat('Sub', categories.ALLUNITS)
        platoon.CurrentPlatoonThreatAntiAir = platoon:CalculatePlatoonThreat('Air', categories.ALLUNITS)
    end
    -- This is just to make the platoon functions a little easier to read
    if not platoon.EnemyRadius then
        platoon.EnemyRadius = 55
    end
    local aiBrain = platoon:GetBrain()
    local platoonUnits = GetPlatoonUnits(platoon)
    local maxPlatoonStrikeDamage = 0
    local maxPlatoonDPS = 0
    local maxPlatoonStrikeRadius = 20
    local maxPlatoonStrikeRadiusDistance = 0
    if platoonUnits > 0 then
        for k, v in platoonUnits do
            if not v.Dead then
                if not v['rngdata'] then
                    v['rngdata'] = {}
                end
                if not v.PlatoonHandle then
                    v.PlatoonHandle = platoon
                end
                if platoon.PlatoonData.SetWeaponPriorities or platoon.MovementLayer == 'Air' then
                    for i = 1, v:GetWeaponCount() do
                        local wep = v:GetWeapon(i)
                        local weaponBlueprint = wep:GetBlueprint()
                        if weaponBlueprint.CannotAttackGround then
                            continue
                        end
                        if platoon.MovementLayer == 'Air' then
                            --RNGLOG('Unit id is '..v.UnitId..' Configure Platoon Weapon Category'..weaponBlueprint.WeaponCategory..' Damage Radius '..weaponBlueprint.DamageRadius)
                        end
                        if v.Blueprint.CategoriesHash.BOMBER and (weaponBlueprint.WeaponCategory == 'Bomb' or weaponBlueprint.RangeCategory == 'UWRC_DirectFire') then
                            v['rngdata'].DamageRadius = weaponBlueprint.DamageRadius
                            v['rngdata'].StrikeDamage = weaponBlueprint.Damage * weaponBlueprint.MuzzleSalvoSize
                            if weaponBlueprint.InitialDamage then
                                v['rngdata'].StrikeDamage = v['rngdata'].StrikeDamage + (weaponBlueprint.InitialDamage * weaponBlueprint.MuzzleSalvoSize)
                            end
                            v['rngdata'].StrikeRadiusDistance = weaponBlueprint.MaxRadius
                            maxPlatoonStrikeDamage = maxPlatoonStrikeDamage + v['rngdata'].StrikeDamage
                            if weaponBlueprint.DamageRadius > 0 or  weaponBlueprint.DamageRadius < maxPlatoonStrikeRadius then
                                maxPlatoonStrikeRadius = weaponBlueprint.DamageRadius
                            end
                            if v['rngdata'].StrikeRadiusDistance > maxPlatoonStrikeRadiusDistance then
                                maxPlatoonStrikeRadiusDistance = v['rngdata'].StrikeRadiusDistance
                            end
                            --RNGLOG('Have set units DamageRadius to '..v['rngdata'].DamageRadius)
                        end
                        if v.Blueprint.CategoriesHash.GUNSHIP and weaponBlueprint.RangeCategory == 'UWRC_DirectFire' then
                            v['rngdata'].ApproxDPS = CalculatedDPSRNG(weaponBlueprint) --weaponBlueprint.RateOfFire * (weaponBlueprint.MuzzleSalvoSize or 1) *  weaponBlueprint.Damage
                            maxPlatoonDPS = maxPlatoonDPS + v['rngdata'].ApproxDPS
                        end
                    end
                end
                if EntityCategoryContains(categories.ARTILLERY * categories.TECH3,v) then
                    v['rngdata'].Role='Artillery'
                elseif EntityCategoryContains(categories.EXPERIMENTAL,v) then
                    v['rngdata'].Role='Experimental'
                elseif EntityCategoryContains(categories.SILO,v) then
                    v['rngdata'].Role='Silo'
                elseif EntityCategoryContains(categories.xsl0202 + categories.xel0305 + categories.xrl0305,v) then
                    v['rngdata'].Role='Heavy'
                elseif EntityCategoryContains((categories.SNIPER + categories.INDIRECTFIRE) * categories.LAND + categories.ual0201 + categories.drl0204 + categories.del0204,v) then
                    v['rngdata'].Role='Sniper'
                    if EntityCategoryContains(categories.ual0201,v) then
                        v['rngdata'].GlassCannon=true
                    end
                elseif EntityCategoryContains(categories.SCOUT,v) then
                    v['rngdata'].Role='Scout'
                    platoon.ScoutPresent = true
                    platoon.ScoutUnit = v
                elseif EntityCategoryContains(categories.ANTIAIR,v) then
                    v['rngdata'].Role='AA'
                elseif EntityCategoryContains(categories.DIRECTFIRE,v) then
                    v['rngdata'].Role='Bruiser'
                elseif EntityCategoryContains(categories.SHIELD,v) then
                    v['rngdata'].Role='Shield'
                end
                local callBacks = aiBrain:GetCallBackCheck(v)
                local primaryWeaponDamage = 0
                for _, weapon in v.Blueprint.Weapon or {} do
                    -- unit can have MaxWeaponRange entry from the last platoon
                    if weapon.Damage and weapon.Damage > primaryWeaponDamage then
                        primaryWeaponDamage = weapon.Damage
                        if not v['rngdata'].MaxWeaponRange or weapon.MaxRadius > v['rngdata'].MaxWeaponRange then
                            -- save the weaponrange 
                            v['rngdata'].MaxWeaponRange = weapon.MaxRadius * 0.9 -- maxrange minus 10%
                            -- save the weapon balistic arc, we need this later to check if terrain is blocking the weapon line of sight
                            if weapon.BallisticArc == 'RULEUBA_LowArc' then
                                v['rngdata'].WeaponArc = 'low'
                            elseif weapon.BallisticArc == 'RULEUBA_HighArc' then
                                v['rngdata'].WeaponArc = 'high'
                            else
                                v['rngdata'].WeaponArc = 'none'
                            end
                        end
                    end
                    if not v['rngdata'].MaxWeaponRange then
                        v['rngdata'].MaxWeaponRange = weapon.MaxRadius
                    end
                    if not platoon['rngdata'].MaxPlatoonWeaponRange or platoon['rngdata'].MaxPlatoonWeaponRange < v['rngdata'].MaxWeaponRange then
                        platoon['rngdata'].MaxPlatoonWeaponRange = v['rngdata'].MaxWeaponRange
                    end
                end
                if v:TestToggleCaps('RULEUTC_StealthToggle') then
                    v:SetScriptBit('RULEUTC_StealthToggle', false)
                end
                if v:TestToggleCaps('RULEUTC_CloakToggle') then
                    v:SetScriptBit('RULEUTC_CloakToggle', false)
                end
                if v:TestToggleCaps('RULEUTC_JammingToggle') then
                    v:SetScriptBit('RULEUTC_JammingToggle', false)
                end
                v['rngdata'].smartPos = {0,0,0}
                if not v['rngdata'].MaxWeaponRange then
                    --WARN('Scanning: unit ['..repr(v.UnitId)..'] has no MaxWeaponRange - '..repr(platoon.BuilderName))
                end
            end
        end
    end
    if maxPlatoonStrikeDamage > 0 then
        platoon['rngdata'].PlatoonStrikeDamage = maxPlatoonStrikeDamage
    end
    if maxPlatoonStrikeRadius > 0 then
        platoon['rngdata'].PlatoonStrikeRadius = maxPlatoonStrikeRadius
    end
    if maxPlatoonStrikeRadiusDistance > 0 then
        platoon['rngdata'].PlatoonStrikeRadiusDistance = maxPlatoonStrikeRadiusDistance
    end
    if maxPlatoonDPS > 0 then
        platoon['rngdata'].MaxPlatoonDPS = maxPlatoonDPS
    end
    if not platoon.Zone then
        if platoon.MovementLayer == 'Land' or platoon.MovementLayer == 'Amphibious' then
           --RNGLOG('Set Zone on platoon during initial config')
           --RNGLOG('Zone Index is '..aiBrain.Zones.Land.index)
            SetZone(table.copy(GetPlatoonPosition(platoon)), aiBrain.Zones.Land.index)
        elseif platoon.MovementLayer == 'Water' then
            --SetZone(PlatoonPosition, aiBrain.Zones.Naval.index)
        end
    end
end

---@param aiBrain AIBrain
---@param locationType string
---@param radius number
---@param tMin number
---@param tMax number
---@param tRings number
---@param tType string
---@param eng Unit
---@return boolean
---@return string
function AIFindNavalAreaNeedsEngineerRNG(aiBrain, locationType, enemyLabelCheck, radius, tMin, tMax, tRings, tType, eng, shortestDistance)
    local pos = aiBrain.BuilderManagers[locationType].Position
    if not pos then
        return false
    end
    if eng then
        pos = eng:GetPosition()
    end
    local positions = AIUtils.AIGetMarkersAroundLocationRNG(aiBrain, 'Naval Area', pos, radius, tMin, tMax, tRings, tType)

    local retPos, retName
    local closest = false
    local retPos, retName
    local positions = AIUtils.AIFilterAlliedBasesRNG(aiBrain, positions)
    local shortList = {}
    local closestLabelDistance
    local closestLabel
    for _, v in positions do
        local labelRejected = false
        local distance
        local inWater = PositionInWater(v.Position)
        if inWater then
            if shortestDistance then
                local path, msg, pathDistance = NavUtils.PathTo('Amphibious', pos, v.Position)
                if path then
                    distance = pathDistance * pathDistance
                else
                    local mx = v.Position[1] - pos[1]
                    local mz = v.Position[3] - pos[3]
                    distance = mx * mx + mz * mz
                end
            else
                local mx = v.Position[1] - pos[1]
                local mz = v.Position[3] - pos[3]
                distance = mx * mx + mz * mz
            end
            if distance then
                if enemyLabelCheck then
                    local label= NavUtils.GetLabel('Water', {v.Position[1], v.Position[2], v.Position[3]})
                    if label and aiBrain.BrainIntel.NavalBaseLabels[label].State then
                        local labelState = aiBrain.BrainIntel.NavalBaseLabels[label].State
                        if labelState ~= 'Confirmed' then
                            labelRejected = true
                        end
                        if not closestLabel or distance < closestLabelDistance then
                            closestLabelDistance = distance
                            closestLabel = label
                        end
                        if closestLabel and label ~= closestLabel then
                            labelRejected = true
                        end
                    end
                end
                if not labelRejected and not aiBrain.BuilderManagers[v.Name] then
                    local closeToExisting = false
                    for _, b in aiBrain.BuilderManagers do
                        if b.Layer == 'Water' then
                            local rx = v.Position[1] - b.Position[1]
                            local rz = v.Position[3] - b.Position[3]
                            local posDistance = rx * rx + rz * rz
                            if posDistance < 10000 then
                                closeToExisting = true
                                break
                            end
                        end
                    end
                    if not closeToExisting and (not closest or distance < closest) then
                        closest = distance
                        retPos = v.Position
                        retName = v.Name
                    end
                elseif not labelRejected then
                    local managers = aiBrain.BuilderManagers[v.Name]
                    if managers.EngineerManager:GetNumUnits('Engineers') == 0 and managers.FactoryManager:GetNumFactories() == 0 then
                        if not closest or distance < closest then
                            closest = distance
                            retPos = v.Position
                            retName = v.Name
                        end
                    end
                end
            end
        end
    end
    return retPos, retName
end

function GetMarkerFromPosition(refPosition, markerType)
    local markers
    local marker
    if markerType == 'Mass' or markerType == 'Hydrocarbon'then
        markers = GetMarkersRNG()
    else
        markers = MarkerUtils.GetMarkersByType(markerType)
    end
    for _, v in markers do
        local position = v.Position or v.position
        if position and position[1] == refPosition[1] and position[3] == refPosition[3] then
            marker =v
            break
        end
    end
    if not marker then
        WARN('No Marker returned from GetMarkerFromPosition, marker type was '..repr(markerType))
    end
    return marker
end

function GetResourcesFromMarker(marker)
    local resourceTable = {
        Extractors = {},
        HydroCarbons = {}
    }
    if marker then
        if marker.Extractors then
            for k, extractor in marker.Extractors do
                table.insert(resourceTable.Extractors, extractor)
            end
        end
        if marker.HydroCarbons then
            for k, hydro in marker.HydroCarbons do
                table.insert(resourceTable.HydroCarbons, hydro)
            end
        end
    else
        WARN('No marker table passed to GetResourcesFromMarker')
    end
   return resourceTable
end

function SetCoreResources(aiBrain, position, baseName)
    coroutine.yield(50)
    aiBrain:WaitForZoneInitialization()
    local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()
    local targetZone = MAP:GetZoneID(position,aiBrain.Zones.Land.index)
    if not targetZone then
        WARN('No zone returned trying to get core resources for base')
        return
    end
    local resourceTable = table.copy(aiBrain.Zones.Land.zones[targetZone].resourcemarkers)
    if resourceTable then
        if aiBrain.BuilderManagers[baseName] then
            aiBrain.BuilderManagers[baseName].CoreResources = resourceTable
        end
    elseif string.find(baseName, 'Naval Area') then
        return {}
    else
        WARN('No resource table found in GetCoreResources')
        return
    end
end

function VentToPlatoon(platoon, aiBrain, plan)
    local ventPlatoon
    local platoonUnits = platoon:GetPlatoonUnits()
    local count = 0
    for _, v in platoonUnits do
        if v and not v.Dead then
            count = count + 1
        end
    end
    platoon.MachineStarted = false
    if plan == 'LandCombatBehavior' then
       --'We are venting to a new state machine '..aiBrain.Nickname..' platoon count is '..count)
        ventPlatoon = aiBrain:MakePlatoon('', '')
        aiBrain:AssignUnitsToPlatoon(ventPlatoon, platoonUnits, 'Attack', 'None')
        import("/mods/rngai/lua/ai/statemachines/platoon-land-combat.lua").AssignToUnitsMachine({ Vented = true}, ventPlatoon, platoonUnits)
        aiBrain:DisbandPlatoon(platoon)
    elseif plan =='LandAssaultBehavior' then
        ventPlatoon = aiBrain:MakePlatoon('', '')
        aiBrain:AssignUnitsToPlatoon(ventPlatoon, platoonUnits, 'Attack', 'None')
        import("/mods/rngai/lua/ai/statemachines/platoon-land-assault.lua").AssignToUnitsMachine({ Vented = true }, ventPlatoon, platoonUnits)
        aiBrain:DisbandPlatoon(platoon)
    else
        ventPlatoon = aiBrain:MakePlatoon('', plan)
        ventPlatoon.PlanName = 'Vented Platoon'
        aiBrain:AssignUnitsToPlatoon(ventPlatoon, platoonUnits, 'Attack', 'None')
        aiBrain:DisbandPlatoon(platoon)
    end
end

function GetShieldPosition(aiBrain, eng, locationType, whatToBuild, unitTable)
    local function normalposition(vec)
        return {vec[1],GetTerrainHeight(vec[1],vec[2]),vec[2]}
    end
    local function heightbuildpos(vec)
        return {vec[1],vec[2],GetTerrainHeight(vec[1],vec[2])}
    end
    local engPos = eng:GetPosition()
    --LOG('Getting Shield Position')
    --LOG('Structure table requiring shield has this many '..table.getn(unitTable))
    if not table.empty(unitTable)then
        --table.sort(unitTable,function(a,b) return VDist3Sq(engPos,a:GetPosition())<VDist3Sq(engPos,b:GetPosition()) end)
        local buildPositions = {}
        local shieldRequired 
        local shieldPosFound = false
        local unitSize = ALLBPS[whatToBuild].Physics
        for k, v in unitTable do
            --LOG('Unit that needs protecting '..v.UnitId)
            --LOG('Entity '..v.EntityId)
            if not v.Dead then
                if not v['rngdata'] then
                    v['rngdata'] = {}
                end
                --LOG('Looking for shield position from unit list, number of shields unit currently has '..tostring(table.getn(v['rngdata'].ShieldsInRange)))
                local shieldSpaceTimeout = false
                if v['rngdata'].NoShieldSpace and v['rngdata'].NoShieldSpace > 0 then
                    shieldSpaceTimeout = true
                end
                local shieldCount = 0
                if v['rngdata'].ShieldsInRange then
                    for _, s in v['rngdata'].ShieldsInRange do
                        if not s.Dead then
                           shieldCount = shieldCount + 1
                        end
                    end
                end
                if not v['rngdata'].ShieldsInRange or v['rngdata'].ShieldsInRange and shieldCount < 4 and not shieldSpaceTimeout then
                    local targetSize = v.Blueprint.Physics
                    local targetPos = v:GetPosition()
                    local differenceX=math.abs(targetSize.SkirtSizeX-unitSize.SkirtSizeX)
                    local offsetX=math.floor(differenceX/2)
                    local differenceZ=math.abs(targetSize.SkirtSizeZ-unitSize.SkirtSizeZ)
                    local offsetZ=math.floor(differenceZ/2)
                    local offsetfactory=0
                    if EntityCategoryContains(categories.FACTORY, v) then
                        offsetfactory=2
                    end
                    -- Top/bottom of unit
                    for i=-offsetX,offsetX do
                        local testPos = { targetPos[1] + (i * 1), targetPos[3]-targetSize.SkirtSizeZ/2-(unitSize.SkirtSizeZ/2)-offsetfactory, 0 }
                        local testPos2 = { targetPos[1] + (i * 1), targetPos[3]+targetSize.SkirtSizeZ/2+(unitSize.SkirtSizeZ/2)+offsetfactory, 0 }
                        -- check if the buildplace is to close to the border or inside buildable area
                        if testPos[1] > 8 and testPos[1] < ScenarioInfo.size[1] - 8 and testPos[2] > 8 and testPos[2] < ScenarioInfo.size[2] - 8 then
                            if aiBrain:CanBuildStructureAt(whatToBuild, normalposition(testPos)) then
                                v['rngdata'].NoShieldSpace = 0
                                return normalposition(testPos)
                            end
                        end
                        if testPos2[1] > 8 and testPos2[1] < ScenarioInfo.size[1] - 8 and testPos2[2] > 8 and testPos2[2] < ScenarioInfo.size[2] - 8 then
                            if aiBrain:CanBuildStructureAt(whatToBuild, normalposition(testPos2)) then
                                v['rngdata'].NoShieldSpace = 0
                                return normalposition(testPos2)
                            end
                        end
                    end
                    -- Sides of unit
                    for i=-offsetZ,offsetZ do
                        local testPos = { targetPos[1]-targetSize.SkirtSizeX/2-(unitSize.SkirtSizeX/2)-offsetfactory, targetPos[3] + (i * 1), 0 }
                        local testPos2 = { targetPos[1]+targetSize.SkirtSizeX/2+(unitSize.SkirtSizeX/2)+offsetfactory, targetPos[3] + (i * 1), 0 }
                        if testPos[1] > 8 and testPos[1] < ScenarioInfo.size[1] - 8 and testPos[2] > 8 and testPos[2] < ScenarioInfo.size[2] - 8 then
                            if aiBrain:CanBuildStructureAt(whatToBuild, normalposition(testPos)) then
                                v['rngdata'].NoShieldSpace = 0
                                return normalposition(testPos)
                            end
                        end
                        if testPos2[1] > 8 and testPos2[1] < ScenarioInfo.size[1] - 8 and testPos2[2] > 8 and testPos2[2] < ScenarioInfo.size[2] - 8 then
                            if aiBrain:CanBuildStructureAt(whatToBuild, normalposition(testPos2)) then
                                v['rngdata'].NoShieldSpace = 0
                                return normalposition(testPos2)
                            end
                        end
                    end
                end
                --LOG('No build position, setting noshieldspace to zero')
                if shieldCount < 4 then
                    if not v['rngdata'].NoShieldSpace then
                        v['rngdata'].NoShieldSpace = 0
                    end
                    if v['rngdata'].NoShieldSpace < 5 then
                        v['rngdata'].NoShieldSpace = v['rngdata'].NoShieldSpace + 1
                    else
                        v['rngdata'].NoShieldSpace = 0
                    end
                end
            end
        end
    end
end

function GetTMDPosition(aiBrain, eng, locationType)
    local StructureManagerRNG = import('/mods/RNGAI/lua/StructureManagement/StructureManager.lua')
    local smInstance = StructureManagerRNG.GetStructureManager(aiBrain)
    local structureTable = table.copy(smInstance.StructuresRequiringTMD)
    local engPos = eng:GetPosition()
    local tmdPos
    local tmdCandidate
    table.sort(structureTable,function(a,b) return VDist3Sq(engPos,a.Unit:GetPosition())<VDist3Sq(engPos,b.Unit:GetPosition()) end)
    --LOG('Getting TMD Position')
    --LOG('Structure table requiring TMD has this many '..table.getn(structureTable))
    if not table.empty(structureTable)then
        local buildPositions = {}
        local tmdRequired 
        local tmdPosFound = false
        for k, v in structureTable do
            --LOG('Unit that needs protecting '..v.UnitId)
            --LOG('Entity '..v.EntityId)
            if not v.Unit.Dead then
                if not v.Unit['rngdata'].TMDInRange and v.Unit['rngdata'].TMLInRange then
                    --LOG('No TMD table but tml in range')
                    local tmlCount = 0
                    for _, c in v.Unit['rngdata'].TMLInRange do
                        if not c.Dead then
                            tmlCount = tmlCount + 1
                        end
                    end
                    tmdRequired = math.ceil(tmlCount / 2)
                    --LOG('We need this many TMD '..tostring(tmdRequired)..' for '..tostring(aiBrain.Nickname))
                    for _, c in v.Unit['rngdata'].TMLInRange do
                        if not c.Dead then
                            --LOG('CalculateTMDPositions for unit '..v.Unit.UnitId)
                            local buildPos = CalculateTMDPositions(aiBrain, v.Unit, c)
                            if buildPos then
                                table.insert(buildPositions, {Position = buildPos, Count = tmdRequired})
                                tmdPosFound = true
                                break
                            end
                        end
                    end
                elseif v.Unit['rngdata'].TMDInRange and v.Unit['rngdata'].TMLInRange then
                    --LOG('TMD table and tml in range')
                    local tmlCount = 0
                    for _, c in v.Unit['rngdata'].TMLInRange do
                        if not c.Dead then
                            tmlCount = tmlCount + 1
                        end
                    end
                    tmdRequired = math.ceil(tmlCount / 2)
                    --LOG('We need this many TMD '..tostring(tmdRequired)..' for '..tostring(aiBrain.Nickname))
                    local tmdCount = 0
                    for _, c in v.Unit['rngdata'].TMDInRange do
                        if not c.Dead then
                            tmdCount = tmdCount + 1
                        end
                    end
                    --LOG('We have this many tmd now '..tostring(tmdCount))
                    if tmdCount < tmdRequired then
                        for c, b in v.Unit['rngdata'].TMLInRange do
                            if not b.Dead then
                                local buildPos = CalculateTMDPositions(aiBrain, v.Unit, b)
                                if buildPos then
                                    table.insert(buildPositions, {Position = buildPos, Count = tmdRequired})
                                    tmdPosFound = true
                                    break
                                end
                            end
                        end
                    end
                end
            end
            if tmdPosFound then
                --LOG('tmdPosFound')
                break
            end
        end
        --LOG('We have '..table.getn(buildPositions)..' build positions for TMD '..tostring(repr(buildPositions)))
        return buildPositions
    end
end

function CalculateTMDPositions(aiBrain, structure, tml)
    --LOG('CalculateTMDPositions for unit'..structure.UnitId)
    local structurePos = structure:GetPosition()
    local tmlPos = tml:GetPosition()
    local tmlAngle = GetAngleToPosition(structurePos, tmlPos)
    local smInstance = aiBrain.StructureManager
    local tmdDistance = 10 -- Adjust this value based on your game's scale
    local tmdSearchRadius = 15
    --LOG('Calculating build position , structurePos is '..repr(structurePos))
    if not smInstance then
        WARN('AI-RNG : Structure Manager not found in CalculateTMDPositions')
    end

    local unitsToProtect = GetUnitsAroundPoint(aiBrain, categories.STRUCTURE - categories.WALL, structurePos, tmdSearchRadius, 'Ally')  -- Adjust the radius as needed
    local closestUnitDistance
    local bestTMDPos
    --LOG('CalculateTMDPositions origin position is '..tostring(repr(structurePos)))
    --LOG('Trying to calculate TMD position, number of units to protect '..tostring(table.getn(unitsToProtect)))
    
    for _, unit in unitsToProtect do
        if not smInstance:StructureTMLCheck(unit, tml) then
            local unitPos = unit:GetPosition()
            --LOG('Unit Pos is '..tostring(repr(unitPos)))
            local tx = unitPos[1] - tmlPos[1]
            local tz = unitPos[3] - tmlPos[3]
            local tmlDistance = tx * tx + tz * tz
            if not closestUnitDistance or tmlDistance < closestUnitDistance then
                --LOG('Have closestUnitDistance for structure')
                local testBuildPos = GetPositionTowardsAngle(unitPos, tmlAngle, tmdDistance)
                --LOG('Checking buildPos of '..repr(testBuildPos))
                if CanBuildStructureAt(aiBrain, 'ueb4201', testBuildPos) then
                    --LOG('We can build there')
                    closestUnitDistance = tmlDistance
                    bestTMDPos = testBuildPos
                else
                    -- if we can't build a structure there we will look around a little bit
                    local lookAroundTable = {1,-1,2,-2,3,-3,4,-4}
                    --LOG('We are trying to look for another build position for TMD')
                    for ix, offsetX in lookAroundTable do
                        for iz, offsetZ in lookAroundTable do
                            local lookAroundPos = {testBuildPos[1]+offsetZ, GetSurfaceHeight(testBuildPos[1]+offsetX, testBuildPos[3]+offsetZ), testBuildPos[3]+offsetX}
                            -- is it lower land... make it our new position to continue searching around
                            if CanBuildStructureAt(aiBrain, 'ueb4201', lookAroundPos) then
                                closestUnitDistance = tmlDistance
                                bestTMDPos = testBuildPos
                                --LOG('We found an alternative build position for TMD')
                                break
                            end
                        end
                    end
                end
            end
        else
            --LOG('StructureTMLCheck returned true')
        end
        if bestTMDPos then
            break
        end
    end
    --LOG('Returning best build pos of '..repr(bestTMDPos))
    return bestTMDPos
end

---@param self FactoryBuilderManager
---@param template any
---@param templateName string
---@param faction Unit
---@return boolean|table
GetCustomUnitReplacement = function(self, template, templateName, faction)
    local retTemplate = false
    local templateData = self.Brain.CustomUnits[templateName]
    if templateData and templateData[faction] then
        -- LOG('*AI DEBUG: Replacement for '..templateName..' exists.')
        local rand = Random(1,100)
        local possibles = {}
        for k,v in templateData[faction] do
            if rand <= v[2] or template[1] == 'NoOriginalUnit' then
                -- LOG('*AI DEBUG: Insert possibility.')
                table.insert(possibles, v[1])
            end
        end
        if not table.empty(possibles) then
            rand = Random(1,TableGetn(possibles))
            local customUnitID = possibles[rand]
            -- LOG('*AI DEBUG: Replaced with '..customUnitID)
            retTemplate = { customUnitID, template[2], template[3], template[4], template[5] }
        end
    end
    return retTemplate
end

CalculateSMDDistanceSquared = function(x1, z1, x2, z2)
    local dx = x2 - x1
    local dz = z2 - z1
    return dx * dx + dz * dz
end

IsWithinInterceptionRadiusSquared = function(position1, position2, radius)
    local distanceSquared = CalculateSMDDistanceSquared(position1[1], position1[3], position2[1], position2[3])
    return distanceSquared <= (radius * radius)
end

FindSMDAtPosition = function(position, smdTable, radius)
    local gameTime = GetGameTimeSeconds()
    local smdList = {}

    for _, defense in smdTable do
        if not defense.object.Dead then
            if ( defense.Detected < gameTime - 240 and defense.Completed and defense.Completed < gameTime - 240 ) and IsWithinInterceptionRadiusSquared(defense.Position, {position[1], position[2], position[3]}, radius) then
                table.insert(smdList, defense)
            end
        end
    end
    if not table.empty(smdList) then
        return true, smdList
    end
    return false
end

FindSMDBetweenPositions = function(start, finish, smdTable, radius, stepDistance)

    local gameTime = GetGameTimeSeconds()

    -- Function to check if the missile's trajectory intersects with any defense system

    local dx = finish[1] - start[1]
    local dy = finish[2] - start[2]
    local dz = finish[3] - start[3]
    local distanceSquared = CalculateSMDDistanceSquared(start[1], start[3], finish[1], finish[3])
    
    -- Normalize direction vector
    local magnitudeSquared = dx * dx + dy * dy + dz * dz
    local invMagnitude = 1 / magnitudeSquared
    dx = dx * invMagnitude
    dy = dy * invMagnitude
    dz = dz * invMagnitude

    local totalDistance = math.sqrt(distanceSquared)
    
    -- Check points along the trajectory for interception
    local numSteps = math.floor(totalDistance / stepDistance)
    local stepSizeSquared = distanceSquared / numSteps
    for i = 1, numSteps do
        local currentX = start[1] + dx * stepSizeSquared * i
        local currentY = start[2] + dy * stepSizeSquared * i
        local currentZ = start[3] + dz * stepSizeSquared * i
        -- Check if current point intersects with any defense system
        for _, defense in smdTable do
            if not defense.object.Dead then
                if ( defense.Detected < gameTime - 240 and defense.Completed and defense.Completed < gameTime - 240 ) and IsWithinInterceptionRadiusSquared(defense.Position, {currentX, currentY, currentZ}, radius) then
                    return true, defense.Position
                end
            end
        end
    end
    return false
end

GetNukeStrikePositionRNG = function(aiBrain, maxMissiles, smlLaunchers, experimentalPresent)
    if not aiBrain then
        return nil
    end
    local function GetMissileDetails(ALLBPS, unitId)
        if ALLBPS[unitId].Weapon[1].DamageType == 'Nuke' and ALLBPS[unitId].Weapon[1].ProjectileId then
            local projBp = ALLBPS[unitId].Weapon[1].ProjectileId
            return ALLBPS[projBp].Economy.BuildCostMass, ALLBPS[unitId].Weapon[1].NukeInnerRingRadius
        end
        return false
    end
    --LOG('GetNukeStrikePosition Started')
    -- Look for commander first
    local ALLBPS = __blueprints
    local im = IntelManagerRNG.GetIntelManager(aiBrain)
    local knownSMDUnits = aiBrain.EnemyIntel.SMD
    -- minimumValue : I want to make sure that whatever we shoot at it either an ACU or is worth more than the missile we just built.
    local minimumValue = 0
    local missilesConsumed = 0
    local firingPositions = {}
    local missileCost
    local missileRadius
    local smdRadius
    local experimentalLauncherAvailable = false
    local gameTime = GetGameTimeSeconds()
    for _, sml in smlLaunchers do
        if sml.Launcher and not sml.Launcher.Dead then
            local smlMissileCost, smlMissileRadius = GetMissileDetails(ALLBPS, sml.Launcher.UnitId)
            if not missileCost or smlMissileCost > missileCost then
                missileCost = smlMissileCost
            end
            if not missileRadius or smlMissileRadius > missileRadius then
                missileRadius = smlMissileRadius
            end
            if sml.Launcher.Blueprint.CategoriesHash.EXPERIMENTAL then
                experimentalLauncherAvailable = true
            end
        end
    end
    if maxMissiles == 0 then
        return {}
    end
    --LOG('GetNukeStrikePosition Max Missiles '..maxMissiles)

    --RNGLOG('SML Missile cost is '..missileCost)
    --RNGLOG('SML Missile radius is '..missileRadius)
    if not missileRadius or not missileCost then
        -- fallback incase its a strange launcher
        missileRadius = 30
        missileCost = 12000
    end
    if not table.empty(knownSMDUnits) then
        for _, v in knownSMDUnits do
            if not v.object.Dead and v.object.Blueprint.Weapon[1].MaxRadius then
                --LOG('knownSMD unit '..repr(v.object:GetPosition()))
                smdRadius = v.Blueprint.Weapon[1].MaxRadius
                break
            else
                --LOG('SMD is dead')
            end
        end
    end
    --LOG('Missile Cost is '..missileCost)
    --LOG('Missile Radius is '..missileRadius)
    --LOG('Known SMD units '..repr(knownSMDUnits))
    if not smdRadius then
        smdRadius = ALLBPS['ueb4302'].Weapon[1].MaxRadius or 90
    end
    --LOG('GetNukeStrikePosition smd radius'..smdRadius)
    local acuTargetPositions = {}
    for k, v in aiBrain.EnemyIntel.ACU do
        if (not v.Unit.Dead) and (not v.Ally) and v.HP ~= 0 and v.LastSpotted ~= 0 then
            if HaveUnitVisual(aiBrain, v.Unit, true) and (not FindSMDAtPosition(v.Position, knownSMDUnits, smdRadius) or experimentalLauncherAvailable)  then
                RNGINSERT(acuTargetPositions, v.Position)
            end
        end
    end
    --LOG('GetNukeStrikePosition targetpositions after acu check'..repr(targetPositions))

    --RNGLOG(' ACUs detected are '..table.getn(targetPositions))
    local targetShortList = {}

    if not table.empty(acuTargetPositions) then
        local targetFound = false
        for _, pos in acuTargetPositions do
            for _, v in smlLaunchers do
                local antiNukes = FindSMDBetweenPositions(v.Launcher:GetPosition(), pos, knownSMDUnits, smdRadius, 45)
                if antiNukes < 1 or experimentalLauncherAvailable then
                    targetFound = true
                    --LOG('Adding firing position for acu')
                    RNGINSERT(targetShortList, { threat = 10000, position = pos, massvalue = 0, ACU=true })
                end
            end
        end
    end

    -- Now look through the bases for the highest economic threat and largest cluster of units
    local enemyBases = aiBrain.EnemyIntel.EnemyThreatLocations
    for _, x in enemyBases do
        for _, z in x do
            local skip = false
            if z.StructuresNotMex then
                for _, v in aiBrain.BrainIntel.SMLTargetPositions do
                    local tx = v.Position[1] - z.Position[1]
                    local tz = v.Position[3] - z.Position[3]
                    local targetDistance = tx * tx + tz * tz
                    if targetDistance < missileRadius * missileRadius then
                        --LOG('Attempting to nuke a position that has recently been nuked, skipping')
                        skip = true
                        break
                    end
                end
                if not skip then
                    local posThreat = aiBrain:GetThreatAtPosition(z.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'Economy')
                    RNGINSERT(targetShortList, { threat = posThreat, position = z.Position, massvalue = 0 })
                end
            end
        end
    end
    RNGSORT( targetShortList, function(a,b) return a.threat > b.threat  end )

    if table.empty(targetShortList) and not table.empty(firingPositions) then
        -- No threat
        return true, firingPositions
    end

    --RNGLOG('First pass of target shortlist complete')
    RNGSORT( targetShortList, function(a,b) return a.threat > b.threat  end )
    local finalShortList = {}
    for _, finalTarget in targetShortList do
        local maxValue = 0
        local lookAroundTable = {-2, -1, 0, 1, 2}
        local squareRadius = (ScenarioInfo.size[1] / 16) / RNGGETN(lookAroundTable)
        for ix, offsetX in lookAroundTable do
            for iz, offsetZ in lookAroundTable do
                local searchPos = {finalTarget.position[1] + offsetX*squareRadius, 0, finalTarget.position[3]+offsetZ*squareRadius}
                local smdPresent, _ = FindSMDAtPosition(searchPos, knownSMDUnits, smdRadius)
                if not smdPresent or experimentalLauncherAvailable then
                    --LOG('No SMD at position '..repr(searchPos))
                    local unitsAtLocation = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE, searchPos, missileRadius, 'Enemy')
                    local currentValue = 0
                    --LOG('Number of units at location with structure category is '..table.getn(unitsAtLocation))
                    for _, v in unitsAtLocation do
                        if v.Blueprint.Economy.BuildCostMass then
                            if v.Blueprint.CategoriesHash.ENERGYPRODUCTION then
                                currentValue = currentValue + v.Blueprint.Economy.BuildCostMass * 1.5
                            else
                                currentValue = currentValue + v.Blueprint.Economy.BuildCostMass
                            end
                        end
                    end
                    if finalTarget.ACU then
                        currentValue = currentValue + 25000
                        --LOG('Adding ACU mass value to shortlist validation')
                    end
                    --LOG('Must be greater than '..missileCost)
                    --LOG('Current value '..tostring(currentValue)..' max value '..tostring(maxValue))
                    if currentValue > missileCost and currentValue > maxValue then
                        maxValue = currentValue
                        --LOG('Value is higher than max value, set maxValue to '..tostring(maxValue))
                        for _, v in smlLaunchers do
                            local experimental = v.Launcher.Blueprint.CategoriesHash.EXPERIMENTAL or false
                            local smdBetweenPos
                            --LOG('Missile Count of current launcher is '..v.Count)
                            if v.Count > 0 then
                                if not experimental then
                                    smdBetweenPos, smd = FindSMDBetweenPositions(v.Launcher:GetPosition(), searchPos, knownSMDUnits, smdRadius, 45)
                                end
                                if not smdBetweenPos or experimentalLauncherAvailable then
                                    --LOG('No SMD between positions for target pos '..repr(searchPos))
                                    --LOG('Adding firing position for searchtargetarea')
                                    --LOG('SMD positions known '..repr(knownSMDUnits))
                                    table.insert(finalShortList, { Launcher = v.Launcher, Position = searchPos,  MassValue = currentValue, TimeStamp = gameTime, EntityId = v.Launcher.EntityId, IMAPPos = finalTarget.position})
                                    break
                                else
                                    --LOG('Found SMD along path to position I was trying to nuke, switch to different position')
                                end
                            end
                        end
                    end
                else
                    --LOG('Found SMD at position I was trying to nuke, switch to different position')
                end
            end
            --LOG('missileAllocated current max value is '..maxValue)
        end
        coroutine.yield(1)
    end
    RNGSORT( finalShortList, function(a,b) return a.MassValue > b.MassValue end )
    --LOG('Looping through final shortlist for highest mass value')
    for k, v in finalShortList do
        --LOG('First value is '..tostring(v.MassValue))
        for _, l in smlLaunchers do
            if v.EntityId == l.Launcher.EntityId and l.Count > 0 then
                --LOG('Adding final position for launcher '..v.EntityId)
                --LOG('Mass value of position is '..v.MassValue)
                missilesConsumed = missilesConsumed + 1
                table.insert(firingPositions, finalShortList[k])
                l.Count = l.Count - 1
            end
        end
        if missilesConsumed >= maxMissiles then
            --LOG('We have used all our missiles')
            break
        end
    end
    if not table.empty(firingPositions) then
        --RNGLOG('Best pos found with a mass value of '..maxValue)
        --RNGLOG('Best pos position is '..repr(bestPos))
        --LOG('Returning firing positions '..tostring(repr(firingPositions)))
        local RNGChat = import("/mods/RNGAI/lua/AI/RNGChat.lua")
        ForkThread(RNGChat.ConsiderAttackTaunt, aiBrain, 'LaunchNuke', nil, 8)
        return true, firingPositions
    end
    --LOG('No target list any firing positions '..repr(firingPositions))
    return false
end

GetStartRaidPositions = function(aiBrain, startPos, enemyIndex)
    local function DrawTargetRadius(brain, position, colour)
        --RNGLOG('Draw Target Radius points')
        local counter = 0
        while counter < 60 do
            DrawCircle(position, 3, colour)
            counter = counter + 1
            coroutine.yield( 2 )
        end
    end

    local function filterPositions(startX, startY, endX, endY, resourcePositions, tolerance)
        local filteredPositions = {}
        
        -- Calculate the slope and intercept of the line connecting start and end positions
        local slope = (endY - startY) / (endX - startX)
        local intercept = startY - slope * startX
        
        -- Iterate through resource positions
        for _, position in ipairs(resourcePositions) do
            -- Calculate the expected Y value on the line for this X position
            local expectedY = slope * position.pos[1] + intercept
            
            -- Check if the actual Y position is within tolerance of the expected Y
            if math.abs(position.pos[3] - expectedY) <= tolerance then
                table.insert(filteredPositions, position)
            end
        end
        
        return filteredPositions
    end
    if not aiBrain.ZonesInitialized then
        WARN('AI-RNG* : Zones are not currently initialized for start raid positions, currentl value is '..repr(aiBrain.ZonesInitialized))
        coroutine.yield(50)
        return
    end
    if not enemyIndex then
        WARN('AI-RNG* : No enemy index passed to get start raid positions, possibly there is not enemy or this is a campaign map')
        coroutine.yield(50)
        return
    end
    local tolerance = 100

    local filteredZoneTable = {}
    local enemyStartPos = aiBrain.EnemyIntel.EnemyStartLocations[enemyIndex].Position
    local distanceToEnemy = VDist2Sq(startPos[1],startPos[3],enemyStartPos[1],enemyStartPos[3])
    for _, v in aiBrain.Zones.Land.zones do
        if not v.startpositionclose then
            local startDist = v.enemystartdata[enemyIndex].startdistance
            if startDist < distanceToEnemy then
                table.insert(filteredZoneTable, {pos = v.pos, resourceValue = v.resourcevalue, startDist = startDist})
            end
        end
    end
    table.sort(filteredZoneTable, function(a, b) return a.startDist < b.startDist end)
    local shortList = {}
    local shortListCount = math.min(RNGGETN(filteredZoneTable), 5)
    --LOG('shortListCount is '..repr(shortListCount))
    if shortListCount == 0 then
        coroutine.yield(5)
        return
    end
    for i=1, shortListCount do
        if filteredZoneTable[i] then
            table.insert(shortList, filteredZoneTable[i])
        end
    end
    
    --LOG('Dump shortList '..repr(shortList))
    table.sort(shortList, function(a, b) return a.resourceValue > b.resourceValue end)
    --LOG('Dump shortList by resource value '..repr(shortList))
    local selectedPos = shortList[math.random(1,shortListCount)]
    --LOG('shortList random pos is '..repr(selectedPos))
    local targetAngle = GetAngleToPosition(selectedPos.pos, startPos)
    table.sort(filteredZoneTable, function(a, b)
        local distanceA = VDist2(startPos[1], startPos[3], a.pos[1], a.pos[3])
        local distanceB = VDist2(startPos[1], startPos[3], b.pos[1], b.pos[3])
        
        -- Check if the resource positions are on the same side as the target angle
        local angleA = GetAngleToPosition(enemyStartPos, a.pos)
        local angleB = GetAngleToPosition(enemyStartPos, b.pos)
        
        local prevAngleDifferenceA = math.abs(targetAngle - angleA)
        local prevAngleDifferenceB = math.abs(targetAngle - angleB)

        prevAngleDifferenceA = math.min(prevAngleDifferenceA, math.pi - prevAngleDifferenceA)
        prevAngleDifferenceB = math.min(prevAngleDifferenceB, math.pi - prevAngleDifferenceB)
        
        -- Prioritize positions that are closer to a straight line between start and end
        local importanceA = a.resourceValue * (1 / (distanceA + 0.1)) * (1 / prevAngleDifferenceA)
        local importanceB = b.resourceValue * (1 / (distanceB + 0.1)) * (1 / prevAngleDifferenceB)
        
        return importanceA > importanceB
    end)
    local filteredPositions = filterPositions(startPos[1], startPos[3], selectedPos.pos[1], selectedPos.pos[3], filteredZoneTable, tolerance)
    table.sort(filteredPositions, function(a, b) return a.startDist > b.startDist end)
    --for _, v in filteredPositions do
    --    aiBrain:ForkThread(DrawTargetRadius, v.pos, 'cc0000')
    --    LOG('Positions returned '..repr(v.pos))
    --end
    return selectedPos, shortList, filteredPositions
end

CalculateAveragePosition = function(positions, playerCount)
    local totalX, totalZ = 0, 0
    for _, pos in positions do
        totalX = totalX + pos.Position[1]
        totalZ = totalZ + pos.Position[3]
    end
    local averageX = totalX / playerCount
    local averageZ = totalZ / playerCount
    return {x = averageX, z = averageZ}
end

CalculateRelativeDistanceValue = function(a_distance, b_distance)
    d_total = a_distance + b_distance
    
    if d_total == 0 then
        return 1  -- Both distances are 0
    end
    
    normalized_distance = (2 * a_distance) / d_total
    
    return normalized_distance
end

GetBaseType = function(baseName)
    local baseType
    if not baseName then
        WARN('No base name provided for GetBaseType')
        return
    end
    if string.find(baseName, 'ZONE') then
        baseType = 'Zone Area'
    else
        baseType = MarkerUtils.GetMarker(baseName).Type
    end
    return baseType
end

CheckForCivilianUnitCapture = function(aiBrain, eng, movementLayer)

    if aiBrain.EnemyIntel.CivilianCaptureUnits and not table.empty(aiBrain.EnemyIntel.CivilianCaptureUnits) then
        local closestUnit
        local closestDistance
        local engPos = eng:GetPosition()
        for _, v in aiBrain.EnemyIntel.CivilianCaptureUnits do
            if not IsDestroyed(v.Unit) and v.Risk == 'Low' and (not v.EngineerAssigned or v.EngineerAssigned.Dead) and v.CaptureAttempts < 3 and NavUtils.CanPathTo(movementLayer,engPos,v.Position) then
                local distance = VDist3Sq(engPos, v.Position)
                if not closestDistance or distance < closestDistance then
                    --LOG('filtering closest unit, current distance is '..math.sqrt(distance))
                    local unitValue = closestUnit.Blueprint.Economy.BuildCostEnergy.BuildCostMass or 50
                    local distanceMult = math.sqrt(distance)
                    if unitValue / distanceMult > 0.2 then
                        --LOG('Found right value unit '..(unitValue / distanceMult))
                        closestUnit = v.Unit
                        closestDistance = distance
                    end
                end
            end
        end
        
        if closestUnit and not IsDestroyed(closestUnit) then
            return closestUnit
        end
    end

end

GetRallyPoint = function(aiBrain, layer, position, minRadius, maxRadius)

    local rallyCheckPoints = NavUtils.GetPositionsInRadius(layer, position, maxRadius)
    local shortlist = {}

    if not table.empty(rallyCheckPoints) then
        minRadius = minRadius * minRadius
        maxRadius = maxRadius * maxRadius
        for _, m in rallyCheckPoints do
            local dx = position[1] - m[1]
            local dz = position[3] - m[3]
            local posDist = dx * dx + dz * dz
            if posDist > minRadius and posDist < maxRadius then
                if aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE, m, 15, 'Ally') < 1 and NavUtils.CanPathTo(layer, position, m) then
                    RNGINSERT(shortlist, {Position = m, Distance = posDist})
                end
            end
        end
        if not table.empty(shortlist) then
            local referencePosition
            local teamAveragePositions = aiBrain.IntelManager:GetTeamAveragePositions()

            local teamAveragePosition
            if teamAveragePositions['Enemy'].x and teamAveragePositions['Enemy'].z then
                teamAveragePosition = {teamAveragePositions['Enemy'].x,GetSurfaceHeight(teamAveragePositions['Enemy'].x, teamAveragePositions['Enemy'].z), teamAveragePositions['Enemy'].z}
            end
            if teamAveragePosition[1] then
                referencePosition = teamAveragePosition
            else
                referencePosition = aiBrain.MapCenterPoint
            end
            
            -- Function to calculate the dot product of two vectors
            function NormalizeVector(v)
                if v.x then
                    v = {v.x, v.y, v.z}
                end
                
                local length = math.sqrt(math.pow(v[1], 2) + math.pow(v[2], 2) + math.pow(v[3], 2))
                
                if length > 0 then
                    local invlength = 1 / length
                    return {v[1] * invlength, v[2] * invlength, v[3] * invlength}
                else
                    return {0, 0, 0}
                end
            end
            
            function GetDirectionVector(v1, v2)
                return NormalizeVector({v1[1] - v2[1], v1[2] - v2[2], v1[3] - v2[3]})
            end
            
            function DotProduct(v1, v2)
                return v1[1] * v2[1] + v1[2] * v2[2] + v1[3] * v2[3]
            end

            local direction = GetDirectionVector(position, referencePosition)

            -- Sort the shortlist based on distance and alignment with the target direction
            table.sort(shortlist, function(a, b)
                -- Calculate the direction vectors from current position to positions a and b
                local directionA = GetDirectionVector(position, a.Position)
                local directionB = GetDirectionVector(position, b.Position)
            
                -- Calculate the dot product with the target direction
                local dotA = DotProduct(direction, directionA)
                local dotB = DotProduct(direction, directionB)
            
                -- First, sort by alignment with the target direction
                if dotA ~= dotB then
                    return dotA > dotB
                end
            
                -- If alignments are equal, sort by distance
                return a.Distance < b.Distance
            end)
        end
        return shortlist[1].Position
    end
end

GetLineOfSightPriority = function(aiBrain, navalPosition, startPosition)
    local destroyerHeight = 0
    local battlesShipHeight = 0
    local checkPos = {navalPosition[1],navalPosition[2] ,navalPosition[3]}
    local priority = 0.7
    if aiBrain:CheckBlockingTerrain({navalPosition[1], navalPosition[2] + destroyerHeight, navalPosition[3]}, startPosition, 'low') then
        priority = 2.0
    elseif aiBrain:CheckBlockingTerrain({navalPosition[1], navalPosition[2] + battlesShipHeight, navalPosition[3]}, startPosition, 'low') then
        priority = 1.5
    elseif aiBrain:CheckBlockingTerrain({navalPosition[1], navalPosition[2] + 60, navalPosition[3]}, startPosition, 'low') then
        priority = 1.0
    end
    return priority
end

UpdateShieldsProtectingUnit = function(aiBrain, finishedUnit)
    local function GetShieldRadiusAboveGroundSquaredRNG(shield)
        local width = shield.Blueprint.Defense.Shield.ShieldSize
        local height = shield.Blueprint.Defense.Shield.ShieldVerticalOffset
        return width - height
    end
    local function IsUnitCoveredByShield(unitPos, unitSizeX, unitSizeZ, shieldPos, shieldRadiusSq)
        local halfX = (unitSizeX or 1) * 0.5
        local halfZ = (unitSizeZ or 1) * 0.5
    
        -- Calculate the four corners of the unit
        local checkPoints = {
            {unitPos[1] - halfX, unitPos[3] - halfZ}, -- Bottom-left
            {unitPos[1] + halfX, unitPos[3] - halfZ}, -- Bottom-right
            {unitPos[1] - halfX, unitPos[3] + halfZ}, -- Top-left
            {unitPos[1] + halfX, unitPos[3] + halfZ}  -- Top-right
        }
    
        local coveredPoints = 0
    
        -- Check if each corner is inside the shield radius
        for _, point in ipairs(checkPoints) do
            local dx = shieldPos[1] - point[1]
            local dz = shieldPos[3] - point[2]
            local distSq = dx * dx + dz * dz  -- Squared distance
    
            if distSq <= shieldRadiusSq then
                coveredPoints = coveredPoints + 1
                -- If at least 3 corners are covered, we can return early
                if coveredPoints >= 3 then
                    return true
                end
            end
        end
    
        return false
    end
    if not finishedUnit['rngdata'] then
        finishedUnit['rngdata'] = {}
    end
    local deathFunction = function(unit)
        if unit['rngdata'].ShieldsInRange then
            for _, v in pairs(unit['rngdata'].ShieldsInRange) do
                if v and not v.Dead and v['rngdata'].UnitsDefended then
                    local keyToDelete
                    for l, c in pairs(v['rngdata'].UnitsDefended) do
                        if unit.EntityId == c.EntityId then
                            --LOG('Removing Unit from shield unitsdefended table')
                            keyToDelete = l
                            break
                        end
                    end
                    if keyToDelete then
                        table.remove(v['rngdata'].UnitsDefended, keyToDelete)
                    end
                end
            end

        end
    end
    import("/lua/scenariotriggers.lua").CreateUnitDestroyedTrigger(deathFunction, finishedUnit)
    local finishedUnitPos = finishedUnit:GetPosition()
    local shields = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE * categories.SHIELD, finishedUnitPos, 50, 'Ally')
    if not table.empty(shields) then
        for _, v in shields do
            if v and not v.Dead then
                if not v['rngdata'] then
                    v['rngdata'] = {}
                end
                if not v['rngdata'].UnitsDefended then
                    v['rngdata'].UnitsDefended = setmetatable({}, WeakValueTable)
                end
                local shieldPos = v:GetPosition()
                local dx = finishedUnitPos[1] - shieldPos[1]
                local dz = finishedUnitPos[3] - shieldPos[3]
                local distSquared = dx * dx + dz * dz
                local unitSizeX = finishedUnit.Blueprint.SizeX or 1
                local unitSizeZ = finishedUnit.Blueprint.SizeZ or 1
                if v['rngdata']['UnitsDefended'] then
                    local defenseRadiusSquared = GetShieldRadiusAboveGroundSquaredRNG(v)
                    if distSquared <= defenseRadiusSquared and IsUnitCoveredByShield(finishedUnitPos, unitSizeX, unitSizeZ, shieldPos, defenseRadiusSquared) then
                        -- Ensure finishedUnit has ShieldsInRange table
                        if not finishedUnit['rngdata'].ShieldsInRange then
                            finishedUnit['rngdata'].ShieldsInRange = setmetatable({}, WeakValueTable)
                        end
                        finishedUnit['rngdata'].ShieldsInRange[v.EntityId] = v
                        v['rngdata']['UnitsDefended'][finishedUnit.EntityId] = finishedUnit
                    end
                end
            end
        end
    end
end

UpdateUnitsProtectedByShield = function(aiBrain, finishedUnit)
    if not finishedUnit['rngdata'] then
        finishedUnit['rngdata'] = {}
    end

    local deathFunction = function(unit)
        if unit['rngdata'].UnitsDefended then
            for _, v in pairs(unit['rngdata'].UnitsDefended) do
                if v and not v.Dead and v.ShieldsInRange then
                    v.ShieldsInRange[unit.EntityId] = nil
                end
            end
        end
    end
    import("/lua/scenariotriggers.lua").CreateUnitDestroyedTrigger(deathFunction, finishedUnit)

    if not finishedUnit['rngdata']['UnitsDefended'] then
        finishedUnit['rngdata']['UnitsDefended'] = {}
    end

    local function GetShieldRadiusAboveGroundSquaredRNG(shield)
        local width = shield.Blueprint.Defense.Shield.ShieldSize
        local height = shield.Blueprint.Defense.Shield.ShieldVerticalOffset
        local radius = width - height
        return radius * radius  -- Return squared value for direct comparison
    end

    local function IsUnitCoveredByShield(unitPos, unitSizeX, unitSizeZ, shieldPos, shieldRadiusSq)
        local halfX = (unitSizeX or 1) * 0.5
        local halfZ = (unitSizeZ or 1) * 0.5
    
        -- Calculate the four corners of the unit
        local checkPoints = {
            {unitPos[1] - halfX, unitPos[3] - halfZ}, -- Bottom-left
            {unitPos[1] + halfX, unitPos[3] - halfZ}, -- Bottom-right
            {unitPos[1] - halfX, unitPos[3] + halfZ}, -- Top-left
            {unitPos[1] + halfX, unitPos[3] + halfZ}  -- Top-right
        }
    
        local coveredPoints = 0
    
        -- Check if each corner is inside the shield radius
        for _, point in ipairs(checkPoints) do
            local dx = shieldPos[1] - point[1]
            local dz = shieldPos[3] - point[2]
            local distSq = dx * dx + dz * dz  -- Squared distance
    
            if distSq <= shieldRadiusSq then
                coveredPoints = coveredPoints + 1
                -- If at least 3 corners are covered, we can return early
                if coveredPoints >= 3 then
                    return true
                end
            end
        end
    
        return false
    end

    local defenseRadiusSq = GetShieldRadiusAboveGroundSquaredRNG(finishedUnit)
    local finishedUnitPos = finishedUnit:GetPosition()
    local units = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE, finishedUnitPos, math.sqrt(defenseRadiusSq), 'Ally')

    if not table.empty(units) then
        for _, v in units do
            if v and not v.Dead then
                local unitPos = v:GetPosition()
                local unitSizeX = v.Blueprint.SizeX or 1
                local unitSizeZ = v.Blueprint.SizeZ or 1

                if IsUnitCoveredByShield(unitPos, unitSizeX, unitSizeZ, finishedUnitPos, defenseRadiusSq) then
                    if not v['rngdata'] then
                        v['rngdata'] = {}
                    end
                    if not v['rngdata'].ShieldsInRange then
                        v['rngdata'].ShieldsInRange = setmetatable({}, WeakValueTable)
                    end
                    v['rngdata'].ShieldsInRange[finishedUnit.EntityId] = finishedUnit
                    finishedUnit['rngdata']['UnitsDefended'][v.EntityId] = v
                end
            end
        end
    end
end

function CalculateThreatWithDynamicDecay(aiBrain, baseName, layer, baseZoneId, maxDistance, minAmplifyDistance, maxAmplifyDistance, amplifyFactor, decayFactor)
    local threatData = { landthreat = 0, land = {}, airthreat = 0, air = {}, navalthreat = 0, naval = {}}
    local zones
    local pathableZones = aiBrain.BuilderManagers[baseName].PathableZones.Zones

    if layer == 'Water' then
        zones = aiBrain.Zones.Naval.zones
    else
        zones = aiBrain.Zones.Land.zones
    end

    for _, pathableZone in ipairs(pathableZones) do
        local zoneId = pathableZone.ZoneID
        local pathDistance = pathableZone.PathDistance
        local currentZone = zones[zoneId]
        if pathDistance and currentZone and pathDistance <= maxDistance then
            local multiplier
            if pathDistance <= maxAmplifyDistance and pathDistance >= minAmplifyDistance then
                multiplier = amplifyFactor
            else
                multiplier = 1 - math.min(((pathDistance - maxAmplifyDistance) / (maxDistance - maxAmplifyDistance)) * decayFactor, 1)
            end
            local landThreat = math.ceil(((currentZone.enemylandthreat or 0) * multiplier))
            if landThreat > 0 then
                table.insert(threatData.land, { ZoneID = zoneId, Position = currentZone.pos, Threat = landThreat})
                if landThreat > threatData.landthreat then
                    threatData.landthreat = landThreat
                end
            end
            
            local airThreat = math.ceil(((currentZone.enemyairthreat or 0) * multiplier))
            if airThreat > 0 then
                table.insert(threatData.air, { ZoneID = zoneId, Position = currentZone.pos, Threat = airThreat})
                if airThreat > threatData.air then
                    threatData.airthreat = airThreat
                end
            end
            local navalThreat = math.ceil(((currentZone.enemylandthreat or 0) * multiplier))
            if navalThreat > 0 then
                table.insert(threatData.naval, { ZoneID = zoneId, Position = currentZone.pos, Threat = navalThreat})
                if navalThreat > threatData.naval then
                    threatData.navalthreat = navalThreat
                end
            end
        end
    end
    --if threatData.land > 0 then
    --    LOG('Total Land threat returned '..tostring(repr(threatData.landthreat)))
    --end
    --if threatData.air > 0 then
    --    LOG('Total Land threat returned '..tostring(repr(threatData.airthreat)))
    --end
    --if threatData.naval > 0 then
    --    LOG('Total Land threat returned '..tostring(repr(threatData.navalthreat)))
    --end
    return threatData
end

-- Used for Campaign where there is no start position available
function CalculatePotentialBrainStartPosition(aiBrain, otherBrain)
    local numberOfHqs = 0
    local furtherestHq
    local furtherestDistance
    local aiStartPos = aiBrain.BrainIntel.StartPos
    local hqStructures = otherBrain:GetListOfUnits(categories.STRUCTURE * categories.FACTORY * categories.TECH3 * (categories.AIR + categories.LAND) - categories.SUPPORTFACTORY, false)
    for _, v in hqStructures do
        numberOfHqs = numberOfHqs + 1
        local hqPos = v:GetPosition()
        local dx = aiStartPos[1] - hqPos[1]
        local dz = aiStartPos[3] - hqPos[3]
        local distanceToMain = dx * dx + dz * dz
        if not furtherestDistance or distanceToMain > furtherestDistance then
            furtherestDistance = distanceToMain
            furtherestHq = hqPos
        end
    end
    return furtherestHq
end

function GetCurrentRole(aiBrain)
    for k, v in pairs(aiBrain.BrainIntel.PlayerRole) do
        if v == true then
            return k
        end
    end
end

function SetCurrentRole(aiBrain, newRole)
    -- Ensure all roles are set to false
    for k, _ in aiBrain.BrainIntel.PlayerRole do
        aiBrain.BrainIntel.PlayerRole[k] = false
    end
    -- Set the new role to true
    aiBrain.BrainIntel.PlayerRole[newRole] = true
end

function GetPoolCountAtLocation(aiBrain, locationType, unitCategory)
    local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
    local testCat = unitCategory
    if not engineerManager then
        WARN('*AI WARNING: HavePoolUnitComparisonAtLocation - Invalid location - ' .. locationType)
        return false
    end
    local poolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
    local numUnits = poolPlatoon:GetNumCategoryUnits(testCat, engineerManager:GetLocationCoords(), engineerManager.Radius)
    return numUnits
end

function ValidateFactoryManager(aiBrain, locationType, layer, unit)
    local locationRadius
    local graphArea
    local unitPos = unit:GetPosition()
    local friendlyLocation
    local markerType
    if layer == 'Water' then
        locationRadius = 70
        graphArea = NavUtils.GetLabel('Water', unitPos)
        markerType = 'Naval Area'
    else
        locationRadius = 120
        graphArea = NavUtils.GetLabel('Land', unitPos)
        markerType = 'Zone Expansion'
    end
    local friendlyBaseClose = false
    if not aiBrain.BuilderManagers[locationType] then
        --LOG('Validate factory manager for unit')
        for k, v in aiBrain.BuilderManagers do
            if layer == 'Water' and v.Layer ~= 'Water' then
                continue
            end
            if v.GraphArea ==  graphArea then
                local rx = v.Position[1] - unitPos[1]
                local rz = v.Position[3] - unitPos[3]
                local baseDistance = rx * rx + rz * rz
                if baseDistance < locationRadius * locationRadius then
                    friendlyBaseClose = true
                    friendlyLocation = k
                    break
                end
            end
        end
        if not friendlyBaseClose then
            --LOG('No friendly base within radius, attempting to add new builder managers for unit')
            aiBrain:AddBuilderManagers(unitPos, locationRadius, locationType, false)
            local baseValues = {}
            local highPri = false
            for templateName, baseData in BaseBuilderTemplates do
                local baseValue = baseData.ExpansionFunction(aiBrain, unitPos, markerType)
                table.insert(baseValues, { Base = templateName, Value = baseValue })
                --SPEW('*AI DEBUG: AINewExpansionBase(): Scann next Base. baseValue= ' .. tostring(baseValue) .. ' ('..tostring(templateName)..')')
                if not highPri or baseValue > highPri then
                    --SPEW('*AI DEBUG: AINewExpansionBase(): Possible next Base. baseValue= ' .. tostring(baseValue) .. ' ('..tostring(templateName)..')')
                    highPri = baseValue
                end
            end
            local validNames = {}
            for k,v in baseValues do
                if v.Value == highPri then
                    table.insert(validNames, v.Base)
                end
            end
            local pick = validNames[ Random(1, table.getn(validNames)) ]
            --LOG('Base pick is '..tostring(pick))
            import('/mods/RNGAI/lua/ai/aiaddbuildertable.lua').AddGlobalBaseTemplate(aiBrain, locationType, pick)
            local factoryManager = aiBrain.BuilderManagers[locationType].FactoryManager
            factoryManager:AddFactory(unit)
        else
            local factoryManager = aiBrain.BuilderManagers[friendlyLocation].FactoryManager
            if factoryManager then
                --LOG('friendly base within radius, attempting to add factory to base')
                factoryManager:AddFactory(unit)
            end
        end
    end
end

-- This function is triggered when an acu is seen as enhancing it will validate if its a gun upgrade
-- This functionality is designed to mimic a humans ability to see which slot an acu is upgrading via the visual enhancement indicator
function ValidateEnhancingUnit(unit)
    if unit.WorkItem then
        local enhancementBp = unit.WorkItem
        local isCombatType = enhancementBp.NewRoF or enhancementBp.NewMaxRadius or enhancementBp.NewRateOfFire or enhancementBp.NewRadius 
            or enhancementBp.NewDamage or enhancementBp.DamageMod or enhancementBp.ZephyrDamageMod
        if isCombatType and not unit['rngdata']['IsUpgradingGun'] then
            if not unit['rngdata'] then
                unit['rngdata'] = {}
            end
            unit['rngdata']['IsUpgradingGun'] = true
            --LOG('Unit detected as upgrading gun')
        end
    end
end

-- Tries to find a decent place for a mobile experimental unit.
function GetMobileLandExperimentalBuildPosition(aiBrain, basePos, radius, engPos)
    -- Fallback enemy base position
    local enemyBasePos = aiBrain.EnemyIntel and aiBrain.EnemyIntel.EnemyBasePosition or false

    -- Get team enemy average position or fallback to map center
    local teamAveragePositions = aiBrain.IntelManager:GetTeamAveragePositions()
    local teamEnemyAveragePosition = (teamAveragePositions['Enemy'].x and teamAveragePositions['Enemy'].z) and {
        teamAveragePositions['Enemy'].x,
        GetSurfaceHeight(teamAveragePositions['Enemy'].x, teamAveragePositions['Enemy'].z),
        teamAveragePositions['Enemy'].z
    } or aiBrain.MapCenterPoint

    -- Find own shields around the base
    local shields = AIUtils.GetOwnUnitsAroundPoint(aiBrain, categories.SHIELD * categories.STRUCTURE, basePos, radius or 60)

    local candidates = {}
    if not shields or table.empty(shields) == 0 then
        return GetGenericMobileExperimentalBuildPosition(aiBrain, basePos, radius, engPos)
    end

    for _, shield in shields do
        local shieldPos = shield:GetPosition()
        local bp = shield.Blueprint
        local shieldSize = (bp.Defense.Shield and bp.Defense.Shield.ShieldSize * 0.35) or 5
        local range = math.max(shieldSize * 0.5 + 5, 8)
        local offsets = DrawCirclePoints(8, shieldSize + 6, shieldPos)

        for _, offset in offsets do
            local distFromBase = VDist3Sq(offset, basePos)
            if distFromBase < 625 or distFromBase > 2025 then continue end

            local energyNearby = aiBrain:GetNumUnitsAroundPoint(categories.ENERGYPRODUCTION, offset, 8, 'Ally')
            if energyNearby > 0 then continue end

            -- Check enemy proximity bias
            local toEnemy = VDist2Sq(shieldPos[1], shieldPos[3], teamEnemyAveragePosition[1], teamEnemyAveragePosition[3])
            local toOffset = VDist2Sq(offset[1], offset[3], teamEnemyAveragePosition[1], teamEnemyAveragePosition[3])
            if toOffset < toEnemy then continue end

            -- Score based on proximity to engineer and base
            local distToEngineer = VDist3Sq(offset, engPos)
            local distToBase = VDist3Sq(offset, basePos)
            local score = distToEngineer + (distToBase * 0.5)

            table.insert(candidates, {
                pos = offset,
                score = score
            })
        end
    end

    if not table.empty(candidates) then
        table.sort(candidates, function(a, b)
            return a.score < b.score
        end)
        --LOG('Returning cadidate pos of '..tostring(repr(candidates[1].pos)))
        return candidates[1].pos
    end

    -- Fallback if no good spot found
    --LOG('Fallback to generic position')
    return GetGenericMobileExperimentalBuildPosition(aiBrain, basePos, radius, engPos)
end

function GetGenericMobileExperimentalBuildPosition(aiBrain, basePos, enemyPos)
    local maxDistanceFromBase = 65  -- maximum distance from base to place experimental
    local searchRadius = 30         -- radius to use for initial circular candidate search
    local safeMinDistFromEnergy = 8

    local enemyBasePos = aiBrain.EnemyIntel and aiBrain.EnemyIntel.EnemyBasePosition or false
    local teamAveragePositions = aiBrain.IntelManager:GetTeamAveragePositions()
    local teamEnemyAveragePosition = (teamAveragePositions['Enemy'].x and teamAveragePositions['Enemy'].z) and {
        teamAveragePositions['Enemy'].x,
        GetSurfaceHeight(teamAveragePositions['Enemy'].x, teamAveragePositions['Enemy'].z),
        teamAveragePositions['Enemy'].z
    } or aiBrain.MapCenterPoint

    local candidates = DrawCirclePoints(12, searchRadius, basePos)

    for _, pos in candidates do
        -- Check it's within max allowed distance from base
        if VDist2(pos[1], pos[3], basePos[1], basePos[3]) > maxDistanceFromBase then
            continue
        end

        -- Prefer positions not toward enemy
        if enemyPos then
            local baseToEnemy = VDist2Sq(basePos[1], basePos[3], teamEnemyAveragePosition[1], teamEnemyAveragePosition[3])
            local posToEnemy = VDist2Sq(pos[1], pos[3], teamEnemyAveragePosition[1], teamEnemyAveragePosition[3])
            if posToEnemy < baseToEnemy then
                continue
            end
        end

        local energyNearby = aiBrain:GetNumUnitsAroundPoint(categories.ENERGYPRODUCTION, pos, safeMinDistFromEnergy, 'Ally')
        if energyNearby == 0 then
            --LOG('Return enemy not nearby pos ' .. repr(pos))
            return pos
        end
    end

    -- Fallback: pick a point directly away from enemy, but clamp within max distance
    if enemyPos then
        local dx = basePos[1] - enemyPos[1]
        local dz = basePos[3] - enemyPos[3]
        local norm = math.sqrt(dx * dx + dz * dz)
        if norm == 0 then norm = 1 end
        local clampedOffset = math.min(maxDistanceFromBase, 30)
        local offset = {
            basePos[1] + (dx / norm) * clampedOffset,
            0,
            basePos[3] + (dz / norm) * clampedOffset,
        }
        --LOG('Returning fallback candidate pos (clamped) of ' .. repr(offset))
        return offset
    end

    -- Absolute fallback: offset in safe direction, still within bounds
    local fallback = {
        basePos[1] + math.min(maxDistanceFromBase, 20),
        0,
        basePos[3] + math.min(maxDistanceFromBase, 20),
    }
    --LOG('Absolute fallback ' .. repr(fallback))
    return fallback
end
