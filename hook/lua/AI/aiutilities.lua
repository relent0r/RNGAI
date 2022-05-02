local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local MABC = import('/lua/editor/MarkerBuildConditions.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG
function AIGetMarkerLocationsNotFriendly(aiBrain, markerType)
    local markerList = {}
    --RNGLOG('* AI-RNG: Marker Type for AIGetMarkerLocationsNotFriendly is '..markerType)
    if markerType == 'Start Location' then
        local tempMarkers = AIGetMarkerLocationsRNG(aiBrain, 'Blank Marker')
        for k, v in tempMarkers do
            if string.sub(v.Name, 1, 5) == 'ARMY_' then
                local ecoStructures = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE * (categories.MASSEXTRACTION + categories.MASSPRODUCTION), v.Position, 30, 'Ally')
                local GetBlueprint = moho.entity_methods.GetBlueprint
                local ecoThreat = 0
                for _, v in ecoStructures do
                    local bp = v:GetBlueprint()
                    local ecoStructThreat = bp.Defense.EconomyThreatLevel
                    --RNGLOG('* AI-RNG: Eco Structure'..ecoStructThreat)
                    ecoThreat = ecoThreat + ecoStructThreat
                end
                if ecoThreat < 10 then
                    table.insert(markerList, {Position = v.Position, Name = v.Name})
                end
            end
        end
    else
        local markers = Scenario.MasterChain._MASTERCHAIN_.Markers
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

function EngineerMoveWithSafePathRNG(aiBrain, unit, destination)
    if not destination then
        return false
    end
    local pos = unit:GetPosition()
    local T1EngOnly = false
    if EntityCategoryContains(categories.ENGINEER * categories.TECH1, unit) then
        T1EngOnly = true
    end
    -- don't check a path if we are in build range
    if VDist2(pos[1], pos[3], destination[1], destination[3]) < 12 then
        return true
    end

    -- first try to find a path with markers. 
    local result, bestPos
    local path, reason = AIAttackUtils.EngineerGenerateSafePathToRNG(aiBrain, 'Amphibious', pos, destination)
    --RNGLOG('EngineerGenerateSafePathToRNG reason is'..reason)
    -- only use CanPathTo for distance closer then 200 and if we can't path with markers
    if reason ~= 'PathOK' then
        -- we will crash the game if we use CanPathTo() on all engineer movments on a map without markers. So we don't path at all.
        if reason == 'NoGraph' then
            result = true
        elseif VDist2(pos[1], pos[3], destination[1], destination[3]) < 200 then
            SPEW('* AI-RNG: EngineerMoveWithSafePath(): executing CanPathTo(). LUA GenerateSafePathTo returned: ('..repr(reason)..') '..VDist2(pos[1], pos[3], destination[1], destination[3]))
            -- be really sure we don't try a pathing with a destoryed c-object
            if unit.Dead or unit:BeenDestroyed() or IsDestroyed(unit) then
                SPEW('* AI-RNG: Unit is death before calling CanPathTo()')
                return false
            end
            result, bestPos = unit:CanPathTo(destination)
        end 
    end
    local bUsedTransports = false
    -- Increase check to 300 for transports
    if (not result and reason ~= 'PathOK') or VDist2Sq(pos[1], pos[3], destination[1], destination[3]) > 250 * 250
    and unit.PlatoonHandle and not EntityCategoryContains(categories.COMMAND, unit) then
        -- If we can't path to our destination, we need, rather than want, transports
        local needTransports = not result and reason ~= 'PathOK'
        if VDist2Sq(pos[1], pos[3], destination[1], destination[3]) > 250 * 250 then
            needTransports = true
        end

        -- Skip the last move... we want to return and do a build
        --RNGLOG('run SendPlatoonWithTransportsNoCheck')
        unit.WaitingForTransport = true
        bUsedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, unit.PlatoonHandle, destination, T1EngOnly, needTransports, true, false)
        unit.WaitingForTransport = false
        --RNGLOG('finish SendPlatoonWithTransportsNoCheck')

        if bUsedTransports then
            return true
        elseif VDist2Sq(pos[1], pos[3], destination[1], destination[3]) > 512 * 512 then
            -- If over 512 and no transports dont try and walk!
            return false
        end
    end

    -- If we're here, we haven't used transports and we can path to the destination
    if result or reason == 'PathOK' then
        --RNGLOG('* AI-RNG: EngineerMoveWithSafePath(): result or reason == PathOK ')
        if reason ~= 'PathOK' then
            path, reason = AIAttackUtils.EngineerGenerateSafePathToRNG(aiBrain, 'Amphibious', pos, destination)
        end
        if path then
            --RNGLOG('* AI-RNG: EngineerMoveWithSafePath(): path 0 true')
            local pathSize = table.getn(path)
            -- Move to way points (but not to destination... leave that for the final command)
            for widx, waypointPath in path do
                IssueMove({unit}, waypointPath)
            end
            IssueMove({unit}, destination)
        else
            IssueMove({unit}, destination)
        end
        return true
    end
    return false
end

function EngineerMoveWithSafePathCHP(aiBrain, eng, destination, whatToBuildM)
    if not destination then
        return false
    end
    local pos = eng:GetPosition()
    local T1EngOnly = false
    if EntityCategoryContains(categories.ENGINEER * categories.TECH1, eng) then
        T1EngOnly = true
    end
    -- don't check a path if we are in build range
    if VDist2Sq(pos[1], pos[3], destination[1], destination[3]) < 144 then
        return true
    end
    if not AIAttackUtils.CanGraphToRNG(pos, destination, 'Amphibious') then
        return false
    end

    -- first try to find a path with markers. 
    local result, bestPos
    local path, reason = AIAttackUtils.EngineerGenerateSafePathToRNG(aiBrain, 'Amphibious', pos, destination, nil, 300)
    --RNGLOG('EngineerGenerateSafePathToRNG reason is'..reason)
    -- only use CanPathTo for distance closer then 200 and if we can't path with markers
    if reason ~= 'PathOK' then
        -- we will crash the game if we use CanPathTo() on all engineer movments on a map without markers. So we don't path at all.
        if reason == 'NoGraph' then
            result = true
        elseif VDist2Sq(pos[1], pos[3], destination[1], destination[3]) < 300*300 then
            SPEW('* AI-RNG: EngineerMoveWithSafePath(): executing CanPathTo(). LUA GenerateSafePathTo returned: ('..repr(reason)..') '..VDist2Sq(pos[1], pos[3], destination[1], destination[3]))
            -- be really sure we don't try a pathing with a destoryed c-object
            if eng.Dead or eng:BeenDestroyed() or IsDestroyed(eng) then
                SPEW('* AI-RNG: Unit is death before calling CanPathTo()')
                return false
            end
            result, bestPos = eng:CanPathTo(destination)
        end 
    end
    --RNGLOG('EngineerGenerateSafePathToRNG move to next bit')
    local bUsedTransports = false
    -- Increase check to 300 for transports
    if (not result and reason ~= 'PathOK') or VDist2Sq(pos[1], pos[3], destination[1], destination[3]) > 300 * 300
    and eng.PlatoonHandle and not EntityCategoryContains(categories.COMMAND, eng) then
        -- If we can't path to our destination, we need, rather than want, transports
        local needTransports = not result and reason ~= 'PathOK'
        if VDist2Sq(pos[1], pos[3], destination[1], destination[3]) > 300 * 300 then
            needTransports = true
        end

        -- Skip the last move... we want to return and do a build
        --RNGLOG('run SendPlatoonWithTransportsNoCheck')
        eng.WaitingForTransport = true
        bUsedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, eng.PlatoonHandle, destination, T1EngOnly, needTransports, true, false)
        eng.WaitingForTransport = false
        --RNGLOG('finish SendPlatoonWithTransportsNoCheck')

        if bUsedTransports then
            return true
        elseif VDist2Sq(pos[1], pos[3], destination[1], destination[3]) > 512 * 512 then
            -- If over 512 and no transports dont try and walk!
            return false
        end
    end

    -- If we're here, we haven't used transports and we can path to the destination
    if result or reason == 'PathOK' then
        --RNGLOG('* AI-RNG: EngineerMoveWithSafePath(): result or reason == PathOK ')
        if reason ~= 'PathOK' then
            path, reason = AIAttackUtils.EngineerGenerateSafePathToRNG(aiBrain, 'Amphibious', pos, destination)
        end
        if path then
            --RNGLOG('We have a path')
            if not whatToBuildM then
                local cons = eng.PlatoonHandle.PlatoonData.Construction
                local buildingTmpl, buildingTmplFile, baseTmpl, baseTmplFile, baseTmplDefault
                local factionIndex = aiBrain:GetFactionIndex()
                buildingTmplFile = import(cons.BuildingTemplateFile or '/lua/BuildingTemplates.lua')
                baseTmplFile = import(cons.BaseTemplateFile or '/lua/BaseTemplates.lua')
                baseTmplDefault = import('/lua/BaseTemplates.lua')
                buildingTmpl = buildingTmplFile[(cons.BuildingTemplate or 'BuildingTemplates')][factionIndex]
                baseTmpl = baseTmplFile[(cons.BaseTemplate or 'BaseTemplates')][factionIndex]
                whatToBuildM = aiBrain:DecideWhatToBuild(eng, 'T1Resource', buildingTmpl)
            end
            --RNGLOG('* AI-RNG: EngineerMoveWithSafePath(): path 0 true')
            local pathSize = table.getn(path)
            -- Move to way points (but not to destination... leave that for the final command)
            --RNGLOG('We are issuing move commands for the path')
            for widx, waypointPath in path do
                if widx>=3 then
                    local bool,markers=MABC.CanBuildOnMassMexPlatoon(aiBrain, waypointPath, 25)
                    if bool then
                        --RNGLOG('We can build on a mass marker within 30')
                        --local massMarker = RUtils.GetClosestMassMarkerToPos(aiBrain, waypointPath)
                        --RNGLOG('Mass Marker'..repr(massMarker))
                        --RNGLOG('Attempting second mass marker')
                        for _,massMarker in markers do
                            RUtils.EngineerTryReclaimCaptureArea(aiBrain, eng, massMarker.Position, 5)
                            EngineerTryRepair(aiBrain, eng, whatToBuildM, massMarker.Position)
                            if massMarker.BorderWarning then
                                RNGLOG('Border Warning on mass point marker')
                                IssueBuildMobile({eng}, massMarker.Position, whatToBuildM, {})
                            else
                                aiBrain:BuildStructure(eng, whatToBuildM, {massMarker.Position[1], massMarker.Position[3], 0}, false)
                            end
                        end
                    end
                end
                if (widx - math.floor(widx/2)*2)==0 or VDist3Sq(destination,waypointPath)<40*40 then continue end
                IssueMove({eng}, waypointPath)
            end
            IssueMove({eng}, destination)
        else
            IssueMove({eng}, destination)
        end
        return true
    end
    return false
end

function GetTransportsRNG(platoon, units, t1EngOnly)
    if not units then
        units = platoon:GetPlatoonUnits()
    end
    
    -- Check for empty platoon
    if table.empty(units) then
        return 0
    end

    local neededTable = GetNumTransports(units)
    local transportsNeeded = false
    if neededTable.Small > 0 or neededTable.Medium > 0 or neededTable.Large > 0 then
        transportsNeeded = true
    end


    local aiBrain = platoon:GetBrain()
    local pool = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')

    -- Make sure more are needed
    local tempNeeded = {}
    tempNeeded.Small = neededTable.Small
    tempNeeded.Medium = neededTable.Medium
    tempNeeded.Large = neededTable.Large

    local location = platoon:GetPlatoonPosition()
    if not location then
        -- We can assume we have at least one unit here
        location = units[1]:GetPosition()
    end

    if not location then
        return 0
    end

    -- Determine distance of transports from platoon
    local transports = {}
    for _, unit in pool:GetPlatoonUnits() do
        if not unit.Dead and EntityCategoryContains(categories.TRANSPORTATION - categories.uea0203, unit) and not unit:IsUnitState('Busy') and not unit:IsUnitState('TransportLoading') and table.empty(unit:GetCargo()) and unit:GetFractionComplete() == 1 then
            if t1EngOnly then
                if EntityCategoryContains(categories.TECH1, unit) then
                    local unitPos = unit:GetPosition()
                    local curr = {Unit = unit, Distance = VDist2(unitPos[1], unitPos[3], location[1], location[3]), Id = unit.UnitId}
                    table.insert(transports, curr)
                end
            else
                local unitPos = unit:GetPosition()
                local curr = {Unit = unit, Distance = VDist2(unitPos[1], unitPos[3], location[1], location[3]), Id = unit.UnitId}
                table.insert(transports, curr)
            end
        end
    end

    local numTransports = 0
    local transSlotTable = {}
    if not table.empty(transports) then
        local sortedList = {}
        -- Sort distances
        for k = 1, table.getn(transports) do
            local lowest = -1
            local key, value
            for j, u in transports do
                if lowest == -1 or u.Distance < lowest then
                    lowest = u.Distance
                    value = u
                    key = j
                end
            end
            sortedList[k] = value
            -- Remove from unsorted table
            table.remove(transports, key)
        end

        -- Take transports as needed
        for i = 1, table.getn(sortedList) do
            if transportsNeeded and table.empty(sortedList[i].Unit:GetCargo()) and not sortedList[i].Unit:IsUnitState('TransportLoading') then
                local id = sortedList[i].Id
                aiBrain:AssignUnitsToPlatoon(platoon, {sortedList[i].Unit}, 'Scout', 'GrowthFormation')
                numTransports = numTransports + 1
                if not transSlotTable[id] then
                    transSlotTable[id] = GetNumTransportSlots(sortedList[i].Unit)
                end
                local tempSlots = {}
                tempSlots.Small = transSlotTable[id].Small
                tempSlots.Medium = transSlotTable[id].Medium
                tempSlots.Large = transSlotTable[id].Large
                -- Update number of slots needed
                while tempNeeded.Large > 0 and tempSlots.Large > 0 do
                    tempNeeded.Large = tempNeeded.Large - 1
                    tempSlots.Large = tempSlots.Large - 1
                    tempSlots.Medium = tempSlots.Medium - 2
                    tempSlots.Small = tempSlots.Small - 4
                end
                while tempNeeded.Medium > 0 and tempSlots.Medium > 0 do
                    tempNeeded.Medium = tempNeeded.Medium - 1
                    tempSlots.Medium = tempSlots.Medium - 1
                    tempSlots.Small = tempSlots.Small - 2
                end
                while tempNeeded.Small > 0 and tempSlots.Small > 0 do
                    tempNeeded.Small = tempNeeded.Small - 1
                    tempSlots.Small = tempSlots.Small - 1
                end
                if tempNeeded.Small <= 0 and tempNeeded.Medium <= 0 and tempNeeded.Large <= 0 then
                    transportsNeeded = false
                end
            end
        end
    end

    if transportsNeeded then
        ReturnTransportsToPool(platoon:GetSquadUnits('Scout'), false)
        return false, tempNeeded.Small, tempNeeded.Medium, tempNeeded.Large
    else
        platoon.UsingTransport = true
        return numTransports, 0, 0, 0
    end
end

-- not in use
function UseTransportsRNG(units, transports, location, transportPlatoon)
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
        coroutine.yield(20)
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
            local safePath = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, 'Air', transports[1]:GetPosition(), location, 200)
            if safePath then
                for _, p in safePath do
                    IssueMove(transports, p)
                end
            end
        else
            if transportPlatoon then
                transportPlatoon.UsingTransport = false
            end
            return true
        end
    else
        -- If no transports return false
        if transportPlatoon then
            transportPlatoon.UsingTransport = false
        end
        return false
    end

    -- Adding Surface Height, so thetransporter get not confused, because the target is under the map (reduces unload time)
    location = {location[1], GetSurfaceHeight(location[1],location[3]), location[3]}
    IssueTransportUnload(transports, location)
    local attached = true
    while attached do
        coroutine.yield(20)
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

function AIGetMarkersAroundLocationRNG(aiBrain, markerType, pos, radius, threatMin, threatMax, threatRings, threatType)
    local markers = AIGetMarkerLocationsRNG(aiBrain, markerType)
    local returnMarkers = {}
    for _, v in markers do
        if markerType == 'Blank Marker' then
            if VDist2Sq(aiBrain.BuilderManagers['MAIN'].Position[1], aiBrain.BuilderManagers['MAIN'].Position[3], v.Position[1], v.Position[3]) < 10000 then
                --RNGLOG('Start Location too close to main base skip, location is '..VDist2Sq(aiBrain.BuilderManagers['MAIN'].Position[1], aiBrain.BuilderManagers['MAIN'].Position[3], v.Position[1], v.Position[3])..' from main base pos')
                continue
            end
        end
        local dist = VDist2(pos[1], pos[3], v.Position[1], v.Position[3])
        if dist < radius then
            if not threatMin then
                table.insert(returnMarkers, v)
            else
                local threat = GetThreatAtPosition(aiBrain, v.Position, threatRings, true, threatType or 'Overall')
                if threat >= threatMin and threat <= threatMax then
                    table.insert(returnMarkers, v)
                end
            end
        end
    end

    return returnMarkers
end

function AIGetMarkerLocationsRNG(aiBrain, markerType)
    local markerList = {}
    if markerType == 'Start Location' then
        local tempMarkers = AIGetMarkerLocationsRNG(aiBrain, 'Blank Marker')
        for k, v in tempMarkers do
            if string.sub(v.Name, 1, 5) == 'ARMY_' then
                table.insert(markerList, {Position = v.Position, Name = v.Name, MassSpotsInRange = v.MassSpotsInRange})
            end
        end
    else
        local markers = Scenario.MasterChain._MASTERCHAIN_.Markers
        if markers then
            for k, v in markers do
                if v.type == markerType then
                    table.insert(markerList, {Position = v.position, Name = k, MassSpotsInRange = v.MassSpotsInRange})
                end
            end
        end
    end

    return markerList
end

function AIFilterAlliedBasesRNG(aiBrain, positions)
    local retPositions = {}
    local armyIndex = aiBrain:GetArmyIndex()
    for _, v in positions do
        local allyPosition = false
        for index,brain in ArmyBrains do
            if brain.BrainType == 'AI' and IsAlly(brain:GetArmyIndex(), armyIndex) then
                if brain.BuilderManagers[v.Name]  or ( v.Position[1] == brain.BuilderManagers['MAIN'].Position[1] and v.Position[3] == brain.BuilderManagers['MAIN'].Position[3] ) then
                    if brain.BuilderManagers[v.Name] then
                        --RNGLOG('Ally AI already has expansion '..v.Name)
                        if brain.BuilderManagers[v.Name].Active then
                            --RNGLOG('BuilderManager is active')
                        end
                    elseif v.Position[1] == brain.BuilderManagers['MAIN'].Position[1] and v.Position[3] == brain.BuilderManagers['MAIN'].Position[3] then
                        --RNGLOG('Ally AI already has Main Position')
                    end
                    allyPosition = true
                    break
                end
            end
        end
        if not allyPosition then
            --RNGLOG('No AI ally at this expansion position, perform structure threat')
            local threat = GetAlliesThreat(aiBrain, v, 2, 'StructuresNotMex')
            if threat == 0 then
                table.insert(retPositions, v)
            end
        end
    end
    return retPositions
end

function AIFindMarkerNeedsEngineerRNG(aiBrain, pos, radius, tMin, tMax, tRings, tType, positions)
    local closest = false
    local markerCount = false
    local retPos, retName
    local positions = AIFilterAlliedBasesRNG(aiBrain, positions)
    --RNGLOG('Pontetial Marker Locations '..repr(positions))
    for _, v in positions do
        if not aiBrain.BuilderManagers[v.Name] then
            if (not closest or VDist3Sq(pos, v.Position) < closest) and (not markerCount or v.MassSpotsInRange < markerCount) then
                closest = VDist3Sq(pos, v.Position)
                retPos = v.Position
                retName = v.Name
                markerCount = v.MassSpotsInRange
            end
        else
            local managers = aiBrain.BuilderManagers[v.Name]
            if managers.EngineerManager:GetNumUnits('Engineers') == 0 and managers.FactoryManager:GetNumFactories() == 0 then
                if (not closest or VDist3Sq(pos, v.Position) < closest) and (not markerCount or v.MassSpotsInRange < markerCount) then
                    closest = VDist3Sq(pos, v.Position)
                    retPos = v.Position
                    retName = v.Name
                    markerCount = v.MassSpotsInRange
                end
            end
        end
    end
    if not markerCount then 
        markerCount = 0
    end
    --RNGLOG('Returning '..repr(retPos)..' with '..markerCount..' Mass Markers')
    return retPos, retName
end

function AIFindMarkerNeedsEngineerThreatRNG(aiBrain, pos, radius, tMin, tMax, tRings, tType, positions)
    local closest = false
    local markerCount = false
    local retPos, retName
    local positions = AIFilterAlliedBasesRNG(aiBrain, positions)
    --RNGLOG('Pontetial Marker Locations '..repr(positions))
    for _, v in positions do
        if not aiBrain.BuilderManagers[v.Name] then
            if GetThreatAtPosition(aiBrain, v.Position, tRings, true, tType) <= tMax then
                if (not closest or VDist3Sq(pos, v.Position) < closest) and (not markerCount or v.MassSpotsInRange < markerCount) then
                    closest = VDist3Sq(pos, v.Position)
                    retPos = v.Position
                    retName = v.Name
                    markerCount = v.MassSpotsInRange
                end
            end
        else
            local managers = aiBrain.BuilderManagers[v.Name]
            if managers.EngineerManager:GetNumUnits('Engineers') == 0 and managers.FactoryManager:GetNumFactories() == 0 then
                if GetThreatAtPosition(aiBrain, v.Position, tRings, true, tType) <= tMax then
                    if (not closest or VDist3Sq(pos, v.Position) < closest) and (not markerCount or v.MassSpotsInRange < markerCount) then
                        closest = VDist3Sq(pos, v.Position)
                        retPos = v.Position
                        retName = v.Name
                        markerCount = v.MassSpotsInRange
                    end
                end
            end
        end
    end
    if not markerCount then 
        markerCount = 0
    end
    --RNGLOG('Returning '..repr(retPos)..' with '..markerCount..' Mass Markers')
    return retPos, retName
end

function AIGetClosestMarkerLocationRNG(aiBrain, markerType, startX, startZ, extraTypes)
    local markerList = AIGetMarkerLocations(aiBrain, markerType)
    if extraTypes then
        for num, pType in extraTypes do
            local moreMarkers = AIGetMarkerLocations(aiBrain, pType)
            if table.getn(moreMarkers) > 0 then
                for _, v in moreMarkers do
                    table.insert(markerList, {Position = v.Position, Name = v.Name})
                end
            end
        end
    end

    local loc, distance, lowest, name = nil
    for _, v in markerList do
        local x = v.Position[1]
        local y = v.Position[2]
        local z = v.Position[3]
        distance = VDist2(startX, startZ, x, z)
        if not lowest or distance < lowest then
            loc = v.Position
            name = v.Name
            lowest = distance
        end
    end

    return loc, name, lowest
end

function AIFindAggressiveBaseLocationRNG(aiBrain, locationType, radius, tMin, tMax, tRings, tType)
    -- Get location of commander
    if not aiBrain:GetCurrentEnemy() then
        return false
    end
    local estartX, estartZ = aiBrain:GetCurrentEnemy():GetArmyStartPos()
    local threatPos = {estartX, 0, estartZ}

    -- Get markers
    local markerList = AIGetMarkerLocations(aiBrain, 'Expansion Area')
    local largeMarkerList = AIGetMarkerLocations(aiBrain, 'Large Expansion Area')
    for k, v in largeMarkerList do
        table.insert(markerList, v)
    end
    -- For each marker, check against threatpos. Save markers that are within the FireBaseRange
    local inRangeList = {}
    for _, marker in markerList do
        local distSq = VDist2Sq(marker.Position[1], marker.Position[3], threatPos[1], threatPos[3])

        if distSq < radius * radius  then
            table.insert(inRangeList, marker)
        end
    end

    -- Pick the closest, least-threatening position in range
    local bestDistSq = 9999999999
    local bestThreat = 9999999999
    local bestMarker = false
    local maxThreat = tMax or 1
    local reference = false
    local refName = false
    
    for _, marker in inRangeList do
        local threat = GetThreatAtPosition(aiBrain, marker.Position, 1, true, 'AntiSurface')
        if threat < maxThreat then
            if threat < bestThreat and threat < maxThreat then
                bestDistSq = VDist2Sq(threatPos[1], threatPos[3], marker.Position[1], marker.Position[3])
                bestThreat = threat
                bestMarker = marker
            elseif threat == bestThreat then
                local distSq = VDist2Sq(threatPos[1], threatPos[3], marker.Position[1], marker.Position[3])
                if distSq > bestDistSq then
                    bestDistSq = distSq
                    bestMarker = marker
                end
            end
        end
    end
    if bestMarker then
        reference = bestMarker.Position
        refName = bestMarker.Name
    end
    
    return reference, refName
end

function AIFindUndefendedBrainTargetInRangeRNG(aiBrain, platoon, squad, maxRange, atkPri)
    local position = platoon:GetPlatoonPosition()
    local CategoriesShield = categories.DEFENSE * categories.SHIELD * categories.STRUCTURE
    if not aiBrain or not position or not maxRange then
        return false
    end

    local numUnits = table.getn(platoon:GetPlatoonUnits())
    local targetUnits = aiBrain:GetUnitsAroundPoint(categories.ALLUNITS - categories.INSIGNIFICANTUNIT, position, maxRange, 'Enemy')
    for _, v in atkPri do
        local retUnit = false
        local distance = false
        local targetShields = 9999
        for num, unit in targetUnits do
            if not unit.Dead and EntityCategoryContains(v, unit) and platoon:CanAttackTarget(squad, unit) then
                local unitPos = unit:GetPosition()
                local numShields = aiBrain:GetNumUnitsAroundPoint(CategoriesShield, unitPos, 46, 'Enemy')
                if numShields > 0 and (not retUnit) and VDist2Sq(position[1], position[3], unitPos[1], unitPos[3]) < distance then
                    local shieldUnits = aiBrain:GetUnitsAroundPoint(CategoriesShield, unitPos, 46, 'Enemy')
                    local totalShieldHealth = 0
                    for _, sUnit in shieldUnits do
                        if not sUnit.Dead and sUnit.MyShield then
                            totalShieldHealth = totalShieldHealth + sUnit.MyShield:GetHealth()
                        end
                    end
                    if totalShieldHealth > 0 then
                        if (platoon.MaxPlatoonDPS / totalShieldHealth) < 15 then
                            retUnit = unit
                            distance = VDist2Sq(position[1], position[3], unitPos[1], unitPos[3])
                            targetShields = numShields
                        end
                    end
                elseif (not retUnit) or VDist2Sq(position[1], position[3], unitPos[1], unitPos[3]) < distance then
                    retUnit = unit
                    distance = VDist2Sq(position[1], position[3], unitPos[1], unitPos[3])
                    targetShields = numShields
                end
            end
        end
        if retUnit and targetShields > 0 then
            local platoonUnits = platoon:GetPlatoonUnits()
            for _, w in platoonUnits do
                if not w.Dead then
                    unit = w
                    break
                end
            end
            local closestBlockingShield, shieldHealth = RUtils.GetClosestShieldProtectingTargetRNG(unit, retUnit)
            if closestBlockingShield then
                return closestBlockingShield, shieldHealth
            end
        end
        if retUnit then
            RNGLOG('Satellite has target')
            return retUnit
        else
            RNGLOG('Satellite did not get target')
        end
    end

    return false
end