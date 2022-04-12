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
        Priority = 500,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 15, categories.SUBCOMMANDER } },
            { EBC, 'GreaterThanEconTrendCombinedRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.20, 0.75}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.SUBCOMMANDER }},
        },
        BuilderType = 'Gate',
    },
    Builder {
        BuilderName = 'RNGAI SACU Engineer',
        PlatoonTemplate = 'T3LandSubCommander',
        Priority = 400,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 6, categories.SUBCOMMANDER } },
            { EBC, 'GreaterThanEconTrendCombinedRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.06, 0.75}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.SUBCOMMANDER }},
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
        Priority = 500,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 15, categories.SUBCOMMANDER } },
            { EBC, 'GreaterThanEconTrendCombinedRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.20, 0.75}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.SUBCOMMANDER }},
        },
        BuilderType = 'Gate',
    },
    Builder {
        BuilderName = 'RNGEXP SACU Engineer',
        PlatoonTemplate = 'T3LandSubCommander',
        Priority = 400,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 6, categories.SUBCOMMANDER } },
            { EBC, 'GreaterThanEconTrendCombinedRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.06, 0.75}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.SUBCOMMANDER }},
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
        },
        BuilderType = 'Gate',
    },
}