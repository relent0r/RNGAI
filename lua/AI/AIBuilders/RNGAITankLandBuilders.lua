--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Land Builders
]]

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local IBC = '/lua/editor/InstantBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI TankLandBuilder',
    BuildersType = 'FactoryBuilder',
    -- Opening Tank Build --
    Builder {
        BuilderName = 'RNGAI Factory Tank Sera', -- Sera only because they don't get labs
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 900, -- After First Engie Group and scout
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.MOBILE * categories.ENGINEER}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.LAND * categories.MOBILE - categories.ENGINEER }},
            { UCBC, 'LessThanGameTimeSeconds', { 240 } }, -- don't build after 4 minutes
            { MIBC, 'FactionIndex', { 4, }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Tank 9',
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 800, -- After Second Engie Group
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.MOBILE * categories.ENGINEER}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 9, categories.LAND * categories.MOBILE - categories.ENGINEER }},
            { UCBC, 'LessThanGameTimeSeconds', { 360 } }, -- don't build after 6 minutes
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Tank 24',
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 750, -- After Second Engie Group
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.MOBILE * categories.ENGINEER}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 24, categories.LAND * categories.MOBILE - categories.ENGINEER }},
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T1 Mortar 9',
        PlatoonTemplate = 'T1LandArtillery',
        Priority = 700,
        BuilderConditions = {
            { UCBC, 'HaveUnitRatio', { 0.25, categories.LAND * categories.INDIRECTFIRE * categories.MOBILE, '<=', categories.LAND * categories.DIRECTFIRE * categories.MOBILE}},
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 1, 'FACTORY LAND TECH3' }},
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 1.05 }},
        },
        BuilderType = 'Land',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Land FormBuilders AntiMass',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    Builder {
        BuilderName = 'RNGAI Anti Mass Small',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Small',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
        Priority = 900,                                                          -- Priority. 1000 is normal.
        InstanceCount = 4,                                                      -- Number of plattons that will be formed.
        BuilderType = 'Any',
        BuilderData = {
            SearchRadius = 120,                                               -- Searchradius for new target.
            GetTargetsFromBase = true,                                         -- Get targets from base position (true) or platoon position (false)
            RequireTransport = false,                                           -- If this is true, the unit is forced to use a transport, even if it has a valid path to the destination.
            AggressiveMove = false,                                              -- If true, the unit will attack everything while moving to the target.
            AttackEnemyStrength = 200,                                          -- Compare platoon to enemy strenght. 100 will attack equal, 50 weaker and 150 stronger enemies.
            TargetSearchCategory = categories.MASSEXTRACTION + categories.ENGINEER, -- Only find targets matching these categories.
            PrioritizedCategories = {                                           -- Attack these targets.
                'MASSEXTRACTION',
                'ENGINEER',
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Anti Mass Medium',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Medium',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
        Priority = 850,                                                          -- Priority. 1000 is normal.
        InstanceCount = 6,                                                      -- Number of plattons that will be formed.
        BuilderType = 'Any',
        BuilderData = {
            SearchRadius = 10000,                                               -- Searchradius for new target.
            GetTargetsFromBase = false,                                         -- Get targets from base position (true) or platoon position (false)
            RequireTransport = false,                                           -- If this is true, the unit is forced to use a transport, even if it has a valid path to the destination.
            AggressiveMove = true,                                              -- If true, the unit will attack everything while moving to the target.
            AttackEnemyStrength = 200,                                          -- Compare platoon to enemy strenght. 100 will attack equal, 50 weaker and 150 stronger enemies.
            TargetSearchCategory = categories.MASSEXTRACTION + categories.ENGINEER, -- Only find targets matching these categories.
            PrioritizedCategories = {                                           -- Attack these targets.
                'MASSEXTRACTION',
                'ALLUNITS',
            },
        },
    },
}