--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAIEconomicBuilders.lua
    Author  :   relentless
    Summary :
        Economic Builders
]]

local EBC = '/lua/editor/EconomyBuildConditions.lua'
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

BuilderGroup {
    BuilderGroupName = 'RNGAI Energy Builder',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1Engineer Pgen Trend OverTime',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 1000,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 90 } },
            { EBC, 'LessThanEnergyTrendOverTimeRNG', { 21.0 } }, -- If our energy is trending into negatives
            { EBC, 'GreaterThanMassStorageOrEfficiency', { 100, 0.8 }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }}, -- Don't build after 1 T2 Pgens Exist
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = true,
            Construction = {
                BuildClose = true,
                AdjacencyPriority = {
                    categories.FACTORY * categories.AIR,
                    categories.RADAR * categories.STRUCTURE,
                    categories.MASSEXTRACTION * categories.TECH1,
                    categories.FACTORY * categories.LAND,
                    categories.ENERGYSTORAGE,   
                    categories.INDIRECTFIRE * categories.DEFENSE,
                    categories.SHIELD * categories.STRUCTURE,
                    categories.ENERGYPRODUCTION * categories.STRUCTURE,
                },
                AvoidCategory = categories.ENERGYPRODUCTION,
                AdjacencyDistance = 50,
                maxUnits = 1,
                maxRadius = 2.5,
                BuildStructures = {
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1Engineer Pgen Trend Instant',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 1000,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 90 } },
            { EBC, 'LessThanEnergyTrendRNG', { 10.0 } }, -- If our energy is trending into negatives
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }}, -- Don't build after 1 T2 Pgens Exist
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = true,
            Construction = {
                BuildClose = true,
                AdjacencyPriority = {
                    categories.FACTORY * categories.AIR,
                    categories.RADAR * categories.STRUCTURE,
                    categories.MASSEXTRACTION * categories.TECH1,
                    categories.FACTORY * categories.LAND,
                    categories.ENERGYSTORAGE,   
                    categories.INDIRECTFIRE * categories.DEFENSE,
                    categories.SHIELD * categories.STRUCTURE,
                    categories.ENERGYPRODUCTION * categories.STRUCTURE,
                },
                AvoidCategory = categories.ENERGYPRODUCTION,
                AdjacencyDistance = 50,
                maxUnits = 1,
                maxRadius = 2.5,
                BuildStructures = {
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1Engineer Pgen Scale',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 1050,
        InstanceCount = 2,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 180 } },
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Energy' }},
            { EBC, 'LessThanEnergyEfficiencyOverTimeRNG', { 1.4 } },
            { EBC, 'GreaterThanMassStorageOrEfficiency', { 200, 1.0 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }}, -- Don't build after 1 T3 Pgen Exist
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = true,
            Construction = {
                AdjacencyPriority = {
                    categories.FACTORY * categories.AIR,
                    categories.RADAR * categories.STRUCTURE,
                    categories.MASSEXTRACTION * categories.TECH1,
                    categories.FACTORY * categories.LAND,
                    categories.ENERGYSTORAGE,   
                    categories.INDIRECTFIRE * categories.DEFENSE,
                    categories.SHIELD * categories.STRUCTURE,
                    categories.ENERGYPRODUCTION * categories.STRUCTURE,
                },
                AvoidCategory = categories.ENERGYPRODUCTION,
                AdjacencyDistance = 50,
                maxUnits = 1,
                maxRadius = 2.5,
                BuildStructures = {
                    'T1EnergyProduction',
                    'T1EnergyProduction'
                },
            }
        }
    },
    --[[Builder {
        BuilderName = 'RNGAI T2 Power Engineer 1st',
        PlatoonTemplate = 'EngineerBuilderT23RNG',
        Priority = 1000,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Energy' }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.9, 0.1 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 12,
            Construction = {
                AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
                AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH2,
                maxUnits = 1,
                maxRadius = 10,
                BuildStructures = {
                    'T2EnergyProduction',
                },
            }
        }
    },]]
    Builder {
        BuilderName = 'RNGAI T2 Power Engineer Negative Trend',
        PlatoonTemplate = 'T2EngineerBuilderRNG',
        Priority = 1005,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'EnergyT2', 6},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'EnergyT2' }},
            { EBC, 'LessThanEnergyTrendCombinedRNG', { 5.0 } },
            { UCBC, 'IsEngineerNotBuilding', { categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION *  categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.1 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 12,
            Construction = {
                --AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
                --AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH2,
                AdjacencyBias = 'Back',
                AdjacencyPriority = {
                    categories.SHIELD * categories.STRUCTURE,
                    categories.STRUCTURE * categories.FACTORY * categories.AIR,
                    categories.RADAR * categories.STRUCTURE,
                    categories.ENERGYPRODUCTION * categories.TECH2,
                    categories.FACTORY * categories.STRUCTURE,
                },
                maxUnits = 1,
                maxRadius = 10,
                BuildStructures = {
                    'T2EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Power Engineer Scale',
        PlatoonTemplate = 'T2EngineerBuilderRNG',
        Priority = 800,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'EnergyT2', 6},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'EnergyT2' }},
            { EBC, 'LessThanEnergyTrendCombinedRNG', { 120.0 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 0.1 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.00}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 3, categories.ENERGYPRODUCTION * categories.TECH2, 1, categories.ENERGYPRODUCTION * categories.TECH3 }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION *  categories.TECH3 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 12,
            Construction = {
                AdjacencyPriority = {
                    categories.SHIELD * categories.STRUCTURE,
                    categories.STRUCTURE * categories.FACTORY * categories.AIR,
                    categories.RADAR * categories.STRUCTURE,
                    categories.ENERGYPRODUCTION * categories.TECH2,
                    categories.FACTORY * categories.STRUCTURE,
                },
                maxUnits = 1,
                maxRadius = 4,
                BuildStructures = {
                    'T2EnergyProduction',
                },
            }
        }
    },
    --[[Builder {
        BuilderName = 'RNGAI T3 Power Engineer 1st',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 900,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Energy' }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION *  categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.9, 0.1 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 12,
            Construction = {
                AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
                AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH3,
                maxUnits = 1,
                maxRadius = 15,
                BuildStructures = {
                    'T3EnergyProduction',
                },
            }
        }
    },]]
    Builder {
        BuilderName = 'RNGAI T3 Power Engineer Negative Trend',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 1010,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'EnergyT3', 6},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'EnergyT3' }},
            { EBC, 'LessThanEnergyTrendCombinedRNG', { 15.0 } },
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.1 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 12,
            Construction = {
                --AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
                --AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH3,
                AdjacencyBias = 'Back',
                AdjacencyPriority = {
                    categories.SHIELD * categories.STRUCTURE,
                    categories.STRUCTURE * categories.FACTORY * categories.AIR,
                    categories.RADAR * categories.STRUCTURE,
                    categories.ENERGYPRODUCTION * categories.TECH2,
                    categories.FACTORY * categories.STRUCTURE,
                },
                maxUnits = 1,
                maxRadius = 15,
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
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'EnergyT3', 6},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'EnergyT3' }},
            { EBC, 'LessThanEnergyTrendCombinedRNG', { 500.0 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 0.5 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.08, 0.0}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * categories.TECH3 }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.ENERGYPRODUCTION * categories.TECH3 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 12,
            Construction = {
                AdjacencyPriority = {
                    categories.SHIELD * categories.STRUCTURE,
                    categories.STRUCTURE * categories.FACTORY * categories.AIR,
                    categories.RADAR * categories.STRUCTURE,
                    categories.ENERGYPRODUCTION * categories.TECH2,
                    categories.FACTORY * categories.STRUCTURE,
                },
                maxUnits = 1,
                maxRadius = 15,
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
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Energy' }},
            { EBC, 'LessThanEnergyEfficiencyOverTimeRNG', { 1.3 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.0, 0.1 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.0}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }}, -- Don't build after 1 T2 Pgens Exist
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = true,
            Construction = {
                AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
                AdjacencyDistance = 50,
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
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Energy' }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 1.1, 0.1 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.0}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.ENERGYPRODUCTION *  categories.TECH3 }},
            { EBC, 'LessThanEnergyTrendOverTimeRNG', { 0.0 } },
            { EBC, 'LessThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.TECH2 * categories.ENERGYPRODUCTION }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
                AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH2,
                maxUnits = 1,
                maxRadius = 10,
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
        BuilderName = 'RNGAI T1Engineer Hydro 60',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1010,
        InstanceCount = 1,
        BuilderConditions = { 
            { UCBC, 'CanBuildOnHydroLessThanDistanceRNG', { 'LocationType', 65, 1, 'AntiSurface'}},
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
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 780,
        InstanceCount = 2,
        BuilderConditions = { 
            { UCBC, 'CanBuildOnHydroLessThanDistanceRNG', { 'LocationType', 256, 1, 'AntiSurface'}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 0.1 }},
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
        BuilderName = 'RNG T1 Energy Storage Builder OverCharge',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 850,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 240 } },
            { UCBC, 'UnitCapCheckLess', { .7 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYSTORAGE }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.9 }},
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
        BuilderName = 'RNG T1 Energy Storage Builder OverCharge Power',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 850,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 480 } },
            { UCBC, 'UnitCapCheckLess', { .7 } },
            { EBC, 'LessThanEnergyStorageCurrentRNG', { 20000 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.9, 0.9 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                AvoidCategory = categories.ENERGYENERGYSTORAGE,
                maxUnits = 1,
                maxRadius = 5,
                BuildStructures = {
                    'EnergyStorage',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG T1 Energy Storage Builder',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 500,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 600 } },
            { UCBC, 'UnitCapCheckLess', { .7 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.0, 1.1 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.80}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 8, categories.ENERGYSTORAGE }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                AvoidCategory = categories.ENERGYENERGYSTORAGE,
                maxUnits = 1,
                maxRadius = 5,
                BuildStructures = {
                    'EnergyStorage',
                },
            }
        }
    },
}
