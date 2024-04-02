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
        -- Step 1: Get a set of markers that are in the layer we're currently interested in.
       --RNGLOG('GenerateZoneList for custom Zone')
        local armyStarts = {}
        local maxmapdimension = math.max(ScenarioInfo.size[1],ScenarioInfo.size[2])
        local mapCenterPoint = { (ScenarioInfo.size[1] / 2), 0 ,(ScenarioInfo.size[2] / 2) }
        local zoneRadius = 50 * 50
        if maxmapdimension < 512 then
            zoneRadius = 35 * 35
        end
        --RNGLOG('Zone Radius is '..zoneRadius)
        for i = 1, 16 do
            local army = ScenarioInfo.ArmySetup['ARMY_' .. i]
            local startPos = ScenarioUtils.GetMarker('ARMY_' .. i).position
            if army and startPos then
                table.insert(armyStarts, startPos)
            end
        end
        local markers = {}
        for _, marker in GetMarkers() do
            if marker.type == 'Mass' then
                if MAP:GetComponent(marker.position,self.layer) > 0 then
                    table.insert(markers,marker)
                end
            end
        end
        local complete = (RNGGETN(markers) == 0)
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
            local resourceGroup = {best}
            best.claimed = true
            local x = best.aggX/best.weight
            local z = best.aggZ/best.weight
            for _, p in armyStarts do
                if VDist2Sq(p[1], p[3],x, z) < (zoneRadius) then
                   --RNGLOG('Start Position Taken '..repr(p))
                    startPos = true
                    break
                end
            end

            -- Claim nearby points
            for _, v in markers do
                if (not v.claimed) and VDist2Sq(v.position[1], v.position[3], best.position[1], best.position[3]) < zoneRadius then
                    table.insert(resourceGroup, v)
                    v.claimed = true
                elseif not v.claimed then
                    complete = false
                end
            end
            --LOG('Resource Group value '..table.getn(resourceGroup))
            self:AddZone({pos={x,GetSurfaceHeight(x,z),z}, component=MAP:GetComponent({x,GetSurfaceHeight(x,z),z},self.layer), weight=best.weight, startpositionclose=startPos, enemylandthreat=0, enemyantiairthreat=0, friendlythreat=0, friendlyantiairthreat=0, resourcevalue=table.getn(resourceGroup), resourcemarkers=resourceGroup, zonealert=false, control=1, enemystartdata = { }, allystartdata = { },  bestarmy = false, teamvalue = 1})
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
