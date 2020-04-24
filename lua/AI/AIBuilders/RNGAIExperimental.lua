local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local IBC = '/lua/editor/InstantBuildConditions.lua'
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
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 1, categories.EXPERIMENTAL * categories.LAND}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'FactoryGreaterAtLocation', { 'LocationType', 0, categories.FACTORY * categories.TECH3 } },
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconIncome', { 7.0, 600.0 }},
            { IBC, 'BrainNotLowPowerMode', {} },
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
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 2, categories.EXPERIMENTAL * categories.LAND}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'FactoryGreaterAtLocation', { 'LocationType', 1, categories.FACTORY * categories.TECH3 } },
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.30, 0.95 } },
            { IBC, 'BrainNotLowPowerMode', {} },
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
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 4, categories.EXPERIMENTAL * categories.LAND}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'FactoryGreaterAtLocation', { 'LocationType', 1, categories.FACTORY * categories.TECH3 } },
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.80, 0.95 } },
            { IBC, 'BrainNotLowPowerMode', {} },
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
        InstanceCount = 3,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 2, categories.EXPERIMENTAL * categories.LAND}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'FactoryGreaterAtLocation', { 'LocationType', 1, categories.FACTORY * categories.TECH3 } },
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.30, 0.95 } },
            { UCBC, 'CheckBuildPlattonDelay', { 'MobileExperimental' }},
            -- Have we the eco to build it ?
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.ENGINEER * categories.TECH3 - categories.STATIONASSISTPOD }},
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
        BuilderName = 'RNGAI Experimental1 Novax',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        Priority = 500,
        DelayEqualBuildPlattons = {'MobileExperimental', 10},
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 1 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads 
            { UCBC, 'CheckBuildPlattonDelay', { 'MobileExperimental' }},
            -- Have we the eco to build it ?
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.30, 0.95 } },
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
        PlatoonTemplate = 'T4ExperimentalLand',
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
        BuilderName = 'RNGAI T4 Exp Satellite',
        PlatoonTemplate = 'T4SatelliteExperimentalSorian',
        Priority = 800,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.STRUCTURE * categories.EXPERIMENTAL * categories.ORBITALSYSTEM } },
        },
        FormRadius = 250,
        InstanceCount = 50,
        BuilderType = 'Any',
        BuilderData = {
            SearchRadius = 6000,
            PrioritizedCategories = { 'STRUCTURE STRATEGIC EXPERIMENTAL', 'EXPERIMENTAL ARTILLERY OVERLAYINDIRECTFIRE', 'STRUCTURE STRATEGIC TECH3', 'STRUCTURE NUKE TECH3', 'EXPERIMENTAL ORBITALSYSTEM', 'EXPERIMENTAL ENERGYPRODUCTION STRUCTURE', 'STRUCTURE ANTIMISSILE TECH3', 'TECH3 MASSFABRICATION', 'TECH3 ENERGYPRODUCTION', 'STRUCTURE STRATEGIC', 'STRUCTURE DEFENSE TECH3 ANTIAIR', 'COMMAND', 'STRUCTURE DEFENSE TECH3 DIRECTFIRE', 'STRUCTURE DEFENSE TECH3 SHIELD', 'STRUCTURE DEFENSE TECH2', 'STRUCTURE' },
        },
    },
}
