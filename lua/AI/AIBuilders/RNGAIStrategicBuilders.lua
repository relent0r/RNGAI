local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local TBC = '/lua/editor/ThreatBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI SML Builders',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI SML Hi Pri',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        Priority = 700,
        DelayEqualBuildPlattons = {'Artillery', 20},
        BuilderConditions = {
            { UCBC, 'BuildOnlyOnLocation', { 'LocationType', 'MAIN' } },
            { EBC, 'GreaterThanEconIncomeRNG', { 7.0, 600.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.90 } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.9, 1.0 }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.NUKE * categories.STRUCTURE}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL) }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.ENERGYPRODUCTION * categories.TECH3 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                DesiresAssist = true,
                NumAssistees = 15,
                BuildClose = false,
                AdjacencyCategory = categories.STRUCTURE * categories.SHIELD,
                AvoidCategory = categories.STRUCTURE * categories.NUKE,
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
        DelayEqualBuildPlattons = {'Artillery', 20},
        BuilderConditions = {
            { UCBC, 'BuildOnlyOnLocation', { 'LocationType', 'MAIN' } },
            { EBC, 'GreaterThanEconIncomeRNG', { 9.0, 800.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.40, 0.90 } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 1.0, 1.0 }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.NUKE * categories.STRUCTURE}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL) }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, categories.ENERGYPRODUCTION * categories.TECH3 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                DesiresAssist = true,
                BuildClose = false,
                AdjacencyCategory = categories.STRUCTURE * categories.SHIELD,
                AvoidCategory = categories.STRUCTURE * categories.NUKE,
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
    BuilderGroupName = 'RNGAI Strategic Artillery Builders Small',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T3 Artillery Hi Pri Small',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        Priority = 600,
        DelayEqualBuildPlattons = {'Artillery', 20},
        BuilderConditions = {
            { UCBC, 'BuildOnlyOnLocation', { 'LocationType', 'MAIN' } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'Artillery' }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.9, 1.0 }},
            { EBC, 'GreaterThanEconIncomeRNG', { 8.0, 700.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.95 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.STRUCTURE * categories.ARTILLERY * categories.TECH3 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.ARTILLERY * categories.TECH3 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                DesiresAssist = true,
                NumAssistees = 15,
                AdjacencyCategory = categories.STRUCTURE * categories.SHIELD,
                AvoidCategory = categories.STRUCTURE * categories.ARTILLERY * categories.TECH3,
                maxUnits = 1,
                maxRadius = 20,
                BuildStructures = {
                    'T3Artillery',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T3 Artillery Lo Pri Small',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        Priority = 600,
        DelayEqualBuildPlattons = {'Artillery', 20},
        BuilderConditions = {
            { UCBC, 'BuildOnlyOnLocation', { 'LocationType', 'MAIN' } },
            { TBC, 'EnemyInT3ArtilleryRangeRNG', { 'LocationType', true } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'Artillery' }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.9, 1.0 }},
            { EBC, 'GreaterThanEconIncomeRNG', { 8.0, 700.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.30, 0.95 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.STRUCTURE * categories.ARTILLERY * categories.TECH3 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                DesiresAssist = true,
                NumAssistees = 15,
                AdjacencyCategory = categories.STRUCTURE * categories.SHIELD,
                AvoidCategory = categories.STRUCTURE * categories.ARTILLERY * categories.TECH3,
                maxUnits = 1,
                maxRadius = 20,
                BuildStructures = {
                    'T3Artillery',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T4 Mavor Exp Nuke Small',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        DelayEqualBuildPlattons = {'Artillery', 20},
        Priority = 650,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'FactionIndex', {1,4} }, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'BuildOnlyOnLocation', { 'LocationType', 'MAIN' } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'Artillery' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.ARTILLERY * categories.TECH3}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.EXPERIMENTAL * categories.STRUCTURE - categories.ORBITALSYSTEM}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.EXPERIMENTAL * categories.STRUCTURE * categories.ARTILLERY}},
            { EBC, 'GreaterThanEconIncomeRNG', {40, 1500}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 1.2, 1.2}},
        },
        BuilderType = 'Any',
        BuilderData = {
            MinNumAssistees = 3,
            Construction = {
                BuildClose = true,
                AdjacencyCategory = categories.SHIELD * categories.STRUCTURE,
                BuildStructures = {
                    'T4Artillery',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T4 RapidFire Small',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        DelayEqualBuildPlattons = {'Artillery', 20},
        Priority = 650,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 } }, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'BuildOnlyOnLocation', { 'LocationType', 'MAIN' } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'Artillery' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.ARTILLERY * categories.TECH3}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.EXPERIMENTAL * categories.STRUCTURE}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.EXPERIMENTAL * categories.STRUCTURE * categories.ARTILLERY}},
            { EBC, 'GreaterThanEconIncomeRNG', {40, 1500}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 1.2, 1.2}},
        },
        BuilderType = 'Any',
        BuilderData = {
            MinNumAssistees = 3,
            Construction = {
                BuildClose = true,
                AdjacencyCategory = categories.SHIELD * categories.STRUCTURE,
                BuildStructures = {
                    'T3RapidArtillery',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T4 Scathis Small',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        DelayEqualBuildPlattons = {'Artillery', 20},
        Priority = 650,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 3 } }, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'BuildOnlyOnLocation', { 'LocationType', 'MAIN' } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'Artillery' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.ARTILLERY * categories.TECH3}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.EXPERIMENTAL * categories.STRUCTURE}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.EXPERIMENTAL * categories.STRUCTURE * categories.ARTILLERY}},
            { EBC, 'GreaterThanEconIncomeRNG', {40, 1500}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 1.2, 1.2}},
        },
        BuilderType = 'Any',
        BuilderData = {
            MinNumAssistees = 3,
            Construction = {
                BuildClose = true,
                AdjacencyCategory = categories.SHIELD * categories.STRUCTURE,
                BuildStructures = {
                    'T4LandExperimental2',
                },
                Location = 'LocationType',
            }
        }
    },

}

BuilderGroup {
    BuilderGroupName = 'RNGAI Strategic Artillery Builders Large',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T3 Artillery Hi Pri Large',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        Priority = 600,
        DelayEqualBuildPlattons = {'Artillery', 20},
        BuilderConditions = {
            { UCBC, 'BuildOnlyOnLocation', { 'LocationType', 'MAIN' } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'Artillery' }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.9, 1.0 }},
            { EBC, 'GreaterThanEconIncomeRNG', { 8.0, 700.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.95 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.STRUCTURE * categories.ARTILLERY * categories.TECH3 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.ARTILLERY * categories.TECH3 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                DesiresAssist = true,
                NumAssistees = 15,
                AdjacencyCategory = categories.STRUCTURE * categories.SHIELD,
                AvoidCategory = categories.STRUCTURE * categories.ARTILLERY * categories.TECH3,
                maxUnits = 1,
                maxRadius = 20,
                BuildStructures = {
                    'T3Artillery',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T3 Artillery Lo Pri Large',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        Priority = 600,
        DelayEqualBuildPlattons = {'Artillery', 20},
        BuilderConditions = {
            { UCBC, 'BuildOnlyOnLocation', { 'LocationType', 'MAIN' } },
            { TBC, 'EnemyInT3ArtilleryRangeRNG', { 'LocationType', true } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'Artillery' }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.9, 1.0 }},
            { EBC, 'GreaterThanEconIncomeRNG', { 8.0, 700.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.30, 0.95 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.STRUCTURE * categories.ARTILLERY * categories.TECH3 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                DesiresAssist = true,
                NumAssistees = 15,
                AdjacencyCategory = categories.STRUCTURE * categories.SHIELD,
                AvoidCategory = categories.STRUCTURE * categories.ARTILLERY * categories.TECH3,
                maxUnits = 1,
                maxRadius = 20,
                BuildStructures = {
                    'T3Artillery',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T4 Mavor Exp Nuke Large',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        DelayEqualBuildPlattons = {'Artillery', 20},
        Priority = 650,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'FactionIndex', {1,4} }, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'BuildOnlyOnLocation', { 'LocationType', 'MAIN' } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'Artillery' }},
            { TBC, 'EnemyInT3ArtilleryRangeRNG', { 'LocationType', false } },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.STRUCTURE * categories.ARTILLERY * categories.TECH3}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.EXPERIMENTAL * categories.STRUCTURE - categories.ORBITALSYSTEM}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.EXPERIMENTAL * categories.STRUCTURE * categories.ARTILLERY}},
            { EBC, 'GreaterThanEconIncomeRNG', {40, 1500}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 1.2, 1.2}},
        },
        BuilderType = 'Any',
        BuilderData = {
            MinNumAssistees = 3,
            Construction = {
                BuildClose = true,
                AdjacencyCategory = categories.SHIELD * categories.STRUCTURE,
                BuildStructures = {
                    'T4Artillery',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T4 RapidFire Large',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        DelayEqualBuildPlattons = {'Artillery', 20},
        Priority = 650,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 } }, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'BuildOnlyOnLocation', { 'LocationType', 'MAIN' } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'Artillery' }},
            { TBC, 'EnemyInT3ArtilleryRangeRNG', { 'LocationType', false } },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.STRUCTURE * categories.ARTILLERY * categories.TECH3}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.EXPERIMENTAL * categories.STRUCTURE}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.EXPERIMENTAL * categories.STRUCTURE * categories.ARTILLERY}},
            { EBC, 'GreaterThanEconIncomeRNG', {40, 1500}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 1.2, 1.2}},
        },
        BuilderType = 'Any',
        BuilderData = {
            MinNumAssistees = 3,
            Construction = {
                BuildClose = true,
                AdjacencyCategory = categories.SHIELD * categories.STRUCTURE,
                BuildStructures = {
                    'T3RapidArtillery',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T4 Scathis Large',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        DelayEqualBuildPlattons = {'Artillery', 20},
        Priority = 650,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 3 } }, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'BuildOnlyOnLocation', { 'LocationType', 'MAIN' } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'Artillery' }},
            { TBC, 'EnemyInT3ArtilleryRangeRNG', { 'LocationType', false } },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.STRUCTURE * categories.ARTILLERY * categories.TECH3}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.EXPERIMENTAL * categories.STRUCTURE}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.EXPERIMENTAL * categories.STRUCTURE * categories.ARTILLERY}},
            { EBC, 'GreaterThanEconIncomeRNG', {40, 1500}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 1.2, 1.2}},
        },
        BuilderType = 'Any',
        BuilderData = {
            MinNumAssistees = 3,
            Construction = {
                BuildClose = true,
                AdjacencyCategory = categories.SHIELD * categories.STRUCTURE,
                BuildStructures = {
                    'T4LandExperimental2',
                },
                Location = 'LocationType',
            }
        }
    },

}

BuilderGroup {
    BuilderGroupName = 'RNGAI Strategic Formers',
    BuildersType = 'PlatoonFormBuilder',
    --[[Builder {
        BuilderName = 'RNGAI SML Former',
        PlatoonTemplate = 'T3NukeRNG',
        Priority = 400,
        InstanceCount = 10,
        FormRadius = 10000,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanArmyPoolWithCategoryRNG', { 0, categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL) } },
        },
        BuilderType = 'Any',
    },]]
    Builder {
        BuilderName = 'RNGAI SML Merger',
        PlatoonTemplate = 'AddToSMLPlatoonRNG',
        Priority = 10,
        InstanceCount = 1,
        FormRadius = 10000,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanArmyPoolWithCategoryRNG', { 0, categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL) } },
        },
        BuilderData = {
            PlatoonPlan = 'NUKEAIRNG',
            Location = 'LocationType'
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T3 Artillery Former',
        PlatoonTemplate = 'T3ArtilleryStructureRNG',
        Priority = 10,
        InstanceCount = 100,
        FormRadius = 10000,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanArmyPoolWithCategoryRNG', { 0, categories.STRUCTURE * categories.ARTILLERY * (categories.TECH3 + categories.EXPERIMENTAL) } },
        },
        BuilderType = 'Any',
    },
}