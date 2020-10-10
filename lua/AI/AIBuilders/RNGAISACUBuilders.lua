local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI SACU Builder',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI SACU Engineer',
        PlatoonTemplate = 'RNGAI SACU Engineer preset',
        Priority = 400,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 15, categories.SUBCOMMANDER } },
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
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
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.04, 0.50}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.SUBCOMMANDER }},
        },
        BuilderType = 'Gate',
    },
}