local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local TBC = '/lua/editor/ThreatBuildConditions.lua'
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

BuilderGroup {
    BuilderGroupName = 'RNGAI SML Builders',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI SML Hi Pri',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        Priority = 700,
        DelayEqualBuildPlattons = {'HighValue', 20},
        BuilderConditions = {
            
            { UCBC, 'BuildOnlyOnLocationRNG', { 'LocationType', 'MAIN' } },
            { UCBC, 'ValidateLateGameBuild', { 'LocationType' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { EBC, 'GreaterThanEconIncomeCombinedRNG', { 7.0, 600.0 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.NUKE * categories.STRUCTURE}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL) }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.ENERGYPRODUCTION * categories.TECH3 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 25,
            Construction = {
                DesiresAssist = true,
                BuildClose = false,
                AdjacencyPriority = {categories.STRUCTURE * categories.SHIELD},
                AvoidCategory = categories.STRUCTURE * categories.NUKE,
                HighValue = true,
                maxUnits = 1,
                maxRadius = 20,
                LocationType = 'LocationType',
                BuildStructures = {
                    'T3StrategicMissile',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI SML Low Pri',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        Priority = 500,
        DelayEqualBuildPlattons = {'HighValue', 20},
        BuilderConditions = {
            
            { UCBC, 'BuildOnlyOnLocationRNG', { 'LocationType', 'MAIN' } },
            { UCBC, 'ValidateLateGameBuild', { 'LocationType' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
            { EBC, 'GreaterThanEconIncomeCombinedRNG', { 9.0, 800.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.40, 0.90 } },
            { UCBC, 'IsEngineerNotBuilding', { categories.NUKE * categories.STRUCTURE}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL) }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, categories.ENERGYPRODUCTION * categories.TECH3 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 10,
            Construction = {
                DesiresAssist = true,
                BuildClose = false,
                AdjacencyPriority = {categories.STRUCTURE * categories.SHIELD},
                AvoidCategory = categories.STRUCTURE * categories.NUKE,
                HighValue = true,
                maxUnits = 1,
                maxRadius = 20,
                LocationType = 'LocationType',
                BuildStructures = {
                    'T3StrategicMissile',
                },
            }
        }
    },
}
BuilderGroup {
    BuilderGroupName = 'RNGAI Strategic Artillery Builders',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T3 Artillery Hi Pri',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        Priority = 600,
        DelayEqualBuildPlattons = {'HighValue', 20},
        BuilderConditions = {
            { UCBC, 'BuildOnlyOnLocationRNG', { 'LocationType', 'MAIN' } },
            { UCBC, 'ValidateLateGameBuild', { 'LocationType' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { EBC, 'GreaterThanEconIncomeCombinedRNG', { 8.0, 700.0 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.ARTILLERY * categories.TECH3 } },
            { TBC, 'EnemyThreatInT3ArtilleryRangeRNG', {'LocationType', 0.30} },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.ARTILLERY * categories.TECH3 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 30,
            Construction = {
                BuildClose = true,
                DesiresAssist = true,
                AdjacencyPriority = {categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3},
                AvoidCategory = categories.STRUCTURE * categories.ARTILLERY * categories.TECH3,
                HighValue = true,
                maxUnits = 1,
                maxRadius = 20,
                BuildStructures = {
                    'T3Artillery',
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T3 Artillery Lo Pri',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        Priority = 600,
        DelayEqualBuildPlattons = {'HighValue', 20},
        BuilderConditions = {
            { UCBC, 'BuildOnlyOnLocationRNG', { 'LocationType', 'MAIN' } },
            { UCBC, 'ValidateLateGameBuild', { 'LocationType' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.2 }},
            { EBC, 'GreaterThanEconIncomeCombinedRNG', { 20.0, 800.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.30, 0.95 } },
            { TBC, 'EnemyThreatInT3ArtilleryRangeRNG', {'LocationType', 0.60} },
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.ARTILLERY * categories.TECH3 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 15,
            Construction = {
                BuildClose = true,
                DesiresAssist = true,
                AdjacencyPriority = {categories.STRUCTURE * categories.SHIELD},
                AvoidCategory = categories.STRUCTURE * categories.ARTILLERY * categories.TECH3,
                HighValue = true,
                maxUnits = 1,
                maxRadius = 20,
                BuildStructures = {
                    'T3Artillery',
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T4 Mavor Exp Nuke',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        DelayEqualBuildPlattons = {'HighValue', 20},
        Priority = 750,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'FactionIndex', {1,4} }, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'BuildOnlyOnLocationRNG', { 'LocationType', 'MAIN' } },
            { UCBC, 'ValidateLateGameBuild', { 'LocationType' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.STRATEGIC * categories.TECH3}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'IsEngineerNotBuilding', { categories.EXPERIMENTAL * categories.STRUCTURE - categories.ORBITALSYSTEM}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.EXPERIMENTAL * categories.STRUCTURE * categories.ARTILLERY}},
            { EBC, 'GreaterThanEconIncomeCombinedRNG', {40, 1500}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.2}},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 35,
            Construction = {
                BuildClose = true,
                AdjacencyPriority = {categories.SHIELD * categories.STRUCTURE},
                HighValue = true,
                BuildStructures = {
                    'T4Artillery',
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T4 RapidFire',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        DelayEqualBuildPlattons = {'HighValue', 20},
        Priority = 750,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 } }, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'BuildOnlyOnLocationRNG', { 'LocationType', 'MAIN' } },
            { UCBC, 'ValidateLateGameBuild', { 'LocationType' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.STRATEGIC * categories.TECH3}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'IsEngineerNotBuilding', { categories.EXPERIMENTAL * categories.STRUCTURE}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.EXPERIMENTAL * categories.STRUCTURE * categories.ARTILLERY}},
            { EBC, 'GreaterThanEconIncomeCombinedRNG', {40, 1500}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.2}},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 35,
            Construction = {
                BuildClose = true,
                AdjacencyPriority = {categories.SHIELD * categories.STRUCTURE},
                HighValue = true,
                BuildStructures = {
                    'T3RapidArtillery',
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T4 Scathis',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        DelayEqualBuildPlattons = {'HighValue', 20},
        Priority = 750,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 3 } }, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'BuildOnlyOnLocationRNG', { 'LocationType', 'MAIN' } },
            { UCBC, 'ValidateLateGameBuild', { 'LocationType' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.STRATEGIC * categories.TECH3}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'IsEngineerNotBuilding', { categories.EXPERIMENTAL * categories.STRUCTURE}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.EXPERIMENTAL * categories.STRUCTURE * categories.ARTILLERY}},
            { EBC, 'GreaterThanEconIncomeCombinedRNG', {40, 1500}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.2}},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 35,
            Construction = {
                BuildClose = true,
                AdjacencyCategory = categories.SHIELD * categories.STRUCTURE,
                HighValue = true,
                BuildStructures = {
                    'T4LandExperimental2',
                },
                LocationType = 'LocationType',
            }
        }
    },

}

BuilderGroup {
    BuilderGroupName = 'RNGAI Strategic Formers',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI Strategic Missile Launcher',
        PlatoonTemplate = 'T3NukeStructureRNG',
        Priority = 10,
        InstanceCount = 5,
        FormRadius = 10000,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanArmyPoolWithCategoryRNG', { 0, categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL) } },
        },
        BuilderData = {
            StateMachine = 'Nuke',
            LocationType = 'LocationType'
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T3 Artillery Former',
        PlatoonTemplate = 'T3ArtilleryStructureRNG',
        Priority = 10,
        InstanceCount = 5,
        FormRadius = 10000,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanArmyPoolWithCategoryRNG', { 0, categories.STRUCTURE * categories.ARTILLERY * (categories.TECH3 + categories.EXPERIMENTAL) } },
        },
        BuilderData = {
            StateMachine = 'StrategicArtillery',
            LocationType = 'LocationType'
        },
        BuilderType = 'Any',
    },
}