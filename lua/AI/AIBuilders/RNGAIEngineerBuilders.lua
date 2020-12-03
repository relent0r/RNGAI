--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Land Builders
]]

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
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
        BuilderName = 'RNGAI Factory Engineer T1 Mass',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 750,
        BuilderConditions = {
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 180, -500, 0, 0, 'AntiSurface', 1}},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 2, categories.LAND * categories.ENGINEER } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 12, categories.ENGINEER - categories.COMMAND } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 NoPath',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 750,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { UCBC, 'PoolLessAtLocation', {'LocationType', 2, categories.ENGINEER * categories.TECH1 - categories.COMMAND }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 2, categories.LAND * categories.ENGINEER } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Power',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 775,
        BuilderConditions = {
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 2, categories.LAND * categories.ENGINEER } },
            { EBC, 'LessThanEnergyTrendRNG', { 20.0 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 12, categories.ENGINEER - categories.COMMAND } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Large',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 600, -- low factory priority
        BuilderConditions = {
            { UCBC, 'PoolLessAtLocation', {'LocationType', 1, categories.ENGINEER * categories.TECH1 - categories.COMMAND }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 2, categories.LAND * categories.ENGINEER } },
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech1' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Expansion',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 750, -- low factory priority
        BuilderConditions = {
            { UCBC, 'StartLocationNeedsEngineer', { 'LocationType', 1000, -1000, 20, 2, 'AntiSurface' } },
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 2, 'ENGINEER TECH1' } },
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech1' } },
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
            { UCBC, 'HaveLessThanUnitsWithCategory', { 4, categories.ENGINEER * categories.TECH2 - categories.COMMAND } }, -- Build engies until we have 6 of them.
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, 'FACTORY TECH2'}},
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T2 Large',
        PlatoonTemplate = 'T2BuildEngineer',
        Priority = 400, -- low factory priority
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8} },
            { UCBC, 'PoolLessAtLocation', {'LocationType', 1, categories.ENGINEER * categories.TECH2 - categories.COMMAND }},
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech2' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T2 Excess',
        PlatoonTemplate = 'T2BuildEngineer',
        Priority = 300, -- low factory priority
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.80, 0.80}},
            { UCBC, 'PoolLessAtLocation', {'LocationType', 3, categories.ENGINEER * categories.TECH2 - categories.COMMAND }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech2' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T3 Small',
        PlatoonTemplate = 'T3BuildEngineer',
        Priority = 850, -- Top factory priority
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.ENGINEER * categories.TECH3 - categories.COMMAND } }, -- Build engies until we have 2 of them.
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, 'FACTORY TECH3'}},
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T3 Medium',
        PlatoonTemplate = 'T3BuildEngineer',
        Priority = 500, -- Top factory priority
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.20, 0.80 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 10, categories.ENGINEER * categories.TECH3 - categories.COMMAND } }, -- Build engies until we have 2 of them.
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, 'FACTORY TECH3'}},
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T3 Excess',
        PlatoonTemplate = 'T3BuildEngineer',
        Priority = 300, -- low factory priority
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, 'FACTORY TECH3'}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.80, 0.80}},
            { UCBC, 'PoolLessAtLocation', {'LocationType', 3, categories.ENGINEER * categories.TECH3 - categories.COMMAND }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 20, categories.ENGINEER * categories.TECH3 - categories.COMMAND } },
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech3' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
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
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech1' } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Expansion Mass',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 850,
        BuilderConditions = {
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 30, -500, 5, 0, 'AntiSurface', 1 }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.4, 0.6} },
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech1' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Maintain',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 400, -- low factory priority
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.4, 0.6} },
            { UCBC, 'PoolLessAtLocation', {'LocationType', 1, categories.ENGINEER - categories.COMMAND }},
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech1' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T2 Expansion',
        PlatoonTemplate = 'T2BuildEngineer',
        Priority = 450, -- low factory priority
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.9, 1.1} },
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, 'ENGINEER TECH2' } },
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech2' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T3 Small Expansion',
        PlatoonTemplate = 'T3BuildEngineer',
        Priority = 500, -- Top factory priority
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, 'FACTORY TECH3'}},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, 'ENGINEER TECH3' } },
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech3' } },
        },
        BuilderType = 'All',
    },
    
}

BuilderGroup {
    BuilderGroupName = 'RNGAI T1 Assist Builders',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Engineer Assist Engineer',
        PlatoonTemplate = 'T1EngineerAssistRNG',
        Priority = 500,
        InstanceCount = 12,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { UCBC, 'GreaterThanMassTrend', { 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.80 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssistLocation = 'LocationType',
                PermanentAssist = true,
                AssistRange = 100,
                AssisteeType = categories.ENGINEER,
                Time = 45,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Engineer Assist Factory T2 Upgrade',
        PlatoonTemplate = 'T12EngineerAssistRNG',
        Priority = 500,
        InstanceCount = 8,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 , categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1 }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { UCBC, 'GreaterThanMassTrend', { 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.80 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssistLocation = 'LocationType',
                AssistUntilFinished = true,
                PermanentAssist = true,
                AssisteeType = categories.FACTORY,
                AssistRange = 80,
                BeingBuiltCategories = {'STRUCTURE LAND FACTORY TECH2'},
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Engineer Assist Factory T3 Upgrade',
        PlatoonTemplate = 'T12EngineerAssistRNG',
        Priority = 550,
        InstanceCount = 8,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.FACTORY * categories.TECH3 * ( categories.LAND + categories.AIR ) , categories.STRUCTURE * categories.FACTORY * categories.TECH2 * ( categories.LAND + categories.AIR ) }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { UCBC, 'GreaterThanMassTrend', { 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.80 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssistLocation = 'LocationType',
                AssistUntilFinished = true,
                PermanentAssist = true,
                AssisteeType = categories.FACTORY,
                AssistRange = 80,
                BeingBuiltCategories = {'STRUCTURE LAND FACTORY TECH3', 'STRUCTURE AIR FACTORY TECH3' },
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Engineer Assist Artillery',
        PlatoonTemplate = 'T12EngineerAssistRNG',
        Priority = 500,
        InstanceCount = 8,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.ARTILLERY * categories.STRATEGIC}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { UCBC, 'GreaterThanMassTrend', { 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.80 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssistLocation = 'LocationType',
                AssistUntilFinished = true,
                PermanentAssist = true,
                AssisteeType = categories.STRUCTURE,
                AssistRange = 80,
                BeingBuiltCategories = {'STRUCTURE ARTILLERY STRATEGIC'},
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI Assist Factory Air AA T12',
        PlatoonTemplate = 'T12EngineerAssistRNG',
        Priority = 400,
        InstanceCount = 4,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.80}}, 
            { UCBC, 'GreaterThanMassTrend', { 0.0 } },
            { UCBC, 'LocationFactoriesBuildingGreater', { 'LocationType', 0, categories.MOBILE * categories.AIR * categories.ANTIAIR} },
        },
        BuilderData = {
            Assist = {
                AssistLocation = 'LocationType',
                AssisteeType = categories.FACTORY,
                AssistRange = 120,
                BeingBuiltCategories = {'AIR MOBILE ANTIAIR'},                   
                PermanentAssist = true,
                AssistClosestUnit = false,                                       
                AssistUntilFinished = true,
                Time = 60,
            },
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI T2 Assist Builders',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T2 Engineer Assist Factory',
        PlatoonTemplate = 'T12EconAssistRNG',
        Priority = 500,
        InstanceCount = 8,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.9, 1.2 }},
            { UCBC, 'GreaterThanMassTrend', { 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.80 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssistLocation = 'LocationType',
                AssistUntilFinished = true,
                AssisteeType = categories.FACTORY,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Engineer Unfinished Structures',
        PlatoonTemplate = 'T1EngineerAssistRNG',
        Priority = 700,
        InstanceCount = 3,
        BuilderConditions = {
                { UCBC, 'UnfinishedUnits', { 'LocationType', categories.STRUCTURE * categories.FACTORY}},
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.80}},
                { UCBC, 'GreaterThanMassTrend', { 0.0 } },
                { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 1.0 }},
            },
        BuilderData = {
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                BeingBuiltCategories = {'STRUCTURE FACTORY, STRUCTURE'},
                Time = 20,
            },
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Engineer Unfinished PGEN',
        PlatoonTemplate = 'T12EngineerAssistRNG',
        Priority = 560,
        InstanceCount = 5,
        BuilderConditions = {
                { UCBC, 'UnfinishedUnits', { 'LocationType', categories.STRUCTURE * categories.ENERGYPRODUCTION}},
                { UCBC, 'GreaterThanMassTrend', { 0.0 } },
                { EBC, 'LessThanEnergyTrendRNG', { 50.0 } },
            },
        BuilderData = {
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                AssistRange = 100,
                BeingBuiltCategories = {'STRUCTURE ENERGYPRODUCTION'},
                AssistClosestUnit = true,
            },
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T12 Engineer Unfinished Experimental',
        PlatoonTemplate = 'T12EngineerAssistRNG',
        Priority = 540,
        InstanceCount = 12,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.EXPERIMENTAL * categories.MOBILE }},
            { UCBC, 'GreaterThanMassTrend', { 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.80}},
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                AssistRange = 100,
                AssistClosestUnit = true,
                BeingBuiltCategories = {'EXPERIMENTAL MOBILE'},
                Time = 120,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI T12 Engineer Unfinished Strategic',
        PlatoonTemplate = 'T12EngineerAssistRNG',
        Priority = 500,
        InstanceCount = 8,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.STRATEGIC }},
            { UCBC, 'GreaterThanMassTrend', { 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.80}},
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                AssistRange = 100,
                AssistClosestUnit = true,
                BeingBuiltCategories = {'STRUCTURE STRATEGIC'},
                Time = 120,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI T12 Engineer Unfinished Novax',
        PlatoonTemplate = 'T12EngineerAssistRNG',
        Priority = 500,
        InstanceCount = 8,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.EXPERIMENTAL * categories.ORBITALSYSTEM }},
            { UCBC, 'GreaterThanMassTrend', { 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.80}},
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                AssistRange = 100,
                AssistClosestUnit = true,
                BeingBuiltCategories = {'EXPERIMENTAL ORBITALSYSTEM'},
                Time = 120,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI T12 Engineer Unfinished PGEN',
        PlatoonTemplate = 'T12EngineerAssistRNG',
        Priority = 550,
        InstanceCount = 8,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'GreaterThanMassTrend', { 0.0 } },
            { EBC, 'LessThanEnergyTrendRNG', { 300.0 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                BeingBuiltCategories = {'STRUCTURE ENERGYPRODUCTION'},
                Time = 60,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI T3 Engineer Unfinished PGEN',
        PlatoonTemplate = 'T3SACUEngineerAssistRNG',
        Priority = 550,
        InstanceCount = 8,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 }},
            { UCBC, 'GreaterThanMassTrend', { 0.0 } },
            { EBC, 'LessThanEnergyTrendRNG', { 500.0 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.ENGINEER,
                BeingBuiltCategories = {'STRUCTURE ENERGYPRODUCTION'},
                Time = 60,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI T3 Engineer Unfinished Experimental',
        PlatoonTemplate = 'T3SACUEngineerAssistRNG',
        Priority = 540,
        InstanceCount = 4,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.EXPERIMENTAL * categories.MOBILE }},
            { UCBC, 'GreaterThanMassTrend', { 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.80}},
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssistRange = 100,
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                BeingBuiltCategories = {'EXPERIMENTAL MOBILE'},
                Time = 120,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI T12 Engineer Upgrade Mex',
        PlatoonTemplate = 'T12EngineerAssistRNG',
        Priority = 200,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.MASSEXTRACTION }},
            { UCBC, 'GreaterThanMassTrend', { 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.80, 0.90}},
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                AssistRange = 100,
                AssistClosestUnit = true,
                BeingBuiltCategories = {'STRUCTURE MASSEXTRACTION'},
                Time = 60,
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
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 3, 'ENGINEERSTATION' }},
            { UCBC, 'EngineerGreaterAtLocation', { 'LocationType', 3, 'ENGINEER TECH2' } },
            { EBC, 'GreaterThanEconIncome',  { 1, 10}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.50, 0.85}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.95, 1.4 }},
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
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 3, 'ENGINEERSTATION' }},
            { UCBC, 'EngineerGreaterAtLocation', { 'LocationType', 3, 'ENGINEER TECH2' } },
            { EBC, 'GreaterThanEconIncome',  { 1, 10}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.50, 0.85}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.95, 1.4 }},
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
    Builder {
        BuilderName = 'RNGAI T1 Engineer Repair',
        PlatoonTemplate = 'EngineerRepairRNG',
        PlatoonAIPlan = 'RepairAI',
        Priority = 900,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'DamagedStructuresInAreaRNG', { 'LocationType', }},
            },
        BuilderData = {
            LocationType = 'LocationType',
        },
        BuilderType = 'Any',
    },
}
BuilderGroup {
    BuilderGroupName = 'RNGAI Energy Production Reclaim',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Engineer Reclaim T1 Pgens',
        PlatoonTemplate = 'EngineerBuilderRNG',
        PlatoonAIPlan = 'ReclaimStructuresAI',
        Priority = 800,
        InstanceCount = 1,
        BuilderConditions = {
                { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 1, (categories.TECH2 + categories.TECH3 ) * categories.ENERGYPRODUCTION}},
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH1 * categories.ENERGYPRODUCTION - categories.HYDROCARBON }},
                { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.1, 1.1 }},
            },
        BuilderData = {
            Location = 'LocationType',
            Reclaim = {categories.STRUCTURE * categories.TECH1 * categories.ENERGYPRODUCTION - categories.HYDROCARBON},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Engineer Reclaim T2 Pgens',
        PlatoonTemplate = 'EngineerBuilderRNG',
        PlatoonAIPlan = 'ReclaimStructuresAI',
        Priority = 600,
        InstanceCount = 1,
        BuilderConditions = {
                { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 3, categories.TECH3 * categories.ENERGYPRODUCTION}},
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH2 * categories.ENERGYPRODUCTION }},
                { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.1, 1.1 }},
            },
        BuilderData = {
            Location = 'LocationType',
            Reclaim = {categories.STRUCTURE * categories.TECH2 * categories.ENERGYPRODUCTION - categories.HYDROCARBON},
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Naval Assist',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Engineer Assist Factory Naval',
        PlatoonTemplate = 'T12EconAssistRNG',
        Priority = 500,
        InstanceCount = 8,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { UCBC, 'GreaterThanMassTrend', { 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.80 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssistLocation = 'LocationType',
                AssistUntilFinished = true,
                AssisteeType = categories.FACTORY,
            },
        }
    },

}
BuilderGroup {
    BuilderGroupName = 'RNGAI T1 Reclaim Builders',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Engineer Reclaim T1 Early', -- Try to get that early reclaim
        PlatoonTemplate = 'RNGAI T1EngineerReclaimer',
        PlatoonAIPlan = 'ReclaimAIRNG',
        Priority = 950,
        InstanceCount = 2,
        BuilderConditions = {
                { UCBC, 'LessThanGameTimeSeconds', { 420 } }, -- don't build after 7 minutes
                { MIBC, 'CheckIfReclaimEnabled', {}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 7, categories.MOBILE * categories.ENGINEER}},
                
            },
        BuilderData = {
            LocationType = 'LocationType',
            ReclaimTime = 80,
            MinimumReclaim = 8
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Engineer Reclaim T1 ',
        PlatoonTemplate = 'RNGAI T1EngineerReclaimer',
        PlatoonAIPlan = 'ReclaimAIRNG',
        Priority = 900,
        InstanceCount = 4,
        BuilderConditions = {
                { UCBC, 'GreaterThanGameTimeSeconds', { 420 } },
                { MIBC, 'CheckIfReclaimEnabled', {}},
                { UCBC, 'LessThanGameTimeSeconds', { 600 } },
                { EBC, 'LessThanEconStorageRatio', { 0.80, 2.0}},
            },
        BuilderData = {
            LocationType = 'LocationType',
            ReclaimTime = 80,
            MinimumReclaim = 8
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Engineer Reclaim T1 Excess',
        PlatoonTemplate = 'RNGAI T1EngineerReclaimer',
        PlatoonAIPlan = 'ReclaimAIRNG',
        Priority = 500,
        InstanceCount = 10,
        BuilderConditions = {
                { UCBC, 'GreaterThanGameTimeSeconds', { 600 } },
                { MIBC, 'CheckIfReclaimEnabled', {}},
                { UCBC, 'PoolGreaterAtLocation', {'LocationType', 2, categories.ENGINEER * categories.TECH1 }},
                { EBC, 'LessThanEconStorageRatio', { 0.80, 2.0}},
            },
        BuilderData = {
            LocationType = 'LocationType',
            ReclaimTime = 80,
            MinimumReclaim = 4
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Engineer Reclaim T2 Excess',
        PlatoonTemplate = 'RNGAI T2EngineerReclaimer',
        PlatoonAIPlan = 'ReclaimAIRNG',
        Priority = 100,
        InstanceCount = 1,
        BuilderConditions = {
                { MIBC, 'CheckIfReclaimEnabled', {}},
                { UCBC, 'PoolGreaterAtLocation', {'LocationType', 2, categories.ENGINEER * categories.TECH2 - categories.STATIONASSISTPOD }},
                { EBC, 'LessThanEconStorageRatio', { 0.80, 2.0}},
            },
        BuilderData = {
            LocationType = 'LocationType',
            ReclaimTime = 80,
            MinimumReclaim = 4
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Engineer Reclaim T3 Excess',
        PlatoonTemplate = 'RNGAI T3EngineerReclaimer',
        PlatoonAIPlan = 'ReclaimAIRNG',
        Priority = 100,
        InstanceCount = 1,
        BuilderConditions = {
                { MIBC, 'CheckIfReclaimEnabled', {}},
                { UCBC, 'PoolGreaterAtLocation', {'LocationType', 2, categories.ENGINEER * categories.TECH3 - categories.STATIONASSISTPOD - categories.COMMAND }},
                { EBC, 'LessThanEconStorageRatio', { 0.80, 2.0}},
            },
        BuilderData = {
            LocationType = 'LocationType',
            ReclaimTime = 80,
            MinimumReclaim = 4
        },
        BuilderType = 'Any',
    },
    
}

BuilderGroup {
    BuilderGroupName = 'RNGAI T1 Reclaim Builders Expansion',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Engineer Reclaim T1 Excess Expansion',
        PlatoonTemplate = 'RNGAI T1EngineerReclaimer',
        PlatoonAIPlan = 'ReclaimAIRNG',
        Priority = 850,
        InstanceCount = 2,
        BuilderConditions = {
                { UCBC, 'GreaterThanGameTimeSeconds', { 420 } },
                { MIBC, 'CheckIfReclaimEnabled', {}},
                { EBC, 'LessThanEconStorageRatio', { 0.80, 2.0}},
            },
        BuilderData = {
            LocationType = 'LocationType',
            ReclaimTime = 80,
            MinimumReclaim = 4
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Engineer Transfer To Active Expansion',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Eng Trans ActiveExpansion',
        PlatoonTemplate = 'T1EngineerTransferRNG',
        Priority = 500,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'GreaterThanGameTimeSeconds', { 600 } },
            { MIBC, 'ExpansionIsActive', {} },
            { UCBC, 'PoolGreaterAtLocation', {'MAIN', 2, categories.MOBILE * categories.ENGINEER * categories.TECH1 - categories.STATIONASSISTPOD - categories.COMMAND }},
            { UCBC, 'EngineerManagerUnitsAtActiveExpansionRNG', { '<', 2,  categories.MOBILE * categories.ENGINEER * categories.TECH1 - categories.STATIONASSISTPOD - categories.COMMAND } },
        },
        BuilderData = {
            MoveToLocationType = 'MAIN',
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Eng Trans ActiveExpansion',
        PlatoonTemplate = 'T2EngineerTransferRNG',
        Priority = 510,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'GreaterThanGameTimeSeconds', { 600 } },
            { MIBC, 'ExpansionIsActive', {} },
            { UCBC, 'PoolGreaterAtLocation', {'MAIN', 2, categories.MOBILE * categories.ENGINEER * categories.TECH2 - categories.STATIONASSISTPOD - categories.COMMAND }},
            { UCBC, 'EngineerManagerUnitsAtActiveExpansionRNG', { '<', 2,  categories.MOBILE * categories.ENGINEER * categories.TECH2 - categories.STATIONASSISTPOD - categories.COMMAND } },
        },
        BuilderData = {
            MoveToLocationType = 'MAIN',
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T3 Eng Trans ActiveExpansion',
        PlatoonTemplate = 'T3EngineerTransferRNG',
        Priority = 520,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'GreaterThanGameTimeSeconds', { 600 } },
            { MIBC, 'ExpansionIsActive', {} },
            { UCBC, 'PoolGreaterAtLocation', {'MAIN', 2, categories.MOBILE * categories.ENGINEER * categories.TECH3 - categories.STATIONASSISTPOD - categories.COMMAND }},
            { UCBC, 'EngineerManagerUnitsAtActiveExpansionRNG', { '<', 2,  categories.MOBILE * categories.ENGINEER * categories.TECH3 - categories.STATIONASSISTPOD - categories.COMMAND } },
        },
        BuilderData = {
            MoveToLocationType = 'MAIN',
        },
        BuilderType = 'Any',
    },
}