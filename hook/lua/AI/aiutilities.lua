WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] * RNGAI: offset aiutilities.lua' )

local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local NavUtils = import('/lua/sim/NavUtils.lua')
local TransportUtils = import("/lua/ai/transportutilities.lua")
local MarkerUtils = import("/lua/sim/MarkerUtilities.lua")
local MABC = import('/lua/editor/MarkerBuildConditions.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG
local RNGINSERT = table.insert
local RNGGETN = table.getn

function AIGetMarkerLocationsNotFriendly(aiBrain, markerType)
    local markerList = {}
    --RNGLOG('* AI-RNG: Marker Type for AIGetMarkerLocationsNotFriendly is '..markerType)
    if markerType == 'Start Location' then
        local tempMarkers = AIGetMarkerLocationsRNG(aiBrain, 'Spawn')
        for k, v in tempMarkers do
            local ecoStructures = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE * (categories.MASSEXTRACTION + categories.MASSPRODUCTION), v.Position, 30, 'Ally')
            local ecoThreat = 0
            for _, v in ecoStructures do
                local bp = v.Blueprint
                local ecoStructThreat = bp.Defense.EconomyThreatLevel
                --RNGLOG('* AI-RNG: Eco Structure'..ecoStructThreat)
                ecoThreat = ecoThreat + ecoStructThreat
            end
            if ecoThreat < 10 then
                table.insert(markerList, {Position = v.Position, Name = v.Name})
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

function EngineerMoveWithSafePathRNG(aiBrain, unit, destination, alwaysGeneratePath, transportWait)
    local ALLBPS = __blueprints
    if not destination then
        return false
    end
    local pos = unit:GetPosition()
    local T1EngOnly = false
    if EntityCategoryContains(categories.ENGINEER * categories.TECH1, unit) then
        T1EngOnly = true
    end
    local jobType = unit.PlatoonHandle.PlatoonData.JobType or 'None'
    -- don't check a path if we are in build range
    if not alwaysGeneratePath and VDist3Sq(pos, destination) < 1225 then
        if NavUtils.CanPathTo('Amphibious', pos, destination) then
            return true
        end
    end
    if not transportWait then
        transportWait = 2
    end

    -- first try to find a path with markers. 
    local result, navReason
    local path, reason = AIAttackUtils.EngineerGenerateSafePathToRNG(aiBrain, 'Amphibious', pos, destination)
    if unit.PlatoonHandle.BuilderName then
        --RNGLOG('EngineerGenerateSafePathToRNG for '..unit.PlatoonHandle.BuilderName..' reason '..reason)
    end
    --RNGLOG('EngineerGenerateSafePathToRNG reason is'..reason)
    -- only use CanPathTo for distance closer then 200 and if we can't path with markers
    if reason ~= 'PathOK' then
        -- we will crash the game if we use CanPathTo() on all engineer movments on a map without markers. So we don't path at all.
        if reason == 'NoGraph' then
            result = true
        elseif VDist2Sq(pos[1], pos[3], destination[1], destination[3]) < 40000 then
            --SPEW('* AI-RNG: EngineerMoveWithSafePath(): executing CanPathTo(). LUA GenerateSafePathTo returned: ('..repr(reason)..') '..VDist2(pos[1], pos[3], destination[1], destination[3]))
            -- be really sure we don't try a pathing with a destoryed c-object
            result, navReason = NavUtils.CanPathTo('Amphibious', pos, destination)
        end 
    end
    if result then
        --RNGLOG('result is true, reason is '..reason)
    else
        --RNGLOG('result is false, reason is '..reason)
    end
    local bUsedTransports = false
    -- Increase check to 300 for transports
    if (not result and reason ~= 'PathOK') or VDist2Sq(pos[1], pos[3], destination[1], destination[3]) > 250 * 250
    and unit.PlatoonHandle and not EntityCategoryContains(categories.COMMAND, unit) then
        -- If we can't path to our destination, we need, rather than want, transports
        local needTransports = not result and reason ~= 'PathOK'
        if VDist2Sq(pos[1], pos[3], destination[1], destination[3]) > 295 * 295 then
            needTransports = true
        end

        -- Skip the last move... we want to return and do a build
        unit.WaitingForTransport = true
        bUsedTransports = TransportUtils.SendPlatoonWithTransports(aiBrain, unit.PlatoonHandle, destination, transportWait, true)
        unit.WaitingForTransport = false

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
            local pathLength = RNGGETN(path)
            local brokenPathMovement = false
            local currentPathNode = 1
            for i=currentPathNode, pathLength do
                IssueMove({unit}, path[i])
            end
            IssueMove({unit}, destination)
            if unit.EngineerBuildQueue and not table.empty(unit.EngineerBuildQueue) then
                if unit.EngineerBuildQueue[1][4] then
                    --RNGLOG('BorderWarning build')
                    IssueBuildMobile({unit}, {unit.EngineerBuildQueue[1][2][1], 0, unit.EngineerBuildQueue[1][2][2]}, unit.EngineerBuildQueue[1][1], {})
                else
                    aiBrain:BuildStructure(unit, unit.EngineerBuildQueue[1][1], {unit.EngineerBuildQueue[1][2][1], unit.EngineerBuildQueue[1][2][2], 0}, unit.EngineerBuildQueue[1][3])
                end
            end
            local dist
            local movementTimeout = 0
            while not IsDestroyed(unit) do
                local reclaimed
                if brokenPathMovement and ( unit.EngineerBuildQueue and not table.empty(unit.EngineerBuildQueue) or jobType == 'Reclaim' )then
                    for i=currentPathNode, pathLength do
                        IssueMove({unit}, path[i])
                    end
                    IssueMove({unit}, destination)
                    if jobType ~= 'Reclaim' then
                        if unit.EngineerBuildQueue[1][4] then
                            --RNGLOG('BorderWarning build')
                            IssueBuildMobile({unit}, {unit.EngineerBuildQueue[1][2][1], 0, unit.EngineerBuildQueue[1][2][2]}, unit.EngineerBuildQueue[1][1], {})
                        else
                            aiBrain:BuildStructure(unit, unit.EngineerBuildQueue[1][1], {unit.EngineerBuildQueue[1][2][1], unit.EngineerBuildQueue[1][2][2], 0}, unit.EngineerBuildQueue[1][3])
                        end
                    end
                    if reclaimed then
                        coroutine.yield(20)
                    end
                    reclaimed = false
                    brokenPathMovement = false
                end
                pos = unit:GetPosition()
                if currentPathNode <= pathLength then
                    dist = VDist3Sq(path[currentPathNode], pos)
                    if dist < 100 or (currentPathNode+1 <= pathLength and dist > VDist3Sq(pos, path[currentPathNode+1])) then
                        currentPathNode = currentPathNode + 1
                    end
                end
                if VDist3Sq(destination, pos) < 100 then
                    break
                end
                if unit.Upgrading or unit.Combat or unit.Active then
                    break
                end
                coroutine.yield(15)
                if unit.Dead then
                    return
                end
                if unit.EngineerBuildQueue or jobType == 'Reclaim' then
                    if jobType == 'Reclaim' or ALLBPS[unit.EngineerBuildQueue[1][1]].CategoriesHash.MASSEXTRACTION and ALLBPS[unit.EngineerBuildQueue[1][1]].CategoriesHash.TECH1 then
                        --RNGLOG('Attempt reclaim on eng movement')
                        if not unit:IsUnitState('Reclaiming') then
                            brokenPathMovement = RUtils.PerformEngReclaim(aiBrain, unit, 5)
                            if brokenPathMovement then
                                reclaimed = true
                            end
                        end
                    end
                end
                if unit:IsUnitState("Moving") then
                    if GetNumUnitsAroundPoint(aiBrain, categories.LAND * categories.MOBILE, pos, 45, 'Enemy') > 0 then
                        local enemyUnits = GetUnitsAroundPoint(aiBrain, categories.LAND * categories.MOBILE, pos, 45, 'Enemy')
                        for _, eunit in enemyUnits do
                            local enemyUnitPos = eunit:GetPosition()
                            if EntityCategoryContains(categories.SCOUT + categories.ENGINEER * (categories.TECH1 + categories.TECH2) - categories.COMMAND, eunit) then
                                if VDist3Sq(enemyUnitPos, pos) < 144 then
                                    --RNGLOG('MexBuild found enemy engineer or scout, try reclaiming')
                                    if eunit and not eunit.Dead and unit:GetFractionComplete() == 1 then
                                        if VDist3Sq(pos, enemyUnitPos) < 100 then
                                            IssueClearCommands({unit})
                                            IssueReclaim({unit}, eunit)
                                            brokenPathMovement = true
                                            break
                                        end
                                    end
                                end
                            elseif EntityCategoryContains(categories.LAND * categories.MOBILE - categories.SCOUT, eunit) then
                                --RNGLOG('MexBuild found enemy unit, try avoid it')
                                if VDist3Sq(enemyUnitPos, pos) < 81 then
                                    --RNGLOG('MexBuild found enemy engineer or scout, try reclaiming')
                                    if eunit and not eunit.Dead and eunit:GetFractionComplete() == 1 then
                                        if VDist3Sq(pos, enemyUnitPos) < 100 then
                                            IssueClearCommands({unit})
                                            IssueReclaim({unit}, eunit)
                                            brokenPathMovement = true
                                            break
                                        end
                                    end
                                else
                                    IssueClearCommands({unit})
                                    IssueMove({unit}, RUtils.AvoidLocation(enemyUnitPos, pos, 50))
                                    brokenPathMovement = true
                                    coroutine.yield(60)
                                end
                            end
                        end
                    end
                end
                if unit:IsIdleState() then
                    movementTimeout = movementTimeout + 1
                    if movementTimeout > 10 then
                        break
                    end
                end
            end
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
    local ALLBPS = __blueprints
    local pos = eng:GetPosition()
    local T1EngOnly = false
    if EntityCategoryContains(categories.ENGINEER * categories.TECH1, eng) then
        T1EngOnly = true
    end
    -- don't check a path if we are in build range
    if VDist2Sq(pos[1], pos[3], destination[1], destination[3]) < 144 then
        return true
    end
    --[[
    if not NavUtils.CanPathTo('Amphibious', pos, destination) then
        return false
    end]]

    -- first try to find a path with markers. 
    local result, navReason
    local path, reason = AIAttackUtils.EngineerGenerateSafePathToRNG(aiBrain, 'Amphibious', pos, destination, nil, 300)

    -- only use CanPathTo for distance closer then 200 and if we can't path with markers
    if reason ~= 'PathOK' then
        -- we will crash the game if we use CanPathTo() on all engineer movments on a map without markers. So we don't path at all.
        if reason == 'NoGraph' then
            result = true
        elseif VDist2Sq(pos[1], pos[3], destination[1], destination[3]) < 300*300 then
            --SPEW('* AI-RNG: EngineerMoveWithSafePath(): executing CanPathTo(). LUA GenerateSafePathTo returned: ('..repr(reason)..') '..VDist2Sq(pos[1], pos[3], destination[1], destination[3]))
            -- be really sure we don't try a pathing with a destoryed c-object
            if IsDestroyed(eng) then
                --SPEW('* AI-RNG: Unit is death before calling CanPathTo()')
                return false
            end
            result, navReason = NavUtils.CanPathTo('Amphibious', pos, destination)
        end 
    end
    --RNGLOG('EngineerGenerateSafePathToRNG move to next bit')
    local bUsedTransports = false
    -- Increase check to 300 for transports
    if (not result and reason ~= 'PathOK') or VDist2Sq(pos[1], pos[3], destination[1], destination[3]) > 300 * 300
    and eng.PlatoonHandle and not EntityCategoryContains(categories.COMMAND, eng) then
        -- If we can't path to our destination, we need, rather than want, transports
        local needTransports = not result and reason ~= 'PathOK'
        if VDist2Sq(pos[1], pos[3], destination[1], destination[3]) > 350 * 350 then
            needTransports = true
        end

        -- Skip the last move... we want to return and do a build
        eng.WaitingForTransport = true
        bUsedTransports = TransportUtils.SendPlatoonWithTransports(aiBrain, eng.PlatoonHandle, destination, 2, true)
        eng.WaitingForTransport = false

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
            -- Move to way points (but not to destination... leave that for the final command)
            --RNGLOG('We are issuing move commands for the path')
            local dist
            local pathLength = RNGGETN(path)
            local brokenPathMovement = false
            local currentPathNode = 1
            local pos
            IssueClearCommands({eng})
            for i=currentPathNode, pathLength do
                if i>=3 then
                    local bool,markers=MABC.CanBuildOnMassMexPlatoon(aiBrain, path[i], 25)
                    if bool then
                        --RNGLOG('We can build on a mass marker within 30')
                        --local massMarker = RUtils.GetClosestMassMarkerToPos(aiBrain, waypointPath)
                        --RNGLOG('Mass Marker'..repr(massMarker))
                        --RNGLOG('Attempting second mass marker')
                        
                        local buildQueueReset = eng.EnginerBuildQueue
                        eng.EnginerBuildQueue = {}
                        for _,massMarker in markers do
                            RUtils.EngineerTryReclaimCaptureArea(aiBrain, eng, massMarker.Position, 5)
                            RUtils.EngineerTryRepair(aiBrain, eng, whatToBuildM, massMarker.Position)
                            if massMarker.BorderWarning then
                               --RNGLOG('Border Warning on mass point marker')
                                IssueBuildMobile({eng}, {massMarker.Position[1], massMarker.Position[3], 0}, whatToBuildM, {})
                                local newEntry = {whatToBuildM, {massMarker.Position[1], massMarker.Position[3], 0}, false,Position=massMarker.Position, true, PathPoint=i}
                                RNGINSERT(eng.EngineerBuildQueue, newEntry)
                            else
                                aiBrain:BuildStructure(eng, whatToBuildM, {massMarker.Position[1], massMarker.Position[3], 0}, false)
                                local newEntry = {whatToBuildM, {massMarker.Position[1], massMarker.Position[3], 0}, false,Position=massMarker.Position, true, PathPoint=i}
                                RNGINSERT(eng.EngineerBuildQueue, newEntry)
                            end
                        end
                        if buildQueueReset then
                            for k, v in buildQueueReset do
                                RNGINSERT(eng.EngineerBuildQueue, v)
                            end
                        end
                    end
                end
                if (i - math.floor(i/2)*2)==0 or VDist3Sq(destination,path[i])<40*40 then continue end
                IssueMove({eng}, path[i])
            end
            --IssueMove({eng}, destination)
            for k, v in eng.EngineerBuildQueue do
                if eng.EngineerBuildQueue[k].PathPoint then
                    continue
                end
                if eng.EngineerBuildQueue[k][5] then
                    IssueBuildMobile({eng}, {eng.EngineerBuildQueue[k][2][1], 0, eng.EngineerBuildQueue[k][2][2]}, eng.EngineerBuildQueue[k][1], {})
                else
                    aiBrain:BuildStructure(eng, eng.EngineerBuildQueue[k][1], {eng.EngineerBuildQueue[k][2][1], eng.EngineerBuildQueue[k][2][2], 0}, eng.EngineerBuildQueue[k][3])
                end
            end
            while not IsDestroyed(eng) do
                local reclaimed
                if brokenPathMovement and eng.EngineerBuildQueue and not table.empty(eng.EngineerBuildQueue) then
                    pos = eng:GetPosition()
                    local queuePointTaken = {}
                    local skipPath = false
                    for i=currentPathNode, pathLength do
                        for k, v in eng.EngineerBuildQueue do
                            if v.PathPoint and (v.PathPoint == i or i > v.PathPoint and not queuePointTaken[k]) then
                                if eng.EngineerBuildQueue[k][5] then
                                    --RNGLOG('BorderWarning build')
                                    --RNGLOG('Found build command at point '..repr(eng.EngineerBuildQueue[k][2]))
                                    IssueBuildMobile({eng}, {eng.EngineerBuildQueue[k][2][1], 0, eng.EngineerBuildQueue[k][2][2]}, eng.EngineerBuildQueue[k][1], {})
                                else
                                    --RNGLOG('Found build command at point '..repr(eng.EngineerBuildQueue[k][2]))
                                    aiBrain:BuildStructure(eng, eng.EngineerBuildQueue[k][1], {eng.EngineerBuildQueue[k][2][1], eng.EngineerBuildQueue[k][2][2], 0}, eng.EngineerBuildQueue[k][3])
                                end
                                queuePointTaken[k] = true
                                skipPath = true
                            end
                        end
                        if not skipPath then
                            IssueMove({eng}, path[i])
                        end
                        skipPath = false
                    end
                    --RNGLOG('queuePointTaken list '..repr(queuePointTaken))
                    --IssueMove({eng}, destination)
                    for k, v in eng.EngineerBuildQueue do
                        if queuePointTaken[k] and eng.EngineerBuildQueue[k]  then
                            --RNGLOG('QueuePoint already taken, skipping for position '..repr(eng.EngineerBuildQueue[k][2]))
                            continue
                        end
                        if eng.EngineerBuildQueue[k][5] then
                            --RNGLOG('Found end build command at point '..repr(eng.EngineerBuildQueue[k][2]))
                            IssueBuildMobile({eng}, {eng.EngineerBuildQueue[k][2][1], 0, eng.EngineerBuildQueue[k][2][2]}, eng.EngineerBuildQueue[k][1], {})
                        else
                            --RNGLOG('Found end build command at point '..repr(eng.EngineerBuildQueue[k][2]))
                            aiBrain:BuildStructure(eng, eng.EngineerBuildQueue[k][1], {eng.EngineerBuildQueue[k][2][1], eng.EngineerBuildQueue[k][2][2], 0}, eng.EngineerBuildQueue[k][3])
                        end
                    end
                    if reclaimed then
                        coroutine.yield(20)
                    end
                    reclaimed = false
                    brokenPathMovement = false
                end
                pos = eng:GetPosition()
                if currentPathNode <= pathLength then
                    dist = VDist3Sq(pos, path[currentPathNode])
                    if dist < 100 or (currentPathNode+1 <= pathLength and dist > VDist3Sq(pos, path[currentPathNode+1])) then
                        currentPathNode = currentPathNode + 1
                    end
                end
                if VDist3Sq(destination, pos) < 100 then
                    break
                end
                coroutine.yield(15)
                if eng.Dead or eng:IsIdleState() then
                    return
                end
                if eng.EngineerBuildQueue then
                    if ALLBPS[eng.EngineerBuildQueue[1][1]].CategoriesHash.MASSEXTRACTION and ALLBPS[eng.EngineerBuildQueue[1][1]].CategoriesHash.TECH1 then
                        if not eng:IsUnitState('Reclaiming') then
                            brokenPathMovement = RUtils.PerformEngReclaim(aiBrain, eng, 5)
                            reclaimed = true
                        end
                    end
                end
                if eng:IsUnitState("Moving") then
                    if GetNumUnitsAroundPoint(aiBrain, categories.LAND * categories.MOBILE, pos, 45, 'Enemy') > 0 then
                        local enemyUnits = GetUnitsAroundPoint(aiBrain, categories.LAND * categories.MOBILE, pos, 45, 'Enemy')
                        for _, eunit in enemyUnits do
                            local enemyUnitPos = eunit:GetPosition()
                            if EntityCategoryContains(categories.SCOUT + categories.ENGINEER * (categories.TECH1 + categories.TECH2) - categories.COMMAND, eunit) then
                                if VDist3Sq(enemyUnitPos, pos) < 144 then
                                    --RNGLOG('MexBuild found enemy engineer or scout, try reclaiming')
                                    if eunit and not eunit.Dead and eunit:GetFractionComplete() == 1 then
                                        if VDist3Sq(pos, enemyUnitPos) < 100 then
                                            IssueClearCommands({eng})
                                            IssueReclaim({eng}, eunit)
                                            brokenPathMovement = true
                                            break
                                        end
                                    end
                                end
                            elseif EntityCategoryContains(categories.LAND * categories.MOBILE - categories.SCOUT, eunit) then
                                --RNGLOG('MexBuild found enemy unit, try avoid it')
                                if VDist3Sq(enemyUnitPos, pos) < 81 then
                                    --RNGLOG('MexBuild found enemy engineer or scout, try reclaiming')
                                    if eunit and not eunit.Dead and eunit:GetFractionComplete() == 1 then
                                        if VDist3Sq(pos, enemyUnitPos) < 100 then
                                            IssueClearCommands({eng})
                                            IssueReclaim({eng}, eunit)
                                            brokenPathMovement = true
                                            coroutine.yield(20)
                                            if not IsDestroyed(eunit) and VDist3Sq(eng:GetPosition(), eunit:GetPosition()) < 100 then
                                                IssueClearCommands({eng})
                                                IssueReclaim({eng}, eunit)
                                                coroutine.yield(30)
                                            end
                                            coroutine.yield(40)
                                            break
                                        end
                                    end
                                else
                                    IssueClearCommands({eng})
                                    IssueMove({eng}, RUtils.AvoidLocation(enemyUnitPos, pos, 50))
                                    brokenPathMovement = true
                                    coroutine.yield(60)
                                end
                            end
                        end
                    end
                end
            end
        else
            IssueMove({eng}, destination)
        end
        return true, path
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
        if not table.empty(data.Units) then
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
        if markerType == 'Spawn' then
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
    local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
    local markerList = {}
    local markers = MarkerUtils.GetMarkersByType(markerType)
    for k, v in markers do
        if v.position[1] > playableArea[1] and v.position[1] < playableArea[3] and v.position[3] > playableArea[2] and v.position[3] < playableArea[4] then
            if v.Extractors then
                table.insert(markerList, {Position = v.position or v.Position, Name = v.Name or v.name, MassSpotsInRange = RNGGETN(v.Extractors)})
            else
                table.insert(markerList, {Position = v.position or v.Position, Name = v.Name or v.name })
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
    local markerList = AIGetMarkerLocationsRNG(aiBrain, markerType)
    if extraTypes then
        for num, pType in extraTypes do
            local moreMarkers = AIGetMarkerLocationsRNG(aiBrain, pType)
            if not table.empty(moreMarkers) then
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
        distance = VDist2Sq(startX, startZ, x, z)
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
    local markerList = AIGetMarkerLocationsRNG(aiBrain, 'Expansion Area')
    local largeMarkerList = AIGetMarkerLocationsRNG(aiBrain, 'Large Expansion Area')
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
                --RNGLOG('Satellite Distance of unit to platoon '..VDist2Sq(position[1], position[3], unitPos[1], unitPos[3]))
                if numShields > 0 and (not retUnit) and (not distance or VDist2Sq(position[1], position[3], unitPos[1], unitPos[3]) < distance) then
                    local shieldUnits = aiBrain:GetUnitsAroundPoint(CategoriesShield, unitPos, 46, 'Enemy')
                    local totalShieldHealth = 0
                    for _, sUnit in shieldUnits do
                        if not sUnit.Dead and sUnit.MyShield then
                            if sUnit.bp.Defense.ShieldSize and VDist3Sq(unitPos, sUnit:GetPosition()) < sUnit.bp.Defense.ShieldSize and sUnit.MyShield.GetHealth then
                                totalShieldHealth = totalShieldHealth + sUnit.MyShield:GetHealth()
                            end
                        end
                    end
                    --RNGLOG('Satellite looking for target found shield')
                    --RNGLOG('Satellite max dps '..platoon.MaxPlatoonDPS..' total shield health '..totalShieldHealth)
                    if totalShieldHealth > 0 then
                        --RNGLOG('Satellite max dps divided by shield health should be less than 12 '..(platoon.MaxPlatoonDPS/totalShieldHealth))
                        if (platoon.MaxPlatoonDPS / totalShieldHealth) < 12 then
                            retUnit = unit
                            distance = VDist2Sq(position[1], position[3], unitPos[1], unitPos[3])
                            targetShields = numShields
                        end
                    end
                elseif (not retUnit) or VDist2Sq(position[1], position[3], unitPos[1], unitPos[3]) < distance then
                    --RNGLOG('Satellite, no shield found blocking target')
                    retUnit = unit
                    distance = VDist2Sq(position[1], position[3], unitPos[1], unitPos[3])
                    targetShields = 0
                end
            end
        end
        if retUnit and targetShields > 0 then
            local unit
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
            --RNGLOG('Satellite has target')
            return retUnit
        else
            --RNGLOG('Satellite did not get target')
        end
    end

    return false
end

function AIFindNavalAreaNeedsEngineer(aiBrain, locationType, radius, tMin, tMax, tRings, tType, eng)
    local pos
    if aiBrain.BuilderManagers[locationType] then
        pos = aiBrain.BuilderManagers[locationType].FactoryManager:GetLocationCoords()
    end
    if not pos then
        return false
    end
    local positions = AIGetMarkersAroundLocationRNG(aiBrain, 'Naval Area', pos, radius, tMin, tMax, tRings, tType)

    local retPos, retName
    if eng then
        retPos, retName = AIFindMarkerNeedsEngineer(aiBrain, eng:GetPosition(), radius, tMin, tMax, tRings, tType, positions)
    else
        retPos, retName = AIFindMarkerNeedsEngineer(aiBrain, pos, radius, tMin, tMax, tRings, tType, positions)
    end

    return retPos, retName
end

