local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt
local LastGetMassMarkerRNG = 0
local LastCheckMassMarkerRNG = {}
local MassMarkerRNG = {}
local NavUtils = import('/lua/sim/NavUtils.lua')
local LastMassBOOLRNG = false
local GetMarkersRNG = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

function CanBuildOnMassMexPlatoon(aiBrain, engPos, distance)
    local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
    distance = distance * distance
    local adaptiveResourceMarkers = GetMarkersRNG()
    local MassMarker = {}
    for _, v in adaptiveResourceMarkers do
        if v.type == 'Mass' then
            if v.position[1] > playableArea[1] and v.position[1] < playableArea[3] and v.position[3] > playableArea[2] and v.position[3] < playableArea[4] then
                local mexBorderWarn = false
                if v.position[1] <= 8 or v.position[1] >= ScenarioInfo.size[1] - 8 or v.position[3] <= 8 or v.position[3] >= ScenarioInfo.size[2] - 8 then
                    mexBorderWarn = true
                end 
                local mexDistance = VDist2Sq( v.position[1],v.position[3], engPos[1], engPos[3] )
                if mexDistance < distance and CanBuildStructureAt(aiBrain, 'ueb1103', v.position) and NavUtils.CanPathTo('Amphibious', engPos, v.position) then
                    --RNGLOG('mexDistance '..mexDistance)
                    table.insert(MassMarker, {Position = v.position, Distance = mexDistance , MassSpot = v, BorderWarning = mexBorderWarn})
                end
            end
        end
    end
    table.sort(MassMarker, function(a,b) return a.Distance < b.Distance end)
    if not table.empty(MassMarker) then
        return true, MassMarker
    else
        return false
    end
end

function CanBuildOnMassEng(aiBrain, engPos, distance, threatMin, threatMax, threatRings, threatType, maxNum )
    local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
    local gameTime = GetGameTimeSeconds()
    if LastGetMassMarkerRNG < gameTime then
        LastGetMassMarkerRNG = gameTime+10
        local adaptiveResourceMarkers = GetMarkersRNG()
        MassMarkerRNG = {}
        for _, v in adaptiveResourceMarkers do
            if v.position[1] > playableArea[1] and v.position[1] < playableArea[3] and v.position[3] > playableArea[2] and v.position[3] < playableArea[4] then
                if v.type == 'Mass' then
                    table.insert(MassMarkerRNG, {Position = v.position, Distance = VDist3( v.position, engPos ) })
                end
            end
        end
        table.sort(MassMarkerRNG, function(a,b) return a.Distance < b.Distance end)
    end
    if not LastCheckMassMarkerRNG[distance] or LastCheckMassMarkerRNG[distance] < gameTime then
        LastCheckMassMarkerRNG[distance] = gameTime
        local threatCheck = false
        if threatMin and threatMax and threatRings then
            threatCheck = true
        end
        LastMassBOOLRNG = false
        for _, v in MassMarkerRNG do
            if v.Distance > distance then
                break
            end
            --RNGLOG(_..'Checking marker with max distance ['..distance..']. Actual marker has distance: ('..(v.Distance)..').')
            if CanBuildStructureAt(aiBrain, 'ueb1103', v.Position) then
                if threatCheck then
                    local threat = aiBrain:GetThreatAtPosition(v.Position, threatRings, true, threatType or 'Overall')
                    if threat <= threatMin or threat >= threatMax then
                        continue
                    end
                end
                LastMassBOOLRNG = true
                break
            end
        end
    end
    return LastMassBOOLRNG
end

function CanBuildOnMassDistanceRNG(aiBrain, locationType, minDistance, maxDistance, threatMin, threatMax, threatRings, threatType, maxNum )
    local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
    local gameTime = GetGameTimeSeconds()
    if LastGetMassMarkerRNG < gameTime then
        LastGetMassMarkerRNG = gameTime+5
        local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
        if not engineerManager then
            --WARN('*AI WARNING: CanBuildOnMass: Invalid location - ' .. locationType)
            return false
        end
        local position = engineerManager.Location
        local adaptiveResourceMarkers = GetMarkersRNG()
        MassMarkerRNG = {}
        for _, v in adaptiveResourceMarkers do
            if v.type == 'Mass' then
                if v.position[1] > playableArea[1] and v.position[1] < playableArea[3] and v.position[3] > playableArea[2] and v.position[3] < playableArea[4] then
                    table.insert(MassMarkerRNG, {Position = v.position, Distance = VDist3( v.position, position ) })
                end
            end
        end
        table.sort(MassMarkerRNG, function(a,b) return a.Distance < b.Distance end)
    end
    if not LastCheckMassMarkerRNG[maxDistance] or LastCheckMassMarkerRNG[maxDistance] < gameTime then
        LastCheckMassMarkerRNG[maxDistance] = gameTime
        local threatCheck = false
        if threatMin and threatMax and threatRings then
            threatCheck = true
        end
        LastMassBOOLRNG = false
        for _, v in MassMarkerRNG do
            if v.Distance < minDistance then
                continue
            elseif v.Distance > maxDistance then
                break
            end
            --RNGLOG(_..'Checking marker with max maxDistance ['..maxDistance..'] minDistance ['..minDistance..'] . Actual marker has distance: ('..(v.Distance)..').')
            if CanBuildStructureAt(aiBrain, 'ueb1103', v.Position) then
                if threatCheck then
                    local threat = aiBrain:GetThreatAtPosition(v.Position, threatRings, true, threatType or 'Overall')
                    if threat <= threatMin or threat >= threatMax then
                        continue
                    end
                end
                --RNGLOG('Returning MassMarkerDistance True')
                LastMassBOOLRNG = true
                break
            end
        end
    end
    return LastMassBOOLRNG
end

function MassMarkerLessThanDistanceRNG(aiBrain, distance)
    local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
    local adaptiveResourceMarkers = GetMarkersRNG()
    local startX, startZ = aiBrain:GetArmyStartPos()
    if type(distance) == 'string' then
        distance = aiBrain.OperatingAreas[distance]
    end
    for k, v in adaptiveResourceMarkers do
        if v.type == 'Mass' then
            if v.position[1] > playableArea[1] and v.position[1] < playableArea[3] and v.position[3] > playableArea[2] and v.position[3] < playableArea[4] then
                if VDist2Sq(startX, startZ, v.position[1], v.position[3]) < distance * distance then
                    --RNGLOG('Mass marker less than '..distance)
                    return true
                end
            end
        end
    end
    return false
end


