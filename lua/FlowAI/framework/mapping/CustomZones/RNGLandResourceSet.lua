-- This file is an example of how you can add custom zones to the FlowAI mapping framework.
-- First import this class
local ZoneSet = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Zones.lua').ZoneSet
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
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
    enemylandthreat=currently populated by imap,
    enemyantiairthreat=currently populated by imap,
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
RNGLandResourceSet = Class(ZoneSet){
    Init = function(self,zoneIndex)
        ZoneSet.Init(self,zoneIndex)
        -- Choice of the layer you want these zones to exist in.
        self.layer = 1 -- land
        -- In your own custom classes please set this to something unique so you can identify your zones later.
        self.name = 'RNGLandResourceSet'
    end,
    GenerateZoneList = function(self)
        local function AssimilateZones(zoneList, zoneCount)

            local startLocations, startLocationCount = import("/lua/sim/markerutilities.lua").GetMarkersByType('Start Location')
            local mapSize = math.max(ScenarioInfo.size[1], ScenarioInfo.size[2])
            local threshold = 30 + 0.02 * mapSize
        
            ---------------------------------------------------------------------------
            -- prepare the start locations
        
            for k = 1, startLocationCount do
                local startLocation = startLocations[k]
                startLocation.resourcemarkers = { }
                --startLocation.HydrocarbonPlants = { }
            end
        
            ---------------------------------------------------------------------------
            -- assimilate expansions
        
            local head = 1
            for k = 1, zoneCount do
                local zone = zoneList[k]
                local center = zone.pos
        
                -- find nearest spawn location
                local nearestStartLocation
                local nearestStartLocationDistance
                for k = 1, startLocationCount do
                    local startLocation = startLocations[k]
                    local dx = startLocation.position[1] - center[1]
                    local dz = startLocation.position[3] - center[3]
                    local startLocationDistance = dx * dx + dz * dz
                    if not nearestStartLocation then
                        nearestStartLocation = startLocation
                        nearestStartLocationDistance = startLocationDistance
                    else
                        if startLocationDistance <  nearestStartLocationDistance then
                            nearestStartLocation = startLocation
                            nearestStartLocationDistance = startLocationDistance
                        end
                    end
                end
        
                -- assimilate it into the spawn location
                if nearestStartLocationDistance and math.sqrt(nearestStartLocationDistance) < threshold then
                    local extractors = nearestStartLocation.resourcemarkers
                    for k, resource in zone.resourcemarkers do
                        table.insert(extractors, resource)
                    end
        
                    --local hydrocarbonPlants = nearestStartLocation.HydrocarbonPlants
                    --for k, resource in expansion.HydrocarbonPlants do
                    --    table.insert(hydrocarbonPlants, resource)
                    --end
                else
                    zoneList[head] = zone
                    head = head + 1
                end
            end
        
            ---------------------------------------------------------------------------
            -- clean up remaining expansions
        
            for k = head, zoneCount do
                zoneList[k] = nil
            end
            for _, v in startLocations do
                zoneList[head] = {pos=v.Position, component=MAP:GetComponent(v.Position,self.layer), weight=table.getn(v.resourcemarkers), startpositionclose=true, enemylandthreat=0, enemyantiairthreat=0, friendlyantisurfacethreat=0, friendlylandantiairthreat=0, friendlydirectfireantisurfacethreat=0, friendlyindirectantisurfacethreat=0,resourcevalue=table.getn(v.resourcemarkers), resourcemarkers=v.resourcemarkers, zonealert=false, control=1, enemystartdata = { }, allystartdata = { },  bestarmy = false, teamvalue = 1, platoonassigned = false, label = 0, BuilderManager = {}, lastexpansionattempt = 0, engineerallocated = false}
                head = head + 1
            end
        
            return zoneList, head - 1
        end
        -- Step 1: Get a set of markers that are in the layer we're currently interested in.
        local maxmapdimension = math.max(ScenarioInfo.size[1],ScenarioInfo.size[2])
        local threshold = 400 + maxmapdimension
        local zoneRadius = threshold

        local markers = {}
        for _, marker in GetMarkers() do
            if marker.type == 'Mass' then
                if MAP:GetComponent(marker.position,self.layer) > 0 then
                    table.insert(markers,marker)
                end
            end
        end
        for _, v in markers do
            v.component = MAP:GetComponent(v.position,self.layer)
        end
        local complete = (RNGGETN(markers) == 0)
        local initialZones = {}
        local initialZoneCount = 0
       --RNGLOG('Starting GenerateZoneList Loop')
        while not complete do
            complete = true
            -- Update weights
            local startPos = false
            for _, v in markers do
                v.weight = 1
                v.aggX = v.position[1]
                v.aggZ = v.position[3]
            end
            for _, v1 in markers do
                if not v1.claimed then
                    for _, v2 in markers do
                        if (not v2.claimed) and (v1 ~= v2) and v1.component == v2.component and VDist2Sq(v1.position[1], v1.position[3], v2.position[1], v2.position[3]) < zoneRadius then
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
            local resourceGroup = {best}
            best.claimed = true
            local x = best.aggX/best.weight
            local z = best.aggZ/best.weight

            -- Claim nearby points
            for _, v in markers do
                if (not v.claimed) and VDist2Sq(v.position[1], v.position[3], best.position[1], best.position[3]) < zoneRadius then
                    table.insert(resourceGroup, v)
                    v.claimed = true
                elseif not v.claimed then
                    complete = false
                end
            end
            initialZoneCount = initialZoneCount + 1
            table.insert(initialZones, {pos={x,GetSurfaceHeight(x,z),z}, component=MAP:GetComponent({x,GetSurfaceHeight(x,z),z},self.layer), weight=best.weight, startpositionclose=startPos, enemylandthreat=0, enemyantiairthreat=0, friendlyantisurfacethreat=0, friendlylandantiairthreat=0, friendlydirectfireantisurfacethreat=0, friendlyindirectantisurfacethreat=0,resourcevalue=table.getn(resourceGroup), resourcemarkers=resourceGroup, zonealert=false, control=1, enemystartdata = { }, allystartdata = { },  bestarmy = false, teamvalue = 1, platoonassigned = false, label = 0, BuilderManager = {}, lastexpansionattempt = 0, engineerallocated = false})
        end
        local finalZonesList, zoneCount = AssimilateZones(initialZones, initialZoneCount)
        for i=1, zoneCount do
            self:AddZone(finalZonesList[i])
        end
    end,
}

-- Now implement a 'GetZoneSetClasses' function to export the zones you want to include in the game.
function GetZoneSetClasses()
    -- Set to true if you want to test this
    local RNGLandResourceSetEnabled = true
    if RNGLandResourceSetEnabled then
        -- Include as many classes here as you like (and are willing to take the performance hit for).
        return {RNGLandResourceSet}
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
