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
        for i, startA in startLocations do
            for j, startB in startLocations do
                if i < j then 
                    local midX = (startA.position[1] + startB.position[1]) / 2
                    local midZ = (startA.position[3] + startB.position[3]) / 2
                    local midY = GetSurfaceHeight(midX, midZ)
                    
                    -- We give these 'Buffer' zones a priority to distinguish them
                    table.insert(airSeeds, {
                        position = {midX, midY, midZ},
                        isStartLocation = false,
                        isMidpoint = true,
                        priority = 5
                    })
                end
            end
            table.insert(airSeeds, {
                position = startA.position,
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
            --LOG('RNGAI: Air Zone Created at ' .. tostring(posX) .. ',' .. tostring(posZ))
            --LOG('RNGAI: Zone ' .. table.getn(self.zones) .. ' captured ' .. totalWeight .. ' mass markers.')
            --if totalWeight == 0 then
            --    LOG('RNGAI: WARNING - Empty Air Zone. AI may have a blind spot here.')
            --end
            self:AddZone({
                pos = {posX, posY, posZ},
                component=MAP:GetComponent({posX, posY, posZ},self.layer),
                --component = 1, -- Placeholder as Air is globally connected
                weight = totalWeight,
                startpositionclose = seed.isStartLocation,
                resourcevalue = totalWeight,
                resourcemarkers = capturedMarkers,
                status = 'Unoccupied',
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