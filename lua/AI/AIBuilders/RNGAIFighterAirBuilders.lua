--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAIFighterAirBuilders.lua
    Author  :   relentless
    Summary :
        Air Builders
]]

local EBC = '/lua/editor/EconomyBuildConditions.lua'
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI Air Builder',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'MicroAI Factory Bomber',
        PlatoonTemplate = 'T1AirBomber',
        Priority = 900,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatio', { 0.0, 0.7}},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 3, categories.AIR * categories.BOMBER } },
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'MicroAI Factory Intie',
        PlatoonTemplate = 'T1AirFighter',
        Priority = 850,
        BuilderConditions = { 
            { EBC, 'GreaterThanEconStorageRatio', { 0.0, 0.7}},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 6, categories.AIR * categories.ANTIAIR } },
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'MicroAI Factory Intie',
        PlatoonTemplate = 'T1AirFighter',
        Priority = 950,
        BuilderConditions = { 
            { EBC, 'GreaterThanEconStorageRatio', { 0.0, 0.7}},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 2, categories.AIR * categories.ANTIAIR } },
        },
        BuilderType = 'Air',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Air Platoon Builder',
    BuildersType = 'PlatoonFormBuilder', -- A PlatoonFormBuilder is for builder groups of units.
    Builder {
        BuilderName = 'RNGAI Air Intercept',
        PlatoonTemplate = 'AntiAirHunt',
        Priority = 900,
        InstanceCount = 5,
        BuilderType = 'Any',     
        BuilderConditions = { },
    },
    Builder {
        BuilderName = 'RNGAI Air Attack',
        PlatoonTemplate = 'BomberAttack',
        Priority = 900,
        InstanceCount = 6,
        BuilderType = 'Any',        
        BuilderConditions = { },
        BuilderData = {
            PrioritizedCategories = {
                'MASSEXTRACTION',
                'ENGINEER TECH1',
                'MOBILE ANTIAIR',
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Air Intercept Response',
        PlatoonTemplate = 'AntiAirHunt',
        Priority = 950,
        InstanceCount = 5,
        BuilderType = 'Any',     
        BuilderConditions = { 
            { UCBC, 'HaveUnitsWithCategoryAndAlliance', { true, 1, categories.AIR * categories.BOMBER, 'Enemy'}}, -- Check if enemy has one bomber or more
        },
    },
}