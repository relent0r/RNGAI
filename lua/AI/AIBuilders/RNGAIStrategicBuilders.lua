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
        PlatoonTemplate = 'EngineerStateT3SACURNG',
        Priority = 700,
        DelayEqualBuildPlattons = {'HighValue', 20},
        BuilderConditions = {
            { EBC, 'HighValueGateRNG', {}},
            { UCBC, 'BuildOnlyOnLocationRNG', { 'LocationType', 'MAIN' } },
            { UCBC, 'ValidateLateGameBuild', { 'LocationType' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.1 }},
            { EBC, 'GreaterThanEconIncomeCombinedRNG', { 7.0, 600.0 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.NUKE * categories.STRUCTURE}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL) }},
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
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
                    { Unit = 'T3StrategicMissile', Categories = categories.STRUCTURE * categories.NUKE * categories.TECH3 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI SML Low Pri',
        PlatoonTemplate = 'EngineerStateT3SACURNG',
        Priority = 500,
        DelayEqualBuildPlattons = {'HighValue', 20},
        BuilderConditions = {
            { EBC, 'HighValueGateRNG', {}},
            { UCBC, 'BuildOnlyOnLocationRNG', { 'LocationType', 'MAIN' } },
            { UCBC, 'ValidateLateGameBuild', { 'LocationType' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.4 }},
            { EBC, 'GreaterThanEconIncomeCombinedRNG', { 18.0, 1500.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.30, 0.95 } },
            { UCBC, 'IsEngineerNotBuilding', { categories.NUKE * categories.STRUCTURE}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL) }},
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
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
                    { Unit = 'T3StrategicMissile', Categories = categories.STRUCTURE * categories.NUKE * categories.TECH3 },
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
        PlatoonTemplate = 'EngineerStateT3SACURNG',
        Priority = 650,
        DelayEqualBuildPlattons = {'HighValue', 20},
        BuilderConditions = {
            { EBC, 'HighValueGateRNG', {}},
            { UCBC, 'BuildOnlyOnLocationRNG', { 'LocationType', 'MAIN' } },
            { UCBC, 'ValidateLateGameBuild', { 'LocationType' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.1 }},
            { EBC, 'GreaterThanEconIncomeCombinedRNG', { 8.0, 700.0 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.ARTILLERY * categories.TECH3 } },
            { TBC, 'EnemyThreatInT3ArtilleryRangeRNG', {'LocationType', 0.30} },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.ARTILLERY * categories.TECH3 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
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
                    { Unit = 'T3Artillery', Categories = categories.STRUCTURE * categories.ARTILLERY * categories.TECH3 },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T3 Artillery Lo Pri',
        PlatoonTemplate = 'EngineerStateT3SACURNG',
        Priority = 600,
        DelayEqualBuildPlattons = {'HighValue', 20},
        BuilderConditions = {
            { EBC, 'HighValueGateRNG', {}},
            { UCBC, 'BuildOnlyOnLocationRNG', { 'LocationType', 'MAIN' } },
            { UCBC, 'ValidateLateGameBuild', { 'LocationType' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.2 }},
            { EBC, 'GreaterThanEconIncomeCombinedRNG', { 20.0, 1400.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.30, 0.95 } },
            { TBC, 'EnemyThreatInT3ArtilleryRangeRNG', {'LocationType', 0.60} },
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.ARTILLERY * categories.TECH3 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
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
                    { Unit = 'T3Artillery', Categories = categories.STRUCTURE * categories.ARTILLERY * categories.TECH3 },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T4 Mavor Exp',
        PlatoonTemplate = 'EngineerStateUEFT3SACURNG',
        DelayEqualBuildPlattons = {'HighValue', 20},
        Priority = 750,
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'HighValueGateRNG', {}},
            { UCBC, 'BuildOnlyOnLocationRNG', { 'LocationType', 'MAIN' } },
            { UCBC, 'ValidateLateGameBuild', { 'LocationType' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.STRATEGIC * categories.TECH3}},
            { UCBC, 'IsEngineerNotBuilding', { categories.EXPERIMENTAL * categories.STRUCTURE - categories.ORBITALSYSTEM}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.EXPERIMENTAL * categories.STRUCTURE * categories.ARTILLERY * categories.UEF}},
            { EBC, 'GreaterThanEconIncomeCombinedRNG', {35, 1500}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.2}},
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            NumAssistees = 35,
            Construction = {
                BuildClose = true,
                AdjacencyPriority = {categories.SHIELD * categories.STRUCTURE},
                HighValue = true,
                BuildStructures = {
                    { Unit = 'T4Artillery', Categories = categories.STRUCTURE * categories.ARTILLERY * categories.EXPERIMENTAL * categories.UEF },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T4 Nuke Exp',
        PlatoonTemplate = 'EngineerStateSeraT3SACURNG',
        DelayEqualBuildPlattons = {'HighValue', 20},
        Priority = 750,
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'HighValueGateRNG', {}},
            { UCBC, 'BuildOnlyOnLocationRNG', { 'LocationType', 'MAIN' } },
            { UCBC, 'ValidateLateGameBuild', { 'LocationType' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.STRATEGIC * categories.TECH3}},
            { UCBC, 'IsEngineerNotBuilding', { categories.EXPERIMENTAL * categories.STRUCTURE }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.EXPERIMENTAL * categories.STRUCTURE * categories.NUKE * categories.SERAPHIM}},
            { EBC, 'GreaterThanEconIncomeCombinedRNG', {35, 1500}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.2}},
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            NumAssistees = 35,
            Construction = {
                BuildClose = true,
                AdjacencyPriority = {categories.SHIELD * categories.STRUCTURE},
                HighValue = true,
                BuildStructures = {
                    { Unit = 'T4Artillery', Categories = categories.STRUCTURE * categories.NUKE * categories.EXPERIMENTAL * categories.SERAPHIM },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T4 RapidFire',
        PlatoonTemplate = 'EngineerStateAeonT3SACURNG',
        DelayEqualBuildPlattons = {'HighValue', 20},
        Priority = 750,
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'HighValueGateRNG', {}},
            { UCBC, 'BuildOnlyOnLocationRNG', { 'LocationType', 'MAIN' } },
            { UCBC, 'ValidateLateGameBuild', { 'LocationType' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.STRATEGIC * categories.TECH3}},
            { UCBC, 'IsEngineerNotBuilding', { categories.EXPERIMENTAL * categories.STRUCTURE}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.EXPERIMENTAL * categories.STRUCTURE * categories.ARTILLERY * categories.AEON}},
            { EBC, 'GreaterThanEconIncomeCombinedRNG', {35, 1500}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.2}},
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            NumAssistees = 35,
            Construction = {
                BuildClose = true,
                AdjacencyPriority = {categories.SHIELD * categories.STRUCTURE},
                HighValue = true,
                BuildStructures = {
                    { Unit = 'T3RapidArtillery', Categories = categories.STRUCTURE * categories.ARTILLERY * categories.EXPERIMENTAL * categories.AEON },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T4 Scathis',
        PlatoonTemplate = 'EngineerStateCybranT3SACURNG',
        DelayEqualBuildPlattons = {'HighValue', 20},
        Priority = 750,
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'HighValueGateRNG', {}},
            { UCBC, 'BuildOnlyOnLocationRNG', { 'LocationType', 'MAIN' } },
            { UCBC, 'ValidateLateGameBuild', { 'LocationType' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.STRATEGIC * categories.TECH3}},
            { UCBC, 'IsEngineerNotBuilding', { categories.EXPERIMENTAL * categories.STRUCTURE}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.EXPERIMENTAL * categories.STRUCTURE * categories.ARTILLERY * categories.CYBRAN}},
            { EBC, 'GreaterThanEconIncomeCombinedRNG', {35, 1500}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.2}},
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            NumAssistees = 35,
            Construction = {
                BuildClose = true,
                AdjacencyCategory = categories.SHIELD * categories.STRUCTURE,
                HighValue = true,
                BuildStructures = {
                    { Unit = 'T4LandExperimental2', Categories = categories.MOBILE * categories.ARTILLERY * categories.EXPERIMENTAL * categories.CYBRAN },
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
        FormRadius = 160,
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
        FormRadius = 160,
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