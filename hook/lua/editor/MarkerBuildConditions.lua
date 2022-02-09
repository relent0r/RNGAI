local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt
local LastGetMassMarkerRNG = 0
local LastCheckMassMarkerRNG = {}
local MassMarkerRNG = {}
local LastMassBOOLRNG = false
local GetMarkersRNG = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG
--[[function CanBuildOnMassDistanceRNG(aiBrain, locationType, distance, threatMin, threatMax, threatRings, threatType, maxNum )
    local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
    if not engineerManager then
        --WARN('*AI WARNING: Invalid location - ' .. locationType)
        return false
    end
    local position = engineerManager.Location
    
    local markerTable = AIUtils.AIGetSortedMassLocations(aiBrain, maxNum, threatMin, threatMax, threatRings, threatType, position)
    return VDist2Sq( markerTable[1][1], markerTable[1][3], position[1], position[3] ) < distance * distance
end]]

function CanBuildOnMassEng2(aiBrain, engPos, distance)
    distance = distance * distance
    local adaptiveResourceMarkers = GetMarkersRNG()
    local MassMarker = {}
    for _, v in adaptiveResourceMarkers do
        if v.type == 'Mass' then
            local mexDistance = VDist2Sq( v.position[1],v.position[3], engPos[1], engPos[3] )
            if mexDistance < distance and CanBuildStructureAt(aiBrain, 'ueb1103', v.position) then
                --RNGLOG('mexDistance '..mexDistance)
                table.insert(MassMarker, {Position = v.position, Distance = mexDistance , MassSpot = v})
            end
        end
    end
    table.sort(MassMarker, function(a,b) return a.Distance < b.Distance end)
    if table.getn(MassMarker) > 0 then
        return true, MassMarker
    else
        return false
    end
end

function CanBuildOnMassMexPlatoon(aiBrain, engPos, distance)
    distance = distance * distance
    local adaptiveResourceMarkers = GetMarkersRNG()
    local MassMarker = {}
    for _, v in adaptiveResourceMarkers do
        if v.type == 'Mass' then
            local mexBorderWarn = false
            if v.position[1] <= 8 or v.position[1] >= ScenarioInfo.size[1] - 8 or v.position[3] <= 8 or v.position[3] >= ScenarioInfo.size[2] - 8 then
                mexBorderWarn = true
            end 
            local mexDistance = VDist2Sq( v.position[1],v.position[3], engPos[1], engPos[3] )
            if mexDistance < distance and CanBuildStructureAt(aiBrain, 'ueb1103', v.position) then
                --RNGLOG('mexDistance '..mexDistance)
                table.insert(MassMarker, {Position = v.position, Distance = mexDistance , MassSpot = v, BorderWarning = mexBorderWarn})
            end
        end
    end
    table.sort(MassMarker, function(a,b) return a.Distance < b.Distance end)
    if table.getn(MassMarker) > 0 then
        return true, MassMarker
    else
        return false
    end
end

function CanBuildOnMassEng(aiBrain, engPos, distance, threatMin, threatMax, threatRings, threatType, maxNum )
    if LastGetMassMarkerRNG < GetGameTimeSeconds() then
        LastGetMassMarkerRNG = GetGameTimeSeconds()+10
        local adaptiveResourceMarkers = GetMarkersRNG()
        MassMarkerRNG = {}
        for _, v in adaptiveResourceMarkers do
            if v.type == 'Mass' then
                table.insert(MassMarkerRNG, {Position = v.position, Distance = VDist3( v.position, engPos ) })
            end
        end
        table.sort(MassMarkerRNG, function(a,b) return a.Distance < b.Distance end)
    end
    if not LastCheckMassMarkerRNG[distance] or LastCheckMassMarkerRNG[distance] < GetGameTimeSeconds() then
        LastCheckMassMarkerRNG[distance] = GetGameTimeSeconds()
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
                    threat = aiBrain:GetThreatAtPosition(v.Position, threatRings, true, threatType or 'Overall')
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
    if LastGetMassMarkerRNG < GetGameTimeSeconds() then
        LastGetMassMarkerRNG = GetGameTimeSeconds()+5
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
                table.insert(MassMarkerRNG, {Position = v.position, Distance = VDist3( v.position, position ) })
            end
        end
        table.sort(MassMarkerRNG, function(a,b) return a.Distance < b.Distance end)
    end
    if not LastCheckMassMarkerRNG[maxDistance] or LastCheckMassMarkerRNG[maxDistance] < GetGameTimeSeconds() then
        LastCheckMassMarkerRNG[maxDistance] = GetGameTimeSeconds()
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
                    threat = aiBrain:GetThreatAtPosition(v.Position, threatRings, true, threatType or 'Overall')
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
    local adaptiveResourceMarkers = GetMarkersRNG()
    local startX, startZ = aiBrain:GetArmyStartPos()
    for k, v in adaptiveResourceMarkers do
        if v.type == 'Mass' then
            if VDist2Sq(startX, startZ, v.position[1], v.position[3]) < distance * distance then
                --RNGLOG('Mass marker less than '..distance)
                return true
            end
        end
    end
    return false
end


