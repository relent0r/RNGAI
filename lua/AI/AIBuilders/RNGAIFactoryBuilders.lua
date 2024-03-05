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

local AirDefenseScramble = function(self, aiBrain, builderManager, builderData)
    local myAirThreat = aiBrain.BrainIntel.SelfThreat.AntiAirNow
    local enemyAirThreat = aiBrain.EnemyIntel.EnemyThreatCurrent.AntiAir
    local enemyCount = 1
    if aiBrain.EnemyIntel.EnemyCount > 0 then
        enemyCount = aiBrain.EnemyIntel.EnemyCount
    end
    if myAirThreat * 1.3 < (enemyAirThreat / enemyCount) then
        return 1015
    else
        return 0
    end
end

local ActiveExpansion = function(self, aiBrain, builderManager)
    --RNGLOG('LocationType is '..builderManager.LocationType)
    if aiBrain.BrainIntel.ActiveExpansion == builderManager.LocationType then
        --RNGLOG('Active Expansion is set'..builderManager.LocationType)
        --RNGLOG('Active Expansion builders are set to 900')
        return 900
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
        BuilderName = 'RNG Factory Builder Land T1 Primary',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1050,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.75 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * categories.TECH1 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    'T1LandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Land T1 MainBase',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1010,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'ForcePathLimitRNG', {'LocationType', categories.FACTORY * categories.LAND, 'LAND', 2}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.80 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { MIBC, 'AirPlayerCheck', {'LocationType', 3, categories.FACTORY * categories.LAND }},
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
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
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'GreaterThanEconStorageCurrentRNG', { 240, 1050 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.70, 0.85 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { MIBC, 'AirPlayerCheck', {'LocationType', 3, categories.FACTORY * categories.LAND } },
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
            --{ UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
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
        Priority = 1015,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.85 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { MIBC, 'AirPlayerCheck', {'LocationType', 3, categories.FACTORY * categories.LAND }},
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 4, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * categories.TECH3 }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                AdjacencyPriority = {categories.ENERGYPRODUCTION},
                BuildStructures = {
                    'T2SupportLandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Land T3 MainBase',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 1020,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.90 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { MIBC, 'AirPlayerCheck', {'LocationType', 3, categories.FACTORY * categories.LAND }},
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 4, categories.FACTORY * categories.LAND * categories.TECH3 }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                AdjacencyPriority = {categories.ENERGYPRODUCTION},
                BuildStructures = {
                    'T3SupportLandFactory',
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
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 0.95 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { MIBC, 'AirPlayerCheck', {'LocationType', 3, categories.FACTORY * categories.LAND }},
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
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
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.30}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.8 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 8, categories.FACTORY * categories.LAND * categories.TECH1 }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
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
        BuilderName = 'RNG Factory Builder Land T1 Primary Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1050,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.75 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * categories.TECH1 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    'T1LandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Land T1 MainBase Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'ForcePathLimitRNG', {'LocationType', categories.FACTORY * categories.LAND, 'LAND', 2}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.9, 0.9 }},
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { MIBC, 'AirPlayerCheck', {'LocationType', 3, categories.FACTORY * categories.LAND }},
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
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
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.80, 'FACTORY'}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.0 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { MIBC, 'AirPlayerCheck', {'LocationType', 3, categories.FACTORY * categories.LAND }},
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
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
        Priority = 1010,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.30, 'FACTORY'}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.80 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { MIBC, 'AirPlayerCheck', {'LocationType', 3, categories.FACTORY * categories.LAND }},
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    'T1LandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Land T2 MainBase Large',
        PlatoonTemplate = 'EngineerBuilderT23RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.0 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { MIBC, 'AirPlayerCheck', {'LocationType', 3, categories.FACTORY * categories.LAND }},
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 4, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * categories.TECH3 }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                AdjacencyPriority = {categories.ENERGYPRODUCTION},
                BuildStructures = {
                    'T2SupportLandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Land T3 MainBase Large',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.0 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { MIBC, 'AirPlayerCheck', {'LocationType', 3, categories.FACTORY * categories.LAND }},
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 4, categories.FACTORY * categories.LAND * categories.TECH3 }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                AdjacencyPriority = {categories.ENERGYPRODUCTION},
                BuildStructures = {
                    'T3SupportLandFactory',
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Factory Builder Air',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Air T1 Primary',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1050,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.80 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * categories.TECH1 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Air T1 Main',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1010,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'MapGreaterThan', { 256, 256 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.1 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 3, categories.FACTORY * categories.AIR }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.AIR * categories.FACTORY }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                AdjacencyPriority = {categories.ENERGYPRODUCTION},
                BuildClose = false,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Air T1 Main Response',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 0,
        PriorityFunction = AirDefenseScramble,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.95 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 3, categories.FACTORY * categories.AIR }},
            { UCBC, 'MinimumFactoryCheckRNG', { 'LocationType', 'Air'}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.AIR * (categories.TECH2 + categories.TECH3) }},
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.AIR * categories.FACTORY }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                AdjacencyPriority = {categories.ENERGYPRODUCTION},
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
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.2 }},
            { UCBC, 'MinimumFactoryCheckRNG', { 'LocationType', 'Air'}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY }},
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                AdjacencyPriority = {categories.ENERGYPRODUCTION},
                BuildStructures = {
                    'T2SupportAirFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Air T3 MainBase',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.2 }},
            { UCBC, 'MinimumFactoryCheckRNG', { 'LocationType', 'Air'}},
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                AdjacencyPriority = {categories.ENERGYPRODUCTION},
                BuildStructures = {
                    'T3SupportAirFactory',
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
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.AIR }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
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
        BuilderName = 'RNG Factory Builder Air T1 Primary Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1050,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.80 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * categories.TECH1 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Air T1 High Pri Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.85 }},
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'MAIN', 3, categories.FACTORY * categories.AIR }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.STRUCTURE * categories.AIR * categories.FACTORY }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
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
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.09, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.05 }},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * categories.TECH3 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.AIR * categories.FACTORY }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Air T2 MainBase Large',
        PlatoonTemplate = 'EngineerBuilderT23RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.1 }},
            { UCBC, 'MinimumFactoryCheckRNG', { 'LocationType', 'Air'}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR *  categories.TECH3 - categories.SUPPORTFACTORY }},
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                AdjacencyPriority = {categories.ENERGYPRODUCTION},
                BuildStructures = {
                    'T2SupportAirFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Air T3 MainBase Large',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.2 }},
            { UCBC, 'MinimumFactoryCheckRNG', { 'LocationType', 'Air'}},
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                AdjacencyPriority = {categories.ENERGYPRODUCTION},
                BuildStructures = {
                    'T3SupportAirFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Air T1 Main Response Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 0,
        PriorityFunction = AirDefenseScramble,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.85 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 4, categories.FACTORY * categories.AIR }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.AIR * (categories.TECH2 + categories.TECH3) }},
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.AIR * categories.FACTORY }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                AdjacencyPriority = {categories.ENERGYPRODUCTION},
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
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.9, 1.05 }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.STRUCTURE * categories.AIR * categories.FACTORY * categories.TECH1 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
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
        BuilderName = 'RNG Factory Builder Sea T1 Primary',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1050,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.85 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.NAVAL * categories.TECH1 }},
            { UCBC, 'LessThanFactoryCountRNG', { 1, categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY, true }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    'T1SeaFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Sea T1 High Pri',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'LessThanFactoryCountRNG', { 3, categories.STRUCTURE * categories.FACTORY * categories.NAVAL, true }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.85 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.NAVAL * categories.TECH1 }},
            { UCBC, 'LessThanFactoryCountRNG', { 1, categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY, true }},
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
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
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.90, 1.0 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.NAVAL * categories.TECH1 }},
            { UCBC, 'LessThanFactoryCountRNG', { 1, categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3), true }},
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildStructures = {
                    'T1SeaFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Sea T2 High Pri Naval',
        PlatoonTemplate = 'EngineerBuilderT23RNG',
        Priority = 0,
        PriorityFunction = NavalAdjust,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.05 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 3, categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.NAVAL * categories.TECH3 }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildStructures = {
                    'T2SupportSeaFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Sea T3 High Pri Naval',
        PlatoonTemplate = 'EngineerBuilderT23RNG',
        Priority = 0,
        PriorityFunction = NavalAdjust,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.05 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH3 - categories.SUPPORTFACTORY } },
            { UCBC, 'LessThanFactoryCountRNG', { 3, categories.FACTORY * categories.NAVAL * categories.TECH3, true }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildStructures = {
                    'T3SupportSeaFactory',
                },
            }
        }
    },

    Builder {
        BuilderName = 'RNG Factory Builder Sea T2 High Pri Naval',
        PlatoonTemplate = 'EngineerBuilderT23RNG',
        Priority = 0,
        PriorityFunction = NavalAdjust,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.05 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 3, categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.NAVAL * categories.TECH3 }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildStructures = {
                    'T2SupportSeaFactory',
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
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.85}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.0, 1.0 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.NAVAL * categories.TECH1 }},
            { UCBC, 'LessThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3), true } },
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                NearMarkerType = 'Naval Area',
                LocationRadius = 90,
                LocationType = 'LocationType',
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
        BuilderName = 'RNG Factory Builder Sea T1 Primary Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1050,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.85 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.NAVAL * categories.TECH1 }},
            { UCBC, 'LessThanFactoryCountRNG', { 1, categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY, true }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    'T1SeaFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Sea T1 High Pri Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'LessThanFactoryCountRNG', { 3, categories.STRUCTURE * categories.FACTORY * categories.NAVAL, true } },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.85 }},
            { UCBC, 'LessThanFactoryCountRNG', { 1, categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY, true }},
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.NAVAL * categories.TECH1 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildStructures = {
                    'T1SeaFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Sea T1 Marker Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 0,
        PriorityFunction = NavalAdjust,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            --{ EBC, 'GreaterThanEconStorageRatioRNG', { 0.08, 0.50}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.90, 1.0 }},
            { UCBC, 'LessThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3), true } },
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.NAVAL * categories.TECH1 }},
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },

        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                NearMarkerType = 'Naval Area',
                LocationRadius = 90,
                LocationType = 'LocationType',
                BuildStructures = {
                    'T1SeaFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Sea T1 Marker Large Excess',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 650,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            --{ EBC, 'GreaterThanEconStorageRatioRNG', { 0.08, 0.50}}, -- Ratio from 0 to 1. (1=100%)
            { UCBC, 'LessThanFactoryCountRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3), true }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.2 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.NAVAL * categories.TECH1 }},
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },

        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                NearMarkerType = 'Naval Area',
                LocationRadius = 90,
                LocationType = 'LocationType',
                BuildStructures = {
                    'T1SeaFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Sea T2 High Pri Naval Large',
        PlatoonTemplate = 'EngineerBuilderT23RNG',
        Priority = 0,
        PriorityFunction = NavalAdjust,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.05 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 3, categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.NAVAL * categories.TECH3 }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildStructures = {
                    'T2SupportSeaFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Sea T3 High Pri Naval Large',
        PlatoonTemplate = 'EngineerBuilderT23RNG',
        Priority = 0,
        PriorityFunction = NavalAdjust,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.05 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH3 - categories.SUPPORTFACTORY } },
            { UCBC, 'LessThanFactoryCountRNG', { 3, categories.FACTORY * categories.NAVAL * categories.TECH3, true }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildStructures = {
                    'T3SupportSeaFactory',
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
            { MIBC, 'AirStagingWantedRNG', { } },
            -- When do we want to build this ?
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.AIRSTAGINGPLATFORM }},
            -- Do we need additional conditions to build it ?
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 20.0 }},
            -- Have we the eco to build it ?
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 1.0 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.AIRSTAGINGPLATFORM }},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 1,
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T2AirStagingPlatform',
                },
                LocationType = 'LocationType',
            }
        }
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
            -- { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
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
            -- { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
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
            -- { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
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
            -- { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.TECH2 * categories.AIR }},
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
            -- { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
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
            -- { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
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
            -- { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
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
            -- { UCBC, 'CheckBuildPlatoonDelayRNG', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH2 }},
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Factory Builder Land Large Expansion',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Land T1 MainBase Large Expansion',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {

            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.60}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    'T1LandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Land T1 Large Expansion',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 800,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 4, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
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
            --{ EBC, 'GreaterThanEconStorageCurrentRNG', { 105, 1050 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.9, 1.0 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
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
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND', true } },
            { TBC, 'ThreatPresentInGraphRNG', {'LocationType', 'StructuresNotMex'} },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 4, categories.FACTORY * categories.LAND }},
         },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
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
            { MIBC, 'GatewayValidation', {} },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.80 } },             -- Ratio from 0 to 1. (1=100%)
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                BuildClose = false,
                LocationType = 'LocationType',
                AdjacencyPriority = {categories.ENERGYPRODUCTION},
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
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            --{ EBC, 'GreaterThanEconStorageCurrentRNG', { 105, 1200 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.LAND * categories.TECH1 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
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
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
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
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.AIR * categories.FACTORY * categories.TECH1 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * (categories.TECH2 + categories.TECH3) }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
}