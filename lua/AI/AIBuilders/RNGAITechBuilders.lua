--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAIEconomicBuilders.lua
    Author  :   relentless
    Summary :
        Factory Builders
]]

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'


local ACUClosePriority = function(self, aiBrain)
    if aiBrain.EnemyIntel.ACUEnemyClose then
        return 850
    else
        return 0
    end
end

local ActiveExpansion = function(self, aiBrain, builderManager)
    --LOG('LocationType is '..builderManager.LocationType)
    if aiBrain.BrainIntel.ActiveExpansion == builderManager.LocationType then
        --LOG('Active Expansion is set'..builderManager.LocationType)
        --LOG('Active Expansion builders are set to 900')
        return 700
    else
        --LOG('Disable Air Intie Pool Builder')
        --LOG('My Air Threat '..myAirThreat..'Enemy Air Threat '..enemyAirThreat)
        return 0
    end
end

BuilderGroup {
    BuilderGroupName = 'RNG Tech Factory Builder Land',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Tech Factory Builder Land T1 MainBase',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 1010,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 2,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 130 } },
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'FutureProofEspendRNG', { 0.5, 'greater' }},
            { EBC, 'GreaterThanEconStorageCurrentRNG', { -3, 500 } },
            { EBC, 'FactorySpendRatioRNG', {'Land', 0.7} },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.FACTORY * categories.LAND } },
            --{ EBC, 'GreaterThanEconStorageCurrentRNG', { 105, 1050 } },
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY }},
            },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            Construction = {
                Location = 'LocationType',
                BuildClose = true,
                AdjacencyCategory = categories.ENERGYPRODUCTION + categories.FACTORY - categories.AIR,
                BuildStructures = {
                    'T1LandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Tech Factory Builder Land T1 Scaler',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 900,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'FactorySpendRatioRNG', {'Land', 0.5} },
            { EBC, 'FutureProofEspendRNG', { 0.9, 'greater' }},
            { EBC, 'GreaterThanEconStorageCurrentRNG', { -3, 500 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 3, categories.FACTORY * categories.LAND } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 1.1, 1.0 }},
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
                AdjacencyCategory = categories.ENERGYPRODUCTION + categories.FACTORY - categories.AIR,
                BuildStructures = {
                    'T1LandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Tech Factory Builder Land T2 MainBase',
        PlatoonTemplate = 'EngineerBuilderT23RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'GreaterThanEconStorageCurrentRNG', { -3, 500 } },
            { EBC, 'FactorySpendRatioRNG', {'Land', 0.7} },
            { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH2 * categories.ENERGYPRODUCTION}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.FACTORY * categories.LAND } },
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH3) }},
            },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
                AdjacencyCategory = categories.ENERGYPRODUCTION + categories.FACTORY - categories.AIR,
                BuildStructures = {
                    'T2SupportLandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Tech Factory Builder Land T2 Scaler',
        PlatoonTemplate = 'EngineerBuilderT23RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 10},
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { EBC, 'GreaterThanEconStorageCurrentRNG', { -3, 500 } },
            { EBC, 'FactorySpendRatioRNG', {'Land', 0.5} },
            { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH2 * categories.ENERGYPRODUCTION}},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 3, categories.FACTORY * categories.LAND } },
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 1.2, 1.0 }},
         },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
                AdjacencyCategory = categories.ENERGYPRODUCTION,
                BuildStructures = {
                    'T2SupportLandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Tech Factory Builder Land T3 MainBase',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 10},
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},         },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
                AdjacencyCategory = categories.ENERGYPRODUCTION,
                BuildStructures = {
                    'T3SupportLandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Tech Engineer Unfinished Support Factory',
        PlatoonTemplate = 'T123EngineerAssistRNG',
        Priority = 1010,
        DelayEqualBuildPlattons = {'EngineerAssistUnfinished', 1},
        InstanceCount = 5,
        BuilderConditions = {
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.SUPPORTFACTORY}},
                { EBC, 'GreaterThanEconEfficiencyRNG', { 0.9, 1.0 }},
                { EBC, 'FactorySpendRatioRNG', {'Land', 0.6} },
                { EBC, 'GreaterThanEconStorageCurrentRNG', { -3, 500 } },
            },
        BuilderData = {
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                AssistRange = 100,
                BeingBuiltCategories = {categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.SUPPORTFACTORY},
                AssistClosestUnit = true,
            },
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNG Tech Engineer Unfinished Support Factory Lategame',
        PlatoonTemplate = 'T123EngineerAssistRNG',
        Priority = 1010,
        DelayEqualBuildPlattons = {'EngineerAssistUnfinished', 1},
        InstanceCount = 10,
        BuilderConditions = {
                { EBC, 'GreaterThanEconIncomeRNG',  { 20.0, 200.0}},
                { EBC, 'FactorySpendRatioRNG', {'Land', 0.8} },
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.SUPPORTFACTORY}},
                { EBC, 'GreaterThanEconEfficiencyRNG', { 0.9, 1.0 }},
                { EBC, 'GreaterThanEconStorageCurrentRNG', { -3, 500 } },
            },
        BuilderData = {
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                AssistRange = 100,
                BeingBuiltCategories = {categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.SUPPORTFACTORY},
                AssistClosestUnit = true,
            },
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNG Tech Engineer Early Assist Factory',
        PlatoonTemplate = 'T12EngineerAssistRNG',
        Priority = 1012,
        DelayEqualBuildPlattons = {'EngineerAssistUnfinishedF', 15},
        InstanceCount = 3,
        BuilderConditions = {
                { UCBC, 'CheckBuildPlatoonDelayRNG', { 'EngineerAssistUnfinishedF' }},
                { EBC, 'FactorySpendRatioRNG', {'Land', 0.6} },
                { MIBC, 'GreaterThanGameTimeRNG', { 200 } },
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1}},
                { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.80, 0.80 }},
                { EBC, 'GreaterThanEconStorageCurrentRNG', { -3, 500 } },
            },
        BuilderData = {
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                AssistRange = 100,
                BeingBuiltCategories = {categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1},
                AssistClosestUnit = true,
            },
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNG Tech Engineer Early Unfinished Factory',
        PlatoonTemplate = 'T1EngineerFinishRNG',
        Priority = 1015,
        DelayEqualBuildPlattons = {'EngineerAssistUnfinishedF', 5},
        InstanceCount = 3,
        BuilderConditions = {
                { UCBC, 'CheckBuildPlatoonDelayRNG', { 'EngineerAssistUnfinishedF' }},
                { EBC, 'FactorySpendRatioRNG', {'Land', 0.9} },
                { MIBC, 'GreaterThanGameTimeRNG', { 200 } },
                { UCBC, 'UnfinishedUnits', { 'LocationType', categories.FACTORY * categories.STRUCTURE  * categories.LAND * categories.TECH1 }},
                { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.80, 0.80 }},
                { EBC, 'GreaterThanEconStorageCurrentRNG', { -3, 900 } },
            },
        BuilderData = {
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                AssistRange = 100,
                BeingBuiltCategories = categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1,
                AssistClosestUnit = true,
            },
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNG Tech Engineer Early Unfinished T1 Air',
        PlatoonTemplate = 'T12EngineerAssistRNG',
        Priority = 1011,
        DelayEqualBuildPlattons = {'EngineerAssistUnfinishedAir', 20},
        InstanceCount = 3,
        BuilderConditions = {
                { UCBC, 'CheckBuildPlatoonDelayRNG', { 'EngineerAssistUnfinishedAir' }},
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH1}},
                { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.80, 0.80 }},
                { MIBC, 'GreaterThanGameTimeRNG', { 200 } },
                { EBC, 'GreaterThanEconStorageCurrentRNG', { -3, 500 } },
            },
        BuilderData = {
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                AssistRange = 100,
                BeingBuiltCategories = {categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH1},
                AssistClosestUnit = true,
            },
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNG Tech Engineer Unfinished Structures',
        PlatoonTemplate = 'T1EngineerFinishRNG',
        Priority = 650,
        DelayEqualBuildPlattons = {'EngineerAssistUnfinished', 1},
        InstanceCount = 3,
        BuilderConditions = {
                { UCBC, 'UnfinishedUnits', { 'LocationType', categories.STRUCTURE }},
                { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.80, 0.80 }},
                { EBC, 'GreaterThanEconStorageCurrentRNG', { -3, 500 } },
            },
        BuilderData = {
            Assist = {
                AssistLocation = 'LocationType',
                BeingBuiltCategories = categories.STRUCTURE,
            },
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNG Tech Factory Builder Air T1 Air Scaling',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1003,
        DelayEqualBuildPlattons = {'FactoriesA', 3},
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoriesA' }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.9, 1.0 }},
            { EBC, 'FutureProofEspendRNG', { 1.0, 'greater' }},
            { EBC, 'GreaterThanEconStorageCurrentRNG', { -3, 1200 } },
            { EBC, 'FactoryTypeRatioRNG', {'Air', 0.2} },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.FACTORY * categories.LAND}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.FACTORY * categories.AIR * categories.TECH1 }},
            { EBC, 'CoinFlipRNG', { 0.8 }},
         },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
                AdjacencyCategory = categories.ENERGYPRODUCTION + categories.FACTORY * categories.AIR,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
}
BuilderGroup {
    BuilderGroupName = 'RNG Tech Air Staging Platform',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Tech Air Staging 1',
        PlatoonTemplate = 'EngineerBuilderT123RNG', -- Air Staging has been moved to T1 so don't need T2 engineers now.
        Priority = 900,
        InstanceCount = 2,
        BuilderConditions = {
            -- When do we want to build this ?
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 5, categories.STRUCTURE * categories.ENERGYPRODUCTION } },
            { EBC, 'CoinFlipRNG', { 0.6 }},
            { EBC, 'AvgFuelRatioRNG', { 0.9 }},
            { UCBC, 'HaveUnitRatioRNG', { 0.7, categories.STRUCTURE * categories.AIRSTAGINGPLATFORM, '<=',categories.STRUCTURE * categories.FACTORY * categories.AIR } },
            { EBC, 'FactorySpendRatioRNG', {'Air', 0.2,'greater'} },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.STRUCTURE * categories.AIRSTAGINGPLATFORM }},
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 1,
            Construction = {
                BuildClose = true,
                AdjacencyCategory = categories.STRUCTURE * categories.AIRSTAGINGPLATFORM,
                BuildStructures = {
                    'T2AirStagingPlatform',
                },
                Location = 'LocationType',
            }
        }
    },
}
BuilderGroup {
    BuilderGroupName = 'RNG Tech Land Upgrade Builders',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNG Tech T1 Land Factory Upgrade HQ',
        PlatoonTemplate = 'T1LandFactoryUpgrade',
        Priority = 800,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY } },
                { EBC, 'GreaterThanEconIncomeRNG',  { 5.0, 30.0}},
                { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 1.0 }},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1 }},
                { EBC, 'GreaterThanEconTrendOverTimeRNG', { 0.0, 0.0 } },
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNG Tech T1 Land Factory Upgrade HQ Enemy',
        PlatoonTemplate = 'T1LandFactoryUpgrade',
        Priority = 800,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY } },
                { UCBC, 'EnemyHasUnitOfCategoryRNG', { categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2}},
                { EBC, 'GreaterThanEconIncomeRNG',  { 4.0, 30.0}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1 }},
                { EBC, 'GreaterThanEconTrendOverTimeRNG', { 0.0, 0.0 } },
                { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 1.0 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNG Tech T1 Land Factory Upgrade HQ Excess',
        PlatoonTemplate = 'T1LandFactoryUpgrade',
        Priority = 800,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY } },
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1 }},
                { EBC, 'GreaterThanEconTrendOverTimeRNG', { 0.0, 0.0 } },
                { EBC, 'GreaterThanEconStorageCurrentRNG', { 1600, 4000 } },
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNG Tech T2 Land Factory Upgrade HQ',
        PlatoonTemplate = 'T2LandFactoryUpgrade',
        Priority = 850,
        InstanceCount = 1,
        BuilderConditions = {
                { EBC, 'GreaterThanEconIncomeRNG',  { 10.0, 60.0}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 - categories.SUPPORTFACTORY } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.ENGINEER * categories.TECH2 } },
                { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 1.0 }},
                { EBC, 'GreaterThanEconTrendOverTimeRNG', { 0.0, 0.0 } },
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNG Tech T2 Land Factory Upgrade HQ Enemy',
        PlatoonTemplate = 'T2LandFactoryUpgrade',
        Priority = 850,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 - categories.SUPPORTFACTORY } },
                { UCBC, 'EnemyHasUnitOfCategoryRNG', { categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.ENGINEER * categories.TECH2 } },
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.3}},
                { EBC, 'GreaterThanEconIncomeRNG',  { 9.0, 60.0}},
                { EBC, 'GreaterThanEconTrendOverTimeRNG', { 0.0, 0.0 } },
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNG Tech T2 Land Factory Upgrade HQ Excess',
        PlatoonTemplate = 'T2LandFactoryUpgrade',
        Priority = 800,
        InstanceCount = 1,
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 600 } },
                { EBC, 'GreaterThanEconStorageCurrentRNG', { 2400, 12000 } },
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 } },
                { EBC, 'GreaterThanEconTrendOverTimeRNG', { 0.0, 0.0 } },
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 }},
            },
        BuilderType = 'Any',
    },
}
BuilderGroup {
    BuilderGroupName = 'RNG Tech Land Factory Reclaimer',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Engineer Reclaim T1 Land',
        PlatoonTemplate = 'EngineerBuilderRNG',
        PlatoonAIPlan = 'ReclaimStructuresRNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 3, (categories.TECH2 + categories.TECH3 ) * categories.SUPPORTFACTORY}},
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH1 * categories.LAND * categories.FACTORY }},
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, (categories.TECH2 + categories.TECH3) * categories.LAND * categories.FACTORY - categories.SUPPORTFACTORY }},
                { EBC, 'FactorySpendRatioRNG', {'Land', 0.5}, 'greater' },
                { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { -0.1, 1.3 }},
            },
        BuilderData = {
            Location = 'LocationType',
            Reclaim = {categories.STRUCTURE * categories.TECH1 * categories.LAND * categories.FACTORY},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Engineer Reclaim T1 Land Mass Stall',
        PlatoonTemplate = 'EngineerBuilderRNG',
        PlatoonAIPlan = 'ReclaimStructuresRNG',
        Priority = 1050,
        InstanceCount = 3,
        BuilderConditions = {
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.SUPPORTFACTORY}},
                { EBC, 'FactorySpendRatioRNG', {'Land', 0.7, 'greater'} },
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH1 * categories.LAND * categories.FACTORY }},
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, (categories.TECH2 + categories.TECH3) * categories.LAND * categories.FACTORY - categories.SUPPORTFACTORY }},
                { EBC, 'LessThanEconEfficiency', { 0.9, 3.0 }},
            },
        BuilderData = {
            Location = 'LocationType',
            Reclaim = {categories.STRUCTURE * categories.TECH1 * categories.LAND * categories.FACTORY},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Engineer Reclaim T2 Land',
        PlatoonTemplate = 'EngineerBuilderRNG',
        PlatoonAIPlan = 'ReclaimStructuresRNG',
        Priority = 940,
        InstanceCount = 4,
        BuilderConditions = {
                { EBC, 'FactorySpendRatioRNG', {'Land', 0.6, 'greater'} },
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 3, categories.TECH3 * categories.LAND * categories.FACTORY * categories.SUPPORTFACTORY}},
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH2 * categories.LAND * categories.FACTORY * categories.SUPPORTFACTORY }},
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH3 * categories.LAND * categories.FACTORY - categories.SUPPORTFACTORY }},
                { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { -0.1, 1.3 }},
            },
        BuilderData = {
            Location = 'LocationType',
            Reclaim = {categories.TECH2 * categories.LAND * categories.FACTORY * categories.SUPPORTFACTORY},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Engineer Reclaim T2 Land Mass Stall',
        PlatoonTemplate = 'EngineerBuilderRNG',
        PlatoonAIPlan = 'ReclaimStructuresRNG',
        Priority = 1050,
        InstanceCount = 10,
        BuilderConditions = {
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.TECH3 * categories.FACTORY * categories.LAND * categories.SUPPORTFACTORY}},
                { EBC, 'FactorySpendRatioRNG', {'Land', 0.7, 'greater'} },
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH3 * categories.LAND * categories.FACTORY - categories.SUPPORTFACTORY }},
                { EBC, 'LessThanEconEfficiency', { 0.9, 3.0 }},
            },
        BuilderData = {
            Location = 'LocationType',
            Reclaim = {categories.TECH2 * categories.LAND * categories.FACTORY * categories.SUPPORTFACTORY},
        },
        BuilderType = 'Any',
    },
}
BuilderGroup {
    BuilderGroupName = 'RNG Tech Energy Builder',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Tech T1Engineer Pgen Trend',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 1011,
        InstanceCount = 2,
        DelayEqualBuildPlattons = {'Energy', 12},
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 110 } },
            { EBC, 'FutureProofEspendRNG', { 1.5 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.1 }},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Energy' }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }}, -- Don't build after 1 T2 Pgens Exist
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.ENERGYPRODUCTION - categories.HYDROCARBON } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = true,
            Construction = {
                BuildClose = true,
                AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * categories.AIR + categories.MASSEXTRACTION,
                AvoidCategory = categories.ENERGYPRODUCTION,
                AdjacencyDistance = 50,
                maxUnits = 4,
                maxRadius = 5,
                BuildStructures = {
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Tech T1Engineer Pgen Trend Preparation',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 994,
        InstanceCount = 2,
        DelayEqualBuildPlattons = {'Energy', 12},
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 110 } },
            { EBC, 'FutureProofEspendRNG', { 1 }},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Energy' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }}, -- Don't build after 1 T2 Pgens Exist
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.ENERGYPRODUCTION}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 4, categories.ENERGYPRODUCTION - categories.HYDROCARBON } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = true,
            Construction = {
                BuildClose = true,
                AdjacencyCategory = categories.FACTORY * categories.STRUCTURE + categories.MASSEXTRACTION,
                AvoidCategory = categories.ENERGYPRODUCTION,
                AdjacencyDistance = 50,
                maxUnits = 1,
                maxRadius = 5,
                BuildStructures = {
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Tech T2 Power Engineer',
        PlatoonTemplate = 'EngineerBuilderT23RNG',
        Priority = 1000,
        InstanceCount = 2,
        DelayEqualBuildPlattons = {'Energy2', 20},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Energy2' }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3 }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) } },
            { EBC, 'FutureProofEspendRNG', { 1.3 }},
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
    },
    Builder {
        BuilderName = 'RNG Tech T3 Power Engineer',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 900,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { EBC, 'FutureProofEspendRNG', { 1.4 }},
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
    },
}
BuilderGroup {
    BuilderGroupName = 'RNG Tech Energy Assist',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Tech T1 Engineer PGEN Assist',
        PlatoonTemplate = 'T1EngineerAssistRNG',
        Priority = 1001,
        DelayEqualBuildPlattons = {'EngineerAssistPgen1', 4},
        InstanceCount = 4,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 200 } },
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'EngineerAssistPgen1' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }},
            { EBC, 'FutureProofEspendRNG', { 1.2 }},
            { EBC, 'GreaterThanEconStorageCurrentRNG', { -3, 300 } },
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH1 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.1 }},
            },
        BuilderData = {
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                AssistRange = 100,
                BeingBuiltCategories = {categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH1},
                AssistClosestUnit = true,
            },
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNG Tech T1 Engineer PGEN Assist Stall',
        PlatoonTemplate = 'T1EngineerAssistRNG',
        Priority = 1050,
        DelayEqualBuildPlattons = {'EngineerAssistPgenS', 15},
        InstanceCount = 5,
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'EngineerAssistPgenS' }},
            { MIBC, 'GreaterThanGameTimeRNG', { 90 } },
            { EBC, 'FutureProofEspendRNG', { 1.0 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.1 }},
            { EBC, 'LessThanEconStorageRatio', { 2.0, 0.8}},
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.ENERGYPRODUCTION}},
            },
        BuilderData = {
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                AssistRange = 100,
                BeingBuiltCategories = {categories.STRUCTURE * categories.ENERGYPRODUCTION},
                AssistClosestUnit = true,
            },
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNG Tech T123 Engineer Unfinished PGEN Midgame',
        PlatoonTemplate = 'T123EngineerAssistRNG',
        Priority = 1010,
        DelayEqualBuildPlattons = {'EngineerAssistPgen', 15},
        InstanceCount = 5,
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'EngineerAssistPgen' }},
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }},
            { EBC, 'FutureProofEspendRNG', { 1.0, 'greater' }},
            { EBC, 'FutureProofEspendRNG', { 2 }},
            --{ EBC, 'GreaterThanEconEfficiencyRNG', { 0.9, 0.1 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssistClosestUnit = false,
                AssisteeType = categories.STRUCTURE,
                BeingBuiltCategories = {categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3)},
                Time = 60,
            },
        }
    },
    Builder {
        BuilderName = 'RNG Tech T123 Engineer Unfinished PGEN Lategame',
        PlatoonTemplate = 'T123EngineerAssistRNG',
        Priority = 950,
        DelayEqualBuildPlattons = {'EngineerAssistPgen', 20},
        InstanceCount = 10,
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'EngineerAssistPgen' }},
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 }},
            { EBC, 'FutureProofEspendRNG', { 1.3 }},
            { EBC, 'GreaterThanEconIncomeRNG',  { 20.0, 200.0}},
            --{ EBC, 'GreaterThanEconEfficiencyRNG', { 0.9, 0.1 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssistClosestUnit = false,
                AssisteeType = categories.STRUCTURE,
                BeingBuiltCategories = {categories.STRUCTURE * categories.ENERGYPRODUCTION},
                Time = 60,
            },
        }
    },
}