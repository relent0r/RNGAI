local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local GetClosestPathNodeInRadiusByLayerRNG = import('/lua/AI/aiattackutilities.lua').GetClosestPathNodeInRadiusByLayerRNG
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
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
local RNGCOPY = table.copy

function GenerateMapZonesRNG(aiBrain)

    local function CreateZoneRNG(pos,weight,id,radius,start)
        return { Pos = RNGCOPY(pos), Weight = weight, Edges = {}, ID = id, Radius = radius, Start = start}
    end

    LOG('Start Generate Map Zones')
    local zones = {}
    local massPoints = {}
    local zoneID = 1
    local zoneRadius = 60 * 60
    
    local armyStarts = {}
    for i = 1, 16 do
        local army = ScenarioInfo.ArmySetup['ARMY_' .. i]
        local startPos = ScenarioUtils.GetMarker('ARMY_' .. i).position
        if army and startPos then
            table.insert(armyStarts, startPos)
        end
    end
    for _, v in AdaptiveResourceMarkerTableRNG do
        if v.type == "Mass" or v.type == "Hydrocarbon" then
            table.insert(massPoints, { pos=v.position, claimed = false, weight = 1, aggX = v.position[1], aggZ = v.position[3] })
        end
    end
    complete = (RNGGETN(massPoints) == 0)
    LOG('Start while loop')
    while not complete do
        complete = true
        -- Update weights
        local startPos = false
        for _, v in massPoints do
            v.weight = 1
            v.aggX = v.pos[1]
            v.aggZ = v.pos[3]
        end
        for _, v1 in massPoints do
            if not v1.claimed then
                for _, v2 in massPoints do
                    if (not v2.claimed) and VDist2Sq(v1.pos[1], v1.pos[3], v2.pos[1], v2.pos[3]) < zoneRadius then
                        v1.weight = v1.weight + 1
                        v1.aggX = v1.aggX + v2.pos[1]
                        v1.aggZ = v1.aggZ + v2.pos[3]
                    end
                end
            end
        end
        -- Find next point to add
        local best = nil
        for _, v in massPoints do
            if (not v.claimed) and ((not best) or best.weight < v.weight) then
                best = v
            end
        end
        -- Add next point
        local massGroup = {best.pos}
        best.claimed = true
        local x = best.aggX/best.weight
        local z = best.aggZ/best.weight
        for _, p in armyStarts do
            if VDist2Sq(p[1], p[3],x, z) < (zoneRadius) then
                --LOG('Position Taken '..repr(v)..' and '..repr(v.position))
                startPos = true
                break
            end
        end
        table.insert(zones,CreateZoneRNG({x,GetSurfaceHeight(x,z),z},best.weight,zoneID, 60, startPos))
        -- Claim nearby points
        for _, v in massPoints do
            if (not v.claimed) and VDist2Sq(v.pos[1], v.pos[3], best.pos[1], best.pos[3]) < zoneRadius then
                table.insert(massGroup, v.pos)
                v.claimed = true
            elseif not v.claimed then
                complete = false
            end
        end
        
        --zones[zoneID].MassPoints = {}
        --zones[zoneID].MassPoints = massGroup
        for k, v in zones do
            if v.ID == zoneID then
                if not v.MassPoints then
                    v.MassPoints = {}
                end
                v.MassPoints = massGroup
                break
            end
        end
        zoneID = zoneID + 1
    end
    for k, v in zones do
        for k1, v1 in v.MassPoints do
            for k2, v2 in AdaptiveResourceMarkerTableRNG do
                if v1[1] == v2.position[1] and v1[3] == v2.position[3] then
                    AdaptiveResourceMarkerTableRNG[k2].zoneid = v.ID
                end
            end
        end
    end
    LOG('Zone Table '..repr(zones))
    LOG('AdaptiveResourceMarkerTable '..repr(AdaptiveResourceMarkerTableRNG))
end

function AIConfigureExpansionWatchTableRNG(aiBrain)
    coroutine.yield(5)
    
    local VDist2Sq = VDist2Sq
    local markerList = {}
    local armyStarts = {}
    local expansionMarkers = Scenario.MasterChain._MASTERCHAIN_.Markers
    local massPointValidated = false
    local myArmy = ScenarioInfo.ArmySetup[aiBrain.Name]
    --LOG('Run ExpansionWatchTable Config')

    for i = 1, 16 do
        local army = ScenarioInfo.ArmySetup['ARMY_' .. i]
        local startPos = ScenarioUtils.GetMarker('ARMY_' .. i).position
        if army and startPos then
            table.insert(armyStarts, startPos)
        end
    end
    --LOG(' Army Starts'..repr(armyStarts))

    if expansionMarkers then
        --LOG('Initial expansionMarker list is '..repr(expansionMarkers))
        for k, v in expansionMarkers do
            local startPosUsed = false
            if v.type == 'Expansion Area' or v.type == 'Large Expansion Area' or v.type == 'Blank Marker' then
                for _, p in armyStarts do
                    if p == v.position then
                        --LOG('Position Taken '..repr(v)..' and '..repr(v.position))
                        startPosUsed = true
                        break
                    end
                end
                if not startPosUsed then
                    if v.MassSpotsInRange then
                        massPointValidated = true
                        table.insert(markerList, {Name = k, Position = v.position, Type = v.type, TimeStamp = 0, MassPoints = v.MassSpotsInRange, Land = 0, Structures = 0, Commander = 0, PlatoonAssigned = false, ScoutAssigned = false, Zone = false})
                    else
                        table.insert(markerList, {Name = k, Position = v.position, Type = v.type, TimeStamp = 0, MassPoints = 0, Land = 0, Structures = 0, Commander = 0, PlatoonAssigned = false, ScoutAsigned = false, Zone = false})
                    end
                end
            end
        end
    end
    if not massPointValidated then
        markerList = CalculateMassValue(markerList)
    end
    --LOG('Army Setup '..repr(ScenarioInfo.ArmySetup))
    local startX, startZ = aiBrain:GetArmyStartPos()
    table.sort(markerList,function(a,b) return VDist2Sq(a.Position[1],a.Position[3],startX, startZ)>VDist2Sq(b.Position[1],b.Position[3],startX, startZ) end)
    aiBrain.BrainIntel.ExpansionWatchTable = markerList
    --LOG('ExpansionWatchTable is '..repr(markerList))
end

ExpansionIntelScanRNG = function(aiBrain)
    --LOG('Pre-Start ExpansionIntelScan')
    AIConfigureExpansionWatchTableRNG(aiBrain)
    coroutine.yield(Random(30,70))
    if RNGGETN(aiBrain.BrainIntel.ExpansionWatchTable) == 0 then
        --LOG('ExpansionWatchTable not ready or is empty')
        return
    end
    local threatTypes = {
        'Land',
        'Commander',
        'Structures',
    }
    local rawThreat = 0
    if ScenarioInfo.Options.AIDebugDisplay == 'displayOn' then
        aiBrain:ForkThread(RUtils.RenderBrainIntelRNG)
    end
    local GetClosestPathNodeInRadiusByLayer = import('/lua/AI/aiattackutilities.lua').GetClosestPathNodeInRadiusByLayer
    --LOG('Starting ExpansionIntelScan')
    while aiBrain.Result ~= "defeat" do
        for k, v in aiBrain.BrainIntel.ExpansionWatchTable do
            if v.PlatoonAssigned.Dead then
                v.PlatoonAssigned = false
            end
            if v.ScoutAssigned.Dead then
                v.ScoutAssigned = false
            end
            if not v.Zone then
                --[[
                    This is the information available in the Path Node currently. subject to change 7/13/2021
                    info: Check for position {
                    info:   GraphArea="LandArea_133",
                    info:   RNGArea="Land15-24",
                    info:   adjacentTo="Land19-11 Land20-11 Land20-12 Land20-13 Land18-11",
                    info:   armydists={ ARMY_1=209.15859985352, ARMY_2=218.62866210938 },
                    info:   bestarmy="ARMY_1",
                    info:   bestexpand="Expansion Area 6",
                    info:   color="fff4a460",
                    info:   expanddists={
                    info:     ARMY_1=209.15859985352,
                    info:     ARMY_2=218.62866210938,
                    info:     ARMY_3=118.64562988281,
                    info:     ARMY_4=290.41003417969,
                    info:     ARMY_5=270.42752075195,
                    info:     ARMY_6=125.28052520752,
                    info:     Expansion Area 1=354.38958740234,
                    info:     Expansion Area 2=354.2922668457,
                    info:     Expansion Area 5=222.54640197754,
                    info:     Expansion Area 6=0
                    info:   },
                    info:   graph="DefaultLand",
                    info:   hint=true,
                    info:   orientation={ 0, 0, 0 },
                    info:   position={ 312, 16.21875, 200, type="VECTOR3" },
                    info:   prop="/env/common/props/markers/M_Path_prop.bp",
                    info:   type="Land Path Node"
                    info: }
                ]]
                local expansionNode = Scenario.MasterChain._MASTERCHAIN_.Markers[GetClosestPathNodeInRadiusByLayer(v.Position, 60, 'Land').name]
                --LOG('Check for position '..repr(expansionNode))
                if expansionNode then
                    aiBrain.BrainIntel.ExpansionWatchTable[k].Zone = expansionNode.RNGArea
                else
                    aiBrain.BrainIntel.ExpansionWatchTable[k].Zone = false
                end
            end
            if v.MassPoints > 2 then
                for _, t in threatTypes do
                    rawThreat = GetThreatAtPosition(aiBrain, v.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, t)
                    if rawThreat > 0 then
                        --LOG('Threats as ExpansionWatchTable for type '..t..' threat is '..rawThreat)
                        --LOG('Expansion is '..v.Name)
                        --LOG('Position is '..repr(v.Position))
                    end
                    aiBrain.BrainIntel.ExpansionWatchTable[k][t] = rawThreat
                end
            elseif v.MassPoints == 2 then
                rawThreat = GetThreatAtPosition(aiBrain, v.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'Structures')
                aiBrain.BrainIntel.ExpansionWatchTable[k]['Structures'] = rawThreat
            end
        end
        coroutine.yield(50)
        -- don't do this, it might have a platoon inside it LOG('Current Expansion Watch Table '..repr(aiBrain.BrainIntel.ExpansionWatchTable))
    end
end

ZoneIntelMonitorRNG = function(aiBrain)
    local threatTypes = {
        'Land',
        'Commander',
        'Structures',
    }
    local rawThreat = 0
    --[[
        Each Zone currently looks like this
        Dont repr the entire zone set
        {
        pos={x,y,z},
        friendlythreat=0,
        weight=6,
        id=6,
        edges = {adjacent zones live in here}
        enemythreat=0,
        startpositionclose="false"
        }
    ]]
    WaitTicks(50)
    while aiBrain.Result ~= "defeat" do
        for k, v in aiBrain.Zones.Land.zones do
            aiBrain.Zones.Land.zones[k].enemythreat = GetThreatAtPosition(aiBrain, v.pos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface')
            coroutine.yield(1)
        end
        coroutine.yield(2)
    end
end

function InitialNavalAttackCheck(aiBrain)
    -- This function will check if there are mass markers that can be hit by frigates. This can trigger faster naval factory builds initially.
    -- points = number of points around the extractor, doesn't need to have too many.
    -- radius = the radius that the points will be, be set this a little lower than a frigates max weapon range
    -- center = the x,y values for the position of the mass extractor. e.g {x = 0, y = 0} 

    local function drawCirclePoints(points, radius, center)
        local extractorPoints = {}
        local slice = 2 * math.pi / points
        for i=1, points do
            local angle = slice * i
            local newX = center[1] + radius * math.cos(angle)
            local newY = center[3] + radius * math.sin(angle)
            table.insert(extractorPoints, { newX, 0 , newY})
        end
        return extractorPoints
    end
    local frigateRaidMarkers = {}
    local markers = AdaptiveResourceMarkerTableRNG
    if markers then
        local markerCount = 0
        local markerCountNotBlocked = 0
        local markerCountBlocked = 0
        for _, v in markers do 
            local checkPoints = drawCirclePoints(6, 26, v.position)
            if checkPoints then
                for _, m in checkPoints do
                    if RUtils.PositionInWater(m) then
                        --LOG('Location '..repr({m[1], m[3]})..' is in water for extractor'..repr({v.Position[1], v.Position[3]}))
                        --LOG('Surface Height at extractor '..GetSurfaceHeight(v.Position[1], v.Position[3]))
                        --LOG('Surface height at position '..GetSurfaceHeight(m[1], m[3]))
                        local pointSurfaceHeight = GetSurfaceHeight(m[1], m[3]) + 0.35
                        markerCount = markerCount + 1
                        if aiBrain:CheckBlockingTerrain({m[1], pointSurfaceHeight, m[3]}, v.position, 'none') then
                            --LOG('This marker is not blocked')
                            markerCountNotBlocked = markerCountNotBlocked + 1
                            table.insert( frigateRaidMarkers, v )
                        else
                            markerCountBlocked = markerCountBlocked + 1
                        end
                        break
                    end
                end
            end
        end
        --LOG('There are potentially '..markerCount..' markers that are in range for frigates')
        --LOG('There are '..markerCountNotBlocked..' markers NOT blocked by terrain')
        --LOG('There are '..markerCountBlocked..' markers that ARE blocked')
        --LOG('Markers that frigates can try and raid '..repr(frigateRaidMarkers))
        if markerCountNotBlocked > 8 then
            aiBrain.EnemyIntel.FrigateRaid = true
            --LOG('Frigate Raid is true')
            aiBrain.EnemyIntel.FrigateRaidMarkers = frigateRaidMarkers
        end
    end
end

function CalculateMassValue(expansionMarkers)
    local MassMarker = {}
    local VDist2Sq = VDist2Sq
    if not expansionMarkers then
        WARN('No Expansion Markers Passed to calcuatemassvalue')
    end
    for _, v in AdaptiveResourceMarkerTableRNG do
        if v.type == 'Mass' then
            if v.position[1] <= 8 or v.position[1] >= ScenarioInfo.size[1] - 8 or v.position[3] <= 8 or v.position[3] >= ScenarioInfo.size[2] - 8 then
                continue
            end
            table.insert(MassMarker, {Position = v.position})
        end
    end
    for k, v in expansionMarkers do
        local masscount = 0
        for k2, v2 in MassMarker do
            if VDist2Sq(v.Position[1], v.Position[3], v2.Position[1], v2.Position[3]) > 6400 then
                continue
            end
            masscount = masscount + 1
        end        
        -- insert mexcount into marker
        v.MassPoints = masscount
        --SPEW('* AI-RNG: CreateMassCount: Node: '..v.Type..' - MassSpotsInRange: '..v.MassPoints)
    end
    return expansionMarkers
end

function QueryExpansionTable(aiBrain, location, radius, movementLayer, threat, type)
    -- Should be a multipurpose Expansion query that can provide units, acus a place to go
    if not aiBrain.BrainIntel.ExpansionWatchTable then
        WARN('No ExpansionWatchTable. Maybe it hasnt been created yet or something is broken')
        coroutine.yield(50)
        return false
    end
    

    local MainPos = aiBrain.BuilderManagers.MAIN.Position
    if VDist2Sq(location[1], location[3], MainPos[1], MainPos[3]) > 3600 then
        return false
    end
    local positionNode = Scenario.MasterChain._MASTERCHAIN_.Markers[GetClosestPathNodeInRadiusByLayerRNG(location, radius, movementLayer).name]
    local centerPoint = aiBrain.MapCenterPoint
    local mainBaseToCenter = VDist2Sq(MainPos[1], MainPos[3], centerPoint[1], centerPoint[3])
    local bestExpansions = {}
    local options = {}
    local currentGameTime = GetGameTimeSeconds()
    -- Note, the expansions zones are land only. Need to fix this to include amphib zone.
    if positionNode.RNGArea then
        for k, expansion in aiBrain.BrainIntel.ExpansionWatchTable do
            if expansion.Zone == positionNode.RNGArea then
                local expansionDistance = VDist2Sq(location[1], location[3], expansion.Position[1], expansion.Position[3])
                LOG('Distance to expansion '..expansionDistance)
                -- Check if this expansion has been staged already in the last 30 seconds unless there is land threat present
                --LOG('Expansion last visited timestamp is '..expansion.TimeStamp)
                if currentGameTime - expansion.TimeStamp > 45 or expansion.Land > 0 or type == 'acu' then
                    if expansionDistance < radius * radius then
                        LOG('Expansion Zone is within radius')
                        if type == 'acu' or VDist2Sq(MainPos[1], MainPos[3], expansion.Position[1], expansion.Position[3]) < (VDist2Sq(MainPos[1], MainPos[3], centerPoint[1], centerPoint[3]) + 900) then
                            LOG('Expansion has '..expansion.MassPoints..' mass points')
                            LOG('Expansion is '..expansion.Name..' at '..repr(expansion.Position))
                            if expansion.MassPoints > 1 then
                                -- Lets ponder this a bit more, the acu is strong, but I don't want him to waste half his hp on civilian PD's
                                if type == 'acu' and GetThreatAtPosition( aiBrain, expansion.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface') > 5 then
                                    LOG('Threat at location too high for easy building')
                                    continue
                                end
                                if type == 'acu' and GetNumUnitsAroundPoint(aiBrain, categories.MASSEXTRACTION, expansion.Position, 30, 'Ally') >= expansion.MassPoints then
                                    LOG('ACU Location has enough masspoints to indicate its already taken')
                                    continue
                                end
                                RNGINSERT(options, {Expansion = expansion, Value = expansion.MassPoints * expansion.MassPoints, Key = k, Distance = expansionDistance})
                            end
                        else
                            LOG('Expansion is beyond the center point')
                            LOG('Distance from main base to expansion '..VDist2Sq(MainPos[1], MainPos[3], expansion.Position[1], expansion.Position[3]))
                            LOG('Should be less than ')
                            LOG('Distance from main base to center point '..VDist2Sq(MainPos[1], MainPos[3], centerPoint[1], centerPoint[3]))
                        end
                    end
                else
                    LOG('This expansion has already been checked in the last 45 seconds')
                end
            end
        end
        LOG('Number of options from first cycle '..table.getn(options))
        local optionCount = 0
        
        for k, withinRadius in options do
            if mainBaseToCenter > VDist2Sq(withinRadius.Expansion.Position[1], withinRadius.Expansion.Position[3], centerPoint[1], centerPoint[3]) then
                --LOG('Expansion has high mass value at location '..withinRadius.Expansion.Name..' at position '..repr(withinRadius.Expansion.Position))
                RNGINSERT(bestExpansions, withinRadius)
            else
                --LOG('Expansion is behind the main base , position '..repr(withinRadius.Expansion.Position))
            end
        end
    else
        WARN('No RNGArea in path node, either its not created yet or the marker analysis hasnt happened')
    end
    --LOG('We have '..RNGGETN(bestExpansions)..' expansions to pick from')
    if RNGGETN(bestExpansions) > 0 then
        if type == 'acu' then
            local bestOption = false
            local secondBestOption = false
            local bestValue = 9999999999
            for _, v in options do
                local alreadySecure = false
                for k, b in aiBrain.BuilderManagers do
                    if k == v.Expansion.Name and RNGGETN(aiBrain.BuilderManagers[k].FactoryManager.FactoryList) > 0 then
                        LOG('Already a builder manager with factory present, set')
                        alreadySecure = true
                        break
                    end
                end
                if alreadySecure then
                    LOG('Position already secured, ignore and move to next expansion')
                    continue
                end
                local expansionValue = v.Distance * v.Distance / v.Value
                if expansionValue < bestValue then
                    secondBestOption = bestOption
                    bestOption = v
                    bestValue = expansionValue
                end
            end
            if secondBestOption and bestOption then
                local acuOptions = { bestOption, secondBestOption }
                LOG('ACU is having a random expansion returned')
                return acuOptions[Random(1,2)]
            end
            LOG('ACU is having the best expansion returned')
            return bestOption
        else
            return bestExpansions[Random(1,RNGGETN(bestExpansions))] 
        end
    end
    return false
end