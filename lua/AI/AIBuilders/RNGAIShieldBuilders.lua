local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local IBC = '/lua/editor/InstantBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI Shield Builder',                   
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Shield Ratio',
        PlatoonTemplate = 'T2EngineerBuilder',
        Priority = 600,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'HaveUnitRatioAtLocation', { 'LocationType', 1.0, categories.STRUCTURE * categories.SHIELD, '<=',categories.STRUCTURE * categories.TECH3 * (categories.ENERGYPRODUCTION + categories.FACTORY) } },
            { MIBC, 'FactionIndex', { 1, 2, 3, 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads 
            { EBC, 'GreaterThanEconStorageRatio', { 0.05, 0.80 } },
            { UCBC, 'GreaterThanEnergyTrend', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 2, categories.STRUCTURE * categories.SHIELD}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 10, categories.STRUCTURE * categories.SHIELD * (categories.TECH2 + categories.TECH3) } },
            { UCBC, 'HaveUnitRatioVersusCap', { 0.12 / 2, '<', categories.STRUCTURE * categories.DEFENSE * categories.SHIELD } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                DesiresAssist = true,
                NumAssistees = 4,
                BuildClose = true,
                AdjacencyCategory = (categories.ENERGYPRODUCTION * categories.TECH3) + (categories.ENERGYPRODUCTION * categories.EXPERIMENTAL) + (categories.STRUCTURE * categories.FACTORY),
                AvoidCategory = categories.STRUCTURE * categories.SHIELD,
                maxUnits = 1,
                maxRadius = 25,
                LocationType = 'LocationType',
                BuildStructures = {
                    'T2ShieldDefense',
                },
            },
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Shields Upgrader',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI Shield Cybran 1',
        PlatoonTemplate = 'T2Shield1',
        Priority = 700,
        DelayEqualBuildPlattons = {'Shield', 2},
        InstanceCount = 5,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatio', { 0.03, 0.50}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconTrend', { 0.0, 0.0 } }, -- relative income
            { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH3 * categories.ENERGYPRODUCTION}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgrade', { 3, categories.STRUCTURE * categories.SHIELD }},
            { UCBC, 'CheckBuildPlattonDelay', { 'Shield' }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Shield Cybran 2',
        PlatoonTemplate = 'T2Shield2',
        Priority = 700,
        DelayEqualBuildPlattons = {'Shield', 2},
        InstanceCount = 5,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatio', { 0.30, 0.50}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconTrend', { 0.0, 0.0 } }, -- relative income
            { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH3 * categories.ENERGYPRODUCTION}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgrade', { 3, categories.STRUCTURE * categories.SHIELD }},
            { UCBC, 'CheckBuildPlattonDelay', { 'Shield' }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Shield Cybran 3',
        PlatoonTemplate = 'T2Shield3',
        Priority = 700,
        DelayEqualBuildPlattons = {'Shield', 2},
        InstanceCount = 5,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatio', { 0.30, 0.50}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconTrend', { 0.0, 0.0 } }, -- relative income
            { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH3 * categories.ENERGYPRODUCTION}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgrade', { 3, categories.STRUCTURE * categories.SHIELD }},
            { UCBC, 'CheckBuildPlattonDelay', { 'Shield' }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Shield Cybran 4',
        PlatoonTemplate = 'T2Shield4',
        Priority = 700,
        DelayEqualBuildPlattons = {'Shield', 2},
        InstanceCount = 5,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatio', { 0.30, 0.90 } },             -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconTrend', { 0.0, 0.0 } }, -- relative income
            { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 1, categories.TECH3 * categories.ENERGYPRODUCTION}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgrade', { 3, categories.STRUCTURE * categories.SHIELD }},
            { UCBC, 'CheckBuildPlattonDelay', { 'Shield' }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Shield UEF Seraphim',
        PlatoonTemplate = 'T2Shield',
        Priority = 700,
        DelayEqualBuildPlattons = {'Shield', 2},
        InstanceCount = 5,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatio', { 0.30, 0.90 } },             -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconTrend', { 0.0, 0.0 } }, -- relative income
            { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 1, categories.TECH3 * categories.ENERGYPRODUCTION}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgrade', { 3, categories.STRUCTURE * categories.SHIELD }},
            { UCBC, 'CheckBuildPlattonDelay', { 'Shield' }},
        },
        BuilderType = 'Any',
    },
}