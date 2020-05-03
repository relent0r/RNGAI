
function EngineerGenerateSafePathToRNG(aiBrain, platoonLayer, startPos, endPos, optThreatWeight, optMaxMarkerDist)
    if not GetPathGraphs()[platoonLayer] then
        return false, 'NoGraph'
    end

    --Get the closest path node at the platoon's position
    optMaxMarkerDist = optMaxMarkerDist or 250
    optThreatWeight = optThreatWeight or 1
    local startNode
    startNode = GetClosestPathNodeInRadiusByLayer(startPos, optMaxMarkerDist, platoonLayer)
    if not startNode then return false, 'NoStartNode' end

    --Get the matching path node at the destiantion
    local endNode = GetClosestPathNodeInRadiusByGraph(endPos, optMaxMarkerDist, startNode.graphName)
    if not endNode then return false, 'NoEndNode' end

    --Generate the safest path between the start and destination
    local path = EngineerGeneratePathRNG(aiBrain, startNode, endNode, ThreatTable[platoonLayer], optThreatWeight, endPos, startPos)
    if not path then return false, 'NoPath' end

    -- Insert the path nodes (minus the start node and end nodes, which are close enough to our start and destination) into our command queue.
    -- delete the first and last node only if they are very near (under 30 map units) to the start or end destination.
    local finalPath = {}
    local NodeCount = table.getn(path.path)
    for i,node in path.path do
        -- IF this is the first AND not the only waypoint AND its nearer 30 THEN continue and don't add it to the finalpath
        if i == 1 and NodeCount > 1 and VDist2(startPos[1], startPos[3], node.position[1], node.position[3]) < 30 then  
            continue
        end
        -- IF this is the last AND not the only waypoint AND its nearer 20 THEN continue and don't add it to the finalpath
        if i == NodeCount and NodeCount > 1 and VDist2(endPos[1], endPos[3], node.position[1], node.position[3]) < 20 then  
            continue
        end
        table.insert(finalPath, node.position)
    end

    -- return the path
    return finalPath, 'PathOK'
end

function EngineerGeneratePathRNG(aiBrain, startNode, endNode, threatType, threatWeight, endPos, startPos)
    threatWeight = threatWeight or 1
    -- Check if we have this path already cached.
    if aiBrain.PathCache[startNode.name][endNode.name][threatWeight].path then
        -- Path is not older then 30 seconds. Is it a bad path? (the path is too dangerous)
        if aiBrain.PathCache[startNode.name][endNode.name][threatWeight].path == 'bad' then
            -- We can't move this way at the moment. Too dangerous.
            return false
        else
            -- The cached path is newer then 30 seconds and not bad. Sounds good :) use it.
            return aiBrain.PathCache[startNode.name][endNode.name][threatWeight].path
        end
    end
    -- loop over all path's and remove any path from the cache table that is older then 30 seconds
    if aiBrain.PathCache then
        local GameTime = GetGameTimeSeconds()
        -- loop over all cached paths
        for StartNodeName, CachedPaths in aiBrain.PathCache do
            -- loop over all paths starting from StartNode
            for EndNodeName, ThreatWeightedPaths in CachedPaths do
                -- loop over every path from StartNode to EndNode stored by ThreatWeight
                for ThreatWeight, PathNodes in ThreatWeightedPaths do
                    -- check if the path is older then 30 seconds.
                    if GameTime - 30 > PathNodes.settime then
                        --LOG('* AI-RNG: GeneratePathRNG() Found old path: storetime: '..PathNodes.settime..' store+60sec: '..(PathNodes.settime + 30)..' actual time: '..GameTime..' timediff= '..(PathNodes.settime + 30 - GameTime) )
                        -- delete the old path from the cache.
                        aiBrain.PathCache[StartNodeName][EndNodeName][ThreatWeight] = nil
                    end
                end
            end
        end
    end
    -- We don't have a path that is newer then 30 seconds. Let's generate a new one.
    --Create path cache table. Paths are stored in this table and saved for 30 seconds, so
    --any other platoons needing to travel the same route can get the path without any extra work.
    aiBrain.PathCache = aiBrain.PathCache or {}
    aiBrain.PathCache[startNode.name] = aiBrain.PathCache[startNode.name] or {}
    aiBrain.PathCache[startNode.name][endNode.name] = aiBrain.PathCache[startNode.name][endNode.name] or {}
    aiBrain.PathCache[startNode.name][endNode.name][threatWeight] = {}
    local fork = {}
    -- Is the Start and End node the same OR is the distance to the first node longer then to the destination ?
    if startNode.name == endNode.name
    or VDist2(startPos[1], startPos[3], startNode.position[1], startNode.position[3]) > VDist2(startPos[1], startPos[3], endPos[1], endPos[3])
    or VDist2(startPos[1], startPos[3], endPos[1], endPos[3]) < 50 then
        -- store as path only our current destination.
        fork.path = { { position = endPos } }
        aiBrain.PathCache[startNode.name][endNode.name][threatWeight] = { settime = GetGameTimeSeconds(), path = fork }
        -- return the destination position as path
        return fork
    end
    -- Set up local variables for our path search
    local AlreadyChecked = {}
    local curPath = {}
    local lastNode = {}
    local newNode = {}
    local dist = 0
    local threat = 0
    local lowestpathkey = 1
    local lowestcost
    local tableindex = 0
    local armyIndex = aiBrain:GetArmyIndex()
    -- Get all the waypoints that are from the same movementlayer than the start point.
    local graph = GetPathGraphs()[startNode.layer][startNode.graphName]
    -- For the beginning we store the startNode here as first path node.
    local queue = {
        {
        cost = 0,
        path = {startNode},
        }
    }
    -- Now loop over all path's that are stored in queue. If we start, only the startNode is inside the queue
    -- (We are using here the "A*(Star) search algorithm". An extension of "Edsger Dijkstra's" pathfinding algorithm used by "Shakey the Robot" in 1959)
    while true do
        -- remove the table (shortest path) from the queue table and store the removed table in curPath
        -- (We remove the path from the queue here because if we don't find a adjacent marker and we
        --  have not reached the destination, then we no longer need this path. It's a dead end.)
        curPath = table.remove(queue,lowestpathkey)
        if not curPath then break end
        -- get the last node from the path, so we can check adjacent waypoints
        lastNode = curPath.path[table.getn(curPath.path)]
        -- Have we already checked this node for adjacenties ? then continue to the next node.
        if not AlreadyChecked[lastNode] then
            -- Check every node (marker) inside lastNode.adjacent
            for i, adjacentNode in lastNode.adjacent do
                -- get the node data from the graph table
                newNode = graph[adjacentNode]
                -- check, if we have found a node.
                if newNode then
                    -- copy the path from the startNode to the lastNode inside fork,
                    -- so we can add a new marker at the end and make a new path with it
                    fork = {
                        cost = curPath.cost,            -- cost from the startNode to the lastNode
                        path = {unpack(curPath.path)},  -- copy full path from starnode to the lastNode
                    }
                    -- get distance from new node to destination node
                    dist = VDist2(newNode.position[1], newNode.position[3], lastNode.position[1], lastNode.position[3])
                    -- get threat from current node to adjacent node
                    -- threat = Scenario.MasterChain._MASTERCHAIN_.Markers[newNode.name][armyIndex] or 0
                    local threat = aiBrain:GetThreatBetweenPositions(newNode.position, lastNode.position, nil, threatType)
                    -- add as cost for the path the path distance and threat to the overall cost from the whole path
                    fork.cost = fork.cost + dist + (threat * 1) * threatWeight
                    -- add the newNode at the end of the path
                    table.insert(fork.path, newNode)
                    -- check if we have reached our destination
                    if newNode.name == endNode.name then
                        -- store the path inside the path cache
                        aiBrain.PathCache[startNode.name][endNode.name][threatWeight] = { settime = GetGameTimeSeconds(), path = fork }
                        -- return the path
                        return fork
                    end
                    -- add the path to the queue, so we can check the adjacent nodes on the last added newNode
                    table.insert(queue,fork)
                end
            end
            -- Mark this node as checked
            AlreadyChecked[lastNode] = true
        end
        -- Search for the shortest / safest path and store the table key in lowestpathkey
        lowestcost = 100000000
        lowestpathkey = 1
        tableindex = 1
        while queue[tableindex].cost do
            if lowestcost > queue[tableindex].cost then
                lowestcost = queue[tableindex].cost
                lowestpathkey = tableindex
            end
            tableindex = tableindex + 1
        end
    end
    -- At this point we have not found any path to the destination.
    -- The path is to dangerous at the moment (or there is no path at all). We will check this again in 30 seconds.
    aiBrain.PathCache[startNode.name][endNode.name][threatWeight] = { settime = GetGameTimeSeconds(), path = 'bad' }
    return false
end

function CanGraphToRNG(startPos, destPos, layer)
    local startNode = GetClosestPathNodeInRadiusByLayer(startPos, 100, layer)
    local endNode = false

    if startNode then
        endNode = GetClosestPathNodeInRadiusByGraph(destPos, 100, startNode.graphName)
    end

    if endNode then
        return true, endNode.Position
    end
end

function SendPlatoonWithTransportsNoCheckRNG(aiBrain, platoon, destination, bRequired, bSkipLastMove)

    GetMostRestrictiveLayer(platoon)

    local units = platoon:GetPlatoonUnits()

    # only get transports for land (or partial land) movement
    if platoon.MovementLayer == 'Land' or platoon.MovementLayer == 'Amphibious' then

        -- DUNCAN - commented out, why check it?
        -- UVESO - If we reach this point, then we have either a platoon with Land or Amphibious MovementLayer.
        --         Both are valid if we have a Land destination point. But if we have a Amphibious destination
        --         point then we don't want to transport landunits.
        --         (This only happens on maps without AI path markers. Path graphing would prevent this.)
        if platoon.MovementLayer == 'Land' then
            local terrain = GetTerrainHeight(destination[1], destination[2])
            local surface = GetSurfaceHeight(destination[1], destination[2])
            if terrain < surface then
                return false
            end
        end

        # if we don't *need* transports, then just call GetTransports...
        if not bRequired then
            #  if it doesn't work, tell the aiBrain we want transports and bail
            if AIUtils.GetTransports(platoon) == false then
                aiBrain.WantTransports = true
                return false
            end
        else
            # we were told that transports are the only way to get where we want to go...
            # ask for a transport every 10 seconds
            local counter = 0
            local transportsNeeded = AIUtils.GetNumTransports(units)
            local numTransportsNeeded = math.ceil((transportsNeeded.Small + (transportsNeeded.Medium * 2) + (transportsNeeded.Large * 4)) / 10)
            if not aiBrain.NeedTransports then
                aiBrain.NeedTransports = 0
            end
            aiBrain.NeedTransports = aiBrain.NeedTransports + numTransportsNeeded
            if aiBrain.NeedTransports > 10 then
                aiBrain.NeedTransports = 10
            end
            
            local bUsedTransports, overflowSm, overflowMd, overflowLg = AIUtils.GetTransports(platoon)
            while not bUsedTransports and counter < 9 do #DUNCAN - was 6
                # if we have overflow, dump the overflow and just send what we can
                if not bUsedTransports and overflowSm+overflowMd+overflowLg > 0 then
                    local goodunits, overflow = AIUtils.SplitTransportOverflow(units, overflowSm, overflowMd, overflowLg)
                    local numOverflow = table.getn(overflow)
                    if table.getn(goodunits) > numOverflow and numOverflow > 0 then
                        --LOG('numOverflow is '..numOverflow)
                        local pool = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
                        for _,v in overflow do
                            if not v.Dead then
                                aiBrain:AssignUnitsToPlatoon(pool, {v}, 'Unassigned', 'None')
                            end
                        end
                        units = goodunits
                    end
                end
                bUsedTransports, overflowSm, overflowMd, overflowLg = AIUtils.GetTransports(platoon)
                if bUsedTransports then
                    break
                end
                counter = counter + 1
                --LOG('Counter is now '..counter..'Waiting 10 seconds')
                --LOG('Eng Build Queue is '..table.getn(units[1].EngineerBuildQueue))
                WaitSeconds(10)
                if not aiBrain:PlatoonExists(platoon) then
                    aiBrain.NeedTransports = aiBrain.NeedTransports - numTransportsNeeded
                    if aiBrain.NeedTransports < 0 then
                        aiBrain.NeedTransports = 0
                    end
                    return false
                end

                local survivors = {}
                for _,v in units do
                    if not v.Dead then
                        table.insert(survivors, v)
                    end
                end
                units = survivors

            end
            --LOG('End while loop for bUsedTransports')

            aiBrain.NeedTransports = aiBrain.NeedTransports - numTransportsNeeded
            if aiBrain.NeedTransports < 0 then
                aiBrain.NeedTransports = 0
            end

            -- couldn't use transports...
            if bUsedTransports == false then
                return false
            end
        end

        -- presumably, if we're here, we've gotten transports
        local transportLocation = false

        --DUNCAN - try the destination directly? Only do for engineers (eg skip last move is true)
        if bSkipLastMove then
            transportLocation = destination
        end
        --DUNCAN - try the land path nodefirst , not the transport marker as this will get units closer(thanks to Sorian).
        if not transportLocation then
            transportLocation = AIUtils.AIGetClosestMarkerLocation(aiBrain, 'Land Path Node', destination[1], destination[3])
        end
        -- find an appropriate transport marker if it's on the map
        if not transportLocation then
            transportLocation = AIUtils.AIGetClosestMarkerLocation(aiBrain, 'Transport Marker', destination[1], destination[3])
        end

        local useGraph = 'Land'
        if not transportLocation then
            # go directly to destination, do not pass go.  This move might kill you, fyi.
            transportLocation = AIUtils.RandomLocation(destination[1],destination[3]) #Duncan - was platoon:GetPlatoonPosition()
            useGraph = 'Air'
        end

        if transportLocation then
            local minThreat = aiBrain:GetThreatAtPosition(transportLocation, 0, true)
            if minThreat > 0 then
                local threatTable = aiBrain:GetThreatsAroundPosition(transportLocation, 1, true, 'Overall')
                for threatIdx,threatEntry in threatTable do
                    if threatEntry[3] < minThreat then
                        -- if it's land...
                        local terrain = GetTerrainHeight(threatEntry[1], threatEntry[2])
                        local surface = GetSurfaceHeight(threatEntry[1], threatEntry[2])
                        if terrain >= surface  then
                           minThreat = threatEntry[3]
                           transportLocation = {threatEntry[1], 0, threatEntry[2]}
                       end
                    end
                end
            end
        end

        -- path from transport drop off to end location
        local path, reason = PlatoonGenerateSafePathTo(aiBrain, useGraph, transportLocation, destination, 200)
        -- use the transport!
        AIUtils.UseTransports(units, platoon:GetSquadUnits('Scout'), transportLocation, platoon)

        -- just in case we're still landing...
        for _,v in units do
            if not v.Dead then
                if v:IsUnitState('Attached') then
                   WaitSeconds(2)
                end
            end
        end

        -- check to see we're still around
        if not platoon or not aiBrain:PlatoonExists(platoon) then
            return false
        end

        # then go to attack location
        if not path then
            # directly
            if not bSkipLastMove then
                platoon:AggressiveMoveToLocation(destination)
                platoon.LastAttackDestination = {destination}
            end
        else
            # or indirectly
            # store path for future comparison
            platoon.LastAttackDestination = path

            local pathSize = table.getn(path)
            #move to destination afterwards
            for wpidx,waypointPath in path do
                if wpidx == pathSize then
                    if not bSkipLastMove then
                        platoon:AggressiveMoveToLocation(waypointPath)
                    end
                else
                    platoon:MoveToLocation(waypointPath, false)
                end
            end
        end
    else
        return false
    end

    return true
end