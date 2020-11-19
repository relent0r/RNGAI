
local LastGetMassMarker = 0
local LastCheckMassMarker = {}
local MassMarker = {}
local LastMassBOOL = false

function CanBuildOnMassLessThanDistance(aiBrain, locationType, distance, threatMin, threatMax, threatRings, threatType, maxNum )
    local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
    if not engineerManager then
        --WARN('*AI WARNING: Invalid location - ' .. locationType)
        return false
    end
    local position = engineerManager.Location
    
    local markerTable = AIUtils.AIGetSortedMassLocations(aiBrain, maxNum, threatMin, threatMax, threatRings, threatType, position)
    positionThreat = aiBrain:GetThreatAtPosition( position, threatRings, true, threatType or 'Overall' )
    if positionThreat > threatMax then
        --LOG('Mass Build at distance :'..distance)
        --LOG('Threat at position :'..positionThreat)
    end
    if markerTable[1] and VDist3( markerTable[1], position ) < distance then
        local dist = VDist3( markerTable[1], position )
        return true
    end
    return false
end

function CanBuildOnMassEng2(aiBrain, engPos, distance, threatMin, threatMax, threatRings, threatType, maxNum )
    local MassMarker = {}
    local threatCheck = true
    for _, v in Scenario.MasterChain._MASTERCHAIN_.Markers do
        if v.type == 'Mass' then
            if v.position[1] <= 8 or v.position[1] >= ScenarioInfo.size[1] - 8 or v.position[3] <= 8 or v.position[3] >= ScenarioInfo.size[2] - 8 then
                -- mass marker is too close to border, skip it.
                continue
            end 
            table.insert(MassMarker, {Position = v.position, Distance = VDist3( v.position, engPos ) })
        end
    end
    table.sort(MassMarker, function(a,b) return a.Distance < b.Distance end)
    LastMassBOOL = false
    for _, v in MassMarker do
        if v.Distance > distance then
            break
        end
        --LOG(_..'Checking marker with max distance ['..distance..']. Actual marker has distance: ('..(v.Distance)..').')
        if aiBrain:CanBuildStructureAt('ueb1103', v.Position) then
            if threatCheck then
                threat = aiBrain:GetThreatAtPosition(v.Position, threatRings, true, threatType or 'Overall')
                if threat < threatMin or threat > threatMax then
                    continue
                end
            end
            LastMassBOOL = true
            break
        end
    end
    return LastMassBOOL
end

function CanBuildOnMassEng(aiBrain, engPos, distance, threatMin, threatMax, threatRings, threatType, maxNum )
    if LastGetMassMarker < GetGameTimeSeconds() then
        LastGetMassMarker = GetGameTimeSeconds()+10
        MassMarker = {}
        for _, v in Scenario.MasterChain._MASTERCHAIN_.Markers do
            if v.type == 'Mass' then
                if v.position[1] <= 8 or v.position[1] >= ScenarioInfo.size[1] - 8 or v.position[3] <= 8 or v.position[3] >= ScenarioInfo.size[2] - 8 then
                    -- mass marker is too close to border, skip it.
                    continue
                end 
                table.insert(MassMarker, {Position = v.position, Distance = VDist3( v.position, engPos ) })
            end
        end
        table.sort(MassMarker, function(a,b) return a.Distance < b.Distance end)
    end
    if not LastCheckMassMarker[distance] or LastCheckMassMarker[distance] < GetGameTimeSeconds() then
        LastCheckMassMarker[distance] = GetGameTimeSeconds()
        local threatCheck = false
        if threatMin and threatMax and threatRings then
            threatCheck = true
        end
        LastMassBOOL = false
        for _, v in MassMarker do
            if v.Distance > distance then
                break
            end
            --LOG(_..'Checking marker with max distance ['..distance..']. Actual marker has distance: ('..(v.Distance)..').')
            if aiBrain:CanBuildStructureAt('ueb1103', v.Position) then
                if threatCheck then
                    threat = aiBrain:GetThreatAtPosition(v.Position, threatRings, true, threatType or 'Overall')
                    if threat < threatMin or threat > threatMax then
                        continue
                    end
                end
                LastMassBOOL = true
                break
            end
        end
    end
    return LastMassBOOL
end



