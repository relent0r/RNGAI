
function AIGetMarkerLocationsNotFriendly(aiBrain, markerType)
    local markerList = {}
    --LOG('* AI-RNG: Marker Type for AIGetMarkerLocationsNotFriendly is '..markerType)
    if markerType == 'Start Location' then
        local tempMarkers = AIGetMarkerLocations(aiBrain, 'Blank Marker')
        for k, v in tempMarkers do
            if string.sub(v.Name, 1, 5) == 'ARMY_' then
                local ecoStructures = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE * (categories.MASSEXTRACTION + categories.MASSPRODUCTION), v.Position, 30, 'Ally')
                local GetBlueprint = moho.entity_methods.GetBlueprint
                local ecoThreat = 0
                for _, v in ecoStructures do
                    local bp = v:GetBlueprint()
                    local ecoStructThreat = bp.Defense.EconomyThreatLevel
                    --LOG('* AI-RNG: Eco Structure'..ecoStructThreat)
                    ecoThreat = ecoThreat + ecoStructThreat
                end
                if ecoThreat < 10 then
                    table.insert(markerList, {Position = v.Position, Name = v.Name})
                end
            end
        end
    else
        local markers = ScenarioUtils.GetMarkers()
        if markers then
            for k, v in markers do
                if v.type == markerType then
                    table.insert(markerList, {Position = v.Position, Name = k})
                end
            end
        end
    end
    return markerList
end

function UseTransports(units, transports, location, transportPlatoon)
    local aiBrain
    for k, v in units do
        if not v.Dead then
            aiBrain = v:GetAIBrain()
            break
        end
    end

    if not aiBrain then
        return false
    end

    -- Load transports
    local transportTable = {}
    local transSlotTable = {}
    if not transports then
        return false
    end

    IssueClearCommands(transports)

    for num, unit in transports do
        local id = unit.UnitId
        if not transSlotTable[id] then
            transSlotTable[id] = GetNumTransportSlots(unit)
        end
        table.insert(transportTable,
            {
                Transport = unit,
                LargeSlots = transSlotTable[id].Large,
                MediumSlots = transSlotTable[id].Medium,
                SmallSlots = transSlotTable[id].Small,
                Units = {}
            }
        )
    end

    local shields = {}
    local remainingSize3 = {}
    local remainingSize2 = {}
    local remainingSize1 = {}
    local pool = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
    for num, unit in units do
        if not unit.Dead then
            if unit:IsUnitState('Attached') then
                aiBrain:AssignUnitsToPlatoon(pool, {unit}, 'Unassigned', 'None')
            elseif EntityCategoryContains(categories.url0306 + categories.DEFENSE, unit) then
                table.insert(shields, unit)
            elseif unit:GetBlueprint().Transport.TransportClass == 3 then
                table.insert(remainingSize3, unit)
            elseif unit:GetBlueprint().Transport.TransportClass == 2 then
                table.insert(remainingSize2, unit)
            elseif unit:GetBlueprint().Transport.TransportClass == 1 then
                table.insert(remainingSize1, unit)
            else
                table.insert(remainingSize1, unit)
            end
        end
    end

    local needed = GetNumTransports(units)
    local largeHave = 0
    for num, data in transportTable do
        largeHave = largeHave + data.LargeSlots
    end

    local leftoverUnits = {}
    local currLeftovers = {}
    local leftoverShields = {}
    transportTable, leftoverShields = SortUnitsOnTransports(transportTable, shields, largeHave - needed.Large)

    transportTable, leftoverUnits = SortUnitsOnTransports(transportTable, remainingSize3, -1)

    transportTable, currLeftovers = SortUnitsOnTransports(transportTable, leftoverShields, -1)

    for _, v in currLeftovers do table.insert(leftoverUnits, v) end
    transportTable, currLeftovers = SortUnitsOnTransports(transportTable, remainingSize2, -1)

    for _, v in currLeftovers do table.insert(leftoverUnits, v) end
    transportTable, currLeftovers = SortUnitsOnTransports(transportTable, remainingSize1, -1)

    for _, v in currLeftovers do table.insert(leftoverUnits, v) end
    transportTable, currLeftovers = SortUnitsOnTransports(transportTable, currLeftovers, -1)

    aiBrain:AssignUnitsToPlatoon(pool, currLeftovers, 'Unassigned', 'None')
    if transportPlatoon then
        transportPlatoon.UsingTransport = true
    end

    local monitorUnits = {}
    for num, data in transportTable do
        if table.getn(data.Units) > 0 then
            IssueClearCommands(data.Units)
            IssueTransportLoad(data.Units, data.Transport)
            for k, v in data.Units do table.insert(monitorUnits, v) end
        end
    end

    local attached = true
    repeat
        WaitSeconds(2)
        local allDead = true
        local transDead = true
        for k, v in units do
            if not v.Dead then
                allDead = false
                break
            end
        end
        for k, v in transports do
            if not v.Dead then
                transDead = false
                break
            end
        end
        if allDead or transDead then return false end
        attached = true
        for k, v in monitorUnits do
            if not v.Dead and not v:IsIdleState() then
                attached = false
                break
            end
        end
    until attached

    -- Any units that aren't transports and aren't attached send back to pool
    for k, unit in units do
        if not unit.Dead and not EntityCategoryContains(categories.TRANSPORTATION, unit) then
            if not unit:IsUnitState('Attached') then
                aiBrain:AssignUnitsToPlatoon(pool, {unit}, 'Unassigned', 'None')
            end
        elseif not unit.Dead and EntityCategoryContains(categories.TRANSPORTATION, unit) and table.getn(unit:GetCargo()) < 1 then
            ReturnTransportsToPool({unit}, true)
            table.remove(transports, k)
        end
    end

    -- If some transports have no units return to pool
    for k, t in transports do
        if not t.Dead and table.getn(t:GetCargo()) < 1 then
            aiBrain:AssignUnitsToPlatoon('ArmyPool', {t}, 'Scout', 'None')
            table.remove(transports, k)
        end
    end

    if table.getn(transports) ~= 0 then
        -- If no location then we have loaded transports then return true
        if location then
            local safePath = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, 'Air', transports[1]:GetPosition(), location, 200)
            if safePath then
                for _, p in safePath do
                    IssueMove(transports, p)
                end
            end
        else
            return true
        end
    else
        -- If no transports return false
        return false
    end

    -- Adding Surface Height, so thetransporter get not confused, because the target is under the map (reduces unload time)
    location = {location[1], GetSurfaceHeight(location[1],location[3]), location[3]}
    IssueTransportUnload(transports, location)
    local attached = true
    while attached do
        WaitSeconds(2)
        local allDead = true
        for _, v in transports do
            if not v.Dead then
                allDead = false
                break
            end
        end

        if allDead then
            return false
        end

        attached = false
        for num, unit in units do
            if not unit.Dead and unit:IsUnitState('Attached') then
                attached = true
                break
            end
        end
    end

    if transportPlatoon then
        transportPlatoon.UsingTransport = false
    end
    ReturnTransportsToPool(transports, true)

    return true
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