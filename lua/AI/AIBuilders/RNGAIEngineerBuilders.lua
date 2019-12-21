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
local MABC = '/lua/editor/MarkerBuildConditions.lua'



BuilderGroup {
    BuilderGroupName = 'RNGAI Engineer Builder',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory Engineer Initial',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 1000, -- Top factory priority
        BuilderConditions = {
            { UCBC, 'LessThanGameTimeSeconds', { 180 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 4, categories.ENGINEER - categories.COMMAND } }, -- Build engies until we have 3 of them.
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Small',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 850,
        BuilderConditions = {
            { UCBC, 'LessThanGameTimeSeconds', { 600 } },
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, categories.LAND * categories.ENGINEER } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 8, categories.ENGINEER - categories.COMMAND } }, -- Build engies until we have 6 of them.
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Mass',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 750,
        BuilderConditions = {
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 180, -500, 0, 0, 'AntiSurface', 1}},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, categories.LAND * categories.ENGINEER } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 12, categories.ENGINEER - categories.COMMAND } }, -- Build engies until we have 6 of them.
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Large',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 600, -- low factory priority
        BuilderConditions = {
            { UCBC, 'PoolLessAtLocation', {'LocationType', 1, categories.ENGINEER * categories.TECH1 - categories.COMMAND }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, categories.LAND * categories.ENGINEER } },
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech1' } },
            { IBC, 'BrainNotLowMassMode', {} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Expansion',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 750, -- low factory priority
        BuilderConditions = {
            { UCBC, 'StartLocationNeedsEngineer', { 'LocationType', 1000, -1000, 0, 2, 'StructuresNotMex' } },
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
        Priority = 800, -- Top factory priority
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
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.ENGINEER * categories.TECH2 - categories.COMMAND } }, -- Build engies until we have 6 of them.
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, 'FACTORY TECH2'}},
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T2 Large',
        PlatoonTemplate = 'T2BuildEngineer',
        Priority = 400, -- low factory priority
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 0.8} },
            { UCBC, 'PoolLessAtLocation', {'LocationType', 1, categories.ENGINEER * categories.TECH2 - categories.COMMAND }},
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech2' } },
            { IBC, 'BrainNotLowMassMode', {} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T3 Small',
        PlatoonTemplate = 'T3BuildEngineer',
        Priority = 850, -- Top factory priority
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.ENGINEER * categories.TECH3 - categories.COMMAND } }, -- Build engies until we have 2 of them.
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, 'FACTORY TECH3'}},
        },
        BuilderType = 'All',
    },
    
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Engineer Builder Expansion',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Expansion Count',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 920,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 2, categories.ENGINEER - categories.COMMAND } }, -- Build engies until we have 2 of them.
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Expansion Mass',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 850,
        BuilderConditions = {
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 30, -500, 5, 0, 'AntiSurface', 1 }},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.4, 0.6} },
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 3, categories.ENGINEER - categories.COMMAND } },
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech1' } },
            { IBC, 'BrainNotLowMassMode', {} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Expansion',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 400, -- low factory priority
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.4, 0.6} },
            { UCBC, 'PoolLessAtLocation', {'LocationType', 1, categories.ENGINEER - categories.COMMAND }},
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech1' } },
            { IBC, 'BrainNotLowMassMode', {} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T2 Expansion',
        PlatoonTemplate = 'T2BuildEngineer',
        Priority = 300, -- low factory priority
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
    BuilderGroupName = 'RNGAI T1 Assist Builders',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Engineer Assist Engineer',
        PlatoonTemplate = 'EngineerAssist',
        Priority = 500,
        InstanceCount = 12,
        BuilderConditions = {
            { IBC, 'BrainNotLowPowerMode', {} },
            { UCBC, 'LocationEngineersBuildingAssistanceGreater', { 'LocationType', 0, 'ALLUNITS' } },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.8, 1.0 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssistLocation = 'LocationType',
                PermanentAssist = true,
                AssisteeType = 'Engineer',
                Time = 45,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Engineer Assist T2 PGEN',
        PlatoonTemplate = 'EngineerAssist',
        Priority = 800,
        InstanceCount = 3,
        BuilderConditions = {
            { IBC, 'BrainNotLowPowerMode', {} },
            { UCBC, 'LocationEngineersBuildingAssistanceGreater', { 'LocationType', 0, 'ENERGYPRODUCTION TECH2' } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH2' }},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.5 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssistLocation = 'LocationType',
                PermanentAssist = false,
                AssisteeType = 'Engineer',
                BeingBuiltCategories = {'ENERGYPRODUCTION TECH2'},
                Time = 60,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Engineer Assist Factory',
        PlatoonTemplate = 'EngineerAssist',
        Priority = 500,
        InstanceCount = 8,
        BuilderConditions = {
            { IBC, 'BrainNotLowPowerMode', {} },
            { UCBC, 'LocationEngineersBuildingAssistanceGreater', { 'LocationType', 0, 'ALLUNITS' } },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.8, 1.0 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssistLocation = 'LocationType',
                PermanentAssist = true,
                AssisteeType = 'Factory',
                Time = 45,
            },
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI T2 Assist Builders',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T2 Engineer Assist Engineer',
        PlatoonTemplate = 'T2EngineerAssist',
        Priority = 500,
        InstanceCount = 12,
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
                Time = 45,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Engineer Assist Factory',
        PlatoonTemplate = 'T2EngineerAssist',
        Priority = 500,
        InstanceCount = 8,
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
                AssisteeType = 'Factory',
                Time = 45,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Engineer Unfinished Structures',
        PlatoonTemplate = 'EngineerBuilder',
        PlatoonAIPlan = 'ManagerEngineerFindUnfinished',
        Priority = 980,
        InstanceCount = 2,
        BuilderConditions = {
                { UCBC, 'UnfinishedUnits', { 'LocationType', categories.STRUCTURE}},
            },
        BuilderData = {
            Assist = {
                AssistLocation = 'LocationType',
                AssisteeType = 'Engineer',
                BeingBuiltCategories = {'STRUCTURE STRATEGIC, STRUCTURE ECONOMIC, STRUCTURE'},
                Time = 20,
            },
        },
        BuilderType = 'Any',
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
            { EBC, 'GreaterThanEconIncome',  { 1, 10}},
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.95, 1.4 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                AdjacencyCategory = 'FACTORY',
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
            { EBC, 'GreaterThanEconIncome',  { 1, 10}},
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.95, 1.4 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                AdjacencyCategory = 'FACTORY',
                BuildClose = true,
                FactionIndex = 3,
                BuildStructures = {
                    'T2EngineerSupport',
                },
            }
        }
    },
}
BuilderGroup {
    BuilderGroupName = 'RNGAI Energy Production Reclaim',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Engineer Reclaim T1 Pgens',
        PlatoonTemplate = 'EngineerBuilder',
        PlatoonAIPlan = 'ReclaimStructuresAI',
        Priority = 850,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'GreaterThanEnergyTrend', { 0.0 } },
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 1, categories.TECH2 * categories.ENERGYPRODUCTION}},
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH1 * categories.ENERGYPRODUCTION }},
                { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.1, 1.1 }},
            },
        BuilderData = {
            Location = 'LocationType',
            Reclaim = {categories.STRUCTURE * categories.TECH1 * categories.ENERGYPRODUCTION - categories.HYDROCARBON},
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI T1 Reclaim Builders',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Engineer Reclaim T1 Early', -- Try to get that early reclaim
        PlatoonTemplate = 'RNGAI T1EngineerReclaimer',
        PlatoonAIPlan = 'ReclaimAIRNG',
        Priority = 850,
        InstanceCount = 2,
        BuilderConditions = {
                { UCBC, 'LessThanGameTimeSeconds', { 420 } }, -- don't build after 7 minutes
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 6, categories.MOBILE * categories.ENGINEER}},
                { MIBC, 'ReclaimablesInArea', { 'LocationType', }},
                
            },
        BuilderData = {
            LocationType = 'LocationType',
            ReclaimTime = 60
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Engineer Reclaim T1 ',
        PlatoonTemplate = 'RNGAI T1EngineerReclaimer',
        PlatoonAIPlan = 'ReclaimAIRNG',
        Priority = 700,
        InstanceCount = 6,
        BuilderConditions = {
                { UCBC, 'GreaterThanGameTimeSeconds', { 420 } },
                { MIBC, 'ReclaimablesInArea', { 'LocationType', }},
                { EBC, 'LessThanEconStorageRatio', { 0.50, 0.0}},
            },
        BuilderData = {
            LocationType = 'LocationType',
            ReclaimTime = 60
        },
        BuilderType = 'Any',
    },
    
}