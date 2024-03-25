WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] * RNGAI: offset aiattackutilities.lua' )
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG
--local GetDirectionInDegrees = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetDirectionInDegrees
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetThreatBetweenPositions = moho.aibrain_methods.GetThreatBetweenPositions
local TransportUtils = import("/mods/RNGAI/lua/AI/transportutilitiesrng.lua")
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

    local NavUtils = import("/lua/sim/navutils.lua")
    --Get the closest path node at the platoon's position
    optMaxMarkerDist = optMaxMarkerDist or 250
    optThreatWeight = optThreatWeight or 1

    --Generate the safest path between the start and destination
    local path, msg, distance, threats = NavUtils.PathToWithThreatThreshold(platoonLayer, startPos, endPos, aiBrain, NavUtils.ThreatFunctions.AntiSurface, 1000, aiBrain.BrainIntel.IMAPConfig.Rings)
    if not path then 
        return false, msg, distance, threats
    end

    -- Insert the path nodes (minus the start node and end nodes, which are close enough to our start and destination) into our command queue.
    -- delete the first and last node only if they are very near (under 30 map units) to the start or end destination.

    -- return the path
    return path, 'PathOK', distance
end

function PlatoonGenerateSafePathToRNG(aiBrain, platoonLayer, start, destination, optThreatWeight, optMaxMarkerDist, minPathDistance, acuPath)
    -- if we don't have markers for the platoonLayer, then we can't build a path.
    local NavUtils = import("/lua/sim/navutils.lua")
    optMaxMarkerDist = optMaxMarkerDist or 250
    optThreatWeight = optThreatWeight or 1
    local threatType = NavUtils.ThreatFunctions.AntiSurface
    if minPathDistance then
        minPathDistance = minPathDistance * minPathDistance
    else
        minPathDistance = 400
    end

    --If we are within 100 units of the destination, don't bother pathing. (Sorian and Duncan AI)
    if (minPathDistance and VDist2Sq(start[1], start[3], destination[1], destination[3]) <= minPathDistance) then
        return { destination }
    end
    if platoonLayer == 'Air' then
        threatType = NavUtils.ThreatFunctions.AntiAir
    end

    --Generate the safest path between the start and destination
    local path, msg, distance, threats = NavUtils.PathToWithThreatThreshold(platoonLayer, start, destination, aiBrain, threatType, 1000, aiBrain.BrainIntel.IMAPConfig.Rings)
    if not path then 
        if msg == 'TooMuchThreat' then
            -- We need to do something here
            -- Ideally the platoon needs to either be more powerful, or we need to completely change strategy.
            -- This returned the grid location of the threat that blocked the path which allows missions to clear it if possible.
            -- I'm thinking long range unit triggers, bomber, tml etc. Or just eco.
            LOG('Threats returned '..repr(threats))
        end
        LOG('No path from '..repr(start)..' to '..repr(destination)..' reason is '..repr(msg)..' platoon layer was '..platoonLayer)
        return false, msg, distance, threats
    end
    -- Insert the path nodes (minus the start node and end nodes, which are close enough to our start and destination) into our command queue.

    return path, 'PathOK', distance
end

function PlatoonGeneratePathToRNG(platoonLayer, start, destination, optMaxMarkerDist, minPathDistance)
    -- if we don't have markers for the platoonLayer, then we can't build a path.
    local NavUtils = import("/lua/sim/navutils.lua")
    optMaxMarkerDist = optMaxMarkerDist or 250
    if minPathDistance then
        minPathDistance = minPathDistance * minPathDistance
    else
        minPathDistance = 400
    end

    --If we are within 100 units of the destination, don't bother pathing. (Sorian and Duncan AI)
    if (minPathDistance and VDist2Sq(start[1], start[3], destination[1], destination[3]) <= minPathDistance) then
        return { destination }
    end

    --Generate path between the start and destination
    local path, msg, distance = NavUtils.PathTo(platoonLayer, start, destination)
    if not path then return false, msg end

    return path, false, distance
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

-- Sproutos work

function GetRealThreatAtPosition(aiBrain, position, range )

    local sfake = GetThreatAtPosition( aiBrain, position, 0, true, 'AntiSurface' )
    local afake = GetThreatAtPosition( aiBrain, position, 0, true, 'AntiAir' )   
    local airthreat = 0
    local surthreat = 0

    local eunits = GetUnitsAroundPoint( aiBrain, categories.ALLUNITS - categories.FACTORY - categories.ECONOMIC - categories.SHIELD - categories.WALL , position, range,  'Enemy')

    if eunits then
        for _,u in eunits do
            if not u.Dead then
                airthreat = airthreat + u.Blueprint.Defense.AirThreatLevel
                surthreat = surthreat + u.Blueprint.Defense.SurfaceThreatLevel
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

function DrawTargetRadius(aiBrain, position)
    --RNGLOG('Draw Target Radius points')
    local counter = 0
    while counter < 60 do
        DrawCircle(position, 20, 'cc0000')
        counter = counter + 1
        coroutine.yield( 2 )
    end
end

function GetBestNavalTargetRNG(aiBrain, platoon, bSkipPathability)

    
    local PrimaryTargetThreatType = 'Naval'
    local SecondaryTargetThreatType = 'Structures'
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
    local WeakAttackThreatWeight = 5

    -- If the platoon we're sending is stronger than a potential target, raise
    -- the desirability of choosing that target by this factor
    local StrongAttackThreatWeight = 10


    -- We can also tune the desirability of a target based on various
    -- distance thresholds.  The thresholds are very near, near, mid, far
    -- and very far.  The Radius value represents the largest distance considered
    -- in a given category; the weight is the multiplicative factor used to increase
    -- the desirability for the distance category

    local VeryNearThreatWeight = 20000
    local VeryNearThreatRadius = 125

    local NearThreatWeight = 2500
    local NearThreatRadius = 250

    local MidThreatWeight = 500
    local MidThreatRadius = 350

    local FarThreatWeight = 100
    local FarThreatRadius = 500

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

    local platoonPosition = platoon.Pos or platoon:GetPlatoonPosition()
    local selectedWeaponArc = 'None'

    if not platoonPosition then
        --Platoon no longer exists.
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

    
    local threatTable = aiBrain:GetThreatsAroundPosition(platoonPosition, 16, true, 'OverallNotAssigned')

    if table.empty(threatTable) then
        --RNGLOG('GetBestNavalTarget threat table is empty returned false ')
        return false
    end

    local platoonUnits = platoon:GetPlatoonUnits()
    local myThreat = 0

    for _,u in platoonUnits do
        local bpThreat = 0
        if not u.Dead then
            local bp = u.Blueprint
            if platoon.MovementLayer == 'Land' then
                bpThreat = bp.Defense.SurfaceThreatLevel
            elseif platoon.MovementLayer == 'Water' then
                bpThreat = bp.Defense.SurfaceThreatLevel
                if bp.Defense.SubThreatLevel then
                    bpThreat = bpThreat + bp.Defense.SubThreatLevel
                end
            elseif platoon.MovementLayer == 'Amphibious' then
                bpThreat = bp.Defense.SurfaceThreatLevel
            elseif platoon.MovementLayer == 'Air' then
                bpThreat = bp.Defense.SurfaceThreatLevel
                if bp.Defense.AirThreatLevel then
                    bpThreat = bpThreat + bp.Defense.AirThreatLevel
                end
            end
        end
        myThreat = myThreat + bpThreat
    end

    --RNGLOG('GetBestNavalTarget myThreat is '..myThreat)
    
    local friendlyThreat = platoon:CalculatePlatoonThreatAroundPosition('Surface', categories.MOBILE * categories.NAVAL, platoonPosition, 50) - myThreat
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
        primaryThreat = aiBrain:GetThreatAtPosition({threat[1], 0, threat[2]}, aiBrain.BrainIntel.IMAPConfig.Rings, true, PrimaryTargetThreatType)
        -- update : we are testing no longer multiplying since they are updating to threat numbers on everything.
        -- We are multipling the structure threat because the default threat allocation is shit. A T1 naval factory is only worth 3 threat which is not enough to make
        -- frigates / subs want to attack them over something else.
        secondaryThreat = aiBrain:GetThreatAtPosition({threat[1], 0, threat[2]}, aiBrain.BrainIntel.IMAPConfig.Rings, true, SecondaryTargetThreatType)
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
            --LOG('NavalAttackAI is weaker than the enemy')
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
    --local pathablePos = CheckNavalPathingRNG(aiBrain, platoon, {x, y, z}, maxRange, selectedWeaponArc)
    
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
        local vectors = NavUtils.GetPositionsInRadius('Water', platoonPosition, maxRange, 6)
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