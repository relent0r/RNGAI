local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

BuilderGroup {
    BuilderGroupName = 'RNGAI SACU Builder',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI SACU Engineer',
        PlatoonTemplate = 'RNGAI SACU Engineer preset',
        Priority = 710,
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Engineer', 'T3', 'sacueng'} },
            { EBC, 'FactorySpendRatioRNG', {'LocationType', 'Land', 'LandUpgrading', nil, true}},
            { EBC, 'GreaterThanEconTrendCombinedRNG', { 0.0, 0.0 } },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Gate',
    },
    Builder {
        BuilderName = 'RNGAI SACU',
        PlatoonTemplate = 'T3LandSubCommander',
        Priority = 400,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 6, categories.SUBCOMMANDER } },
            { EBC, 'GreaterThanEconTrendCombinedRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.06, 0.75}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.SUBCOMMANDER }},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Gate',
    },
    Builder {
        BuilderName = 'RNGAI SACU RAS',
        PlatoonTemplate = 'RNGAI SACU RAS preset 123x5',
        Priority = 700,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 12, categories.SUBCOMMANDER } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.9, 1.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.50}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.SUBCOMMANDER }},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Gate',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGEXP SACU Builder',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGEXP SACU Engineer',
        PlatoonTemplate = 'RNGAI SACU Engineer preset',
        Priority = 710,
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Engineer', 'T3', 'sacueng'} },
            { EBC, 'FactorySpendRatioRNG', {'LocationType', 'Land', 'LandUpgrading', nil, true}},
            { EBC, 'GreaterThanEconTrendCombinedRNG', { 3.0, 450.0 } },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Gate',
    },
    Builder {
        BuilderName = 'RNGEXP SACU',
        PlatoonTemplate = 'T3LandSubCommander',
        Priority = 400,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 6, categories.SUBCOMMANDER } },
            { EBC, 'GreaterThanEconTrendCombinedRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.06, 0.9}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.SUBCOMMANDER }},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Gate',
    },
    Builder {
        BuilderName = 'RNGEXP SACU RAS',
        PlatoonTemplate = 'RNGAI SACU RAS preset 123x5',
        Priority = 700,
        BuilderConditions = {
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'SCU' } },
            { EBC, 'GreaterThanEconTrendCombinedRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.04, 0.50}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Gate',
    },
}