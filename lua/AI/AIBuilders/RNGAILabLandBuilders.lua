--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Land Builders
]]

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI LabLandBuilder',
    BuildersType = 'FactoryBuilder',
    -- Opening Lab Build --
    Builder {
        BuilderName = 'RNGAI Factory Lab',
        PlatoonTemplate = 'T1LandDFBot',
        Priority = 900, -- Try to get out before second engie group
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.MOBILE * categories.ENGINEER}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.LAND * categories.MOBILE - categories.ENGINEER }},
            { MIBC, 'FactionIndex', { 1, 2, 3, 5 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'LessThanGameTimeSeconds', { 180 } }, -- don't build after 3 minutes
        },
        BuilderType = 'Land',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Mass Hunter Labs FormBuilders',
    BuildersType = 'PlatoonFormBuilder',
    
    Builder {
        BuilderName = 'RNGAI Lab Early Game',
        PlatoonTemplate = 'RNGAI T1 Mass Raiders Small',
        Priority = 1000,
        BuilderConditions = {  
                { MIBC, 'LessThanGameTime', { 180 } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.MOBILE * categories.LAND }},      	
            },
        BuilderData = {
            MarkerType = 'Mass',            
            MoveFirst = 'Random',
            MoveNext = 'Threat',
            ThreatType = 'Economy',			    -- Type of threat to use for gauging attacks
            FindHighestThreat = true,			-- Don't find high threat targets
            MaxThreatThreshold = 2900,			-- If threat is higher than this, do not attack
            MinThreatThreshold = 1000,			-- If threat is lower than this, do not attack
            AvoidBases = false,
            AvoidBasesRadius = 75,
            AggressiveMove = true,      
            AvoidClosestRadius = 50,  
        },    
        InstanceCount = 2,
        BuilderType = 'Any',
    },
}