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
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.EXPERIMENTAL * categories.LAND}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.TECH3 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.EXPERIMENTAL * categories.LAND } },
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconIncome', { 7.0, 600.0 }},
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
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.EXPERIMENTAL * categories.LAND}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.TECH3 } },
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
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
        InstanceCount = 3,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 4, categories.EXPERIMENTAL * categories.LAND}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.TECH3 } },
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
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
        Priority = 400,
        DelayEqualBuildPlattons = {'MobileExperimental', 10},
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.EXPERIMENTAL * categories.LAND}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.TECH3 } },
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.20, 0.95 } },
            { UCBC, 'CheckBuildPlattonDelay', { 'MobileExperimental' }},
            -- Have we the eco to build it ?
            { UCBC, 'UnitCapCheckLess', { 0.99 } },
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
        Priority = 500,
        DelayEqualBuildPlattons = {'MobileExperimental', 10},
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2, 3, 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads 
            -- Have we the eco to build it ?
            { UCBC, 'CanBuildCategory', { categories.MOBILE * categories.AIR * categories.EXPERIMENTAL - categories.SATELLITE } },
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.95 } },
            { EBC, 'GreaterThanEconIncome', { 7.0, 600.0 }},                    -- Base income
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
            { UCBC, 'CanBuildCategory', { categories.MOBILE * categories.AIR * categories.EXPERIMENTAL - categories.SATELLITE } },
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.20, 0.95 } },
            { EBC, 'GreaterThanEconIncome', { 7.0, 600.0 }},                    -- Base income
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
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.90 } },
            { EBC, 'GreaterThanEconIncome', { 7.0, 600.0 }},                    -- Base income
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
            PrioritizedCategories = { 'MASSEXTRACTION STRUCTURE TECH3', 'MASSEXTRACTION STRUCTURE TECH2', 'MASSEXTRACTION STRUCTURE', 'STRUCTURE STRATEGIC EXPERIMENTAL', 'EXPERIMENTAL ARTILLERY OVERLAYINDIRECTFIRE', 'STRUCTURE STRATEGIC TECH3', 'STRUCTURE NUKE TECH3', 'EXPERIMENTAL ORBITALSYSTEM', 'EXPERIMENTAL ENERGYPRODUCTION STRUCTURE', 'STRUCTURE ANTIMISSILE TECH3', 'TECH3 MASSFABRICATION', 'TECH3 ENERGYPRODUCTION', 'STRUCTURE STRATEGIC', 'STRUCTURE DEFENSE TECH3 ANTIAIR', 'COMMAND', 'STRUCTURE DEFENSE TECH3 DIRECTFIRE', 'STRUCTURE DEFENSE TECH3 SHIELD', 'STRUCTURE DEFENSE TECH2', 'STRUCTURE' },
        },
    },
}
