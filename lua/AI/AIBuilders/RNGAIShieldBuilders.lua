local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI Shield Builder',                   
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T2 Shield Ratio',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 625,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'HaveUnitRatioAtLocationRNG', { 'LocationType', 1.0, categories.STRUCTURE * categories.SHIELD, '<=',categories.STRUCTURE * categories.TECH3 * (categories.ENERGYPRODUCTION + categories.FACTORY) } },
            { MIBC, 'FactionIndex', { 1, 3, 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads 
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.06, 0.80 } },
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.STRUCTURE * categories.SHIELD}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 20, categories.STRUCTURE * categories.SHIELD * (categories.TECH2 + categories.TECH3) } },
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
                maxRadius = 35,
                LocationType = 'LocationType',
                BuildStructures = {
                    'T2ShieldDefense',
                },
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Shield Ratio',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 650,
        InstanceCount = 2,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2, 5 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads 
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.06, 0.80 } },
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.STRUCTURE * categories.SHIELD}},
            { UCBC, 'HaveUnitRatioAtLocationRNG', { 'LocationType', 1.0, categories.STRUCTURE * categories.SHIELD, '<=',categories.STRUCTURE * categories.TECH3 * (categories.ENERGYPRODUCTION + categories.FACTORY) } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 20, categories.STRUCTURE * categories.SHIELD * (categories.TECH2 + categories.TECH3) } },
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
                maxRadius = 35,
                LocationType = 'LocationType',
                BuildStructures = {
                    'T3ShieldDefense',
                }
            }
        }
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
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } }, -- relative income
            { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH3 * categories.ENERGYPRODUCTION}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 2, categories.STRUCTURE * categories.SHIELD }},
            { UCBC, 'CheckBuildPlatoonDelay', { 'Shield' }},
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
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } }, -- relative income
            { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH3 * categories.ENERGYPRODUCTION}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 2, categories.STRUCTURE * categories.SHIELD }},
            { UCBC, 'CheckBuildPlatoonDelay', { 'Shield' }},
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
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } }, -- relative income
            { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH3 * categories.ENERGYPRODUCTION}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 2, categories.STRUCTURE * categories.SHIELD }},
            { UCBC, 'CheckBuildPlatoonDelay', { 'Shield' }},
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
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.80 } },             -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } }, -- relative income
            { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 1, categories.TECH3 * categories.ENERGYPRODUCTION}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 2, categories.STRUCTURE * categories.SHIELD }},
            { UCBC, 'CheckBuildPlatoonDelay', { 'Shield' }},
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
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.80 } },             -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } }, -- relative income
            { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 1, categories.TECH3 * categories.ENERGYPRODUCTION}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 2, categories.STRUCTURE * categories.SHIELD }},
            { UCBC, 'CheckBuildPlatoonDelay', { 'Shield' }},
        },
        BuilderType = 'Any',
    },
}