--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Land Builders
]]

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

--[[BuilderGroup {
    BuilderGroupName = 'RNGAI LabLandBuilder',
    BuildersType = 'FactoryBuilder',
    -- Opening Lab Build --
    Builder {
        BuilderName = 'RNGAI Factory Lab',
        PlatoonTemplate = 'T1LandDFBot',
        Priority = 900, -- Try to get out before second engie group
        BuilderConditions = {
            { UCBC, 'LessThanGameTimeSecondsRNG', { 180 } }, -- don't build after 3 minutes
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.MOBILE * categories.ENGINEER}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.LAND * categories.MOBILE - categories.ENGINEER }},
            { MIBC, 'FactionIndex', { 1, 2, 3, 5 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
        },
        BuilderType = 'Land',
    },
}]]

BuilderGroup {
    BuilderGroupName = 'RNGAI Mass Hunter Labs FormBuilders',
    BuildersType = 'PlatoonFormBuilder',
    
    Builder {
        BuilderName = 'RNGAI Lab Early Game',
        PlatoonTemplate = 'RNGAI T1 Mass Raiders Mini',
        PlatoonAddBehaviors = { 'ZoneUpdate' },
        Priority = 1000,
        InstanceCount = 4,
        BuilderConditions = {  
                { MIBC, 'LessThanGameTime', { 320 } },
                { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.LAND * categories.DIRECTFIRE } },      	
            },
        BuilderType = 'Any',
        BuilderData = {
            MarkerType = 'Mass',            
            MoveFirst = 'Random',
            MoveNext = 'Threat',
            Avoid        = true,
            ThreatType = 'Economy',			    -- Type of threat to use for gauging attacks
            FindHighestThreat = true,			-- Don't find high threat targets
            MaxThreatThreshold = 3900,			-- If threat is higher than this, do not attack
            MinThreatThreshold = 1000,			-- If threat is lower than this, do not attack
            AvoidBases = true,
            AvoidBasesRadius = 150,
            AggressiveMove = true,      
            AvoidClosestRadius = 50,
            EarlyRaid = true,
            TargetSearchPriorities = { 
                categories.MOBILE * categories.LAND
            },
            PrioritizedCategories = {   
                categories.ENGINEER,
                categories.MASSEXTRACTION,
                categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MOBILE * categories.LAND,
                categories.STRUCTURE * categories.DEFENSE,
                categories.STRUCTURE,
            },
        },    
    },
}