
function CanBuildOnMassLessThanDistance(aiBrain, locationType, distance, threatMin, threatMax, threatRings, threatType, maxNum )
    local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
    if not engineerManager then
        WARN('*AI WARNING: Invalid location - ' .. locationType)
        return false
    end
    local position = engineerManager:GetLocationCoords()
    
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

