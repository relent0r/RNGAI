--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAIEconomicBuilders.lua
    Author  :   relentless
    Summary :
        Factory Builders
]]

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local TBC = '/lua/editor/ThreatBuildConditions.lua'
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

local ACUClosePriority = function(self, aiBrain)
    if aiBrain.EnemyIntel.ACUEnemyClose then
        return 850
    else
        return 0
    end
end

local LandThreat = function(self, aiBrain)

    if (aiBrain.BrainIntel.SelfThreat.LandNow + aiBrain.BrainIntel.SelfThreat.AllyLandThreat) < aiBrain.EnemyIntel.EnemyThreatCurrent.Land then
        return 850
    else
        return 0
    end
end

local ActiveExpansion = function(self, aiBrain, builderManager)
    --RNGLOG('LocationType is '..builderManager.LocationType)
    if aiBrain.BrainIntel.ActiveExpansion == builderManager.LocationType then
        --RNGLOG('Active Expansion is set'..builderManager.LocationType)
        --RNGLOG('Active Expansion builders are set to 900')
        return 700
    else
        --RNGLOG('Disable Air Intie Pool Builder')
        --RNGLOG('My Air Threat '..myAirThreat..'Enemy Air Threat '..enemyAirThreat)
        return 0
    end
end

local NavalAdjust = function(self, aiBrain, builderManager)
    if aiBrain.MapWaterRatio > 0.60 then
        --RNGLOG('NavalExpansionAdjust return 200')
        return 910
    else
        --RNGLOG('NavalExpansionAdjust return 750')
        return 0
    end
end

BuilderGroup {
    BuilderGroupName = 'RNGAI Factory Builder Land',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Land T1 MainBase',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1010,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            --{ EBC, 'GreaterThanEconStorageCurrentRNG', { 105, 1050 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.85 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
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
        BuilderName = 'RNG Factory Builder Land T1 MainBase Storage',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1010,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'GreaterThanEconStorageCurrentRNG', { 240, 1050 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.70, 0.50 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
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
        BuilderName = 'RNG Factory Builder Land T2 MainBase',
        PlatoonTemplate = 'EngineerBuilderT23RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.3, 1.0 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 5, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
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
        BuilderName = 'RNG Factory Builder Land T1',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 900,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 2,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 0.7 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 3, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
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
}
BuilderGroup {
    BuilderGroupName = 'RNGAI Factory Builder Unmarked Spam',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Land T1 Unmarked Spam',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.30}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.8 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 8, categories.FACTORY * categories.LAND * categories.TECH1 }},
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
}
BuilderGroup {
    BuilderGroupName = 'RNGAI Factory Builder Land Large',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Land T1 MainBase Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.9, 0.9 }},
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 6, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
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
        BuilderName = 'RNG Factory Builder Land T1 Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 800,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.11, 0.80, 'FACTORY'}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.0 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 6, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
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
        BuilderName = 'RNG Factory Builder Land T1 Path Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 950,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.85 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 6, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
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
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Factory Builder Air',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Air T1 High Pri',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1015,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            --{ EBC, 'GreaterThanEconStorageCurrentRNG', { 105, 1200 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.8 }},
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            { UCBC, 'GreaterThanFactoryCountRNG', { 1, categories.FACTORY * categories.LAND}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR }},
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.AIR * categories.TECH1 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
         },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            Construction = {
                Location = 'LocationType',
                AdjacencyCategory = categories.ENERGYPRODUCTION,
                BuildClose = false,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Air T1 Main',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 900,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'MapGreaterThan', { 256, 256 }},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.0, 1.0 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 3, categories.FACTORY * categories.AIR }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.AIR * categories.FACTORY * categories.TECH1 }},
         },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                AdjacencyCategory = categories.ENERGYPRODUCTION,
                BuildClose = false,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Air T2 MainBase',
        PlatoonTemplate = 'EngineerBuilderT23RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.2, 1.2 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
         },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
                AdjacencyCategory = categories.ENERGYPRODUCTION,
                BuildStructures = {
                    'T2SupportAirFactory',
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Factory Builder Air Expansion',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Air T1 Expansion',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 700,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.AIR * categories.TECH1 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
         },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Factory Builder Air Large',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Air T1 High Pri Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.8 }},
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'MAIN', 3, categories.FACTORY * categories.AIR * categories.TECH1 }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.STRUCTURE * categories.AIR * categories.FACTORY * categories.TECH1 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
         },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Air T1 Main Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 800,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.09, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.8 }},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.AIR * categories.FACTORY * categories.TECH1 }},
         },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Factory Builder Air Large Expansion',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Air T1 High Pri Large Expansion',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 0,
        PriorityFunction = ActiveExpansion,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.9, 0.9 }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.STRUCTURE * categories.AIR * categories.FACTORY * categories.TECH1 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
         },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Factory Builder Sea',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Sea T1 High Pri',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { UCBC, 'LessThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.NAVAL - categories.SUPPORTFACTORY }, true },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 1.0 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.NAVAL * categories.TECH1 }},
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildStructures = {
                    'T1SeaFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Sea T1 High Pri Naval',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 0,
        PriorityFunction = NavalAdjust,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 1.0 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.NAVAL * categories.TECH1 }},
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildStructures = {
                    'T1SeaFactory',
                },
            }
        }
    },
    
    Builder {
        BuilderName = 'RNG Factory Builder Sea T1 Marker',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 700,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { UCBC, 'LessThanFactoryCountRNG', { 4, categories.STRUCTURE * categories.FACTORY * categories.NAVAL }, true },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.0, 1.0 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.NAVAL * categories.TECH1 }},
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                NearMarkerType = 'Naval Area',
                LocationRadius = 90,
                Location = 'LocationType',
                BuildStructures = {
                    'T1SeaFactory',
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Factory Builder Sea Large',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Sea T1 High Pri Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { UCBC, 'LessThanFactoryCountRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.NAVAL }, true },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.8 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.NAVAL * categories.TECH1 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildStructures = {
                    'T1SeaFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Sea T1 Marker Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 700,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.08, 0.50}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.0, 1.0 }},
            { UCBC, 'LessThanFactoryCountRNG', { 12, categories.STRUCTURE * categories.FACTORY * categories.NAVAL }, true },
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.NAVAL * categories.TECH1 }},
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                NearMarkerType = 'Naval Area',
                LocationRadius = 90,
                Location = 'LocationType',
                BuildStructures = {
                    'T1SeaFactory',
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Air Staging Platform',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Air Staging 1',
        PlatoonTemplate = 'EngineerBuilderT123RNG', -- Air Staging has been moved to T1 so don't need T2 engineers now.
        Priority = 900,
        BuilderConditions = {
            -- When do we want to build this ?
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.AIRSTAGINGPLATFORM }},
            -- Do we need additional conditions to build it ?
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 5, categories.STRUCTURE * categories.ENERGYPRODUCTION } },
            -- Have we the eco to build it ?
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.70}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconTrendOverTimeRNG', { 0.2, 4.0 }}, -- relative income
            -- Don't build it if...
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.AIRSTAGINGPLATFORM }},
            { MIBC, 'GreaterThanGameTimeRNG', { 480 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 1,
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T2AirStagingPlatform',
                },
                Location = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Land Upgrade Builders',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Land Factory Upgrade HQ',
        PlatoonTemplate = 'T1LandFactoryUpgrade',
        Priority = 800,
        InstanceCount = 1,
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 450, true } },
                { UCBC, 'LessThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY } },
                { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 2.5, 20.0 }},
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.3}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1 }},
                { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.025, 1.025 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Land Factory Upgrade HQ Enemy',
        PlatoonTemplate = 'T1LandFactoryUpgrade',
        Priority = 800,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'LessThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY } },
                { UCBC, 'EnemyLandPhaseRNG', { 2 }},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1 }},
                { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.06, 0.60}},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Land Factory Upgrade HQ Excess',
        PlatoonTemplate = 'T1LandFactoryUpgrade',
        Priority = 800,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'LessThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY } },
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1 }},
                { EBC, 'GreaterThanEconStorageCurrentRNG', { 1600, 2000 } },
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Land Factory Upgrade Support',
        PlatoonTemplate = 'T1LandFactoryUpgrade',
        Priority = 750,
        InstanceCount = 1,
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9501', 'zab9501', 'zrb9501', 'zsb9501', 'znb9501' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
                { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * ( categories.TECH2 + categories.TECH3 ) - categories.SUPPORTFACTORY } },
                { UCBC, 'LessThanFactoryCountRNG', { 10, categories.STRUCTURE * categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) * categories.SUPPORTFACTORY } },
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1 }},
                --{ EBC, 'GreaterThanEconTrendOverTimeRNG', { 0.0, 0.0 } },
                { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.025, 1.025 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Land Factory Upgrade Support Excess',
        PlatoonTemplate = 'T1LandFactoryUpgrade',
        Priority = 750,
        InstanceCount = 1,
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9501', 'zab9501', 'zrb9501', 'zsb9501', 'znb9501' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
                { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * ( categories.TECH2 + categories.TECH3 ) - categories.SUPPORTFACTORY } },
                { UCBC, 'LessThanFactoryCountRNG', { 10, categories.STRUCTURE * categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) * categories.SUPPORTFACTORY } },
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1 }},
                { EBC, 'GreaterThanEconStorageCurrentRNG', { 1300, 3990 } },
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Land Factory Upgrade HQ',
        PlatoonTemplate = 'T2LandFactoryUpgrade',
        Priority = 850,
        InstanceCount = 1,
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 960 } },
                { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 5.0, 100.0}},
                { UCBC, 'LessThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY } },
                { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 - categories.SUPPORTFACTORY } },
                { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.0, 1.0 }},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Land Factory Upgrade HQ Enemy',
        PlatoonTemplate = 'T2LandFactoryUpgrade',
        Priority = 850,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'LessThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY } },
                { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 - categories.SUPPORTFACTORY } },
                { UCBC, 'EnemyLandPhaseRNG', { 3 }},
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.3}},
                { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Land Factory Upgrade HQ Excess',
        PlatoonTemplate = 'T2LandFactoryUpgrade',
        Priority = 800,
        InstanceCount = 1,
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 600 } },
                { EBC, 'GreaterThanEconStorageCurrentRNG', { 2400, 9000 } },
                { UCBC, 'LessThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY } },
                { UCBC, 'GreaterThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 } },
                { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 }},
            },
        BuilderType = 'Any',
    },
    Builder { 
        BuilderName = 'RNGAI T2 Land Factory Upgrade Support UEF',
        PlatoonTemplate = 'T2LandSupFactoryUpgrade1',
        Priority = 760,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9601', 'zab9601', 'zrb9601', 'zsb9601', 'znb9601' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.UEF * categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.UEF * categories.SUPPORTFACTORY * categories.LAND * categories.TECH2 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH2 }},
        },
        BuilderType = 'Any',
    },
    Builder { 
        BuilderName = 'RNGAI T2 Land Factory Upgrade Support AEON',
        PlatoonTemplate = 'T2LandSupFactoryUpgrade2',
        Priority = 760,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9601', 'zab9601', 'zrb9601', 'zsb9601', 'znb9601' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.AEON * categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.AEON * categories.SUPPORTFACTORY * categories.LAND * categories.TECH2 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH2 }},
        },
        BuilderType = 'Any',
    },
    Builder { 
        BuilderName = 'RNGAI T2 Land Factory Upgrade Support Cybran',
        PlatoonTemplate = 'T2LandSupFactoryUpgrade3',
        Priority = 760,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9601', 'zab9601', 'zrb9601', 'zsb9601', 'znb9601' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.CYBRAN * categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.CYBRAN * categories.SUPPORTFACTORY * categories.LAND * categories.TECH2 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH2 }},
        },
        BuilderType = 'Any',
    },
    Builder { BuilderName = 'RNGAI T2 Land Factory Upgrade Support Sera',
        PlatoonTemplate = 'T2LandSupFactoryUpgrade4',
        Priority = 760,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9601', 'zab9601', 'zrb9601', 'zsb9601', 'znb9601' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.SERAPHIM * categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.SERAPHIM * categories.SUPPORTFACTORY * categories.LAND * categories.TECH2 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH2 }},
        },
        BuilderType = 'Any',
    },
}
BuilderGroup {
    BuilderGroupName = 'RNGAI Air Upgrade Builders',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Air Factory Upgrade HQ',
        PlatoonTemplate = 'T1AirFactoryUpgrade',
        Priority = 900,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY } },
                { UCBC, 'LessThanFactoryCountRNG', { 1, categories.FACTORY * categories.AIR * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH1 }},
                { UCBC, 'GreaterThanFactoryCountRNG', { 1, categories.FACTORY * categories.AIR}},
                { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.025, 1.025 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Air Factory Upgrade HQ CloseACU',
        PlatoonTemplate = 'T1AirFactoryUpgrade',
        PriorityFunction = ACUClosePriority,
        Priority = 0,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'LessThanFactoryCountRNG', { 1, categories.FACTORY * categories.AIR * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH1 }},
                { UCBC, 'GreaterThanFactoryCountRNG', { 1, categories.FACTORY * categories.AIR}},
                { EBC, 'GreaterThanEconTrendOverTimeRNG', { 0.0, 0.0 } },
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Air Factory Upgrade Support',
        PlatoonTemplate = 'T1AirFactoryUpgrade',
        Priority = 750,
        InstanceCount = 1,
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9502', 'zab9502', 'zrb9502', 'zsb9502', 'znb9502' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
                { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.AIR * ( categories.TECH2 + categories.TECH3 ) - categories.SUPPORTFACTORY } },
                { UCBC, 'LessThanFactoryCountRNG', { 8, categories.FACTORY * categories.AIR * (categories.TECH2 + categories.TECH3) }},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH1 }},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3)}},
                { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.025, 1.025 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Factory Upgrade HQ',
        PlatoonTemplate = 'T2AirFactoryUpgrade',
        Priority = 900,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY} },
                { UCBC, 'LessThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY }},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.TECH2 * categories.AIR }},
                { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH2 - categories.SUPPORTFACTORY } },
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.80}},
                { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.0, 1.0 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Factory Upgrade Support UEF',
        PlatoonTemplate = 'T2AirSupFactoryUpgrade1',
        Priority = 760,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9602', 'zab9602', 'zrb9602', 'zsb9602', 'znb9602' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.UEF * categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.UEF * categories.AIR * categories.SUPPORTFACTORY * categories.TECH2 }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.1 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.3}},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.TECH2 * categories.AIR }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Factory Upgrade Support Aeon',
        PlatoonTemplate = 'T2AirSupFactoryUpgrade2',
        Priority = 760,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9602', 'zab9602', 'zrb9602', 'zsb9602', 'znb9602' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.AEON * categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.AEON * categories.AIR * categories.SUPPORTFACTORY * categories.TECH2 }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.1 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.3}},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.TECH2 * categories.AIR }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Factory Upgrade Support Cybran',
        PlatoonTemplate = 'T2AirSupFactoryUpgrade3',
        Priority = 760,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9602', 'zab9602', 'zrb9602', 'zsb9602', 'znb9602' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.CYBRAN * categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.CYBRAN * categories.AIR * categories.SUPPORTFACTORY * categories.TECH2 }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.1 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.3}},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.TECH2 * categories.AIR }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Factory Upgrade Support Seraphim',
        PlatoonTemplate = 'T2AirSupFactoryUpgrade4',
        Priority = 760,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9602', 'zab9602', 'zrb9602', 'zsb9602', 'znb9602' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.SERAPHIM * categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.SERAPHIM * categories.AIR * categories.SUPPORTFACTORY * categories.TECH2 }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.1 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.3}},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.TECH2 * categories.AIR }},
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Air Upgrade Builders Expansion',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Air Factory Upgrade HQ Expansion',
        PlatoonTemplate = 'T1AirFactoryUpgrade',
        Priority = 700,
        InstanceCount = 1,
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 450 } },
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH1 }},
                { UCBC, 'LessThanFactoryCountRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.AIR * (categories.TECH3 + categories.TECH3) - categories.SUPPORTFACTORY }},
                { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.AIR * (categories.TECH3 + categories.TECH3) - categories.SUPPORTFACTORY } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3)}},
                { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Air Factory Upgrade Support Expansion',
        PlatoonTemplate = 'T1AirFactoryUpgrade',
        Priority = 600,
        InstanceCount = 1,
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9502', 'zab9502', 'zrb9502', 'zsb9502', 'znb9502' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 420 } },
                { UCBC, 'LessThanFactoryCountRNG', { 5, categories.FACTORY * categories.AIR * (categories.TECH2 + categories.TECH3)}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH1 }},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH2}},
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.80}},
                { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Factory Upgrade HQ Expansion',
        PlatoonTemplate = 'T2AirFactoryUpgrade',
        Priority = 700,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'LessThanFactoryCountRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY }},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.TECH2 * categories.AIR }},
                { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * categories.TECH3}},
                { MIBC, 'GreaterThanGameTimeRNG', { 900 } },
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.80}},
                { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Factory Upgrade Support UEF Expansion',
        PlatoonTemplate = 'T2AirSupFactoryUpgrade1',
        Priority = 650,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9602', 'zab9602', 'zrb9602', 'zsb9602', 'znb9602' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.UEF * categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.UEF * categories.AIR * categories.SUPPORTFACTORY * categories.TECH2 }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.3}},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.TECH2 * categories.AIR }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Factory Upgrade Support Aeon Expansion',
        PlatoonTemplate = 'T2AirSupFactoryUpgrade2',
        Priority = 650,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9602', 'zab9602', 'zrb9602', 'zsb9602', 'znb9602' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.AEON * categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.AEON * categories.AIR * categories.SUPPORTFACTORY * categories.TECH2 }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.3}},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.TECH2 * categories.AIR }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Factory Upgrade Support Cybran Expansion',
        PlatoonTemplate = 'T2AirSupFactoryUpgrade3',
        Priority = 650,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9602', 'zab9602', 'zrb9602', 'zsb9602', 'znb9602' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.CYBRAN * categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.CYBRAN * categories.AIR * categories.SUPPORTFACTORY * categories.TECH2 }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.3}},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.TECH2 * categories.AIR }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Factory Upgrade Support Seraphim Expansion',
        PlatoonTemplate = 'T2AirSupFactoryUpgrade4',
        Priority = 650,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9602', 'zab9602', 'zrb9602', 'zsb9602', 'znb9602' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.SERAPHIM * categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.SERAPHIM * categories.AIR * categories.SUPPORTFACTORY * categories.TECH2 }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.3}},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.TECH2 * categories.AIR }},
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Sea Upgrade Builders',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Sea Factory Upgrade HQ',
        PlatoonTemplate = 'T1SeaFactoryUpgrade',
        Priority = 800,
        InstanceCount = 1,
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 480 } },
                { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 5.5, 50.0}},
                { UCBC, 'LessThanFactoryCountRNG', { 1, categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3)}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH1 }},
                { UCBC, 'GreaterThanFactoryCountRNG', { 1, categories.FACTORY * categories.NAVAL}, true},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3)}},
                { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Sea Factory Upgrade Support',
        PlatoonTemplate = 'T1SeaFactoryUpgrade',
        Priority = 750,
        InstanceCount = 1,
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9503', 'zab9503', 'zrb9503', 'zsb9503', 'znb9503' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
                { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.FACTORY * categories.NAVAL * categories.TECH2 - categories.SUPPORTFACTORY}, true},
                { UCBC, 'LessThanFactoryCountRNG', { 7, categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3)}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH1 }},
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.5}},
                { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Sea Factory Upgrade HQ',
        PlatoonTemplate = 'T2SeaFactoryUpgrade',
        Priority = 810,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 1500 } },
            { UCBC, 'CheckBuildPlattonDelay', { 'FactoryUpgrade' }},
            { UCBC, 'LessThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH3 - categories.SUPPORTFACTORY } },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH2 - categories.SUPPORTFACTORY }, true},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.5}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH2 }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Sea Factory Upgrade Support UEF',
        PlatoonTemplate = 'T2SeaSupFactoryUpgrade1',
        Priority = 760,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9603', 'zab9603', 'zrb9603', 'zsb9603', 'znb9603' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.UEF * categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH3 - categories.SUPPORTFACTORY}, true },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.UEF * categories.SUPPORTFACTORY * categories.NAVAL * categories.TECH2 }, true },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.8}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH2 }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Sea Factory Upgrade Support Aeon',
        PlatoonTemplate = 'T2SeaSupFactoryUpgrade2',
        Priority = 760,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9603', 'zab9603', 'zrb9603', 'zsb9603', 'znb9603' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.AEON * categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH3 - categories.SUPPORTFACTORY}, true },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.AEON * categories.SUPPORTFACTORY * categories.NAVAL * categories.TECH2 }, true },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.8}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH2 }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Sea Factory Upgrade Support Cybran',
        PlatoonTemplate = 'T2SeaSupFactoryUpgrade3',
        Priority = 760,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9603', 'zab9603', 'zrb9603', 'zsb9603', 'znb9603' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.CYBRAN * categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH3 - categories.SUPPORTFACTORY}, true },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.CYBRAN * categories.SUPPORTFACTORY * categories.NAVAL * categories.TECH2 }, true },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.8}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH2 }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Sea Factory Upgrade Support Sera',
        PlatoonTemplate = 'T2SeaSupFactoryUpgrade4',
        Priority = 760,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9603', 'zab9603', 'zrb9603', 'zsb9603', 'znb9603' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.SERAPHIM * categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH3 - categories.SUPPORTFACTORY}, true },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.SERAPHIM * categories.SUPPORTFACTORY * categories.NAVAL * categories.TECH2 }, true },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.8}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH2 }},
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Land Upgrade Builders Expansions',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Land Factory Upgrade HQ Expansions',
        PlatoonTemplate = 'T1LandFactoryUpgrade',
        Priority = 800,
        InstanceCount = 1,
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 450 } },
                { UCBC, 'LessThanFactoryCountRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY } },
                { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY }},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1 }},
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.80}},
                { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Land Factory Upgrade HQ Excess Expansions',
        PlatoonTemplate = 'T1LandFactoryUpgrade',
        Priority = 800,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'LessThanFactoryCountRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY } },
                { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY }},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1 }},
                { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.30, 0.80}},
                { EBC, 'GreaterThanEconStorageCurrentRNG', { 1200, 4000 } },
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Land Factory Upgrade Support Expansions',
        PlatoonTemplate = 'T1LandFactoryUpgrade',
        Priority = 650,
        InstanceCount = 1,
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9501', 'zab9501', 'zrb9501', 'zsb9501', 'znb9501' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 450 } },
                { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * ( categories.TECH2 + categories.TECH3 ) - categories.SUPPORTFACTORY } },
                { UCBC, 'LessThanFactoryCountRNG', { 10, categories.STRUCTURE * categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) * categories.SUPPORTFACTORY } },
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1 }},
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.50}},
                { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Land Factory Upgrade HQ Expansions',
        PlatoonTemplate = 'T2LandFactoryUpgrade',
        Priority = 850,
        InstanceCount = 1,
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 1080 } },
                { UCBC, 'LessThanFactoryCountRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY } },
                { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 - categories.SUPPORTFACTORY } },
                { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3}},
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.50}},
                { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Land Factory Upgrade HQ Excess Expansions',
        PlatoonTemplate = 'T2LandFactoryUpgrade',
        Priority = 800,
        InstanceCount = 1,
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 720 } },
                { EBC, 'GreaterThanEconStorageCurrentRNG', { 1200, 8000 } },
                { UCBC, 'LessThanFactoryCountRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY } },
                { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 - categories.SUPPORTFACTORY } },
                { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY }},
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.30, 0.80}},
                { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 }},
            },
        BuilderType = 'Any',
    },
    Builder { 
        BuilderName = 'RNGAI T2 Land Factory Upgrade Support UEF Expansions',
        PlatoonTemplate = 'T2LandSupFactoryUpgrade1',
        Priority = 700,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9601', 'zab9601', 'zrb9601', 'zsb9601', 'znb9601' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.UEF * categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.UEF * categories.SUPPORTFACTORY * categories.LAND * categories.TECH2 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.50}},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH2 }},
        },
        BuilderType = 'Any',
    },
    Builder { 
        BuilderName = 'RNGAI T2 Land Factory Upgrade Support AEON Expansions',
        PlatoonTemplate = 'T2LandSupFactoryUpgrade2',
        Priority = 700,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9601', 'zab9601', 'zrb9601', 'zsb9601', 'znb9601' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.AEON * categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.AEON * categories.SUPPORTFACTORY * categories.LAND * categories.TECH2 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.50}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH2 }},
        },
        BuilderType = 'Any',
    },
    Builder { 
        BuilderName = 'RNGAI T2 Land Factory Upgrade Support Cybran Expansions',
        PlatoonTemplate = 'T2LandSupFactoryUpgrade3',
        Priority = 700,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9601', 'zab9601', 'zrb9601', 'zsb9601', 'znb9601' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.CYBRAN * categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.CYBRAN * categories.SUPPORTFACTORY * categories.LAND * categories.TECH2 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.50}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH2 }},
        },
        BuilderType = 'Any',
    },
    Builder { BuilderName = 'RNGAI T2 Land Factory Upgrade Support Sera Expansions',
        PlatoonTemplate = 'T2LandSupFactoryUpgrade4',
        Priority = 700,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9601', 'zab9601', 'zrb9601', 'zsb9601', 'znb9601' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.SERAPHIM * categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.SERAPHIM * categories.SUPPORTFACTORY * categories.LAND * categories.TECH2 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.50}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH2 }},
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Factory Builder Land Large Expansion',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Land T1 MainBase Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.60}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * categories.TECH2 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * categories.TECH1 }},
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
        BuilderName = 'RNG Factory Builder Land T1 Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 800,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 4, categories.FACTORY * categories.LAND * categories.TECH2 }},
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
}
BuilderGroup {
    BuilderGroupName = 'RNGAI T1 Upgrade Builders Expansion',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Land Factory Upgrade Expansion',
        PlatoonTemplate = 'T1LandFactoryUpgrade',
        Priority = 200,
        InstanceCount = 1,
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9501', 'zab9501', 'zrb9501', 'zsb9501', 'znb9501' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 420 } },
                { UCBC, 'LessThanFactoryCountRNG', { 6, categories.FACTORY * (categories.TECH2 + categories.TECH3)}},
                { UCBC, 'GreaterThanFactoryCountRNG', { 2, categories.FACTORY * categories.TECH2 }},
                { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * (categories.TECH2 + categories.TECH3) } },
                { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, categories.FACTORY * (categories.TECH2 + categories.TECH3) } },
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.80}},
                { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Land Factory Upgrade Support Expansions Active',
        PlatoonTemplate = 'T1LandFactoryUpgrade',
        Priority = 0,
        PriorityFunction = ActiveExpansion,
        InstanceCount = 1,
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9501', 'zab9501', 'zrb9501', 'zsb9501', 'znb9501' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 450 } },
                { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * ( categories.TECH2 + categories.TECH3 ) - categories.SUPPORTFACTORY } },
                { UCBC, 'LessThanFactoryCountRNG', { 10, categories.STRUCTURE * categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) * categories.SUPPORTFACTORY } },
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1 }},
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50}},
                { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Factory Builder Land Expansion',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Land T1 Expansion',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        PriorityFunction = ActiveExpansion,
        Priority = 0,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.08, 0.35, 'FACTORY'}}, -- Ratio from 0 to 1. (1=100%)
            --{ EBC, 'GreaterThanEconStorageCurrentRNG', { 105, 1050 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND }},
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
        BuilderName = 'RNG Factory Builder Land T1 Island Expansion',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { TBC, 'ThreatPresentInGraphRNG', {'LocationType', 'StructuresNotMex'} },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 4, categories.FACTORY * categories.LAND }},
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

}

BuilderGroup {
    BuilderGroupName = 'RNGAI Gate Builders',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Gate Builder',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 800,
        BuilderConditions = {
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Gate' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.80 } },             -- Ratio from 0 to 1. (1=100%)
            -- Don't build it if...
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                Location = 'LocationType',
                AdjacencyCategory = categories.ENERGYPRODUCTION,
                BuildStructures = {
                    'T3QuantumGate',
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGEXP Factory Builder Land',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGEXP Factory Builder Land T1 High Pri',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            --{ EBC, 'GreaterThanEconStorageCurrentRNG', { 105, 1200 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.LAND * categories.TECH1 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
         },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    'T1LandFactory',
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGEXP Factory Builder Air',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGEXP Factory Builder Air T1 High Pri',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            --{ EBC, 'GreaterThanEconStorageCurrentRNG', { 105, 1200 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { UCBC, 'GreaterThanFactoryCountRNG', { 1, categories.FACTORY * categories.LAND}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.AIR }},
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.AIR * categories.TECH1 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
         },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGEXP Factory Builder Air T1 Main',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 900,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.AIR * categories.FACTORY * categories.TECH1 }},
         },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGEXP Air Upgrade Builders',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGEXP T1 Air Factory Upgrade HQ',
        PlatoonTemplate = 'T1AirFactoryUpgrade',
        Priority = 900,
        InstanceCount = 1,
        BuilderConditions = {
                { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 2.3, 20.0}},
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.3}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 10, categories.ENERGYPRODUCTION * (categories.TECH1 + categories.TECH2 + categories.TECH3)}},
                { UCBC, 'LessThanFactoryCountRNG', { 1, categories.FACTORY * categories.AIR * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH1 }},
                { UCBC, 'GreaterThanFactoryCountRNG', { 1, categories.FACTORY * categories.AIR}},
                { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGEXP T1 Air Factory Upgrade HQ CloseACU',
        PlatoonTemplate = 'T1AirFactoryUpgrade',
        PriorityFunction = ACUClosePriority,
        Priority = 0,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'LessThanFactoryCountRNG', { 1, categories.FACTORY * categories.AIR * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH1 }},
                { UCBC, 'GreaterThanFactoryCountRNG', { 1, categories.FACTORY * categories.AIR}},
                { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGEXP T1 Air Factory Upgrade Support',
        PlatoonTemplate = 'T1AirFactoryUpgrade',
        Priority = 700,
        InstanceCount = 1,
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9502', 'zab9502', 'zrb9502', 'zsb9502', 'znb9502' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 420 } },
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH1 }},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH2}},
                { UCBC, 'GreaterThanFactoryCountRNG', { 1, categories.FACTORY * categories.AIR * categories.TECH1}},
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.80}},
                { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGEXP T2 Air Factory Upgrade HQ',
        PlatoonTemplate = 'T2AirFactoryUpgrade',
        Priority = 900,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * categories.TECH2}},
                { UCBC, 'LessThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY }},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.TECH2 * categories.AIR }},
                { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH2 - categories.SUPPORTFACTORY } },
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.3}},
                { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGEXP T2 Air Factory Upgrade Support UEF',
        PlatoonTemplate = 'T2AirSupFactoryUpgrade1',
        Priority = 750,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9602', 'zab9602', 'zrb9602', 'zsb9602', 'znb9602' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.UEF * categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.UEF * categories.AIR * categories.SUPPORTFACTORY * categories.TECH2 }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.3}},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.TECH2 * categories.AIR }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGEXP T2 Air Factory Upgrade Support Aeon',
        PlatoonTemplate = 'T2AirSupFactoryUpgrade2',
        Priority = 750,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9602', 'zab9602', 'zrb9602', 'zsb9602', 'znb9602' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.AEON * categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.AEON * categories.AIR * categories.SUPPORTFACTORY * categories.TECH2 }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.3}},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.TECH2 * categories.AIR }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGEXP T2 Air Factory Upgrade Support Cybran',
        PlatoonTemplate = 'T2AirSupFactoryUpgrade3',
        Priority = 750,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9602', 'zab9602', 'zrb9602', 'zsb9602', 'znb9602' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.CYBRAN * categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.CYBRAN * categories.AIR * categories.SUPPORTFACTORY * categories.TECH2 }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.3}},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.TECH2 * categories.AIR }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGEXP T2 Air Factory Upgrade Support Seraphim',
        PlatoonTemplate = 'T2AirSupFactoryUpgrade4',
        Priority = 750,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9602', 'zab9602', 'zrb9602', 'zsb9602', 'znb9602' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.SERAPHIM * categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.SERAPHIM * categories.AIR * categories.SUPPORTFACTORY * categories.TECH2 }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.3}},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.TECH2 * categories.AIR }},
        },
        BuilderType = 'Any',
    },
}