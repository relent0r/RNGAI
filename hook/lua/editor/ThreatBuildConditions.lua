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
    elseif aiBrain:PBMHasPlatoonList() then
        for k,v in aiBrain.PBM.Locations do
            if v.LocationType == locationType then
                baseposition = v.Location
                radius = v.Radius
                MAPBASEPOSTITIONSRNG[AIName] = MAPBASEPOSTITIONSRNG[AIName] or {} 
                MAPBASEPOSTITIONSRNG[AIName][locationType] = {baseposition, radius}
                break
            end
        end
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

function EnemyThreatInT3ArtilleryRangeRNG(aiBrain, locationtype, radius, ratio)
    -- This will look at all structure threat on the map and figure out what ratio exist within the radius of a T3 static artillery
    local basePos = aiBrain.BuilderManagers[locationtype].Position
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

function ThreatPresentInGraphRNG(aiBrain, locationtype, tType)
    local factoryManager = aiBrain.BuilderManagers[locationtype].FactoryManager
    if not factoryManager then
        return false
    end
    local expansionMarkers = Scenario.MasterChain._MASTERCHAIN_.Markers
    local graphArea = aiBrain.BuilderManagers[locationtype].GraphArea
    if not graphArea then
        WARN('Missing RNGArea for expansion land node or no path markers')
        return false
    end
    if expansionMarkers then
        --RNGLOG('Initial expansionMarker list is '..repr(expansionMarkers))
        for k, v in expansionMarkers do
            if v.type == 'Expansion Area' or v.type == 'Large Expansion Area' or v.type == 'Blank Marker' or v.type == 'Spawn' then
                if v.RNGArea then
                    if string.find(graphArea, v.RNGArea) then
                        local threat = GetThreatAtPosition(aiBrain, v.position, aiBrain.BrainIntel.IMAPConfig.Rings, true, tType)
                        if threat > 2 then
                            -- I had to do this because neutral civilians show up as structure threat
                            if aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE - categories.WALL, v.position, 60, 'Enemy') > 0 then
                                --RNGLOG('Number of enemy structure '..aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE - categories.WALL, v.position, 60, 'Enemy'))
                                --RNGLOG('StructuresNotMex threat present for base '..locationtype)
                                --RNGLOG('Expansion position detected is '..repr(v.position))
                                --RNGLOG('There is '..threat..' enemy structure threat on the graph area expansion markers')
                                --RNGLOG('Distance is '..VDist3(v.position, factoryManager.Location))
                                return true
                            end
                        end
                    end
                end
            end
        end
    end
    --RNGLOG('No threat in graph area')
    return false
end

function LandThreatAtBaseOwnZones(aiBrain)
    -- used for bomber response former
    if aiBrain.BasePerimeterMonitor['MAIN'].LandUnits > 0 or aiBrain.EnemyIntel.HighPriorityTargetAvailable then
        return true
    end
    return false
end
