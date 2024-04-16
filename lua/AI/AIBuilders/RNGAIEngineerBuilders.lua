--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Land Builders
]]

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MABC = '/lua/editor/MarkerBuildConditions.lua'
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

local AirDefenseScramble = function(self, aiBrain, builderManager)
    local myAirThreat = aiBrain.BrainIntel.SelfThreat.AntiAirNow
    local enemyAirThreat = aiBrain.EnemyIntel.EnemyThreatCurrent.Air
    if myAirThreat < enemyAirThreat then
        --RNGLOG('Enable Air ASF Scramble Pool Builder')
        --RNGLOG('My Air Threat '..myAirThreat..'Enemy Air Threat '..enemyAirThreat)
        return 810
    else
        --RNGLOG('Disable Air ASF Scramble Pool Builder')
        --RNGLOG('My Air Threat '..myAirThreat..'Enemy Air Threat '..enemyAirThreat)
        return 0
    end
end

local LandAdvantage = function(self, aiBrain, builderManager)
    if (aiBrain.BrainIntel.SelfThreat.LandNow + aiBrain.BrainIntel.SelfThreat.AllyLandThreat) > aiBrain.EnemyIntel.EnemyThreatCurrent.Land then
        return 750
    end
    return 740
end

local MexChokeFlag = function(self, aiBrain, builderManager)
    if aiBrain.ChokeFlag then
        return 900
    end
    return 200
end

local StartingReclaimPresent = function(self, aiBrain, builderManager)
    if aiBrain.StartMassReclaimTotal > 500 then
        return 1002
    end
    if aiBrain.StartEnergyReclaimTotal > 5000 then
        return 1002
    end
    return 950
end

local ReclaimBasedFactoryPriority = function(self, aiBrain, builderManager)
    if aiBrain.StartReclaimCurrent > 500 then
        --RNGLOG('Priority Function More than 500 reclaim')
        return 740
    end
    if aiBrain:GetNumPlatoonsTemplateNamed('RNGAI T1EngineerReclaimer') < 7 then
        return 756
    end
    return 0
end

local MinimumAntiAirThreat = function(self, aiBrain, builderManager, builderData)
    local myAntiAirThreat = aiBrain.BrainIntel.SelfThreat.AntiAirNow
    if myAntiAirThreat > 12 then
        return 893
    end
    return 0

end

local AggressiveExpansion = function(self, aiBrain, builderManager)
    --RNGLOG('LocationType is '..builderManager.LocationType)
    if aiBrain.BrainIntel.AggressiveExpansion == builderManager.LocationType then
        --RNGLOG('Active Expansion is set'..builderManager.LocationType)
        --RNGLOG('Active Expansion builders are set to 900')
        return 950
    else
        --RNGLOG('Disable Air Intie Pool Builder')
        --RNGLOG('My Air Threat '..myAirThreat..'Enemy Air Threat '..enemyAirThreat)
        return 0
    end
end

BuilderGroup {
    BuilderGroupName = 'RNGAI Engineer Builder',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 MassRatioAvailable',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 756,
        BuilderConditions = {
            { MIBC, 'MassPointRatioAvailable', {}},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, categories.LAND * categories.ENGINEER } },
            { UCBC, 'PoolLessAtLocation', {'LocationType', 1, categories.ENGINEER * categories.TECH1 - categories.COMMAND }},
            { UCBC, 'UnitToThreatRatio', { 0.3, categories.MOBILE * categories.ENGINEER * categories.TECH1 - categories.INSIGNIFICANTUNIT, 'Land', '<'}},
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Reclaim',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 0,
        PriorityFunction = ReclaimBasedFactoryPriority,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsLessAtRestrictedRNG', { 'LocationType', 1, 'LAND' }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 2, categories.LAND * categories.ENGINEER } },
            { UCBC, 'PoolLessAtLocation', {'LocationType', 1, categories.ENGINEER - categories.COMMAND }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 30, categories.ENGINEER * categories.TECH1 - categories.COMMAND } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Reclaim Available',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 879,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsLessAtRestrictedRNG', { 'LocationType', 1, 'LAND' }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, categories.LAND * categories.ENGINEER } },
            { UCBC, 'PoolLessAtLocation', {'LocationType', 2, categories.ENGINEER - categories.COMMAND }},
            { MIBC, 'ReclaimablesAvailableAtBase', {'LocationType'}},
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Power',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 775,
        BuilderConditions = {
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, categories.LAND * categories.ENGINEER } },
            { EBC, 'NegativeEcoPowerCheck', { 0.0 } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.5, 0.0 }},
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Power AirOnly',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 893,
        PriorityFunction = MinimumAntiAirThreat,
        BuilderConditions = {
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 2, categories.LAND * categories.ENGINEER } },
            { EBC, 'LessThanEnergyTrendRNG', { 0.0 } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.5, 0.0 }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 50, categories.ENGINEER - categories.COMMAND } },
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Excess Mass',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 775,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsLessAtRestrictedRNG', { 'LocationType', 1, 'LAND' }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, categories.LAND * categories.ENGINEER } },
            { UCBC, 'PoolLessAtLocation', {'LocationType', 2, categories.ENGINEER - categories.COMMAND }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.50, 0.50}},
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T2 Power',
        PlatoonTemplate = 'T2BuildEngineer',
        Priority = 776,
        BuilderConditions = {
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, categories.LAND * categories.ENGINEER } },
            { EBC, 'NegativeEcoPowerCheck', { 0.0 } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.0 }},
            { UCBC, 'PoolLessAtLocation', {'LocationType', 1, categories.ENGINEER * categories.TECH2 - categories.COMMAND }},
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T2 Power AirOnly',
        PlatoonTemplate = 'T2BuildEngineer',
        Priority = 894,
        BuilderConditions = {
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 2, categories.LAND * categories.ENGINEER * categories.TECH2 } },
            { EBC, 'LessThanEnergyTrendRNG', { 0.0 } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.0 }},
            { UCBC, 'PoolLessAtLocation', {'LocationType', 1, categories.ENGINEER * categories.TECH2 - categories.COMMAND }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T2 Small AirOnly',
        PlatoonTemplate = 'T2BuildEngineer',
        Priority = 910, -- Top factory priority
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.FACTORY * categories.TECH2 * categories.AIR}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENGINEER * categories.TECH2 - categories.COMMAND } }, -- Build engies until we have 3 of them.
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.0 }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T3 Power',
        PlatoonTemplate = 'T3BuildEngineer',
        Priority = 777,
        BuilderConditions = {
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, categories.LAND * categories.ENGINEER } },
            { EBC, 'NegativeEcoPowerCheck', { 0.0 } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.0 }},
            { UCBC, 'PoolLessAtLocation', {'LocationType', 1, categories.ENGINEER * categories.TECH3 - categories.COMMAND }},
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T3 Power AirOnly',
        PlatoonTemplate = 'T3BuildEngineer',
        Priority = 895,
        BuilderConditions = {
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 2, categories.LAND * categories.ENGINEER * categories.TECH3 } },
            { EBC, 'LessThanEnergyTrendRNG', { 0.0 } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.0 }},
            { UCBC, 'PoolLessAtLocation', {'LocationType', 1, categories.ENGINEER * categories.TECH3 - categories.COMMAND }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Large',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 300, -- low factory priority
        BuilderConditions = {
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech1' } },
            { UCBC, 'PoolLessAtLocation', {'LocationType', 1, categories.ENGINEER * categories.TECH1 - categories.COMMAND }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.0, 1.0 }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 2, categories.LAND * categories.ENGINEER } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Expansion',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 650, -- low factory priority
        BuilderConditions = {
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech1' } },
            { UCBC, 'StartLocationNeedsEngineerRNG', { 'LocationType', 200, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, categories.ENGINEER * categories.TECH1 } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'All',
    },
    
    Builder {
        BuilderName = 'RNGAI Factory Engineer T2 Small',
        PlatoonTemplate = 'T2BuildEngineer',
        Priority = 800, -- Top factory priority
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.ENGINEER * categories.TECH2 - categories.COMMAND } }, -- Build engies until we have 2 of them.
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.FACTORY * categories.TECH2}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.0 }},
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T2 Dynamic',
        PlatoonTemplate = 'T2BuildEngineer',
        Priority = 900, -- Top factory priority
        BuilderConditions = {
            { UCBC, 'EngineerBuildPowerRequired', { 2, true } },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.FACTORY * categories.TECH2}},
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T2 Excess',
        PlatoonTemplate = 'T2BuildEngineer',
        Priority = 840, -- low factory priority
        BuilderConditions = {
            { UCBC, 'EnemyUnitsLessAtRestrictedRNG', { 'LocationType', 1, 'LAND' }},
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.FACTORY * categories.TECH2}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.50, 0.50}},
            { UCBC, 'PoolLessAtLocation', {'LocationType', 3, categories.ENGINEER * categories.TECH2 - categories.COMMAND }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 20, categories.ENGINEER * categories.TECH2 - categories.COMMAND } },
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech2' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'All',
    },

    Builder {
        BuilderName = 'RNGAI Factory Engineer T3 Small',
        PlatoonTemplate = 'T3BuildEngineer',
        Priority = 850, -- Top factory priority
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.FACTORY * categories.TECH3}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.ENGINEER * categories.TECH3 - categories.COMMAND } }, -- Build engies until we have 3 of them.
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.0 }},
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T3 Dynamic',
        PlatoonTemplate = 'T3BuildEngineer',
        Priority = 910, -- Top factory priority
        BuilderConditions = {
            { UCBC, 'EngineerBuildPowerRequired', { 3, true } },
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.FACTORY * categories.TECH3}},
        },
        BuilderType = 'All',
    },
    --[[
    Builder {
        BuilderName = 'RNGAI Factory Engineer T3 Small AirOnly',
        PlatoonTemplate = 'T3BuildEngineer',
        Priority = 910, -- Top factory priority
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.FACTORY * categories.TECH3 * categories.AIR}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENGINEER * categories.TECH3 - categories.COMMAND } }, -- Build engies until we have 3 of them.
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.0 }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T3 Medium',
        PlatoonTemplate = 'T3BuildEngineer',
        Priority = 500, -- Top factory priority
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.FACTORY * categories.TECH3}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.025, 0.8} },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 15, categories.ENGINEER * categories.TECH3 - categories.COMMAND } }, -- Build engies until we have 2 of them.
        },
        BuilderType = 'All',
    },]]
    Builder {
        BuilderName = 'RNGAI Factory Engineer T3 Excess',
        PlatoonTemplate = 'T3BuildEngineer',
        Priority = 850, -- low factory priority
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.FACTORY * categories.TECH3}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.50, 0.50}},
            { UCBC, 'PoolLessAtLocation', {'LocationType', 3, categories.ENGINEER * categories.TECH3 - categories.COMMAND }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 20, categories.ENGINEER * categories.TECH3 - categories.COMMAND } },
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech3' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'All',
    },
    
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Engineer Builder Naval Expansion',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Naval',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 870,
        BuilderConditions = {
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech1' } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T2 Naval',
        PlatoonTemplate = 'T2BuildEngineer',
        Priority = 450, -- low factory priority
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.9, 0.9} },
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech2' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'All',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Engineer Builder Expansion',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Aggression Count',
        PlatoonTemplate = 'T1BuildEngineer',
        PriorityFunction = AggressiveExpansion,
        Priority = 0,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsLessAtRestrictedRNG', { 'LocationType', 1, 'LAND' }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 2, categories.ENGINEER - categories.COMMAND } }, -- Build engies until we have 2 of them.
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech1' } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Expansion Count',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 870,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 1, categories.ENGINEER - categories.COMMAND } }, -- Build engies until we have 2 of them.
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech1' } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Expansion Mass',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 850,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.4, 0.6} },
            { UCBC, 'EnemyUnitsLessAtRestrictedRNG', { 'LocationType', 1, 'LAND' }},
            { MABC, 'CanBuildOnMassDistanceRNG', { 'LocationType', 0, 60, nil, -1000, 0, 'AntiSurface', 1 }},
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech1' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Maintain',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 400, -- low factory priority
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.4, 0.6} },
            { UCBC, 'EnemyUnitsLessAtRestrictedRNG', { 'LocationType', 1, 'LAND' }},
            { UCBC, 'PoolLessAtLocation', {'LocationType', 1, categories.ENGINEER - categories.COMMAND }},
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech1' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T1 Reclaim Expansion',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 900,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsLessAtRestrictedRNG', { 'LocationType', 1, 'LAND' }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, categories.LAND * categories.ENGINEER } },
            { UCBC, 'PoolLessAtLocation', {'LocationType', 1, categories.ENGINEER * categories.TECH1 - categories.COMMAND }},
            { MIBC, 'ReclaimablesAvailableAtBase', {'LocationType'}},
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T2 Expansion',
        PlatoonTemplate = 'T2BuildEngineer',
        Priority = 450, -- low factory priority
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.0, 0.9} },
            { UCBC, 'EnemyUnitsLessAtRestrictedRNG', { 'LocationType', 1, 'LAND' }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, categories.ENGINEER * categories.TECH2 } },
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech2' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T2 Expansion Active',
        PlatoonTemplate = 'T2BuildEngineer',
        Priority = 800, -- low factory priority
        BuilderConditions = {
            { MIBC, 'ExpansionIsActive', {} },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.9} },
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, categories.ENGINEER * categories.TECH2 } },
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech2' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer T3 Small Expansion',
        PlatoonTemplate = 'T3BuildEngineer',
        Priority = 500, -- Top factory priority
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.FACTORY * categories.TECH3}},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, categories.ENGINEER * categories.TECH3 } },
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech3' } },
        },
        BuilderType = 'All',
    },
    
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Assist Builders',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Assist Factory Air AA T123',
        PlatoonTemplate = 'T12EngineerAssistRNG',
        Priority = 0,
        DelayEqualBuildPlattons = {'EngineerAssistFactory', 1},
        PriorityFunction = AirDefenseScramble,
        InstanceCount = 6,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.90, 1.0 }},
        },
        BuilderData = {
            JobType = 'Assist',
            StateMachine = 'PreAllocatedTask',
            PreAllocatedTask = true,
            Task = 'EngineerAssist',
            Assist = {
                AssistLocation = 'LocationType',
                AssisteeType = categories.FACTORY,
                AssistRange = 120,
                AssistFactoryUnit = true,
                BeingBuiltCategories = {categories.AIR * categories.MOBILE * categories.ANTIAIR},                   
                AssistClosestUnit = false,  
                AssistHighestTier = true,                                     
                AssistUntilFinished = false,
                Time = 120,
            },
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Engineer Unfinished Structures',
        PlatoonTemplate = 'T123EngineerFinishRNG',
        Priority = 1005,
        DelayEqualBuildPlattons = {'EngineerAssistUnfinished', 1},
        InstanceCount = 4,
        BuilderConditions = {
                { UCBC, 'UnfinishedUnits', { 'LocationType', categories.STRUCTURE * (categories.DEFENSE + categories.FACTORY + categories.ENERGYPRODUCTION + categories.MASSEXTRACTION) }},
                { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            },
        BuilderData = {
            JobType = 'Assist',
            StateMachine = 'PreAllocatedTask',
            PreAllocatedTask = true,
            Task = 'FinishUnit',
            Assist = {
                AssistLocation = 'LocationType',
                BeingBuiltCategories = categories.STRUCTURE * (categories.FACTORY + categories.ENERGYPRODUCTION + categories.MASSEXTRACTION),
            },
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Engineer Unfinished Defense',
        PlatoonTemplate = 'T123EngineerAssistRNG',
        Priority = 1010,
        InstanceCount = 4,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'LANDNAVAL' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 1.0 }},
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * (categories.DEFENSE * (categories.DIRECTFIRE + categories.ANTIAIR) + categories.ARTILLERY * categories.TECH2)}},
            },
        BuilderData = {
            JobType = 'Assist',
            StateMachine = 'PreAllocatedTask',
            PreAllocatedTask = true,
            Task = 'EngineerAssist',
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                AssistRange = 100,
                BeingBuiltCategories = {categories.STRUCTURE * categories.TECH2 * categories.ARTILLERY, categories.STRUCTURE * categories.DEFENSE * (categories.DIRECTFIRE + categories.ANTIAIR)},
                AssistClosestUnit = true,
            },
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T123 Engineer Unfinished SMD',
        PlatoonTemplate = 'T123EngineerAssistRNG',
        Priority = 650,
        InstanceCount = 10,
        BuilderConditions = {
            { EBC, 'GreaterThanMassTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH3 } },
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH3 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.60}},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Assist',
            StateMachine = 'PreAllocatedTask',
            PreAllocatedTask = true,
            Task = 'EngineerAssist',
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                AssistRange = 100,
                AssistClosestUnit = true,
                BeingBuiltCategories = { categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH3},
                Time = 120,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI T123 Unfinished Experimental Small',
        PlatoonTemplate = 'T23EngineerAssistRNG',
        Priority = 800,
        InstanceCount = 3,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.1 }},
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.EXPERIMENTAL * categories.MOBILE }},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Assist',
            StateMachine = 'PreAllocatedTask',
            PreAllocatedTask = true,
            Task = 'EngineerAssist',
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                AssistRange = 100,
                AssistClosestUnit = true,
                BeingBuiltCategories = {categories.EXPERIMENTAL * categories.MOBILE},
                Time = 120,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI T123 Engineer Unfinished Experimental',
        PlatoonTemplate = 'T123EngineerAssistRNG',
        Priority = 600,
        DelayEqualBuildPlattons = {'EngineerAssistExp', 1},
        InstanceCount = 16,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.0, 1.0 }},
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.EXPERIMENTAL }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.80}},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Assist',
            StateMachine = 'PreAllocatedTask',
            PreAllocatedTask = true,
            Task = 'EngineerAssist',
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                AssistRange = 100,
                AssistClosestUnit = true,
                BeingBuiltCategories = { categories.EXPERIMENTAL },
                Time = 120,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI T123 Engineer Unfinished Strategic',
        PlatoonTemplate = 'T123EngineerAssistRNG',
        Priority = 500,
        DelayEqualBuildPlattons = {'EngineerAssistExp', 1},
        InstanceCount = 12,
        BuilderConditions = {
            { EBC, 'GreaterThanMassTrendRNG', { 0.0 } },
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.STRATEGIC }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.80}},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Assist',
            StateMachine = 'PreAllocatedTask',
            PreAllocatedTask = true,
            Task = 'EngineerAssist',
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                AssistRange = 100,
                AssistClosestUnit = true,
                BeingBuiltCategories = {categories.STRUCTURE * categories.STRATEGIC},
                Time = 120,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI T123 Engineer Unfinished PGEN',
        PlatoonTemplate = 'T123EngineerAssistRNG',
        Priority = 810,
        DelayEqualBuildPlattons = {'EngineerAssistPgen', 1},
        InstanceCount = 8,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.9, 0.0 }},
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }},
            { EBC, 'LessThanEnergyTrendOverTimeRNG', { 100.0 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Assist',
            StateMachine = 'PreAllocatedTask',
            PreAllocatedTask = true,
            Task = 'EngineerAssist',
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

BuilderGroup {
    BuilderGroupName = 'RNGAI Engineering Support Builder',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T2 Engineering Support UEF',
        PlatoonTemplate = 'UEFT2EngineerBuilderRNG',
        Priority = 500,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 1 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 6, categories.ENGINEERSTATION }},
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 1, 10}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.60, 0.85}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.95, 1.2 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                AdjacencyCategory = categories.FACTORY,
                BuildClose = true,
                FactionIndex = 1,
                BuildStructures = {
                    'T2EngineerSupport',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Engineering Support Cybran',
        PlatoonTemplate = 'CybranT2EngineerBuilderRNG',
        Priority = 500,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 3 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 6, categories.ENGINEERSTATION }},
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 1, 10}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.60, 0.85}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.95, 1.2 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                AdjacencyCategory = categories.FACTORY,
                BuildClose = true,
                FactionIndex = 3,
                BuildStructures = {
                    'T2EngineerSupport',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI Engineer Repair',
        PlatoonTemplate = 'EngineerRepairRNG',
        PlatoonAIPlan = 'RepairAIRNG',
        Priority = 900,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'DamagedStructuresInAreaRNG', { 'LocationType', }},
            },
        BuilderData = {
            JobType = 'Repair',
            LocationType = 'LocationType',
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Land Factory Reclaim',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T12 Engineer Reclaim T1 Land',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        PlatoonAIPlan = 'ReclaimStructuresRNG',
        Priority = 1050,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.TECH1 * categories.LAND * categories.FACTORY }},
                --{ UCBC, 'HaveGreaterThanUnitsInCategoryBeingUpgradedRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.LAND }},
                { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 1, (categories.TECH2 + categories.TECH3 ) * categories.SUPPORTFACTORY * categories.LAND}},
                { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, (categories.TECH2 + categories.TECH3) * categories.LAND * categories.FACTORY - categories.SUPPORTFACTORY }},
                { EBC, 'LessThanMassToFactoryRatioBaseCheckRNG', { 'LocationType', true }},
            },
        BuilderData = {
            JobType = 'ReclaimStructure',
            LocationType = 'LocationType',
            ReclaimMax = 1,
            Reclaim = {categories.STRUCTURE * categories.TECH1 * categories.LAND * categories.FACTORY},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T12 Engineer Reclaim T2 Land',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        PlatoonAIPlan = 'ReclaimStructuresRNG',
        Priority = 1040,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.TECH2 * categories.LAND * categories.FACTORY * categories.SUPPORTFACTORY }},
                { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 1, categories.TECH3 * categories.SUPPORTFACTORY * categories.LAND }},
                { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.TECH3 * categories.LAND * categories.FACTORY - categories.SUPPORTFACTORY }},
                { EBC, 'LessThanMassToFactoryRatioBaseCheckRNG', { 'LocationType', true }},
            },
        BuilderData = {
            JobType = 'ReclaimStructure',
            LocationType = 'LocationType',
            ReclaimMax = 1,
            Reclaim = {categories.STRUCTURE * categories.TECH2 * categories.LAND * categories.FACTORY * categories.SUPPORTFACTORY},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Engineer Reclaim T3 Land',
        PlatoonTemplate = 'EngineerBuilderT23RNG',
        PlatoonAIPlan = 'ReclaimStructuresRNG',
        Priority = 1030,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 3, categories.TECH3 * categories.LAND * categories.FACTORY * categories.SUPPORTFACTORY }},
                { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.TECH3 * categories.LAND * categories.FACTORY - categories.SUPPORTFACTORY }},
                { EBC, 'LessThanMassToFactoryRatioBaseCheckRNG', { 'LocationType', true }},
            },
        BuilderData = {
            JobType = 'ReclaimStructure',
            LocationType = 'LocationType',
            ReclaimMax = 1,
            Reclaim = {categories.STRUCTURE * categories.TECH3 * categories.LAND * categories.FACTORY * categories.SUPPORTFACTORY},
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Air Factory Reclaim',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T12 Engineer Reclaim T1 Air',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        PlatoonAIPlan = 'ReclaimStructuresRNG',
        Priority = 1050,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH1 * categories.AIR * categories.FACTORY }},
                --{ UCBC, 'HaveGreaterThanUnitsInCategoryBeingUpgradedRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.LAND }},
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 1, (categories.TECH2 + categories.TECH3 ) * categories.SUPPORTFACTORY * categories.AIR}},
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, (categories.TECH2 + categories.TECH3) * categories.AIR * categories.FACTORY - categories.SUPPORTFACTORY }},
                { EBC, 'LessThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' }},
            },
        BuilderData = {
            JobType = 'ReclaimStructure',
            LocationType = 'LocationType',
            ReclaimMax = 1,
            Reclaim = {categories.STRUCTURE * categories.TECH1 * categories.AIR * categories.FACTORY},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T12 Engineer Reclaim T2 Air',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        PlatoonAIPlan = 'ReclaimStructuresRNG',
        Priority = 1040,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH2 * categories.AIR * categories.FACTORY * categories.SUPPORTFACTORY }},
                --{ UCBC, 'HaveGreaterThanUnitsInCategoryBeingUpgradedRNG', { 0, categories.STRUCTURE * categories.FACTORY * categories.LAND }},
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 1, categories.TECH3 * categories.SUPPORTFACTORY * categories.AIR }},
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH3 * categories.AIR * categories.FACTORY - categories.SUPPORTFACTORY }},
                { EBC, 'LessThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' }},
            },
        BuilderData = {
            JobType = 'ReclaimStructure',
            LocationType = 'LocationType',
            ReclaimMax = 1,
            Reclaim = {categories.STRUCTURE * categories.TECH2 * categories.AIR * categories.FACTORY * categories.SUPPORTFACTORY},
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Naval Factory Reclaim',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T12 Engineer Reclaim T1 Naval',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        PlatoonAIPlan = 'ReclaimStructuresRNG',
        Priority = 1050,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH1 * categories.NAVAL * categories.FACTORY }},
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.SUPPORTFACTORY * categories.NAVAL * (categories.TECH2 + categories.TECH3 )}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.NAVAL * categories.FACTORY * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY }},
                { EBC, 'LessThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' }},
            },
        BuilderData = {
            JobType = 'ReclaimStructure',
            LocationType = 'LocationType',
            ReclaimMax = 1,
            Reclaim = {categories.STRUCTURE * categories.TECH1 * categories.NAVAL * categories.FACTORY},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T12 Engineer Reclaim T2 Naval',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        PlatoonAIPlan = 'ReclaimStructuresRNG',
        Priority = 1040,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 1, categories.TECH2 * categories.NAVAL * categories.FACTORY * categories.SUPPORTFACTORY }},
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH3 * categories.SUPPORTFACTORY * categories.NAVAL }},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.TECH3 * categories.NAVAL * categories.FACTORY - categories.SUPPORTFACTORY }},
                { EBC, 'LessThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' }},
            },
        BuilderData = {
            JobType = 'ReclaimStructure',
            LocationType = 'LocationType',
            ReclaimMax = 1,
            Reclaim = {categories.STRUCTURE * categories.TECH2 * categories.NAVAL * categories.FACTORY * categories.SUPPORTFACTORY},
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Energy Production Reclaim',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Engineer Reclaim T1 Pgens',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        PlatoonAIPlan = 'ReclaimStructuresRNG',
        Priority = 800,
        InstanceCount = 2,
        BuilderConditions = {
                { EBC, 'GreaterThanEnergyTrendOverTimeRNG', { 0.0 } },
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, (categories.TECH2 + categories.TECH3 ) * categories.ENERGYPRODUCTION}},
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH1 * categories.ENERGYPRODUCTION - categories.HYDROCARBON }},
                { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.1, 1.1 }},
            },
        BuilderData = {
            JobType = 'ReclaimT1Power',
            LocationType = 'LocationType',
            ReclaimMax = 5,
            Reclaim = {categories.STRUCTURE * categories.TECH1 * categories.ENERGYPRODUCTION - categories.HYDROCARBON},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Engineer Reclaim T2 Pgens',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        PlatoonAIPlan = 'ReclaimStructuresRNG',
        Priority = 600,
        InstanceCount = 2,
        BuilderConditions = {
                { EBC, 'GreaterThanEnergyTrendOverTimeRNG', { 0.0 } },
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH3 * categories.ENERGYPRODUCTION}},
                { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH2 * categories.ENERGYPRODUCTION }},
                { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.1, 1.3 }},
            },
        BuilderData = {
            JobType = 'ReclaimPower',
            LocationType = 'LocationType',
            ReclaimMax = 1,
            Reclaim = {categories.STRUCTURE * categories.TECH2 * categories.ENERGYPRODUCTION - categories.HYDROCARBON},
        },
        BuilderType = 'Any',
    },
    
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Naval Assist',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Engineer Assist Factory Naval',
        PlatoonTemplate = 'T12EngineerAssistRNG',
        DelayEqualBuildPlattons = {'Assist', 3},
        Priority = 500,
        InstanceCount = 8,
        BuilderConditions = {
            { EBC, 'NavalAssistControlRNG', { 1.05, 1.05, 'LocationType', 'Naval' }},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Assist',
            StateMachine = 'PreAllocatedTask',
            PreAllocatedTask = true,
            Task = 'EngineerAssist',
            Assist = {
                AssistLocation = 'LocationType',
                AssistFactoryUnit = true,
                AssisteeType = categories.FACTORY,
                AssistClosestUnit = false,                                       
                AssistHighestTier = true,
                AssistUntilFinished = false,
                Time = 180,
            },
        }
    },

}
BuilderGroup {
    BuilderGroupName = 'RNGAI T1 Reclaim Builders',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Engineer Reclaim T1 Minimum', -- Try to get that early reclaim
        PlatoonTemplate = 'RNGAI T1EngineerReclaimer',
        PriorityFunction = StartingReclaimPresent,
        Priority = 950,
        InstanceCount = 2,
        BuilderConditions = {
                { MIBC, 'CheckIfReclaimEnabled', {}},
                --{ EBC, 'GreaterThanEnergyStorageRatioRNG', { 0.40 } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.MOBILE * categories.ENGINEER - categories.COMMAND}},
                
            },
        BuilderData = {
            JobType = 'Reclaim',
            Early = true,
            ReclaimTable = true,
            LocationType = 'LocationType',
            ReclaimTime = 80,
            MinimumReclaim = 8
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Engineer Reclaim T1',
        PlatoonTemplate = 'RNGAI T1EngineerReclaimer',
        DelayEqualBuildPlattons = {'EngineerReclaim', 1},
        Priority = 900,
        InstanceCount = 5,
        BuilderConditions = {
                { UCBC, 'GreaterThanGameTimeSecondsRNG', { 380 } },
                { MIBC, 'CheckIfReclaimEnabled', {}},
                { EBC, 'GreaterThanEnergyTrendOverTimeRNG', { 0.0 } },
                { EBC, 'LessThanEconStorageRatioRNG', { 0.80, 2.0}},
            },
        BuilderData = {
            JobType = 'Reclaim',
            LocationType = 'LocationType',
            ReclaimTable = true,
            ReclaimTime = 80,
            MinimumReclaim = 15
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Engineer Reclaim T1 Excess',
        PlatoonTemplate = 'RNGAI T1EngineerReclaimer',
        DelayEqualBuildPlattons = {'EngineerReclaim', 1},
        Priority = 700,
        InstanceCount = 15,
        BuilderConditions = {
                { UCBC, 'GreaterThanGameTimeSecondsRNG', { 600 } },
                { MIBC, 'CheckIfReclaimEnabled', {}},
                { UCBC, 'PoolGreaterAtLocation', {'LocationType', 3, categories.ENGINEER * categories.TECH1 }},
                { EBC, 'LessThanEconStorageRatioRNG', { 0.80, 2.0}},
            },
        BuilderData = {
            JobType = 'Reclaim',
            LocationType = 'LocationType',
            ReclaimTime = 80,
            MinimumReclaim = 15
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Engineer Reclaim T2 Excess',
        PlatoonTemplate = 'RNGAI T2EngineerReclaimer',
        DelayEqualBuildPlattons = {'EngineerReclaim', 1},
        Priority = 100,
        InstanceCount = 1,
        BuilderConditions = {
                { MIBC, 'CheckIfReclaimEnabled', {}},
                { UCBC, 'PoolGreaterAtLocation', {'LocationType', 3, categories.ENGINEER * categories.TECH2 - categories.STATIONASSISTPOD }},
                { EBC, 'LessThanEconStorageRatioRNG', { 0.80, 2.0}},
            },
        BuilderData = {
            JobType = 'Reclaim',
            LocationType = 'LocationType',
            ReclaimTime = 80,
            MinimumReclaim = 15,
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Assist Manager BuilderGroup',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Assist Manager T1',
        PlatoonTemplate = 'EngineerAssistManagerT1RNG',
        Priority = 999,
        DelayEqualBuildPlattons = {'EngineerAssistExp', 1},
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'EngineerAssistManagerNeedsEngineers', { } },
            { UCBC, 'GreaterThanGameTimeSecondsRNG', { 180 } },
        },
        BuilderData = {
            JobType = 'Assist',
            PlatoonPlan = 'EngineerAssistManagerRNG',
            LocationType = 'LocationType'
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Assist Manager T2',
        PlatoonTemplate = 'EngineerAssistManagerT2RNG',
        Priority = 999,
        DelayEqualBuildPlattons = {'EngineerAssistExp', 1},
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'EngineerAssistManagerNeedsEngineers', { } },
            { UCBC, 'PoolGreaterAtLocation', {'LocationType', 2, categories.ENGINEER * categories.TECH2 }},
        },
        BuilderData = {
            JobType = 'Assist',
            PlatoonPlan = 'EngineerAssistManagerRNG',
            LocationType = 'LocationType'
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Assist Manager T3',
        PlatoonTemplate = 'EngineerAssistManagerT3RNG',
        Priority = 999,
        DelayEqualBuildPlattons = {'EngineerAssistExp', 1},
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'EngineerAssistManagerNeedsEngineers', { } },
            { UCBC, 'PoolGreaterAtLocation', {'LocationType', 2, categories.ENGINEER * categories.TECH3 }},
        },
        BuilderData = {
            JobType = 'Assist',
            PlatoonPlan = 'EngineerAssistManagerRNG',
            LocationType = 'LocationType'
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI T1 Reclaim Floating',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Engineer Reclaim T1 Floating',
        PlatoonTemplate = 'RNGAI T1EngineerReclaimer',
        Priority = 900,
        InstanceCount = 14,
        BuilderConditions = {
                { MIBC, 'CheckIfReclaimEnabled', {}},
                { EBC, 'LessThanEconStorageRatioRNG', { 0.80, 2.0}},
            },
        BuilderData = {
            JobType = 'Expansion',
            ReclaimTable = true,
            LocationType = 'LocationType',
            ReclaimTime = 80,
            MinimumReclaim = 4
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI T1 Reclaim Builders Expansion',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Engineer Reclaim T1 Excess Expansion',
        PlatoonTemplate = 'RNGAI T1EngineerReclaimer',
        Priority = 900,
        InstanceCount = 16,
        BuilderConditions = {
                { UCBC, 'PoolGreaterAtLocation', {'LocationType', 1, categories.ENGINEER * categories.TECH1 }},
                { MIBC, 'CheckIfReclaimEnabled', {}},
                { EBC, 'LessThanEconStorageRatioRNG', { 0.80, 2.0}},
            },
        BuilderData = {
            JobType = 'Expansion',
            ReclaimTable = true,
            LocationType = 'LocationType',
            ReclaimTime = 80,
            MinimumReclaim = 4
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Engineer Transfer To Active Expansion',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Eng Trans ActiveExpansion',
        PlatoonTemplate = 'T1EngineerTransferRNG',
        Priority = 500,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'GreaterThanGameTimeSecondsRNG', { 600 } },
            { MIBC, 'ExpansionIsActive', {} },
            { UCBC, 'PoolGreaterAtLocation', {'MAIN', 7, categories.MOBILE * categories.ENGINEER * categories.TECH1 - categories.STATIONASSISTPOD - categories.COMMAND }},
            { UCBC, 'EngineerManagerUnitsAtActiveExpansionRNG', { '<', 2,  categories.MOBILE * categories.ENGINEER * categories.TECH1 - categories.STATIONASSISTPOD - categories.COMMAND } },
        },
        BuilderData = {
            JobType = 'Expansion',
            MoveToLocationType = 'ActiveExpansion',
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Eng Trans ActiveExpansion',
        PlatoonTemplate = 'T2EngineerTransferRNG',
        Priority = 510,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'GreaterThanGameTimeSecondsRNG', { 600 } },
            { MIBC, 'ExpansionIsActive', {} },
            { UCBC, 'PoolGreaterAtLocation', {'MAIN', 5, categories.MOBILE * categories.ENGINEER * categories.TECH2 - categories.STATIONASSISTPOD - categories.COMMAND }},
            { UCBC, 'EngineerManagerUnitsAtActiveExpansionRNG', { '<', 1,  categories.MOBILE * categories.ENGINEER * categories.TECH2 - categories.STATIONASSISTPOD - categories.COMMAND } },
        },
        BuilderData = {
            JobType = 'Expansion',
            MoveToLocationType = 'ActiveExpansion',
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T3 Eng Trans ActiveExpansion',
        PlatoonTemplate = 'T3EngineerTransferRNG',
        Priority = 520,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'GreaterThanGameTimeSecondsRNG', { 600 } },
            { MIBC, 'ExpansionIsActive', {} },
            { UCBC, 'PoolGreaterAtLocation', {'MAIN', 5, categories.MOBILE * categories.ENGINEER * categories.TECH3 - categories.STATIONASSISTPOD - categories.COMMAND }},
            { UCBC, 'EngineerManagerUnitsAtActiveExpansionRNG', { '<', 1,  categories.MOBILE * categories.ENGINEER * categories.TECH3 - categories.STATIONASSISTPOD - categories.COMMAND } },
        },
        BuilderData = {
            JobType = 'Expansion',
            MoveToLocationType = 'ActiveExpansion',
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Engineer Transfer To Main From Expansion',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Eng Trans Main',
        PlatoonTemplate = 'T1EngineerTransferRNG',
        Priority = 500,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'GreaterThanGameTimeSecondsRNG', { 600 } },
            { MIBC, 'ExpansionIsActive', {} },
            { UCBC, 'PoolGreaterAtLocation', {'LocationType', 2, categories.MOBILE * categories.ENGINEER * categories.TECH1 - categories.STATIONASSISTPOD - categories.COMMAND }},
        },
        BuilderData = {
            JobType = 'Expansion',
            MoveToLocationType = 'MAIN',
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Eng Trans Main',
        PlatoonTemplate = 'T2EngineerTransferRNG',
        Priority = 510,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'GreaterThanGameTimeSecondsRNG', { 600 } },
            { MIBC, 'ExpansionIsActive', {} },
            { UCBC, 'PoolGreaterAtLocation', {'LocationType', 1, categories.MOBILE * categories.ENGINEER * categories.TECH2 - categories.STATIONASSISTPOD - categories.COMMAND }},
        },
        BuilderData = {
            JobType = 'Expansion',
            MoveToLocationType = 'MAIN',
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T3 Eng Trans Main',
        PlatoonTemplate = 'T3EngineerTransferRNG',
        Priority = 520,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'GreaterThanGameTimeSecondsRNG', { 600 } },
            { MIBC, 'ExpansionIsActive', {} },
            { UCBC, 'PoolGreaterAtLocation', {'LocationType', 1, categories.MOBILE * categories.ENGINEER * categories.TECH3 - categories.STATIONASSISTPOD - categories.COMMAND }},
        },
        BuilderData = {
            JobType = 'Expansion',
            MoveToLocationType = 'MAIN',
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGEXP Engineer Builder',
    BuildersType = 'FactoryBuilder',
    --[[Builder {
        BuilderName = 'RNGEXP Factory Engineer Initial',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 1000, -- Top factory priority
        BuilderConditions = {
            { UCBC, 'LessThanGameTimeSeconds', { 180 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 4, categories.ENGINEER - categories.COMMAND } }, -- Build engies until we have 3 of them.
        },
        BuilderType = 'All',
    },]]
    Builder {
        BuilderName = 'RNGEXP Factory Engineer T1 Mass',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 750,
        BuilderConditions = {
            { MABC, 'CanBuildOnMassDistanceRNG', { 'LocationType', 0, 120, nil, nil, 0, 'AntiSurface', 1}},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 2, categories.LAND * categories.ENGINEER } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 12, categories.ENGINEER - categories.COMMAND } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGEXP Factory Engineer T1 Power',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 775,
        BuilderConditions = {
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 2, categories.LAND * categories.ENGINEER } },
            { EBC, 'LessThanEnergyTrendOverTimeRNG', { 10.0 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 20, categories.ENGINEER - categories.COMMAND } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGEXP Factory Engineer T1 Large',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 300, -- low factory priority
        BuilderConditions = {
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech1' } },
            { UCBC, 'PoolLessAtLocation', {'LocationType', 1, categories.ENGINEER - categories.COMMAND }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 2, categories.LAND * categories.ENGINEER } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGEXP Factory Engineer T1 Expansion',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 750, -- low factory priority
        BuilderConditions = {
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech1' } },
            { UCBC, 'StartLocationNeedsEngineerRNG', { 'LocationType', 1000, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 2, categories.ENGINEER * categories.TECH1 } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGEXP Factory Engineer T2 Small',
        PlatoonTemplate = 'T2BuildEngineer',
        Priority = 900, -- Top factory priority
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 10, categories.ENGINEER * categories.TECH2 - categories.COMMAND } }, -- Build engies until we have 7 of them.
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.FACTORY * categories.TECH2}},
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGEXP Factory Engineer T2 Medium',
        PlatoonTemplate = 'T2BuildEngineer',
        Priority = 750, -- Top factory priority
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 15, categories.ENGINEER * categories.TECH2 - categories.COMMAND } }, -- Build engies until we have 10 of them.
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.FACTORY * categories.TECH2}},
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGEXP Factory Engineer T2 Large',
        PlatoonTemplate = 'T2BuildEngineer',
        Priority = 400, -- low factory priority
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.85, 0.8} },
            { UCBC, 'PoolLessAtLocation', {'LocationType', 1, categories.ENGINEER - categories.COMMAND }},
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech2' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGEXP Factory Engineer T3 Small',
        PlatoonTemplate = 'T3BuildEngineer',
        Priority = 990, -- Top factory priority
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 6, categories.ENGINEER * categories.TECH3 - categories.COMMAND } }, -- Build engies until we have 3 of them.
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.FACTORY * categories.TECH3}},
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGEXP Factory Engineer T3 Medium',
        PlatoonTemplate = 'T3BuildEngineer',
        Priority = 500, -- Top factory priority
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.30 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 15, categories.ENGINEER * categories.TECH3 - categories.COMMAND } }, -- Build engies until we have 2 of them.
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.FACTORY * categories.TECH3}},
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGEXP Factory Engineer T3 Excess',
        PlatoonTemplate = 'T3BuildEngineer',
        Priority = 300, -- low factory priority
        BuilderConditions = {
            { UCBC, 'GreaterThanFactoryCountRNG', { 0, categories.FACTORY * categories.TECH3}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.80, 0.00}},
            { UCBC, 'PoolLessAtLocation', {'LocationType', 3, categories.ENGINEER * categories.TECH3 - categories.COMMAND }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 30, categories.ENGINEER * categories.TECH3 - categories.COMMAND } },
            { UCBC, 'EngineerCapCheck', { 'LocationType', 'Tech3' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'All',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGEXP Hard Assist Builders',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGEXP Engineer Assist Quantum Gateway',
        PlatoonTemplate = 'T123EngineerAssistRNG',
        Priority = 510,
        DelayEqualBuildPlattons = {'EngineerAssistFactory', 1},
        InstanceCount = 12,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.SUBCOMMANDER}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 1.0, 1.0 }},
            { EBC, 'GreaterThanEconTrendOverTimeRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.04, 0.50}},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Assist',
            StateMachine = 'PreAllocatedTask',
            PreAllocatedTask = true,
            Task = 'EngineerAssist',
            Assist = {
                AssistLocation = 'LocationType',
                AssistUntilFinished = true,
                AssisteeType = categories.FACTORY,
                AssistRange = 80,
                BeingBuiltCategories = {categories.SUBCOMMANDER},
            },
        }
    },
    Builder {
        BuilderName = 'RNGEXP Engineer Assist HQ Upgrade',
        PlatoonTemplate = 'T123EngineerAssistRNG',
        Priority = 550,
        DelayEqualBuildPlattons = {'EngineerAssistFactory', 1},
        InstanceCount = 5,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.FACTORY * ( categories.TECH2 + categories.TECH3 ) - categories.SUPPORTFACTORY}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 1.0, 1.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.01, 0.50}},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Assist',
            StateMachine = 'PreAllocatedTask',
            PreAllocatedTask = true,
            Task = 'EngineerAssist',
            Assist = {
                AssistLocation = 'LocationType',
                AssistUntilFinished = true,
                AssisteeType = categories.FACTORY,
                AssistRange = 80,
                BeingBuiltCategories = {categories.STRUCTURE * categories.FACTORY * ( categories.TECH2 + categories.TECH3 ) - categories.SUPPORTFACTORY},
            },
        }
    },
    Builder {
        BuilderName = 'RNGEXP Engineer Unfinished Structures',
        PlatoonTemplate = 'T123EngineerFinishRNG',
        Priority = 750,
        DelayEqualBuildPlattons = {'EngineerAssistUnfinished', 1},
        InstanceCount = 8,
        BuilderConditions = {
                { UCBC, 'UnfinishedUnits', { 'LocationType', categories.STRUCTURE * (categories.FACTORY + categories.MASSEXTRACTION + categories.MASSFABRICATION + categories.ENERGYPRODUCTION)}},
                { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 1.0 }},
            },
        BuilderData = {
            JobType = 'Assist',
            StateMachine = 'PreAllocatedTask',
            PreAllocatedTask = true,
            Task = 'FinishUnit',
            Assist = {
                AssistLocation = 'LocationType',
                BeingBuiltCategories = categories.STRUCTURE * (categories.FACTORY + categories.MASSEXTRACTION + categories.MASSFABRICATION + categories.ENERGYPRODUCTION),
            },
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGEXP T123 Engineer Upgrade Mex T2',
        PlatoonTemplate = 'T123EngineerAssistRNG',
        Priority = 850,
        InstanceCount = 8,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyRNG', { 1.0, 1.0 }},
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * (categories.MASSEXTRACTION * categories.TECH2 + categories.MASSSTORAGE) }},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Assist',
            StateMachine = 'PreAllocatedTask',
            PreAllocatedTask = true,
            Task = 'EngineerAssist',
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                AssistRange = 100,
                AssistClosestUnit = true,
                BeingBuiltCategories = {categories.STRUCTURE * (categories.MASSEXTRACTION * categories.TECH2 + categories.MASSSTORAGE)},
                Time = 60,
            },
        }
    },
    Builder {
        BuilderName = 'RNGEXP T123 Engineer Upgrade Mex T3',
        PlatoonTemplate = 'T123EngineerAssistRNG',
        Priority = 840,
        InstanceCount = 8,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyRNG', { 1.0, 1.0 }},
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.MASSEXTRACTION * categories.TECH3 }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 10, categories.STRUCTURE * categories.MASSEXTRACTION * categories.TECH1 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Assist',
            StateMachine = 'PreAllocatedTask',
            PreAllocatedTask = true,
            Task = 'EngineerAssist',
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                AssistRange = 100,
                AssistClosestUnit = true,
                BeingBuiltCategories = {categories.STRUCTURE * categories.MASSEXTRACTION * categories.TECH3},
                Time = 60,
            },
        }
    },
    Builder {
        BuilderName = 'RNGEXP T123 Engineer Unfinished Experimental',
        PlatoonTemplate = 'T123EngineerAssistRNG',
        Priority = 640,
        DelayEqualBuildPlattons = {'EngineerAssistExp', 1},
        InstanceCount = 20,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyRNG', { 1.0, 1.0 }},
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.EXPERIMENTAL * categories.MOBILE }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.01, 0.50}},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Assist',
            StateMachine = 'PreAllocatedTask',
            PreAllocatedTask = true,
            Task = 'EngineerAssist',
            Assist = {
                AssistUntilFinished = true,
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                AssistRange = 100,
                AssistClosestUnit = true,
                BeingBuiltCategories = {categories.EXPERIMENTAL * categories.MOBILE},
                Time = 30,
            },
        }
    },
}