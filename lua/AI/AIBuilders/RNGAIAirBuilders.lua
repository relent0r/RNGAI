--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAIFighterAirBuilders.lua
    Author  :   relentless
    Summary :
        Air Builders
]]

local EBC = '/lua/editor/EconomyBuildConditions.lua'
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local TBC = '/lua/editor/ThreatBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'

local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetMOARadii()

local AirDefenseMode = function(self, aiBrain, manager)
    local myAirThreat = aiBrain.BrainIntel.SelfThreat.AntiAirNow
    local enemyAirThreat = aiBrain.EnemyIntel.EnemyThreatCurrent.AntiAir
    if myAirThreat < enemyAirThreat then
        --LOG('Enable Air Intie Pool Builder')
        --LOG('My Air Threat '..myAirThreat..'Enemy Air Threat '..enemyAirThreat)
        return 890
    else
        --LOG('Disable Air Intie Pool Builder')
        --LOG('My Air Threat '..myAirThreat..'Enemy Air Threat '..enemyAirThreat)
        return 0
    end
end

local AirAttackMode = function(self, aiBrain, builderManager)
    local myAirThreat = aiBrain.BrainIntel.SelfThreat.AirNow
    local enemyAirThreat = aiBrain.EnemyIntel.EnemyThreatCurrent.Air
    if myAirThreat / 1.5 > enemyAirThreat then
        --LOG('Enable Air Attack Queue')
        aiBrain.BrainIntel.AirAttackMode = true
        return 880
    else
        --LOG('Disable Air Attack Queue')
        aiBrain.BrainIntel.AirAttackMode = false
        return 0
    end
end

BuilderGroup {
    BuilderGroupName = 'RNGAI Air Builder T1',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory Intie T1',
        PlatoonTemplate = 'RNGAIFighterGroup',
        Priority = 700,
        BuilderConditions = { 
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, 'FACTORY AIR TECH3' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.5}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.8 }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 1, categories.AIR * categories.ANTIAIR * categories.TECH3} },
            { UCBC, 'PoolLessAtLocation', {'LocationType', 10, categories.AIR * categories.ANTIAIR }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory Intie Response',
        PlatoonTemplate = 'RNGAIFighterGroup',
        Priority = 900,
        BuilderConditions = { 
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, 'FACTORY AIR TECH3' }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.3, 0.7 }},
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.AIR - categories.SCOUT }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory Intie Enemy Threat',
        PlatoonTemplate = 'RNGAIFighterGroup',
        Priority = 0,
        PriorityFunction = AirDefenseMode,
        BuilderConditions = { 
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, 'FACTORY AIR TECH3' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.5}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.9 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory Bomber T1 Response',
        PlatoonTemplate = 'T1AirBomber',
        Priority = 850,
        BuilderConditions = {
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, 'FACTORY AIR TECH2' }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, 'FACTORY AIR TECH3' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.3, 0.5}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.9 }},
            { UCBC, 'EnemyUnitsLessAtLocationRadius', { BaseEnemyArea, 'LocationType', 1, categories.ANTIAIR }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 3, categories.AIR * categories.BOMBER * categories.TECH2} },
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory Gunship T1',
        PlatoonTemplate = 'T1Gunship',
        Priority = 750,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 3 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.5}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.9 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, 'FACTORY AIR TECH2, FACTORY AIR TECH3' }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Air Attack Queue T1',
        PlatoonTemplate = 'RNGAIT1AirQueue',
        Priority = 0,
        PriorityFunction = AirAttackMode,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.5}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.9 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, 'FACTORY AIR TECH2, FACTORY AIR TECH3' }},
        },
        BuilderType = 'Air',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Air Builder T2',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Air Attack Queue T2',
        PlatoonTemplate = 'RNGAIT2AirQueue',
        Priority = 0,
        PriorityFunction = AirAttackMode,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.5}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.9 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, 'FACTORY AIR TECH3' }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory Intie Enemy Threat T2',
        PlatoonTemplate = 'RNGAIFighterGroupT2',
        Priority = 0,
        PriorityFunction = AirDefenseMode,
        BuilderConditions = { 
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, 'FACTORY AIR TECH3' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.5}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.9 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory Swift Wind Response',
        PlatoonTemplate = 'RNGAIT2FighterAeon',
        Priority = 910,
        BuilderConditions = { 
            { MIBC, 'FactionIndex', { 2 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, 'FACTORY AIR TECH3' }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.2, 0.7 }},
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.AIR - categories.SCOUT }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory T2 FighterBomber ACUClose',
        PlatoonTemplate = 'T2FighterBomber',
        Priority = 800,
        BuilderType = 'Air',
        BuilderConditions = { 
            { TBC, 'EnemyACUCloseToBase', {}},
            { MIBC, 'FactionIndex', { 1, 3, 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads 
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.9 }},
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Gunship',
        PlatoonTemplate = 'T2AirGunship',
        Priority = 700,
        BuilderType = 'Air',
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.04, 0.5}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.9 }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 12, categories.AIR * categories.GROUNDATTACK * categories.TECH2} },
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Mercy',
        PlatoonTemplate = 'T2AirMissile',
        Priority = 750,
        BuilderType = 'Air',
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.04, 0.5}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.9 }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 3, categories.AIR * categories.TECH2 * categories.daa0206} },
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Torp Bomber',
        PlatoonTemplate = 'T2AirTorpedoBomber',
        Priority = 750,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatio', { 0.04, 0.50 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 11, categories.MOBILE * categories.AIR * categories.ANTINAVY }},
            { UCBC, 'UnitsGreaterAtEnemy', { 0 , categories.NAVAL * categories.FACTORY } },
            { UCBC, 'HaveUnitRatioRNG', { 0.5, categories.MOBILE * categories.AIR * categories.ANTINAVY, '<',categories.MOBILE * categories.AIR * categories.ANTIAIR - categories.GROUNDATTACK - categories.BOMBER } },
            { EBC, 'GreaterThanEconTrend', { 0.0, 0.0 } },
        },
        BuilderType = 'Air',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Air Builder T3',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory ASF Response',
        PlatoonTemplate = 'RNGAIT3AirResponse',
        Priority = 900,
        BuilderConditions = { 
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, 'FACTORY AIR TECH3' }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.4, 0.7 }},
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.AIR - categories.SCOUT }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI T3 Air Queue',
        PlatoonTemplate = 'RNGAIT3AirQueue',
        Priority = 850,
        PriorityFunction = AirDefenseMode,
        BuilderType = 'Air',
        BuilderConditions = {
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, 'FACTORY AIR TECH3' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, 'ENERGYPRODUCTION TECH3' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.9 }},
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Air Attack Queue',
        PlatoonTemplate = 'RNGAIT3AirAttackQueue',
        Priority = 0,
        PriorityFunction = AirAttackMode,
        BuilderType = 'Air',
        BuilderConditions = {
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, 'FACTORY AIR TECH3' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, 'ENERGYPRODUCTION TECH3' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.9 }},
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Air Response Formers',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI Air Intercept Response BaseRestrictedArea',
        PlatoonTemplate = 'RNGAI AntiAirHunt',
        PlatoonAddBehaviors = { 'AirUnitRefit' },
        Priority = 950,
        InstanceCount = 5,
        BuilderType = 'Any',
        BuilderData = {
            NeverGuardEngineers = true,
            PrioritizedCategories = {
                'BOMBER AIR',
                'GUNSHIP AIR',
                'ANTIAIR AIR',
            },
        },
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.AIR - categories.SCOUT }},
        },
    },
    Builder {
        BuilderName = 'RNGAI Air Mercy BaseEnemyArea',
        PlatoonTemplate = 'RNGAI MercyAttack',
        Priority = 960,
        InstanceCount = 4,
        BuilderType = 'Any',
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            PrioritizedCategories = {
                'COMMAND',
                'EXPERIMENTAL',
            },
        },
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseEnemyArea, 'LocationType', 0, categories.COMMAND - categories.EXPERIMENTAL }},
            { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 3, categories.daa0206 } },
        },
    },
    Builder {
        BuilderName = 'RNGAI Air AntiNavy BaseEnemyArea',
        PlatoonTemplate = 'RNGAI TorpBomberAttack',
        Priority = 960,
        InstanceCount = 4,
        BuilderType = 'Any',
        BuilderData = {
            SearchRadius = BaseMilitaryArea,
            PrioritizedCategories = {
                'COMMAND',
                'EXPERIMENTAL',
                'NAVAL',
                'AMPHIBIOUS',
            },
        },
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseMilitaryArea, 'LocationType', 0, categories.NAVAL * categories.MOBILE }},
            { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.AIR * categories.ANTINAVY - categories.EXPERIMENTAL } },
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Air Platoon Builder',
    BuildersType = 'PlatoonFormBuilder', -- A PlatoonFormBuilder is for builder groups of units.
    Builder {
        BuilderName = 'RNGAI Air Intercept',
        PlatoonTemplate = 'RNGAI AntiAirHunt',
        PlatoonAddBehaviors = { 'AirUnitRefit' },
        Priority = 800,
        InstanceCount = 5,
        BuilderType = 'Any',
        BuilderData = {
            AvoidBases = true,
            NeverGuardEngineers = true,
            PrioritizedCategories = {
                'GUNSHIP AIR',
                'BOMBER AIR',
                'ANTIAIR AIR',
            },
        },
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.AIR * categories.MOBILE * (categories.TECH1 + categories.TECH2 + categories.TECH3) * categories.ANTIAIR } },
         },
    },
    Builder {
        BuilderName = 'RNGAI Air Lockdown',
        PlatoonTemplate = 'AntiAirHunt',
        PlatoonAddBehaviors = { 'AirUnitRefit' },
        Priority = 750,
        InstanceCount = 8,
        BuilderType = 'Any',
        BuilderData = {
            NeverGuardEngineers = true,
            PrioritizedCategories = {
                'EXPERIMENTAL AIR',
                'BOMBER AIR',
                'GUNSHIP AIR',
                'ANTIAIR AIR',
            },
        },
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.AIR * categories.MOBILE * (categories.TECH1 + categories.TECH2 + categories.TECH3) * categories.ANTIAIR - categories.GROUNDATTACK } },
         },
    },
    Builder {
        BuilderName = 'RNGAI Bomber Base Guard',
        PlatoonTemplate = 'RNGAI Bomber BaseGuard',
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        PlatoonAddBehaviors = { 'AirUnitRefit' },
        Priority = 890,
        InstanceCount = 5,
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseMilitaryArea, 'LocationType', 0, categories.MOBILE * categories.LAND - categories.SCOUT}},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 1, categories.MOBILE * categories.AIR * categories.BOMBER - categories.TECH3 - categories.daa0206 } },
        },
        BuilderData = {
            GuardType = 'Bomber',
            SearchRadius = BaseMilitaryArea,
            PrioritizedCategories = {
                'ENGINEER TECH1',
                'MOBILE LAND',
                'MASSEXTRACTION',
                'ALLUNITS',
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Bomber Attack',
        PlatoonTemplate = 'RNGAI BomberAttack',
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        PlatoonAddBehaviors = { 'AirUnitRefit' },
        Priority = 890,
        InstanceCount = 3,
        BuilderType = 'Any',        
        BuilderConditions = { 
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.AIR * categories.BOMBER - categories.daa0206 } },
        },
        BuilderData = {
            SearchRadius = BaseMilitaryArea,
            PrioritizedCategories = {
                'MASSEXTRACTION',
                'ENGINEER TECH1',
                'MOBILE LAND',
                'MOBILE ANTIAIR',
                'ALLUNITS',
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Bomber Attack MassRaid',
        PlatoonTemplate = 'RNGAI BomberAttack',
        PlatoonAddBehaviors = { 'AirUnitRefit' },
        Priority = 900,
        InstanceCount = 2,
        BuilderType = 'Any',        
        BuilderConditions = { 
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.AIR * categories.BOMBER - categories.daa0206 } },
        },
        BuilderData = {
            AvoidBases = true,
            SearchRadius = BaseEnemyArea,
            PrioritizedCategories = {
                'MASSEXTRACTION',
                'ENGINEER',
                'ENERGYPRODUCTION',
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Gunship Attack T1',
        PlatoonTemplate = 'RNGAI GunShipAttack',
        Priority = 890,
        InstanceCount = 5,
        BuilderType = 'Any',
        BuilderConditions = { 
            { MIBC, 'FactionIndex', { 3 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.AIR * categories.MOBILE * categories.GROUNDATTACK * categories.TECH1 } },
        },
        BuilderData = {
            SearchRadius = BaseMilitaryArea,
            AvoidBases = true,
            TargetSearchPriorities = {
                'ENGINEER',
                'MASSEXTRACTION',
                'RADAR STRUCTURE',
                'ENERGYSTORAGE',
                'ENERGYPRODUCTION',
                'ALLUNITS',
            },
            PrioritizedCategories = {
                'MOBILE LAND ANTIAIR',
                'MOBILE LAND',
                'ENGINEER',
                'MOBILE LAND ANTIAIR',
                'MASSEXTRACTION',
                'ALLUNITS',
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Gunship Attack T2T3',
        PlatoonTemplate = 'RNGAI GunShipAttack',
        Priority = 890,
        InstanceCount = 5,
        BuilderType = 'Any',
        BuilderConditions = { 
            { UCBC, 'ScalePlatoonSize', { 'LocationType', 'AIR', categories.AIR * categories.MOBILE * categories.GROUNDATTACK * (categories.TECH2 + categories.TECH3) } },
        },
        BuilderData = {
            SearchRadius = BaseMilitaryArea,
            TargetSearchPriorities = {
                'MOBILE LAND',
                'MASSEXTRACTION',
                'RADAR STRUCTURE',
                'ENERGYSTORAGE',
                'ENERGYPRODUCTION',
                'ALLUNITS',
            },
            PrioritizedCategories = {
                'MOBILE LAND ANTIAIR',
                'MOBILE LAND',
                'ENGINEER',
                'MASSEXTRACTION',
                'RADAR STRUCTURE',
                'ENERGYSTORAGE',
                'ENERGYPRODUCTION',
                'ALLUNITS',
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Bomber Attack Enemy',
        PlatoonTemplate = 'RNGAI BomberAttack',
        Priority = 890,
        InstanceCount = 3,
        BuilderType = 'Any',        
        BuilderConditions = { 
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.AIR * categories.BOMBER * categories.TECH1 - categories.daa0206 } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            PrioritizedCategories = {
                'RADAR STRUCTURE',
                'ENGINEER TECH1',
                'MOBILE ANTIAIR',
                'ENERGYPRODUCTION',
                'MOBILE LAND',
                'MASSEXTRACTION',
                'ALLUNITS',
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Bomber Attack Excess',
        PlatoonTemplate = 'RNGAI BomberAttack',
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        Priority = 700,
        InstanceCount = 20,
        BuilderType = 'Any',        
        BuilderConditions = { 
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.MOBILE * categories.AIR * categories.BOMBER - categories.daa0206 } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            PrioritizedCategories = {
                'MASSEXTRACTION',
                'ENGINEER TECH1',
                'MOBILE ANTIAIR',
                'ENERGYSTORAGE',
                'ENERGYPRODUCTION',
                'ALLUNITS',
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Energy Attack',
        PlatoonTemplate = 'RNGAI BomberEnergyAttack',
        Priority = 890,
        InstanceCount = 3,
        BuilderType = 'Any',        
        BuilderConditions = { 
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.AIR * categories.BOMBER - categories.daa0206 } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            PrioritizedCategories = {
                'RADAR STRUCTURE',
                'ENERGYSTORAGE',
                'ENERGYPRODUCTION TECH3',
                'ENERGYPRODUCTION TECH2',
                'ENERGYPRODUCTION TECH1',
                'ALLUNITS',
            },
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI TransportFactoryBuilders Large',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Air Transport Large Need',
        PlatoonTemplate = 'T1AirTransport',
        Priority = 900,
        BuilderConditions = {
            { MIBC, 'ArmyNeedsTransports', {} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.8}},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, 'TRANSPORTFOCUS' } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, 'TRANSPORTFOCUS' } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI T1 Air Transport Large Want',
        PlatoonTemplate = 'T1AirTransport',
        Priority = 900,
        BuilderConditions = {
            { MIBC, 'ArmyWantsTransports', {} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.8}},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, 'TRANSPORTFOCUS' } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, 'TRANSPORTFOCUS' } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI T1 Air Transport Excess Large',
        PlatoonTemplate = 'T1AirTransport',
        Priority = 700,
        BuilderConditions = {
            { MIBC, 'ArmyNeedsTransports', {} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.8}},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 5, 'TRANSPORTFOCUS' } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, 'TRANSPORTFOCUS' } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Transport Large',
        PlatoonTemplate = 'T2AirTransport',
        Priority = 910,
        BuilderConditions = {
            { MIBC, 'ArmyNeedsTransports', {} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.8}},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, 'TRANSPORTFOCUS' } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, 'TRANSPORTFOCUS' } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Transport Excess Large',
        PlatoonTemplate = 'T2AirTransport',
        Priority = 700,
        BuilderConditions = {
            { MIBC, 'ArmyNeedsTransports', {} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.08, 0.8}},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 5, 'TRANSPORTFOCUS' } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, 'TRANSPORTFOCUS' } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
        },
        BuilderType = 'Air',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI TransportFactoryBuilders Small',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Air Transport Need',
        PlatoonTemplate = 'T1AirTransport',
        Priority = 850,
        BuilderConditions = {
            { MIBC, 'ArmyNeedsTransports', {} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.04, 0.8}},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, 'TRANSPORTFOCUS' } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, 'TRANSPORTFOCUS' } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI T1 Air Transport Want',
        PlatoonTemplate = 'T1AirTransport',
        Priority = 850,
        BuilderConditions = {
            { MIBC, 'ArmyWantsTransports', {} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.04, 0.8}},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, 'TRANSPORTFOCUS' } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, 'TRANSPORTFOCUS' } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI T1 Air Transport Excess',
        PlatoonTemplate = 'T1AirTransport',
        Priority = 700,
        BuilderConditions = {
            { MIBC, 'ArmyNeedsTransports', {} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.8}},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 5, 'TRANSPORTFOCUS' } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, 'TRANSPORTFOCUS' } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Transport',
        PlatoonTemplate = 'T2AirTransport',
        Priority = 860,
        BuilderConditions = {
            { MIBC, 'ArmyNeedsTransports', {} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.8}},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, 'TRANSPORTFOCUS' } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, 'TRANSPORTFOCUS' } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Transport Excess',
        PlatoonTemplate = 'T2AirTransport',
        Priority = 700,
        BuilderConditions = {
            { MIBC, 'ArmyNeedsTransports', {} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.08, 0.8}},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 5, 'TRANSPORTFOCUS' } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, 'TRANSPORTFOCUS' } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
        },
        BuilderType = 'Air',
    },
}