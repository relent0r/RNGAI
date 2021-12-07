local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local GetClosestPathNodeInRadiusByLayerRNG = import('/lua/AI/aiattackutilities.lua').GetClosestPathNodeInRadiusByLayerRNG
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
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
    for _, v in Scenario.MasterChain._MASTERCHAIN_.Markers do
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