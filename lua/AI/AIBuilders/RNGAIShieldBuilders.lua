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
            { MIBC, 'FactionIndex', { 1, 3, 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads 
            { EBC, 'GreaterThanEconStorageRatio', { 0.10, 0.95 } },
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