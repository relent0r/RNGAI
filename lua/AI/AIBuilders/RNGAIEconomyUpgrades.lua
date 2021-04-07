--[[ Disabling all economy upgrade builders post mex platoon implementation
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local IBC = '/lua/editor/InstantBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI ExtractorUpgrades',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Mass Extractor Upgrade Single 10000',
        PlatoonTemplate = 'T1MassExtractorUpgrade',
        InstanceCount = 1,
        Priority = 100,
        BuilderConditions = {

            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 1.0 }},
            { MIBC, 'GreaterThanGameTimeRNG', { 1200 } },
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.MASSEXTRACTION } },
        },
        FormRadius = 10000,
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Mass Extractor Upgrade Single 60',
        PlatoonTemplate = 'T1MassExtractorUpgrade',
        InstanceCount = 1,
        Priority = 400,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },

            { EBC, 'GreaterThanEconStorageCurrentRNG', { 200, 0 } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.6 }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.MASSEXTRACTION * categories.TECH1 } },
        },
        FormRadius = 60,
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Mass Extractor Upgrade Single 120',
        PlatoonTemplate = 'T1MassExtractorUpgrade',
        InstanceCount = 1,
        Priority = 300,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 480 } },

            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.6 }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.MASSEXTRACTION * categories.TECH1 } },
        },
        FormRadius = 120,
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Mass Extractor Upgrade Single 120 excess',
        PlatoonTemplate = 'T1MassExtractorUpgrade',
        InstanceCount = 1,
        Priority = 300,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 120 } },

            { EBC, 'GreaterThanEconStorageCurrentRNG', { 500, 0 } },
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 3, categories.MASSEXTRACTION * categories.TECH1 } },
        },
        FormRadius = 120,
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Mass Extractor Upgrade Single 1000',
        PlatoonTemplate = 'T1MassExtractorUpgrade',
        InstanceCount = 1,
        Priority = 200,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 660 } },

            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 1.0 }},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.MASSEXTRACTION * categories.TECH1 } },
        },
        FormRadius = 1000,
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Mass Extractor Upgrade Single 10000',
        PlatoonTemplate = 'T2MassExtractorUpgrade',
        InstanceCount = 1,
        Priority = 200,
        BuilderConditions = {

            { EBC, 'GreaterThanEconIncomeRNG',  { 2.8, 30}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 1.0 }},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { MIBC, 'GreaterThanGameTimeRNG', { 1500 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.MASSEXTRACTION } },
        },
        FormRadius = 10000,
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Mass Extractor Upgrade Single 120',
        PlatoonTemplate = 'T2MassExtractorUpgrade',
        InstanceCount = 1,
        Priority = 400,
        BuilderConditions = {
            {UCBC, 'HaveUnitRatio', {0.80, categories.MASSEXTRACTION * categories.TECH1, '<=', categories.MASSEXTRACTION * categories.TECH2}},

            { EBC, 'GreaterThanEconIncomeRNG',  { 2.8, 30}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.MASSEXTRACTION } },
            { MIBC, 'GreaterThanGameTimeRNG', { 1020 } },
        },
        FormRadius = 120,
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Mass Extractor Upgrade Single 120 excess',
        PlatoonTemplate = 'T2MassExtractorUpgrade',
        InstanceCount = 1,
        Priority = 300,
        BuilderConditions = {

            { EBC, 'GreaterThanEconStorageCurrentRNG', { 1500, 0 } },
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.MASSEXTRACTION * categories.TECH3 } },
        },
        FormRadius = 512,
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI ExtractorUpgrades Expansion',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNAIG T1 Mass Extractor Upgrade Expansion',
        PlatoonTemplate = 'T1MassExtractorUpgrade',
        InstanceCount = 1,
        Priority = 200,
        BuilderConditions = {

            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.9, 1.2 }},
            { MIBC, 'GreaterThanGameTimeRNG', { 800 } },
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.MASSEXTRACTION * categories.TECH1 } },
        },
        FormRadius = 10000,
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Mass Extractor Upgrade Single 120 excess Expansion',
        PlatoonTemplate = 'T1MassExtractorUpgrade',
        InstanceCount = 1,
        Priority = 200,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 120 } },

            { EBC, 'GreaterThanEconStorageCurrentRNG', { 1000, 0 } },
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 3, categories.MASSEXTRACTION * categories.TECH1 } },
        },
        FormRadius = 120,
        BuilderType = 'Any',
    },
}
]]