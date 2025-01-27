local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt
local LastGetMassMarkerRNG = 0
local LastCheckMassMarkerRNG = {}
local MassMarkerRNG = {}
local NavUtils = import('/lua/sim/NavUtils.lua')
local LastMassBOOLRNG = false
local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()
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
        local amphibGraphArea = aiBrain.BuilderManagers[locationType].AmphibGraphArea
        local adaptiveResourceMarkers = GetMarkersRNG()
        local noTransportsAvailable
        if locationType ~= 'FLOATING' then
            noTransportsAvailable = aiBrain.TransportPool and table.getn(aiBrain.TransportPool) < 1
        end
        MassMarkerRNG = {}
        for _, v in adaptiveResourceMarkers do
            if v.type == 'Mass' then
                if noTransportsAvailable and amphibGraphArea ~= v.AmphibGraphArea then
                    continue 
                end
                    if v.position[1] > playableArea[1] and v.position[1] < playableArea[3] and v.position[3] > playableArea[2] and v.position[3] < playableArea[4] then
                    table.insert(MassMarkerRNG, {Position = v.position, Distance = VDist3Sq( v.position, position ) })
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
            if v.Distance < minDistance * minDistance then
                continue
            elseif v.Distance > maxDistance * maxDistance then
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

function CanBuildMassInZoneEdgeRNG(aiBrain, locationType, falseBool)

    -- Determine the zone of the given position
    local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
    if not engineerManager then
        --WARN('*AI WARNING: CanBuildOnMass: Invalid location - ' .. locationType)
        return false
    end
    local zoneMaxDistance = math.min(80, math.max(50, math.max(ScenarioInfo.size[1] - 40, ScenarioInfo.size[2] - 40) / 4))
    local position = engineerManager.Location
    local zoneId = MAP:GetZoneID(position, aiBrain.Zones.Land.index)
    local currentZone = aiBrain.Zones.Land.zones[zoneId]

    if not currentZone or not currentZone.resourcemarkers then
        WARN('AI-RNG : No zone found for engineer manager position or no resource markers')
        return false-- No zone found for this position
    end

    -- Function to evaluate a zone
    local function evaluateZone(zone, basePosition)
        local dx = basePosition[1] - zone.pos[1]
        local dz = basePosition[3] - zone.pos[3]
        local distance = dx * dx + dz * dz -- Squared distance for efficiency
    
        -- Check if this zone is better based on the criteria
        if distance < zoneMaxDistance * zoneMaxDistance then
            for _, res in zone.resourcemarkers do
                if aiBrain:CanBuildStructureAt('ueb1103', res.position) then
                    return true
                end
            end
        end
    end

    -- Evaluate the current zone
    local canBuildOnMass = evaluateZone(currentZone, position)
    if falseBool and canBuildOnMass then
        return false
    elseif canBuildOnMass then
        return true
    end

    -- Evaluate neighboring zones through edges
    for _, edge in ipairs(currentZone.edges or {}) do
        local neighborZone = edge.zone
        if neighborZone then
            local canBuildOnMassEdge = evaluateZone(neighborZone, position)
            if falseBool and canBuildOnMassEdge then
                return false
            elseif canBuildOnMassEdge then
                return true
            end
        end
    end
    if falseBool then
        return true
    else
        return false
    end
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

function CanBuildOnZoneDistanceRNG(aiBrain, locationType, minDistance, maxDistance, threatMin, threatMax, threatRings, threatType)
    if not aiBrain.ZonesInitialized then
        return false
    end
    local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
    local locationPosition = engineerManager.Location
    if not engineerManager then
        --WARN('*AI WARNING: CanBuildOnMass: Invalid location - ' .. locationType)
        return false
    end
    local zoneMarkers = {}
    local threatCheck = false
    if threatMin and threatMax and threatRings then
        threatCheck = true
    end
    for _, v in aiBrain.Zones.Land.zones do
        if v.resourcevalue > 0 then
            local zx = locationPosition[1] - v.pos[1]
            local zz = locationPosition[3] - v.pos[3]
            local zoneDistance = zx * zx + zz * zz
            if zoneDistance <= maxDistance and zoneDistance >= minDistance then
                table.insert(zoneMarkers, { Position = v.pos, ResourceMarkers = table.copy(v.resourcemarkers), ResourceValue = v.resourcevalue, ZoneID = v.id })
            end
        end
    end
    for _, v in aiBrain.Zones.Naval.zones do
        --LOG('Inserting zone data position '..repr(v.pos)..' resource markers '..repr(v.resourcemarkers)..' resourcevalue '..repr(v.resourcevalue)..' zone id '..repr(v.id))
        if v.resourcevalue > 0 then
            local zx = locationPosition[1] - v.pos[1]
            local zz = locationPosition[3] - v.pos[3]
            local zoneDistance = zx * zx + zz * zz
            if zoneDistance <= maxDistance and zoneDistance >= minDistance then
                table.insert(zoneMarkers, { Position = v.pos, ResourceMarkers = table.copy(v.resourcemarkers), ResourceValue = v.resourcevalue, ZoneID = v.id })
            end
            table.insert(zoneMarkers, { Position = v.pos, ResourceMarkers = table.copy(v.resourcemarkers), ResourceValue = v.resourcevalue, ZoneID = v.id })
        end
    end
    local zoneFound = false
    for _,v in zoneMarkers do
        if threatCheck then
            local threat = aiBrain:GetThreatAtPosition(v.Position, threatRings, true, threatType or 'Overall')
            if threat <= threatMin or threat >= threatMax then
                continue
            end
        end
        for _, m in v.ResourceMarkers do
            if aiBrain:CanBuildStructureAt('ueb1103', m.position) then
                zoneFound = true
                break
            end
        end
        if zoneFound then
            break
        end
    end
end
