local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI SACU Builder',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI SACU Engineer',
        PlatoonTemplate = 'RNGAI SACU Engineer preset',
        Priority = 500,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.SUBCOMMANDER } },
            { EBC, 'GreaterThanEconTrend', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatio', { 0.05, 0.75}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 1, categories.SUBCOMMANDER }},
        },
        BuilderType = 'Gate',
    },
}