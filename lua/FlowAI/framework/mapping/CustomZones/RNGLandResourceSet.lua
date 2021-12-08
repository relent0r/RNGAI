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

-- We'll use these too later
local GetMarkers = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
local MAP = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMap()

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
        -- Step 1: Get a set of markers that are in the layer we're currently interested in.
        LOG('GenerateZoneList for custom Zone')
        local armyStarts = {}
        local zoneRadius = 50 * 50
        for i = 1, 16 do
            local army = ScenarioInfo.ArmySetup['ARMY_' .. i]
            local startPos = ScenarioUtils.GetMarker('ARMY_' .. i).position
            if army and startPos then
                table.insert(armyStarts, startPos)
            end
        end
        local markers = {}
        for _, marker in GetMarkers() do
            if MAP:GetComponent(marker.position,self.layer) > 0 then
                table.insert(markers,marker)
            end
        end
        complete = (RNGGETN(markers) == 0)
        LOG('Starting GenerateZoneList Loop')
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
                        if (not v2.claimed) and VDist2Sq(v1.position[1], v1.position[3], v2.position[1], v2.position[3]) < zoneRadius then
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
            local massGroup = {best.position}
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
            --table.insert(zones,CreateZoneRNG({x,GetSurfaceHeight(x,z),z},best.weight,zoneID, 60, startPos))
            self:AddZone({pos={x,GetSurfaceHeight(x,z),z}, weight=best.weight, startpositionclose=startPos, enemythreat=0, friendlythreat=0})
            -- Claim nearby points
            for _, v in markers do
                if (not v.claimed) and VDist2Sq(v.position[1], v.position[3], best.position[1], best.position[3]) < zoneRadius then
                    table.insert(massGroup, v.position)
                    v.claimed = true
                elseif not v.claimed then
                    complete = false
                end
            end
            
            --zones[zoneID].MassPoints = {}
            --zones[zoneID].MassPoints = massGroup
            --[[for k, v in zones do
                if v.ID == zoneID then
                    if not v.MassPoints then
                        v.MassPoints = {}
                    end
                    v.MassPoints = massGroup
                    break
                end
            end
            zoneID = zoneID + 1]]
        end
        --[[for k, v in zones do
            for k1, v1 in v.MassPoints do
                for k2, v2 in AdaptiveResourceMarkerTableRNG do
                    if v1[1] == v2.position[1] and v1[3] == v2.position[3] then
                        AdaptiveResourceMarkerTableRNG[k2].zoneid = v.ID
                    end
                end
            end
        end]]
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
