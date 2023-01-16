WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] * RNGAI: offset aiattackutilities.lua' )
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG
--local GetDirectionInDegrees = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetDirectionInDegrees
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetThreatBetweenPositions = moho.aibrain_methods.GetThreatBetweenPositions
local AIUtils = import('/lua/ai/AIUtilities.lua')
local NavUtils = import('/lua/sim/NavUtils.lua')
local RNGPOW = math.pow
local RNGSQRT = math.sqrt
local RNGGETN = table.getn
local RNGINSERT = table.insert
local RNGREMOVE = table.remove
local RNGSORT = table.sort
local RNGFLOOR = math.floor
local RNGCEIL = math.ceil
local RNGPI = math.pi
local RNGCAT = table.cat

function EngineerGenerateSafePathToRNG(aiBrain, platoonLayer, startPos, endPos, optThreatWeight, optMaxMarkerDist)
    local VDist2Sq = VDist2Sq
    if not GetPathGraphsRNG()[platoonLayer] then
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
        if i == 1 and NodeCount > 1 and VDist2Sq(startPos[1], startPos[3], node.position[1], node.position[3]) < 900 then  
            continue
        end
        -- IF this is the last AND not the only waypoint AND its nearer 20 THEN continue and don't add it to the finalpath
        if i == NodeCount and NodeCount > 1 and VDist2Sq(endPos[1], endPos[3], node.position[1], node.position[3]) < 400 then  
            continue
        end
        RNGINSERT(finalPath, node.position)
    end

    -- return the path
    return finalPath, 'PathOK'
end

function EngineerGeneratePathRNG(aiBrain, startNode, endNode, threatType, threatWeight, endPos, startPos, platoonLayer)
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
                        --RNGLOG('* AI-RNG: GeneratePathRNG() Found old path: storetime: '..PathNodes.settime..' store+60sec: '..(PathNodes.settime + 30)..' actual time: '..GameTime..' timediff= '..(PathNodes.settime + 30 - GameTime) )
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
    or VDist2Sq(startPos[1], startPos[3], startNode.position[1], startNode.position[3]) > VDist2Sq(startPos[1], startPos[3], endPos[1], endPos[3])
    or VDist2Sq(startPos[1], startPos[3], endPos[1], endPos[3]) < 2500 and NavUtils.CanPathTo(platoonLayer, startPos, endPos) then
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
    local graph = GetPathGraphsRNG()[startNode.layer][startNode.graphName]
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
                    RNGINSERT(fork.path, newNode)
                    -- check if we have reached our destination
                    if newNode.name == endNode.name then
                        -- store the path inside the path cache
                        aiBrain.PathCache[startNode.name][endNode.name][threatWeight] = { settime = GetGameTimeSeconds(), path = fork }
                        -- return the path
                        return fork
                    end
                    -- add the path to the queue, so we can check the adjacent nodes on the last added newNode
                    RNGINSERT(queue,fork)
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

function PlatoonGenerateSafePathToRNG(aiBrain, platoonLayer, start, destination, optThreatWeight, optMaxMarkerDist, testPathDist, acuPath)
    -- if we don't have markers for the platoonLayer, then we can't build a path.
    if not GetPathGraphsRNG()[platoonLayer] then
        return false, 'NoGraph'
    end
    local location = start
    optMaxMarkerDist = optMaxMarkerDist or 250
    optThreatWeight = optThreatWeight or 1
    local finalPath = {}

    if testPathDist and VDist2Sq(start[1], start[3], destination[1], destination[3]) <= testPathDist then
        RNGINSERT(finalPath, destination)
        return finalPath
    end

    --Get the closest path node at the platoon's position
    local startNode

    startNode = GetClosestPathNodeInRadiusByLayer(location, optMaxMarkerDist, platoonLayer)
    if not startNode then return false, 'NoStartNode' end

    --Get the matching path node at the destiantion
    local endNode

    endNode = GetClosestPathNodeInRadiusByGraph(destination, optMaxMarkerDist, startNode.graphName)
    if not endNode then return false, 'NoEndNode' end

    --Generate the safest path between the start and destination
    local path
    path = GeneratePathRNG(aiBrain, startNode, endNode, ThreatTable[platoonLayer], optThreatWeight, destination, location, platoonLayer, acuPath)

    if not path then return false, 'NoPath' end
    -- Insert the path nodes (minus the start node and end nodes, which are close enough to our start and destination) into our command queue.
    for i,node in path.path do
        if i > 1 and i < table.getn(path.path) then
            RNGINSERT(finalPath, node.position)
        end
    end

    RNGINSERT(finalPath, destination)

    return finalPath, false, path.totalThreat
end

function PlatoonGeneratePathToRNG(aiBrain, platoonLayer, start, destination, optMaxMarkerDist, testPathDist)
    -- if we don't have markers for the platoonLayer, then we can't build a path.
    if not GetPathGraphsRNG()[platoonLayer] then
        return false, 'NoGraph'
    end
    local location = start
    optMaxMarkerDist = optMaxMarkerDist or 250
    local finalPath = {}

    --If we are within 100 units of the destination, don't bother pathing. (Sorian and Duncan AI)
    if (testPathDist and VDist2Sq(start[1], start[3], destination[1], destination[3]) <= testPathDist) then
        RNGINSERT(finalPath, destination)
        return finalPath
    end

    --Get the closest path node at the platoon's position
    local startNode

    startNode = GetClosestPathNodeInRadiusByLayer(location, optMaxMarkerDist, platoonLayer)
    if not startNode then return false, 'NoStartNode' end

    --Get the matching path node at the destiantion
    local endNode

    endNode = GetClosestPathNodeInRadiusByGraph(destination, optMaxMarkerDist, startNode.graphName)
    if not endNode then return false, 'NoEndNode' end

    --Generate the safest path between the start and destination
    local path
    path = GeneratePathNoThreatRNG(aiBrain, startNode, endNode, destination, location, platoonLayer)

    if not path then return false, 'NoPath' end
    -- Insert the path nodes (minus the start node and end nodes, which are close enough to our start and destination) into our command queue.
    for i,node in path.path do
        if i > 1 and i < table.getn(path.path) then
            RNGINSERT(finalPath, node.position)
        end
    end

    RNGINSERT(finalPath, destination)

    return finalPath, false
end

function GeneratePathRNG(aiBrain, startNode, endNode, threatType, threatWeight, endPos, startPos, platoonLayer, acuPath)
    local VDist2 = VDist2
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
    local mapSizeX = ScenarioInfo.size[1]
    local mapSizeZ = ScenarioInfo.size[2]
    -- Get all the waypoints that are from the same movementlayer than the start point.
    local graph = GetPathGraphsRNG()[startNode.layer][startNode.graphName]
    -- For the beginning we store the startNode here as first path node.
    local queue = {
        {
        cost = 0,
        path = {startNode},
        totalThreat = 0
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
                        path = {unpack(curPath.path)}, -- copy full path from starnode to the lastNode
                        totalThreat = curPath.totalThreat  -- total threat across the path
                    }
                    -- get distance from new node to destination node
                    dist = VDist2(newNode.position[1], newNode.position[3], endNode.position[1], endNode.position[3])
                    -- this brings the dist value from 0 to 100% of the maximum length with can travel on a map
                    dist = 100 * dist / ( mapSizeX + mapSizeZ )
                    -- get threat from current node to adjacent node
                    if platoonLayer == 'Air' or acuPath then
                        threat = GetThreatAtPosition(aiBrain, newNode.position, aiBrain.BrainIntel.IMAPConfig.Rings, true, threatType)
                    else
                        threat = GetThreatBetweenPositions(aiBrain, newNode.position, lastNode.position, nil, threatType)
                    end
                    -- add as cost for the path the distance and threat to the overall cost from the whole path
                    fork.cost = fork.cost + dist + (threat * threatWeight)
                    fork.totalThreat = fork.totalThreat + threat
                    -- add the newNode at the end of the path
                    RNGINSERT(fork.path, newNode)
                    -- check if we have reached our destination
                    if newNode.name == endNode.name then
                        -- store the path inside the path cache
                        aiBrain.PathCache[startNode.name][endNode.name][threatWeight] = { settime = GetGameTimeSeconds(), path = fork }
                        fork.pathLength = table.getn(fork.path)
                        -- return the path
                        return fork
                    end
                    -- add the path to the queue, so we can check the adjacent nodes on the last added newNode
                    RNGINSERT(queue,fork)
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
    --RNGLOG('GeneratePath, no path found')
    return false
end

function GetPathGraphsRNG()
    if ScenarioInfo.PathGraphsRNG then
        return ScenarioInfo.PathGraphsRNG
    else
        if ScenarioInfo.MarkersInfectedRNG then
            ScenarioInfo.PathGraphsRNG = {}
        else 
            return false
        end
    end

    local markerGroups = {
        Land = AIUtils.AIGetMarkerLocationsEx(nil, 'Land Path Node') or {},
        Water = AIUtils.AIGetMarkerLocationsEx(nil, 'Water Path Node') or {},
        Air = AIUtils.AIGetMarkerLocationsEx(nil, 'Air Path Node') or {},
        Amphibious = AIUtils.AIGetMarkerLocationsEx(nil, 'Amphibious Path Node') or {},
    }

    for gk, markerGroup in markerGroups do
        for mk, marker in markerGroup do
            --Create stuff if it doesn't exist
            ScenarioInfo.PathGraphsRNG[gk] = ScenarioInfo.PathGraphsRNG[gk] or {}
            ScenarioInfo.PathGraphsRNG[gk][marker.graph] = ScenarioInfo.PathGraphsRNG[gk][marker.graph] or {}
            -- If the marker has no adjacentTo then don't use it. We can't build a path with this node.
            if not (marker.adjacentTo) then
                WARN('*AI DEBUG: GetPathGraphsRNG(): Path Node '..marker.name..' has no adjacentTo entry!')
                continue
            end
            --Add the marker to the graph.
            ScenarioInfo.PathGraphsRNG[gk][marker.graph][marker.name] = {name = marker.name, layer = gk, graphName = marker.graph, position = marker.position, RNGArea = marker.RNGArea, BestArmy = marker.bestarmy ,adjacent = STR_GetTokens(marker.adjacentTo, ' '), color = marker.color}
        end
    end

    return ScenarioInfo.PathGraphsRNG or {}
end

function GetClosestPathNodeInRadiusByLayerRNG(location, radius, layer)

    local bestDist = radius*radius
    local bestMarker = false

    local graphTable =  GetPathGraphsRNG()[layer]
    if graphTable == false then
        --RNGLOG('graphTable doesnt exist yet')
        return false
    end

    if graphTable then
        for name, graph in graphTable do
            for mn, markerInfo in graph do
                local dist2 = VDist2Sq(location[1], location[3], markerInfo.position[1], markerInfo.position[3])

                if dist2 < bestDist then
                    bestDist = dist2
                    bestMarker = markerInfo
                end
            end
        end
    end

    return bestMarker
end

function GetClosestPathNodeInRadiusByGraphRNG(location, radius, graphName)
    local bestDist = radius*radius
    local bestMarker = false

    for graphLayer, graphTable in GetPathGraphsRNG() do
        for name, graph in graphTable do
            if graphName == name then
                for mn, markerInfo in graph do
                    local dist2 = VDist2Sq(location[1], location[3], markerInfo.position[1], markerInfo.position[3])

                    if dist2 < bestDist then
                        bestDist = dist2
                        bestMarker = markerInfo
                    end
                end
            end
        end
    end

    return bestMarker
end

function CanGraphToRNG(startPos, destPos, layer)
    local startNode = GetClosestPathNodeInRadiusByLayerRNG(startPos, 100, layer)
    local endNode = false

    if startNode then
        endNode = GetClosestPathNodeInRadiusByGraphRNG(destPos, 100, startNode.graphName)
    end

    if endNode then
        if startNode.RNGArea == endNode.RNGArea then
            --RNGLOG('CanGraphToIsTrue for area '..startNode.RNGArea)
            return true, endNode.Position
        else
            --RNGLOG('CanGraphToIsFalse for start area '..startNode.RNGArea..' and end area of '..endNode.RNGArea)
        end
    end
    return false
end

function SendPlatoonWithTransportsNoCheckRNG(aiBrain, platoon, destination, t1EngOnly, bRequired, bSkipLastMove, safeZone)

    if not platoon.MovementLayer then
        GetMostRestrictiveLayerRNG(platoon)
    end

    local units = platoon:GetPlatoonUnits()
    local transportplatoon = false
    local markerRange = 125
    local maxThreat = 200
    local airthreatMax = 20

    -- only get transports for land (or partial land) movement
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

        -- if we don't *need* transports, then just call GetTransports...
        if not bRequired then
            --  if it doesn't work, tell the aiBrain we want transports and bail
            if AIUtils.GetTransportsRNG(platoon, false, t1EngOnly) == false then
                aiBrain.WantTransports = true
                --RNGLOG('SendPlatoonWithTransportsNoCheckRNG returning false setting WantTransports')
                return false
            end
        else
            -- we were told that transports are the only way to get where we want to go...
            -- ask for a transport every 10 seconds
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
            
            local bUsedTransports, overflowSm, overflowMd, overflowLg = AIUtils.GetTransportsRNG(platoon, false, t1EngOnly)
            while not bUsedTransports and counter < 7 do --Set to 7, default is 6, 9 was previous.
                -- if we have overflow, dump the overflow and just send what we can
                if not bUsedTransports and overflowSm+overflowMd+overflowLg > 0 then
                    local goodunits, overflow = AIUtils.SplitTransportOverflow(units, overflowSm, overflowMd, overflowLg)
                    local numOverflow = table.getn(overflow)
                    if table.getn(goodunits) > numOverflow and numOverflow > 0 then
                        --RNGLOG('numOverflow is '..numOverflow)
                        local pool = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
                        for _,v in overflow do
                            if not v.Dead then
                                aiBrain:AssignUnitsToPlatoon(pool, {v}, 'Unassigned', 'None')
                            end
                        end
                        units = goodunits
                    end
                end
                bUsedTransports, overflowSm, overflowMd, overflowLg = AIUtils.GetTransportsRNG(platoon, false, t1EngOnly)
                if bUsedTransports then
                    break
                end
                counter = counter + 1
                --RNGLOG('Counter is now '..counter..'Waiting 10 seconds')
                --RNGLOG('Eng Build Queue is '..table.getn(units[1].EngineerBuildQueue))
                coroutine.yield(30)
                if not units[1].Dead and EntityCategoryContains(categories.ENGINEER - categories.COMMAND, units[1]) then
                    --RNGLOG('Run engineer wait during transport wait')
                    local eng = units[1]
                    local engPos = eng:GetPosition()
                    local reclaiming = false
                    if GetNumUnitsAroundPoint(aiBrain, categories.LAND * categories.ENGINEER * (categories.TECH1 + categories.TECH2), engPos, 10, 'Enemy') > 0 then
                        local enemyEngineer = GetUnitsAroundPoint(aiBrain, categories.LAND * categories.ENGINEER * (categories.TECH1 + categories.TECH2), engPos, 10, 'Enemy')
                        if enemyEngineer then
                            --RNGLOG('Enemy engineer found during transport wait')
                            local enemyEngPos
                            for _, unit in enemyEngineer do
                                if unit and not unit.Dead and unit:GetFractionComplete() == 1 then
                                    enemyEngPos = unit:GetPosition()
                                    if VDist2Sq(engPos[1], engPos[3], enemyEngPos[1], enemyEngPos[3]) < 100 then
                                        IssueStop({eng})
                                        IssueClearCommands({eng})
                                        IssueReclaim({eng}, enemyEngineer[1])
                                        break
                                    end
                                end
                            end
                        end
                    elseif aiBrain:GetEconomyStoredRatio('MASS') <= 0.80 then
                        local rect = Rect(engPos[1] - 10, engPos[3] - 10, engPos[1] + 10, engPos[3] + 10)
                        local reclaimRect = {}
                        reclaimRect = GetReclaimablesInRect(rect)
                        if reclaimRect and RNGGETN(reclaimRect) > 0 then
                            IssueClearCommands({eng})
                            --RNGLOG('Reclaim found during transport wait')
                            local reclaimCount = 0
                            for c, b in reclaimRect do
                                if reclaimCount > 15 then break end
                                if not IsProp(b) then continue end
                                local rpos = b.CachePosition
                                -- Start Blacklisted Props
                                if (b.MaxMassReclaim and b.MaxMassReclaim > 0) or (b.MaxEnergyReclaim and b.MaxEnergyReclaim > 10) then
                                    reclaimCount = reclaimCount + 1
                                    IssueReclaim({eng}, b)
                                    eng.Active = true
                                    reclaiming = true
                                end
                            end
                        end
                    end
                    if reclaiming then
                        coroutine.yield(60)
                        reclaiming = false
                        eng.Active = false
                    end
                end
                coroutine.yield(70)
                if not aiBrain:PlatoonExists(platoon) then
                    aiBrain.NeedTransports = aiBrain.NeedTransports - numTransportsNeeded
                    if aiBrain.NeedTransports < 0 then
                        aiBrain.NeedTransports = 0
                    end
                    --RNGLOG('SendPlatoonWithTransportsNoCheckRNG returning false no platoon exist')
                    return false
                end

                local survivors = {}
                for _,v in units do
                    if not v.Dead then
                        RNGINSERT(survivors, v)
                    end
                end
                units = survivors
            end
            --RNGLOG('End while loop for bUsedTransports')

            aiBrain.NeedTransports = aiBrain.NeedTransports - numTransportsNeeded
            if aiBrain.NeedTransports < 0 then
                aiBrain.NeedTransports = 0
            end

            -- couldn't use transports...
            if bUsedTransports == false then
                --RNGLOG('SendPlatoonWithTransportsNoCheckRNG returning false bUsedTransports')
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
            transportLocation = AIUtils.AIGetClosestMarkerLocationRNG(aiBrain, 'Land Path Node', destination[1], destination[3])
        end
        -- find an appropriate transport marker if it's on the map
        if not transportLocation then
            transportLocation = AIUtils.AIGetClosestMarkerLocationRNG(aiBrain, 'Transport Marker', destination[1], destination[3])
        end

        local useGraph = 'Land'
        if not transportLocation then
            -- go directly to destination, do not pass go.  This move might kill you, fyi.
            transportLocation = AIUtils.RandomLocation(destination[1],destination[3]) --Duncan - was platoon:GetPlatoonPosition()
            useGraph = 'Air'
        end

        if transportLocation then
            --RNGLOG('initial transport location is '..repr(transportLocation))
            local minThreat = aiBrain:GetThreatAtPosition(transportLocation, 0, true)
            --RNGLOG('Transport Location minThreat is '..minThreat)
            if (minThreat > 0) or safeZone then
                if platoon.MovementLayer == 'Amphibious' then
                    --RNGLOG('Find Safe Drop Amphib')
                    transportLocation = FindSafeDropZoneWithPathRNG(aiBrain, platoon, {'Amphibious Path Node','Land Path Node','Transport Marker'}, markerRange, destination, maxThreat, airthreatMax, 'AntiSurface', platoon.MovementLayer, safeZone)
                else
                    --RNGLOG('Find Safe Drop Non Amphib')
                    transportLocation = FindSafeDropZoneWithPathRNG(aiBrain, platoon, {'Land Path Node','Transport Marker'}, markerRange, destination, maxThreat, airthreatMax, 'AntiSurface', platoon.MovementLayer, safeZone)
                end
            end
            --RNGLOG('Decided transport location is '..repr(transportLocation))
        end

        if not transportLocation then
            --RNGLOG('No transport location or threat at location too high')
            return false
        end

        -- path from transport drop off to end location
        local path, reason = PlatoonGenerateSafePathToRNG(aiBrain, useGraph, transportLocation, destination, 200)
        -- use the transport!
        local transportSquad = platoon:GetSquadUnits('Scout')
        if not transportSquad then
            return false
        end
        for _, v in transportSquad do
            if not v.Dead and not EntityCategoryContains(categories.TRANSPORTFOCUS, v) then
                IssueStop({v})
                aiBrain:AssignUnitsToPlatoon('ArmyPool', {v}, 'Unassigned', 'NoFormation')
                --RNGLOG('Non transport in transport squad, assignined to armypool')
            end
        end
        AIUtils.UseTransportsRNG(units, transportSquad, transportLocation, platoon)

        -- just in case we're still landing...
        for _,v in units do
            if not v.Dead then
                if v:IsUnitState('Attached') then
                    coroutine.yield(20)
                end
            end
        end

        -- check to see we're still around
        if not platoon or not aiBrain:PlatoonExists(platoon) then
            --RNGLOG('SendPlatoonWithTransportsNoCheckRNG returning false platoon doesnt exist')
            return false
        end

        -- then go to attack location
        if not path then
            -- directly
            if not bSkipLastMove then
                platoon:AggressiveMoveToLocation(destination)
                platoon.LastAttackDestination = {destination}
            end
        else
            -- or indirectly
            -- store path for future comparison
            platoon.LastAttackDestination = path

            local pathSize = table.getn(path)
            --move to destination afterwards
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
        --RNGLOG('SendPlatoonWithTransportsNoCheckRNG returning false due to movement layer')
        return false
    end
    --RNGLOG('SendPlatoonWithTransportsNoCheckRNG returning true')
    return true
end

function GeneratePathNoThreatRNG(aiBrain, startNode, endNode, endPos, startPos)
    local threatWeight = 0
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
    or VDist2Sq(startPos[1], startPos[3], startNode.position[1], startNode.position[3]) > VDist2Sq(startPos[1], startPos[3], endPos[1], endPos[3])
    or VDist2Sq(startPos[1], startPos[3], endPos[1], endPos[3]) < 50*50 then
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
    local lowestpathkey = 1
    local lowestcost
    local tableindex = 0
    local mapSizeX = ScenarioInfo.size[1]
    local mapSizeZ = ScenarioInfo.size[2]
    -- Get all the waypoints that are from the same movementlayer than the start point.
    local graph = GetPathGraphsRNG()[startNode.layer][startNode.graphName]
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
                        path = {unpack(curPath.path)}, -- copy full path from starnode to the lastNode
                    }
                    -- get distance from new node to destination node
                    dist = VDist2(newNode.position[1], newNode.position[3], endNode.position[1], endNode.position[3])
                    -- this brings the dist value from 0 to 100% of the maximum length with can travel on a map
                    dist = 100 * dist / ( mapSizeX + mapSizeZ )
                    -- add as cost for the path the distance to the overall cost from the whole path
                    fork.cost = fork.cost + dist
                    -- add the newNode at the end of the path
                    RNGINSERT(fork.path, newNode)
                    -- check if we have reached our destination
                    if newNode.name == endNode.name then
                        -- store the path inside the path cache
                        aiBrain.PathCache[startNode.name][endNode.name][threatWeight] = { settime = GetGameTimeSeconds(), path = fork }
                        fork.pathLength = table.getn(fork.path)
                        -- return the path
                        return fork
                    end
                    -- add the path to the queue, so we can check the adjacent nodes on the last added newNode
                    RNGINSERT(queue,fork)
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
    -- We will check this again in 30 seconds.
    return false
end

-- Sproutos work

function GetRealThreatAtPosition(aiBrain, position, range )

    local sfake = GetThreatAtPosition( aiBrain, position, 0, true, 'AntiSurface' )
    local afake = GetThreatAtPosition( aiBrain, position, 0, true, 'AntiAir' )
    local bp
    local ALLBPS = __blueprints
    
    local airthreat = 0
    local surthreat = 0

    local eunits = GetUnitsAroundPoint( aiBrain, categories.ALLUNITS - categories.FACTORY - categories.ECONOMIC - categories.SHIELD - categories.WALL , position, range,  'Enemy')

    if eunits then

        for _,u in eunits do
    
            if not u.Dead then
        
                bp = ALLBPS[u.UnitId].Defense
            
                airthreat = airthreat + bp.AirThreatLevel
                surthreat = surthreat + bp.SurfaceThreatLevel
            end
        end
    end
    
    -- if there is IMAP threat and it's greater than what we actually see
    -- use the sum of both * .5
    if sfake > 0 and sfake > surthreat then
        surthreat = (surthreat + sfake) * .5
    end
    
    if afake > 0 and afake > airthreat then
        airthreat = (airthreat + afake) * .5
    end

    return surthreat, airthreat
end

-- Sproutos work
function FindSafeDropZoneWithPathRNG(aiBrain, platoon, markerTypes, markerrange, destination, threatMax, airthreatMax, threatType, layer, safeZone)

    local markerlist = {}
    local VDist2Sq = VDist2Sq

    -- locate the requested markers within markerrange of the supplied location	that the platoon can safely land at
    for _,v in markerTypes do
    
        markerlist = RNGCAT( markerlist, AIUtils.AIGetMarkersAroundLocationRNG(aiBrain, v, destination, markerrange, 0, threatMax, 0, 'AntiSurface') )
    end
    --RNGLOG('Marker List is '..repr(markerlist))
    
    -- sort the markers by closest distance to final destination
    if not safeZone then
        RNGSORT( markerlist, function(a,b) return VDist2Sq( a.Position[1],a.Position[3], destination[1],destination[3] ) < VDist2Sq( b.Position[1],b.Position[3], destination[1],destination[3] )  end )
    else
        RNGSORT( markerlist, function(a,b) return VDist2Sq( a.Position[1],a.Position[3], destination[1],destination[3] ) > VDist2Sq( b.Position[1],b.Position[3], destination[1],destination[3] )  end )
        --RNGLOG('SafeZone Sorted marker list '..repr(markerlist))
    end
   
    -- loop thru each marker -- see if you can form a safe path on the surface 
    -- and a safe path for the transports -- use the first one that satisfies both
    for _, v in markerlist do

        -- test the real values for that position
        local stest, atest = GetRealThreatAtPosition(aiBrain, v.Position, 75 )
        coroutine.yield(1)
        --RNGLOG('stest is '..stest..'atest is '..atest)

        if stest <= threatMax and atest <= airthreatMax then
            --RNGLOG("*AI DEBUG "..aiBrain.Nickname.." FINDSAFEDROP for "..repr(destination).." is testing "..repr(v.Position).." "..v.Name)
            --RNGLOG("*AI DEBUG "..aiBrain.Nickname.." "..platoon.BuilderName.." Position "..repr(v.Position).." says Surface threat is "..stest.." vs "..threatMax.." and Air threat is "..atest.." vs "..airthreatMax )
            --RNGLOG("*AI DEBUG "..aiBrain.Nickname.." "..platoon.BuilderName.." drop distance is "..repr( VDist3(destination, v.Position) ) )
            -- can the platoon path safely from this marker to the final destination 
            if NavUtils.CanPathTo(layer, v.Position, destination) then
                return v.Position, v.Name
            end
        end
    end
    --RNGLOG('Safe landing Location returning false')
    return false, nil
end

function NormalizeVector( v )
	if v.x then
		v = {v.x, v.y, v.z}
    end
    local length = math.sqrt( math.pow( v[1], 2 ) + math.pow( v[2], 2 ) + math.pow(v[3], 2 ) )

    if length > 0 then
        local invlength = 1 / length
        return Vector( v[1] * invlength, v[2] * invlength, v[3] * invlength )
    else
        return Vector( 0,0,0 )
    end
end

function GetDirectionVector( v1, v2 )
    return NormalizeVector( Vector(v1[1] - v2[1], v1[2] - v2[2], v1[3] - v2[3]) )
end

function GetDirectionInDegrees( v1, v2 )
	local vec = GetDirectionVector( v1, v2)

	if vec[1] >= 0 then
		return math.acos(vec[3]) * (360/(math.pi*2))
	end
	return 360 - (math.acos(vec[3]) * (360/(math.pi*2)))
end

function AIPlatoonSquadAttackVectorRNG(aiBrain, platoon, bAggro)

    --Engine handles whether or not we can occupy our vector now, so this should always be a valid, occupiable spot.
    local attackPos = GetBestThreatTarget(aiBrain, platoon)
    --RNGLOG('* AI-RNG: AttackForceAIRNG Platoon Squad Attack Vector starting')

    local bNeedTransports = false
    local PlatoonFormation = platoon.PlatoonData.UseFormation
    -- if no pathable attack spot found
    if not attackPos then
        -- try skipping pathability
        --RNGLOG('* AI-RNG: AttackForceAIRNG No attack position found')
        attackPos = GetBestThreatTarget(aiBrain, platoon, true)
        bNeedTransports = true
        if not attackPos then
            platoon:StopAttack()
            return {}
        end
    end


    -- avoid mountains by slowly moving away from higher areas
    GetMostRestrictiveLayerRNG(platoon)
    if platoon.MovementLayer == 'Land' then
        local bestPos = attackPos
        local attackPosHeight = GetTerrainHeight(attackPos[1], attackPos[3])
        -- if we're land
        if attackPosHeight >= GetSurfaceHeight(attackPos[1], attackPos[3]) then
            local lookAroundTable = {1,0,-2,-1,2}
            local squareRadius = (ScenarioInfo.size[1] / 16) / table.getn(lookAroundTable)
            for ix, offsetX in lookAroundTable do
                for iz, offsetZ in lookAroundTable do
                    local surf = GetSurfaceHeight(bestPos[1]+offsetX, bestPos[3]+offsetZ)
                    local terr = GetTerrainHeight(bestPos[1]+offsetX, bestPos[3]+offsetZ)
                    -- is it lower land... make it our new position to continue searching around
                    if terr >= surf and terr < attackPosHeight then
                        bestPos[1] = bestPos[1] + offsetX
                        bestPos[3] = bestPos[3] + offsetZ
                        attackPosHeight = terr
                    end
                end
            end
        end
        attackPos = bestPos
    end

    local oldPathSize = table.getn(platoon.LastAttackDestination)

    -- if we don't have an old path or our old destination and new destination are different
    if oldPathSize == 0 or attackPos[1] ~= platoon.LastAttackDestination[oldPathSize][1] or
    attackPos[3] ~= platoon.LastAttackDestination[oldPathSize][3] then

        GetMostRestrictiveLayerRNG(platoon)
        -- check if we can path to here safely... give a large threat weight to sort by threat first
        local path, reason = PlatoonGenerateSafePathToRNG(aiBrain, platoon.MovementLayer, platoon:GetPlatoonPosition(), attackPos, platoon.PlatoonData.NodeWeight or 10)

        -- clear command queue
        platoon:Stop()

        local usedTransports = false
        local position = platoon:GetPlatoonPosition()
        if (not path and reason == 'NoPath') or bNeedTransports then
            usedTransports = SendPlatoonWithTransportsNoCheckRNG(aiBrain, platoon, attackPos, false, true)
        -- Require transports over 500 away
        elseif VDist2Sq(position[1], position[3], attackPos[1], attackPos[3]) > 512*512 then
            usedTransports = SendPlatoonWithTransportsNoCheckRNG(aiBrain, platoon, attackPos, false, true)
        -- use if possible at 250
        elseif VDist2Sq(position[1], position[3], attackPos[1], attackPos[3]) > 256*256 then
            usedTransports = SendPlatoonWithTransportsNoCheckRNG(aiBrain, platoon, attackPos, false, false)
        end

        if not usedTransports then
            if not path then
                if reason == 'NoStartNode' or reason == 'NoEndNode' then
                    --Couldn't find a valid pathing node. Just use shortest path.
                    platoon:AggressiveMoveToLocation(attackPos)
                end
                -- force reevaluation
                platoon.LastAttackDestination = {attackPos}
            else
                --RNGLOG('* AI-RNG: AttackForceAIRNG not usedTransports starting movement queue')
                local pathSize = table.getn(path)
                local prevpoint = platoon:GetPlatoonPosition() or false
                -- store path
                platoon.LastAttackDestination = path
                -- move to new location
                for wpidx,waypointPath in path do
                    local direction = GetDirectionInDegrees( prevpoint, waypointPath )
                    --RNGLOG('* AI-RNG: AttackForceAIRNG direction is '..direction)
                    --RNGLOG('* AI-RNG: AttackForceAIRNG prevpoint is '..repr(prevpoint)..' waypointPath is '..repr(waypointPath))
                    if wpidx == pathSize or bAggro then
                        --platoon:AggressiveMoveToLocation(waypointPath)
                        IssueFormAggressiveMove( platoon:GetPlatoonUnits(), waypointPath, PlatoonFormation, direction)
                    else
                        --platoon:MoveToLocation(waypointPath, false)
                        IssueFormMove( platoon:GetPlatoonUnits(), waypointPath, PlatoonFormation, direction)
                    end
                    prevpoint = table.copy(waypointPath)
                end
            end
        end
    end

    -- return current command queue
    local cmd = {}
    for k,v in platoon:GetPlatoonUnits() do
        if not v.Dead then
            local unitCmdQ = v:GetCommandQueue()
            for cmdIdx,cmdVal in unitCmdQ do
                RNGINSERT(cmd, cmdVal)
                break
            end
        end
    end
    return cmd
end

function AIFindUnitRadiusThreatRNG(aiBrain, alliance, priTable, position, radius, tMin, tMax, tRing)
    local catTable = {}
    local unitTable = {}
    for k,v in priTable do
        RNGINSERT(catTable, v)
        RNGINSERT(unitTable, {})
    end

    local units = aiBrain:GetUnitsAroundPoint(categories.ALLUNITS, position, radius, alliance) or {}
    for num, unit in units do
        for tNum, catType in catTable do
            if EntityCategoryContains(catType, unit) then
                RNGINSERT(unitTable[tNum], unit)
                break
            end
        end
    end

    local checkThreat = false
    if tMin and tMax and tRing then
        checkThreat = true
    end

    local distance = false
    local retUnit = false
    for tNum, catList in unitTable do
        for num, unit in catList do
            if not unit.Dead then
                local unitPos = unit:GetPosition()
                local useUnit = true
                if checkThreat then
                    coroutine.yield(1)
                    local threat = aiBrain:GetThreatAtPosition(unitPos, tRing, true)
                    if not (threat >= tMin and threat <= tMax) then
                        useUnit = false
                    end
                end
                if useUnit then
                    local tempDist = VDist2(unitPos[1], unitPos[3], position[1], position[3])
                    if tempDist < radius and (not distance or tempDist < distance) then
                        distance = tempDist
                        retUnit = unit
                    end
                end
            end
        end
        if retUnit then
            return retUnit
        end
    end
end
-- This is Sproutos function for finding SMD's between launcher and target.
function AIFindNumberOfUnitsBetweenPointsRNG( aiBrain, start, finish, unitCat, stepby, alliance)
	local returnNum = 0
	-- number of steps to take based on distance divided by stepby ( min. 1)
	-- break the distance up into equal steps BUT each step is 125% of the stepby distance (so we reduce the overlap)
	local steps = math.floor( VDist2(start[1], start[3], finish[1], finish[3]) / (stepby * 1.25) ) + 1
	local xstep, ystep
	
	-- the distance of each step
	xstep = (start[1] - finish[1]) / steps
	ystep = (start[3] - finish[3]) / steps
	
    for i = 1, steps do
        local enemyAntiMissile = GetUnitsAroundPoint(aiBrain, unitCat, { start[1] - (xstep * i), 0, start[3] - (ystep * i) }, stepby, alliance)
        local siloCount = table.getn(enemyAntiMissile)
        --RNGLOG('Total Anti missile Count '..siloCount..' completion is ')
        if siloCount > 0 then
            for _, silo in enemyAntiMissile do
                --RNGLOG('Silo completed fraction is '..silo:GetFractionComplete())
                if silo and not silo.Dead and silo:GetFractionComplete() == 1 then
                    --RNGLOG('Completed Anti missile Detected')
                    returnNum = returnNum + 1
                end
            end
        end
	end
	return returnNum
end

function GetBestNavalTargetRNG(aiBrain, platoon, bSkipPathability)

    
    local PrimaryTargetThreatType = 'Naval'
    local SecondaryTargetThreatType = 'StructuresNotMex'
    --RNGLOG('GetBestNavalTargetRNG Running')


    -- These are the values that are used to weight the two types of "threats"
    -- primary by default is weighed most heavily, while a secondary threat is
    -- weighed less heavily
    local PrimaryThreatWeight = 20
    local SecondaryThreatWeight = 0.5

    -- After being sorted by those two types of threats, the places to attack are then
    -- sorted by distance.  So you don't have to worry about specifying that units go
    -- after the closest valid threat - they do this naturally.

    -- If the platoon we're sending is weaker than a potential target, lower
    -- the desirability of choosing that target by this factor
    local WeakAttackThreatWeight = 8

    -- If the platoon we're sending is stronger than a potential target, raise
    -- the desirability of choosing that target by this factor
    local StrongAttackThreatWeight = 8


    -- We can also tune the desirability of a target based on various
    -- distance thresholds.  The thresholds are very near, near, mid, far
    -- and very far.  The Radius value represents the largest distance considered
    -- in a given category; the weight is the multiplicative factor used to increase
    -- the desirability for the distance category

    local VeryNearThreatWeight = 20000
    local VeryNearThreatRadius = 25

    local NearThreatWeight = 2500
    local NearThreatRadius = 75

    local MidThreatWeight = 500
    local MidThreatRadius = 150

    local FarThreatWeight = 100
    local FarThreatRadius = 300

    -- anything that's farther than the FarThreatRadius is considered VeryFar
    local VeryFarThreatWeight = 1

    -- if the platoon is weaker than this threat level, then ignore stronger targets if they're stronger by
    -- the given ratio
    --DUNCAN - Changed from 5
    local IgnoreStrongerTargetsIfWeakerThan = 10
    local IgnoreStrongerTargetsRatio = 10.0
    -- If the platoon is weaker than the target, and the platoon represents a
    -- larger fraction of the unitcap this this value, then ignore
    -- the strength of target - the platoon's death brings more units
    local IgnoreStrongerUnitCap = 0.8

    -- When true, ignores the commander's strength in determining defenses at target location
    local IgnoreCommanderStrength = true

    -- If the combined threat of both primary and secondary threat types
    -- is less than this level, then just outright ignore it as a threat
    local IgnoreThreatLessThan = 5
    -- if the platoon is stronger than this threat level, then ignore weaker targets if the platoon is stronger
    -- by the given ratio
    local IgnoreWeakerTargetsIfStrongerThan = 20
    local IgnoreWeakerTargetsRatio = 5
    -- if we've already chosen an enemy, should this platoon focus on that enemy
    local TargetCurrentEnemy = true

    ----------------------------------------------------------------------------------

    local platoonPosition = platoon:GetPlatoonPosition()
    local selectedWeaponArc = 'None'

    if not platoonPosition then
        #Platoon no longer exists.
        --RNGLOG('GetBestNavalTarget platoon position is nil returned false ')
        return false
    end

    -- get overrides in platoon data
    local ThreatWeights = platoon.PlatoonData.ThreatWeights
    if ThreatWeights then
        PrimaryThreatWeight = ThreatWeights.PrimaryThreatWeight or PrimaryThreatWeight
        SecondaryThreatWeight = ThreatWeights.SecondaryThreatWeight or SecondaryThreatWeight
        WeakAttackThreatWeight = ThreatWeights.WeakAttackThreatWeight or WeakAttackThreatWeight
        StrongAttackThreatWeight = ThreatWeights.StrongAttackThreatWeight or StrongAttackThreatWeight
        FarThreatWeight = ThreatWeights.FarThreatWeight or FarThreatWeight
        NearThreatWeight = ThreatWeights.NearThreatWeight or NearThreatWeight
        NearThreatRadius = ThreatWeights.NearThreatRadius or NearThreatRadius
        IgnoreStrongerTargetsIfWeakerThan = ThreatWeights.IgnoreStrongerTargetsIfWeakerThan or IgnoreStrongerTargetsIfWeakerThan
        IgnoreStrongerTargetsRatio = ThreatWeights.IgnoreStrongerTargetsRatio or IgnoreStrongerTargetsRatio
        SecondaryTargetThreatType = SecondaryTargetThreatType or ThreatWeights.SecondaryTargetThreatType
        IgnoreWeakerTargetsIfStrongerThan = ThreatWeights.IgnoreWeakerTargetsIfStrongerThan or IgnoreWeakerTargetsIfStrongerThan
        IgnoreWeakerTargetsRatio = ThreatWeights.IgnoreWeakerTargetsRatio or IgnoreWeakerTargetsRatio
        IgnoreThreatLessThan = ThreatWeights.IgnoreThreatLessThan or IgnoreThreatLessThan
        PrimaryTargetThreatType = ThreatWeights.PrimaryTargetThreatType or PrimaryTargetThreatType
        SecondaryTargetThreatType = ThreatWeights.SecondaryTargetThreatType or SecondaryTargetThreatType
        TargetCurrentEnemy = ThreatWeights.TargetCurrentyEnemy or TargetCurrentEnemy
    end

    -- Need to use overall so we can get all the threat points on the map and then filter from there
    -- if a specific threat is used, it will only report back threat locations of that type
    local enemyIndex = -1
    if aiBrain:GetCurrentEnemy() and TargetCurrentEnemy then
        enemyIndex = aiBrain:GetCurrentEnemy():GetArmyIndex()
    end
    
    local threatTable = aiBrain:GetThreatsAroundPosition(platoonPosition, 16, true, 'OverallNotAssigned', enemyIndex)

    if table.empty(threatTable) then
        --RNGLOG('GetBestNavalTarget threat table is empty returned false ')
        return false
    end

    local platoonUnits = platoon:GetPlatoonUnits()
    #eval platoon threat
    local myThreat = GetThreatOfUnits(platoon)
    --RNGLOG('GetBestNavalTarget myThreat is '..myThreat)
    local friendlyThreat = aiBrain:GetThreatAtPosition(platoonPosition, aiBrain.BrainIntel.IMAPConfig.Rings, true, ThreatTable[platoon.MovementLayer], aiBrain:GetArmyIndex()) - myThreat
    friendlyThreat = friendlyThreat * -1
    --RNGLOG('GetBestNavalTarget friendlyThreat is '..friendlyThreat)

    local threatDist
    local curMaxThreat = -99999999
    local curMaxIndex = 1
    local foundPathableThreat = false
    local mapSizeX = ScenarioInfo.size[1]
    local mapSizeZ = ScenarioInfo.size[2]
    local maxMapLengthSq = math.sqrt((mapSizeX * mapSizeX) + (mapSizeZ * mapSizeZ))
    local logCount = 0

    local unitCapRatio = GetArmyUnitCostTotal(aiBrain:GetArmyIndex()) / GetArmyUnitCap(aiBrain:GetArmyIndex())

    local maxRange = false
    local turretPitch = nil
    if platoon.MovementLayer == 'Water' then
        maxRange, selectedWeaponArc = GetNavalPlatoonMaxRange(aiBrain, platoon)
    end
    --RNGLOG('GetBestNavalTarget final threat table was '..repr(threatTable))

    for tIndex,threat in threatTable do
        --check if we can path to the position or a position nearby
        if not bSkipPathability then

            local bestPos
            bestPos = CheckNavalPathingRNG(aiBrain, platoon, {threat[1], 0, threat[2]}, maxRange, selectedWeaponArc)
            if not bestPos then
                continue
            end
        end

        --threat[3] represents the best target

        -- calculate new threat
        -- for debugging

        local baseThreat = 0
        local targetThreat = 0
        local distThreat = 0

        local primaryThreat = 0
        local secondaryThreat = 0


        -- Determine the value of the target
        primaryThreat = aiBrain:GetThreatAtPosition({threat[1], 0, threat[2]}, aiBrain.BrainIntel.IMAPConfig.Rings, true, PrimaryTargetThreatType, enemyIndex)
        -- update : we are testing no longer multiplying since they are updating to threat numbers on everything.
        -- We are multipling the structure threat because the default threat allocation is shit. A T1 naval factory is only worth 3 threat which is not enough to make
        -- frigates / subs want to attack them over something else.
        secondaryThreat = aiBrain:GetThreatAtPosition({threat[1], 0, threat[2]}, aiBrain.BrainIntel.IMAPConfig.Rings, true, SecondaryTargetThreatType, enemyIndex)
        --RNGLOG('GetBestNavalTarget Primary Threat is '..primaryThreat..' secondaryThreat is '..secondaryThreat)

        baseThreat = primaryThreat + secondaryThreat

        targetThreat = (primaryThreat or 0) * PrimaryThreatWeight + (secondaryThreat or 0) * SecondaryThreatWeight
        threat[3] = targetThreat

        -- Determine relative strength of platoon compared to enemy threat
        local enemyThreat = aiBrain:GetThreatAtPosition({threat[1], 0, threat[2]}, aiBrain.BrainIntel.IMAPConfig.Rings, true, ThreatTable[platoon.MovementLayer] or 'AntiSurface')

        --defaults to no threat (threat difference is opposite of platoon threat)
        local threatDiff =  myThreat - enemyThreat

        --DUNCAN - Moved outside threatdiff check
        -- if we have no threat... what happened?  Also don't attack things way stronger than us
        if myThreat <= IgnoreStrongerTargetsIfWeakerThan
                and (myThreat == 0 or enemyThreat / (myThreat + friendlyThreat) > IgnoreStrongerTargetsRatio)
                and unitCapRatio < IgnoreStrongerUnitCap then
            --RNGLOG('*AI DEBUG: Skipping threat')
            continue
        end

        if threatDiff <= 0 then
            -- if we're weaker than the enemy... make the target less attractive anyway
            threat[3] = threat[3] + threatDiff * WeakAttackThreatWeight
        else
            -- ignore overall threats that are really low, otherwise we want to defeat the enemy wherever they are
            if (baseThreat <= IgnoreThreatLessThan) or (myThreat >= IgnoreWeakerTargetsIfStrongerThan and (enemyThreat == 0 or myThreat / enemyThreat > IgnoreWeakerTargetsRatio)) then
                continue
            end
            threat[3] = threat[3] + threatDiff * StrongAttackThreatWeight
        end

        -- only add distance if there's a threat at all
        local threatDistNorm = -1
        if targetThreat > 0 then
            threatDist = math.sqrt(VDist2Sq(threat[1], threat[2], platoonPosition[1], platoonPosition[3]))
            --distance is 1-100 of the max map length, distance function weights are split by the distance radius

            threatDistNorm = 100 * threatDist / maxMapLengthSq
            if threatDistNorm < 1 then
                threatDistNorm = 1
            end
            -- farther away is less threatening, so divide
            if threatDist <= VeryNearThreatRadius then
                threat[3] = threat[3] + VeryNearThreatWeight / threatDistNorm
                distThreat = VeryNearThreatWeight / threatDistNorm
            elseif threatDist <= NearThreatRadius then
                threat[3] = threat[3] + MidThreatWeight / threatDistNorm
                distThreat = MidThreatWeight / threatDistNorm
            elseif threatDist <= MidThreatRadius then
                threat[3] = threat[3] + NearThreatWeight / threatDistNorm
                distThreat = NearThreatWeight / threatDistNorm
            elseif threatDist <= FarThreatRadius then
                threat[3] = threat[3] + FarThreatWeight / threatDistNorm
                distThreat = FarThreatWeight / threatDistNorm
            else
                threat[3] = threat[3] + VeryFarThreatWeight / threatDistNorm
                distThreat = VeryFarThreatWeight / threatDistNorm
            end

            -- store max value
            if threat[3] > curMaxThreat then
                curMaxThreat = threat[3]
                curMaxIndex = tIndex
            end
            foundPathableThreat = true
       end --ignoreThreat
    end --threatTable loop

    --no pathable threat found (or no threats at all)
    if not foundPathableThreat or curMaxThreat == 0 then
        return false
    end
    local x = threatTable[curMaxIndex][1]
    local y = GetTerrainHeight(threatTable[curMaxIndex][1], threatTable[curMaxIndex][2])
    local z = threatTable[curMaxIndex][2]
    
    return {x, y, z}
end

function CheckNavalPathingRNG(aiBrain, platoon, location, maxRange, selectedWeaponArc)
    local platoonPosition = platoon:GetPlatoonPosition()
    selectedWeaponArc = selectedWeaponArc or 'none'

    local success, bestGoalPos
    local threatTargetPos = location
    local inWater = GetTerrainHeight(location[1], location[3]) < GetSurfaceHeight(location[1], location[3]) - 1.4

    --if this threat is in the water, see if we can get to it
    if inWater then
        --RNGLOG('Naval Location is in water')
        if NavUtils.CanPathTo(platoon.MovementLayer, platoonPosition, location) then
            bestGoalPos = location
            success = true
        end
    end

    --if it is not in the water or we can't get to it, then see if there is water within weapon range that we can get to
    if not success and maxRange then
        --Check vectors in 8 directions around the threat location at maxRange to see if they are in water.
        local rootSaver = maxRange / 1.4142135623 --For diagonals. X and Z components of the vector will have length maxRange / sqrt(2)
        local vectors = {
            {location[1],             0, location[3] + maxRange},   --up
            {location[1],             0, location[3] - maxRange},   --down
            {location[1] + maxRange,  0, location[3]},              --right
            {location[1] - maxRange,  0, location[3]},              --left

            {location[1] + rootSaver,  0, location[3] + rootSaver},   --right-up
            {location[1] + rootSaver,  0, location[3] - rootSaver},   --right-down
            {location[1] - rootSaver,  0, location[3] + rootSaver},   --left-up
            {location[1] - rootSaver,  0, location[3] - rootSaver},   --left-down
        }

        --Sort the vectors by their distance to us.
        table.sort(vectors, function(a,b)
            local distA = VDist2Sq(platoonPosition[1], platoonPosition[3], a[1], a[3])
            local distB = VDist2Sq(platoonPosition[1], platoonPosition[3], b[1], b[3])

            return distA < distB
        end)

        --Iterate through the vector list and check if each is in the water. Use the first one in the water that has enemy structures in range.
        for _,vec in vectors do
            inWater = GetTerrainHeight(vec[1], vec[3]) < GetSurfaceHeight(vec[1], vec[3]) - 2
            if inWater then
                if NavUtils.CanPathTo(platoon.MovementLayer, platoonPosition, vec) then
                    bestGoalPos = vec
                    success = true
                end
            end

            if success then
                success = not aiBrain:CheckBlockingTerrain(bestGoalPos, threatTargetPos, selectedWeaponArc)
            end

            if success then
                --I hate having to do this check, but the influence map doesn't have enough resolution and without it the boats
                --will just get stuck on the shore. The code hits this case about once every 5-10 seconds on a large map with 4 naval AIs
                local numUnits = aiBrain:GetNumUnitsAroundPoint(categories.NAVAL + categories.STRUCTURE, bestGoalPos, maxRange, 'Enemy')
                if numUnits > 0 then
                    break
                else
                    success = false
                end
            end
        end
    end
    if bestGoalPos then
        --RNGLOG('bestGoalPos returned is '..repr(bestGoalPos))
    else
        --RNGLOG('bestGoalPos is nil ')
    end

    return bestGoalPos
end

function GetMostRestrictiveLayerRNG(platoon)
    -- in case the platoon is already destroyed return false.
    if not platoon then
        return false
    end
    platoon.MovementLayer = 'Air'
    platoon.MappingMovementLayer = 0

    for k,v in platoon:GetPlatoonUnits() do
        if not v.Dead then
            local mType = v:GetBlueprint().Physics.MotionType
            if (mType == 'RULEUMT_AmphibiousFloating' or mType == 'RULEUMT_Hover' or mType == 'RULEUMT_Amphibious') and (platoon.MovementLayer == 'Air' or platoon.MovementLayer == 'Water') then
                platoon.MovementLayer = 'Amphibious'
                platoon.MappingMovementLayer = 3
            elseif (mType == 'RULEUMT_Water' or mType == 'RULEUMT_SurfacingSub') and (platoon.MovementLayer ~= 'Water') then
                platoon.MovementLayer = 'Water'
                platoon.MappingMovementLayer = 2
                break   --Nothing more restrictive than water, since there should be no mixed land/water platoons
            elseif mType == 'RULEUMT_Air' and platoon.MovementLayer == 'Air' then
                platoon.MovementLayer = 'Air'
                platoon.MappingMovementLayer = 0
            elseif (mType == 'RULEUMT_Biped' or mType == 'RULEUMT_Land') and platoon.MovementLayer ~= 'Land' then
                platoon.MovementLayer = 'Land'
                platoon.MappingMovementLayer = 1
                break   --Nothing more restrictive than land, since there should be no mixed land/water platoons
            end
        end
    end
    return true
end