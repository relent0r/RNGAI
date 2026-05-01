local ZoneSet = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Zones.lua').ZoneSet
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

local MAP = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMap()

RNGAirResourceSet = Class(ZoneSet){
    Init = function(self, zoneIndex)
        ZoneSet.Init(self, zoneIndex)
        self.layer = 0
        self.name = 'RNGAirResourceSet'
    end,

    GenerateZoneList = function(self)
        local airSeeds = {}
        
        -- 1. Seeding from Start Locations
        local startLocations = import("/lua/sim/markerutilities.lua").GetMarkersByType('Start Location')
        for _, start in startLocations do
            table.insert(airSeeds, {
                position = start.position,
                isStartLocation = true,
                priority = 10
            })
        end

        -- 2. Expansion Radius (Conceptual limit for value calculation)
        local mapSize = math.max(ScenarioInfo.size[1], ScenarioInfo.size[2])
        local zoneRadiusSq = (120 + (mapSize * 0.1)) ^ 2 

        -- 3. Gather Mass markers for SVS (Strategic Value Scoring)
        -- Using your existing GetMarkersRNG from Mapping.lua
        local GetMarkers = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
        local allMassMarkers = {}
        for _, marker in GetMarkers() do
            if marker.type == 'Mass' then
                table.insert(allMassMarkers, marker)
            end
        end

        -- 4. Build the Zone Table for the Painter
        for _, seed in airSeeds do
            local x, z = seed.position[1], seed.position[3]
            
            local capturedMarkers = {}
            local totalWeight = 0
            
            for _, m in allMassMarkers do
                local distSq = VDist2Sq(x, z, m.position[1], m.position[3])
                if distSq < zoneRadiusSq then
                    table.insert(capturedMarkers, m)
                    totalWeight = totalWeight + 1
                end
            end
            
            local posX = math.floor(x)
            local posZ = math.floor(z)
            local posY = GetSurfaceHeight(posX, posZ)
            LOG('Adding air zone '..tostring(repr({posX, posY, posZ}))..' is this a player start zone '..tostring(repr(seed.isStartLocation)))
            self:AddZone({
                pos = {posX, posY, posZ},
                component=MAP:GetComponent({posX, posY, posZ},self.layer),
                --component = 1, -- Placeholder as Air is globally connected
                weight = totalWeight,
                startpositionclose = seed.isStartLocation,
                resourcevalue = totalWeight,
                resourcemarkers = capturedMarkers,
                status = 'Unoccupied',
                platoonallocations = {
                    friendlyantiairallocatedthreat = 0, 
                    friendlydirectfireallocatedthreat = 0
                },
            })
        end
    end,
}

function GetZoneSetClasses()
    return {RNGAirResourceSet}
end