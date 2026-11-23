-- This file is an example of how you can add custom zones to the FlowAI mapping framework.
-- First import this class
local ZoneSet = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Zones.lua').ZoneSet
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local MarkerUtils = import("/lua/sim/MarkerUtilities.lua")
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
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

-- We'll use these too later
local GetMarkers = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
local MAP = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMap()

--[[
    Resulting Zone Table looks something like
    {
    pos=Zone Center Position, 
    weight=weight based on masspoints, 
    startpositionclose=do we have a live start position within the radius, 
    enemythreat=currently populated by imap, 
    friendlythreat=currently populated by the intel manager according to the platoons threat values, 
    massmarkers=all the mass markers in the zone,
    control=information on how the AI thinks it controls a zone
    zonealert=this will be used for re-enforcements..I think.
    edges ={
        {
            distance = I think this is the distance between the centerpoint and the edge of the zone
            border = something, check with softles
            zone = the ID of that adjacent zone
        }
    }
    }
]]

-- Now create a subclass of 'ZoneSet', non-destructively hooking 'Init' and implementing the 'GenerateZoneList' function.
-- You can create as many classes as you like here.
-- Don't bother implementing any other methods or having any other variables since they'll be lost in the copy operation.
RNGNavalResourceSet = Class(ZoneSet){
    Init = function(self,zoneIndex)
        ZoneSet.Init(self,zoneIndex)
        -- Choice of the layer you want these zones to exist in.
        self.layer = 2 -- Naval
        -- In your own custom classes please set this to something unique so you can identify your zones later.
        self.name = 'RNGNavalResourceSet'
    end,
    GenerateZoneList = function(self)
        -- Step 1: Get a set of markers that are in the layer we're currently interested in.
       --RNGLOG('GenerateZoneList for custom Zone')
        local navalStartPositions = {}
        local maxmapdimension = math.max(ScenarioInfo.size[1],ScenarioInfo.size[2])
        local zoneRadius = 70 * 70
        --if maxmapdimension < 512 then
        --    zoneRadius = 70 * 70
        --elseif maxmapdimension < 1024 then
        --    zoneRadius = 180 * 180
        --end

        --RNGLOG('Zone Radius is '..zoneRadius)

        local markers = {}
        local navalMarkers = MarkerUtils.GetMarkersByType('Naval Area')
        local mapSizeX = ScenarioInfo.size[1]
        local mapSizeZ = ScenarioInfo.size[2]

        local function FindNearbyWater(x, z, layer, maxRadius)
            local y = GetSurfaceHeight(x, z)
            if MAP:GetComponent({x, y, z}, layer) > 0 then
                return {x, y, z}
            end
            local step = 16
            for r = step, maxRadius, step do
                local checks = {
                    {x + r, z}, {x - r, z}, {x, z + r}, {x, z - r},
                    {x + r, z + r}, {x - r, z + r}, {x + r, z - r}, {x - r, z - r}
                }
                for _, pos in checks do
                    if pos[1] > 0 and pos[1] < mapSizeX and pos[2] > 0 and pos[2] < mapSizeZ then
                        local checkY = GetSurfaceHeight(pos[1], pos[2])
                        if MAP:GetComponent({pos[1], checkY, pos[2]}, layer) > 0 then
                            return {pos[1], checkY, pos[2]}
                        end
                    end
                end
            end
            return nil
        end

        for _, marker in GetMarkers() do
            if marker.type == 'Mass' then
                if MAP:GetComponent(marker.position,self.layer) > 0 then
                    if GetTerrainHeight(marker.position[1], marker.position[3]) < GetSurfaceHeight(marker.position[1], marker.position[3]) then
                        RNGINSERT(markers,marker)
                    end
                end
            end
        end
        for _, marker in navalMarkers do
            if marker.type == 'Naval Area' then
                if MAP:GetComponent(marker.position,self.layer) > 0 then
                    RNGINSERT(markers,{name=marker.name, position=marker.position, type=marker.type, size=marker.size})
                end
            end
        end
        
        for i = 1, 16 do
            local army = ScenarioInfo.ArmySetup['ARMY_' .. i]
            local startMarker = ScenarioUtils.GetMarker('ARMY_' .. i)
            local startPos = startMarker and startMarker.position
            if army and startPos then
                local closestMarker = false
                local closestDistance = false
                for _, n in markers do
                    if n.type == 'Naval Area' then
                        local distance = VDist2Sq(startPos[1], startPos[3], n.position[1], n.position[3])
                        if not closestDistance or distance < closestDistance then
                            closestMarker = n
                            closestDistance = distance
                        end
                    end
                end
                -- Fallback to water mass markers if no Naval Area markers exist
                if not closestMarker then
                    for _, n in markers do
                        local distance = VDist2Sq(startPos[1], startPos[3], n.position[1], n.position[3])
                        if not closestDistance or distance < closestDistance then
                            closestMarker = n
                            closestDistance = distance
                        end
                    end
                end
                if closestMarker then
                    RNGINSERT(navalStartPositions, { index = i, marker = closestMarker, armyindex = i, distance = closestDistance, position = closestMarker.position })
                end
            end
        end

        -- Midpoint Buffer Zone Seeding
        local bufferSeeds = {}
        local minDistanceBetweenBuffersSq = 80 * 80
        local minDistanceFromMarkersSq = 70 * 70

        -- 1. Midpoints from Naval Start Positions
        local numNavalStarts = RNGGETN(navalStartPositions)
        if numNavalStarts > 1 then
            for i = 1, numNavalStarts - 1 do
                for j = i + 1, numNavalStarts do
                    local startA = navalStartPositions[i]
                    local startB = navalStartPositions[j]
                    local posA = startA.position
                    local posB = startB.position
                    local distSq = VDist2Sq(posA[1], posA[3], posB[1], posB[3])
                    if distSq > (140 * 140) then
                        local midX = (posA[1] + posB[1]) / 2
                        local midZ = (posA[3] + posB[3]) / 2
                        local waterPos = FindNearbyWater(midX, midZ, self.layer, 64)
                        if waterPos then
                            local tooClose = false
                            for _, m in markers do
                                if VDist2Sq(waterPos[1], waterPos[3], m.position[1], m.position[3]) < minDistanceFromMarkersSq then
                                    tooClose = true
                                    break
                                end
                            end
                            if not tooClose then
                                for _, b in bufferSeeds do
                                    if VDist2Sq(waterPos[1], waterPos[3], b.position[1], b.position[3]) < minDistanceBetweenBuffersSq then
                                        tooClose = true
                                        break
                                    end
                                end
                            end
                            if not tooClose then
                                RNGINSERT(bufferSeeds, {
                                    name = 'Naval Buffer Midpoint',
                                    position = waterPos,
                                    type = 'Naval Buffer',
                                    isMidpoint = true,
                                })
                            end
                        end
                    end
                end
            end
        end

        -- 2. Seeding midpoints from Start Locations (similar to RNGAirResourceSet)
        local startLocations = MarkerUtils.GetMarkersByType('Start Location')
        local numStarts = RNGGETN(startLocations)
        if numStarts > 1 then
            for i = 1, numStarts - 1 do
                for j = i + 1, numStarts do
                    local startA = startLocations[i]
                    local startB = startLocations[j]
                    local posA = startA.position
                    local posB = startB.position
                    local distSq = VDist2Sq(posA[1], posA[3], posB[1], posB[3])
                    if distSq > (140 * 140) then
                        local midX = (posA[1] + posB[1]) / 2
                        local midZ = (posA[3] + posB[3]) / 2
                        local waterPos = FindNearbyWater(midX, midZ, self.layer, 64)
                        if waterPos then
                            local tooClose = false
                            for _, m in markers do
                                if VDist2Sq(waterPos[1], waterPos[3], m.position[1], m.position[3]) < minDistanceFromMarkersSq then
                                    tooClose = true
                                    break
                                end
                            end
                            if not tooClose then
                                for _, b in bufferSeeds do
                                    if VDist2Sq(waterPos[1], waterPos[3], b.position[1], b.position[3]) < minDistanceBetweenBuffersSq then
                                        tooClose = true
                                        break
                                    end
                                end
                            end
                            if not tooClose then
                                RNGINSERT(bufferSeeds, {
                                    name = 'Naval Buffer Midpoint',
                                    position = waterPos,
                                    type = 'Naval Buffer',
                                    isMidpoint = true,
                                })
                            end
                        end
                    end
                end
            end
        end

        for _, bSeed in bufferSeeds do
            RNGINSERT(markers, bSeed)
        end

        local complete = (RNGGETN(markers) == 0)
       --RNGLOG('Starting GenerateZoneList Loop')
        local count = 0
        while not complete do
            complete = true
            -- Update weights
            for _, v in markers do
                v.weight = 1
                v.aggX = v.position[1]
                v.aggZ = v.position[3]
            end
            for _, v1 in markers do
                if not v1.claimed then
                    for _, v2 in markers do
                        if (not v2.claimed) and (v1 ~= v2) and VDist2Sq(v1.position[1], v1.position[3], v2.position[1], v2.position[3]) < zoneRadius then
                            v1.weight = v1.weight + 1
                            v1.aggX = v1.aggX + v2.position[1]
                            v1.aggZ = v1.aggZ + v2.position[3]
                        end
                    end
                end
            end
            -- Find next point to add
            local best = nil
            for _, v in markers do
                if (not v.claimed) and ((not best) or best.weight < v.weight) then
                    best = v
                end
            end
            -- Add next point
            local resourceGroup = {}
            if best.type == 'Mass' then
                RNGINSERT(resourceGroup, best)
            end
            best.claimed = true
            local x = best.aggX/best.weight
            local z = best.aggZ/best.weight
            

            -- Claim nearby points
            for _, v in markers do
                if (not v.claimed) and VDist2Sq(v.position[1], v.position[3], best.position[1], best.position[3]) < zoneRadius then
                    if v.type == 'Mass' then
                        RNGINSERT(resourceGroup, v)
                    end
                    v.claimed = true
                elseif not v.claimed then
                    complete = false
                end
            end
            local posX = math.floor(x)
            local posZ = math.floor(z)
            local posY = GetSurfaceHeight(posX, posZ)

            local startPosClose = false
            for _, s in navalStartPositions do
                if VDist2Sq(posX, posZ, s.position[1], s.position[3]) < (100 * 100) then
                    startPosClose = true
                    break
                end
            end

            self:AddZone({
                pos={posX, posY, posZ}, 
                component=MAP:GetComponent({posX, posY, posZ},self.layer), 
                weight=best.weight, 
                startpositionclose=startPosClose, 
                enemystructurethreat=0, 
                gridenemylandthreat=0, 
                enemylandthreat=0, 
                enemyantisurfacethreat=0, 
                enemyantiairthreat=0,
                enemyairthreat=0,
                enemynavalthreat=0,
                enemydefensestructurethreat=0,
                enemySilos=0, 
                friendlyantisurfacethreat=0, 
                friendlylandantiairthreat=0, 
                friendlydirectfireantisurfacethreat=0, 
                friendlyantinavythreat=0, 
                friendlyindirectfireantisurfacethreat=0,
                friendlydefenseantisurfacethreat=0,
                friendlydefenseantiairthreat=0,
                resourcevalue=RNGGETN(resourceGroup), 
                resourcemarkers=resourceGroup, 
                zonealert=false, 
                control=1, 
                enemystartdata = { }, 
                allystartdata = { }, 
                bestarmy = false, 
                teamvalue = 1, 
                platoonallocations = {friendlyantiairallocatedthreat=0, friendlydirectfireallocatedthreat=0}, 
                label = 0, 
                amphiblabel = 0,
                staticaascore = 0,
                staticcontrolscore = 0,
                staticraidscore = 0,
                staticsairsurfacescore = 0,
                BuilderManager = false, 
                lastexpansionattempt = 0, 
                engineerplatoonallocated = false, 
                intelassignment = {}, 
                zoneincome = {
                    selfincome = 0,
                    allyincome = 0,
                    enemyincome = 0
                },
                navaldata = {},
                defensespokes = false,
                status = 'Unoccupied',
            })
        end
    end,
}

-- Now implement a 'GetZoneSetClasses' function to export the zones you want to include in the game.
function GetZoneSetClasses()
    -- Set to true if you want to test this
    local RNGNavalResourceSetEnabled = true
    if RNGNavalResourceSetEnabled then
        -- Include as many classes here as you like (and are willing to take the performance hit for).
        return {RNGNavalResourceSet}
    else
        return {}
    end
end

--[[
    Awesome, we've implemented and added a new set of Zones to the FlowAI mappign framework!  What
    you'll want to do now is load these into your AI so you can make use of them.

    In order to avoid problems with different AIs changing data in the same zone tables, the
    'GameMap' class implements a way of exporting a completely clean version of a ZoneSet, that you
    can use freely within a single AI without worrying about those issues.

    In order to find and export your custom zones, you'll need to call:
        'map:FindZoneSet(name,layer)'.
    
    If you have a 'zoneSet' variable, you can also ask the map what zone a thing is in using:
        'map:GetZoneID(pos,zoneSet.index)'
]]
