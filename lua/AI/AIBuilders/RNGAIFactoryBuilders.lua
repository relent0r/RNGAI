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
        return 950
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
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 1050,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.75 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.LAND * categories.FACTORY * categories.TECH1 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * categories.TECH1 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY }},
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    { Unit = 'T1LandFactory', Categories = categories.FACTORY * categories.LAND * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Land T1 MainBase',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 1010,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'ForcePathLimitRNG', {'LocationType', categories.FACTORY * categories.LAND, 'LAND', 2}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.80 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'PlayerRoleCheck', {'LocationType', 2, categories.FACTORY * categories.LAND, {'AIR', 'NAVAL'}, 1 }},
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Land' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    { Unit = 'T1LandFactory', Categories = categories.FACTORY * categories.LAND * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Land T1 MainBase Storage',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 1010,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'GreaterThanEconStorageCurrentRNG', { 240, 1050 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.60, 0.80 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'PlayerRoleCheck', {'LocationType', 2, categories.FACTORY * categories.LAND, {'AIR', 'NAVAL'}, 1 }},
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Land', false, true } },
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    { Unit = 'T1LandFactory', Categories = categories.FACTORY * categories.LAND * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Land T2 MainBase',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 1015,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.90 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'PlayerRoleCheck', {'LocationType', 2, categories.FACTORY * categories.LAND, {'AIR'}, 1 }},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Land' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 4, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                AdjacencyPriority = {categories.ENERGYPRODUCTION},
                BuildStructures = {
                    { Unit = 'T2SupportLandFactory', Categories = categories.FACTORY * categories.LAND * categories.TECH2 * categories.SUPPORTFACTORY },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Land T3 MainBase',
        PlatoonTemplate = 'EngineerStateT3RNG',
        Priority = 1020,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.90 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'PlayerRoleCheck', {'LocationType', 2, categories.FACTORY * categories.LAND, {'AIR'}, 1 }},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Land' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 4, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                StateMachine = 'EngineerBuilder',
                LocationType = 'LocationType',
                BuildClose = false,
                AdjacencyPriority = {categories.ENERGYPRODUCTION},
                BuildStructures = {
                    { Unit = 'T3SupportLandFactory', Categories = categories.FACTORY * categories.LAND * categories.TECH3 * categories.SUPPORTFACTORY },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Land T1',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 900,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 2,
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.0 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'PlayerRoleCheck', {'LocationType', 2, categories.FACTORY * categories.LAND, {'AIR'}, 1 }},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Land' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    { Unit = 'T1LandFactory', Categories = categories.FACTORY * categories.LAND * categories.TECH1 },
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
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.30}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.8 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 8, categories.FACTORY * categories.LAND }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    { Unit = 'T1LandFactory', Categories = categories.FACTORY * categories.LAND * categories.TECH1 },
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
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 1050,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.75 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.LAND * categories.FACTORY * categories.TECH1 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * categories.TECH1 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY }},
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    { Unit = 'T1LandFactory', Categories = categories.FACTORY * categories.LAND * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Land T1 MainBase Large',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'ForcePathLimitRNG', {'LocationType', categories.FACTORY * categories.LAND, 'LAND', 2}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.85 }},
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'PlayerRoleCheck', {'LocationType', 2, categories.FACTORY * categories.LAND, {'AIR', 'NAVAL'}, 1 }},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Land' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    { Unit = 'T1LandFactory', Categories = categories.FACTORY * categories.LAND * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Land T1 Large',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 800,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.80, 'FACTORY'}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.0 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'PlayerRoleCheck', {'LocationType', 2, categories.FACTORY * categories.LAND, {'AIR'}, 1 }},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Land' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    { Unit = 'T1LandFactory', Categories = categories.FACTORY * categories.LAND * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Land T1 Path Large',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 1010,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.30, 'FACTORY'}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.85 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'PlayerRoleCheck', {'LocationType', 2, categories.FACTORY * categories.LAND, {'AIR', 'NAVAL'}, 1 }},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Land' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    { Unit = 'T1LandFactory', Categories = categories.FACTORY * categories.LAND * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Land T2 MainBase Large',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.0 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'PlayerRoleCheck', {'LocationType', 2, categories.FACTORY * categories.LAND, {'AIR'}, 1 }},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Land' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 4, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                AdjacencyPriority = {categories.ENERGYPRODUCTION},
                BuildStructures = {
                    { Unit = 'T2SupportLandFactory', Categories = categories.FACTORY * categories.LAND * categories.TECH2 * categories.SUPPORTFACTORY },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Land T3 MainBase Large',
        PlatoonTemplate = 'EngineerStateT3RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.0 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'PlayerRoleCheck', {'LocationType', 2, categories.FACTORY * categories.LAND, {'AIR'}, 1 }},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Land' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 4, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                AdjacencyPriority = {categories.ENERGYPRODUCTION},
                BuildStructures = {
                    { Unit = 'T3SupportLandFactory', Categories = categories.FACTORY * categories.LAND * categories.TECH3 * categories.SUPPORTFACTORY },
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
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 1050,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.80 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Air' } },
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.AIR * categories.FACTORY * categories.TECH1 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * categories.TECH1 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY }},
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    { Unit = 'T1AirFactory', Categories = categories.FACTORY * categories.AIR * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Air T1 Main',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 1010,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'MapGreaterThan', { 256, 256 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.15 }},
            { UCBC, 'PlayerRoleCheck', {'LocationType', 1, categories.FACTORY * categories.AIR, {'SPAM'} }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 3, categories.FACTORY * categories.AIR }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Air' } },
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.AIR * categories.FACTORY }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            StateMachine = 'EngineerBuilder',
            Construction = {
                LocationType = 'LocationType',
                AdjacencyPriority = {categories.ENERGYPRODUCTION},
                BuildClose = false,
                BuildStructures = {
                    { Unit = 'T1AirFactory', Categories = categories.FACTORY * categories.AIR * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Air T1 Main Response',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 0,
        PriorityFunction = AirDefenseScramble,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { UCBC, 'PlayerRoleCheck', {'LocationType', 1, categories.FACTORY * categories.AIR, {'SPAM'} }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.0 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 3, categories.FACTORY * categories.AIR }},
            { UCBC, 'MinimumFactoryCheckRNG', { 'LocationType', 'Air'}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.AIR * (categories.TECH2 + categories.TECH3) }},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Air' } },
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.AIR * categories.FACTORY }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                AdjacencyPriority = {categories.ENERGYPRODUCTION},
                BuildClose = false,
                BuildStructures = {
                    { Unit = 'T1AirFactory', Categories = categories.FACTORY * categories.AIR * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Air T2 MainBase',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.2 }},
            { UCBC, 'MinimumFactoryCheckRNG', { 'LocationType', 'Air'}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY }},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Air' } },
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                AdjacencyPriority = {categories.ENERGYPRODUCTION},
                BuildStructures = {
                    { Unit = 'T2SupportAirFactory', Categories = categories.FACTORY * categories.AIR * categories.TECH2 * categories.SUPPORTFACTORY },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Air T3 MainBase',
        PlatoonTemplate = 'EngineerStateT3RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.2 }},
            { UCBC, 'MinimumFactoryCheckRNG', { 'LocationType', 'Air'}},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Air' } },
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                AdjacencyPriority = {categories.ENERGYPRODUCTION},
                BuildStructures = {
                    { Unit = 'T3SupportAirFactory', Categories = categories.FACTORY * categories.AIR * categories.TECH3 * categories.SUPPORTFACTORY },
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
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 700,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.1 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.AIR }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    { Unit = 'T1AirFactory', Categories = categories.FACTORY * categories.AIR * categories.TECH1 },
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
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 1050,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.80 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Air' } },
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.AIR * categories.FACTORY * categories.TECH1 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * categories.TECH1 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    { Unit = 'T1AirFactory', Categories = categories.FACTORY * categories.AIR * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Air T1 High Pri Large',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'PlayerRoleCheck', {'LocationType', 1, categories.FACTORY * categories.AIR, {'SPAM'} }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.85 }},
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'MAIN', 3, categories.FACTORY * categories.AIR }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.STRUCTURE * categories.AIR * categories.FACTORY }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Air' } },
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    { Unit = 'T1AirFactory', Categories = categories.FACTORY * categories.AIR * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Air T1 Main Large',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 800,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'PlayerRoleCheck', {'LocationType', 1, categories.FACTORY * categories.AIR, {'SPAM'} }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.09, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.05 }},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Air' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.AIR * categories.FACTORY }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    { Unit = 'T1AirFactory', Categories = categories.FACTORY * categories.AIR * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Air T2 MainBase Large',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.1 }},
            { UCBC, 'MinimumFactoryCheckRNG', { 'LocationType', 'Air'}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR *  categories.TECH3 - categories.SUPPORTFACTORY }},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Air' } },
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                AdjacencyPriority = {categories.ENERGYPRODUCTION},
                BuildStructures = {
                    { Unit = 'T2SupportAirFactory', Categories = categories.FACTORY * categories.AIR * categories.TECH2 * categories.SUPPORTFACTORY },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Air T3 MainBase Large',
        PlatoonTemplate = 'EngineerStateT3RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.2 }},
            { UCBC, 'MinimumFactoryCheckRNG', { 'LocationType', 'Air'}},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Air' } },
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                AdjacencyPriority = {categories.ENERGYPRODUCTION},
                BuildStructures = {
                    { Unit = 'T3SupportAirFactory', Categories = categories.FACTORY * categories.AIR * categories.TECH3 * categories.SUPPORTFACTORY },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Air T1 Main Response Large',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 0,
        PriorityFunction = AirDefenseScramble,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'PlayerRoleCheck', {'LocationType', 1, categories.FACTORY * categories.AIR, {'SPAM'} }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.0 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 4, categories.FACTORY * categories.AIR }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.AIR * (categories.TECH2 + categories.TECH3) }},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Air' } },
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.AIR * categories.FACTORY }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                AdjacencyPriority = {categories.ENERGYPRODUCTION},
                BuildClose = false,
                BuildStructures = {
                    { Unit = 'T1AirFactory', Categories = categories.FACTORY * categories.AIR * categories.TECH1 },
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
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 0,
        PriorityFunction = ActiveExpansion,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.9, 1.05 }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.STRUCTURE * categories.AIR * categories.FACTORY * categories.TECH1 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Air' } },
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    { Unit = 'T1AirFactory', Categories = categories.FACTORY * categories.AIR * categories.TECH1 },
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
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 1050,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.85 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.NAVAL * categories.FACTORY * categories.TECH1 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.NAVAL * categories.TECH1 }},
            { UCBC, 'LessThanFactoryCountRNG', { 1, categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY, true }},
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    { Unit = 'T1SeaFactory', Categories = categories.FACTORY * categories.NAVAL * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Sea T1 High Pri',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'LessThanFactoryCountRNG', { 3, categories.STRUCTURE * categories.FACTORY * categories.NAVAL, true }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.85 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.NAVAL * categories.TECH1 }},
            { UCBC, 'LessThanFactoryCountRNG', { 1, categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY, true }},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Naval' } },
            { UCBC, 'UnitCapCheckLess', { .95 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildStructures = {
                    { Unit = 'T1SeaFactory', Categories = categories.FACTORY * categories.NAVAL * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Sea T1 High Pri Naval',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 0,
        PriorityFunction = NavalAdjust,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.90, 1.0 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.NAVAL * categories.TECH1 }},
            { UCBC, 'LessThanFactoryCountRNG', { 1, categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3), true }},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Naval' } },
            { UCBC, 'UnitCapCheckLess', { .95 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildStructures = {
                    { Unit = 'T1SeaFactory', Categories = categories.FACTORY * categories.NAVAL * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Sea T2 High Pri Naval',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 0,
        PriorityFunction = NavalAdjust,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.05 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Naval' } },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 3, categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.NAVAL * categories.TECH3 }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildStructures = {
                    { Unit = 'T2SupportSeaFactory', Categories = categories.FACTORY * categories.NAVAL * categories.TECH2 * categories.SUPPORTFACTORY },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Sea T3 High Pri Naval',
        PlatoonTemplate = 'EngineerStateT3RNG',
        Priority = 0,
        PriorityFunction = NavalAdjust,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.05 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Naval' } },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH3 - categories.SUPPORTFACTORY } },
            { UCBC, 'LessThanFactoryCountRNG', { 3, categories.FACTORY * categories.NAVAL * categories.TECH3, true }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildStructures = {
                    { Unit = 'T3SupportSeaFactory', Categories = categories.FACTORY * categories.NAVAL * categories.TECH3 * categories.SUPPORTFACTORY },
                },
            }
        }
    },

    Builder {
        BuilderName = 'RNG Factory Builder Sea T2 High Pri Naval',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 0,
        PriorityFunction = NavalAdjust,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.05 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Naval' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 3, categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.NAVAL * categories.TECH3 }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildStructures = {
                    { Unit = 'T2SupportSeaFactory', Categories = categories.FACTORY * categories.NAVAL * categories.TECH2 * categories.SUPPORTFACTORY },
                },
            }
        }
    },
    
    Builder {
        BuilderName = 'RNG Factory Builder Sea T1 Marker',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 700,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.85}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.0, 1.0 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.NAVAL * categories.TECH1 }},
            { UCBC, 'LessThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3), true } },
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Naval' } },
            { UCBC, 'UnitCapCheckLess', { .95 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                NearMarkerType = 'Naval Area',
                LocationRadius = 90,
                LocationType = 'LocationType',
                BuildStructures = {
                    { Unit = 'T1SeaFactory', Categories = categories.FACTORY * categories.NAVAL * categories.TECH1 },
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
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 1050,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.85 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Naval' } },
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.NAVAL * categories.FACTORY * categories.TECH1 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.NAVAL * categories.TECH1 }},
            { UCBC, 'LessThanFactoryCountRNG', { 1, categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY, true }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    { Unit = 'T1SeaFactory', Categories = categories.FACTORY * categories.NAVAL * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Sea T1 High Pri Large',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'LessThanFactoryCountRNG', { 3, categories.STRUCTURE * categories.FACTORY * categories.NAVAL, true } },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.85 }},
            { UCBC, 'LessThanFactoryCountRNG', { 1, categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY, true }},
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.NAVAL * categories.TECH1 }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildStructures = {
                    { Unit = 'T1SeaFactory', Categories = categories.FACTORY * categories.NAVAL * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Sea T1 Marker Large',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 0,
        PriorityFunction = NavalAdjust,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            --{ EBC, 'GreaterThanEconStorageRatioRNG', { 0.08, 0.50}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.90, 1.0 }},
            { UCBC, 'LessThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3), true } },
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.NAVAL * categories.TECH1 }},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Naval' } },
            { UCBC, 'UnitCapCheckLess', { .95 } },

        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                NearMarkerType = 'Naval Area',
                LocationRadius = 90,
                LocationType = 'LocationType',
                BuildStructures = {
                    { Unit = 'T1SeaFactory', Categories = categories.FACTORY * categories.NAVAL * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Sea T1 Marker Large Excess',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 650,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            --{ EBC, 'GreaterThanEconStorageRatioRNG', { 0.08, 0.50}}, -- Ratio from 0 to 1. (1=100%)
            { UCBC, 'LessThanFactoryCountRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3), true }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.2 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.NAVAL * categories.TECH1 }},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Naval' } },
            { UCBC, 'UnitCapCheckLess', { .95 } },

        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                NearMarkerType = 'Naval Area',
                LocationRadius = 90,
                LocationType = 'LocationType',
                BuildStructures = {
                    { Unit = 'T1SeaFactory', Categories = categories.FACTORY * categories.NAVAL * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Sea T2 High Pri Naval Large',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 0,
        PriorityFunction = NavalAdjust,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.05 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Naval' } },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 3, categories.FACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.NAVAL * categories.TECH3 }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildStructures = {
                    { Unit = 'T2SupportSeaFactory', Categories = categories.FACTORY * categories.NAVAL * categories.TECH2 * categories.SUPPORTFACTORY },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Sea T3 High Pri Naval Large',
        PlatoonTemplate = 'EngineerStateT3RNG',
        Priority = 0,
        PriorityFunction = NavalAdjust,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.05 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Naval' } },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH3 - categories.SUPPORTFACTORY } },
            { UCBC, 'LessThanFactoryCountRNG', { 3, categories.FACTORY * categories.NAVAL * categories.TECH3, true }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildStructures = {
                    { Unit = 'T3SupportSeaFactory', Categories = categories.FACTORY * categories.NAVAL * categories.TECH3 * categories.SUPPORTFACTORY },
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
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 900,
        BuilderConditions = {
            { UCBC, 'AirStagingWantedRNG', { } },
            -- When do we want to build this ?
            -- Do we need additional conditions to build it ?
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 20.0 }},
            -- Have we the eco to build it ?
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 1.0 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.AIRSTAGINGPLATFORM }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            NumAssistees = 1,
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    { Unit = 'T2AirStagingPlatform', Categories = categories.STRUCTURE * categories.AIRSTAGINGPLATFORM },
                },
                LocationType = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Factory Builder Land Expansion',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Land T1 Expansion Primary',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 1.0 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    { Unit = 'T1LandFactory', Categories = categories.FACTORY * categories.LAND * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Land T1 Expansion Active',
        PlatoonTemplate = 'EngineerStateT123RNG',
        PriorityFunction = ActiveExpansion,
        Priority = 0,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND'} },
            { EBC, 'GreaterThanMassStorageOrEfficiency', { 150, 0.8 }},
            { EBC, 'GreaterThanEnergyEfficiencyOverTimeRNG', { 0.9 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Land', false, true } },
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    { Unit = 'T1LandFactory', Categories = categories.FACTORY * categories.LAND * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Land T2 Expansion Active',
        PlatoonTemplate = 'EngineerStateT23RNG',
        PriorityFunction = ActiveExpansion,
        Priority = 0,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND'} },
            { EBC, 'GreaterThanMassStorageOrEfficiency', { 150, 0.9 }},
            { EBC, 'GreaterThanEnergyEfficiencyOverTimeRNG', { 1.0 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * categories.TECH3 }},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Land', false, true } },
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    { Unit = 'T2SupportLandFactory', Categories = categories.FACTORY * categories.LAND * categories.TECH2 * categories.SUPPORTFACTORY },
                    
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Land T3 Expansion Active',
        PlatoonTemplate = 'EngineerStateT3RNG',
        PriorityFunction = ActiveExpansion,
        Priority = 0,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND'} },
            { EBC, 'GreaterThanMassStorageOrEfficiency', { 150, 0.9 }},
            { EBC, 'GreaterThanEnergyEfficiencyOverTimeRNG', { 1.0 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Land', false, true } },
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    { Unit = 'T3SupportLandFactory', Categories = categories.FACTORY * categories.LAND * categories.TECH3 * categories.SUPPORTFACTORY },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Land T1 Island Expansion',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND', true } },
            { TBC, 'ThreatPresentOnLabelRNG', {'LocationType', 'StructuresNotMex'} },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Land' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 4, categories.FACTORY * categories.LAND }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    { Unit = 'T1LandFactory', Categories = categories.FACTORY * categories.LAND * categories.TECH1 },
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
        PlatoonTemplate = 'EngineerStateT3RNG',
        Priority = 850,
        BuilderConditions = {
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Gate' } },
            { MIBC, 'GatewayValidation', {} },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.80 } },             -- Ratio from 0 to 1. (1=100%)
            { UCBC, 'UnitCapCheckLess', { .95 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                BuildClose = false,
                LocationType = 'LocationType',
                AdjacencyPriority = {categories.ENERGYPRODUCTION},
                BuildStructures = {
                    { Unit = 'T3QuantumGate', Categories = categories.FACTORY * categories.GATE * categories.TECH3 },
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
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            --{ EBC, 'GreaterThanEconStorageCurrentRNG', { 105, 1200 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.LAND * categories.TECH1 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    { Unit = 'T1LandFactory', Categories = categories.FACTORY * categories.LAND * categories.TECH1 },
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
        PlatoonTemplate = 'EngineerStateT123RNG',
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
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    { Unit = 'T1AirFactory', Categories = categories.FACTORY * categories.AIR * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGEXP Factory Builder Air T1 Main',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 900,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { EBC, 'ZoneBasedFactoryToMassSupported', { 'LocationType', 'Air' } },
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.AIR * categories.FACTORY * categories.TECH1 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                LocationType = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    { Unit = 'T1AirFactory', Categories = categories.FACTORY * categories.AIR * categories.TECH1 },
                },
            }
        }
    },
}