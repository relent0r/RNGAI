
function AIGetMarkerLocationsNotFriendly(aiBrain, markerType)
    local markerList = {}
    --LOG('Marker Type for AIGetMarkerLocationsNotFriendly is '..markerType)
    if markerType == 'Start Location' then
        local tempMarkers = AIGetMarkerLocations(aiBrain, 'Blank Marker')
        for k, v in tempMarkers do
            if string.sub(v.Name, 1, 5) == 'ARMY_' then
                local myThreat = aiBrain:GetThreatAtPosition(v.position, 0, true, 'StructuresNotMex', self:GetArmyIndex())
                --LOG('Friendly threat at '..v.position..' has value of '..myThreat)
                if myThreat < 10 then
                    table.insert(markerList, {Position = v.Position, Name = v.Name})
                end
            end
        end
    else
        local markers = ScenarioUtils.GetMarkers()
        if markers then
            for k, v in markers do
                if v.type == markerType then
                    table.insert(markerList, {Position = v.position, Name = k})
                end
            end
        end
    end
    return markerList
end

function RandomLocation(x, z)
    local finalX = x + Random(-30, 30)
    while finalX <= 0 or finalX >= ScenarioInfo.size[1] do
        finalX = x + Random(-30, 30)
    end

    local finalZ = z + Random(-30, 30)
    while finalZ <= 0 or finalZ >= ScenarioInfo.size[2] do
        finalZ = z + Random(-30, 30)
    end

    local movePos = {finalX, 0, finalZ}
    local height = GetTerrainHeight(movePos[1], movePos[3])
    if GetSurfaceHeight(movePos[1], movePos[3]) > height then
        height = GetSurfaceHeight(movePos[1], movePos[3])
    end
    movePos[2] = height

    return movePos
end