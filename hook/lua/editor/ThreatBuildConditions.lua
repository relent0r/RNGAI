--[[
    File    :   /lua/AI/AIBaseTemplates/ThreatBuildConditions.lua
    Author  :   relentless
    Summary :
        Threat Build Conditions
]]
local MAPBASEPOSTITIONSRNG = {}
local AIUtils = import('/lua/ai/AIUtilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

function EnemyThreatGreaterThanValueAtBaseRNG(aiBrain, locationType, threatValue, threatType, rings, builder)
    local testRings = rings or 10
    local AIName = ArmyBrains[aiBrain:GetArmyIndex()].Nickname
    local baseposition, radius
    if MAPBASEPOSTITIONSRNG[AIName][locationType] then
        baseposition = MAPBASEPOSTITIONSRNG[AIName][locationType].Pos
        radius = MAPBASEPOSTITIONSRNG[AIName][locationType].Rad
    elseif aiBrain.BuilderManagers[locationType] then
        baseposition = aiBrain.BuilderManagers[locationType].FactoryManager.Location
        radius = aiBrain.BuilderManagers[locationType].FactoryManager:GetLocationRadius()
        MAPBASEPOSTITIONSRNG[AIName] = MAPBASEPOSTITIONSRNG[AIName] or {} 
        MAPBASEPOSTITIONSRNG[AIName][locationType] = {Pos=baseposition, Rad=radius}
    end
    if not baseposition then
        return false
    end
    local currentThreat = aiBrain:GetThreatAtPosition( baseposition, testRings, true, threatType or 'Overall' )
    --RNGLOG('Threat Value Detected :'..currentThreat..'Threat Value Desired'..threatValue)
    if currentThreat > threatValue then
        --RNGLOG('EnemyThreatGreaterThanValueAtBase returning true for : ', builder)
        return true
    end
    --RNGLOG('EnemyThreatGreaterThanValueAtBase returning false for : ', builder)
    return false
end

-- not in use
function EnemyThreatGreaterThanAI(aiBrain, threatType)
    local enemyThreat
    local aiThreat
    if threatType == 'Air' then
        enemyThreat = aiBrain.EnemyIntel.EnemyThreatCurrent.Air
        aiThreat = aiBrain.BrainIntel.SelfThreat.AirNow
    elseif threatType == 'Land' then
        enemyThreat = aiBrain.EnemyIntel.EnemyThreatCurrent.Land
        aiThreat = aiBrain.BrainIntel.SelfThreat.Land
    end
    if enemyThreat > aiThreat then
        return true
    else
        return false
    end
    return false
end

function EnemyACUCloseToBase(aiBrain)

    if aiBrain.EnemyIntel.ACUEnemyClose then
        return true
    else
        return false
    end
    return false
end

function EnemyInT3ArtilleryRangeRNG(aiBrain, locationtype, inrange)
    local engineerManager = aiBrain.BuilderManagers[locationtype].EngineerManager
    if not engineerManager then
        return false
    end
    local start = engineerManager:GetLocationCoords()
    local radius = 825
    for k,v in ArmyBrains do
        if v.Status ~= "Defeat" and not ArmyIsCivilian(v:GetArmyIndex()) and IsEnemy(v:GetArmyIndex(), aiBrain:GetArmyIndex()) then
            local estartX, estartZ = v:GetArmyStartPos()
            if (VDist2Sq(start[1], start[3], estartX, estartZ) <= radius * radius) and inrange then
                return true
            elseif (VDist2Sq(start[1], start[3], estartX, estartZ) > radius * radius) and not inrange then
                return true
            end
        end
    end
    return false
end

function EnemyThreatInT3ArtilleryRangeRNG(aiBrain, locationtype, ratio)
    -- This will look at all structure threat on the map and figure out what ratio exist within the radius of a T3 static artillery
    local basePos = aiBrain.BuilderManagers[locationtype].Position
    local radius = 825 * 825
    local structureThreats = aiBrain:GetThreatsAroundPosition(basePos, 16, true, 'Economy')
    local inRangeThreat = 0
    local totalThreat = 0
    for _, v in structureThreats do
        local tx = v[1] - basePos[1]
        local tz = v[2] - basePos[3]
        local threatDistance = tx * tx + tz * tz
        if threatDistance < radius then
            inRangeThreat = inRangeThreat + v[3]
            
        end
        totalThreat = totalThreat + v[3]
    end
    if totalThreat > 0 and inRangeThreat > 0 then
        if inRangeThreat / totalThreat > ratio then
            return true
        end
    end
    return false
end

function ThreatPresentOnLabelRNG(aiBrain, locationtype, tType, ratioRequired)
    local factoryManager = aiBrain.BuilderManagers[locationtype].FactoryManager
    if not factoryManager then
        return false
    end
    local graphArea = aiBrain.BuilderManagers[locationtype].GraphArea
    if not graphArea then
        WARN('Missing GraphArea for expansion land node or no path markers')
        return false
    end
    local gameTime = GetGameTimeSeconds()
    if not table.empty(aiBrain.EnemyIntel.EnemyThreatLocations) then
        local threatTotal = 0
        for k, x in aiBrain.EnemyIntel.EnemyThreatLocations do
            for _, z in x do
                if tType == 'Defensive' then
                    if z.LandLabel == graphArea and z.LandDefStructureCount and z.LandDefStructureCount > 0 and (gameTime - z.UpdateTime) < 45 then
                        threatTotal = threatTotal + z.LandDefStructureThreat
                    end
                elseif z[tType] and z[tType] > 0 and z.LandLabel == graphArea and (gameTime - z.UpdateTime) < 45 then
                    --LOG('ThreatPresentOnLabelRNG Threat is present in graph area of type '..tType)
                    threatTotal = threatTotal + z[tType]
                end
            end
        end
        if tType == 'Air' and aiBrain.GraphZones and aiBrain.GraphZones[graphArea].FriendlyLandAntiAirThreat < threatTotal then
            return true
        end
        if tType == 'Land' and aiBrain.GraphZones and aiBrain.GraphZones[graphArea].FriendlySurfaceDirectFireThreat < threatTotal then
            return true
        end
        if tType == 'StructuresNotMex' and aiBrain.GraphZones and aiBrain.GraphZones[graphArea].FriendlySurfaceInDirectFireThreat < threatTotal then
            return true
        end
        if tType == 'Defensive' and aiBrain.GraphZones and aiBrain.GraphZones[graphArea].FriendlySurfaceInDirectFireThreat < threatTotal then
            --LOG('ThreatPresentOnLabelRNG Defensive threat found in graph for threat type '..tostring(tType))
            return true
        end
    end
    if tType == 'Air' and aiBrain.GraphZones then
        if aiBrain.EnemyIntel.EnemyThreatCurrent.AirSurface and aiBrain.GraphZones[graphArea].FriendlyLandAntiAirThreat then
            if aiBrain.EnemyIntel.EnemyThreatCurrent.AirSurface > 10 and aiBrain.GraphZones[graphArea].FriendlyLandAntiAirThreat < 10 then
                return true
            end
        end
    end
    return false
end

function LandThreatAtBaseOwnZones(aiBrain)
    -- used for bomber response former
    if aiBrain.BasePerimeterMonitor['MAIN'].LandUnits > 0 or aiBrain.EnemyIntel.HighPriorityTargetAvailable then
        return true
    end
    return false
end
