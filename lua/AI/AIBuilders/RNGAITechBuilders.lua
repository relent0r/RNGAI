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
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 900,
        DelayEqualBuildPlattons = {'Factories', 5},
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            --{ EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.35, 'FACTORY'}}, -- Ratio from 0 to 1. (1=100%)
            --{ EBC, 'GreaterThanEconStorageCurrentRNG', { 105, 1050 } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { EBC, 'GreaterThanEconStorageRatio', { -0.1, 0.3 }},
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY }},
         },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            Construction = {
                Location = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    'T1LandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Tech Factory Builder Land T1',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 850,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.4, 0.70}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyRNG', { 1.0, 1.0 }},
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY }},
         },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    'T1LandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Tech Engineer Early Unfinished Factory',
        PlatoonTemplate = 'T12EngineerAssistRNG',
        Priority = 1010,
        DelayEqualBuildPlattons = {'EngineerAssistUnfinished', 1},
        InstanceCount = 2,
        BuilderConditions = {
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.FACTORY * categories.TECH1}},
                { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 1.0 }},
                { EBC, 'GreaterThanEconStorageRatio', { -0.1, 0.8 }},
            },
        BuilderData = {
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                AssistRange = 100,
                BeingBuiltCategories = {categories.STRUCTURE * categories.FACTORY * categories.TECH1},
                AssistClosestUnit = true,
            },
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNG Tech Engineer Early Unfinished T1 Air',
        PlatoonTemplate = 'T12EngineerAssistRNG',
        Priority = 1090,
        DelayEqualBuildPlattons = {'EngineerAssistUnfinished', 1},
        InstanceCount = 3,
        BuilderConditions = {
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH1}},
                { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 1.0 }},
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
        BuilderName = 'RNG Tech Factory Builder First Air T1 MainBase',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 1},
        InstanceCount = 1,
        BuilderConditions = {
            --{ EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.35, 'FACTORY'}}, -- Ratio from 0 to 1. (1=100%)
            --{ EBC, 'GreaterThanEconStorageCurrentRNG', { 105, 1050 } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR }},
         },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            Construction = {
                Location = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Tech Engineer Unfinished Structures',
        PlatoonTemplate = 'T1EngineerFinishRNG',
        Priority = 650,
        DelayEqualBuildPlattons = {'EngineerAssistUnfinished', 1},
        InstanceCount = 3,
        BuilderConditions = {
                { UCBC, 'UnfinishedUnits', { 'LocationType', categories.STRUCTURE }},
                { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 1.0 }},
            },
        BuilderData = {
            Assist = {
                AssistLocation = 'LocationType',
                BeingBuiltCategories = categories.STRUCTURE,
            },
        },
        BuilderType = 'Any',
    },
}
BuilderGroup {
    BuilderGroupName = 'RNG Tech Factory Builder Land Large',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Tech Factory Builder Land T1 MainBase Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 5},
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            --{ EBC, 'GreaterThanEconStorageRatioRNG', { 0.09, 0.40}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 6, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY }},
         },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            Construction = {
                Location = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    'T1LandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Tech Factory Builder Land T1 Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 800,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.11, 0.80, 'FACTORY'}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.9, 1.0 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 6, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY }},
         },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    'T1LandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Tech Factory Builder Land T1 Path Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 500,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 2,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 1.0 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 8, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY }},
         },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    'T1LandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Tech Engineer Early Unfinished Factory Large',
        PlatoonTemplate = 'T12EngineerAssistRNG',
        Priority = 1010,
        DelayEqualBuildPlattons = {'EngineerAssistUnfinished', 1},
        InstanceCount = 3,
        BuilderConditions = {
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.FACTORY * categories.TECH1 }},
                { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 1.0 }},
            },
        BuilderData = {
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                AssistRange = 100,
                BeingBuiltCategories = {categories.STRUCTURE * categories.FACTORY * categories.TECH1},
                AssistClosestUnit = true,
            },
        },
        BuilderType = 'Any',
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
    BuilderGroupName = 'RNG Tech Support Factory Builder Land',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Tech Factory Builder Land T2 MainBase',
        PlatoonTemplate = 'EngineerBuilderT23RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 10},
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY }},
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { UCBC, 'HaveUnitRatioRNG', { 0.4, categories.STRUCTURE * categories.LAND * categories.FACTORY * (categories.TECH2 + categories.TECH3), '<=',categories.STRUCTURE * categories.MASSEXTRACTION } },
         },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
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
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { UCBC, 'HaveUnitRatioRNG', { 0.4, categories.STRUCTURE * categories.LAND * categories.FACTORY * categories.TECH3, '<=',categories.STRUCTURE * categories.MASSEXTRACTION } },
         },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
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
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.SUPPORTFACTORY}},
                { EBC, 'GreaterThanEconEfficiencyRNG', { 0.9, 1.0 }},
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
}
BuilderGroup {
    BuilderGroupName = 'RNG Tech Land Factory Reclaimer',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Engineer Reclaim T1 Land',
        PlatoonTemplate = 'EngineerBuilderRNG',
        PlatoonAIPlan = 'ReclaimStructuresAI',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 5, (categories.TECH2 + categories.TECH3 ) * categories.SUPPORTFACTORY}},
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH1 * categories.LAND * categories.FACTORY }},
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, (categories.TECH2 + categories.TECH3) * categories.LAND * categories.FACTORY - categories.SUPPORTFACTORY }},
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
        PlatoonAIPlan = 'ReclaimStructuresAI',
        Priority = 1050,
        InstanceCount = 3,
        BuilderConditions = {
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.SUPPORTFACTORY}},
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 5, (categories.TECH2 + categories.TECH3 ) * categories.SUPPORTFACTORY}},
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
        PlatoonAIPlan = 'ReclaimStructuresAI',
        Priority = 940,
        InstanceCount = 4,
        BuilderConditions = {
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 5, categories.TECH3 * categories.LAND * categories.FACTORY * categories.SUPPORTFACTORY}},
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
        PlatoonAIPlan = 'ReclaimStructuresAI',
        Priority = 1050,
        InstanceCount = 10,
        BuilderConditions = {
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.TECH3 * categories.FACTORY * categories.LAND * categories.SUPPORTFACTORY}},
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 5, categories.TECH3 * categories.LAND * categories.FACTORY * categories.SUPPORTFACTORY}},
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
        Priority = 1000,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 140 } },
            { EBC, 'LessThanEconEfficiency', { 3, 1.5 }},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Energy' }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }}, -- Don't build after 1 T2 Pgens Exist
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = true,
            Construction = {
                BuildClose = true,
                AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
                AvoidCategory = categories.ENERGYPRODUCTION,
                AdjacencyDistance = 50,
                maxUnits = 3,
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
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3 }},
            { EBC, 'LessThanEconEfficiency', { 3, 1.4 }},
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
            { EBC, 'LessThanEconEfficiency', { 3, 1.3 }},
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
        PlatoonTemplate = 'T12EngineerAssistRNG',
        Priority = 960,
        DelayEqualBuildPlattons = {'EngineerAssistPgen', 1},
        InstanceCount = 3,
        BuilderConditions = {
            { EBC, 'LessThanEconEfficiency', { 3.0, 1.2 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.9, 0.1 }},
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.ENERGYPRODUCTION }},
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
        BuilderName = 'RNG Tech T1 Engineer PGEN Assist Stall',
        PlatoonTemplate = 'T12EngineerAssistRNG',
        Priority = 1050,
        DelayEqualBuildPlattons = {'EngineerAssistPgen', 1},
        InstanceCount = 5,
        BuilderConditions = {
            { EBC, 'LessThanEconEfficiency', { 3.0, 1.0 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.9, 0.1 }},
            { EBC, 'LessThanEconStorageRatio', { 2.0, 0.8}},
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.ENERGYPRODUCTION }},
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
        DelayEqualBuildPlattons = {'EngineerAssistPgen', 1},
        InstanceCount = 5,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }},
            { EBC, 'LessThanEconEfficiency', { 3.0, 1.3 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.9, 0.1 }},
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
    Builder {
        BuilderName = 'RNG Tech T123 Engineer Unfinished PGEN Lategame',
        PlatoonTemplate = 'T123EngineerAssistRNG',
        Priority = 950,
        DelayEqualBuildPlattons = {'EngineerAssistPgen', 1},
        InstanceCount = 10,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 }},
            { EBC, 'LessThanEconEfficiency', { 3.0, 1.3 }},
            { EBC, 'GreaterThanEconIncomeRNG',  { 20.0, 200.0}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.9, 0.1 }},
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