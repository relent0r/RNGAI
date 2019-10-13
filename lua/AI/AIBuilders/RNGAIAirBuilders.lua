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
        BuilderName = 'RNGAI Factory Bomber',
        PlatoonTemplate = 'T1AirBomber',
        Priority = 850,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatio', { 0.0, 0.7}},
            { EBC, 'GreaterThanEconTrend', { 0.7, 7.0 }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 3, categories.AIR * categories.BOMBER } },
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory Intie',
        PlatoonTemplate = 'T1AirFighter',
        Priority = 850,
        BuilderConditions = { 
            { EBC, 'GreaterThanEconTrend', { 0.5, 7.0 }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 6, categories.AIR * categories.ANTIAIR } },
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory Intie',
        PlatoonTemplate = 'T1AirFighter',
        Priority = 500,
        BuilderConditions = { 
            { EBC, 'GreaterThanEconTrend', { 0.5, 7.0 }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 18, categories.AIR * categories.ANTIAIR } },
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory Intie Small',
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
        PlatoonTemplate = 'RNGAI AntiAirHunt',
        Priority = 900,
        InstanceCount = 5,
        BuilderType = 'Any',
        BuilderData = {
            NeverGuardEngineers = true,
        },
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.AIR * categories.MOBILE * (categories.TECH1 + categories.TECH2 + categories.TECH3) * categories.ANTIAIR } },
         },
    },
    Builder {
        BuilderName = 'RNGAI AntiAir Base Guard',
        PlatoonTemplate = 'RNGAI AntiAirBaseGuard',
        Priority = 800,
        InstanceCount = 2,
        BuilderType = 'Any',
        BuilderData = {
            NeverGuardEngineers = true,
            GuardRadius = 200, -- this is in the guardBase function as self.PlatoonData.GuardRadius
        },
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.AIR * categories.MOBILE * (categories.TECH1 + categories.TECH2) * categories.ANTIAIR } },
        },
    },
    Builder {
        BuilderName = 'RNGAI Air Attack',
        PlatoonTemplate = 'RNGAI BomberAttack',
        Priority = 900,
        InstanceCount = 3,
        BuilderType = 'Any',        
        BuilderConditions = { },
        BuilderData = {
            SearchRadius = 100,
            PrioritizedCategories = {
                'MASSEXTRACTION',
                'ENGINEER TECH1',
                'MOBILE ANTIAIR',
                'ALLUNITS',
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Air Intercept Response',
        PlatoonTemplate = 'RNGAI AntiAirHunt',
        Priority = 950,
        InstanceCount = 5,
        BuilderType = 'Any',     
        BuilderConditions = { 
            { UCBC, 'HaveUnitsWithCategoryAndAlliance', { true, 1, categories.AIR * categories.BOMBER * categories.ANTIAIR, 'Enemy'}}, -- Check if enemy has air units
        },
    },
}