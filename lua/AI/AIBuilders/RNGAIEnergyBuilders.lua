--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAIEconomicBuilders.lua
    Author  :   relentless
    Summary :
        Economic Builders
]]

local EBC = '/lua/editor/EconomyBuildConditions.lua'
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI Energy Builder',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1Engineer Pgen Trend',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 950,
        InstanceCount = 2,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTime', { 90 } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { UCBC, 'LessThanEnergyTrend', { 0.0 } }, -- If our energy is trending into negatives
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH2' }}, -- Don't build after 1 T2 Pgens Exist
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH3' }}, -- Don't build after 1 T3 Pgen Exist
        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
            AdjacencyDistance = 50,
            NeedGuard = false,
            BuildClose = true,
            DesiresAssist = true,
            Construction = {
                BuildStructures = {
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1Engineer Pgen Scale',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 900,
        InstanceCount = 2,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTime', { 360 } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { UCBC, 'LessThanEnergyTrend', { 80.0 } },
            { EBC, 'GreaterThanEconStorageRatio', { 0.02, 0.0}},
            { UCBC, 'GreaterThanMassTrend', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH2' }}, -- Don't build after 1 T2 Pgens Exist
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH3' }}, -- Don't build after 1 T3 Pgen Exist
        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
            AdjacencyDistance = 50,
            NeedGuard = false,
            DesiresAssist = true,
            Construction = {
                BuildStructures = {
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Power Engineer 1st',
        PlatoonTemplate = 'T2EngineerBuilder',
        Priority = 1000,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH2' }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH3' }},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.5, 0.1 }},
            { EBC, 'LessThanEconEfficiencyOverTime', { 2.0, 1.7 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
            DesiresAssist = true,
            Construction = {
                NumAssistees = 3,
                BuildStructures = {
                    'T2EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Power Engineer Negative Trend',
        PlatoonTemplate = 'T2EngineerBuilder',
        Priority = 900,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { UCBC, 'LessThanEnergyTrend', { 0.0 } },
            { UCBC, 'EngineerLessAtLocation', { 'LocationType', 3, 'TECH3 ENGINEER' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 1, 'ENERGYPRODUCTION TECH2, ENERGYPRODUCTION TECH3' }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, 'ENERGYPRODUCTION TECH3' }},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.8, 0.1 }},
            { EBC, 'LessThanEconEfficiencyOverTime', { 2.0, 1.7 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
            DesiresAssist = true,
            Construction = {
                BuildStructures = {
                    'T2EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Power Engineer Scale',
        PlatoonTemplate = 'T2EngineerBuilder',
        Priority = 700,
        InstanceCount = 2,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { UCBC, 'LessThanEnergyTrend', { 100.0 } },
            { UCBC, 'GreaterThanMassTrend', { 0.0 } },
            { EBC, 'GreaterThanEconStorageRatio', { 0.03, 0.0}},
            { UCBC, 'EngineerLessAtLocation', { 'LocationType', 3, 'TECH3 ENGINEER' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 2, 'ENERGYPRODUCTION TECH2, ENERGYPRODUCTION TECH3' }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, 'ENERGYPRODUCTION TECH3' }},
        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
            DesiresAssist = true,
            Construction = {
                BuildStructures = {
                    'T2EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Power Engineer Scale Extra',
        PlatoonTemplate = 'T2EngineerBuilder',
        Priority = 700,
        InstanceCount = 2,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { UCBC, 'LessThanEnergyTrend', { 300.0 } },
            { UCBC, 'GreaterThanMassTrend', { 0.0 } },
            { EBC, 'GreaterThanEconStorageRatio', { 0.03, 0.0}},
            { UCBC, 'EngineerLessAtLocation', { 'LocationType', 3, 'TECH3 ENGINEER' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 2, 'ENERGYPRODUCTION TECH2, ENERGYPRODUCTION TECH3' }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, 'ENERGYPRODUCTION TECH3' }},
        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
            DesiresAssist = true,
            Construction = {
                BuildStructures = {
                    'T2EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T3 Power Engineer 1st',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 900,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH3' }},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.5, 0.1 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
            DesiresAssist = true,
            Construction = {
                NumAssistees = 5,
                BuildStructures = {
                    'T3EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T3 Power Engineer Scale',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 700,
        InstanceCount = 2,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { UCBC, 'LessThanEnergyTrend', { 100.0 } },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.5 }},
            { EBC, 'GreaterThanEconStorageRatio', { 0.02, 0.0}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, 'ENERGYPRODUCTION TECH3' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 2, 'ENERGYPRODUCTION TECH3' }},
        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
            DesiresAssist = true,
            Construction = {
                BuildStructures = {
                    'T3EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T3 Power Engineer Scale Extra',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 500,
        InstanceCount = 2,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { UCBC, 'LessThanEnergyTrend', { 500.0 } },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.5 }},
            { EBC, 'GreaterThanEconStorageRatio', { 0.02, 0.0}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, 'ENERGYPRODUCTION TECH3' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 2, 'ENERGYPRODUCTION TECH3' }},
        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
            DesiresAssist = true,
            Construction = {
                BuildStructures = {
                    'T3EnergyProduction',
                },
            }
        }
    },
}
BuilderGroup {
    BuilderGroupName = 'RNGAI Energy Builder Expansion',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1Engineer Pgen Scale Expansion',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 900,
        InstanceCount = 2,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTime', { 360 } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { UCBC, 'LessThanEnergyTrend', { 30.0 } },
            { EBC, 'GreaterThanEconStorageRatio', { 0.02, 0.0}},
            { UCBC, 'GreaterThanMassTrend', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH2' }}, -- Don't build after 1 T2 Pgens Exist
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH3' }}, -- Don't build after 1 T3 Pgen Exist
        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
            AdjacencyDistance = 50,
            NeedGuard = false,
            DesiresAssist = true,
            Construction = {
                BuildStructures = {
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Power Engineer Expansion',
        PlatoonTemplate = 'T2EngineerBuilder',
        Priority = 800,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH3' }},
            { UCBC, 'EngineerLessAtLocation', { 'LocationType', 3, 'TECH3 ENGINEER' }},
            { UCBC, 'LessThanEnergyTrend', { 0.0 } },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.TECH2 * categories.ENERGYPRODUCTION }},
        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
            Construction = {
                BuildStructures = {
                    'T2EnergyProduction',
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Hydro Builder',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1Engineer Hydro 30',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 920,
        InstanceCount = 1,
        BuilderConditions = { 
            { UCBC, 'CanBuildOnHydroLessThanDistance', { 'LocationType', 50, -1000, 100, 1, 'AntiSurface', 1 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = true,
            Construction = {
                BuildStructures = {
                    'T1HydroCarbon',
                },
            }
        }

    },
    Builder {
        BuilderName = 'RNGAI T1Engineer Hydro 250',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 600,
        InstanceCount = 1,
        BuilderConditions = { 
            { UCBC, 'CanBuildOnHydroLessThanDistance', { 'LocationType', 256, -1000, 100, 1, 'AntiSurface', 1 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                BuildStructures = {
                    'T1HydroCarbon',
                },
            }
        }

    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Energy Storage Builder',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'T1 Energy Storage Builder OverCharge',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 800,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTime', { 300 } },
            { EBC, 'GreaterThanEconStorageRatio', { 10.0, 0.80}},
            { UCBC, 'UnitCapCheckLess', { .7 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYSTORAGE' }},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 1.0, 1.1 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BuildStructures = {
                    'EnergyStorage',
                },
            }
        }
    },
    Builder {
        BuilderName = 'T1 Energy Storage Builder',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 500,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTime', { 600 } },
            { UCBC, 'UnitCapCheckLess', { .7 } },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 1.0, 1.1 }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 5, 'ENERGYSTORAGE' }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'EnergyStorage',
                },
            }
        }
    },
}
