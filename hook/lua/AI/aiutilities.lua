
function AIGetMarkerLocationsNotFriendly(aiBrain, markerType)
    local markerList = {}
    LOG('Marker Type for AIGetMarkerLocationsNotFriendly is '..markerType)
    if markerType == 'Start Location' then
        local tempMarkers = AIGetMarkerLocations(aiBrain, 'Blank Marker')
        for k, v in tempMarkers do
            if string.sub(v.Name, 1, 5) == 'ARMY_' then
                local myThreat = aiBrain:GetThreatAtPosition(v.position, 0, true, 'StructuresNotMex', self:GetArmyIndex())
                LOG('Friendly threat at '..v.position..' has value of '..myThreat)
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