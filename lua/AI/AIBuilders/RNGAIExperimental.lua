local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local ExBaseTmpl = 'ExpansionBaseTemplates'

BuilderGroup {
    BuilderGroupName = 'RNGAI Experimental Builders',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Experimental1 1st',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 800,
        DelayEqualBuildPlattons = {'MobileExperimental', 10},
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'CheckBuildPlattonDelay', { 'MobileExperimental' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.EXPERIMENTAL * categories.LAND}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.TECH3 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.EXPERIMENTAL * categories.LAND } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 1.0, 1.0 }},
            { EBC, 'GreaterThanEconIncomeRNG', { 7.0, 400.0 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 10,
            Construction = {
                DesiresAssist = true,
                NumAssistees = 10,
                BuildClose = true,
                AdjacencyCategory = categories.STRUCTURE * categories.SHIELD,
                BuildStructures = {
                    'T4LandExperimental1',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI Experimental1 MultiBuild',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 500,
        DelayEqualBuildPlattons = {'MobileExperimental', 10},
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'CheckBuildPlattonDelay', { 'MobileExperimental' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.EXPERIMENTAL * categories.LAND}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.TECH3 } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 1.0, 1.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.90 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 10,
            Construction = {
                DesiresAssist = true,
                NumAssistees = 10,
                BuildClose = true,
                AdjacencyCategory = categories.STRUCTURE * categories.SHIELD,
                BuildStructures = {
                    'T4LandExperimental1',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI Experimental1 Excess',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 300,
        DelayEqualBuildPlattons = {'MobileExperimental', 10},
        InstanceCount = 3,
        BuilderConditions = {
            { UCBC, 'CheckBuildPlattonDelay', { 'MobileExperimental' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 4, categories.EXPERIMENTAL * categories.LAND}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.TECH3 } },
            { EBC, 'GreaterThanEconTrendOverTimeRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.80, 0.95 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 10,
            Construction = {
                DesiresAssist = true,
                NumAssistees = 10,
                BuildClose = true,
                AdjacencyCategory = categories.STRUCTURE * categories.SHIELD,
                BuildStructures = {
                    'T4LandExperimental1',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI Experimental1 Megabot',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        Priority = 500,
        DelayEqualBuildPlattons = {'MobileExperimental', 10},
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 3 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'CheckBuildPlattonDelay', { 'MobileExperimental' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.EXPERIMENTAL * categories.LAND}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.TECH3 } },
            { EBC, 'GreaterThanEconTrendOverTimeRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.90 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 10,
            Construction = {
                DesiresAssist = true,
                NumAssistees = 10,
                BuildClose = false,
                AdjacencyCategory = categories.STRUCTURE * categories.SHIELD,
                BuildStructures = {
                    'T4LandExperimental3',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI Experimental1 Air',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        Priority = 550,
        DelayEqualBuildPlattons = {'MobileExperimental', 10},
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2, 3, 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads 
            { UCBC, 'CheckBuildPlattonDelay', { 'MobileExperimental' }},
            -- Have we the eco to build it ?
            { UCBC, 'CanBuildCategoryRNG', { categories.MOBILE * categories.AIR * categories.EXPERIMENTAL - categories.SATELLITE } },
            { EBC, 'GreaterThanEconTrendOverTimeRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.95 } },
            { EBC, 'GreaterThanEconIncomeRNG', { 7.0, 600.0 }},                    -- Base income
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 10,
            Construction = {
                DesiresAssist = true,
                NumAssistees = 10,
                BuildClose = true,
                BuildStructures = {
                    'T4AirExperimental1',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI Experimental1 Sea',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        Priority = 500,
        DelayEqualBuildPlattons = {'MobileExperimental', 10},
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads 
            -- Have we the eco to build it ?
            { UCBC, 'CanBuildCategoryRNG', { categories.MOBILE * categories.AIR * categories.EXPERIMENTAL - categories.SATELLITE } },
            { EBC, 'GreaterThanEconTrendOverTimeRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.20, 0.95 } },
            { EBC, 'GreaterThanEconIncomeRNG', { 7.0, 600.0 }},                    -- Base income
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 10,
            Construction = {
                DesiresAssist = true,
                NumAssistees = 10,
                BuildClose = true,
                BuildStructures = {
                    'T4SeaExperimental1',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI Experimental1 Novax',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        Priority = 700,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'MobileExperimental', 10},
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 1 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads 
            { UCBC, 'CheckBuildPlattonDelay', { 'MobileExperimental' }},
            -- Have we the eco to build it ?
            { EBC, 'GreaterThanEconTrendOverTimeRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.90 } },
            { EBC, 'GreaterThanEconIncomeRNG', { 7.0, 600.0 }},                    -- Base income
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 10,
            Construction = {
                DesiresAssist = true,
                NumAssistees = 10,
                BuildClose = true,
                BuildStructures = {
                    'T4SatelliteExperimental',
                },
                Location = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAIR Experimental Builders',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAIR Experimental1 1st',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 800,
        DelayEqualBuildPlattons = {'MobileExperimental', 10},
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'CheckBuildPlattonDelay', { 'MobileExperimental' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.EXPERIMENTAL * categories.LAND}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.TECH3 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.EXPERIMENTAL * categories.LAND } },
            { EBC, 'GreaterThanEconTrendOverTimeRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconIncomeRNG', { 7.0, 400.0 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 20,
            Construction = {
                DesiresAssist = true,
                NumAssistees = 20,
                BuildClose = true,
                AdjacencyCategory = categories.STRUCTURE * categories.SHIELD,
                BuildStructures = {
                    'T4LandExperimental1',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAIR Experimental1 MultiBuild',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 500,
        DelayEqualBuildPlattons = {'MobileExperimental', 10},
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'CheckBuildPlattonDelay', { 'MobileExperimental' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.EXPERIMENTAL * categories.LAND}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 5, categories.MASSEXTRACTION * categories.TECH3}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.TECH3 } },
            { EBC, 'GreaterThanEconTrendOverTimeRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.90 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 10,
            Construction = {
                DesiresAssist = true,
                NumAssistees = 10,
                BuildClose = true,
                AdjacencyCategory = categories.STRUCTURE * categories.SHIELD,
                BuildStructures = {
                    'T4LandExperimental1',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAIR Experimental1 Excess',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 300,
        DelayEqualBuildPlattons = {'MobileExperimental', 10},
        InstanceCount = 3,
        BuilderConditions = {
            { UCBC, 'CheckBuildPlattonDelay', { 'MobileExperimental' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 4, categories.EXPERIMENTAL * categories.LAND}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.TECH3 } },
            { EBC, 'GreaterThanEconIncome', { 30.0, 0.0 } },
            { EBC, 'GreaterThanEconTrendOverTimeRNG', { 0.0, 0.0 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 10,
            Construction = {
                DesiresAssist = true,
                NumAssistees = 10,
                BuildClose = true,
                AdjacencyCategory = categories.STRUCTURE * categories.SHIELD,
                BuildStructures = {
                    'T4LandExperimental1',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAIR Experimental1 Megabot',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        Priority = 500,
        DelayEqualBuildPlattons = {'MobileExperimental', 10},
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 3 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'CheckBuildPlattonDelay', { 'MobileExperimental' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.EXPERIMENTAL * categories.LAND}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.TECH3 } },
            { EBC, 'GreaterThanEconTrendOverTimeRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.90 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 10,
            Construction = {
                DesiresAssist = true,
                NumAssistees = 10,
                BuildClose = false,
                AdjacencyCategory = categories.STRUCTURE * categories.SHIELD,
                BuildStructures = {
                    'T4LandExperimental3',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAIR Experimental1 Air',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        Priority = 550,
        DelayEqualBuildPlattons = {'MobileExperimental', 10},
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2, 3, 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads 
            { UCBC, 'CheckBuildPlattonDelay', { 'MobileExperimental' }},
            -- Have we the eco to build it ?
            { UCBC, 'CanBuildCategoryRNG', { categories.MOBILE * categories.AIR * categories.EXPERIMENTAL - categories.SATELLITE } },
            { EBC, 'GreaterThanEconTrendOverTimeRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.95 } },
            { EBC, 'GreaterThanEconIncomeRNG', { 40.0, 60.0 }},                    -- Base income
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 10,
            Construction = {
                DesiresAssist = true,
                NumAssistees = 10,
                BuildClose = true,
                BuildStructures = {
                    'T4AirExperimental1',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAIR Experimental1 Sea',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        Priority = 500,
        DelayEqualBuildPlattons = {'MobileExperimental', 10},
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads 
            -- Have we the eco to build it ?
            { UCBC, 'CanBuildCategoryRNG', { categories.MOBILE * categories.AIR * categories.EXPERIMENTAL - categories.SATELLITE } },
            { EBC, 'GreaterThanEconTrendOverTimeRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.20, 0.95 } },
            { EBC, 'GreaterThanEconIncomeRNG', { 20.0, 60.0 }},                    -- Base income
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 10,
            Construction = {
                DesiresAssist = true,
                NumAssistees = 10,
                BuildClose = true,
                BuildStructures = {
                    'T4SeaExperimental1',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAIR Experimental1 Novax',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        Priority = 700,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'MobileExperimental', 10},
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 1 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads 
            { UCBC, 'CheckBuildPlattonDelay', { 'MobileExperimental' }},
            -- Have we the eco to build it ?
            { EBC, 'GreaterThanEconTrendOverTimeRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.90 } },
            { EBC, 'GreaterThanEconIncomeRNG', { 50.0, 60.0 }},                    -- Base income
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 10,
            Construction = {
                DesiresAssist = true,
                NumAssistees = 10,
                BuildClose = true,
                BuildStructures = {
                    'T4SatelliteExperimental',
                },
                Location = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Experimental Formers',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T4 Exp Land',
        PlatoonTemplate = 'T4ExperimentalLandRNG',
        Priority = 1000,
        FormRadius = 10000,
        InstanceCount = 50,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.LAND * categories.EXPERIMENTAL } },
        },
        BuilderType = 'Any',
        BuilderData = {
            ThreatWeights = {
                TargetThreatType = 'Commander',
            },
            UseMoveOrder = true,
            PrioritizedCategories = { 'EXPERIMENTAL LAND', 'COMMAND', 'FACTORY LAND', 'MASSPRODUCTION', 'ENERGYPRODUCTION', 'STRUCTURE STRATEGIC', 'STRUCTURE' },
        },
    },
    Builder {
        BuilderName = 'RNGAI T4 Exp Air',
        PlatoonTemplate = 'T4ExperimentalAirRNG',
        Priority = 1000,
        FormRadius = 10000,
        InstanceCount = 50,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.AIR * categories.EXPERIMENTAL } },
        },
        BuilderType = 'Any',
        BuilderData = {
            ThreatWeights = {
                TargetThreatType = 'Commander',
            },
            UseMoveOrder = true,
            PrioritizedCategories = { 'EXPERIMENTAL LAND', 'COMMAND', 'FACTORY LAND', 'MASSPRODUCTION', 'ENERGYPRODUCTION', 'STRUCTURE STRATEGIC', 'STRUCTURE' },
        },
    },
    Builder {
        BuilderName = 'RNGAI T4 Exp Sea',
        PlatoonTemplate = 'T4ExperimentalSea',
        Priority = 1000,
        FormRadius = 10000,
        InstanceCount = 50,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.NAVAL * categories.EXPERIMENTAL } },
        },
        BuilderType = 'Any',
        BuilderData = {
            ThreatWeights = {
                TargetThreatType = 'Commander',
            },
            UseMoveOrder = true,
            PrioritizedCategories = { 'EXPERIMENTAL LAND', 'COMMAND', 'FACTORY NAVAL', 'MASSPRODUCTION', 'ENERGYPRODUCTION', 'STRUCTURE STRATEGIC', 'STRUCTURE' },
        },
    },
    Builder {
        BuilderName = 'RNGAI T4 Exp Satellite',
        PlatoonTemplate = 'T4SatelliteExperimentalRNG',
        Priority = 800,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.STRUCTURE * categories.EXPERIMENTAL * categories.ORBITALSYSTEM } },
        },
        FormRadius = 250,
        InstanceCount = 50,
        BuilderType = 'Any',
        BuilderData = {
            SearchRadius = 6000,
            PrioritizedCategories = { 
                categories.MASSEXTRACTION * categories.STRUCTURE * categories.TECH3,
                categories.MASSEXTRACTION * categories.STRUCTURE * categories.TECH2, 
                categories.MASSEXTRACTION * categories.STRUCTURE, 
                categories.STRUCTURE * categories.STRATEGIC * categories.EXPERIMENTAL, 
                categories.EXPERIMENTAL * categories.ARTILLERY * categories.OVERLAYINDIRECTFIRE, 
                categories.STRUCTURE * categories.STRATEGIC * categories.TECH3, 
                categories.STRUCTURE * categories.NUKE * categories.TECH3, 
                categories.EXPERIMENTAL * categories.ORBITALSYSTEM, 
                categories.EXPERIMENTAL * categories.ENERGYPRODUCTION * categories.STRUCTURE, 
                categories.STRUCTURE * categories.ANTIMISSILE * categories.TECH3, 
                categories.TECH3 * categories.MASSFABRICATION, 
                categories.TECH3 * categories.ENERGYPRODUCTION, 
                categories.STRUCTURE * categories.STRATEGIC, 
                categories.STRUCTURE * categories.DEFENSE * categories.TECH3 * categories.ANTIAIR, 
                categories.COMMAND, 
                categories.STRUCTURE * categories.DEFENSE * categories.TECH3 * categories.DIRECTFIRE, 
                categories.STRUCTURE * categories.DEFENSE * categories.TECH3 * categories.SHIELD, 
                categories.STRUCTURE * categories.DEFENSE * categories.TECH2, 
                categories.STRUCTURE,
            },
        },
    },
}
