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
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconIncome',  { 1.4, 6}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 1.0 }},
            { MIBC, 'GreaterThanGameTime', { 1200 } },
            { UCBC, 'HaveLessThanMassExtractorsBeingUpgraded', { 2, 'MASSEXTRACTION TECH2', 'MASSEXTRACTION' } },
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
            { MIBC, 'GreaterThanGameTime', { 240 } },
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconIncome',  { 1.0, 6}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.6 }},
            { UCBC, 'HaveLessThanMassExtractorsBeingUpgraded', { 1, 'MASSEXTRACTION TECH2', 'MASSEXTRACTION' } },
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
            { MIBC, 'GreaterThanGameTime', { 480 } },
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconIncome',  { 1.2, 6}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.6 }},
            { UCBC, 'HaveLessThanMassExtractorsBeingUpgraded', { 1, 'MASSEXTRACTION TECH2', 'MASSEXTRACTION' } },
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
            { MIBC, 'GreaterThanGameTime', { 660 } },
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 1.0 }},
            { UCBC, 'HaveLessThanMassExtractorsBeingUpgraded', { 1, 'MASSEXTRACTION TECH2', 'MASSEXTRACTION' } },
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
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconIncome',  { 5.4, 60}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 1.0 }},
            { MIBC, 'GreaterThanGameTime', { 1500 } },
            { UCBC, 'HaveLessThanMassExtractorsBeingUpgraded', { 1, 'MASSEXTRACTION TECH3', 'MASSEXTRACTION' } },
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
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconIncome',  { 2.8, 30}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.8, 1.0 }},
            { UCBC, 'HaveLessThanMassExtractorsBeingUpgraded', { 1, 'MASSEXTRACTION TECH3', 'MASSEXTRACTION' } },
            { MIBC, 'GreaterThanGameTime', { 840 } },
        },
        FormRadius = 120,
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
        Priority = 400,
        BuilderConditions = {
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconIncome',  { 1.0, 6}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.9, 1.2 }},
            { MIBC, 'GreaterThanGameTime', { 960 } },
            { UCBC, 'HaveLessThanMassExtractorsBeingUpgraded', { 1, 'MASSEXTRACTION TECH2', 'MASSEXTRACTION' } },
        },
        FormRadius = 10000,
        BuilderType = 'Any',
    },
}