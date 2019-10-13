--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Land Builders
]]

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local IBC = '/lua/editor/InstantBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI Engineer Builder',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory Engineer Initial',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 1000, -- Top factory priority
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.ENGINEER - categories.COMMAND } }, -- Build engies until we have 3 of them.
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Small',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 850,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 6, categories.ENGINEER - categories.COMMAND } }, -- Build engies until we have 6 of them.
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Medium',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 700,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 8, categories.ENGINEER - categories.COMMAND } }, -- Build engies until we have 8 of them.
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Large',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 400, -- low factory priority
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.9, 1.1} },
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, 'ENGINEER TECH1' } },
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech1' } },
            { IBC, 'BrainNotLowMassMode', {} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T2 Small',
        PlatoonTemplate = 'T2BuildEngineer',
        Priority = 750, -- Top factory priority
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.ENGINEER * categories.TECH2 - categories.COMMAND } }, -- Build engies until we have 2 of them.
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, 'FACTORY TECH2'}},
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T2 Medium',
        PlatoonTemplate = 'T2BuildEngineer',
        Priority = 500, -- Top factory priority
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 6, categories.ENGINEER * categories.TECH2 - categories.COMMAND } }, -- Build engies until we have 6 of them.
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, 'FACTORY TECH2'}},
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T2 Large',
        PlatoonTemplate = 'T2BuildEngineer',
        Priority = 400, -- low factory priority
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.9, 1.1} },
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, 'ENGINEER TECH2' } },
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech1' } },
            { IBC, 'BrainNotLowMassMode', {} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'All',
    },
    
}
BuilderGroup {
    BuilderGroupName = 'RNGAI T1 Reclaim Assist Builders',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Engineer Reclaim T1',
        PlatoonTemplate = 'T1EngineerReclaimer',
        PlatoonAIPlan = 'ReclaimAI',
        Priority = 500,
        InstanceCount = 3,
        BuilderConditions = {
                { MIBC, 'ReclaimablesInArea', { 'LocationType', }},
            },
        BuilderData = {
            LocationType = 'LocationType',
        },
        BuilderType = 'Any',
    },
    Builder {
            BuilderName = 'RNGAI T1 Engineer Assist Engineer',
            PlatoonTemplate = 'EngineerAssist',
            Priority = 600,
            InstanceCount = 20,
            BuilderConditions = {
                { IBC, 'BrainNotLowPowerMode', {} },
                { UCBC, 'LocationEngineersBuildingAssistanceGreater', { 'LocationType', 0, 'ALLUNITS' } },
                { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.9, 1.2 }},
            },
            BuilderType = 'Any',
            BuilderData = {
                Assist = {
                    AssistLocation = 'LocationType',
                    PermanentAssist = true,
                    AssisteeType = 'Engineer',
                    Time = 30,
                },
            }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI T2 Reclaim Assist Builders',
    BuildersType = 'EngineerBuilder',
    Builder {
            BuilderName = 'RNGAI T2 Engineer Assist Engineer',
            PlatoonTemplate = 'T2EngineerAssist',
            Priority = 600,
            InstanceCount = 20,
            BuilderConditions = {
                { IBC, 'BrainNotLowPowerMode', {} },
                { UCBC, 'LocationEngineersBuildingAssistanceGreater', { 'LocationType', 0, 'ALLUNITS' } },
                { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.9, 1.2 }},
            },
            BuilderType = 'Any',
            BuilderData = {
                Assist = {
                    AssistLocation = 'LocationType',
                    PermanentAssist = true,
                    AssisteeType = 'Engineer',
                    Time = 30,
                },
            }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Engineering Support Builder',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T2 Engineering Support UEF',
        PlatoonTemplate = 'UEFT2EngineerBuilder',
        Priority = 500,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 2, 'ENGINEERSTATION' }},
            { UCBC, 'EngineerGreaterAtLocation', { 'LocationType', 3, 'ENGINEER TECH2' } },
            { EBC, 'GreaterThanEconIncome',  { 10, 100}},
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.95, 1.4 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                AdjacencyCategory = 'ENERGYPRODUCTION',
                BuildClose = true,
                FactionIndex = 1,
                BuildStructures = {
                    'T2EngineerSupport',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Engineering Support Cybran',
        PlatoonTemplate = 'CybranT2EngineerBuilder',
        Priority = 500,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 2, 'ENGINEERSTATION' }},
            { UCBC, 'EngineerGreaterAtLocation', { 'LocationType', 3, 'ENGINEER TECH2' } },
            { EBC, 'GreaterThanEconIncome',  { 10, 100}},
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.95, 1.4 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                AdjacencyCategory = 'ENERGYPRODUCTION',
                BuildClose = true,
                FactionIndex = 3,
                BuildStructures = {
                    'T2EngineerSupport',
                },
            }
        }
    },
}