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
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 1000,
        InstanceCount = 3,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 90 } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { EBC, 'LessThanEnergyTrendRNG', { 0.0 } }, -- If our energy is trending into negatives
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
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 900,
        InstanceCount = 2,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { EBC, 'LessThanEnergyTrendRNG', { 80.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.0}},
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
        BuilderName = 'RNGAI T1 Power MassRatio',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 700,
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'EnergyToMassRatioIncome', { 10.0, '<=' } },  -- True if we have less than 10 times more Energy then Mass income ( 100 <= 10 = true )
            { UCBC, 'GreaterThanMassTrend', { 0.0 } },
            { EBC, 'GreaterThanEconIncome',  { 0.6, 0.0}}, -- Absolut Base income
            { UCBC, 'HaveUnitRatioVersusCap', { 0.12 , '<', categories.STRUCTURE - categories.MASSEXTRACTION - categories.DEFENSE - categories.FACTORY } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH2' }}, -- Don't build after 1 T2 Pgens Exist
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH3' }}, -- Don't build after 1 T3 Pgen Exist
        },
        InstanceCount = 1,
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                AdjacencyCategory = categories.STRUCTURE * categories.FACTORY * (categories.LAND + categories.AIR),
                AdjacencyDistance = 50,
                BuildClose = true,
                LocationType = 'LocationType',
                BuildStructures = {
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Power Engineer 1st',
        PlatoonTemplate = 'EngineerBuilderT23RNG',
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
            AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
            AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH2,
            maxUnits = 1,
            maxRadius = 10,
            DesiresAssist = true,
            NumAssistees = 10,
            Construction = {
                BuildStructures = {
                    'T2EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Power Engineer Negative Trend',
        PlatoonTemplate = 'EngineerBuilderT23RNG',
        Priority = 900,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { EBC, 'LessThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'EngineerLessAtLocation', { 'LocationType', 3, 'TECH3 ENGINEER' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, 'ENERGYPRODUCTION TECH2, ENERGYPRODUCTION TECH3' }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, 'ENERGYPRODUCTION TECH3' }},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.5 }},
            { EBC, 'LessThanEconEfficiencyOverTime', { 2.0, 1.7 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
            AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH2,
            maxUnits = 1,
            maxRadius = 10,
            DesiresAssist = true,
            NumAssistees = 10,
            Construction = {
                BuildStructures = {
                    'T2EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Power Engineer Scale',
        PlatoonTemplate = 'EngineerBuilderT23RNG',
        Priority = 700,
        InstanceCount = 2,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { EBC, 'LessThanEnergyTrendRNG', { 100.0 } },
            { UCBC, 'GreaterThanMassTrend', { 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.08, 0.20}},
            { UCBC, 'EngineerLessAtLocation', { 'LocationType', 3, 'TECH3 ENGINEER' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.ENERGYPRODUCTION * categories.TECH2, 1, categories.ENERGYPRODUCTION * categories.TECH3 }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, 'ENERGYPRODUCTION TECH3' }},
        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
            AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH2,
            maxUnits = 1,
            maxRadius = 4,
            DesiresAssist = true,
            NumAssistees = 10,
            Construction = {
                BuildStructures = {
                    'T2EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Power Engineer Scale Extra',
        PlatoonTemplate = 'EngineerBuilderT23RNG',
        Priority = 500,
        InstanceCount = 2,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { EBC, 'LessThanEnergyTrendRNG', { 500.0 } },
            { UCBC, 'GreaterThanMassTrend', { 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.12, 0.20}},
            { UCBC, 'EngineerLessAtLocation', { 'LocationType', 3, 'TECH3 ENGINEER' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.ENERGYPRODUCTION * categories.TECH2, 1, categories.ENERGYPRODUCTION * categories.TECH3 }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, 'ENERGYPRODUCTION TECH3' }},
        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
            AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH2,
            maxUnits = 1,
            maxRadius = 10,
            DesiresAssist = true,
            NumAssistees = 3,
            Construction = {
                BuildStructures = {
                    'T2EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T3 Power Engineer 1st',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 900,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH3' }},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.1 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
            AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH3,
            maxUnits = 1,
            maxRadius = 15,
            DesiresAssist = true,
            NumAssistees = 10,
            Construction = {
                BuildStructures = {
                    'T3EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T3 Power Engineer 2nd',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 850,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, 'ENERGYPRODUCTION TECH3' }},
            { UCBC, 'GreaterThanMassTrend', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, 'ENERGYPRODUCTION TECH3' }},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.1 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
            AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH3,
            maxUnits = 1,
            maxRadius = 15,
            DesiresAssist = true,
            NumAssistees = 10,
            Construction = {
                BuildStructures = {
                    'T3EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T3 Power Engineer Negative Trend',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 900,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { UCBC, 'LessThanEnergyTrend', { 0.0 } },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.1 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
            AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH3,
            maxUnits = 1,
            maxRadius = 15,
            DesiresAssist = true,
            NumAssistees = 10,
            Construction = {
                BuildStructures = {
                    'T3EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T3 Power Engineer Scale',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 700,
        InstanceCount = 2,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { EBC, 'LessThanEnergyTrendRNG', { 100.0 } },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.5 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.0}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, 'ENERGYPRODUCTION TECH3' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, 'ENERGYPRODUCTION TECH3' }},
        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
            AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH3,
            maxUnits = 1,
            maxRadius = 15,
            DesiresAssist = true,
            NumAssistees = 15,
            Construction = {
                BuildStructures = {
                    'T3EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T3 Power Engineer Scale Extra',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 500,
        InstanceCount = 2,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { EBC, 'LessThanEnergyTrendRNG', { 800.0 } },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.5 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.0}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, 'ENERGYPRODUCTION TECH3' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, 'ENERGYPRODUCTION TECH3' }},
        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
            AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH3,
            maxUnits = 1,
            maxRadius = 15,
            DesiresAssist = true,
            NumAssistees = 15,
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
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 900,
        InstanceCount = 2,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 360 } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { EBC, 'LessThanEnergyTrendRNG', { 0.0 } },
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
        PlatoonTemplate = 'T2EngineerBuilderRNG',
        Priority = 800,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { UCBC, 'GreaterThanMassTrend', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH3' }},
            { UCBC, 'EngineerLessAtLocation', { 'LocationType', 3, 'TECH3 ENGINEER' }},
            { EBC, 'LessThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.TECH2 * categories.ENERGYPRODUCTION }},
        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
            AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH2,
            maxUnits = 1,
            maxRadius = 10,
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
        PlatoonTemplate = 'EngineerBuilderT123RNG',
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
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 800,
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
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 800,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.01, 0.80}},
            { UCBC, 'UnitCapCheckLess', { .7 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYSTORAGE' }},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 0.8 }},
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
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 500,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 600 } },
            { UCBC, 'UnitCapCheckLess', { .7 } },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 1.0, 1.1 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.80}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 8, 'ENERGYSTORAGE' }},
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
